"""CYPURRPUNK - makes the AFTERBURNER boost's sound + HUD badge (no internet, no tool server needed).

    python tools/make_boost_assets.py

Writes:
    sounds/sfx/boost.wav        - a crunchy rocket WHOOSH-ROAR when the car boosts (scripts/car/car_boost.gd)
    ui/icons/status/boost.png   - 32x32 pixel flame, the charge badges next to the health bar (hud.gd)

Change the numbers below and run it again to retune them (Godot re-imports by itself).
"""
import wave
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RATE = 22050  # low sample rate on purpose: sounds a bit PS1


def boost_sound():
    seconds = 1.4
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(7)
    noise = rng.uniform(-1, 1, n)
    # Low-pass the noise a bit (running average) so it roars instead of hissing.
    roar = np.convolve(noise, np.ones(6) / 6, mode="same")
    # A rumbling engine growl that sweeps UP (the car taking off).
    freq = 55 + 140 * (t / seconds) ** 0.6
    growl = np.sign(np.sin(2 * np.pi * np.cumsum(freq) / RATE)) * 0.35
    # Punchy start (the ignition "whump"), then a long fade.
    attack = np.clip(t / 0.02, 0, 1)
    body = np.exp(-t * 1.6)
    whump = np.exp(-t * 18) * np.sin(2 * np.pi * 60 * t) * 0.8
    x = (roar * 0.9 + growl) * attack * body + whump
    x = np.round(np.clip(x, -1, 1) * 64) / 64 * 0.75  # bit-crush for the console crunch
    out = ROOT / "sounds" / "sfx" / "boost.wav"
    with wave.open(str(out), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((x * 32767).astype("<i2").tobytes())
    print("wrote", out)


def boost_icon():
    # A white flame (the HUD tints it): fat round bottom, flickering tongues on top, a hole in the
    # middle so it reads as fire, not a blob. Drawn pixel by pixel at 32x32.
    size = 32
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            u = (x - 15.5) / 11.0          # -1..1 across
            v = (y - 4.0) / 25.0           # 0 at the top tip, 1 at the bottom
            if v < 0 or v > 1:
                continue
            # Width grows towards the bottom, rounded off at the very bottom.
            width = (v ** 0.7) * (1.0 - max(0.0, v - 0.8) * 3.5)
            # Two little side tongues.
            tongue = 0.25 * np.exp(-((v - 0.35) ** 2) / 0.01) * (1 if abs(u) > 0.3 else 0)
            if abs(u) <= width + tongue:
                inner = abs(u) <= width * 0.42 and 0.55 < v < 0.9
                if not inner:
                    px[x, y] = (255, 255, 255, 255)
    out = ROOT / "ui" / "icons" / "status" / "boost.png"
    img.save(out)
    print("wrote", out)


if __name__ == "__main__":
    boost_sound()
    boost_icon()
