"""Cuts the trailers together from the filmed clips (trailer/record.py), the music
(trailer/music.py) and the captions (trailer/cards.py).

    python trailer/edit.py            (makes every trailer)
    python trailer/edit.py long       (just one: long, short_heist, short_boss, short_cats, short_coop, short_loop)

Output: shots/trailer/out/*.mp4  (long = 1920x1080, shorts = 1080x1920 for TikTok / Reels / Shorts)

HOW AN EDIT IS WRITTEN: a list of segments, played one after the other:
    (clip, in_seconds, length_seconds, caption)
  clip     = a clip name from record.py, or "black" for a plain card
  in       = where in that clip to start (clips spend their first ~1 s loading, so >= 1.0)
  caption  = None, or (lines, style): style "card" = big middle text, "low" = lower-third,
             "logo" = the CYPURRPUNK title (lines[0] = tagline)
Music: MUSIC_BARS picks which bars of music.wav play under it (1 bar = 2 s); the segments'
lengths must add up to the same total.
"""
import subprocess
import sys
from pathlib import Path

import cards

ROOT = Path(__file__).resolve().parent.parent / "shots" / "trailer"
CLIPS = ROOT / "clips"
WORK = ROOT / "work"
OUT = ROOT / "out"
BAR = 2.0
FPS = 30

# Brighten the (very dark) game picture a bit for small screens and compressed video.
GRADE = "eq=gamma=1.35:brightness=0.02:saturation=1.25:contrast=1.05"

# ---------------------------------------------------------------------------------------------
# THE LONG TRAILER (92 s, whole track)
# ---------------------------------------------------------------------------------------------
LONG = [
    # intro: pad + rain (0-16 s)
    ("black", 0, 2.0, (["1999."], "card")),
    ("city_orbit", 2.5, 4.0, (["THE CITY NEVER SLEEPS"], "low")),
    ("avenue_crane", 1.0, 4.0, None),
    ("black", 0, 2.0, (["THE FISH ARE UP THERE."], "card")),
    ("street_walk", 1.0, 4.0, None),
    # groove: the hub (16-32 s)
    ("hub_reveal", 1.0, 4.0, (["BELOW THE STREETS..."], "low")),
    ("don_push", 2.8, 3.0, (["DON CATLEONE HAS A JOB FOR YOU"], "low")),
    ("don_talk", 1.0, 3.0, None),
    ("whiskers_push", 3.0, 2.0, (["GEAR UP"], "low")),
    ("shop", 1.0, 2.0, None),
    ("grab_fish", 1.0, 2.0, (["GRAB THE FISH"], "low")),
    # build (32-36 s)
    ("grab_koi", 0.8, 2.0, (["GET GREEDY"], "low")),
    ("black", 0, 1.0, (["BUT..."], "card")),
    ("roomba_chase", 1.0, 1.0, None),
    # DROP (36-68 s)
    ("roomba_chase", 2.0, 4.0, (["THE VAC-COPS ARE WATCHING"], "low")),
    ("gunfight", 1.0, 3.0, None),
    ("gunfight_side", 1.0, 3.0, None),
    ("zoomies", 1.5, 2.0, None),
    ("black", 0, 2.0, (["THE MORE YOU TAKE", "THE HOTTER IT GETS"], "card")),
    ("boss_reveal", 1.3, 3.0, (["MEGA VAC-COP"], "low")),
    ("boss_fight", 1.0, 4.0, None),
    ("car_cine", 1.0, 3.0, None),
    ("car_drive", 2.0, 2.0, None),
    ("meow_mart", 1.2, 2.0, None),
    ("extract", 1.0, 4.0, (["GET OUT ALIVE"], "low")),
    # breather: co-op + cats (68-76 s)
    ("split4", 1.5, 4.0, (["UP TO 8 PLAYERS", "ONLINE + COUCH CO-OP"], "low")),
    ("outfit0", 0.6, 0.67, (["DRESS TO KILL"], "low")),
    ("outfit1", 0.6, 0.67, (["DRESS TO KILL"], "low")),
    ("outfit2", 0.6, 0.66, (["DRESS TO KILL"], "low")),
    ("outfit3", 0.6, 0.67, (["DRESS TO KILL"], "low")),
    ("outfit4", 0.6, 0.67, (["DRESS TO KILL"], "low")),
    ("outfit5", 0.6, 0.66, (["DRESS TO KILL"], "low")),
    # final run: one cut a beat... then two (76-84 s)
    ("gunfight", 2.3, 1.0, None),
    ("boss_fight", 4.3, 1.0, None),
    ("car_cine", 6.0, 1.0, None),
    ("roomba_chase", 2.0, 1.0, None),
    ("mittens", 1.5, 1.0, None),
    ("zoomies", 3.0, 1.0, None),
    ("gunfight_side", 2.0, 1.0, None),
    ("extract", 2.0, 1.0, None),
    # title (84-92 s)
    ("black", 0, 6.0, (["STEAL FISH. DODGE ROOMBAS. GET OUT."], "logo")),
    ("black", 0, 2.0, (["COMING SOON"], "card")),
]
LONG_MUSIC = [(0, 46)]

