"""CYPURRPUNK - makes the crunchy PS1 GUN + LAUNCHER sounds (no internet, no tool server needed).

    python tools/make_gun_sfx.py

Writes into sounds/sfx/ (each gun scene picks its sound by name in the Inspector: "Shot Sound" etc.):
    gun_pistol.wav        PAW-PISTOL      - punchy "POK" with a low thump under it
    gun_tommy.wav         PURR-TOMMY      - short tight "tak" (fires 12 a second, so it stays short)
    gun_hairball.wav      HAIRBALL BLASTER- wet shotgun "BWOMF" + a pump "chk-chk" at the end
    laser_hum.wav         THE RED DOT     - a LOOPING electric hum, plays while the trigger is held
    laser_on.wav          THE RED DOT     - little rising "zwip" when the beam switches on
    launch_cucumber.wav   CUCUMBER LAUNCHER - hollow tube "THOONK"
    launch_zooka.wav      YARN-ZOOKA      - charge whine into a "VWOOMP"
    lob_whirr.wav         both launchers  - LOOPING spinning whirr on the shot while it flies
    cucumber_bounce.wav   CUCUMBER LAUNCHER - rubbery "boink" on each hop
    blast_cucumber.wav    CUCUMBER LAUNCHER - big crunchy boom
    blast_yarn.wav        YARN-ZOOKA      - electric stun "BZZZT-pop"
    launcher_ready.wav    both launchers  - "chk-CHAK" reload when you can fire again (only you hear it)

The PS1 crunch comes from: a low sample rate (22050), "sample hold" (each sample repeated = gritty
aliasing) and bit crushing (few loudness steps). Change the numbers below and run it again to retune
(Godot re-imports by itself). Loops are built from whole wave cycles so they never click.
"""
import wave
from pathlib import Path

import numpy as np

RATE = 22050  # low sample rate on purpose: sounds a bit PS1
OUT = Path(__file__).resolve().parent.parent / "sounds" / "sfx"
RNG = np.random.default_rng(1999)


# ---------- building blocks ----------

def t_of(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.002, decay=0.1):
    """Fast attack, exponential decay ("decay" = seconds to fall to about 5%)."""
    t = np.arange(n) / RATE
    return np.clip(t / max(attack, 1e-4), 0, 1) * np.exp(-t * 3.0 / max(decay, 1e-4))


def sweep(f_from, f_to, seconds, shape="sine", curve=3.0):
    """A tone whose pitch slides from f_from to f_to (exponential-ish, fast at first)."""
    t = t_of(seconds)
    k = 1 - np.exp(-curve * t / seconds)
    k = k / max(k[-1], 1e-6)
    freq = f_from + (f_to - f_from) * k
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    if shape == "square":
        return np.sign(np.sin(phase))
    if shape == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1.0) - 1
    return np.sin(phase)


def noise(seconds):
    return RNG.uniform(-1, 1, int(RATE * seconds))


def lowpass(x, amount):
    """Cheap one-pole low-pass. amount 0..1: higher = darker."""
    y = np.zeros_like(x)
    acc = 0.0
    a = 1 - amount
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def loop_lowpass(x, amount):
    """Low-pass for a LOOP: filtered twice round, so the end flows into the start (no click)."""
    return lowpass(np.tile(x, 2), amount)[len(x):]


def highpass(x, amount):
    return x - lowpass(x, amount)


def drive(x, amount=2.0):
    """Soft clip: makes things louder and grittier."""
    return np.tanh(x * amount) / np.tanh(amount)


def mix(*parts):
    """Add sounds that may have different lengths: [(sound, start_seconds, gain), ...]."""
    end = max(int(start * RATE) + len(s) for s, start, _ in parts)
    out = np.zeros(end)
    for s, start, gain in parts:
        i = int(start * RATE)
        out[i:i + len(s)] += s * gain
    return out


def crunch(x, hold=2, bits=6):
    """The PS1 bit: sample hold (gritty aliasing) + bit crush."""
    if hold > 1:
        x = np.repeat(x[::hold], hold)[:len(x)]
    steps = 2 ** bits
    return np.round(x * steps) / steps


def save(name, x, volume=0.8, hold=2, bits=6, normalise=True):
    if normalise:
        x = x / max(np.max(np.abs(x)), 1e-6)
    x = crunch(np.clip(x * volume, -1, 1), hold, bits)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)
    print("wrote", OUT / name, "%.2fs" % (len(x) / RATE))


# ---------- the guns ----------

