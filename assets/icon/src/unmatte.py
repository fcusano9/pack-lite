"""Recover straight alpha from two composites of the same art.

qlmanage flattens transparency onto a solid background, so rendering the same
SVG on white and on black gives:
    Cw = C*a + 255*(1-a)
    Cb = C*a
Subtracting:  a = 1 - (Cw - Cb)/255,  and  C = Cb / a.
That's exact, including anti-aliased edges, which a chroma-key would fringe.
"""
import struct
import sys
import zlib


def _unfilter(raw, width, height, channels):
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


def read_png(path):
    data = open(path, 'rb').read()
    pos, idat = 8, b''
    width = height = color_type = None
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        chunk = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        if chunk == b'IHDR':
            width, height, depth, color_type = struct.unpack('>IIBB', payload[:10])
            if depth != 8:
                sys.exit(f'{path}: only 8-bit PNGs supported, got {depth}')
        elif chunk == b'IDAT':
            idat += payload
        pos += 12 + length
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color_type]
    return width, height, channels, _unfilter(zlib.decompress(idat), width, height, channels)


def write_rgba_png(path, width, height, pixels):
    raw = bytearray()
    stride = width * 4
    for row in range(height):
        raw.append(0)  # filter: none
        raw += pixels[row * stride:(row + 1) * stride]

    def chunk(tag, payload):
        return (struct.pack('>I', len(payload)) + tag + payload
                + struct.pack('>I', zlib.crc32(tag + payload) & 0xFFFFFFFF))

    out = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
           + chunk(b'IEND', b''))
    open(path, 'wb').write(out)


def main(white_path, black_path, out_path):
    width, height, channels_w, white = read_png(white_path)
    width_b, height_b, channels_b, black = read_png(black_path)
    if (width, height) != (width_b, height_b):
        sys.exit('renders differ in size')

    result = bytearray(width * height * 4)
    opaque = transparent = 0
    for i in range(width * height):
        wr = white[i * channels_w:i * channels_w + 3]
        br = black[i * channels_b:i * channels_b + 3]
        # Average the three channels for a more stable alpha estimate.
        alpha = 0
        for c in range(3):
            alpha += 255 - (wr[c] - br[c])
        alpha = max(0, min(255, alpha // 3))
        if alpha == 0:
            transparent += 1
            result[i * 4:i * 4 + 4] = b'\x00\x00\x00\x00'
            continue
        if alpha == 255:
            opaque += 1
        for c in range(3):
            result[i * 4 + c] = max(0, min(255, (br[c] * 255) // alpha))
        result[i * 4 + 3] = alpha

    write_rgba_png(out_path, width, height, result)
    total = width * height
    print(f'wrote {out_path}  {width}x{height}')
    print(f'  fully transparent: {transparent} px ({100*transparent/total:.1f}%)')
    print(f'  fully opaque:      {opaque} px ({100*opaque/total:.1f}%)')


if __name__ == '__main__':
    main(*sys.argv[1:4])
