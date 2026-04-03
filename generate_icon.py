#!/usr/bin/env python3
"""Generate Screeny app icons for macOS AppIcon.appiconset."""
import os
import math
from PIL import Image, ImageDraw

def create_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size

    # — Rounded rect background (blue gradient via vertical bands) —
    radius = int(s * 0.225)
    top_color    = (56,  132, 255, 255)
    bottom_color = (15,  72,  204, 255)

    # Draw gradient pixel row by row inside a mask
    mask = Image.new("L", (s, s), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, s - 1, s - 1], radius=radius, fill=255)

    gradient = Image.new("RGBA", (s, s))
    for y in range(s):
        t = y / s
        r = int(top_color[0] * (1 - t) + bottom_color[0] * t)
        g = int(top_color[1] * (1 - t) + bottom_color[1] * t)
        b = int(top_color[2] * (1 - t) + bottom_color[2] * t)
        for x in range(s):
            gradient.putpixel((x, y), (r, g, b, 255))

    img.paste(gradient, mask=mask)

    # — Selection rectangle (semi-transparent white fill) —
    m = int(s * 0.175)
    sel = [m, m, s - m, s - m]
    overlay = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ov_draw = ImageDraw.Draw(overlay)
    ov_draw.rectangle(sel, fill=(255, 255, 255, 26))
    img = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)

    # — Corner L-brackets —
    bl  = int(s * 0.165)   # bracket arm length
    bw  = max(2, int(s * 0.052))  # stroke width
    wht = (255, 255, 255, 242)

    corners = [
        (m, m,     1,  1),
        (s-m, m,  -1,  1),
        (m, s-m,   1, -1),
        (s-m, s-m,-1, -1),
    ]
    for (x, y, hd, vd) in corners:
        # horizontal arm
        draw.line([(x, y), (x + bl * hd, y)], fill=wht, width=bw)
        # vertical arm
        draw.line([(x, y), (x, y + bl * vd)], fill=wht, width=bw)

    # — Center crosshair —
    ch   = int(s * 0.065)
    cx   = s // 2
    cy   = s // 2
    cw   = max(1, int(bw * 0.6))
    wht2 = (255, 255, 255, 204)
    draw.line([(cx - ch, cy), (cx + ch, cy)], fill=wht2, width=cw)
    draw.line([(cx, cy - ch), (cx, cy + ch)], fill=wht2, width=cw)

    # — Center dot —
    dr = max(2, int(bw * 0.55))
    draw.ellipse([cx - dr, cy - dr, cx + dr, cy + dr], fill=(255, 255, 255, 230))

    return img


def main():
    base = os.path.dirname(os.path.abspath(__file__))
    out  = os.path.join(base, "Screeny", "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(out, exist_ok=True)

    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for px in sizes:
        icon = create_icon(px)
        path = os.path.join(out, f"icon_{px}.png")
        icon.save(path, "PNG")
        print(f"✓ icon_{px}.png")

    print(f"\nDone → {out}")


if __name__ == "__main__":
    main()
