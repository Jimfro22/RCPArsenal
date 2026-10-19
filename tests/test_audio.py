"""User-provided runtime audio integrity; native audibility is not simulated."""
from pathlib import Path
import hashlib
import json
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "RCPArsenal/Media/Audio"
PROVENANCE = ROOT / "provenance/user-alert-audio"


class AudioAssets(unittest.TestCase):
    def test_six_runtime_exports_match_reviewed_hashes_and_vorbis_headers(self):
        rows = json.loads((PROVENANCE / "manifest.json").read_text())["files"]
        expected = {f"RCP_Sound{index:02d}.ogg" for index in range(1, 7)}
        self.assertEqual({p.name for p in MEDIA.glob("*.ogg")}, expected)
        self.assertEqual(len(rows), 6)
        for row in rows:
            path = MEDIA / Path(row["export"]).name
            with self.subTest(file=path.name):
                data = path.read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(), row["sha256"])
                self.assertEqual(len(data), row["bytes"])
                position, packet, packets, granule = 0, bytearray(), [], 0
                while position < len(data):
                    self.assertEqual(data[position:position + 5], b"OggS\x00")
                    count = data[position + 26]
                    sizes = data[position + 27:position + 27 + count]
                    self.assertEqual(len(sizes), count)
                    current = struct.unpack_from("<Q", data, position + 6)[0]
                    if current != 0xffffffffffffffff:
                        granule = current
                    offset = position + 27 + count
                    for size in sizes:
                        chunk = data[offset:offset + size]
                        self.assertEqual(len(chunk), size)
                        packet.extend(chunk)
                        offset += size
                        if size < 255:
                            if len(packets) < 3:
                                packets.append(bytes(packet))
                            packet.clear()
                    position = offset
                self.assertEqual(position, len(data))
                self.assertEqual([p[:7] for p in packets], [b"\x01vorbis", b"\x03vorbis", b"\x05vorbis"])
                self.assertEqual(struct.unpack_from("<IBI", packets[0], 7), (0, 2, 44100))
                self.assertEqual(granule, row["format"]["final_granule_frames"])
                self.assertAlmostEqual(granule / 44100, row["format"]["container_duration_seconds"], places=6)
                self.assertGreater(granule, 0)
                self.assertLess(granule / 44100, 1)

    def test_conversion_record_preserves_source_levels_and_provenance(self):
        manifest = json.loads((PROVENANCE / "manifest.json").read_text())
        self.assertIn("User-provided", manifest["provenance"])
        self.assertTrue(manifest["originals_untouched"])
        self.assertFalse(manifest["gain_or_sound_design_changes"])
        script = PROVENANCE / "prepare_user_audio.py"
        self.assertEqual(hashlib.sha256(script.read_bytes()).hexdigest(), manifest["script_sha256"])
        for row in manifest["files"]:
            with self.subTest(file=row["label"]):
                self.assertTrue(row["source_copy_matches_original"])
                self.assertTrue(row["repeat_encode_byte_identical"])
                self.assertTrue(row["no_filters_trim_or_remix"])
                self.assertEqual(row["gain_db_applied"], 0)
                self.assertEqual(row["export_decoded_levels"]["out_of_range_float_samples"], 0)
                self.assertLess(row["export_decoded_levels"]["peak_dbfs"], 0)
                self.assertLess(abs(row["rms_delta_db"]), .25)
                self.assertIn("libvorbis", row["encode_command"])
                self.assertEqual(row["suggested_destination"], "RCPArsenal/Media/Audio/" + Path(row["export"]).name)

    def test_source_media_is_outside_runtime_payload(self):
        self.assertEqual({p.suffix for p in MEDIA.iterdir()}, {".ogg", ".txt"})
        self.assertIn("owner-provided", (MEDIA / "CREDITS.txt").read_text())


if __name__ == "__main__":
    unittest.main()
