#!/usr/bin/env python3
"""Export the existing RP artwork for its 42-unit header use, using stdlib only.

Keep RCPLogo.tga unchanged. Prefilter its exact interior to 64px with premultiplied
coverage; hint the same six-point outline to a consistent 1.25px at this size.
The stroke's color stops come from the original border. Transparent RGB bleeds
prevent a black fringe when WoW linearly samples this straight-alpha texture.
"""
import hashlib
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'RCPArsenal/Media/RCPLogo.tga'
TARGET = ROOT / 'RCPArsenal/Media/RCPLogoHeader.tga'
SOURCE_SHA256 = '9729123a843bd16ab41a500daf9fdabfcd329958e489bc7e9bc497af1d25a461'
SIZE = 64
# Original contour, not a new logo silhouette. RP glyphs/check remain raster-exact.
VERTICES = ((128, 16), (224, 72), (224, 184), (128, 240), (32, 184), (32, 72))
COLOR_SAMPLES = ((128, 16), (223, 72), (223, 183), (128, 239), (32, 183), (32, 72))


def read_source():
    data = SOURCE.read_bytes()
    if hashlib.sha256(data).hexdigest() != SOURCE_SHA256:
        raise ValueError('Original RP artwork changed; review its small-size export.')
    h = struct.unpack_from('<BBBHHBHHHHBB', data)
    if (h[1], h[2], h[8], h[9], h[10]) != (0, 2, 256, 256, 32):
        raise ValueError('Expected original uncompressed 256px RGBA TGA.')
    raw = data[18+h[0]:18+h[0]+256*256*4]
    rows = [[(raw[i+2], raw[i+1], raw[i], raw[i+3])
             for i in range(y*256*4, (y+1)*256*4, 4)] for y in range(256)]
    if not h[11] & 32:
        rows.reverse()
    return rows


def closest_edge(x, y):
    result = (1e9, 0, 0)
    for i, (ax, ay) in enumerate(VERTICES):
        bx, by = VERTICES[(i+1) % 6]
        ax, ay, bx, by = ax/4, ay/4, bx/4, by/4
        dx, dy = bx-ax, by-ay
        t = max(0, min(1, ((x-ax)*dx+(y-ay)*dy)/(dx*dx+dy*dy)))
        distance = math.hypot(x-ax-t*dx, y-ay-t*dy)
        if distance < result[0]:
            result = (distance, i, t)
    return result


def build():
    source = read_source()
    colors = tuple(source[y][x][:3] for x,y in COLOR_SAMPLES)
    pixels = []
    for y in range(SIZE):
        for x in range(SIZE):
            block = [source[sy][sx] for sy in range(y*4, y*4+4)
                     for sx in range(x*4, x*4+4)]
            weight = sum(p[3] for p in block)
            base_alpha = weight/(16*255)
            base = [sum(p[c]*p[3] for p in block)/weight if weight else 0 for c in range(3)]
            distance, edge, t = closest_edge(x+.5, y+.5)
            coverage = 0
            if distance < 1.5:
                coverage = sum(closest_edge(x+(sx+.5)/8, y+(sy+.5)/8)[0] <= .625
                               for sy in range(8) for sx in range(8))/64
            color = [colors[edge][c]*(1-t)+colors[(edge+1) % 6][c]*t for c in range(3)]
            alpha = coverage+base_alpha*(1-coverage)
            rgb = [round((color[c]*coverage+base[c]*base_alpha*(1-coverage))/alpha)
                   if alpha else 0 for c in range(3)]
            pixels.append(tuple(rgb)+(round(alpha*255),))
    # RGB-only extrusion leaves the visible bounds/coverage unchanged.
    for _ in range(2):
        updated = pixels[:]
        for y in range(SIZE):
            for x in range(SIZE):
                i = y*SIZE+x
                if pixels[i][3] or any(pixels[i][:3]):
                    continue
                neighbors = [pixels[ny*SIZE+nx] for ny in range(max(0,y-1),min(SIZE,y+2))
                             for nx in range(max(0,x-1),min(SIZE,x+2)) if any(pixels[ny*SIZE+nx][:3])]
                if neighbors:
                    updated[i] = tuple(round(sum(p[c] for p in neighbors)/len(neighbors)) for c in range(3))+(0,)
        pixels = updated
    header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 40)
    return header+bytes(value for r,g,b,a in pixels for value in (b,g,r,a))


if __name__ == '__main__':
    result = build()
    TARGET.write_bytes(result)
    print(f'{TARGET.relative_to(ROOT)}: {SIZE}x{SIZE}, sha256 {hashlib.sha256(result).hexdigest()}')
