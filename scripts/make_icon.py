#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 1024x1024 的 App 图标。

只使用 Python 标准库（math / struct / zlib），不依赖 Pillow，
所以 GitHub Actions 的 macOS 机器上直接就能跑。

用法： python3 make_icon.py 输出路径.png
"""

import math
import os
import struct
import sys
import zlib

SIZE = 1024

BG_TOP = (47.0, 107.0, 255.0)
BG_BOTTOM = (11.0, 16.0, 48.0)

PAGE = (253.0, 253.0, 255.0)
ACCENT = (47.0, 107.0, 255.0)
LINE = (198.0, 211.0, 232.0)
CURSOR = (33.0, 208.0, 122.0)

# (left, top, right, bottom, radius, color)
SHAPES = [
    (252.0, 168.0, 772.0, 856.0, 74.0, PAGE),
    (320.0, 268.0, 520.0, 312.0, 22.0, ACCENT),
    (320.0, 356.0, 700.0, 388.0, 16.0, LINE),
    (320.0, 436.0, 700.0, 468.0, 16.0, LINE),
    (320.0, 516.0, 620.0, 548.0, 16.0, LINE),
    (320.0, 596.0, 560.0, 628.0, 16.0, LINE),
    (636.0, 512.0, 650.0, 552.0, 7.0, CURSOR),
]


def rounded_rect_sdf(px, py, left, top, right, bottom, radius):
    """圆角矩形的有符号距离，用来做 1px 抗锯齿。"""
    cx = (left + right) * 0.5
    cy = (top + bottom) * 0.5
    hw = (right - left) * 0.5
    hh = (bottom - top) * 0.5
    dx = abs(px - cx) - (hw - radius)
    dy = abs(py - cy) - (hh - radius)
    ox = dx if dx > 0.0 else 0.0
    oy = dy if dy > 0.0 else 0.0
    return math.hypot(ox, oy) + min(max(dx, dy), 0.0) - radius


def build_pixels():
    pixels = bytearray(SIZE * SIZE * 3)
    clamp_hi = 255.0
    for y in range(SIZE):
        py = y + 0.5
        t = y / float(SIZE - 1)
        br = BG_TOP[0] + (BG_BOTTOM[0] - BG_TOP[0]) * t
        bg = BG_TOP[1] + (BG_BOTTOM[1] - BG_TOP[1]) * t
        bb = BG_TOP[2] + (BG_BOTTOM[2] - BG_TOP[2]) * t
        row = y * SIZE * 3
        for x in range(SIZE):
            px = x + 0.5
            r, g, b = br, bg, bb
            for (left, top, right, bottom, radius, color) in SHAPES:
                if px < left - 2.0 or px > right + 2.0 or py < top - 2.0 or py > bottom + 2.0:
                    continue
                sdf = rounded_rect_sdf(px, py, left, top, right, bottom, radius)
                alpha = 0.5 - sdf
                if alpha <= 0.0:
                    continue
                if alpha > 1.0:
                    alpha = 1.0
                r += (color[0] - r) * alpha
                g += (color[1] - g) * alpha
                b += (color[2] - b) * alpha
            i = row + x * 3
            pixels[i] = int(min(max(r, 0.0), clamp_hi))
            pixels[i + 1] = int(min(max(g, 0.0), clamp_hi))
            pixels[i + 2] = int(min(max(b, 0.0), clamp_hi))
    return pixels


def write_png(path, pixels):
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)  # filter type 0
        start = y * SIZE * 3
        raw.extend(pixels[start:start + SIZE * 3])

    def chunk(tag, data):
        body = tag + data
        return (struct.pack(">I", len(data)) + body
                + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF))

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", header)
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as handle:
        handle.write(png)


def main():
    if len(sys.argv) < 2:
        print("用法: python3 make_icon.py 输出路径.png")
        return 1
    out = sys.argv[1]
    folder = os.path.dirname(os.path.abspath(out))
    if folder and not os.path.isdir(folder):
        os.makedirs(folder, exist_ok=True)
    write_png(out, build_pixels())
    print("icon written: %s (%d bytes)" % (out, os.path.getsize(out)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