def gun_pistol():
    # "POK": a bright noise crack on top, a pitch-dropping square thump underneath (the oomph).
    crack = highpass(noise(0.08), 0.6) * env(int(RATE * 0.08), 0.0005, 0.03)
    body = sweep(420, 70, 0.22, "square", 4.0) * env(int(RATE * 0.22), 0.001, 0.12)
    sub = sweep(120, 45, 0.25) * env(int(RATE * 0.25), 0.002, 0.18)
    tail = lowpass(noise(0.3), 0.85) * env(int(RATE * 0.3), 0.01, 0.2)
    return drive(mix((crack, 0, 1.0), (body, 0, 0.6), (sub, 0, 0.9), (tail, 0.01, 0.6)), 2.5)


def gun_tommy():
    # Short and tight so 12 shots a second still rattle instead of mushing together.
    crack = highpass(noise(0.05), 0.5) * env(int(RATE * 0.05), 0.0005, 0.02)
    body = sweep(600, 110, 0.1, "square", 5.0) * env(int(RATE * 0.1), 0.001, 0.06)
    sub = sweep(150, 60, 0.12) * env(int(RATE * 0.12), 0.001, 0.08)
    return drive(mix((crack, 0, 1.0), (body, 0, 0.55), (sub, 0, 0.8)), 2.2)


def gun_hairball():
    # Wet shotgun: big dark boom + a squishy low "bwomf", then the pump racks back.
    boom = lowpass(noise(0.45), 0.7) * env(int(RATE * 0.45), 0.001, 0.25)
    crack = highpass(noise(0.06), 0.5) * env(int(RATE * 0.06), 0.0005, 0.03)
    bwomf = sweep(260, 38, 0.35, "saw", 3.0) * env(int(RATE * 0.35), 0.002, 0.22)
    bwomf = lowpass(bwomf, 0.6)
    sub = sweep(90, 32, 0.4) * env(int(RATE * 0.4), 0.003, 0.3)
    chk = lambda f: (highpass(noise(0.035), 0.3) * 0.7 + sweep(f, f * 0.6, 0.035, "square") * 0.4) * env(int(RATE * 0.035), 0.0005, 0.02)
    return drive(mix((crack, 0, 0.9), (boom, 0, 1.0), (bwomf, 0, 0.8), (sub, 0, 1.0),
                     (chk(1800), 0.36, 0.35), (chk(1300), 0.43, 0.45)), 2.8)


def laser_hum():
    # 1 second loop. Every frequency is a whole number of cycles per second, so the loop is seamless.
    t = t_of(1.0)
    wobble = 1 + 0.18 * np.sin(2 * np.pi * 6 * t)              # the "wah-wah" throb, 6 a second
    base = 2 * ((110 * t) % 1.0) - 1                            # buzzy saw
    fifth = np.sign(np.sin(2 * np.pi * 165 * t)) * 0.35         # square a fifth up: electric
    sub = np.sin(2 * np.pi * 55 * t) * 0.8                      # the deep hum you feel
    shimmer = np.sin(2 * np.pi * 880 * t + 2 * np.sin(2 * np.pi * 3 * t)) * 0.12
    x = (base * 0.55 + fifth + sub) * wobble + shimmer
    return drive(loop_lowpass(x, 0.35), 1.6)


def laser_on():
    zip_up = sweep(200, 1400, 0.12, "square", 2.0) * env(int(RATE * 0.12), 0.002, 0.1)
    return mix((zip_up, 0, 0.7), (sweep(55, 110, 0.12) * env(int(RATE * 0.12), 0.002, 0.1), 0, 0.6))


# ---------- the launchers ----------

def launch_cucumber():
    # Hollow tube "THOONK": a pop of air, a low drop, and the tube ringing.
    pff = lowpass(noise(0.12), 0.5) * env(int(RATE * 0.12), 0.001, 0.06)
    thoonk = sweep(240, 60, 0.35) * env(int(RATE * 0.35), 0.001, 0.25)
    ring = (np.sin(2 * np.pi * 420 * t_of(0.4)) + 0.5 * np.sin(2 * np.pi * 690 * t_of(0.4))) * env(int(RATE * 0.4), 0.005, 0.3)
    sub = sweep(80, 35, 0.4) * env(int(RATE * 0.4), 0.002, 0.3)
    return drive(mix((pff, 0, 0.9), (thoonk, 0, 1.0), (ring, 0.01, 0.25), (sub, 0, 0.9)), 2.6)


