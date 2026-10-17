#!/usr/bin/env python3
"""Explicit captures and exact decoded-pixel checks; excluded from the R package."""
import argparse
import base64
import gzip
import hashlib
import json
import os
from pathlib import Path
import platform
import struct
import subprocess
import sys
import tarfile
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = Path(__file__).with_name('profile-template.json')
FILES = {
    'mascot.js': 'inst/www/mascot.js',
    'mascot-parts.js': 'inst/www/mascot-parts.js',
    'mascot-geometry.js': 'inst/www/mascot-geometry.js',
    'mascot-faces.js': 'inst/www/mascot-faces.js',
    'mascot-motion.js': 'inst/www/mascot-motion.js',
    'mascot-player.js': 'inst/www/mascot-player.js',
    'tessa.json': 'inst/format/characters/tessa.json',
    'classic.json': 'inst/format/kits/classic.json',
    'screen.json': 'inst/format/kits/screen.json',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text())


def write_json(path, data):
    Path(path).write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])


def rgba(path):
    """Decode non-interlaced Chrome RGB/RGBA8 PNGs, including all PNG row filters."""
    data = Path(path).read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f'Not PNG: {path}')
    at, payload, header = 8, bytearray(), None
    while at < len(data):
        length = struct.unpack('>I', data[at:at+4])[0]
        kind, body = data[at+4:at+8], data[at+8:at+8+length]
        crc = struct.unpack('>I', data[at+8+length:at+12+length])[0]
        if zlib.crc32(kind + body) & 0xffffffff != crc:
            raise ValueError(f'PNG checksum failed: {path}')
        if kind == b'IHDR':
            header = struct.unpack('>IIBBBBB', body)
        elif kind == b'IDAT':
            payload.extend(body)
        at += 12 + length
        if kind == b'IEND':
            break
    if header is None:
        raise ValueError('Missing PNG header')
    width, height, depth, colour, compression, filtering, interlace = header
    if depth != 8 or colour not in (2, 6) or (compression, filtering, interlace) != (0, 0, 0):
        raise ValueError('Expected non-interlaced RGB/RGBA8 PNG')
    channels = 4 if colour == 6 else 3
    stride = width * channels
    raw = zlib.decompress(payload)
    if len(raw) != height * (stride + 1):
        raise ValueError('PNG decoded size differs from header')
    previous, pixels = bytearray(stride), bytearray()
    for y in range(height):
        offset = y * (stride + 1)
        method = raw[offset]
        row = bytearray(raw[offset+1:offset+1+stride])
        for x in range(stride):
            left = row[x-channels] if x >= channels else 0
            up = previous[x]
            corner = previous[x-channels] if x >= channels else 0
            if method == 0:
                predictor = 0
            elif method == 1:
                predictor = left
            elif method == 2:
                predictor = up
            elif method == 3:
                predictor = (left + up) // 2
            elif method == 4:
                estimate = left + up - corner
                distances = (abs(estimate-left), abs(estimate-up), abs(estimate-corner))
                predictor = (left, up, corner)[distances.index(min(distances))]
            else:
                raise ValueError('Unknown PNG row filter')
            row[x] = (row[x] + predictor) & 255
        if channels == 4:
            pixels.extend(row)
        else:
            for x in range(0, stride, 3):
                pixels.extend(row[x:x+3] + b'\xff')
        previous = row
    return width, height, bytes(pixels)