# ---------------------------------------------------------------------------------------------
# THE SHORTS (vertical). Footage is a square cut from the middle of the picture,
# with a headline above and captions below. Each is 18-30 s.
# ---------------------------------------------------------------------------------------------
SHORTS = {
    # The whole game in 26 s: the heist.
    "short_heist": {
        "headline": ["YOU'RE A CAT.", "THE COPS ARE ROOMBAS."],
        "music": [(16, 26), (42, 45)],  # build + drop, then the title hit
        "edit": [
            ("street_walk", 1.0, 2.0, (["1999. NEON CITY."], "low")),
            ("grab_fish", 1.0, 2.0, (["STEAL FISH"], "low")),
            ("roomba_chase", 1.5, 3.0, (["RUN"], "low")),
            ("gunfight", 1.0, 3.0, (["FIGHT BACK"], "low")),
            ("boss_reveal", 1.3, 3.0, (["UH OH"], "low")),
            ("car_cine", 1.0, 3.0, (["GETAWAY"], "low")),
            ("extract", 1.0, 4.0, (["GET OUT ALIVE"], "low")),
            ("black", 0, 6.0, (["STEAL FISH. DODGE ROOMBAS."], "logo")),
        ],
    },
    # The boss.
    "short_boss": {
        "headline": ["TOO MUCH HEAT", "BRINGS THE MEGA VAC-COP"],
        "music": [(16, 24), (42, 45)],
        "edit": [
            ("grab_koi", 0.8, 2.0, (["ONE MORE FISH..."], "low")),
            ("zoomies", 1.5, 2.0, None),
            ("boss_reveal", 1.0, 4.0, (["MEGA VAC-COP"], "low")),
            ("boss_fight", 1.0, 5.0, None),
            ("roomba_chase", 1.5, 3.0, (["RUN."], "low")),
            ("black", 0, 6.0, (["STEAL FISH. DODGE ROOMBAS."], "logo")),
        ],
    },
    # Dress your cat.
    "short_cats": {
        "headline": ["DRESS YOUR CAT", "FOR THE HEIST"],
        "music": [(8, 16), (42, 44)],
        "edit": [
            ("creator", 0.6, 2.0, None),
            *[(f"outfit{n}", 0.6, 2.0, None) for n in range(6)],
            ("street_walk", 1.0, 2.0, (["NOW GO STEAL FISH"], "low")),
            ("black", 0, 4.0, (["YOUR CAT. YOUR CREW."], "logo")),
        ],
    },
    # Couch co-op.
    "short_coop": {
        "headline": ["4 CATS. 1 COUCH.", "8 ONLINE."],
        "music": [(18, 26), (42, 45)],
        "edit": [
            ("split4", 1.5, 5.0, (["SPLIT-SCREEN CO-OP"], "low")),
            ("car_drive", 1.5, 3.0, (["ONE GETAWAY CAR"], "low")),
            ("gunfight", 1.0, 3.0, (["TOO MANY ROOMBAS"], "low")),
            ("extract", 1.0, 3.0, (["EVERYBODY OUT"], "low")),
            ("split4", 3.5, 2.0, None),
            ("black", 0, 6.0, (["PLAY WITH YOUR FRIENDS"], "logo")),
        ],
    },
    # How a run goes, step by step.
    "short_loop": {
        "headline": ["HOW TO ROB", "A CYBERPUNK CITY"],
        "music": [(8, 18), (42, 45)],
        "edit": [
            ("don_talk", 1.0, 3.0, (["1. TAKE A JOB"], "low")),
            ("shop", 1.0, 3.0, (["2. GEAR UP"], "low")),
            ("avenue_crane", 1.0, 3.0, (["3. GO UP TOP"], "low")),
            ("grab_fish", 1.0, 3.0, (["4. STEAL FISH"], "low")),
            ("roomba_chase", 1.5, 3.0, (["5. DON'T GET VACUUMED"], "low")),
            ("extract", 1.0, 5.0, (["6. GET OUT"], "low")),
            ("black", 0, 6.0, (["REPEAT. GET RICH."], "logo")),
        ],
    },
}


