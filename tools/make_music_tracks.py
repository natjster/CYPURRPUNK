"""CYPURRPUNK MUSIC MAKER: four looping 90s PS1-style arcade techno / drum & bass tracks, made from
maths (no samples, no licence worries), straight into sounds/music/.

    python tools/make_music_tracks.py                 (makes all four)
    python tools/make_music_tracks.py escape breach   (only these)
    python tools/make_music_tracks.py --levels        (also print each instrument's loudness)

The tracks (SETUP_GUIDE.md section 12 says when each one plays):
    city_ridge    "NEON APEX"          138 BPM arcade techno   (a street raid track)
    city_wipeout  "ANTI-GRAV WHISKERS" 160 BPM liquid DnB      (a street raid track)
    escape        "HOT PAWS"           168 BPM jungle          (the exit is open: run!)
    breach        "TOTAL SANITATION"   176 BPM hardcore        (DEEP CLEAN / SEWER BREACH)

HOW TO TWEAK A TRACK: each one is a function near the bottom (track_neon_apex, ...). At its top are
the plain settings: BPM, BARS (how long the loop is), the chords, the drum patterns, the tunes and
the ARRANGEMENT (which instruments play in which bars). Change a number, run the script again, and
start the game: Godot picks the new file up by itself.

Drum patterns are 16 letters per bar (one per 16th note):  X = loud hit, x = normal, o = soft
(a "ghost" note), . = nothing.
Notes are MIDI numbers (60 = middle C, +12 = an octave up). Tunes are lists of
(step, note, length in steps), counted in 16th notes from the start of the phrase.

SEAMLESS LOOPS: everything is drawn onto a "circular" tape exactly one loop long: a cymbal or echo
that rings past the end comes round again at the start, so the game's loop has no click or gap.

Output: 16-bit mono 22050 Hz .wav (the same as the rest of the game's sounds). Needs only numpy.
"""
from __future__ import annotations

import os
import sys
import wave

import numpy as np

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC_DIR = os.path.join(PROJECT_ROOT, "sounds", "music")
RATE = 22050
## How loud the finished track is (average level). The old city.wav / hub.wav sit around 0.08-0.11;
## these are a bit punchier. Peaks are softly limited below full scale.
TARGET_RMS = 0.13
## --levels on the command line prints how loud each instrument is in each track.
SHOW_LEVELS = "--levels" in sys.argv


# =====================================================================================
# Small building blocks
# =====================================================================================

