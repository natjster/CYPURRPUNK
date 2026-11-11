# 15. Making trailers (the `trailer/` folder)

[Back to the contents page](../SETUP_GUIDE.md)


The trailers are made by scripts, so you can re-make them any time the game changes (new
outfits, a new enemy...). Nothing here touches the game itself. You need **Python** and **ffmpeg**
(both already installed on this PC). Open a terminal in the project folder and run, in order:

```
python trailer/record.py      <- films every shot by playing the game (about 10 minutes)
python trailer/music.py       <- makes the soundtrack (a few seconds)
python trailer/edit.py        <- cuts the trailers together (a few minutes)
```

The finished videos land in `shots\trailer\out\`:
- `cypurrpunk_long.mp4` — the 92-second trailer, 1920x1080 (YouTube, Steam, itch.io)
- `cypurrpunk_short_*.mp4` — 20-26-second vertical (1080x1920) cuts for TikTok, Instagram Reels and
  YouTube Shorts: `heist` (the whole game in one go), `boss` (the MEGA VAC-COP), `cats` (dressing up),
  `coop` (split screen), `loop` (how a run goes, step by step).

**How it works**
- `trailer/record.py` = the **shot list**. Each line is one shot: the game starts with test options
  (where the cat stands, what it holds, what it does) and Godot's **Movie Maker** films it at a
  steady 30 fps, with the game's sound. The film camera options (`--cam_from`, `--cam_to`,
  `--cam_orbit`, `--cam_follow`, `--no_hud`...) are listed at the top of `scripts/dev_capture.gd`.
  Run one shot again with e.g. `python trailer/record.py boss_reveal`. The in-game music is muted
  while filming (the trailer has its own). Every shot happens in city #1999 so they match.
- `trailer/music.py` = the soundtrack: an original 120 BPM synthwave track made from maths (no
  samples, so no copyright problems). 1 bar = 2 seconds. `SECTIONS` says which instruments play when.
- `trailer/cards.py` = the captions and the CYPURRPUNK title, as chunky pixel letters.
- `trailer/edit.py` = the **edits**. Each trailer is a list of `(shot, start second, length, caption)`.
  Change a caption's words, swap a shot, or move its start point, then run `edit.py` again. The
  lengths must add up to the music's length (it warns you if not).
- `python trailer/contact.py` makes a picture per shot (`shots\trailer\contact\`) with a frame every
  half second, handy for picking start points.

**Thumbnail:** `python trailer/thumbnail.py` turns stills in `shots\thumb\` (`raw_a.png`, `raw_b.png`) into
1280x720 YouTube thumbnails (`thumbnail_red.jpg`, `thumbnail_blue.jpg`): logo top-left, "REVEAL TRAILER"
bottom-left (change `TAG` in the script). The stills are the hero cat with the MEGA VAC-COP behind it,
taken with DevCapture `--heat=100 --roomba=boss --no_boss_sign --bait_roomba=-7 --portrait=me --portrait_side=0.5`
(`raw_b` = after 80 frames, red siren; `raw_a` = after 40 frames, blue siren).
`thumbnail_gunfight.jpg` uses `gun_40.png`: the cat firing the PURR-TOMMY from the side as a VAC-COP explodes
(`--give=tommy_gun --pos=0,0,-20 --bait_roomba=aim --hold=shoot --hold_frames=40 --keep_holding --frames=1`
`--cam_from=-3.2,0.45,-21.6 --look_from=0.2,0.55,-21.8 --no_hud`). Each thumbnail's still, framing, logo spot and tag
are listed in `THUMBNAILS` at the top of the script.

**Uploading:** TikTok / Reels / Shorts take the vertical files as they are. Add your store link
(Steam / itch.io) in the post text; the trailers end on "COMING SOON" — change that card in `edit.py`
once there's a wishlist page.
