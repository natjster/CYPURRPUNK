# 12. Sound & music

[Back to the contents page](../SETUP_GUIDE.md)


Every sound goes through one Autoload, **Sound** (`scripts/sound.gd`). The sounds themselves
are just files in the `sounds/` folder — **adding or replacing a sound needs no code.**

```
sounds/
├── sfx/          <- one-off effects        (SOUND FX slider)
├── ambience/     <- background loops        (SOUND FX slider)
└── music/        <- music loops, one per area (MUSIC slider)
```

The files there now are **placeholder bleeps** made by Claude. Replace them with real ones.

### Replacing or adding a sound (no code)
1. Get a sound file: `.wav` for short effects, `.ogg` for music and long loops (`.mp3` also works).
2. Name it exactly like the one it replaces (e.g. `shoot.wav`) and drop it into the right folder,
   overwriting the old one. (In Godot: drag it from Explorer into the **FileSystem** dock.)
3. Press Play. It's picked up by its name the next time the game starts.
- **Several versions of one sound:** number them: `meow_1.wav`, `meow_2.wav`, `meow_3.wav`...
  They're all "meow", and a random one plays each time. Great for footsteps and meows.
- Every play is also nudged a little higher or lower at random, so repeats don't sound robotic.
- A sound name the game asks for but has no file yet just stays silent (the Output panel says
  `[Sound] No file for 'x' yet` once).

### The sounds the game uses
| File name (in `sfx/`) | When it plays | Who hears it |
|---|---|---|
| `footstep` (`_1`, `_2`, `_3`) | every cat's steps, quicker when running | everyone nearby |
| `jump` | jumping (and catdip double jumps) | everyone nearby |
| `meow_blip_cat_male` / `meow_blip_cat_female` (`_1`..`_4`) | your cat "talking" its MEOW taunt as it types out over its head (MY CAT > VOICE picks which; each cat a slightly different pitch, §23) | everyone nearby |
| `meow` (`_1`, `_2`) | a downed cat's sad meow, NPCs | everyone nearby |
| `radio_squawk` | the walkie-talkie click when someone HECKLES from the CAT-CAM (§24), over the watched cat | everyone nearby |
| `shoot` | each gun shot (per gun: **Shot Sound** on the gun scene's root) | everyone nearby |
| `pickup` | grabbing an item / fish | everyone nearby |
| `roomba_hum` (loops) | every VAC-COP, revs up while chasing (higher-pitched on a SQUIRT-DRONE) | everyone nearby |
| `squirt` | a SQUIRT-DRONE fires a water zap | everyone nearby |
| `splat` | LINT-TRAPPER glue: a lob, its landing, and your paws getting stuck | everyone nearby (paws: only you) |
| `alert` | a LINT-TRAPPER or SQUIRT-DRONE starts chasing | everyone nearby |
| `bonk` | a VAC-COP bonks a cat | everyone nearby |
| `roomba_hit` | a bolt hits a VAC-COP | everyone nearby |
| `explode` | a VAC-COP explodes | everyone nearby |
| `engine_loop` (loops) | the getaway car; pitch follows the speed | everyone nearby |
| `car_door` | getting in / out of the car | everyone nearby |
| `hurt` / `knockout` | you lose HP / you're knocked out for good | just you |
| `hitmarker` / `kill_confirm` | your shot lands / YOU smashed a bot (`tools/make_feedback_sfx.py`) | just you |
| `loot_get` | something went into your backpack (`tools/make_feedback_sfx.py`) | just you |
| `downed` | you hit 0 HP and are waiting for a revive (placeholder "wah-wahh") | just you |
| `revive` | a downed cat is picked back up (placeholder rising blip) | everyone nearby |
| `extract` | you climb down the exit manhole | just you |
| `phone_ring` (loops) | payphones while the exit is open and nobody has called Don yet | everyone nearby |
| `koi_grab` | someone grabs a golden koi | everyone (2D) |
| `door_slide` | Meow-Mart's sliding doors open (§27) | everyone nearby |
| `can_clatter` / `shelf_collapse` | a can stack knocked off a shelf / a whole aisle toppling (§27) | everyone nearby |
| `scanner_beep` | [E] SCAN at a Meow-Mart checkout | everyone nearby |
| `plate_click` / `security_door` | the security scale pressed / let go; the EMPLOYEES ONLY door rolling | everyone nearby |
| `tank_shatter` | the golden koi tank breaks | everyone nearby |
| `store_alarm` (loops) | the STORE ALARM klaxon, inside and over the street door | everyone nearby |
| `overclean_mart_alarm` | "Aquatic display breach detected..." | players up top |
| ambience `meow_mart_hum` | fluorescent + fridge hum while player 1 is inside the store | just you |
| `heat_up` | the police siren: a VAC-COP (or the MEGA VAC-COP) spots you and starts chasing; also the tutorial's exit opening. Which sound and how loud: select the Roomba in `scenes/roomba.tscn` > Inspector > **Spotted Sound** / **Spotted Sound Db** (default -7) | everyone nearby |
| `boss_siren` | the MEGA VAC-COP comes out | everyone (2D) |
| `overclean_*` | OVERCLEAN's announcements (chime + robot voice, §21) | players up top (the seal: everyone) |
| `bin_clatter` / `cone_bounce` / `box_thump` / `poster_scratch` | a bin / cone / box knocked over, a poster scratched (§23) | everyone nearby |
| `vending_smash` / `hydrant_burst` / `cart_roll` / `sign_spark` / `dumpster_rummage` | STREET PROPS PACK: a vending machine kicked, a hydrant wrenched open, a cart shoved, a neon A-frame knocked flat, a dumpster rummaged (§23) | everyone nearby |
| `prop_standup` | a VAC-COP finishes tidying a mess (it stands back up) | everyone nearby |
| `roomba_tidy` | a VAC-COP vacuuming up a mess (repeats while TIDYING) | everyone nearby |
| `roomba_curious` | a VAC-COP heard a meow and comes to look | everyone nearby |
| `overclean_mess_1..3` | OVERCLEAN's remark when the city gets trashed (§23) | players up top |
| `pa_chime`, `scratch` | made by the Sound Lab (§20); not used yet | |
| `meow_blip_<name>` (`_1`..`_4`) | an NPC's talking voice while their line types out (each NPC's **Voice**, §8) | just you |
| `buy` / `error` | the Black Markitten sells you something / says no | just you |
| `click` | any menu button | just you |
| `report_open` / `report_row` / `report_award` | the RAID REPORT appears / each cat's row slides in / each award stamps down (§22) | just you |