def run(args: list[str]) -> None:
    result = subprocess.run(["ffmpeg", "-v", "error", "-y", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr[-3000:])


def caption_png(lines: list[str], style: str, size: tuple[int, int], vertical: bool, key: str) -> Path:
    path = WORK / "cards" / f"{key}.png"
    if style == "logo":
        cards.logo_png(path, size, pixel=9 if vertical else 12, tagline=lines[0], centre_y=0.45)
    elif style == "card":
        cards.text_png(path, lines, size, pixel=6 if vertical else 7, font_px=12, color=cards.WHITE, centre_y=0.5)
    else:  # "low" = lower third (in the shorts: the band under the square picture)
        cards.text_png(path, lines, size, pixel=8 if vertical else 5, font_px=12, color=cards.YELLOW,
                       centre_y=0.8 if vertical else 0.84, box=not vertical)
    return path


def make_segment(n: int, seg: tuple, size: tuple[int, int], vertical: bool, headline: Path | None, tag: str) -> Path:
    clip, start, length, caption = seg
    out = WORK / f"{tag}_{n:02d}.mp4"
    w, h = size
    inputs: list[str] = []
    if clip == "black":
        inputs += ["-f", "lavfi", "-t", str(length), "-i", f"color=c=0x0a0410:s={w}x{h}:r={FPS}",
                   "-f", "lavfi", "-t", str(length), "-i", "anullsrc=r=48000:cl=stereo"]
        picture = "[0:v]null[pic]"
        audio = "[1:a]anull[aud]"
    else:
        inputs += ["-ss", str(start), "-t", str(length), "-i", str(CLIPS / f"{clip}.avi")]
        if vertical:
            # A square from the middle of the 16:9 picture, blown up to the full width; on a dark
            # backdrop made from the same picture (blurred + darkened) so it never looks empty.
            picture = (f"[0:v]{GRADE},split[a][b];"
                       f"[a]crop=720:720,scale={w}:{w}:flags=neighbor[sq];"
                       f"[b]scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h},boxblur=20,eq=brightness=-0.25[bg];"
                       f"[bg][sq]overlay=0:(H-h)/2-60[pic]")
        else:
            picture = f"[0:v]{GRADE},scale={w}:{h}:flags=neighbor[pic]"
        audio = "[0:a]volume=0.7,aresample=48000[aud]"
    layers = []
    if headline is not None and clip != "black":
        layers.append(headline)
    if caption is not None:
        layers.append(caption_png(caption[0], caption[1], size, vertical, f"{tag}_{n:02d}"))
    graph = picture
    last = "pic"
    for i, layer in enumerate(layers):
        inputs += ["-loop", "1", "-framerate", str(FPS), "-t", str(length + 0.5), "-i", str(layer)]
        index = (2 if clip == "black" else 1) + i
        fade = f",fade=in:st=0:d=0.15:alpha=1" if layer != headline else ""
        graph += f";[{index}:v]format=rgba{fade}[l{i}];[{last}][l{i}]overlay=0:0:eof_action=pass[o{i}]"
        last = f"o{i}"
    # Exactly the right number of frames (the last frame is repeated if a clip runs short).
    frames = round(length * FPS)
    graph += (f";[{last}]fps={FPS},tpad=stop_mode=clone:stop_duration=2,trim=end_frame={frames},setpts=PTS-STARTPTS,"
              f"format=yuv420p,setsar=1[v];{audio.replace('[aud]', ',apad[ap]')};[ap]atrim=end_sample={round(frames / FPS * 48000)}[a]")
    run([*inputs, "-filter_complex", graph, "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-preset", "medium",
         "-crf", "16", "-r", str(FPS), "-c:a", "pcm_s16le", "-ar", "48000", "-ac", "2", str(out)])
    return out


def music_for(bars: list[tuple[int, int]], tag: str) -> Path:
    """Cuts the chosen bar ranges out of music.wav and joins them (each a whole number of bars)."""
    out = WORK / f"{tag}_music.wav"
    parts = "".join(f"[0:a]atrim={a * BAR}:{b * BAR},asetpts=PTS-STARTPTS[m{i}];" for i, (a, b) in enumerate(bars))
    joins = "".join(f"[m{i}]" for i in range(len(bars)))
    run(["-i", str(ROOT / "music.wav"), "-filter_complex", f"{parts}{joins}concat=n={len(bars)}:v=0:a=1,afade=out:st="
         f"{sum(b - a for a, b in bars) * BAR - 1.5}:d=1.5[m]", "-map", "[m]", str(out)])
    return out


def build(tag: str, edit: list, music_bars: list, size: tuple[int, int], vertical: bool, headline_lines=None) -> Path:
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    total = sum(seg[2] for seg in edit)
    music_len = sum(b - a for a, b in music_bars) * BAR
    if abs(total - music_len) > 0.05:
        print(f"!! {tag}: pictures are {total:.2f} s but the music is {music_len:.2f} s")
    headline = None
    if headline_lines:
        headline = cards.text_png(WORK / "cards" / f"{tag}_headline.png", headline_lines, size, pixel=6, font_px=12,
                                  color=cards.WHITE, centre_y=0.13)
    segments = [make_segment(n, seg, size, vertical, headline, tag) for n, seg in enumerate(edit)]
    music = music_for(music_bars, tag)
    out = OUT / f"cypurrpunk_{tag}.mp4"
    # Join every segment (re-encoded once, so they all match), then lay the music on top with the
    # game sound (shots, booms, rain) underneath it.
    inputs = [arg for s in segments for arg in ("-i", str(s))]
    joins = "".join(f"[{i}:v][{i}:a]" for i in range(len(segments)))
    m = len(segments)
    run([*inputs, "-i", str(music), "-filter_complex",
         f"{joins}concat=n={m}:v=1:a=1[v][g0];[g0]volume=0.55[g];[{m}:a]volume=1.0[mu];"
         # -14 LUFS = the loudness YouTube / TikTok / Instagram play everything at.
         f"[g][mu]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[a]",
         # High quality but a sensible size (the rain makes video big): capped at 20 Mbit/s.
         "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-preset", "slow", "-crf", "19",
         "-maxrate", "20M", "-bufsize", "40M", "-pix_fmt", "yuv420p",
         "-r", str(FPS), "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", str(out)])
    print(f"made {out}  ({total:.1f} s)")
    return out


if __name__ == "__main__":
    wanted = sys.argv[1:] or ["long", *SHORTS]
    for name in wanted:
        if name == "long":
            build("long", LONG, LONG_MUSIC, (1920, 1080), False)
        else:
            short = SHORTS[name]
            build(name, short["edit"], short["music"], (1080, 1920), True, short["headline"])
