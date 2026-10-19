"""Packaging invariants; these do not simulate the WoW runtime."""

import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shutil.copytree(ROOT / "RCPArsenal", self.root / "RCPArsenal")
        spec = importlib.util.spec_from_file_location("package", ROOT / "tools/package.py")
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        self.module.ROOT = self.root
        self.module.ADDON = self.root / "RCPArsenal"

    def test_changed_baseline_is_rejected(self):
        core = self.module.ADDON / "Core.lua"
        core.write_bytes(core.read_bytes() + b"\n-- fixture change\n")
        with self.assertRaisesRegex(ValueError, "Baseline payload differs"):
            self.module.collect(True)

    def test_unreviewed_font_is_rejected(self):
        (self.module.ADDON / "fixture.ttf").write_bytes(b"fixture")
        with self.assertRaisesRegex(ValueError, "Unreviewed file type"):
            self.module.collect(False)

    def test_missing_toc_module_is_rejected(self):
        (self.module.ADDON / "UI.lua").unlink()
        with self.assertRaisesRegex(ValueError, "Missing TOC load entry"):
            self.module.collect(False)

    def test_symlink_payload_is_rejected(self):
        (self.module.ADDON / "fixture.lua").symlink_to(ROOT / "tools/package.py")
        with self.assertRaisesRegex(ValueError, "Symlinks"):
            self.module.collect(False)

    def test_repeat_builds_are_identical(self):
        a, b = self.root / "a", self.root / "b"
        for output in (a, b):
            subprocess.run([sys.executable, str(ROOT / "tools/package.py"),
                            "--output-dir", str(output), "--label", "test"],
                           check=True, capture_output=True)
        self.assertEqual(next(a.glob("*.zip")).read_bytes(),
                         next(b.glob("*.zip")).read_bytes())

    def test_incorrect_release_tag_is_rejected(self):
        for tag in ("v999.0.0-alpha", "baseline.1"):
            with self.subTest(tag=tag):
                result = subprocess.run([sys.executable, str(ROOT / "tools/package.py"),
                                         "--release-tag", tag], capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("tag does not match", result.stderr)


if __name__ == "__main__":
    unittest.main()
