"""Generate Echo Bay's two atmosphere sounds from scratch (original,
CC0). Pure synthesis with numpy — no samples, no external material.

- pen_scratch.wav: a soft pen nib scratch — filtered noise shaped by a
  quick ramp with two pressure humps, like a short handwritten word.
- page_turn.wav: a page settling on a desk — a soft broadband brush
  followed by a low, quiet thump.

Both are 22050 Hz mono 16-bit WAV (universal support, tiny size).
"""
import struct
import wave

import numpy as np

SR = 22050
OUT = "assets/audio"


def env_humps(n, points, floor=0.0):
    """Piecewise-smooth amplitude envelope through (t, a) points."""
    t = np.linspace(0, 1, n)
    ts = np.array([p[0] for p in points])
    ys = np.array([p[1] for p in points])
    return np.interp(t, ts, ys, left=floor, right=floor)


def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def write_wav(path, x):
    peak = np.max(np.abs(x)) or 1.0
    data = (x / peak * 32000).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{path}: {len(data)/SR:.2f}s")


rng = np.random.default_rng(7)

# -- pen scratch -------------------------------------------------------
n = int(SR * 0.38)
noise = rng.standard_normal(n)
# The nib's timbre: lowpassed grain + a bit of high sizzle.
grain = lowpass(noise, 0.28)
sizzle = noise - lowpass(noise, 0.6)
x = 0.8 * grain + 0.25 * sizzle
# Two pen-press strokes with a lift between them.
x *= env_humps(n, [(0.0, 0.0), (0.08, 0.9), (0.22, 0.35), (0.34, 0.8),
                   (0.62, 0.15), (0.78, 0.4), (0.92, 0.05), (1.0, 0.0)])
# Faint 180 Hz body so it feels physical, not like pure static.
x += 0.06 * np.sin(2 * np.pi * 180 * np.arange(n) / SR) * env_humps(
    n, [(0, 0), (0.1, 1), (0.6, 0.6), (1, 0)])
write_wav(f"{OUT}/pen_scratch.wav", 0.85 * x)

# -- page turn ---------------------------------------------------------
n = int(SR * 0.45)
noise = rng.standard_normal(n)
brush = lowpass(noise, 0.16)
# Sweep the "paper edge" across: rising then settling brush.
brush *= env_humps(n, [(0.0, 0.0), (0.12, 0.5), (0.3, 0.95), (0.55, 0.35),
                       (0.7, 0.55), (1.0, 0.0)])
t = np.arange(n) / SR
# Soft desk contact at the end: damped low thump.
thump_t0 = int(SR * 0.62)
thump = np.zeros(n)
m = n - thump_t0
tt = np.arange(m) / SR
thump[thump_t0:] = 0.5 * np.exp(-tt * 55) * np.sin(2 * np.pi * 95 * tt)
x = brush + thump
write_wav(f"{OUT}/page_turn.wav", x)