def launch_zooka():
    # A quick charge-up whine, then the "VWOOMP" as it goes, and a whoosh trailing off.
    whine = sweep(300, 1600, 0.12, "square", 1.0) * env(int(RATE * 0.12), 0.03, 0.5)
    vwoomp = sweep(330, 50, 0.4, "saw", 3.0) * env(int(RATE * 0.4), 0.001, 0.25)
    sub = sweep(100, 35, 0.45) * env(int(RATE * 0.45), 0.002, 0.32)
    whoosh = lowpass(noise(0.5), 0.75) * env(int(RATE * 0.5), 0.05, 0.3)
    return drive(mix((whine, 0, 0.35), (vwoomp, 0.1, 0.8), (sub, 0.1, 1.0), (whoosh, 0.1, 0.7)), 2.4)


def lob_whirr():
    # 0.5 s loop: a wobbling whirr (8 wobbles a second x 0.5 s = whole cycles, so seamless).
    t = t_of(0.5)
    whirr = np.sin(2 * np.pi * 300 * t + 3 * np.sin(2 * np.pi * 16 * t))
    flutter = 0.6 + 0.4 * np.sin(2 * np.pi * 8 * t)
    return loop_lowpass(whirr * flutter, 0.4)


def cucumber_bounce():
    boink = sweep(180, 520, 0.14, "sine", 2.0) * env(int(RATE * 0.14), 0.001, 0.1)
    thud = lowpass(noise(0.05), 0.6) * env(int(RATE * 0.05), 0.0005, 0.03)
    return mix((boink, 0, 0.9), (thud, 0, 0.7))


def blast_cucumber():
    # Big crunchy boom: crack, a long dark rumble, a sub drop and some crackle in the tail.
    crack = highpass(noise(0.1), 0.4) * env(int(RATE * 0.1), 0.0005, 0.05)
    rumble = lowpass(noise(1.1), 0.88) * env(int(RATE * 1.1), 0.002, 0.7)
    sub = sweep(110, 28, 0.9) * env(int(RATE * 0.9), 0.002, 0.6)
    pops = np.zeros(int(RATE * 0.8))
    for _ in range(14):  # bits of cucumber sizzling
        i = RNG.integers(int(RATE * 0.1), len(pops) - 200)
        pops[i:i + 120] += RNG.uniform(-1, 1, 120) * env(120, 0.0002, 0.003) * RNG.uniform(0.3, 1)
    return drive(mix((crack, 0, 1.0), (rumble, 0, 1.3), (sub, 0, 1.1), (pops, 0.05, 0.5)), 3.0)


def blast_yarn():
    # Electric stun: a zap, a 60 Hz buzz that crackles, a falling "bzzt" and a soft pop.
    t = t_of(0.7)
    zap = highpass(noise(0.08), 0.3) * env(int(RATE * 0.08), 0.0005, 0.04)
    buzz = np.sign(np.sin(2 * np.pi * 60 * t)) * (0.5 + 0.5 * (RNG.uniform(0, 1, len(t)) > 0.6))
    buzz = lowpass(buzz, 0.3) * env(len(t), 0.002, 0.5)
    bzzt = sweep(1800, 120, 0.5, "square", 2.0) * env(int(RATE * 0.5), 0.001, 0.4)
    pop = sweep(200, 50, 0.3) * env(int(RATE * 0.3), 0.001, 0.2)
    return drive(mix((zap, 0, 1.0), (buzz, 0, 0.6), (bzzt, 0, 0.35), (pop, 0, 1.0)), 2.4)


def launcher_ready():
    # Reload: "chk" (slide back) then "CHAK" (slide home), metallic.
    def click(f, seconds):
        n = int(RATE * seconds)
        return (highpass(noise(seconds), 0.3) * 0.8 + np.sign(np.sin(2 * np.pi * f * t_of(seconds))) * 0.4) * env(n, 0.0005, seconds * 0.5)
    return mix((click(1500, 0.04), 0, 0.55), (click(950, 0.06), 0.09, 1.0))


if __name__ == "__main__":
    save("gun_pistol.wav", gun_pistol(), 0.85)
    save("gun_tommy.wav", gun_tommy(), 0.75)
    save("gun_hairball.wav", gun_hairball(), 0.9)
    save("laser_hum.wav", laser_hum(), 0.7, hold=2, bits=7)
    save("laser_on.wav", laser_on(), 0.6)
    save("launch_cucumber.wav", launch_cucumber(), 0.9)
    save("launch_zooka.wav", launch_zooka(), 0.9)
    save("lob_whirr.wav", lob_whirr(), 0.5, bits=7)
    save("cucumber_bounce.wav", cucumber_bounce(), 0.6)
    save("blast_cucumber.wav", blast_cucumber(), 0.95, hold=3, bits=5)
    save("blast_yarn.wav", blast_yarn(), 0.85, hold=2, bits=5)
    save("launcher_ready.wav", launcher_ready(), 0.55)
