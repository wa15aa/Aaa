#!/usr/bin/env python3
"""compose_asc.py — 把 1170x2532 模拟器截图合成 1290x2796 ASC 截图（顶部差异化 caption）。

用法: python3 tools/compose_asc.py <in.png> <out.png> <line1> [line2]
版式参数量自 2026-09-18 已验收的 appstore/01_today_asc.png。
"""
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 1290, 2796
BG = (247, 247, 250)
FONT = "/System/Library/Fonts/Helvetica.ttc"
FONT_SIZE = 100          # index 1 = Bold（0=Regular 2=Oblique）
CAPTION_TOP = 150
LINE_GAP = 130
SHOT_X, SHOT_Y = 60, 470


def main():
    src, dst = sys.argv[1], sys.argv[2]
    lines = [l for l in sys.argv[3:] if l]
    canvas = Image.new("RGB", (W, H), BG)
    shot = Image.open(src).convert("RGB")
    assert shot.size == (1170, 2532), shot.size
    canvas.paste(shot, (SHOT_X, SHOT_Y))
    d = ImageDraw.Draw(canvas)
    size = FONT_SIZE
    font = ImageFont.truetype(FONT, size, index=1)
    # 自动缩字号防裁切：最长行超出 W-80 就按比缩小
    longest = max((d.textlength(l, font=font) for l in lines), default=0)
    if longest > W - 80:
        size = int(size * (W - 80) / longest)
        font = ImageFont.truetype(FONT, size, index=1)
    for i, line in enumerate(lines):
        w = d.textlength(line, font=font)
        d.text(((W - w) / 2, CAPTION_TOP + i * LINE_GAP), line, font=font, fill=(20, 20, 22))
    canvas.save(dst)
    print("wrote", dst)


if __name__ == "__main__":
    main()
