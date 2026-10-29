"""Check delivered alpha artwork geometry and deterministic export."""
from pathlib import Path
import math
import runpy
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RadialMaskTests(unittest.TestCase):
    def test_reproducible_white_alpha_masks_and_selection_bounds(self):
        exporter = runpy.run_path(str(ROOT / 'tools/build_radial_masks.py'))
        images = {}
        for name, (size, units, _) in exporter['ASSETS'].items():
            with self.subTest(asset=name):
                actual = (ROOT / 'RCPArsenal/Media' / (name + '.tga')).read_bytes()
                self.assertEqual(actual, exporter['build'](name))
                self.assertEqual(struct.unpack_from('<HHBB', actual, 12), (size,size,32,40))
                pixels = actual[18:]
                self.assertEqual(len(pixels), size*size*4)
                self.assertTrue(all(pixels[i] == 255 for i in range(len(pixels)) if i%4 != 3))
                self.assertEqual(max(pixels[3::4]), 255)
                images[name] = (size, units, pixels)

        def alpha(name, radius, degrees):
            size, units, pixels = images[name]
            angle = math.radians(degrees)
            x = int((.5+math.sin(angle)*radius/units)*size)
            y = int((.5-math.cos(angle)*radius/units)*size)
            return pixels[(y*size+x)*4+3]

        self.assertEqual(alpha('RadialSelection',92,0),255)
        for side in (-1,1):
            self.assertGreater(alpha('RadialSelection',92,side*22),0)
            self.assertEqual(alpha('RadialSelection',92,side*23.5),0)
            self.assertGreater(alpha('RadialSelectionEdge',92,side*22.5),0)
        for radius in (0,27,119,135):
            self.assertEqual(alpha('RadialSelection',radius,0),0)
        self.assertEqual(alpha('RadialSelectionEdge',92,0),0)
        self.assertGreater(alpha('RadialSelectionEdge',116,0),0)


if __name__ == '__main__':
    unittest.main()
