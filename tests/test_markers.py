"""Static delivery/binding checks complement the Lua behavior harness."""
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class MarkerDeliveryTests(unittest.TestCase):
    def test_native_binding_header_is_declared_once_and_inherited(self):
        bindings = ET.parse(ROOT / "RCPArsenal/Bindings.xml").getroot()
        headers = [node.attrib["header"] for node in bindings if node.get("header")]
        self.assertEqual(headers, ["RCPARSENAL_MARKERS"],
                         "Declare the shared header once; later bindings inherit it.")
        active_header = None
        for node in bindings:
            active_header = node.get("header", active_header)
            self.assertEqual(active_header, "RCPARSENAL_MARKERS")
        names = [node.attrib["name"] for node in bindings]
        self.assertEqual(len(names), len(set(names)), "Binding commands must be unique.")

    def test_bindings_xml_is_left_to_the_native_auto_loader(self):
        toc_entries = [line.strip().replace("\\", "/").lower()
                       for line in (ROOT / "RCPArsenal/RCPArsenal.toc").read_text().splitlines()
                       if line.strip() and not line.lstrip().startswith("#")]
        self.assertNotIn("bindings.xml", toc_entries)
        for xml in (ROOT / "RCPArsenal").rglob("*.xml"):
            for node in ET.parse(xml).getroot().iter():
                if node.tag.rsplit("}", 1)[-1] == "Include":
                    self.assertNotEqual(node.get("file", "").replace("\\", "/").lower(), "bindings.xml")

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
