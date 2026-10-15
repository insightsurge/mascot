"""Independent PNG filter/CRC and fail-closed/archive probes; no browser needed."""
import importlib.util
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
