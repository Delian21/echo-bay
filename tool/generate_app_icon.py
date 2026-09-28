"""Generates the Echo Bay app icon: a hand-drawn chalk 'E' on sepia paper.

Draws with jittered strokes + a chalk double-pass so it matches the app's
'Golden Hour, Inked' sketch kit, then writes app_icon.ico (16..256) for the
Windows runner.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

SEED = 7919
rng = random.Random(SEED)

# Sepia paper + charcoal ink (the sketch kit's constants).
PAPER = (245, 239, 226)
PAPER_EDGE = (231, 220, 196)
INK = (43, 42, 38)

def jitter(x, y, wobble):
    return (x + (rng.random() - 0.5) * 2 * wobble,
            y + (rng.random() - 0.5) * 2 * wobble)

def chalk_stroke(draw, pts, width, alpha=255):
    """Draw a polyline with round caps in two passes (chalk double-pass)."""
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        draw.line([x1, y1, x2, y2], fill=INK + (alpha,), width=width)
        # Round caps via circles at joints.
        r = width / 2
        draw.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], fill=INK + (alpha,))
        draw.ellipse([x2 - r, y2 - r, x2 + r, y2 + r], fill=INK + (alpha,))

def draw_e(size):
    """Draw the chalk E onto an RGBA canvas of [size] px."""
    s = 4  # supersample factor for crisp downscale
    big = size * s
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Sepia paper disc with a slightly darker rim (uneven, hand-cut).
    cx = cy = big / 2
    R = big / 2 - big * 0.02
    # Paper: sampled disc (two-tone edge).
    for r in range(int(R), 0, -1):
        t = r / R
        col = PAPER_EDGE if t > 0.94 else PAPER
        # Per-pixel angular wobble on the rim only.
        if t > 0.94 and rng.random() < 0.4:
            col = PAPER
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (255,))

    scale = big / 24.0
    W = 2.1 * scale  # main stroke width

    # The E: spine + three arms, each a jittered polyline, plus a lighter
    # offset ghost pass (the chalk caught the slate twice).
    def arm(x1, y1, x2, y2, wobble=1.0):
        n = 8
        pts = [jitter(x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n, wobble * scale * 0.5)
               for i in range(n + 1)]
        chalk_stroke(d, pts, int(W), 255)
        # Ghost pass: thinner, translucent, differently jittered.
        ghost = [jitter(x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n, wobble * scale * 0.7)
                 for i in range(n + 1)]
        chalk_stroke(d, ghost, max(2, int(W * 0.5)), 90)

    arm(9, 5, 9, 19)          # spine
    arm(9, 5, 16.5, 5.4)      # top arm
    arm(9, 12, 15, 12)        # middle arm (shorter)
    arm(9, 19, 17, 18.6)      # bottom arm

    return img.resize((size, size), Image.LANCZOS)

def main():
    out = Path('windows/runner/resources/app_icon.ico')
    out.parent.mkdir(parents=True, exist_ok=True)
    sizes = [16, 24, 32, 48, 64, 128, 256]
    frames = [draw_e(s) for s in sizes]
    frames[-1].save(out, format='ICO',
                    sizes=[(s, s) for s in sizes],
                    append_images=frames[:-1])
    print(f'wrote {out} with sizes {sizes}')

if __name__ == '__main__':
    main()
