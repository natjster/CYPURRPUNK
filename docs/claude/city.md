# City generator, street props, district twists, Meow-Mart interior

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- `scripts/city_generator.gd` (`CityGenerator`, the `City` node): the whole level is generated from a
  seed with one seeded RNG — keep all randomness on `_rng` and in a fixed order, or players' cities
  diverge. Host sends only the seed (`Game._receive_city_seed`). Centre crossroads and car spot
  (`CAR_SPAWN`) are fixed for every seed; Meow-Mart's BLOCK is random (`_meow_mart_block`; it takes the block's whole south half,
  doors facing +z), except the start menu's showcase city (`generate(PREVIEW_SEED, true)`: the block NW of the centre; `car.park_for_menu()` at CAR_SPAWN). Nothing
  may tick game rules behind the menu: `everyone_has_been_up()` is false with 0 players (it used to race the heat). Buildings share
  materials; per-object colour comes from the shader's `instance_tint` instance uniform.
  Determinism check: DevCapture prints a city `fingerprint`; host and client must match.
  Large surfaces must stay subdivided (~2.5 m: build with `LevelKit` (`scripts/level_kit.gd`: add_box/add_cylinder/add_light/add_sign/psx_material/subdivided_plane, shared box-mesh cache) — city, hub, manhole and gun bolts all use it): affine texture mapping on big
  triangles makes textures shear and swim. DevCapture `--no_affine` / `--no_snap` help diagnose.
  Never stack visible surfaces a few cm apart (e.g. sidewalk over street): they z-fight and
  flicker/streak at low camera angles. Ground is a non-overlapping tile grid (`_build_ground`).
- BUILDING STYLES: `scripts/city_buildings.gd` (static `CityBuildings`, `Style` BOX/SETBACK/SHOPHOUSE/TWIN/CORP). `_build_building`
  calls `pick_style` (one `_rng` draw, weights = City exports `style_*_weight`, tall styles gated by height) then `build(...)`,
  which returns the GROUND-FLOOR box {center,size[,awning_on_x]} that neon/poster/vending use (keep every style's ground floor
  = the full footprint, ≥10 m for SETBACK/TWIN so signs never float). Code-built LevelKit boxes, shared static materials,
  BLACKOUT -> dead grey + no lights. `building_style_counts` -> `DevCapture buildings:` line.
- `LevelKit.instantiate_model(path|name, parent, pos, yaw)` (cached PackedScene) + `psx_ify(root)` (shared psx_lit copy per source
  material, keeps albedo texture/colour, world_uv false). City props: `_add_bin` (StaticBody box) / `_add_cone` (no collision,
  `knocked_over`), yard pile = shuffled 4x4 grid, `_place_corner_props` (sidewalk corners, along 9.6-10.2 m: outside loot's ±9 m
  and clear of lamps), Meow-Mart door ±4.4 m; all on `_rng`. DevCapture prints `DevCapture props:` counts.
- DISTRICT TWISTS (SETUP_GUIDE §26): `scripts/district_twist.gd` (`DistrictTwist.instance`, node `Twist` under Main ABOVE City/Items).
  `Kind` NONE/BLACKOUT/BIN_DAY/CLEARANCE/HIGH_ALERT. Host `roll(seed, number)` in `Game.new_district` (rng `seed ^ 0x77157`, `twist_chance`,
  no repeat of `kind`; district 1 + tutorial = NONE), sent WITH the seed: `_receive_city_seed(seed, twist, district)` -> `set_twist` before
  `city.generate`. Ask `is_blackout()/...` or `sight/prop/heat/bot_multiplier()`, `roll_scrap_drop()`. BIN DAY extras use city `_bin_rng`
  (layout unchanged); chaos bonus = `MessManager.player_messes_this_trip` in fish_heist (`_extracted` 4th arg). Boss news `news_line()`,
  send-off `send_off_line()` (npc.gd), (the hub CRT shows only the Mainframe % now; `intel_line()` is test-only), report `twist`. No up-top popup (user's call). Test: `--twist=NAME`, `--twist_rolls`, `--twist_heat=F`.

- MEOW-MART (SETUP_GUIDE §27): a REAL walk-in store, no teleport. `scripts/interiors/meow_mart_interior.gd` (`MeowMartInterior.instance`,
  node `Main/MeowMart`, GameSystems + Interactable (one `_best_action` dispatcher, prio 5)) is built once from code and moved onto its
  block by `CityGenerator._build_meow_mart(block_center)` -> `place_in_city(floor_centre)` (hidden at y=-50 until then; `_placed`).
  Store coords: ROOM 21 x 4.5 x 10.8, FRONT_Z +5.4 (always faces +z, translation only, no rotation), floor `FLOOR_LIFT` 6 cm above
  the street, footprint `outer_size()`. Outside dressing = `scripts/interiors/meow_mart_exterior.gd` (`MeowMartExterior.build`:
  cladding `textures/mart_cladding.png`, sign facade, neon, awning, models `mart_cat_sign`/`security_cam`/`rooftop_ac`/`freezer_case`
  from `tools/make_meow_mart_specs.py`; tweens animate eyes/fans/cams). Inside: aisles (stepped `TIERS`, `AISLE_Z`, 4 segments,
  `_stacks`), checkouts, FRESH CATCH counter, security SCALE (`PLATE_SPOT`), HEAVY basket (`crate_pos`, host `_move_crate` cast_motion),
  EMPLOYEES ONLY roller door (`security_open`), back room KOI TANK (`HitRelay` `scripts/interiors/hit_relay.gd`; other walls hand hits to
  `receive_hit`). Doors: `_animate_doors` (any cat near, no collision on the leaves). `contains(pos)` = inside the walls only; hub
  `mood_at` -> `MART_MOOD`; `Roomba._can_chase` ignores cats inside; `cat_player` calls `cat_bump` after MessManager's. Host requests
  `request_swat/topple/tank_hit/drag/push/exit_button` -> RPCs; messes via `MessManager.count_mess`; shatter -> `ItemManager.drop_on_street`,
  `trip_alarm` = instant heat + `RoombaPatrol.ambush(street_spot)` + `hear_noise`, `Events.store_alarm_tripped`. Late join `_receive_state`,
  new district `_reset`. Loot: LootSpawn `MEOW_MART_SHELF`/`MEOW_MART_COUNTER` (ItemManager `_free_mart_spots`); the OUTSIDE_MEOW_MART fish
  row was removed from loot/city.tres (user's call, 12 Nov 2026: it blocked the door) so CLEARANCE's fish multiplier is idle. The street
  lamp in front of the doors shifts 7 m. Tests (game port may be busy: add `--port=7790`): `--test_meow_mart[=D]`, `--inside_meow_mart[=W]`,
  `--shatter_tank[=F]`, `--mart_swat/topple/plate/drag/tank_hits/log`; `--seed=1999` puts the store door at (-18, 0, -7).
- DEPTH PULL (`psx_lit` `depth_pull` share of distance, `depth_pull_max` metres): thin layers on other surfaces z-fight because the vertex snap breaks depth interpolation. Used by StickyPatch (0.08) and the Mainframe screen + gauge cells (0.03, max 0.15; the % Label3D floats 0.22 m out). `--goop=D` drops a puddle to look at.
