"""Makes the trailer's music: an original 120 BPM dark synthwave track, built from scratch
(no samples), so there are no licence worries. Saved to shots/trailer/music.wav.

The track is laid out in BARS (1 bar = 2 seconds at 120 BPM). trailer/edit.py cuts the
pictures to these same bars, so hits land on the beat. Change SECTIONS to rearrange it.

Run from the project folder:   python trailer/music.py
"""
import wave
from pathlib import Path

import numpy as np

RATE = 44100
BPM = 120
BEAT = 60 / BPM          # 0.5 s
BAR = BEAT * 4           # 2 s
STEP = BEAT / 4          # a 16th note
OUT = Path(__file__).resolve().parent.parent / "shots" / "trailer" / "music.wav"

# Which instruments play in each bar range: (first bar, last bar + 1, parts).
SECTIONS = [
    (0, 4, {"pad"}),                                              # 0-8 s    intro: rain + pad
    (4, 8, {"pad", "arp_soft"}),                                  # 8-16 s   the arp creeps in
    (8, 16, {"pad", "arp", "bass", "kick"}),                      # 16-32 s  the hub: groove
    (16, 18, {"pad", "arp", "bass", "build"}),                    # 32-36 s  build up
    (18, 34, {"pad", "arp", "bass", "kick", "snare", "hats", "lead"}),  # 36-68 s  DROP: action
    (34, 38, {"pad", "arp_soft", "bass"}),                        # 68-76 s  breather: co-op + cats
    (38, 42, {"pad", "arp", "bass", "kick", "snare", "hats", "lead"}),  # 76-84 s  final run
    (42, 46, {"pad", "boom"}),                                    # 84-92 s  title card
]
TOTAL_BARS = 46

# Am - F - C - G, one chord per bar: (bass note, chord notes) as MIDI numbers.
CHORDS = [(45, [57, 60, 64]), (41, [53, 57, 60]), (48, [55, 60, 64]), (43, [55, 59, 62])]

# The lead tune over 4 bars: (16th-step, MIDI note, length in 16ths). Two versions alternate.
LEAD_A = [(0, 76, 3), (3, 74, 1), (4, 76, 4), (10, 69, 2), (12, 72, 4),
          (16, 72, 3), (19, 69, 1), (20, 65, 4), (26, 69, 2), (28, 72, 4),
          (32, 79, 3), (35, 76, 1), (36, 72, 4), (42, 76, 2), (44, 79, 4),
          (48, 74, 6), (54, 71, 2), (56, 67, 4), (60, 71, 4)]
LEAD_B = [(0, 81, 3), (3, 79, 1), (4, 76, 4), (8, 81, 2), (10, 84, 2), (12, 83, 4),
          (16, 81, 6), (22, 77, 2), (24, 72, 4), (28, 77, 4),
          (32, 79, 3), (35, 76, 1), (36, 79, 4), (40, 84, 4), (44, 83, 4),
          (48, 83, 6), (54, 79, 2), (56, 74, 4), (60, 71, 4)]


