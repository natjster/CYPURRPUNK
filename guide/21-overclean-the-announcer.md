# 21. OVERCLEAN, the announcer (`scripts/overclean_announcer.gd`)

[Back to the contents page](../SETUP_GUIDE.md)


OVERCLEAN talks over the city's loudspeakers: a two-tone chime, then a calm, polite, slightly
robotic voice with an echo off the buildings. **Nothing appears at the bottom of the screen:** the
words **type out as floating cyan text beside the horns of the LOUDSPEAKER POLE NEAREST YOU**, in
time with the voice, and vanish a moment after it ends. Only that one pole shows them, and only
when you're within about **10 m** of it (split screen: each player gets their own nearest pole).
Walk over to another pole halfway through and the words carry on there.

### The loudspeaker poles
- A tall steel pole on a concrete base, a junction box with an OVERCLEAN stencil, three flared
  megaphone horns facing the street, and a little light on top that blinks **red and cyan while
  OVERCLEAN talks**. Model: `models/loudspeaker.glb` (104 triangles, 64x64 texture; master copy
  `models/blockbench/loudspeaker.bbmodel`, recipe `tools/model_specs/loudspeaker.json`, §20).
- Scene: `scenes/props/loudspeaker.tscn`:
  ```
  Loudspeaker (StaticBody3D, scripts/loudspeaker.gd)
  ├── PoleShape / BaseShape   (cats and cars bump into it)
  ├── Model                   (the .glb, made PS1 when the city loads)
  ├── LedGlow + LedLight      (the blinking light)
  └── Readout (Label3D, scripts/ui/floating_line.gd, groups "hud_name_tags" + "overclean_speakers")
  ```
  Select **Readout** to change Wrap At (40 letters per line), Text Height (how big the words are),
  Readable From (10 m: how close you must be), Fade Over (2 m: it fades out over the last
  bit), Hold Seconds, Biggest Font Size. Move it to move the words.
  Select the root for the light's Idle / Talking Color and brightness.
- **Where they stand:** the city puts them on sidewalk corners, horns towards the street, never
  on top of a lamp post or corner prop. **Main > City** > Inspector > **Loudspeakers**:
  **Loudspeaker Chance** (0.4 = about 14 poles per city; 0 = none), **Loudspeaker Along** (how far
  from the very corner). They come from the city number, so every player has the same poles.
- Test: `--host --near_speaker=6 --speaker_side=1.5 --speaker_turn=-22 --pitch=6 --announce
  --frames=130 --capture=shots/loudspeaker_readout.png` (prints `DevCapture speaker:` lines:
  how many poles, and how many typed the line: should be 1; `--announce=seal|level2|ko|...` picks the line).

| Moment | What it says (on the poles) | File in `sounds/sfx/` |
|---|---|---|
| The first cat of a district climbs up top | "Unregistered shedding has been detected..." (one of 3) | `overclean_deploy_1` .. `_3` |
| Heat level 2 | "Cleanliness alert. Hairball levels exceeding municipal tolerance..." | `overclean_level2` |
| Heat level 3 | "Warning. Unauthorized fish handling in progress..." | `overclean_level3` |
| Heat level 4 | "Critical mess threshold reached..." | `overclean_level4` |
| A MEGA VAC-COP rolls out | "Heavy sanitation unit deployed. Have a spotless day." | `overclean_boss` |
| Heat 100: the hatch seals (DEEP CLEAN) | "Sector quarantine initiated. Commencing total Deep Clean..." | `overclean_seal` |
| A cat is knocked out up top | "One stray removed from the premises. Street hygiene restored by 14 percent." | `overclean_ko` |

**Who hears it:** only players who are **up top** (the speakers are in the city; the sewers are
safe). The seal is the exception: everyone hears it. Lines never talk over each other (they wait
their turn), each heat level is said once per district, and the boss and knockout lines have a
cooldown so they don't repeat. It stays quiet in the TUTORIAL.

**Changing it (no code):** select **Announcer** in `main.tscn` (Scene dock: **Main > Announcer**).
Inspector: **Enabled**, **In Tutorial**, **Volume Db**, **Min Gap Seconds**, **Subtitle Prefix /
Color** (written in front of / the colour of the words on the poles), then one group per moment
with its **sound** (a file name in `sounds/sfx/` without `.wav`), its **line** (the words on the
poles), and delays / cooldowns. Changing the words doesn't change what the
voice says: ask Claude to remake that line with the Sound Lab (or edit
`tools/sound_specs/overclean.json` and run the batch command in §20), and keep the two matching.

**Adding a new announcement from a script:**
`OvercleanAnnouncer.instance.say("overclean_my_line", "The words on the poles.")`
(add `true` to make everyone hear it, not just players up top).

**Where the moments come from:** game Events (§16): `player_went_up` (new, fish_heist.gd),
`heat_level_changed`, `boss_deployed` (new, roomba_patrol.gd), `district_sealed`,
`player_knocked_out`. The words go to every pole's **Readout** (group `overclean_speakers`).

**Testing:** `--deploy --heat_ramp=40 --sound_log --frames=3300` (plus `--capture=shots/x.png`)
sends your cat up and raises the heat to 100 over 40 seconds; the console prints an
`[Announcer]` line for each announcement (and `[Sound] overclean_...`).
