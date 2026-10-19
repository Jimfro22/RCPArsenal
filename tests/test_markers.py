"""Static delivery/binding checks complement the Lua behavior harness."""
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class MarkerDeliveryTests(unittest.TestCase):
    def test_native_bindings_have_no_insecure_lua_body(self):
        bindings = ET.parse(ROOT / "RCPArsenal/Bindings.xml").getroot()
        self.assertEqual(bindings.tag, "Bindings")
        names = {node.attrib["name"] for node in bindings}
        self.assertEqual(names, {
            "CLICK RCPArsenalWorldMarkerCycle:LeftButton",
            "CLICK RCPArsenalWorldMarkerClear:LeftButton",
        })
        for node in bindings:
            self.assertFalse((node.text or "").strip())
        source = (ROOT / "RCPArsenal/WorldMarkers.lua").read_text()
        for name in names:
            self.assertIn('"' + name + '"', source)
        self.assertNotRegex(source, r"\b(?:SetBinding\w*|SaveBindings|SetOverrideBinding\w*|ClearOverrideBindings)\s*\(")

    def test_module_loads_before_ui_and_import_excludes_marker_fields(self):
        toc = (ROOT / "RCPArsenal/RCPArsenal.toc").read_text().splitlines()
        self.assertLess(toc.index("WorldMarkers.lua"), toc.index("Config.lua"))
        profile_io = (ROOT / "RCPArsenal/ProfileIO.lua").read_text()
        self.assertNotIn('"worldMarkers', profile_io)

    def test_no_reserved_modified_macro_attributes_in_sequence_storage(self):
        source = (ROOT / "RCPArsenal/WorldMarkers.lua").read_text()
        self.assertNotRegex(source, r'SetAttribute\("macro"\s*\.\.')
        self.assertNotRegex(source, r'SetAttribute\("macro[1-8]"')
        self.assertIn('"rcp-sequence-macro-"', source)


if __name__ == "__main__":
    unittest.main()
