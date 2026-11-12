# CatPlayer, cars, passengers, rides

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- `scenes/player.tscn` + `scripts/cat_player.gd` (`CatPlayer`): owner-authoritative cat. Owner writes
  `sync_position` / `sync_model_rotation` / `player_name`; remote copies glide toward them in `_process`.
  Only `CatModel` rotates; body never does (camera is a child). Remote copies start with `sync_position = position`
  (else they snap to (0,0,0) = the city for a moment, and the host marked new joiners `went_up`).
  CAT MOVES = child node `Moves` (`scripts/cat/cat_moves.gd`, `CatMoves`, all knobs there): `jump()` (coyote, buffer,
  short hop, POUNCE when zooming, WALL KICK via 8 short rays / is_on_wall), `air_target`/`acceleration_scale`/`steering_locked`,
  `clamber()` (down ray onto ledge + headroom ray), `gravity_multiplier` (fall faster), `air_lean` (pitch; stays < 0.35 rad so
  `_spin_around_middle` doesn't think it's a flip). BUNNY HOP cap: chained pounces fall off (`chain_pounce_falloff`) and are
  capped at zoomies*upgrade*speed_boost + pounce_boost*`pounce_max_stack` (before: each pounce stacked on the last = faster than the car). `animate()` = squash/stretch `cat_model.scale` on EVERY computer from motion
  (nothing else may set CatModel's scale). Catdip air jumps only fire when `jump()` returned "". Test `--moves_test`.
  8-player stress test recipe: SETUP_GUIDE §6 (host `--add_local=3 --heat=95`, clients 2+1+1, `--net_stats`).
- CARS: one per gang in main.tscn (`GetawayCar` team 0, `GangCar` team 1; car export `team` only picks the parking
  spot `parking_spot()` = `park_distance` up the N-S street from `FishHeist.entry_position(team)`; -1 = `CAR_SPAWN`).
  Never assume one car: `Game.instance.cars()` / `car_of(id)`; Enemy.run_over_by_car checks every car. DevCapture `_car_for`.
- `scenes/getaway_car.tscn` + `scripts/getaway_car.gd` (`GetawayCar`): arcade RigidBody3D. Authority =
  driver (host when empty); non-authority copies are frozen (kinematic) and glide to `sync_*`.
  Enter/exit go through host-validated RPCs (`request_enter`/`request_exit(player_id)` → `set_driver`).
  Passengers: `passenger_ids` (`passenger_seats` 3, `set_passengers` RPC = whole list); use `has_occupant(id)` /
  `Game.car_of(id)` (driver OR passenger), `remove_occupant(id)`, `empty_car()`. Test: `--drive --ride_along=1,2 --ride_exit=1`.
  Drive input (`throttle`/`steer`/`handbrake`) is filled by `_read_driver_keys()`; physics only reads it.
  LOOK: `Model/CarModel` = `models/getaway_car.glb` (spec `tools/model_specs/getaway_car.json`, kind "vehicle" <500 tris; model kit
  element `poly` = free-form corner points). `_set_up_model` psx_ifies it, tints `Trim` `Teams.color_of(max(0, team))` + glow,
  `_update_wheels` spins WheelFL/FR/BL/BR (from moved distance, works on frozen copies) + steers the fronts. Test `--car_light`, `DevCapture car_look`.
- RIDING = `scripts/cat/cat_ride.gd` (`CatRide`, node `Ride` under Player, like Moves): `cat.enter_car/exit_car` just call
  `ride.enter/exit`. `cat.riding_car` (every computer). Owner: `ride.follow()` every physics frame keeps the hidden body at the
  car (+`ride_height`) and sync_position, so bots chase cars (roomba.gd `_can_chase` allows `riding_car`, `_clear_line_to` skips the
  car, `_attack` -> `_bonk_car`). GUNNER = passenger (`cat.is_gunner()`): camera stays in its own spring arm (car RID excluded,
  `gunner_camera_distance/lift`), mouse/stick look work, `ItemManager._use_held_items`/HUD allow gunners; `HeldItem.own_rids()` =
  holder + car (weapon/melee rays + blasts). Test `--add_local=1 --drive --ride_along=1 --gunner_test`.
- CAR HEALTH `scripts/car/car_health.gd` (`car.health`, node Health, GameSystems): host `damage(amount, cause)`, `_set_health` rpc,
  `wrecked` (empty_car + hop + `_boom`, refuses entry, `repair()` after `wreck_seconds` = park). Crashes (only if export
  `crashes_hurt`, OFF since 12 Nov 2026 = enemies only) detected on the car's authority (`_recent_speed` drop, skips `car.teleport_frame`) -> `report_crash`. Rival gunfire: `car.receive_hit` -> `request_shot`.
  `car.gang()`, `car.health_bar_info()` (car in HudHealthBars group; friend = same gang). Fx helpers `scripts/car/car_fx.gd`.
- AFTERBURNER `scripts/car/car_boost.gd` (`car.boost`, node Boost): host owns `charges`/`recharge` (`max_charges` = `base_charges` (1) + crew tier of
  "afterburner"; static `test_charges` for tests, never touch real upgrades in tests: they save to test_profiles), action "boost"
  (car context, Shift / Pad A) -> `request_boost` -> `_start_boost` rpc (flames, kick impulse on authority, FOV/shake).
  `_integrate_forces` floors it (`speed_multiplier`). Host `_exhaust_blast`: `Enemy.launch(push)` (is_flying, daze stun; roomba
  skips steering + spins), `get_zapped` cats, `MessManager.knock`. Ram while boosting = launch, not smash (`Enemy.run_over_by_car`).
  HUD = `HudBoostBar` (`scripts/ui/hud_boost_bar.gd`, Frame/Middle/Boost, fed by hud.gd `_update_boost`,
  sits above Held): one fixed-width bar split per charge. Test `--drive --car_test [--boost_snap --frames=20]`, `--car_chase`
  (module `scripts/dev_tests/cars.gd`). getaway_car.gd is ~800 lines: put new car features in `scripts/car/`.
- JUICE `scripts/car/car_juice.gd` (`car.juice`, node Juice): `handling()` called from `_integrate_forces` (on ground, authority
  only) = launch bonus, drift keeps speed (drag scale, carry, `drift_max_angle` swings the velocity back = no spin-outs), DRIFT TURBO
  (`_drift_time` -> `turbo_level` 1 blue / 2 orange, kick on handbrake release, `_turbo_fx` unreliable rpc). `_physics_process` on
  EVERY computer from measured motion: lean/squash on `Model/CarModel` (rotation + scale: nothing else may set those; wrecks use
  `Model`), drift/launch/turbo SPEED STREAKS via the `Streaks` node (`scripts/car/car_streaks.gd`: ImmediateMesh ribbons like the
  claw marks, `burst()` / `stream()`; Boost uses it too, no cube particles), skid loop, landing thump, `camera_arm.spring_length` pullback, rumble. Test `--drive --car_juice`.
