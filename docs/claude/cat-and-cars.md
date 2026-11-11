# CatPlayer, cars, passengers, rides

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- `scenes/player.tscn` + `scripts/cat_player.gd` (`CatPlayer`): owner-authoritative cat. Owner writes
  `sync_position` / `sync_model_rotation` / `player_name`; remote copies glide toward them in `_process`.
  Only `CatModel` rotates; body never does (camera is a child). Remote copies start with `sync_position = position`
  (else they snap to (0,0,0) = the city for a moment, and the host marked new joiners `went_up`).
  CAT MOVES = child node `Moves` (`scripts/cat/cat_moves.gd`, `CatMoves`, all knobs there): `jump()` (coyote, buffer,
  short hop, POUNCE when zooming, WALL KICK via 8 short rays / is_on_wall), `air_target`/`acceleration_scale`/`steering_locked`,
  `clamber()` (down ray onto ledge + headroom ray), `gravity_multiplier` (fall faster), `air_lean` (pitch; stays < 0.35 rad so
  `_spin_around_middle` doesn't think it's a flip). `animate()` = squash/stretch `cat_model.scale` on EVERY computer from motion
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
