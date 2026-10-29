#!/usr/bin/env python3
"""Build white alpha artwork for the approved 282-unit marker wheel.

Geometry follows the October 29 radial-polish visual spec and its north wedge
SVG: annulus 30..116, selected boundaries +/-22.5 degrees, neutral half-angle
21.9 degrees. Native marker icons are not inputs or outputs of this exporter.
All colors are supplied by the running theme. Transparent RGB stays white to
avoid a dark fringe under linear filtering. No imaging dependency is needed.
"""
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "RCPArsenal/Media"
HALF_ANGLE = math.pi / 8
INNER, OUTER = 30, 116
SAMPLES = 4


def wedge(x, y, half_angle=HALF_ANGLE):
    return INNER <= math.hypot(x, y) <= OUTER and abs(math.atan2(x, -y)) <= half_angle


def edge(x, y):
    radius = math.hypot(x, y)
    angle = abs(math.atan2(x, -y))
    # The centered 1.25-unit stroke matches the reviewed SVG, including both
    # radial edges and both arcs. Closest endpoint handles the four corners.
    arc_angle = min(angle, HALF_ANGLE)
    arc = min(math.hypot(x-sign*math.sin(arc_angle)*r, y+math.cos(arc_angle)*r)
              for r in (INNER, OUTER) for sign in (-1, 1))
    projected = max(INNER, min(OUTER, radius*math.cos(angle-HALF_ANGLE)))
    side = math.hypot(abs(x)-math.sin(HALF_ANGLE)*projected,
                      y+math.cos(HALF_ANGLE)*projected)
    return min(arc, side) <= .625


def chevron(x, y):
    # Exact selected SVG vertices translated from (141,97.107) to (0,0).
    vertices = ((-4.077, 5.107), (0, -5.107), (4.077, 5.107), (0, 1.893))
    inside = False
    for i, (ax, ay) in enumerate(vertices):
        bx, by = vertices[i-1]
        if (ay > y) != (by > y) and x < (bx-ax)*(y-ay)/(by-ay)+ax:
            inside = not inside
    return inside


ASSETS = {
    "RadialSector": (256, 282, lambda x,y: wedge(x,y,math.radians(21.9))),
    "RadialSelection": (256, 282, wedge),
    "RadialSelectionEdge": (256, 282, edge),
    "RadialChevron": (32, 32, chevron),
    "RadialHub": (64, 56.02, lambda x,y: math.hypot(x,y) <= 28.01),
    "RadialHubBorder": (64, 56.02, lambda x,y: 27.01 <= math.hypot(x,y) <= 28.01),
}


def build(name):
    size, units, shape = ASSETS[name]
    pixels = bytearray()
    for py in range(size):
        for px in range(size):
            hits = sum(shape(((px+(sx+.5)/SAMPLES)/size-.5)*units,
                             ((py+(sy+.5)/SAMPLES)/size-.5)*units)
                       for sy in range(SAMPLES) for sx in range(SAMPLES))
            pixels.extend((255,255,255,round(hits*255/(SAMPLES*SAMPLES))))
    return struct.pack('<BBBHHBHHHHBB',0,0,2,0,0,0,0,0,size,size,32,40)+pixels


if __name__ == '__main__':
    for asset in ASSETS:
        path = MEDIA / (asset + '.tga')
        path.write_bytes(build(asset))
        print(path.relative_to(ROOT))
