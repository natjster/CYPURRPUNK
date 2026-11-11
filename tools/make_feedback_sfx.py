"""CYPURRPUNK - makes the little PLAYER FEEDBACK sounds (no internet, no tool server needed).

    python tools/make_feedback_sfx.py

Writes into sounds/sfx/:
    hitmarker.wav     - tiny crunchy "tik" when one of your shots / swings lands
    kill_confirm.wav  - two-note PS1 "ding-DING" when YOU smash an enemy
    loot_get.wav      - short sparkly up-chirp when loot goes into your backpack

Change the numbers below and run it again to retune them (Godot re-imports by itself).
"""
import wave
from pathlib import Path

import numpy as np

RATE = 22050  # low sample rate on purpose: sounds a bit PS1
OUT = Path(__file__).resolve().parent.parent / "sounds" / "sfx"


def envelope(n, attack=0.005, release=0.6):
    """Fast attack, exponential fade out."""
    t = np.arange(n) / RATE
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / max(release * n / RATE, 1e-4) * 3.0)


def tone(freq, seconds, square=0.3):
    t = np.arange(int(RATE * seconds)) / RATE
    sine = np.sin(2 * np.pi * freq * t)
    return (1 - square) * sine + square * np.sign(sine)


def crush(x, bits=6):
    """Bit crush for that cheap console crunch."""
    steps = 2 ** bits
    return np.round(x * steps) / steps


def save(name, x, volume=0.7):
    x = crush(np.clip(x, -1, 1)) * volume
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)
    print("wrote", OUT / name)


def hitmarker():
    n = int(RATE * 0.06)
    noise = np.random.default_rng(7).uniform(-1, 1, n) * 0.5
    click = tone(2400, 0.06, square=0.6)[:n]
    return (noise + click) * envelope(n, 0.001, 0.25)


def kill_confirm():
    a = tone(880, 0.07, 0.5)
    a *= envelope(len(a), 0.002, 0.8)
    b = tone(1320, 0.16, 0.5)
    b *= envelope(len(b), 0.002, 0.7)
    gap = np.zeros(int(RATE * 0.015))
    return np.concatenate([a, gap, b])


def loot_get():
    seconds = 0.14
    t = np.arange(int(RATE * seconds)) / RATE
    freq = 700 + 1400 * (t / seconds)  # sweeps up
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    x = 0.6 * np.sin(phase) + 0.4 * np.sign(np.sin(phase * 2))
    return x * envelope(len(t), 0.003, 0.8)


if __name__ == "__main__":
    save("hitmarker.wav", hitmarker(), 0.55)
    save("kill_confirm.wav", kill_confirm(), 0.6)
    save("loot_get.wav", loot_get(), 0.5)