def profile_check(path):
    """Fail closed; a template or an uncommitted lock is never a canonical profile."""
    if not path or not Path(path).is_file():
        raise ValueError('Missing canonical profile lock; provisional captures cannot approve T1')
    path = Path(path).resolve()
    profile = read_json(path)
    if profile.get('status') != 'locked':
        raise ValueError('Canonical profile is not locked')
    for field in ('container', 'chrome', 'chrome_sha256', 'chromote', 'font_files', 'font_packages'):
        if not profile.get(field):
            raise ValueError(f'Missing pinned {field}')
    if '@sha256:' not in profile['container']:
        raise ValueError('Container must be pinned by digest')
    template = read_json(TEMPLATE)
    for field in ('viewport', 'dpr', 'sizes', 'colour_space', 'locale', 'timezone', 'moods', 'frame', 'origin', 'backdrops', 'flags'):
        if profile.get(field) != template[field]:
            raise ValueError(f'Capture setting differs: {field}')
    if platform.system() != 'Linux' or platform.machine() not in ('x86_64', 'amd64'):
        raise ValueError('Canonical capture requires Linux x86_64')
    os_release = Path('/etc/os-release').read_text()
    if 'ID=ubuntu' not in os_release or 'VERSION_ID="24.04"' not in os_release:
        raise ValueError('Canonical capture requires Ubuntu 24.04')
    if os.environ.get('MASCOT_VISUAL_CONTAINER') != profile['container']:
        raise ValueError('Container identity differs from lock')
    chrome = os.environ.get('CHROMOTE_CHROME')
    if not chrome or sha(Path(chrome).read_bytes()) != profile['chrome_sha256']:
        raise ValueError('Chrome executable missing or checksum differs')
    for font, checksum in profile['font_files'].items():
        if sha(Path(font).read_bytes()) != checksum:
            raise ValueError(f'Font checksum differs: {font}')
    for package, version in profile['font_packages'].items():
        actual = subprocess.check_output(['dpkg-query', '-W', '-f=${Version}', package], text=True)
        if actual != version:
            raise ValueError(f'Font package differs: {package}')
    relative = str(path.relative_to(ROOT))
    if git('show', f'HEAD:{relative}') != path.read_bytes():
        raise ValueError('Commit the reviewed profile lock before canonical capture')
    return profile


def capture(output, source, lock=None, provisional=False, defect=False,
            character_file=None, background=None, dpr=None):
    profile = read_json(TEMPLATE) if provisional else profile_check(lock)
    output = Path(output).resolve()
    if output.exists():
        raise ValueError('Output already exists; captures never overwrite baselines')
    output.mkdir(parents=True)
    source_sha = git('rev-parse', 'HEAD' if source == 'working-tree' else f'{source}^{{commit}}').decode().strip()
    source_label = ('working-tree:' if source == 'working-tree' else '') + source_sha

    if character_file is not None:
        char_path = Path(character_file).resolve()
        if not char_path.is_file():
            raise ValueError(f'Character file not found: {character_file}')
        char_bytes = char_path.read_bytes()
        char_info = json.loads(char_bytes.decode('utf-8'))
        char_id = char_info.get('id', char_path.stem)
        char_sha = sha(char_bytes)
        bg = background if background is not None else 'light'
        modes = [bg]
        backdrops = {'light': '#ffffff', 'dark': '#16201b'}
        character_filename = f'{char_id}.json'
    else:
        char_id = 'tessa'
        character_filename = 'tessa.json'
        if background is not None:
            bg = background
            modes = [bg]
            backdrops = {'light': '#ffffff', 'dark': '#16201b' if bg == 'dark' else '#212529'}
        else:
            bg = None
            modes = ['light', 'dark']
            backdrops = {'light': '#ffffff', 'dark': '#212529'}

    with tempfile.TemporaryDirectory(prefix='mascot-visual-') as work:
        work = Path(work)
        hashes = {}
        files = dict(FILES)
        if character_file is not None:
            del files['tessa.json']
            (work / character_filename).write_bytes(char_bytes)
            hashes[str(character_file)] = char_sha
        for name, file in files.items():
            data = (ROOT / file).read_bytes() if source == 'working-tree' else git('show', f'{source_sha}:{file}')
            hashes[file] = sha(data)
            if defect and name == 'mascot-faces.js':
                needle = b'glyphs.push(eye(entry, face, index, value, flags));'
                if data.count(needle) != 1:
                    raise ValueError('Missing-eye probe insertion point changed')
                data = data.replace(needle, b'/* planted defect: eyes omitted */')
            (work / name).write_bytes(data)
        config = {
            'source': str(work),
            'output': str(output),
            'flags': profile['flags'],
            'chrome': None if provisional else profile['chrome'],
            'chromote': None if provisional else profile['chromote'],
            'character_id': char_id,
            'character_file': character_filename,
            'modes': modes,
            'backdrops': backdrops,
            'dprs': [dpr] if dpr else [1, 2],
        }
        write_json(work / 'config.json', config)
        env = dict(os.environ, RENV_CONFIG_AUTOLOADER_ENABLED='FALSE')
        subprocess.run(['Rscript', str(Path(__file__).with_name('capture.R')), str(work / 'config.json')],
                       env=env, check=True, cwd=ROOT)
    record = read_json(output / 'capture.json')
    record['runtime']['chrome_sha256'] = sha(Path(record['runtime'].pop('chrome_path')).read_bytes())
    manifest = {'status': 'provisional-macos' if provisional else 'canonical',
                'source': source_label, 'source_files': hashes, 'defect': 'missing-eyes' if defect else None,
                'profile': profile, 'profile_sha256': None if provisional else sha(Path(lock).read_bytes()),
                **record, 'files': {}}
    if provisional:
        manifest['status'] = 'provisional-' + platform.system().lower()
    if character_file is not None:
        manifest['character_file'] = str(character_file)
        manifest['character_sha256'] = char_sha
        manifest['character'] = char_id
    if bg is not None:
        manifest['background'] = bg
    if character_file is not None or background is not None:
        manifest['profile']['backdrops'] = backdrops

    for name, case in record['cases'].items():
        width, height, pixels = rgba(output / name)
        if (width, height) != (case['size'] * case['dpr'],) * 2:
            raise ValueError('Decoded capture dimensions differ')
        manifest['files'][name] = {'png_sha256': sha((output / name).read_bytes()), 'rgba_sha256': sha(pixels)}
    write_json(output / 'manifest.json', manifest)
    (output / 'capture.json').unlink()
    print(f'CAPTURE {manifest["status"]}: {len(manifest["files"])} frames from {source_sha[:7]}')
    return output