Music and background loops change by area (they fade into each other): in the sewers
`music/hub` + `ambience/sewer`, up top (and on the start menu) `music/city` + `ambience/rain`.
Watching someone (CAT-CAM, the breach live feed) counts as being where the camera is.
To use other files, select **Hub** in `main.tscn` > Inspector > **Music** group (Hub Music,
City Music, Hub Ambience, City Ambience: file names without `.wav`; empty = silence).
(10 Nov 2026: a 4-stage synth soundtrack was tried and reverted; it's in git history.)

"Everyone nearby" sounds come from a spot in the 3D world: louder when your camera is close,
left/right speaker by direction, silent beyond 45 m.

### Where to find sounds
- **jsfxr** (sfxr.me, in your browser): click "Pickup", "Laser", "Explosion"... and export a
  `.wav`. Perfect for the retro feel.
- **Freesound.org** (filter by the **CC0** licence = free for anything), **Kenney.nl** audio
  packs, **OpenGameArt.org**. Check each sound's licence before you put it in the game.
- Record your own: real meows from a phone are the best meows.
- **PS1 crunch tip:** save effects at **22050 Hz mono** (Audacity: Tracks > Resample, and
  Tracks > Mix > Mix Stereo Down to Mono). Loops must start and end smoothly or they click.

### Split screen and sound
The game can only listen from ONE spot (Godot can't mix sound for several cameras): player 1's
camera. So a sound that's closer to another player on this computer (player 2's fish pickup,
their gunshot, the car engine while player 2 drives) is played as if player 1's ears were where
that player is: same distance, same direction. Everyone on the couch shares the speakers, so
you hear what's happening to whoever it's happening to. (`Sound.hearing_position`, automatic
for `play_at` / `play_everywhere` / `attach_loop`. `--sound_log` says "moved to another player's
ears" when it does it.)

### Tuning knobs
- **`scripts/sound.gd`** (top of the file, change the number): `PITCH_VARIATION` (random pitch
  nudge), `HEARING_RANGE` (metres), `LOUDNESS_SIZE` (bigger = loud further away), `FADE_SECONDS`
  (music crossfade), `MUSIC_DB` / `AMBIENCE_DB` (music and ambience loudness),
  `RETRO_CUTOFF_HZ` (the PS1 "cheap TV speaker" muffle on all sound; 0 = off).
- **Cat** (`scenes/player.tscn`, root) > **Sounds**: Footstep Interval, Footstep Volume Db, Meow Cooldown.
- **GetawayCar** (`scenes/getaway_car.tscn`, root) > **Engine Sound**: Engine Idle Pitch,
  Engine Top Pitch, Engine Volume Db.
- **Guns** (e.g. `scenes/items/pistol.tscn`, root) > **Look** > **Shot Sound**: which `sfx/` file it fires.

### Making something new play a sound (one line of code)
- `Sound.play("buy")` — plain sound, only you hear it (menus, "you got hurt").
- `Sound.play_at("shoot", where)` — from a spot in the world, on this computer. Use it where
  **every** computer already runs the code (like a shot that's drawn on every screen).
- `Sound.play_everywhere("bonk", where)` — from a spot, sent to **every** player's computer.
  Use it where only one computer knows it happened (usually the host).
- `Sound.attach_loop("engine_loop", self)` — a looping sound that rides along on a node; keep the
  returned player to change its `pitch_scale` / `volume_db`.
- `Sound.play_music("city")` / `Sound.play_ambience("rain")` — fade over to another track.

### Testing shortcut
Add `--sound_log` to a test run: every sound that plays is printed (`[Sound] footstep at (...)`).
Music checks: `--solo` (hub), `--solo --deploy` (city). Look for `[Sound] music now playing: ...`.
