"""CYPURRPUNK SOUND LAB: free, local sound making for the game (no paid services).

Used by tools/sound_mcp.py (the MCP server Claude talks to) and from the command line:

    python tools/cypurr_sound.py batch tools/sound_specs/overclean.json   (every line in a list)
    python tools/cypurr_sound.py voice overclean_test "Please remain still."
    python tools/cypurr_sound.py blips don bossy 150
    python tools/cypurr_sound.py sfx bin_clatter metal_bin_clatter

What it makes (16-bit mono .wav files, straight into sounds/sfx/ unless told otherwise):
  * OVERCLEAN voice lines: free neural text-to-speech (Microsoft Edge's voices via the
    `edge-tts` package; needs internet while generating, not while playing) -> robot effect
    (ring modulator + metallic comb) -> cheap city PA speaker (narrow band, slight distortion,
    slap-back echo off the buildings) -> optional two-tone "ding-dong" chime in front.
  * Cat voice blips: Animal Crossing style "mi / mra / nya" syllables, synthesised from scratch,
    pitched and shaped by a mood. Saved as numbered variants (meow_blip_don_1.wav ...) so the
    game's Sound system picks a random one each time ("meow_blip_don").
  * Crunchy PS1 sound effects: modal synthesis (struck metal / plastic) + filtered noise,
    then sample-rate and bit crushing.

Needs: pip install numpy edge-tts ; ffmpeg on PATH (for decoding the speech).
"""
from __future__ import annotations

import asyncio
import json
import os
import shutil
import subprocess
import sys
import tempfile
import wave

import numpy as np

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOUNDS_DIR = os.path.join(PROJECT_ROOT, "sounds")
RATE = 22050  # output sample rate: plenty for a PS1-style game (and the game muffles >7 kHz)

DEFAULT_VOICE = "en-GB-SoniaNeural"  # calm, cold, polite: the voice of a building's lift


# =====================================================================================
# Basics
# =====================================================================================

def out_path(name: str, folder: str = "sfx") -> str:
    if folder not in ("sfx", "music", "ambience"):
        raise ValueError("folder must be sfx, music or ambience")
    name = os.path.basename(name)
    if not name.endswith(".wav"):
        name += ".wav"
    return os.path.join(SOUNDS_DIR, folder, name)


def write_wav(path: str, x: np.ndarray, rate: int = RATE, peak_db: float = -1.0) -> str:
    """Normalise to peak_db and save as 16-bit mono."""
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) if x.size else 0.0
    if peak > 0:
        x = x / peak * (10 ** (peak_db / 20.0))
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data.tobytes())
    return path


def _ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if exe is None:
        raise RuntimeError("ffmpeg isn't installed (winget install Gyan.FFmpeg), it's needed to decode the speech")
    return exe


def decode(path: str, pitch: float = 1.0, rate: int = RATE) -> np.ndarray:
    """Any audio file -> mono float array at `rate`. pitch = 1.2 is 20% higher, same length."""
    filters = []
    if abs(pitch - 1.0) > 1e-3:
        filters.append("asetrate=%d,aresample=%d" % (int(rate * pitch), rate))
        tempo = 1.0 / pitch
        while tempo < 0.5:
            filters.append("atempo=0.5")
            tempo /= 0.5
        while tempo > 2.0:
            filters.append("atempo=2.0")
            tempo /= 2.0
        filters.append("atempo=%.5f" % tempo)
    cmd = [_ffmpeg(), "-v", "error", "-i", path, "-ac", "1", "-ar", str(rate)]
    if filters:
        cmd += ["-af", ",".join(filters)]
    cmd += ["-f", "f32le", "-"]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype="<f4").astype(np.float64)