def hz(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def secs(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, n)


def _blep(phase: np.ndarray, dt: np.ndarray) -> np.ndarray:
    """PolyBLEP: smooths the jump in a saw wave so high notes don't fizz (anti-aliasing)."""
    out = np.zeros_like(phase)
    m = phase < dt
    t = phase[m] / dt[m]
    out[m] = t + t - t * t - 1.0
    m = phase > 1.0 - dt
    t = (phase[m] - 1.0) / dt[m]
    out[m] = t * t + t + t + 1.0
    return out


def _phase(freq: np.ndarray, start: float = 0.0):
    dt = np.clip(freq / RATE, 1e-6, 0.49)
    return (start + np.cumsum(dt)) % 1.0, dt


def saw(freq, start: float = 0.0) -> np.ndarray:
    freq = np.asarray(freq, dtype=np.float64)
    ph, dt = _phase(freq, start)
    return 2.0 * ph - 1.0 - _blep(ph, dt)


def pulse(freq, width: float = 0.5, start: float = 0.0) -> np.ndarray:
    freq = np.asarray(freq, dtype=np.float64)
    ph, dt = _phase(freq, start)
    ph2 = (ph + width) % 1.0
    return (2.0 * ph - 1.0 - _blep(ph, dt)) - (2.0 * ph2 - 1.0 - _blep(ph2, dt))


def sine(freq, start: float = 0.0) -> np.ndarray:
    freq = np.asarray(freq, dtype=np.float64)
    return np.sin(2 * np.pi * (start + np.cumsum(freq / RATE)))


def fft_filter(x: np.ndarray, low: float = 0.0, high: float = 0.0, order: int = 2, circular: bool = False) -> np.ndarray:
    """Static band-pass (Hz; 0 = no limit). circular=True wraps round (for whole loops: seamless)."""
    n = len(x)
    if n == 0:
        return x
    size = n if circular else 1 << int(np.ceil(np.log2(n * 2)))
    spec = np.fft.rfft(x, size)
    f = np.fft.rfftfreq(size, 1.0 / RATE)
    gain = np.ones_like(f)
    if high > 0:
        gain *= 1.0 / np.sqrt(1.0 + (f / high) ** (2 * order))
    if low > 0:
        gain *= 1.0 / np.sqrt(1.0 + (low / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(spec * gain, size)[:n]


def svf(x: np.ndarray, cutoff, resonance: float = 0.7, mode: str = "low", prime: int = 0) -> np.ndarray:
    """Resonant filter whose cutoff (Hz, one value or one per sample) can move: the acid / sweep sound.
    resonance 0.5 = gentle, 0.9+ = squelchy. prime = run this many samples from the END first, so
    a whole loop starts with the filter already 'warm' from its own ending (seamless)."""
    n = len(x)
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), (n,))
    if prime > 0:
        x = np.concatenate([x[-prime:], x])
        cutoff = np.concatenate([cutoff[-prime:], cutoff])
    g = np.tan(np.pi * np.clip(cutoff, 20.0, RATE * 0.45) / RATE)
    k = 2.0 - 2.0 * min(resonance, 0.98)
    h = 1.0 / (1.0 + g * (g + k))
    out = np.empty(len(x))
    s1 = s2 = 0.0
    xs, gs, hs = x.tolist(), g.tolist(), h.tolist()
    want = {"low": 0, "band": 1, "high": 2}[mode]
    for i in range(len(xs)):
        gi = gs[i]
        hp = (xs[i] - (gi + k) * s1 - s2) * hs[i]
        bp = gi * hp + s1
        s1 = gi * hp + bp
        lp = gi * bp + s2
        s2 = gi * bp + lp
        out[i] = lp if want == 0 else (bp if want == 1 else hp)
    return out[prime:]


def env(n: int, attack: float = 0.002, decay: float = 0.2, sustain: float = 0.0, release_at: int = -1, release: float = 0.01) -> np.ndarray:
    """Volume shape: quick rise, fall to 'sustain', then fade out from sample release_at."""
    t = np.arange(n) / RATE
    e = sustain + (1.0 - sustain) * np.exp(-t / max(decay, 1e-4))
    a = int(attack * RATE)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    if 0 <= release_at < n:
        r = np.arange(n - release_at) / RATE
        e[release_at:] *= np.exp(-r / max(release, 1e-4))
    return e


def fade_edges(x: np.ndarray, ms: float = 2.0) -> np.ndarray:
    m = min(len(x) // 2, int(ms / 1000 * RATE))
    if m > 0:
        x = x.copy()
        x[:m] *= np.linspace(0, 1, m)
        x[-m:] *= np.linspace(1, 0, m)
    return x


def drive(x: np.ndarray, amount: float) -> np.ndarray:
    """Distortion: amount 1 = warm, 5+ = smashed."""
    return np.tanh(x * amount) / np.tanh(amount)


# =====================================================================================
# Drum sounds (909 / breakbeat kit, all synthesised)
# =====================================================================================

def kick(rng, punch=130.0, low=48.0, length=0.42, dirt=1.6, click=0.35) -> np.ndarray:
    t = secs(length)
    f = low + punch * np.exp(-t / 0.032)
    body = sine(f) * np.exp(-t / (length * 0.55))
    tick = noise(len(t), rng) * np.exp(-t / 0.003) * click
    return drive(body + tick, dirt)


def snare(rng, tone=185.0, length=0.22, snap=1.0, bright=1800.0) -> np.ndarray:
    t = secs(length)
    body = sine(tone * (1 + 0.5 * np.exp(-t / 0.01))) * np.exp(-t / 0.05) * 0.7
    hiss = fft_filter(noise(len(t), rng), low=bright, high=9000) * np.exp(-t / (length * 0.45)) * 1.6 * snap
    return drive(body + hiss, 1.4)


def clap(rng, length=0.3) -> np.ndarray:
    t = secs(length)
    n = noise(len(t), rng)
    shape = np.exp(-t / 0.09) * 0.8
    for gap in (0.0, 0.011, 0.022):  # three hands, a hair apart
        shape += np.where(t >= gap, np.exp(-np.maximum(t - gap, 0) / 0.006), 0)
    return fft_filter(n * shape, low=900, high=3500)


def hat(rng, length=0.04) -> np.ndarray:
    t = secs(length)
    metal = sum(pulse(np.full(len(t), f)) for f in (3200, 4530, 5900, 7120)) * 0.25
    return fft_filter(noise(len(t), rng) * 0.6 + metal * 0.4, low=6000) * np.exp(-t / (length * 0.35))


def crash(rng, length=1.6) -> np.ndarray:
    t = secs(length)
    return fft_filter(noise(len(t), rng), low=3500) * np.exp(-t / (length * 0.35)) * 0.8


# =====================================================================================
# The tape: one loop long, everything placed on it wraps round (seamless)
# =====================================================================================

class Song:
    def __init__(self, name: str, bpm: float, bars: int, seed: int):
        self.name = name
        self.bpm = bpm
        self.bars = bars
        self.step = 60.0 / bpm / 4.0          # one 16th note, seconds
        self.bar = self.step * 16
        self.n = int(round(bars * self.bar * RATE))
        self.rng = np.random.default_rng(seed)
        self.stems: dict[str, np.ndarray] = {}
        self.kicks: list[float] = []          # kick times (seconds), for the sidechain pump

    def stem(self, name: str) -> np.ndarray:
        if name not in self.stems:
            self.stems[name] = np.zeros(self.n)
        return self.stems[name]

    def at(self, bar: int, step: float = 0.0) -> float:
        return (bar * 16 + step) * self.step

    def put(self, stem: str, sound: np.ndarray, when: float, gain: float = 1.0) -> None:
        """Add a sound to a stem at 'when' seconds, wrapping past the loop's end round to the start."""
        buf = self.stem(stem)
        start = int(round(when * RATE)) % self.n
        sound = sound[: self.n] * gain
        end = start + len(sound)
        if end <= self.n:
            buf[start:end] += sound
        else:
            cut = self.n - start
            buf[start:] += sound[:cut]
            buf[: end - self.n] += sound[cut:]

    # --- drums ---
    def drums(self, stem: str, sound_maker, pattern: str, bars, gain: float = 1.0, swing: float = 0.0,
              is_kick: bool = False, variations: int = 4) -> None:
        """Play 'pattern' (16 letters) in every bar of 'bars'. A few versions of the sound are made
        and picked at random so it doesn't sound like a machine gun."""
        versions = [sound_maker() for _ in range(variations)]
        levels = {"X": 1.0, "x": 0.75, "o": 0.3}
        for b in bars:
            for s, ch in enumerate(pattern):
                if ch in levels:
                    when = self.at(b, s + (swing if s % 2 else 0.0))
                    self.put(stem, versions[self.rng.integers(len(versions))], when, gain * levels[ch])
                    if is_kick and ch != "o":
                        self.kicks.append(when)

    def break_bars(self, stem: str, kit: dict, pattern: dict, bars, chops: list | None = None,
                   gain: float = 1.0, swing: float = 0.0, dirt: float = 1.0) -> None:
        """A breakbeat: one bar of break played from 'pattern' ({"kick": "x...", "snare": ...}),
        then cut into 16 slices and re-ordered per bar by 'chops' (a list of 16 slice numbers per
        bar, cycling; None = play it straight). That cutting-up is the jungle sound."""
        bar_n = int(round(self.bar * RATE))
        one = np.zeros(bar_n + int(0.5 * RATE))
        levels = {"X": 1.0, "x": 0.75, "o": 0.3}
        for part, letters in pattern.items():
            for s, ch in enumerate(letters):
                if ch in levels:
                    snd = kit[part]() * levels[ch]
                    at = int(round((s + (swing if s % 2 else 0.0)) * self.step * RATE))
                    one[at: at + len(snd)] += snd[: len(one) - at]
        # the tail that rings past the bar wraps onto its start (it repeats bar after bar)
        tail = one[bar_n:]
        one = one[:bar_n].copy()
        one[: len(tail)] += tail
        one = drive(one, dirt) if dirt > 1.0 else one
        edges = np.linspace(0, bar_n, 17).astype(int)
        slices = [fade_edges(one[edges[i]: edges[i + 1]], 1.5) for i in range(16)]
        for i, b in enumerate(bars):
            order = chops[i % len(chops)] if chops else list(range(16))
            out = np.concatenate([slices[k] for k in order])
            self.put(stem, out, self.at(b), gain)
            for s, k in enumerate(order):  # where kicks landed (for the pump)
                if pattern.get("kick", "")[k:k + 1] in ("X", "x"):
                    self.kicks.append(self.at(b, s))

    # --- melodic lines (one voice that can slide between notes) ---
    def line(self, stem: str, notes: list, bars_from: int, osc: str = "saw", gain: float = 1.0,
             cutoff: float = 900.0, env_amount: float = 2500.0, env_decay: float = 0.12,
             resonance: float = 0.6, glide: float = 0.0, decay: float = 0.4, sustain: float = 0.6,
             detune: float = 0.0, vibrato: float = 0.0, bend: float = 0.0, transpose: float = 0.0,
             sub: float = 0.0, dirt: float = 1.0, accents: set | None = None) -> None:
        """A bass / lead / arp line: notes = [(step, midi, length_steps), ...] counted from bar
        'bars_from'. glide = seconds it slides into each note; bend = semitones each note rises;
        detune = cents spread of two oscillators (Reese bass / supersaw)."""
        if not notes:
            return
        last = max(s + l for s, _, l in notes)
        total = int(round((last * self.step + 0.6) * RATE))
        freq = np.zeros(total)
        amp = np.zeros(total)
        cut = np.full(total, cutoff)
        prev = None
        for s, m, l in sorted(notes):
            m = m + transpose
            a = int(round(s * self.step * RATE))
            length = int(round(l * self.step * RATE))
            seg = np.arange(total - a) / RATE
            pitch = np.full(total - a, float(m))
            if bend:
                pitch += bend * np.clip(seg / max(l * self.step, 1e-3), 0, 1)
            if glide > 0 and prev is not None:
                g = np.clip(seg / glide, 0, 1)
                pitch = prev + (pitch - prev) * g
            if vibrato:
                pitch += vibrato * np.sin(2 * np.pi * 5.5 * seg) * np.clip((seg - 0.12) / 0.2, 0, 1)
            freq[a:] = 440.0 * 2 ** ((pitch - 69) / 12.0)
            accent = 1.3 if accents and s in accents else 1.0
            e = env(total - a, attack=0.003, decay=decay, sustain=sustain, release_at=length, release=0.03)
            amp[a:] = e * accent
            cut[a:] = cutoff + env_amount * accent * np.exp(-seg / env_decay)
            prev = m
        if osc == "saw":
            wave_ = saw(freq)
            if detune:
                wave_ = 0.5 * wave_ + 0.5 * saw(freq * 2 ** (detune / 1200.0), 0.33)
                wave_ = 0.66 * wave_ + 0.34 * saw(freq * 2 ** (-detune / 1200.0), 0.71)
        elif osc == "square":
            wave_ = pulse(freq, 0.5)
            if detune:
                wave_ = 0.5 * wave_ + 0.5 * pulse(freq * 2 ** (detune / 1200.0), 0.5, 0.4)
        elif osc == "supersaw":  # bright, brassy lead
            wave_ = saw(freq) * 0.5 + 0.3 * saw(freq * 1.006, 0.2) + 0.3 * saw(freq * 0.994, 0.6) + 0.2 * pulse(freq * 2, 0.3)
        else:
            wave_ = sine(freq)
        filtered = svf(wave_, cut, resonance)
        if sub:
            filtered = filtered + sub * sine(freq / 2.0)
        out = drive(filtered * amp, dirt) if dirt > 1.0 else filtered * amp
        self.put(stem, out, self.at(bars_from), gain)

    # --- chords ---
    def chord(self, stem: str, notes: list, when: float, length: float, gain: float = 1.0,
              kind: str = "stab", bright: float = 3000.0) -> None:
        """A chord: kind 'stab' = short brassy rave hit, 'pad' = long soft wash, 'hoover' = the
        dipping, detuned rave 'hoover' hit, 'alarm' = industrial two-tone siren stab."""
        t = secs(length + 0.3)
        out = np.zeros(len(t))
        for m in notes:
            f = np.full(len(t), hz(m))
            if kind == "hoover":
                f = f * 2 ** ((-2.0 * np.exp(-t / 0.05)) / 12.0)
            if kind == "alarm":
                f = f * np.where((t * 9.0) % 1.0 < 0.5, 1.0, 2 ** (3 / 12.0))
                out += pulse(f, 0.3)
                continue
            for cents, ph in ((0, 0.0), (11, 0.37), (-13, 0.71)):  # three detuned voices per note
                f2 = f * 2 ** (cents / 1200.0)
                out += pulse(f2, 0.25, ph) if kind == "hoover" else saw(f2, ph)
        out /= max(len(notes), 1)
        rel = int(length * RATE)
        if kind == "pad":
            e = env(len(t), attack=min(0.35, length * 0.3), decay=2.0, sustain=0.75, release_at=rel, release=0.12)
            out = fft_filter(out, high=bright, order=2)
        elif kind == "alarm":
            e = env(len(t), attack=0.002, decay=0.5, sustain=0.6, release_at=rel, release=0.02)
            out = drive(fft_filter(out, low=300, high=bright), 3.0)
        else:  # stab / hoover: filter snaps shut quickly = "brassy"
            e = env(len(t), attack=0.002, decay=0.16, sustain=0.15, release_at=rel, release=0.04)
            out = svf(out, bright * (0.25 + 0.75 * np.exp(-t / 0.08)), 0.4)
        self.put(stem, out * e, when, gain)

    # --- effects on a whole stem ---
    def echo(self, stem: str, delay_steps: float, feedback: float = 0.4, repeats: int = 4, mix: float = 0.5) -> None:
        buf = self.stem(stem)
        d = int(round(delay_steps * self.step * RATE))
        wet = np.zeros(self.n)
        for i in range(1, repeats + 1):
            wet += np.roll(buf, d * i) * feedback ** (i - 1)
        self.stems[stem] = buf + mix * fft_filter(wet, high=3500, circular=True)

    def space(self, stem: str, amount: float = 0.25) -> None:
        """A cheap room: a few short echoes, darkened (PS1 reverb was about this fancy)."""
        buf = self.stem(stem)
        wet = sum(np.roll(buf, int(ms / 1000 * RATE)) * g for ms, g in ((23, .5), (41, .4), (67, .3), (97, .25), (131, .18)))
        self.stems[stem] = buf + amount * fft_filter(wet, high=2500, circular=True)

    def pump(self, stems: list, depth: float = 0.6, release: float = 0.16) -> None:
        """Sidechain 'pumping': these stems duck under every kick (that breathing techno sound)."""
        duck = np.zeros(self.n)
        k = depth * np.exp(-secs(release * 3) / release)
        for when in self.kicks:
            start = int(round(when * RATE)) % self.n
            idx = (start + np.arange(len(k))) % self.n
            duck[idx] = np.maximum(duck[idx], k)
        for s in stems:
            if s in self.stems:
                self.stems[s] = self.stems[s] * (1.0 - duck)

    def sweep(self, stem: str, source: np.ndarray, start_bar: int, bars: int, low: float, high: float,
              resonance: float = 0.85, gain: float = 1.0) -> None:
        """A filter sweep (rising whoosh / acid sweep) over some bars."""
        n = int(round(bars * self.bar * RATE))
        src = np.resize(source, n)
        cut = low * (high / low) ** np.linspace(0, 1, n) ** 2
        out = svf(src, cut, resonance) * np.linspace(0.3, 1, n)
        self.put(stem, fade_edges(out, 30), self.at(start_bar), gain)

    # --- finish ---
    def mix(self, levels: dict) -> np.ndarray:
        out = np.zeros(self.n)
        for name, buf in self.stems.items():
            out += buf * levels.get(name, 1.0)
        if SHOW_LEVELS:  # --levels: how loud each instrument ends up (to balance the mix)
            total = np.sqrt(np.mean(out ** 2)) + 1e-9
            print("  %s: " % self.name + ", ".join("%s %.0f%%" % (k, 100 * np.sqrt(np.mean((b * levels.get(k, 1.0)) ** 2)) / total)
                                               for k, b in self.stems.items()))
        out -= out.mean()
        out = fft_filter(out, low=28, high=9500, circular=True)  # no rumble, no fizz
        out = out / (np.sqrt(np.mean(out ** 2)) + 1e-9) * TARGET_RMS
        return 0.95 * np.tanh(out / 0.95)  # soft limiter: peaks round off instead of clipping

    def save(self, levels: dict) -> str:
        data = (np.clip(self.mix(levels), -1, 1) * 32767).astype("<i2")
        path = os.path.join(MUSIC_DIR, self.name + ".wav")
        os.makedirs(MUSIC_DIR, exist_ok=True)
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(data.tobytes())
        return path


def arp_notes(chords: list, bars_per_chord: int, every: int = 1, octaves: int = 2, pattern=(0, 1, 2, 3, 2, 1)):
    """16th-note arpeggio climbing each chord: [(step, midi, len), ...]."""
    out = []
    for i, (_, tones) in enumerate(chords):
        ladder = [m + 12 * o for o in range(octaves) for m in tones]
        for s in range(0, 16 * bars_per_chord, every):
            out.append((i * 16 * bars_per_chord + s, ladder[pattern[(s // every) % len(pattern)] % len(ladder)], every))
    return out


def repeat(notes: list, steps: int, times: int, transpose: list | None = None):
    """Copy a phrase 'times' times, each 'steps' later (optionally shifted up per copy)."""
    out = []
    for k in range(times):
        up = transpose[k % len(transpose)] if transpose else 0
        out += [(s + k * steps, m + up, l) for s, m, l in notes]
    return out


def bars(a: int, b: int):
    return range(a, b)


# =====================================================================================
# 1. NEON APEX: 138 BPM arcade techno (Ridge Racer-style street raid)
# =====================================================================================

def track_neon_apex() -> str:
    song = Song("city_ridge", bpm=138, bars=24, seed=138)
    # D minor, uplifting: Dm - Bb - F - C, one chord per bar. (bass root, chord notes)
    CHORDS = [(38, [62, 65, 69, 74]), (34, [58, 62, 65, 70]), (41, [60, 65, 69, 72]), (36, [60, 64, 67, 72])]
    # ARRANGEMENT (bars): intro groove 0-3, lead 4-11, breakdown 12-15, big finish 16-23
    full = list(bars(0, 12)) + list(bars(16, 24))
    r = song.rng
    song.drums("kick", lambda: kick(r, punch=150, low=50, length=0.4, dirt=1.8), "x...x...x...x...", full, 1.0, is_kick=True)
    song.drums("hats", lambda: hat(r, 0.16), "..x...x...x...x.", bars(0, 24), 0.55)         # offbeat open hats
    song.drums("hats", lambda: hat(r, 0.035), "x.oxx.oxx.oxx.ox", full, 0.35)               # 16th closed hats
    song.drums("clap", lambda: clap(r), "....x.......x...", list(bars(4, 12)) + list(bars(14, 24)), 0.6)
    song.drums("clap", lambda: snare(r, length=0.12), "x.x.x.x.xxxxxxxx", [15], 0.4)      # roll into the drop
    for b in (0, 4, 16):
        song.put("fx", crash(r), song.at(b), 0.5)
    # Rubbery octave bass: low root on the beat, an octave up on every offbeat 8th.
    bass = []
    for i in range(24):
        root = CHORDS[i % 4][0]
        for s in range(0, 16, 2):
            bass.append((i * 16 + s, root + (12 if s % 4 else 0), 2))
    song.line("bass", bass, 0, "saw", 0.8, cutoff=260, env_amount=1500, env_decay=0.07, resonance=0.7, decay=0.12, sustain=0.3, sub=0.5)
    # Bright brassy rave stabs on a syncopated rhythm.
    for b in full:
        for s in (0, 3, 6, 10, 13):
            song.chord("stabs", CHORDS[b % 4][1], song.at(b, s), song.step * 1.5, 0.8, "stab", 4200)
    # Pad + arp carry the breakdown.
    for b in bars(12, 16):
        song.chord("pad", CHORDS[b % 4][1], song.at(b), song.bar, 0.7, "pad", 2000)
    arp = arp_notes([(r0, [n + 12 for n in t]) for r0, t in CHORDS], 1, every=1, octaves=2, pattern=(0, 2, 4, 1, 3, 5, 7, 6))
    song.line("arp", repeat(arp, 64, 6), 0, "square", 0.35, cutoff=1200, env_amount=2500, env_decay=0.05, decay=0.06, sustain=0.0)
    song.echo("arp", 3, 0.35, 3, 0.4)
    # The soaring lead: tune A twice in bars 4-11, tune B (higher) twice in bars 16-23.
    LEAD_A = [(0, 74, 4), (4, 77, 2), (6, 76, 2), (8, 74, 4), (12, 72, 2), (14, 74, 2), (16, 77, 6), (22, 74, 2),
              (24, 72, 4), (28, 70, 4), (32, 72, 4), (36, 77, 2), (38, 79, 2), (40, 81, 6), (46, 79, 2),
              (48, 79, 4), (52, 77, 2), (54, 76, 2), (56, 72, 8)]
    LEAD_B = [(0, 81, 6), (6, 79, 2), (8, 77, 4), (12, 81, 4), (16, 82, 6), (22, 81, 2), (24, 77, 8),
              (32, 84, 4), (36, 81, 4), (40, 79, 4), (44, 77, 4), (48, 76, 6), (54, 79, 2), (56, 84, 8)]
    song.line("lead", repeat(LEAD_A, 64, 2), 4, "supersaw", 0.55, cutoff=1500, env_amount=2500, env_decay=0.2, resonance=0.3, glide=0.04, decay=0.5, sustain=0.7, vibrato=0.25)
    song.line("lead", repeat(LEAD_B, 64, 2), 16, "supersaw", 0.55, cutoff=1700, env_amount=2800, env_decay=0.2, resonance=0.3, glide=0.04, decay=0.5, sustain=0.7, vibrato=0.25)
    song.echo("lead", 3, 0.3, 3, 0.35)
    song.space("stabs", 0.35)
    song.space("lead", 0.3)
    song.pump(["bass", "stabs", "pad", "arp", "lead"], depth=0.55)
    return song.save({"kick": 0.55, "hats": 1.6, "clap": 0.9, "fx": 0.6, "bass": 0.55, "stabs": 1.0, "pad": 0.8, "arp": 0.6, "lead": 1.0})


# =====================================================================================
# 2. ANTI-GRAV WHISKERS: 160 BPM atmospheric liquid drum & bass (Wipeout-style street raid)
# =====================================================================================

def track_anti_grav() -> str:
    song = Song("city_wipeout", bpm=160, bars=24, seed=160)
    # F minor, two bars per chord: Fm9 - Dbmaj7 - Eb(add9) - Cm7. (bass root, chord notes)
    CHORDS = [(41, [56, 60, 63, 67]), (37, [53, 56, 60, 61]), (39, [55, 58, 63, 65]), (36, [55, 58, 63, 67])]
    # ARRANGEMENT: groove 0-7, + bells + acid 8-15, drums drop out 16-19, full 20-23
    drums_on = list(bars(0, 16)) + list(bars(20, 24))
    r = song.rng
    kit = {"kick": lambda: kick(r, punch=110, low=52, length=0.28, dirt=1.4, click=0.5),
           "snare": lambda: snare(r, tone=200, length=0.18, bright=2200),
           "hat": lambda: hat(r, 0.03)}
    BREAK = {"kick":  "x.........x.....",   # two-step: kick on 1 and the 'and' of 3
             "snare": "....X..o....X..o",
             "hat":   "x.xox.x.x.xox.xo"}
    song.break_bars("drums", kit, BREAK, drums_on, None, 1.0, swing=0.12)
    song.drums("hats", lambda: hat(r, 0.012), "oxoxoxoxoxoxoxox", drums_on, 0.25, swing=0.12)  # shaker ride
    for b in (0, 8, 20):
        song.put("fx", crash(r, 2.2), song.at(b), 0.5)
    # Deep warm Reese bass: two detuned saws that 'beat' against each other, sliding between notes.
    reese = []
    for i in range(12):  # 12 two-bar chords
        root = CHORDS[i % 4][0]
        base = i * 32
        reese += [(base, root, 14), (base + 14, root + 7, 2), (base + 16, root, 10), (base + 26, root + 3, 6)]
    song.line("bass", reese, 0, "saw", 0.8, cutoff=320, env_amount=500, env_decay=0.4, resonance=0.4, glide=0.06, decay=1.0, sustain=0.85, detune=18, sub=0.8)
    # Atmospheric pads, one per chord (two bars long).
    for i in range(12):
        song.chord("pad", CHORDS[i % 4][1], song.at(i * 2), song.bar * 2, 0.9, "pad", 1600)
    song.space("pad", 0.5)
    # Acid sweep: a squelchy 16th line whose filter slowly opens (bars 8-15, and again 16-23).
    acid_src = []
    for i in range(16):
        root = CHORDS[(i // 2) % 4][0] + 12
        for s, up in zip(range(16), (0, 0, 12, 0, 7, 0, 12, 3, 0, 0, 12, 0, 10, 0, 7, 12)):
            acid_src.append((i * 16 + s, root + up, 1))
    song.line("acid", acid_src[:128], 8, "saw", 0.35, cutoff=300, env_amount=1400, env_decay=0.06, resonance=0.88, decay=0.08, sustain=0.2, glide=0.01)
    song.sweep("acid", saw(np.full(int(song.bar * RATE), hz(53))) * 0.5 + noise(int(song.bar * RATE), r) * 0.3, 16, 4, 150, 5000, 0.9, 0.5)
    song.echo("acid", 3, 0.4, 3, 0.4)
    # Futuristic bell lead, sparse, with a long dotted echo.
    BELLS = [(0, 72, 3), (3, 75, 3), (6, 79, 6), (14, 77, 2), (16, 75, 6), (24, 72, 4), (28, 70, 4),
             (32, 68, 3), (35, 72, 3), (38, 77, 6), (46, 75, 2), (48, 72, 8), (60, 70, 4),
             (64, 70, 3), (67, 74, 3), (70, 79, 6), (78, 77, 2), (80, 75, 8), (92, 74, 4),
             (96, 72, 3), (99, 75, 3), (102, 79, 4), (106, 84, 6), (112, 82, 8), (124, 79, 4)]
    song.line("bells", BELLS, 8, "square", 0.4, cutoff=1800, env_amount=2000, env_decay=0.05, resonance=0.3, decay=0.25, sustain=0.0)
    song.line("bells", BELLS, 16, "square", 0.3, cutoff=1400, env_amount=1500, env_decay=0.05, resonance=0.3, decay=0.25, sustain=0.0)
    song.echo("bells", 6, 0.45, 4, 0.55)
    song.space("bells", 0.4)
    song.pump(["pad", "bass"], depth=0.25, release=0.12)
    return song.save({"drums": 0.9, "hats": 2.5, "fx": 0.5, "bass": 0.55, "pad": 0.6, "acid": 1.0, "bells": 1.0})


# =====================================================================================
# 3. HOT PAWS: 168 BPM jungle (the exit is open: chase music)
# =====================================================================================

AMEN = {"kick":  "X.x.......xx....",   # the classic 1969 break's shape, rebuilt from scratch
        "snare": "....X..o.o..X..o",
        "hat":   "x.x.x.x.x.x.x.x."}
CHOPS = [list(range(16)),                                  # straight
         [0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 10, 11, 12, 13, 12, 13],
         list(range(16)),
         [0, 1, 4, 5, 2, 3, 4, 7, 8, 9, 12, 12, 12, 12, 14, 15]]  # stutter roll at the end
HARD_CHOPS = [[0, 1, 4, 4, 2, 3, 12, 13, 8, 9, 4, 5, 12, 12, 14, 15],
              [0, 0, 0, 0, 4, 5, 6, 7, 12, 13, 12, 13, 4, 4, 4, 4]]


def track_hot_paws() -> str:
    song = Song("escape", bpm=168, bars=24, seed=168)
    # E minor with a tense B major: Em - C - Am - B, one per bar.
    CHORDS = [(40, [64, 67, 71]), (36, [64, 67, 72]), (45, [64, 69, 72]), (47, [63, 66, 71])]
    r = song.rng
    kit = {"kick": lambda: kick(r, punch=120, low=55, length=0.25, dirt=1.6, click=0.6),
           "snare": lambda: snare(r, tone=210, length=0.16, bright=2000, snap=1.2),
           "hat": lambda: hat(r, 0.035)}
    # ARRANGEMENT: break + bass + stabs 0-7, sirens rising 8-15, chopped mayhem 16-19, all of it 20-23
    song.break_bars("drums", kit, AMEN, list(bars(0, 16)) + list(bars(20, 24)), CHOPS, 1.0)
    song.break_bars("drums", kit, AMEN, bars(16, 20), HARD_CHOPS, 1.0, dirt=2.0)
    song.drums("kick", lambda: kick(r, punch=90, low=45, length=0.5, dirt=1.2, click=0.1), "X.........X.....", bars(0, 24), 0.6, is_kick=True)
    for b in (0, 8, 16, 20):
        song.put("fx", crash(r), song.at(b), 0.5)
    # Urgent pulsing bass: stabby 8ths on the root, with a jump at the end of each bar.
    bass = []
    for i in range(24):
        root = CHORDS[i % 4][0]
        for s, up in zip(range(0, 16, 2), (0, 0, 12, 0, 0, 12, 7, 10)):
            bass.append((i * 16 + s, root + up - 12, 2))
    song.line("bass", bass, 0, "saw", 0.8, cutoff=220, env_amount=900, env_decay=0.05, resonance=0.55, decay=0.1, sustain=0.4, detune=12, sub=0.9)
    # Rave hoover stabs on the off-beats.
    for b in bars(0, 24):
        for s in (0, 6, 12) if b % 2 == 0 else (2, 8, 14):
            song.chord("stabs", [n - 12 for n in CHORDS[b % 4][1]], song.at(b, s), song.step * 2, 0.8, "hoover", 3000)
    # Siren arps: every note bends up, and each pass climbs higher (bars 8-15 and 20-23).
    arp = arp_notes([(c[0], [n + 12 for n in c[1]]) for c in CHORDS], 1, every=1, octaves=2, pattern=(0, 1, 2, 3, 4, 5, 4, 3))
    song.line("siren", repeat(arp, 64, 2, transpose=[0, 2]), 8, "square", 0.32, cutoff=1500, env_amount=2000, env_decay=0.05, decay=0.07, sustain=0.1, bend=1.5, resonance=0.5)
    song.line("siren", arp, 20, "square", 0.32, cutoff=1700, env_amount=2200, env_decay=0.05, decay=0.07, sustain=0.1, bend=1.5, resonance=0.5)
    song.echo("siren", 3, 0.3, 2, 0.3)
    # A riser whoosh into the chopped section.
    song.sweep("fx", noise(int(song.bar * RATE), r), 12, 4, 300, 6000, 0.8, 0.5)
    song.space("stabs", 0.3)
    song.pump(["bass", "stabs"], depth=0.3, release=0.1)
    return song.save({"drums": 0.7, "kick": 0.6, "fx": 0.5, "bass": 0.7, "stabs": 1.1, "siren": 1.1})


# =====================================================================================
# 4. TOTAL SANITATION: 176 BPM hardcore breakbeat / industrial rave (DEEP CLEAN / SEWER BREACH)
# =====================================================================================

def track_total_sanitation() -> str:
    song = Song("breach", bpm=176, bars=28, seed=176)
    # A Phrygian: dark and nasty. Am - Bb - Am - Gm, one per bar.
    CHORDS = [(33, [69, 72, 76]), (34, [70, 74, 77]), (33, [69, 72, 76]), (31, [67, 70, 74])]
    r = song.rng
    kit = {"kick": lambda: kick(r, punch=160, low=52, length=0.22, dirt=4.0, click=0.7),
           "snare": lambda: snare(r, tone=230, length=0.15, bright=1800, snap=1.4),
           "hat": lambda: hat(r, 0.03)}
    BREAK = {"kick":  "X.x...X...x.....",
             "snare": "....X..o.o..X.oX",
             "hat":   "xxx.xxx.xxx.xxxx"}
    # ARRANGEMENT: drums + acid 0-7, + alarms 8-15, panic breakdown 16-19, everything 20-27
    beat = list(bars(0, 16)) + list(bars(20, 28))
    song.break_bars("drums", kit, BREAK, beat, [list(range(16)), list(range(16)), list(range(16)), [0, 1, 2, 3, 4, 5, 6, 7, 12, 13, 12, 13, 12, 12, 12, 12]], 1.0, dirt=2.5)
    song.drums("kick", lambda: kick(r, punch=200, low=48, length=0.3, dirt=6.0, click=0.4), "X...X...X...X...", list(bars(8, 16)) + list(bars(20, 28)), 0.75, is_kick=True)
    song.drums("snare", lambda: snare(r, length=0.1), "xxxxxxxxXXXXXXXX", [19], 0.5)
    for b in (0, 8, 20, 24):
        song.put("fx", crash(r), song.at(b), 0.55)
    # Aggressive acid 303 bass: 16ths with accents and slides, filter squealing, then distorted.
    PATTERN = [(0, 0), (1, 0), (2, 12), (3, 0), (4, 1), (5, 0), (6, 12), (7, 13), (8, 0), (9, 0), (10, 15), (11, 12), (12, 0), (13, 1), (14, 12), (15, 7)]
    acid = []
    for i in range(28):
        root = CHORDS[i % 4][0] + 12
        acid += [(i * 16 + s, root + up, 1) for s, up in PATTERN]
    accents = {i * 16 + s for i in range(28) for s in (0, 6, 10, 14)}
    song.line("acid", acid, 0, "saw", 0.7, cutoff=380, env_amount=2600, env_decay=0.07, resonance=0.9, decay=0.1, sustain=0.35, glide=0.012, dirt=3.0, accents=accents)
    song.line("sub", [(i * 16, CHORDS[i % 4][0], 16) for i in range(28)], 0, "sine", 0.6, decay=1.0, sustain=0.9, cutoff=400, env_amount=0)
    # Industrial alarm stabs: a two-tone siren on the chord, twice a bar.
    for b in list(bars(8, 20)) + list(bars(20, 28)):
        for s in (0, 8) if b < 16 or b >= 20 else (0, 4, 8, 12):
            song.chord("alarm", CHORDS[b % 4][1][:2], song.at(b, s), song.step * 3, 0.6, "alarm", 3200)
    # Hoover stabs too.
    for b in list(bars(8, 16)) + list(bars(20, 28)):
        for s in (3, 11):
            song.chord("stabs", [n - 12 for n in CHORDS[b % 4][1]], song.at(b, s), song.step * 1.5, 0.7, "hoover", 3500)
    # Frantic rave lead: a fast 16th-note riff (bars 20-27).
    RIFF = [(0, 81, 1), (1, 84, 1), (2, 88, 1), (3, 84, 1), (4, 82, 2), (6, 81, 1), (7, 77, 1),
            (8, 81, 1), (9, 84, 1), (10, 88, 1), (11, 89, 1), (12, 88, 2), (14, 84, 1), (15, 82, 1)]
    song.line("lead", repeat(RIFF, 16, 8, transpose=[0, 1, 0, -2]), 20, "supersaw", 0.45, cutoff=2000, env_amount=2500, env_decay=0.04, resonance=0.4, decay=0.08, sustain=0.4)
    song.echo("lead", 3, 0.3, 2, 0.3)
    # Panic breakdown: a screaming filter sweep on noise + saw.
    src_n = int(song.bar * RATE)
    song.sweep("fx", saw(np.full(src_n, hz(45))) * 0.6 + noise(src_n, r) * 0.4, 16, 4, 200, 6000, 0.92, 0.6)
    song.space("alarm", 0.3)
    song.pump(["acid", "sub", "stabs"], depth=0.35, release=0.08)
    return song.save({"drums": 0.65, "kick": 0.55, "snare": 1.0, "fx": 0.6, "acid": 0.85, "sub": 0.6, "alarm": 0.8, "stabs": 1.2, "lead": 1.4})


TRACKS = {
    "city_ridge": track_neon_apex,
    "city_wipeout": track_anti_grav,
    "escape": track_hot_paws,
    "breach": track_total_sanitation,
}


def main(argv: list) -> int:
    wanted = [a for a in argv if not a.startswith("--")] or list(TRACKS)
    for name in wanted:
        if name not in TRACKS:
            print("No track called %r. Tracks: %s" % (name, ", ".join(TRACKS)))
            return 1
        path = TRACKS[name]()
        with wave.open(path) as w:
            seconds = w.getnframes() / w.getframerate()
        print("made %s (%.1f s loop)" % (os.path.relpath(path, PROJECT_ROOT), seconds))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