def freq(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def times(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def saw(f: float, t: np.ndarray, harmonics: int) -> np.ndarray:
    """A saw wave made of only its first few harmonics (fewer = darker / more 'filtered')."""
    out = np.zeros_like(t)
    for k in range(1, harmonics + 1):
        if f * k > RATE / 2:
            break
        out += np.sin(2 * np.pi * f * k * t) / k
    return out


def square(f: float, t: np.ndarray, harmonics: int) -> np.ndarray:
    out = np.zeros_like(t)
    for k in range(1, harmonics * 2, 2):
        if f * k > RATE / 2:
            break
        out += np.sin(2 * np.pi * f * k * t) / k
    return out


def envelope(n: int, attack: float, release: float) -> np.ndarray:
    env = np.ones(n)
    a = min(n, int(attack * RATE))
    r = min(n - a, int(release * RATE))
    if a:
        env[:a] = np.linspace(0, 1, a)
    if r:
        env[n - r:] = np.linspace(1, 0, r)
    return env


def add(track: np.ndarray, sound: np.ndarray, at: float, gain: float = 1.0) -> None:
    start = int(at * RATE)
    end = min(len(track), start + len(sound))
    if start < end:
        track[start:end] += sound[: end - start] * gain


def echo(sound: np.ndarray, delay: float, feedback: float, taps: int) -> np.ndarray:
    """A simple tape echo: quieter copies of the sound, each one delay later."""
    out = sound.copy()
    shift = int(delay * RATE)
    for n in range(1, taps + 1):
        out[shift * n:] += sound[: len(sound) - shift * n] * feedback ** n
    return out


def build() -> np.ndarray:
    length = TOTAL_BARS * BAR + 2
    parts = {name: np.zeros(int(length * RATE)) for name in
             ["pad", "arp", "bass", "kick", "snare", "hats", "lead", "fx"]}
    rng = np.random.default_rng(1999)

    def playing(bar: int) -> set:
        for first, last, names in SECTIONS:
            if first <= bar < last:
                return names
        return set()

    for bar in range(TOTAL_BARS):
        now = playing(bar)
        start = bar * BAR
        root, chord = CHORDS[bar % 4]
        if "pad" in now:
            t = times(BAR + 0.6)
            pad = sum(saw(freq(n), t, 6) + saw(freq(n) * 1.004, t, 6) for n in chord)
            pad *= envelope(len(t), 0.5, 0.6)
            add(parts["pad"], pad, start, 0.05)
        if "arp" in now or "arp_soft" in now:
            soft = "arp_soft" in now
            pattern = chord + [chord[0] + 12] + chord[::-1]
            for step in range(16):
                t = times(STEP * 0.9)
                note = pattern[step % len(pattern)] + 12
                tone = square(freq(note), t, 3 if soft else 6) * np.exp(-t * 14)
                add(parts["arp"], tone, start + step * STEP, 0.05 if soft else 0.08)
        if "bass" in now:
            for eighth in range(8):
                t = times(BEAT / 2 * 0.85)
                note = root - 12 + (12 if eighth % 2 else 0)  # octave pulse
                tone = saw(freq(note), t, 8) * envelope(len(t), 0.004, 0.05)
                add(parts["bass"], tone, start + eighth * BEAT / 2, 0.22)
        if "kick" in now:
            for beat in range(4):
                t = times(0.35)
                pitch = 45 + 110 * np.exp(-t * 30)
                kick = np.sin(2 * np.pi * np.cumsum(pitch) / RATE) * np.exp(-t * 9)
                add(parts["kick"], kick, start + beat * BEAT, 0.9)
        if "snare" in now:
            for beat in (1, 3):
                t = times(0.25)
                snare = (rng.uniform(-1, 1, len(t)) * 0.7 + np.sin(2 * np.pi * 190 * t) * 0.5) * np.exp(-t * 18)
                add(parts["snare"], snare, start + beat * BEAT, 0.45)
        if "hats" in now:
            for step in range(2, 16, 4):
                t = times(0.06)
                noise = rng.uniform(-1, 1, len(t))
                hat = (noise - np.concatenate([[0], noise[:-1]])) * np.exp(-t * 60)  # a crude high-pass
                add(parts["hats"], hat, start + step * STEP, 0.12)
        if "lead" in now:
            tune = LEAD_A if (bar // 4) % 2 == 0 else LEAD_B
            for step, note, length in tune:
                if step // 16 != bar % 4:
                    continue
                t = times(length * STEP)
                vibrato = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 4, 0, 1)
                tone = saw(freq(note), t * vibrato, 10) + saw(freq(note) * 1.006, t, 10)
                tone *= envelope(len(t), 0.01, 0.08)
                add(parts["lead"], tone, start + (step % 16) * STEP, 0.07)
        if "build" in now:
            # Snare roll speeding up + a noise riser across the two build bars.
            local = bar - 16
            hits = 8 if local == 0 else 16
            for h in range(hits):
                t = times(0.1)
                snare = rng.uniform(-1, 1, len(t)) * np.exp(-t * 30)
                add(parts["snare"], snare, start + h * BAR / hits, 0.15 + 0.2 * (local + h / hits) / 2)
            t = times(BAR)
            noise = np.convolve(rng.uniform(-1, 1, len(t)), np.ones(6) / 2, mode="same")  # softened hiss
            riser = noise * np.linspace(0.0, 1.0, len(t)) ** 2
            phase = np.cumsum(freq(57 + 12 * local) * (1 + t / BAR)) / RATE  # a rising whine
            riser += sum(np.sin(2 * np.pi * k * phase) / k for k in range(1, 5)) * 0.4
            add(parts["fx"], riser, start, 0.12 + 0.1 * local)
        if "boom" in now and bar == 42:
            # The title hit: a deep boom + a crash of noise, ringing out.
            t = times(4.0)
            pitch = 30 + 90 * np.exp(-t * 12)
            boom = np.sin(2 * np.pi * np.cumsum(pitch) / RATE) * np.exp(-t * 1.2)
            crash = rng.uniform(-1, 1, len(t)) * np.exp(-t * 2.5)
            add(parts["fx"], boom * 0.9 + crash * 0.25, start, 1.0)

    # Space: echo on the arp, lead and pad; then mix and keep it from clipping.
    parts["arp"] = echo(parts["arp"], BEAT * 0.75, 0.35, 4)
    parts["lead"] = echo(parts["lead"], BEAT * 0.75, 0.3, 3)
    parts["pad"] = echo(parts["pad"], 0.11, 0.4, 5)
    mix = sum(parts.values())
    mix = np.tanh(mix * 1.3) / np.tanh(1.3)  # gentle tape-style saturation
    return mix / np.max(np.abs(mix)) * 0.89


def save(samples: np.ndarray) -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    # Slightly different left / right (a few ms apart) for some width.
    left = samples
    right = np.concatenate([np.zeros(int(0.012 * RATE)), samples[: -int(0.012 * RATE)]]) * 0.5 + samples * 0.5
    stereo = (np.stack([left, right], axis=1) * 32767).astype(np.int16)
    with wave.open(str(OUT), "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(stereo.tobytes())
    print(f"saved {OUT} ({len(samples) / RATE:.1f} s)")


if __name__ == "__main__":
    save(build())