def verify_archive(path, digest, directory):
    if not path or not digest or not Path(path).is_file():
        raise ValueError('Supply the pinned archive and SHA256; decoded images alone are insufficient')
    path, directory = Path(path), Path(directory)
    if sha(path.read_bytes()) != digest:
        raise ValueError('Pinned archive checksum differs')
    with tarfile.open(path) as archive:
        expected = {file.name for file in directory.iterdir() if file.is_file()}
        members = archive.getmembers()
        if {member.name for member in members} != expected or len(members) != len(expected):
            raise ValueError('Archive member set differs')
        for member in members:
            if not member.isfile() or archive.extractfile(member).read() != (directory / member.name).read_bytes():
                raise ValueError('Archive member differs from supplied decoded baseline')


def compare(baseline, candidate, strict=False, lock=None, archive_file=None, archive_sha256=None, report=None):
    baseline, candidate = Path(baseline), Path(candidate)
    old, new = read_json(baseline / 'manifest.json'), read_json(candidate / 'manifest.json')
    CORE_MOODS = ('idle', 'thinking', 'happy', 'worried', 'celebrating')
    for record in (old, new):
        if tuple(record.get('profile', {}).get('moods', [])) != CORE_MOODS:
            raise ValueError('Manifest profile moods must be exactly the five core moods')
    if strict:
        verify_archive(archive_file, archive_sha256, baseline)
        profile_check(lock)
        for record in (old, new):
            if record['status'] != 'canonical' or record['profile_sha256'] != sha(Path(lock).read_bytes()):
                raise ValueError('Missing/different canonical profile; provisional captures are never accepted')
    if old['profile'] != new['profile'] or old['runtime'] != new['runtime']:
        raise ValueError('Different capture environments; review/rebaseline explicitly')
    expected = {f'tessa-{m}-{mode}-{size}-dpr{dpr}.png' for m in CORE_MOODS
                for mode in ('light', 'dark') for size in (160, 96, 24) for dpr in (1, 2)}
    if set(old['files']) != expected or set(new['files']) != expected:
        raise ValueError('Incomplete or different frame sets')
    differences = []
    for name in sorted(expected):
        for directory, record in ((baseline, old), (candidate, new)):
            width, height, pixels = rgba(directory / name)
            if sha(pixels) != record['files'][name]['rgba_sha256']:
                raise ValueError(f'Decoded checksum differs: {directory / name}')
            if sha((directory / name).read_bytes()) != record['files'][name]['png_sha256']:
                raise ValueError(f'Archive member checksum differs: {directory / name}')
        if rgba(baseline / name) != rgba(candidate / name):
            differences.append(name)
    if report:
        from visual_report import write_report
        write_report(report, baseline, candidate, old, new, rgba)
        print(f'REPORT: {Path(report).resolve() / "index.html"}')
    if differences:
        raise ValueError(f'{len(differences)}/{len(expected)} frames differ: {differences[0]}')
    print(f'COMPARE PASS: {len(expected)} frames, exact decoded RGBA ({old["status"]})')


