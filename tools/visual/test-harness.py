"""Independent PNG filter/CRC and fail-closed/archive probes; no browser needed."""
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

spec = importlib.util.spec_from_file_location('visual', Path(__file__).with_name('visual-baselines.py'))
visual = importlib.util.module_from_spec(spec)
spec.loader.exec_module(visual)
from visual_report import picture, write_report, png as raw_png


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)


def png(path, colour, filtered):
    header = struct.pack('>IIBBBBB', 2, 2, 8, colour, 0, 0, 0)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(filtered)) + chunk(b'IEND', b''))


class HarnessTests(unittest.TestCase):
    def test_all_rgba_row_filters_have_the_same_independent_pixels(self):
        # Two identical pixels per row, (10,20,30,40). The second row equals the
        # first. These literal encodings follow PNG section9 filter definitions.
        first = bytes([0, 10, 20, 30, 40, 10, 20, 30, 40])
        rows = [bytes([0, 10, 20, 30, 40, 10, 20, 30, 40]),
                bytes([1, 10, 20, 30, 40, 0, 0, 0, 0]), bytes([2, 0, 0, 0, 0, 0, 0, 0, 0]),
                bytes([3, 5, 10, 15, 20, 0, 0, 0, 0]), bytes([4, 0, 0, 0, 0, 0, 0, 0, 0])]
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'case.png'
            for row in rows:
                png(file, 6, first + row)
                self.assertEqual(visual.rgba(file), (2, 2, bytes([10, 20, 30, 40]) * 4))

    def test_rgb_is_expanded_to_opaque_rgba_and_corruption_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'rgb.png'
            png(file, 2, bytes([0, 1, 2, 3, 1, 2, 3]) * 2)
            self.assertEqual(visual.rgba(file)[2], bytes([1, 2, 3, 255]) * 4)
            data = bytearray(file.read_bytes())
            data[40] ^= 1
            file.write_bytes(data)
            with self.assertRaisesRegex(ValueError, 'checksum'):
                visual.rgba(file)

    def test_missing_lock_and_missing_archive_are_errors(self):
        with self.assertRaisesRegex(ValueError, 'Missing canonical'):
            visual.profile_check(None)
        with self.assertRaisesRegex(ValueError, 'Supply the pinned archive'):
            visual.verify_archive(None, None, '.')

    def test_strict_cli_fails_nonzero_without_a_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'must-not-be-created'
            result = subprocess.run([sys.executable, str(Path(__file__).with_name('visual-baselines.py')),
                                     'capture', '--strict', '--output', str(output)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn('Missing canonical profile lock', result.stderr)
            self.assertFalse(output.exists())

    def test_report_counts_a_known_changed_pixel_and_marks_its_exact_location(self):
        old = bytes([10, 20, 30, 255]) * 4
        new = old[:8] + bytes([17, 20, 30, 255]) + old[12:]
        image, metrics = picture(2, 2, old, new)
        self.assertEqual(metrics['changed_pixels'], 1)
        self.assertEqual(metrics['changed_percent'], 25)
        self.assertEqual(metrics['max_channel_delta'], 7)
        self.assertEqual(metrics['bounds_xyxy'], [0, 1, 0, 1])
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'picture.png'
            file.write_bytes(image)
            width, height, pixels = visual.rgba(file)
            self.assertEqual((width, height), (6, 2))
            self.assertEqual(pixels[(6 + 4) * 4:(6 + 5) * 4], bytes([255, 0, 255, 255]))
            self.assertEqual(pixels[(6 + 5) * 4:(6 + 6) * 4], bytes([0, 0, 0, 255]))
        _, same = picture(2, 2, old, old)
        self.assertEqual(same['changed_pixels'], 0)
        self.assertIsNone(same['bounds_xyxy'])

    def test_report_records_all_cases_escapes_metadata_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old, new = root / 'old', root / 'new'
            old.mkdir(); new.mkdir()
            png(old / 'case.png', 6, bytes([0, 10, 20, 30, 255, 10, 20, 30, 255]) * 2)
            png(new / 'case.png', 6, bytes([0, 10, 20, 30, 255, 10, 20, 30, 255]) * 2)
            record = {'files': {'case.png': {}}, 'cases': {'case.png': {'mood': 'idle'}}, 'status': 'provisional-test', 'source': '<script>unsafe</script>'}
            for path in (old, new): (path / 'manifest.json').write_text('{}')
            output = root / 'report'
            result = write_report(output, old, new, record, record, visual.rgba)
            self.assertEqual(result['frames'], 1)
            self.assertEqual(result['different_frames'], 0)
            self.assertEqual(json.loads((output / 'results.json').read_text())['results'][0]['changed_pixels'], 0)
            self.assertTrue((output / 'case.png').is_file())
            self.assertIn('&lt;script&gt;unsafe', (output / 'index.html').read_text())
            with self.assertRaisesRegex(ValueError, 'never overwrite'):
                write_report(output, old, new, record, record, visual.rgba)

    def test_compare_rejects_manifest_with_four_moods(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            baseline, candidate = root / 'old', root / 'new'
            baseline.mkdir()
            candidate.mkdir()
            four_moods = ['idle', 'thinking', 'happy', 'worried']
            record_bad = {
                'profile': {'moods': four_moods},
                'runtime': {},
                'files': {},
                'cases': {},
                'source': 'test',
                'status': 'provisional-test',
            }
            record_good = {
                'profile': {'moods': ['idle', 'thinking', 'happy', 'worried', 'celebrating']},
                'runtime': {},
                'files': {},
                'cases': {},
                'source': 'test',
                'status': 'provisional-test',
            }
            visual.write_json(baseline / 'manifest.json', record_bad)
            visual.write_json(candidate / 'manifest.json', record_bad)
            with self.assertRaisesRegex(ValueError, 'core moods'):
                visual.compare(baseline, candidate)
            visual.write_json(baseline / 'manifest.json', record_good)
            with self.assertRaisesRegex(ValueError, 'core moods'):
                visual.compare(baseline, candidate)

    def test_comparison_failure_stays_nonzero_with_pictures_and_bad_environments_make_no_report(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            baseline, candidate = root / 'old', root / 'new'
            baseline.mkdir(); candidate.mkdir()
            moods = ['idle', 'thinking', 'happy', 'worried', 'celebrating']
            record = {'profile': {'moods': moods}, 'runtime': {}, 'files': {}, 'cases': {}, 'source': 'test', 'status': 'provisional-test'}
            for mood in moods:
                for mode in ('light', 'dark'):
                    for size in (160, 96, 24):
                        for dpr in (1, 2):
                            name = f'tessa-{mood}-{mode}-{size}-dpr{dpr}.png'
                            dimension = size * dpr
                            pixels = bytes([255, 255, 255, 255]) * dimension * dimension
                            image = raw_png(dimension, dimension, pixels)
                            for path in (baseline, candidate): (path / name).write_bytes(image)
                            record['files'][name] = {'png_sha256': visual.sha(image), 'rgba_sha256': visual.sha(pixels)}
                            record['cases'][name] = {'mood': mood, 'mode': mode, 'size': size, 'dpr': dpr, 'frame': 0}
            visual.write_json(baseline / 'manifest.json', record)
            name = 'tessa-idle-light-24-dpr1.png'
            pixels = bytes([128, 255, 255, 255]) + bytes([255, 255, 255, 255]) * (24 * 24 - 1)
            image = raw_png(24, 24, pixels)
            (candidate / name).write_bytes(image)
            record['files'][name] = {'png_sha256': visual.sha(image), 'rgba_sha256': visual.sha(pixels)}
            visual.write_json(candidate / 'manifest.json', record)
            with self.assertRaisesRegex(ValueError, '1/60 frames differ'):
                visual.compare(baseline, candidate, report=root / 'report')
            result = json.loads((root / 'report/results.json').read_text())
            self.assertEqual(result['different_frames'], 1)
            row = next(x for x in result['results'] if x['changed_pixels'])
            self.assertEqual(row['changed_pixels'], 1)
            self.assertTrue((root / 'report' / row['detail_picture']).is_file())
            record['runtime'] = {'different': True}
            visual.write_json(candidate / 'manifest.json', record)
            with self.assertRaisesRegex(ValueError, 'Different capture environments'):
                visual.compare(baseline, candidate, report=root / 'blocked')
            self.assertFalse((root / 'blocked').exists())

    def test_archives_are_reproducible_and_must_match_supplied_images(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'frames'
            source.mkdir()
            (source / 'manifest.json').write_text('{}\n')
            visual.archive(source)
            archive = next(Path(directory).glob('*.tar.gz'))
            digest = visual.sha(archive.read_bytes())
            visual.archive(source)
            self.assertEqual(len(list(Path(directory).glob('*.tar.gz'))), 1)
            visual.verify_archive(archive, digest, source)
            (source / 'manifest.json').write_text('{"changed":true}\n')
            with self.assertRaisesRegex(ValueError, 'member differs'):
                visual.verify_archive(archive, digest, source)
            with self.assertRaisesRegex(ValueError, 'checksum differs'):
                visual.verify_archive(archive, '0' * 64, source)


if __name__ == '__main__':
    unittest.main()
