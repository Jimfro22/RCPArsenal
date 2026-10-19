"""Asset delivery checks; the separate Lua harness exercises runtime calls."""
from pathlib import Path
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]


class IconDeliveryTests(unittest.TestCase):
    def test_every_theme_media_path_has_exact_case_valid_visible_tga(self):
        source = (ROOT / "RCPArsenal/Theme.lua").read_text()
        media = ROOT / "RCPArsenal/Media"
        names = re.findall(r'Theme\.MediaPath \.\. "([A-Za-z0-9]+)"', source)
        self.assertGreater(len(names), 20)
        for name in names:
            with self.subTest(asset=name):
                path = media / (name + ".tga")
                self.assertIn(path.name, {p.name for p in media.iterdir()})
                data = path.read_bytes()
                header = struct.unpack_from("<BBBHHBHHHHBB", data)
                id_size, color_map, image_type = header[:3]
                width, height, bits, descriptor = header[8:]
                self.assertEqual((color_map, image_type, bits, descriptor & 15), (0, 2, 32, 8))
                self.assertTrue(width > 0 and not (width & (width - 1)))
                self.assertTrue(height > 0 and not (height & (height - 1)))
                pixels = data[18 + id_size:18 + id_size + width * height * 4]
                self.assertEqual(len(pixels), width * height * 4)
                self.assertGreater(max(pixels[3::4]), 0, "Entirely transparent asset")

    def test_actual_icon_call_sites_register_recoverable_refs(self):
        ui = (ROOT / "RCPArsenal/UI.lua").read_text()
        leader = (ROOT / "RCPArsenal/RaidLeader.lua").read_text()
        media = (ROOT / "RCPArsenal/Media.lua").read_text()
        self.assertIn('RA:RegisterSpellIcon(texture, ability.spellID)', ui)
        self.assertIn('SetAbilityIcon(row.icon, ability)', ui)
        self.assertIn('SetAbilityIcon(tile.icon, ability)', ui)
        self.assertIn('RA:RegisterSpellIcon(row.icon, items[i].spellID)', leader)
        self.assertIn('Theme:RegisterAssetTexture(texture, asset, 134400, "LINEAR")', leader)
        self.assertIn('self:RegisterVisualFont(fontString, size, weight, shadow, applied)', media)
        self.assertIn('panicHUDButton.label:SetText("!")', ui)
        self.assertIn('splitButton.left = Font(', leader)
        self.assertIn('splitButton.right = Font(', leader)
        self.assertIn('missingButton.count = Font(', leader)

    def test_asset_broker_cannot_trigger_inspection_or_protected_layout(self):
        source = (ROOT / "RCPArsenal/Assets.lua").read_text()
        self.assertNotRegex(source, r'\b(?:RequestInspectionScan|ScheduleInspectionScan|NotifyInspect|RefreshHUD|SetPoint|SetSize|SetAttribute|CreateFrame)\s*\(')
        self.assertNotIn('OnUpdate', source)
        self.assertIn('result == false', source)
        self.assertIn('SPELL_DATA_LOAD_RESULT', source)


if __name__ == "__main__":
    unittest.main()
