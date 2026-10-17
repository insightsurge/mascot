"""Pixel comparison pictures and metrics; no image library or external assets."""
import html
import hashlib
import json
from pathlib import Path
import struct
import zlib


def png(width, height, pixels):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    rows = b''.join(b'\0' + pixels[y * width * 4:(y + 1) * width * 4] for y in range(height))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


def picture(width, height, old, new):
    if len(old) != width * height * 4 or len(new) != len(old):
        raise ValueError('Comparison image dimensions differ')
    changed, maximum, xs, ys = 0, 0, [], []
    mask = bytearray()
    for offset in range(0, len(old), 4):
        delta = max(abs(a - b) for a, b in zip(old[offset:offset+4], new[offset:offset+4]))
        maximum = max(maximum, delta)
        if delta:
            changed += 1
            xs.append((offset // 4) % width)
            ys.append((offset // 4) // width)
        mask.extend((255, 0, 255, 255) if delta else (0, 0, 0, 255))
    combined = bytearray()
    stride = width * 4
    for row in range(height):
        for pixels in (old, new, mask):
            combined.extend(pixels[row * stride:(row + 1) * stride])
    return png(width * 3, height, combined), {
        'changed_pixels': changed, 'total_pixels': width * height,
        'changed_percent': 100 * changed / (width * height), 'max_channel_delta': maximum,
        'bounds_xyxy': [min(xs), min(ys), max(xs), max(ys)] if xs else None,
    }


def write_report(output, baseline, candidate, old, new, decode):
    output = Path(output)
    if output.exists():
        raise ValueError('Report already exists; never overwrite reviewed evidence')
    # All integrity/environment/frame checks precede this call in compare().
    results, images = [], {}
    for name in sorted(old['files']):
        width, height, pixels = decode(Path(baseline) / name)
        other_width, other_height, other = decode(Path(candidate) / name)
        if (width, height) != (other_width, other_height):
            raise ValueError('Comparison image dimensions differ')
        image, metrics = picture(width, height, pixels, other)
        images[name] = image
        if metrics['bounds_xyxy']:
            left, top, right, bottom = metrics['bounds_xyxy']
            left, top = max(0, left - 4), max(0, top - 4)
            right, bottom = min(width - 1, right + 4), min(height - 1, bottom + 4)
            def crop(data):
                return b''.join(data[(y * width + left) * 4:(y * width + right + 1) * 4] for y in range(top, bottom + 1))
            detail, _ = picture(right - left + 1, bottom - top + 1, crop(pixels), crop(other))
            metrics['detail_picture'] = Path(name).stem + '-detail.png'
            images[metrics['detail_picture']] = detail
        results.append({'file': name, **old['cases'][name], **metrics})
    output.mkdir(parents=True)
    for name, image in images.items():
        (output / name).write_bytes(image)
    differences = sum(row['changed_pixels'] > 0 for row in results)
    record = {'status': old['status'], 'baseline_source': old['source'], 'candidate_source': new['source'],
              'baseline_manifest_sha256': hashlib.sha256((Path(baseline) / 'manifest.json').read_bytes()).hexdigest(),
              'candidate_manifest_sha256': hashlib.sha256((Path(candidate) / 'manifest.json').read_bytes()).hexdigest(),
              'frames': len(results), 'different_frames': differences, 'results': results}
    (output / 'results.json').write_text(json.dumps(record, indent=2, sort_keys=True) + '\n')
    rows = []
    for row in results:
        name = html.escape(row['file'])
        metrics = f"{row['changed_pixels']}/{row['total_pixels']} pixels ({row['changed_percent']:.4f}%); max channel delta {row['max_channel_delta']}; bounds {row['bounds_xyxy']}"
        detail = (f'<p>Changed region, enlarged:</p><img src="{html.escape(row["detail_picture"])}" alt="Enlarged changed region for {name}">'
                  if row.get('detail_picture') else '')
        rows.append(f'<section id="{name}" class="{"different" if row["changed_pixels"] else "same"}"><h2>{name}</h2><p>{metrics}</p><img src="{name}" alt="Old baseline, adapter, and magenta changed-pixel mask for {name}">{detail}</section>')
    links = ' '.join(f'<a href="#{html.escape(row["file"])}">{html.escape(row["file"])}</a>' for row in results if row['changed_pixels'])
    (output / 'index.html').write_text(f'''<!doctype html><html lang="en"><meta charset="utf-8"><title>Tessa E1 comparison</title>
<style>body{{font:16px system-ui;margin:2rem;background:#111827;color:#e5e7eb}}a{{color:#7dd3fc}}section{{margin:2rem 0;padding:1rem;border:1px solid #374151}}.different{{border-color:#f472b6}}img{{display:block;width:min(100%,960px);height:auto;image-rendering:pixelated}}h2{{font-size:1rem;overflow-wrap:anywhere}}nav a{{display:block}}</style>
<h1>Tessa E1: {differences}/{len(results)} different frames</h1><p>{html.escape(old['status'])}: non-canonical evidence when provisional. Exact RGBA comparison, no tolerance. Comparison is separate from baseline approval.</p>
<p>Left: old baseline. Centre: adapter. Right: every changed pixel is magenta (black means identical). Images enlarged with nearest-neighbour CSS; source pixels unchanged.</p>
<p>Baseline: {html.escape(old['source'])}<br>Candidate: {html.escape(new['source'])}</p><nav>{links or 'No differences.'}</nav>{''.join(rows)}</html>''')
    return record
