#!/usr/bin/env python3
"""Build every app-icon PNG from the single source SVG.

    python3 assets/icon/src/build_icons.py
    dart run flutter_launcher_icons

Writes three files into assets/icon/:

    icon.png             full-bleed master  -> iOS + Play listing + legacy Android
    icon_background.png  cobalt gradient    -> Android adaptive background layer
    icon_foreground.png  art on transparent -> Android adaptive foreground layer

Why this is a script rather than four checked-in SVGs
-----------------------------------------------------
There is no SVG rasteriser on this machine — no ImageMagick, no librsvg, no
Pillow. The only option is macOS `qlmanage`, which flattens transparency onto
white. Feeding that straight in would make the adaptive foreground an opaque
white square.

Rendering the same art twice, on white and on black, makes alpha exactly
solvable:

    Cw = C*a + 255*(1 - a)      (composited on white)
    Cb = C*a                    (composited on black)
      =>  a = 1 - (Cw - Cb)/255
      =>  C = Cb / a

That is exact including anti-aliased edges, unlike a chroma-key which leaves
coloured fringes. Everything here is stdlib, so there is nothing to install.
"""
from __future__ import annotations

import shutil
import struct
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ElementTree
import zlib
from pathlib import Path

SVG_NS = 'http://www.w3.org/2000/svg'
SRC = Path(__file__).resolve().parent
OUT = SRC.parent


# ---- SVG variants -----------------------------------------------------------

def _variant(backdrop_fill: str | None, keep_art: bool) -> bytes:
    """Re-emit the source SVG with the backdrop recoloured and/or art removed."""
    ElementTree.register_namespace('', SVG_NS)
    tree = ElementTree.parse(SRC / 'icon.svg')
    root = tree.getroot()

    backdrop = root.find(f'.//{{{SVG_NS}}}rect[@id="backdrop"]')
    art = root.find(f'.//{{{SVG_NS}}}g[@id="art"]')
    if backdrop is None or art is None:
        sys.exit('icon.svg must keep the ids "backdrop" and "art" — see its header comment.')

    if backdrop_fill is not None:
        backdrop.set('fill', backdrop_fill)
    if not keep_art:
        root.remove(art)

    return ElementTree.tostring(root, encoding='utf-8')


# ---- PNG ---------------------------------------------------------------------

def _unfilter(raw: bytes, width: int, height: int, channels: int) -> bytearray:
    stride = width * channels
    out = bytearray(stride * height)
    previous = bytearray(stride)
    pos = 0
    for row in range(height):
        filter_type = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if filter_type == 1:
            for x in range(channels, stride):
                line[x] = (line[x] + line[x - channels]) & 255
        elif filter_type == 2:
            for x in range(stride):
                line[x] = (line[x] + previous[x]) & 255
        elif filter_type == 3:
            for x in range(stride):
                left = line[x - channels] if x >= channels else 0
                line[x] = (line[x] + ((left + previous[x]) >> 1)) & 255
        elif filter_type == 4:
            for x in range(stride):
                left = line[x - channels] if x >= channels else 0
                up = previous[x]
                upleft = previous[x - channels] if x >= channels else 0
                estimate = left + up - upleft
                da, db, dc = (abs(estimate - left), abs(estimate - up),
                              abs(estimate - upleft))
                if da <= db and da <= dc:
                    predictor = left
                elif db <= dc:
                    predictor = up
                else:
                    predictor = upleft
                line[x] = (line[x] + predictor) & 255
        out[row * stride:(row + 1) * stride] = line
        previous = line
    return out


def read_png(path: Path):
    data = path.read_bytes()
    pos, idat = 8, b''
    width = height = color_type = None
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        if tag == b'IHDR':
            width, height, depth, color_type = struct.unpack('>IIBB', payload[:10])
            if depth != 8:
                sys.exit(f'{path}: expected 8-bit PNG, got {depth}-bit')
        elif tag == b'IDAT':
            idat += payload
        pos += 12 + length
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color_type]
    return width, height, channels, _unfilter(zlib.decompress(idat), width, height, channels)


def write_rgba_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
    stride = width * 4
    raw = bytearray()
    for row in range(height):
        raw.append(0)  # filter: none
        raw += pixels[row * stride:(row + 1) * stride]

    def chunk(tag: bytes, payload: bytes) -> bytes:
        return (struct.pack('>I', len(payload)) + tag + payload
                + struct.pack('>I', zlib.crc32(tag + payload) & 0xFFFFFFFF))

    path.write_bytes(b'\x89PNG\r\n\x1a\n'
                     + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
                     + chunk(b'IEND', b''))


# ---- pipeline ---------------------------------------------------------------

def rasterise(svg: bytes, work: Path, name: str) -> Path:
    svg_path = work / f'{name}.svg'
    svg_path.write_bytes(svg)
    subprocess.run(['qlmanage', '-t', '-s', '1024', '-o', str(work), str(svg_path)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    png = work / f'{name}.svg.png'
    if not png.exists():
        sys.exit(f'qlmanage produced no output for {name}.svg')
    return png


def unmatte(white_path: Path, black_path: Path, out_path: Path) -> None:
    width, height, cw, white = read_png(white_path)
    width_b, height_b, cb, black = read_png(black_path)
    if (width, height) != (width_b, height_b):
        sys.exit('white and black renders differ in size')

    pixels = bytearray(width * height * 4)
    transparent = 0
    for i in range(width * height):
        wp = white[i * cw:i * cw + 3]
        bp = black[i * cb:i * cb + 3]
        alpha = sum(255 - (wp[c] - bp[c]) for c in range(3)) // 3
        alpha = max(0, min(255, alpha))
        if alpha == 0:
            transparent += 1
            continue  # already zeroed
        for c in range(3):
            pixels[i * 4 + c] = max(0, min(255, (bp[c] * 255) // alpha))
        pixels[i * 4 + 3] = alpha

    write_rgba_png(out_path, width, height, pixels)
    print(f'  {out_path.name}  ({100 * transparent / (width * height):.0f}% transparent)')


def main() -> None:
    if not shutil.which('qlmanage'):
        sys.exit('qlmanage not found — this build only runs on macOS.')

    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)

        # Master and adaptive background are opaque, so a single render each.
        for name, svg, dest in (
            ('master', _variant(None, keep_art=True), OUT / 'icon.png'),
            ('background', _variant(None, keep_art=False), OUT / 'icon_background.png'),
        ):
            shutil.copy(rasterise(svg, work, name), dest)
            print(f'  {dest.name}')

        # The foreground needs real transparency, so render twice and solve.
        # NOTE: do not scale the art here — ic_launcher.xml already applies a
        # 16% inset, and scaling as well compounds the two (see README).
        white = rasterise(_variant('#FFFFFF', keep_art=True), work, 'fg_white')
        black = rasterise(_variant('#000000', keep_art=True), work, 'fg_black')
        unmatte(white, black, OUT / 'icon_foreground.png')

    print('\nNow run:  dart run flutter_launcher_icons')


if __name__ == '__main__':
    main()
