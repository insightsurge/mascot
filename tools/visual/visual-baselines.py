#!/usr/bin/env python3
"""Explicit captures and exact decoded-pixel checks; excluded from the R package."""
import argparse
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
FILES = {'mascot.js': 'inst/www/mascot.js', 'mascot-draw.js': 'inst/www/mascot-draw.js',
         'tessa.json': 'inst/characters/tessa.json'}


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


def capture(output, source, lock=None, provisional=False, defect=False, adapter=False):
    profile = read_json(TEMPLATE) if provisional else profile_check(lock)
    output = Path(output).resolve()
    if output.exists():
        raise ValueError('Output already exists; captures never overwrite baselines')
    output.mkdir(parents=True)
    source_sha = git('rev-parse', 'HEAD' if source == 'working-tree' else f'{source}^{{commit}}').decode().strip()
    source_label = ('working-tree:' if source == 'working-tree' else '') + source_sha
    with tempfile.TemporaryDirectory(prefix='mascot-visual-') as work:
        work = Path(work)
        hashes = {}
        files = dict(FILES)
        if adapter:
            files.update({name: 'inst/www/' + name for name in ('mascot-parts.js', 'mascot-geometry.js', 'mascot-tessa-adapter.js')})
        for name, file in files.items():
            data = (ROOT / file).read_bytes() if source == 'working-tree' else git('show', f'{source_sha}:{file}')
            hashes[file] = sha(data)
            if defect and name == 'mascot-draw.js':
                needle = b'drawEyes(g, face, p);'
                if data.count(needle) != 1:
                    raise ValueError('Missing-eye probe insertion point changed')
                data = data.replace(needle, b'/* planted defect: eyes omitted */')
            (work / name).write_bytes(data)
        config = {'source': str(work), 'output': str(output), 'flags': profile['flags'],
                  'chrome': None if provisional else profile['chrome'],
                  'chromote': None if provisional else profile['chromote'], 'adapter': adapter}
        write_json(work / 'config.json', config)
        env = dict(os.environ, RENV_CONFIG_AUTOLOADER_ENABLED='FALSE')
        subprocess.run(['Rscript', str(Path(__file__).with_name('capture.R')), str(work / 'config.json')],
                       env=env, check=True, cwd=ROOT)
    record = read_json(output / 'capture.json')
    record['runtime']['chrome_sha256'] = sha(Path(record['runtime'].pop('chrome_path')).read_bytes())
    manifest = {'status': 'provisional-macos' if provisional else 'canonical',
                'source': source_label, 'source_files': hashes, 'adapter': adapter, 'defect': 'missing-eyes' if defect else None,
                'profile': profile, 'profile_sha256': None if provisional else sha(Path(lock).read_bytes()),
                **record, 'files': {}}
    if provisional:
        manifest['status'] = 'provisional-' + platform.system().lower()
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
    if strict:
        verify_archive(archive_file, archive_sha256, baseline)
        profile_check(lock)
        for record in (old, new):
            if record['status'] != 'canonical' or record['profile_sha256'] != sha(Path(lock).read_bytes()):
                raise ValueError('Missing/different canonical profile; provisional captures are never accepted')
    if old['profile'] != new['profile'] or old['runtime'] != new['runtime']:
        raise ValueError('Different capture environments; review/rebaseline explicitly')
    expected = {f'tessa-{m}-{mode}-{size}-dpr{dpr}.png' for m in old['profile']['moods']
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('capture', 'compare', 'archive', 'probe'))
    parser.add_argument('--output')
    parser.add_argument('--source', default='ace06f5')
    parser.add_argument('--profile')
    parser.add_argument('--provisional', action='store_true')
    parser.add_argument('--adapter', action='store_true')
    parser.add_argument('--strict', action='store_true')
    parser.add_argument('--baseline')
    parser.add_argument('--candidate')
    parser.add_argument('--report', help='New directory for all comparison pictures and per-frame metrics')
    parser.add_argument('--archive-file')
    parser.add_argument('--archive-sha256')
    args = parser.parse_args()
    if args.provisional and args.strict:
        parser.error('provisional and strict are mutually exclusive')
    if args.action == 'capture':
        if not args.output or not (args.strict or args.provisional):
            parser.error('capture needs --output and exactly one of --strict/--provisional')
        capture(args.output, args.source, args.profile, args.provisional, adapter=args.adapter)
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
