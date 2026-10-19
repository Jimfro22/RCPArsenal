"""Asset delivery checks; the separate Lua harness exercises runtime calls."""
from pathlib import Path
import re
import hashlib
import runpy
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
        self.assertIn('RA:SetVisualText(panicHUDButton.label, "!")', ui)
        self.assertIn('splitButton.left = Font(', leader)
        self.assertIn('splitButton.right = Font(', leader)
        self.assertIn('missingButton.count = Font(', leader)

    def test_asset_broker_cannot_trigger_inspection_or_protected_layout(self):
        source = (ROOT / "RCPArsenal/Assets.lua").read_text()
        self.assertNotRegex(source, r'\b(?:RequestInspectionScan|ScheduleInspectionScan|NotifyInspect|RefreshHUD|SetPoint|SetSize|SetAttribute|CreateFrame)\s*\(')
        self.assertNotIn('OnUpdate', source)
        self.assertIn('result == false', source)
        self.assertIn('SPELL_DATA_LOAD_RESULT', source)

    def test_header_logo_is_reproducible_and_preserves_original(self):
        source = ROOT / "RCPArsenal/Media/RCPLogo.tga"
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),
                         "9729123a843bd16ab41a500daf9fdabfcd329958e489bc7e9bc497af1d25a461")
        exporter = runpy.run_path(str(ROOT / "tools/build_header_logo.py"))
        exported = (ROOT / "RCPArsenal/Media/RCPLogoHeader.tga").read_bytes()
        self.assertEqual(exporter["build"](), exported)
        self.assertEqual(struct.unpack_from("<HH", exported, 12), (64, 64))

    def test_optional_fonts_are_resolved_away_from_live_captions(self):
        media = (ROOT / "RCPArsenal/Media.lua").read_text()
        self.assertIn('pcall(CreateFont, "RCPArsenalResolvedFont"', media)
        self.assertIn('NormalizePath(actualPath) == NormalizePath(candidates[i])', media)
        self.assertIn('if ok and actualPath and NormalizePath(actualPath)', media)
        self.assertNotIn('result == true and actualPath', media)
        self.assertNotIn('pcall(fontString.SetFont, fontString, candidates[i]', media)
        assets = (ROOT / "RCPArsenal/Assets.lua").read_text()
        self.assertIn('function RA:SetVisualText(region, text)', assets)
        self.assertNotIn('local text = region:GetText()', assets)


if __name__ == "__main__":
    unittest.main()
