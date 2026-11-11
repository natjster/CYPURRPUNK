# Enemy framework, VAC-COP Roombas, hunters, bot models + eye weak spot

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- ENEMY FRAMEWORK `scripts/enemy.gd` (`Enemy`, CharacterBody3D): health (synced), `receive_hit` -> host `take_hit`
  (heat, flash) -> `_on_hurt(shooter)` virtual / `explode()` (drops `stomach` + `drop_on_destroy`, heat, `destroyed`
  signal), `run_over_by_car(delta)`, `health_bar_info`, non-host glide to `sync_position`/`sync_yaw` (rotates `Model`).
  Subclasses call `super()` in `_ready`/`_process`. HIT FRAMEWORK `scripts/hit.gd` (`Hit`: shooter, weapon, damage,
  crit, direction, position; `Hit.target_of(collider)` walks up to a `receive_hit` node): weapon.gd never type-checks
  targets; cat (shove), car (push), Enemy implement `receive_hit(hit) -> bool` (true = damage number).
  `Motion` (`scripts/motion.gd`): `flat`, `flat_distance`, `glide_weight`, `glide`.
- Enemy: VAC-COP `Roomba` (`scenes/roomba.tscn`, `scripts/roomba.gd`, extends Enemy), host-simulated, on
  collision layer 2 (mask 1), others glide to `sync_position`/`sync_yaw`/`state`. `RoombaPatrol`
  (`Roombas` node + `RoombaSpawner`) spawns them at host start with its own RNG (not the city seed).
  Bonk = `get_zapped` + `ItemManager.take_one_loot` into `stomach`; guns call `take_hit` on the host;
  explode drops stomach via `ItemManager.drop_on_street`. Test: `--bait_roomba=D|aim`, `--zap_roomba=N`.
- HUNTERS: `SquirtDrone` (`scripts/squirt_drone.gd`) and `LintTrapper` (`scripts/lint_trapper.gd`) EXTEND `Roomba` (so patrol/`as Roomba` lists, perf, stun,
  DevCapture all just work) and override only `_fall`, `_chase_point`, `_attack`, `_show_light`. Their scenes keep the node names roomba.gd looks up (Eye, SirenRed/Blue,
  SirenLight; Brush optional). `RoombaPatrol._pick_scene` = `lint_trapper_chance`/`squirt_drone_chance`. Drone heat stacks per drone. Puddles = `StickyPatch` (`scripts/sticky_patch.gd`,
  local nodes on Main made by RPC on every computer; `StickyPatch.touches(pos)`, owner checks in `CatPlayer._sticky_paws`). Test: `--roomba=drone|trapper --bait_roomba=8 [--stun_roomba=6]`, `DevCapture sticky` line.
Bots: each scene's `Model` = `models/roomba|lint_trapper|squirt_drone.glb`; `Enemy._set_up_model` psx_ifies + `glow_parts` (part -> colour,
`glow_energy`). EYE WEAK SPOT (OFF by default since 11 Nov 2026, user's call: `eye_is_weak_spot` false; the eye still glows): `Enemy.receive_hit` -> `is_eye_hit(pos, dir)` (closest approach of the bolt's path to `eye_centre()`
<= `eye_crit_radius` * model scale, not from behind, never blasts) forces crit + `eye_crit_multiplier`, `eye_flashing()` (roomba.gd tints
the eye white-hot); `eye_crit_sound` "" = silent (the eye_crit sound was removed on request). Recipes: `tools/make_creature_specs.py` -> tools/model_specs/*.json (re-running REPLACES the
.bbmodel). Test: `--eye_test [--roomba=vac|boss|drone|trapper]`, `--portrait=bot --roomba=X`.
