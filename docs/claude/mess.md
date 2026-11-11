# Mess-making, street props pack, meow taunt

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- MESS-MAKING (SETUP_GUIDE §23): `scripts/mess_manager.gd` (`MessManager.instance`, node `Mess` under Main, GameSystems) +
  `scripts/mess_prop.gd` (`MessProp` Kind BIN/CONE/BOX/POSTER: model, `Hitbox` StaticBody (bins `SOLID_LAYER` 8 = cats only, cat
  mask adds it; others `HIT_ONLY_LAYER` 16 = bullets only), `receive_hit`, Interactable prio -5, `show_knocked/show_standing`,
  bin `Lid` flips, poster `Poster`/`Torn` groups, debris seeded by id). City builds them in order: `CityGenerator.mess_props`
  (index = id, same everywhere; `_add_mess_prop`; pre-knocked cones stay scenery). Anyone noticing -> `MessManager.knock(player_id,
  id, dir)` (deduped 1 s) -> host `request_knock` (sender_owns, up top) -> `_set_knocked` RPC + `add_heat(heat_per_mess)` +
  `Events.mess_made`. Noticers: `cat_bump` (owner, cat_player after move_and_slide, pre-slide velocity; bins need `bin_knock_speed`),
  `car_bump` (driver authority), Hit, E. Late join `_set_all_knocked` (+ `_pending` until the city exists; reset on `city.generated`).
  Remarks: every computer counts knocks -> `OvercleanAnnouncer.say(overclean_mess_N)`. Bots (`roomba.gd`): states appended
  `TIDY_GO/TIDYING/INVESTIGATE` (keep new states at the END: synced int), `_look_for_mess` -> `claim_nearest` (claim valid while
  `tidying_prop()`), `distracted_sight`, `MessManager.tidy(id)`; `tidies_messes` false for drone/trapper (their `_ready`), never
  boss/breach. MEOW: `CatPlayer.meow()` -> `_meow` RPC (`TauntBubble` name-tag marker under CatModel, white SHOUT, no typing: metas
  `shout_at` (msec) / `shout_seconds` -> `HudNameTags._shout` pop/shake/fade; `moves.puff()` + `Feedback.shake_near`; `_shout_blips`
  plays a burst of `CatLook.voice_sound(look)` at `voice_pitch()*taunt_shout_pitch`; voice = look key `voice` (`CatLook.VOICES` male/female, `voice_of`, MY CAT VOICE row)) -> host `RoombaPatrol.hear_noise(pos, meow_heard_from)` -> `Roomba.hear`. Test-only `CatPlayer.unseen_by_bots`.
  Test: `--mess=N`, `--ram_prop=bin|cone|box [--ram_trace]`, `--scratch`, `--shoot_prop`, `--ghost`, `--face_mess`,
  `--bait_mess=D`, `--meow[=F]`, `--mess_log=N` ("DevCapture mess" lines, `layout=` hash = same city check). Sounds: `tools/sound_specs/mess.json` (Sound Lab `taunt`
  kind / `generate_cat_taunt`, presets `cardboard_thump`, `vacuum`).
  STREET PROPS PACK: Kind also VENDING/HYDRANT/CART/NEON_SIGN/DUMPSTER (models from `tools/make_street_prop_specs.py`, group names
  Screen/Flap/Cap/Handle/Wheels/SignFace/Lid matter; sounds `tools/sound_specs/street_props.json`). `MessProp.cat_can_bump()` / `cart_can_bowl()` /
  `geyser_active()` (claim_nearest skips it); tuning = plain vars at the top of mess_prop.gd. Host `MessManager.host_knock` = the one knock path
  (request_knock checks, then calls it; a rolling cart's `_bowl_along` calls it with `knocked_by`); `_drop_loot` + `_looted_props` (once per prop
  per district, SCAVENGING: weighted `vending/dumpster/bin/box_finds` {id: weight, "" = nothing} via `finds_for`/`roll_find`; every item incl. guns). Geyser: each computer launches its own cats/driven car, host stuns
  `Enemy.GROUP`. Cart stop spot = ray vs city STATIC bodies only (deterministic). Glow parts dim via instance_tint; `powered` false in BLACKOUT.
  City: `_add_vending/_add_hydrant/_add_cart/_add_aframe_sign/_add_dumpster` (`_add_neon_sign` is the BUILDING neon), `_add_shopfront_vending`,
  Meow-Mart side-wall layout, yard dumpster + carts, corner `roll` ladder. Test: `--use_prop=KIND [--prop_twice|--geyser_jump|--geyser_bot|--cart_bowl]`,
  `--shoot_prop=KIND`, `--instant_props`, `--look_prop=KIND`. Port 7777 busy (user's Godot running)? use `--solo`.