def archive(directory):
    directory = Path(directory).resolve()
    with tempfile.NamedTemporaryFile(suffix='.tar.gz', delete=False) as temp:
        path = Path(temp.name)
    try:
        with path.open('wb') as raw, gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode='w', format=tarfile.USTAR_FORMAT) as tar:
                for file in sorted(directory.iterdir()):
                    if file.is_file():
                        info = tar.gettarinfo(str(file), arcname=file.name)
                        info.uid = info.gid = info.mtime = 0
                        info.uname = info.gname = ''
                        info.mode = 0o644
                        with file.open('rb') as content:
                            tar.addfile(info, content)
        digest = sha(path.read_bytes())
        destination = directory.parent / f'{digest}.tar.gz'
        if destination.exists() and destination.read_bytes() != path.read_bytes():
            raise ValueError('Content-addressed archive collision')
        path.replace(destination)
        destination.with_suffix('.gz.sha256').write_text(f'{digest}  {destination.name}\n')
        print(f'ARCHIVE {destination.name}')
    finally:
        path.unlink(missing_ok=True)


def sheet(capture_dirs, output, reference=None):
    CORE_MOODS = ('idle', 'thinking', 'happy', 'worried', 'celebrating')
    sizes = (160, 96, 24)
    ref_dir = Path(reference).resolve() if reference else None
    captures = []
    for cap_dir in capture_dirs:
        cap_path = Path(cap_dir).resolve()
        manifest_file = cap_path / 'manifest.json'
        if not manifest_file.is_file():
            raise ValueError(f'Missing manifest.json in {cap_path}')
        manifest = read_json(manifest_file)
        char_id = manifest.get('character')
        if not char_id:
            for f in manifest.get('files', {}):
                char_id = f.split('-')[0]
                break
            char_id = char_id or 'tessa'
        bg = manifest.get('background')
        if not bg:
            modes = {c.get('mode') for c in manifest.get('cases', {}).values()}
            bg = modes.pop() if len(modes) == 1 else 'light'
        palette = manifest.get('palette', 'original')
        cases = manifest.get('cases', {})
        best_dpr = max((c.get('dpr', 1) for c in cases.values()), default=2)

        rows = []
        for mood in CORE_MOODS:
            row = {'mood': mood, 'sizes': {}}
            for sz in sizes:
                target_name = None
                for name, case in cases.items():
                    if case.get('mood') == mood and case.get('size') == sz and case.get('dpr') == best_dpr:
                        if bg and case.get('mode') == bg:
                            target_name = name
                            break
                        elif target_name is None:
                            target_name = name
                if target_name and (cap_path / target_name).is_file():
                    data = (cap_path / target_name).read_bytes()
                    row['sizes'][sz] = f'data:image/png;base64,{base64.b64encode(data).decode("ascii")}'
                else:
                    row['sizes'][sz] = None

            ref_svg = None
            if ref_dir:
                ref_file = ref_dir / f'{char_id}-{mood}-full.svg'
                if ref_file.is_file():
                    data = ref_file.read_bytes()
                    ref_svg = f'data:image/svg+xml;base64,{base64.b64encode(data).decode("ascii")}'
            row['reference_svg'] = ref_svg
            rows.append(row)

        captures.append({
            'dir_name': cap_path.name,
            'character': char_id,
            'background': bg,
            'palette': palette,
            'rows': rows,
        })

    sections_html = []
    for cap in captures:
        bg_class = f'bg-{cap["background"]}'
        has_ref = any(r['reference_svg'] is not None for r in cap['rows'])
        table_rows = []
        for r in cap['rows']:
            if r['reference_svg']:
                full_cell = (
                    f'<div class="comparison-pair">\n'
                    f'  <div class="pair-item">\n'
                    f'    <div class="preview-frame {bg_class}"><img src="{r["reference_svg"]}" width="160" height="160" alt="Approved drawing"></div>\n'
                    f'    <span class="item-caption">approved drawing</span>\n'
                    f'  </div>\n'
                    f'  <div class="pair-item">\n'
                    f'    <div class="preview-frame {bg_class}"><img src="{r["sizes"][160]}" width="160" height="160" alt="Engine"></div>\n'
                    f'    <span class="item-caption">engine</span>\n'
                    f'  </div>\n'
                    f'</div>'
                )
            else:
                img_src = r['sizes'][160] or ''
                full_cell = (
                    f'<div class="preview-box">\n'
                    f'  <div class="preview-frame {bg_class}"><img src="{img_src}" width="160" height="160" alt="Engine"></div>\n'
                    f'  <span class="item-caption">engine</span>\n'
                    f'</div>'
                )

            small_src = r['sizes'][96] or ''
            micro_src = r['sizes'][24] or ''
            table_rows.append(
                f'<tr>\n'
                f'  <td class="mood-cell">{r["mood"]}</td>\n'
                f'  <td>{full_cell}</td>\n'
                f'  <td>\n'
                f'    <div class="preview-box">\n'
                f'      <div class="preview-frame {bg_class}"><img src="{small_src}" width="96" height="96" alt="Small"></div>\n'
                f'      <span class="item-caption">96px</span>\n'
                f'    </div>\n'
                f'  </td>\n'
                f'  <td>\n'
                f'    <div class="preview-box">\n'
                f'      <div class="preview-frame {bg_class}"><img src="{micro_src}" width="24" height="24" alt="Micro"></div>\n'
                f'      <span class="item-caption">24px</span>\n'
                f'    </div>\n'
                f'  </td>\n'
                f'</tr>'
            )

        ref_header = 'Full (160px) &mdash; Approved drawing | Engine' if has_ref else 'Full (160px)'
        section = (
            f'<section class="capture-card">\n'
            f'  <div class="capture-header">\n'
            f'    <div class="badge"><span class="badge-label">Character:</span> <span class="badge-value">{cap["character"]}</span></div>\n'
            f'    <div class="badge"><span class="badge-label">Background:</span> <span class="badge-value">{cap["background"]}</span></div>\n'
            f'    <div class="badge"><span class="badge-label">Palette:</span> <span class="badge-value">{cap["palette"]}</span></div>\n'
            f'    <div class="badge"><span class="badge-label">Capture:</span> <span class="badge-value">{cap["dir_name"]}</span></div>\n'
            f'  </div>\n'
            f'  <table class="grid-table">\n'
            f'    <thead>\n'
            f'      <tr>\n'
            f'        <th>Mood</th>\n'
            f'        <th>{ref_header}</th>\n'
            f'        <th>Small (96px)</th>\n'
            f'        <th>Micro (24px)</th>\n'
            f'      </tr>\n'
            f'    </thead>\n'
            f'    <tbody>\n'
            f'      {"".join(table_rows)}\n'
            f'    </tbody>\n'
            f'  </table>\n'
            f'</section>\n'
        )
        sections_html.append(section)

    html = (
        '<!doctype html>\n'
        '<html lang="en">\n'
        '<head>\n'
        '  <meta charset="utf-8">\n'
        '  <meta name="viewport" content="width=device-width, initial-scale=1">\n'
        '  <title>Mascot Character Live Engine Review</title>\n'
        '  <style>\n'
        '    :root {\n'
        '      --bg-color: #0c100e;\n'
        '      --card-bg: #131a16;\n'
        '      --text-primary: #e6edf3;\n'
        '      --text-secondary: #8b949e;\n'
        '      --border-color: #212c25;\n'
        '      --badge-bg: #1c2721;\n'
        '    }\n'
        '    * { box-sizing: border-box; margin: 0; padding: 0; }\n'
        '    body {\n'
        '      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;\n'
        '      background: var(--bg-color);\n'
        '      color: var(--text-primary);\n'
        '      padding: 2rem;\n'
        '      line-height: 1.5;\n'
        '    }\n'
        '    header {\n'
        '      margin-bottom: 2rem;\n'
        '      border-bottom: 1px solid var(--border-color);\n'
        '      padding-bottom: 1rem;\n'
        '    }\n'
        '    h1 { font-size: 1.75rem; font-weight: 600; margin-bottom: 0.5rem; }\n'
        '    .subtitle { color: var(--text-secondary); font-size: 0.95rem; }\n'
        '    .capture-card {\n'
        '      background: var(--card-bg);\n'
        '      border: 1px solid var(--border-color);\n'
        '      border-radius: 8px;\n'
        '      margin-bottom: 2.5rem;\n'
        '      overflow: hidden;\n'
        '    }\n'
        '    .capture-header {\n'
        '      padding: 1rem 1.5rem;\n'
        '      background: #17211c;\n'
        '      border-bottom: 1px solid var(--border-color);\n'
        '      display: flex;\n'
        '      align-items: center;\n'
        '      gap: 1.25rem;\n'
        '      flex-wrap: wrap;\n'
        '    }\n'
        '    .badge {\n'
        '      display: inline-flex;\n'
        '      align-items: center;\n'
        '      gap: 0.4rem;\n'
        '      background: var(--badge-bg);\n'
        '      border: 1px solid var(--border-color);\n'
        '      padding: 0.25rem 0.6rem;\n'
        '      border-radius: 4px;\n'
        '      font-size: 0.85rem;\n'
        '    }\n'
        '    .badge-label { color: var(--text-secondary); font-weight: 500; }\n'
        '    .badge-value { color: var(--text-primary); font-weight: 600; }\n'
        '    .grid-table {\n'
        '      width: 100%;\n'
        '      border-collapse: collapse;\n'
        '      text-align: center;\n'
        '    }\n'
        '    .grid-table th {\n'
        '      background: #16201a;\n'
        '      padding: 0.75rem 1rem;\n'
        '      font-size: 0.85rem;\n'
        '      font-weight: 600;\n'
        '      color: var(--text-secondary);\n'
        '      border-bottom: 1px solid var(--border-color);\n'
        '      border-right: 1px solid var(--border-color);\n'
        '    }\n'
        '    .grid-table td {\n'
        '      padding: 1.25rem 1rem;\n'
        '      border-bottom: 1px solid var(--border-color);\n'
        '      border-right: 1px solid var(--border-color);\n'
        '      vertical-align: middle;\n'
        '    }\n'
        '    .grid-table th:last-child, .grid-table td:last-child {\n'
        '      border-right: none;\n'
        '    }\n'
        '    .mood-cell {\n'
        '      font-weight: 600;\n'
        '      font-size: 0.95rem;\n'
        '      color: var(--text-primary);\n'
        '      text-transform: capitalize;\n'
        '      text-align: left;\n'
        '      padding-left: 1.5rem !important;\n'
        '      width: 120px;\n'
        '    }\n'
        '    .preview-box {\n'
        '      display: inline-flex;\n'
        '      flex-direction: column;\n'
        '      align-items: center;\n'
        '      gap: 0.4rem;\n'
        '    }\n'
        '    .preview-frame {\n'
        '      display: inline-flex;\n'
        '      align-items: center;\n'
        '      justify-content: center;\n'
        '      border-radius: 4px;\n'
        '      border: 1px solid rgba(128,128,128,0.25);\n'
        '      overflow: hidden;\n'
        '    }\n'
        '    .preview-frame.bg-light { background: #ffffff; }\n'
        '    .preview-frame.bg-dark { background: #16201b; }\n'
        '    .comparison-pair {\n'
        '      display: inline-flex;\n'
        '      align-items: center;\n'
        '      gap: 1.25rem;\n'
        '      justify-content: center;\n'
        '    }\n'
        '    .pair-item {\n'
        '      display: flex;\n'
        '      flex-direction: column;\n'
        '      align-items: center;\n'
        '      gap: 0.4rem;\n'
        '    }\n'
        '    .item-caption {\n'
        '      font-size: 0.75rem;\n'
        '      color: var(--text-secondary);\n'
        '      text-transform: uppercase;\n'
        '      letter-spacing: 0.04em;\n'
        '    }\n'
        '    img { display: block; image-rendering: -webkit-optimize-contrast; }\n'
        '  </style>\n'
        '</head>\n'
        '<body>\n'
        '  <header>\n'
        '    <h1>Mascot Character Live Engine Review</h1>\n'
        '    <p class="subtitle">Format-v1 engine captures across moods, sizes and light/dark backdrops, at the highest pixel density captured.</p>\n'
        '  </header>\n'
        f'  {"".join(sections_html)}\n'
        '</body>\n'
        '</html>\n'
    )
    out_path = Path(output).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(html, encoding='utf-8')
    print(f'SHEET: {out_path}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('capture', 'compare', 'archive', 'probe', 'sheet'))
    parser.add_argument('--output')
    parser.add_argument('--source', default='working-tree')
    parser.add_argument('--profile')
    parser.add_argument('--provisional', action='store_true')
    parser.add_argument('--runtime', action='store_true', default=True, help=argparse.SUPPRESS)
    parser.add_argument('--strict', action='store_true')
    parser.add_argument('--baseline')
    parser.add_argument('--candidate')
    parser.add_argument('--report', help='New directory for all comparison pictures and per-frame metrics')
    parser.add_argument('--archive-file')
    parser.add_argument('--archive-sha256')
    parser.add_argument('--character-file', help='Path to format-v1 character file')
    parser.add_argument('--background', choices=('light', 'dark'), help='Background mode (light or dark)')
    parser.add_argument('--dpr', type=int, choices=(1, 2, 3, 4), help='Capture only this pixel density (review sheets)')
    parser.add_argument('--capture', nargs='+', help='One or more capture directories for sheet')
    parser.add_argument('--reference', help='Directory with reference SVGs for sheet')
    args = parser.parse_args()
    if args.provisional and args.strict:
        parser.error('provisional and strict are mutually exclusive')
    if args.action == 'capture':
        if not args.output or not (args.strict or args.provisional):
            parser.error('capture needs --output and exactly one of --strict/--provisional')
        capture(args.output, args.source, args.profile, args.provisional,
                character_file=args.character_file, background=args.background, dpr=args.dpr)
    elif args.action == 'sheet':
        if not args.capture or not args.output:
            parser.error('sheet needs --capture and --output')
        sheet(args.capture, args.output, args.reference)
    elif args.action == 'compare':
        if not args.baseline or not args.candidate:
            parser.error('compare needs --baseline and --candidate')
        compare(args.baseline, args.candidate, args.strict, args.profile, args.archive_file, args.archive_sha256, args.report)
    elif args.action == 'archive':
        if not args.baseline:
            parser.error('archive needs --baseline')
        archive(args.baseline)
    else:
        if not args.baseline or not (args.strict or args.provisional):
            parser.error('probe needs --baseline and --strict/--provisional')
        with tempfile.TemporaryDirectory(prefix='mascot-defect-') as temporary:
            directory = capture(Path(temporary) / 'defect', args.source, args.profile, args.provisional, defect=True)
            try:
                compare(args.baseline, directory, args.strict, args.profile, args.archive_file, args.archive_sha256)
            except ValueError as error:
                if 'frames differ:' not in str(error):
                    raise
                print(f'PROBE PASS: planted missing eyes detected ({error})')
            else:
                raise ValueError('Planted missing-eye defect was not detected')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        sys.exit(1)