def band(x: np.ndarray, low: float = 0.0, high: float = 0.0, order: int = 4, rate: int = RATE) -> np.ndarray:
    """Zero-phase band-pass (low/high in Hz; 0 = no limit) done in the frequency domain."""
    n = len(x)
    if n == 0:
        return x
    size = 1 << int(np.ceil(np.log2(n * 2)))
    spec = np.fft.rfft(x, size)
    f = np.fft.rfftfreq(size, 1.0 / rate)
    gain = np.ones_like(f)
    if high > 0:
        gain *= 1.0 / np.sqrt(1.0 + (f / high) ** (2 * order))
    if low > 0:
        with np.errstate(divide="ignore"):
            gain *= 1.0 / np.sqrt(1.0 + (low / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(spec * gain, size)[:n]


def convolve(x: np.ndarray, h: np.ndarray) -> np.ndarray:
    n = len(x) + len(h) - 1
    size = 1 << int(np.ceil(np.log2(n)))
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(h, size), size)[:n]


def crush(x: np.ndarray, hold: int = 2, bits: int = 16) -> np.ndarray:
    """PS1 crunch: keep every `hold`-th sample (lower sample rate) and fewer volume steps."""
    if hold > 1:
        x = np.repeat(x[::hold], hold)[:len(x)]
    if bits < 16:
        steps = 2 ** (bits - 1)
        peak = np.max(np.abs(x)) or 1.0
        x = np.round(x / peak * steps) / steps * peak
    return x


def silence(seconds: float) -> np.ndarray:
    return np.zeros(int(seconds * RATE))


def _t(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


# =====================================================================================
# The PA chime and the OVERCLEAN voice
# =====================================================================================

def chime(high: float = 830.6, low: float = 659.3, gap: float = 0.42) -> np.ndarray:
    """The classic two-tone 'ding... dong' of a public address system (a falling major third)."""
    def bell(freq, seconds=1.3):
        t = _t(seconds)
        tone = (np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 2 * t)
                + 0.12 * np.sin(2 * np.pi * freq * 3 * t) + 0.06 * np.sin(2 * np.pi * freq * 4.2 * t) * np.exp(-t * 9))
        return tone * np.exp(-t * 3.2) * np.minimum(1.0, t / 0.004)
    a, b = bell(high), bell(low)
    out = np.zeros(int(gap * RATE) + len(b))
    out[:len(a)] += a
    out[int(gap * RATE):] += b
    return out * 0.6


def robot(x: np.ndarray, strength: float = 0.5) -> np.ndarray:
    """Machine voice: ring modulator (the classic sci-fi robot), a metallic comb and a little
    sample crunch. strength 0 = untouched, 1 = very robotic."""
    if strength <= 0:
        return x
    t = np.arange(len(x)) / RATE
    ring = x * np.sin(2 * np.pi * 52.0 * t)            # 52 Hz carrier: buzzy, still readable
    y = x * (1 - 0.6 * strength) + ring * (0.9 * strength)
    taps = np.zeros(int(0.0062 * RATE) * 6 + 1)         # 6.2 ms comb: "inside a metal box"
    for k in range(6):
        taps[int(0.0062 * RATE) * k] = (0.55 * strength) ** k
    y = convolve(y, taps)[:len(x)]
    return crush(y, hold=2 if strength > 0.3 else 1)


def pa_speaker(x: np.ndarray, reverb: float = 0.5, drive: float = 2.2) -> np.ndarray:
    """A tinny outdoor loudspeaker heard down the street: narrow band (horn speaker), slight
    distortion, slap-back echoes off buildings and a short tail. reverb 0..1."""
    y = band(x, 380.0, 3600.0, order=3)
    y = np.tanh(y / (np.max(np.abs(y)) or 1.0) * drive)
    tail = int(1.2 * RATE)
    out = np.concatenate([y, np.zeros(tail)])
    for delay, gain in ((0.115, 0.42), (0.24, 0.26), (0.41, 0.14)):  # buildings across the street
        d = int(delay * RATE)
        out[d:d + len(y)] += y * gain * reverb
    if reverb > 0:
        rng = np.random.default_rng(99)
        t = _t(0.9)
        ir = rng.standard_normal(len(t)) * np.exp(-t * 6.0)
        wet = band(convolve(y, ir)[:len(out)], 300, 2500)
        out[:len(wet)] += wet / (np.max(np.abs(wet)) or 1.0) * 0.18 * reverb
    return band(out, 250.0, 4200.0, order=2)


async def _tts(text: str, voice: str, rate: str, mp3: str) -> None:
    import edge_tts
    await edge_tts.Communicate(text, voice, rate=rate).save(mp3)


def speak(text: str, voice: str = DEFAULT_VOICE, rate: str = "-6%", pitch: float = 1.0) -> np.ndarray:
    """Free neural text-to-speech (edge-tts) -> mono float array."""
    with tempfile.TemporaryDirectory() as tmp:
        mp3 = os.path.join(tmp, "line.mp3")
        asyncio.run(_tts(text, voice, rate, mp3))
        return decode(mp3, pitch)


def overclean_voice(sound_id: str, text: str, pitch_shift: float = -1.5, robot_strength: float = 0.45,
                    pa_reverb: float = 0.55, with_chime: bool = True, voice: str = DEFAULT_VOICE,
                    rate: str = "-6%", folder: str = "sfx") -> dict:
    """One OVERCLEAN announcement -> sounds/<folder>/<sound_id>.wav.
    pitch_shift = semitones (-12..12; negative = deeper), robot_strength 0..1, pa_reverb 0..1."""
    speech = speak(text, voice, rate, 2 ** (pitch_shift / 12.0))
    # Trim the TTS's leading/trailing silence so the chime and the voice sit close together.
    loud = np.nonzero(np.abs(speech) > 0.01)[0]
    if loud.size:
        speech = speech[max(0, loud[0] - 400):loud[-1] + 1200]
    voiced = pa_speaker(robot(speech, robot_strength), pa_reverb)
    if with_chime:
        ding = pa_speaker(chime(), pa_reverb * 0.6, drive=1.2)[:int(1.25 * RATE)]
        ding = ding / (np.max(np.abs(ding)) or 1.0) * 0.7
        start = int(1.05 * RATE)
        out = np.zeros(max(len(ding), start + len(voiced)))
        out[:len(ding)] += ding
        out[start:start + len(voiced)] += voiced / (np.max(np.abs(voiced)) or 1.0)
    else:
        out = voiced
    path = write_wav(out_path(sound_id, folder), out)
    return {"file": os.path.relpath(path, PROJECT_ROOT), "seconds": round(len(out) / RATE, 2), "text": text}


# =====================================================================================
# Cat voice blips (Animal Crossing / PS1 style talking)
# =====================================================================================

# mood: (pitch contour points, syllable seconds, vibrato Hz, vibrato depth, growl 0..1, brightness)
MOODS = {
    "happy":   ([1.0, 1.22, 1.12], 0.15, 0.0, 0.0, 0.0, 1.15),
    "grumpy":  ([1.0, 0.92, 0.78], 0.22, 0.0, 0.0, 0.55, 0.8),
    "sly":     ([0.94, 1.12, 0.9], 0.21, 5.0, 0.02, 0.1, 1.0),
    "nervous": ([1.1, 1.18, 1.05], 0.12, 13.0, 0.06, 0.0, 1.2),
    "bossy":   ([1.0, 0.98, 0.84], 0.19, 0.0, 0.0, 0.35, 0.85),
    "sleepy":  ([0.98, 0.9, 0.76], 0.26, 3.0, 0.02, 0.1, 0.75),
    "angry":   ([1.05, 1.15, 0.85], 0.16, 0.0, 0.0, 0.8, 1.05),
}
# Vowel formants (F1, F2, F3 Hz) the "m..." glides into: mi, me, ma, mo, mu, nya.
VOWELS = [(320, 2300, 3000), (450, 2000, 2700), (750, 1300, 2500), (520, 900, 2400), (350, 850, 2300), (650, 1700, 2600)]


def _syllable(f0: float, mood: str, rng: np.random.Generator) -> np.ndarray:
    contour, seconds, vib_hz, vib_depth, growl, bright = MOODS[mood]
    seconds *= rng.uniform(0.85, 1.15)
    t = _t(seconds)
    shape = np.interp(t / seconds, np.linspace(0, 1, len(contour)), contour) * rng.uniform(0.94, 1.06)
    freq = f0 * shape * (1 + vib_depth * np.sin(2 * np.pi * vib_hz * t))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    v_from = VOWELS[rng.integers(len(VOWELS))]
    v_to = VOWELS[rng.integers(len(VOWELS))]
    glide = np.clip(t / seconds * 1.6, 0, 1)[:, None]
    # "m" start: the formants begin low and closed and open into the vowel.
    m_start = np.clip(t / 0.035, 0, 1)[:, None]
    formants = (np.array([250, 1100, 2400]) * (1 - m_start) + (np.array(v_from) * (1 - glide) + np.array(v_to) * glide) * m_start)
    formants = formants * bright
    out = np.zeros(len(t))
    for k in range(1, 40):
        fk = freq * k
        if np.min(fk) > 5500:
            break
        amp = np.zeros(len(t))
        for i, (bw, gain) in enumerate(((110, 1.0), (160, 0.7), (230, 0.35))):
            amp += gain * np.exp(-((fk - formants[:, i]) / bw) ** 2)
        amp = (amp + 0.03) / k ** 0.6
        amp[fk > 5500] = 0
        out += amp * np.sin(phase * k)
    if growl > 0:  # purr-like roughness
        out *= 1 - growl * 0.5 * (1 + np.sin(2 * np.pi * 34 * t))
    env = np.minimum(1, t / 0.012) * np.minimum(1, (seconds - t) / 0.05)
    env *= np.where(t < 0.03, 0.45 + 0.55 * t / 0.03, 1.0)  # the soft "m" before the vowel
    return out * np.clip(env, 0, 1)


def cat_blips(cat_id: str, base_pitch: float = 420.0, mood: str = "happy", count: int = 4, seed: int = 1,
              crunch: bool = False, soft: bool = True, folder: str = "sfx") -> dict:
    """Talking-cat syllables -> sounds/<folder>/meow_blip_<cat_id>_1.wav .. _<count>.wav.
    base_pitch Hz (kittens ~600, Don ~150), mood = one of MOODS.
    soft (default) = easy on the ear: highs rolled off, a gentle fade in and out, a bit quieter.
    crunch = the old bright PS1 bit-crushed chatter (louder and harsher)."""
    if mood not in MOODS:
        raise ValueError("mood must be one of: " + ", ".join(MOODS))
    rng = np.random.default_rng(seed)
    files = []
    for i in range(1, count + 1):
        s = _syllable(base_pitch, mood, rng)
        peak = -3.0
        if soft:
            # Keep only the warm middle (no hiss / squeak up top), then fade in over 30 ms and
            # out over the last 40% so every blip is a rounded "mm" instead of a click.
            s = band(s, 80, 2200)
            t = np.arange(len(s)) / RATE
            seconds = len(s) / RATE
            fade_in = np.clip(t / 0.03, 0, 1)
            tail = np.clip((seconds - t) / (seconds * 0.4), 0, 1)
            s = s * np.sin(fade_in * np.pi / 2) ** 2 * np.sin(tail * np.pi / 2) ** 2
            peak = -8.0
        if crunch:
            s = crush(band(s, 120, 5000), hold=2, bits=10)
        files.append(os.path.relpath(write_wav(out_path("meow_blip_%s_%d" % (cat_id, i), folder), s, peak_db=peak), PROJECT_ROOT))
    return {"files": files, "sound_id": "meow_blip_" + cat_id,
            "how_to_play": 'Sound.play("meow_blip_%s") picks a random one' % cat_id}


# =====================================================================================
# PS1 sound effects
# =====================================================================================

def _hit(modes, noise=None, seconds=1.0, rng=None) -> np.ndarray:
    """One strike: modes = [[freq Hz, decay seconds, amplitude]], noise = {gain, decay, low, high}."""
    t = _t(seconds)
    out = np.zeros(len(t))
    for freq, decay, amp in modes:
        ph = rng.uniform(0, 2 * np.pi) if rng is not None else 0.0
        out += amp * np.sin(2 * np.pi * freq * t + ph) * np.exp(-t / max(decay, 1e-3))
    out *= np.minimum(1, t / 0.002)
    if noise:
        r = rng if rng is not None else np.random.default_rng(0)
        n = r.standard_normal(len(t)) * np.exp(-t / max(noise.get("decay", 0.03), 1e-3))
        out += band(n, noise.get("low", 0), noise.get("high", 0)) * noise.get("gain", 0.5)
    return out


def _metal_modes(base, rng, decay=0.5, count=6):
    ratios = [1.0, 2.32, 3.41, 4.95, 6.7, 8.9][:count]
    return [[base * r * rng.uniform(0.97, 1.03), decay / (1 + i * 0.6), 1.0 / (1 + i * 0.5)] for i, r in enumerate(ratios)]


def _preset(name: str, p: dict, rng: np.random.Generator) -> dict:
    """Build {"duration", "hits": [...], "noise_bed": {...}} for a named preset."""
    pitch = p.get("pitch", 1.0)
    if name == "metal_bin_clatter":
        hits = [{"time": 0.0, "gain": 1.0, "seconds": 1.2, "modes": _metal_modes(205 * pitch, rng, 0.55),
                 "noise": {"gain": 0.8, "decay": 0.04, "low": 1500, "high": 7000}}]
        t, gap, gain = 0.22, 0.2, 0.7
        for _ in range(int(p.get("rattles", 7))):  # the lid rolling / wobbling to a stop
            hits.append({"time": t, "gain": gain, "seconds": 0.5, "modes": _metal_modes(rng.uniform(380, 520) * pitch, rng, 0.18, 4),
                         "noise": {"gain": 0.5, "decay": 0.015, "low": 2000, "high": 8000}})
            t += gap
            gap *= 0.72
            gain *= 0.8
        return {"duration": t + 0.8, "hits": hits}
    if name == "metal_clang":
        return {"duration": 1.4, "hits": [{"time": 0, "gain": 1, "seconds": 1.4, "modes": _metal_modes(240 * pitch, rng, 0.7),
                                           "noise": {"gain": 0.6, "decay": 0.03, "low": 1500, "high": 7000}}]}
    if name == "cone_bounce":
        hits, t, gap, gain = [], 0.0, 0.26, 1.0
        for _ in range(int(p.get("bounces", 4))):  # hollow plastic: low, short, "bonk"
            base = 185 * pitch * rng.uniform(0.95, 1.05)
            hits.append({"time": t, "gain": gain, "seconds": 0.4,
                         "modes": [[base, 0.09, 1.0], [base * 1.62, 0.06, 0.6], [base * 2.45, 0.04, 0.35], [base * 4.1, 0.025, 0.2]],
                         "noise": {"gain": 0.35, "decay": 0.012, "low": 300, "high": 3000}})
            t += gap
            gap *= 0.68
            gain *= 0.62
        return {"duration": t + 0.4, "hits": hits, "noise_bed": {"gain": 0.06, "low": 800, "high": 4000, "from": t - 0.1, "to": t + 0.25}}
    if name == "plastic_tap":
        base = 260 * pitch
        return {"duration": 0.35, "hits": [{"time": 0, "gain": 1, "seconds": 0.35, "modes": [[base, 0.07, 1], [base * 1.7, 0.04, 0.5]],
                                            "noise": {"gain": 0.3, "decay": 0.01, "low": 500, "high": 4000}}]}
    if name == "scratch":
        return {"duration": 0.75, "scratch": [{"time": s, "seconds": rng.uniform(0.12, 0.17), "low": 2200 * pitch, "high": 6500}
                                             for s in (0.0, 0.22, 0.45)][:int(p.get("strokes", 3))]}
    if name == "pa_chime":
        return {"duration": 1.8, "raw": "chime"}
    if name == "cardboard_thump":
        base = 95 * pitch  # a dull, papery "bwomp": low thud, short, lots of soft noise
        return {"duration": 0.6, "hits": [
            {"time": 0, "gain": 1, "seconds": 0.35, "modes": [[base, 0.06, 1], [base * 1.9, 0.035, 0.5], [base * 3.1, 0.02, 0.25]],
             "noise": {"gain": 0.7, "decay": 0.05, "low": 150, "high": 1800}},
            {"time": 0.16, "gain": 0.35, "seconds": 0.25, "modes": [[base * 1.2, 0.04, 1]],
             "noise": {"gain": 0.5, "decay": 0.03, "low": 200, "high": 1500}}]}
    if name == "vacuum":
        # A little robot vacuum tidying up: a motor hum that revs up and down + suction hiss.
        seconds = p.get("seconds", 1.6)
        return {"duration": seconds, "raw": "vacuum", "seconds": seconds, "pitch": pitch}
    if name == "vending_smash":
        # A cat kicks the FISH 2 GO machine: a heavy metal thump, the glass cracking, an electric
        # zap fizzing out, then a coin rattle and a can dropping into the tray.
        hits = [{"time": 0.0, "gain": 1.0, "seconds": 0.9, "modes": _metal_modes(105 * pitch, rng, 0.45),
                 "noise": {"gain": 0.9, "decay": 0.05, "low": 80, "high": 1500}},
                {"time": 0.03, "gain": 0.55, "seconds": 0.25, "modes": [[rng.uniform(3200, 4200) * pitch, 0.03, 0.6], [5600 * pitch, 0.02, 0.4]],
                 "noise": {"gain": 0.9, "decay": 0.025, "low": 3000, "high": 9000}}]
        for i in range(4):  # little glass tinkles
            hits.append({"time": 0.09 + i * rng.uniform(0.04, 0.07), "gain": 0.25, "seconds": 0.15,
                         "modes": [[rng.uniform(2800, 5000) * pitch, 0.04, 1.0]]})
        t = 0.55
        for i in range(3):  # coins bouncing
            hits.append({"time": t, "gain": 0.4 - i * 0.1, "seconds": 0.3, "modes": _metal_modes(rng.uniform(1100, 1400) * pitch, rng, 0.12, 3)})
            t += 0.07 - i * 0.015
        hits.append({"time": 0.8, "gain": 0.7, "seconds": 0.4, "modes": [[290 * pitch, 0.08, 1.0], [610 * pitch, 0.05, 0.5]],
                     "noise": {"gain": 0.4, "decay": 0.02, "low": 200, "high": 2500}})
        zaps = [{"time": 0.12, "seconds": 0.32, "low": 1500 * pitch, "high": 7000}, {"time": 0.46, "seconds": 0.12, "low": 2500 * pitch, "high": 8000}]
        return {"duration": 1.25, "hits": hits, "scratch": zaps}
    if name == "hydrant_burst":
        # The cap clangs off and a high-pressure jet roars out: a clang + two layers of water hiss.
        hits = [{"time": 0.0, "gain": 1.0, "seconds": 1.2, "modes": _metal_modes(330 * pitch, rng, 0.6),
                 "noise": {"gain": 0.6, "decay": 0.03, "low": 1200, "high": 6000}},
                {"time": 0.42, "gain": 0.45, "seconds": 0.6, "modes": _metal_modes(410 * pitch, rng, 0.3, 4)}]  # the cap landing
        seconds = p.get("seconds", 2.2)
        beds = [{"gain": 0.75, "low": 300, "high": 2500, "from": 0.02, "to": seconds},
                {"gain": 0.45, "low": 2500, "high": 9000, "from": 0.05, "to": seconds - 0.2}]
        return {"duration": seconds + 0.1, "hits": hits, "noise_beds": beds}
    if name == "cart_roll":
        # A shopping cart rattling away down the pavement: lots of tiny wire rattles over a rumble,
        # then a crash as it tips over at the end.
        seconds = p.get("seconds", 1.3)
        hits, t = [], 0.0
        while t < seconds - 0.25:
            hits.append({"time": t, "gain": rng.uniform(0.15, 0.4), "seconds": 0.12,
                         "modes": _metal_modes(rng.uniform(700, 1500) * pitch, rng, 0.05, 3),
                         "noise": {"gain": 0.2, "decay": 0.006, "low": 2000, "high": 8000}})
            t += rng.uniform(0.025, 0.06)
        hits.append({"time": seconds - 0.25, "gain": 0.9, "seconds": 0.6, "modes": _metal_modes(260 * pitch, rng, 0.35),
                     "noise": {"gain": 0.7, "decay": 0.04, "low": 800, "high": 6000}})
        return {"duration": seconds + 0.4, "hits": hits, "noise_beds": [{"gain": 0.35, "low": 60, "high": 500, "from": 0.0, "to": seconds - 0.15}]}
    if name == "sign_spark":
        # A sheet-metal sandwich board slapping down, the neon tube popping and buzzing out.
        hits = [{"time": 0.0, "gain": 0.9, "seconds": 0.5, "modes": _metal_modes(280 * pitch, rng, 0.25, 5),
                 "noise": {"gain": 0.6, "decay": 0.03, "low": 600, "high": 5000}},
                {"time": 0.06, "gain": 0.8, "seconds": 0.2, "modes": [[1900 * pitch, 0.02, 0.6]],
                 "noise": {"gain": 1.0, "decay": 0.012, "low": 400, "high": 9000}},  # the tube popping
                {"time": 0.16, "gain": 0.45, "seconds": 0.4, "modes": _metal_modes(330 * pitch, rng, 0.15, 4)},
                {"time": 0.27, "gain": 0.25, "seconds": 0.3, "modes": _metal_modes(360 * pitch, rng, 0.1, 3)},
                {"time": 0.1, "gain": 0.5, "seconds": 0.8,  # the mains buzz dying away
                 "modes": [[120 * pitch, 0.35, 0.5], [240 * pitch, 0.3, 0.6], [360 * pitch, 0.25, 0.4], [600 * pitch, 0.2, 0.3]]}]
        zaps = [{"time": 0.09, "seconds": 0.14, "low": 2500, "high": 9000}, {"time": 0.33, "seconds": 0.08, "low": 3000, "high": 9000},
                {"time": 0.52, "seconds": 0.05, "low": 3000, "high": 9000}]
        return {"duration": 1.0, "hits": hits, "scratch": zaps}
    if name == "dumpster_rummage":
        # A heavy hollow lid BANG as it flies open, a second clang as it hits the back, then the
        # rustle of a cat digging through trash bags.
        hits = [{"time": 0.0, "gain": 1.0, "seconds": 1.4, "modes": _metal_modes(78 * pitch, rng, 0.9),
                 "noise": {"gain": 0.9, "decay": 0.06, "low": 60, "high": 1200}},
                {"time": 0.28, "gain": 0.6, "seconds": 0.9, "modes": _metal_modes(96 * pitch, rng, 0.6, 5),
                 "noise": {"gain": 0.5, "decay": 0.04, "low": 80, "high": 1500}}]
        rustle = [{"time": 0.5 + i * rng.uniform(0.17, 0.24), "seconds": rng.uniform(0.12, 0.2), "low": 700 * pitch, "high": 4500}
                  for i in range(int(p.get("strokes", 4)))]
        return {"duration": 1.6, "hits": hits, "scratch": rustle}
    raise ValueError("unknown preset '%s' (try: %s)" % (name, ", ".join(PRESETS)))


PRESETS = ["metal_bin_clatter", "metal_clang", "cone_bounce", "plastic_tap", "scratch", "pa_chime", "cardboard_thump", "vacuum",
           "vending_smash", "hydrant_burst", "cart_roll", "sign_spark", "dumpster_rummage"]


def ps1_sfx(sound_id: str, preset_or_params, folder: str = "sfx") -> dict:
    """A crunchy retro effect -> sounds/<folder>/<sound_id>.wav.
    preset_or_params = a preset name (PRESETS) or a dict:
      {"preset": name, "pitch": 1.0, "seed": 1, "bits": 10, "hold": 2, ...preset knobs
       (rattles, bounces, strokes)}  or fully custom:
      {"duration": s, "hits": [{"time", "gain", "seconds", "modes": [[freq, decay, amp]],
       "noise": {"gain", "decay", "low", "high"}}]}"""
    p = {"preset": preset_or_params} if isinstance(preset_or_params, str) else dict(preset_or_params)
    rng = np.random.default_rng(p.get("seed", 1))
    recipe = _preset(p["preset"], p, rng) if "preset" in p else p
    n = int(recipe.get("duration", 1.0) * RATE)
    out = np.zeros(n)
    if recipe.get("raw") == "chime":
        c = pa_speaker(chime(), 0.4, drive=1.2)
        out = np.zeros(max(n, len(c)))
        out[:len(c)] += c
    if recipe.get("raw") == "vacuum":
        t = _t(recipe["seconds"])
        rev = 1 + 0.25 * np.sin(2 * np.pi * 1.3 * t) + 0.15 * np.minimum(1, t / 0.3)
        f0 = 140 * recipe["pitch"] * rev
        phase = 2 * np.pi * np.cumsum(f0) / RATE
        hum = np.sign(np.sin(phase)) * 0.25 + np.sin(phase * 2) * 0.3 + np.sin(phase * 3.02) * 0.15
        hiss = band(rng.standard_normal(len(t)), 900, 5000) * (0.5 + 0.3 * np.sin(2 * np.pi * 7 * t))
        env = np.minimum(1, t / 0.08) * np.minimum(1, (recipe["seconds"] - t) / 0.25)
        out = np.zeros(max(n, len(t)))
        out[:len(t)] += (hum * 0.6 + hiss * 0.5) * env
    for hit in recipe.get("hits", []):
        h = _hit(hit["modes"], hit.get("noise"), hit.get("seconds", 1.0), rng) * hit.get("gain", 1.0)
        start = int(hit.get("time", 0) * RATE)
        end = min(n, start + len(h))
        if start < n:
            out[start:end] += h[:end - start]
    for bed in ([recipe["noise_bed"]] if recipe.get("noise_bed") else []) + recipe.get("noise_beds", []):  # (one or a list)
        a, b = int(bed.get("from", 0) * RATE), int(bed.get("to", recipe["duration"]) * RATE)
        a, b = max(0, a), min(n, b)
        if b > a:
            seg = band(rng.standard_normal(b - a), bed.get("low", 0), bed.get("high", 0)) * bed.get("gain", 0.1)
            out[a:b] += seg * np.hanning(b - a)
    for s in recipe.get("scratch", []):  # claws: noise chopped by a jittery saw = the "skrrt"
        t = _t(s["seconds"])
        chop = (np.mod(t * rng.uniform(55, 90), 1.0) < 0.55).astype(float)
        stroke = band(rng.standard_normal(len(t)), s["low"], s["high"]) * chop
        stroke *= np.sin(np.pi * t / s["seconds"]) ** 0.7
        start = int(s["time"] * RATE)
        end = min(n, start + len(t))
        out[start:end] += stroke[:end - start]
    out = crush(out, hold=int(p.get("hold", 2)), bits=int(p.get("bits", 10)))
    path = write_wav(out_path(sound_id, folder), out)
    return {"file": os.path.relpath(path, PROJECT_ROOT), "seconds": round(len(out) / RATE, 2)}


# =====================================================================================
# Player cat taunts (the MEOW button: a meow, then a squeaky little cat voice talking back)
# =====================================================================================

def cat_taunt(sound_id: str, text: str = "Go lick yourself!", voice: str = "en-US-AnaNeural", pitch_shift: float = 5.0,
              rate: str = "+8%", meow_pitch: float = 520.0, mood: str = "sly", seed: int = 3, folder: str = "sfx") -> dict:
    """A cat's MEOW-button taunt -> sounds/<folder>/<sound_id>.wav: a synthesised meow syllable, then
    "text" in a squeaky TTS cat voice (pitched up pitch_shift semitones), crunched to PS1 quality.
    The game changes the pitch per cat (scripts/cat_player.gd voice_pitch), so one file serves every cat."""
    rng = np.random.default_rng(seed)
    meow = _syllable(meow_pitch, mood, rng)
    meow = np.concatenate([meow, _syllable(meow_pitch * 1.15, mood, rng)[: int(0.12 * RATE)]])
    speech = speak(text, voice, rate, 2 ** (pitch_shift / 12.0))
    loud = np.nonzero(np.abs(speech) > 0.01)[0]
    if loud.size:
        speech = speech[max(0, loud[0] - 300):loud[-1] + 800]
    speech = speech / (np.max(np.abs(speech)) or 1.0)
    # A little nasal "cat mouth" colour: thin out the lows, add a fast wobble.
    speech = band(speech, 280, 6000) * (1 + 0.08 * np.sin(2 * np.pi * 9 * _t(len(speech) / RATE)))
    meow = meow / (np.max(np.abs(meow)) or 1.0) * 0.8
    out = np.concatenate([meow, silence(0.06), speech])
    out = crush(out, hold=2, bits=11)
    path = write_wav(out_path(sound_id, folder), out, peak_db=-2.0)
    return {"file": os.path.relpath(path, PROJECT_ROOT), "seconds": round(len(out) / RATE, 2), "text": text}


# =====================================================================================
# Batches (a JSON list of jobs, so a whole set of lines can be remade with one command)
# =====================================================================================

def run_batch(path: str) -> list:
    """A JSON file: {"jobs": [{"kind": "voice"|"blips"|"taunt"|"sfx", ...the function's arguments}]}"""
    with open(path, "r", encoding="utf-8") as f:
        jobs = json.load(f)["jobs"]
    results = []
    for job in jobs:
        job = dict(job)
        kind = job.pop("kind")
        job.pop("note", None)
        if kind == "voice":
            results.append(overclean_voice(**job))
        elif kind == "blips":
            results.append(cat_blips(**job))
        elif kind == "taunt":
            results.append(cat_taunt(**job))
        elif kind == "sfx":
            results.append(ps1_sfx(job["sound_id"], job["params"], job.get("folder", "sfx")))
        print(json.dumps(results[-1]))
    return results


def main(argv: list) -> int:
    if not argv:
        print(__doc__)
        return 1
    cmd = argv[0]
    if cmd == "batch":
        run_batch(argv[1])
    elif cmd == "voice":
        print(overclean_voice(argv[1], argv[2]))
    elif cmd == "blips":
        print(cat_blips(argv[1], float(argv[3]) if len(argv) > 3 else 420.0, argv[2] if len(argv) > 2 else "happy"))
    elif cmd == "sfx":
        print(ps1_sfx(argv[1], json.loads(argv[2]) if argv[2].startswith("{") else argv[2]))
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
