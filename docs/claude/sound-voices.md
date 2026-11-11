# Sound autoload, OVERCLEAN announcer, NPC voices

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- Sound: autoload `Sound` (`scripts/sound.gd`): files in `res://sounds/{sfx,ambience,music}/` load by
  name (`meow_1/_2` = random variants of "meow"); `play` (2D, local), `play_at` (3D, local: use where
  every peer already runs the code), `play_everywhere` (3D, RPC to all), `attach_loop`, `play_music` /
  `play_ambience` (crossfade; hub.gd picks hub/city per area by `view_cameras()`). The 4-stage synth soundtrack was REVERTED
  (user's call, 10 Nov 2026: liked the original music): don't bring it back unasked. Missing files are silent. Split screen: only player 1's
  camera listens, so 3D sounds / loops nearer another local player are moved via `Sound.hearing_position`. Never hand-build
  AudioStreamPlayers elsewhere. Sound table in SETUP_GUIDE.md section 12. Test: `--sound_log`.
- `OvercleanAnnouncer` (`scripts/overclean_announcer.gd`, node `Announcer` under Main, `instance`, `say(sound, text, everyone, delay, why)`):
  local only (Events fire everywhere), queue sorted by start time, one line at a time, heard only by local cats up top, seal = everyone.
  NO HUD subtitle: the words type onto the NEAREST loudspeaker pole's `Readout` per local cat (`_type_on_speakers` sets `_showing`,
  `_follow_nearest_poles` each frame moves it with `FloatingLine.skip_ahead`; `nearest_readout(pos)`; Readout `readable_from` 10 m,
  `fade_over` 2 m -> HUD meta `fade_distance`; group `Loudspeaker.GROUP` "overclean_speakers", `last_text`). Poles: `scenes/props/loudspeaker.tscn` (`scripts/loudspeaker.gd`, `models/loudspeaker.glb`,
  spec `tools/model_specs/loudspeaker.json`), placed by `CityGenerator._place_loudspeakers` (on `_rng`, `loudspeaker_chance`,
  `_taken_spots` keeps them off lamps/corner props; `city.loudspeakers`). FLOATING TEXT = `FloatingLine` (`scripts/ui/floating_line.gd`,
  Label3D marker: `say(text, color, seconds, voice, pitch, hold)`, wraps at `wrap_at`, per-word 3D blips; HUD metas `typed`,
  `max_distance`, `max_font_size`, `text_height`). No speech-bubble boxes anywhere (meta "bubble" is gone). PAYPHONES open no
  NpcDialog: `Payphone.talk` reveals (exit open) + `Readout.say(boss line, boss voice)`, `last_line`. Test: `--near_speaker=D
  [--speaker_side --speaker_turn] --announce[=boss|seal|level2..4|ko|deploy]`, `--talk=Payphone0` ("DevCapture payphone"). New Events: `player_went_up(id, first_in_district)`
  (fish_heist `_mark_went_up`, late-join catch-up passes announce=false), `boss_deployed` (roomba_patrol `_boss_siren`).
  `Sound` also registers numbered files by full name (`Sound.play("overclean_deploy_2")`). Test: `--deploy --heat_ramp=S --sound_log`.
- NPC VOICES: `Npc.voice` (e.g. "meow_blip_don", set on each npcs/*.tscn root; blips from `tools/sound_specs/npc_voices.json`) ->
  `NpcDialog.open(speaker, line, choices, voice)` types the line (`letters_per_second`, VC_CHARS_AFTER_SHAPING + label min height
  = full line count) and blips once per word (`blip_per_word`, min gap `blip_gap_seconds`) (cap `max_blips_per_line`, 0 = none: the default, the voice lasts the whole line); accept/interact while typing = show all.
  Payphone uses `boss.leader.voice`. Test: `--talk=DonCatleone --sound_log`.
