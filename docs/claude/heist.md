# Extraction loop, heat, one trip per district, manholes / payphones / exits, blue arrow

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- Extraction loop: cats spawn in the hub `Hub` (`scripts/hub.gd`, `UndergroundHub.instance`), a fixed
  code-built sewer at y=-200 (anything below y=-100 is "in the hub" = safe zone, guns don't fire).
  Don Catleone (`scenes/npcs/don_catleone.tscn`) is an `Npc`; his "send_up_top" action calls
  `hub.deploy(cat)`. Host detects cats/driver at the beam in `fish_heist.gd` -> `_extracted` RPC ->
  owner calls `hub.return_cat`. Owners move their own cat with `CatPlayer.teleport_to`. The hub swaps
  the local mood (moon/rain off, green fog) when the camera is below the line.
- Greed + pressure: loot tiers sardine $20 / fish $50 / `golden_koi` $400 (ItemData `carry_speed`,
  `noise`, `heat_on_pickup`, `pickup_announcement`; `ItemManager.carry_speed/loot_noise`). HEAT =
  `scripts/heat_meter.gd` (`HeatMeter.instance`, `Heat` node, host-only `add_heat`, shared 0..100,
  levels 1-5, HUD `Heat` bar top-right flashes red/blue; level-ups also play a sound): `RoombaPatrol._follow_the_heat` adds Roombas per level
  (20 base, +5/level, +40 DEEP CLEAN) and spawns the boss `scenes/roomba_boss.tscn` (inherits roomba.tscn, `is_boss`,
  drops scrap) at each heat level in `boss_on_levels` (2-4, stacks; no boss below `boss_min_heat` 25 except DEEP CLEAN; HUD heat bar = Mainframe bar in the hub), every `boss_every_kills` (3) regular kills when no boss is out (max `bosses_per_district` 4), plus at max heat.
  Roomba perf: far (>60 m from all cats) patrollers think every 4th frame (velocity scaled for move_and_slide),
  chase route replanned 10/s, mesh `visibility_range_end`, siren light distance fade, hum paused when far;
  sync_position/yaw are ON_CHANGE (`delta_interval` 0.05). Health bars show only once shot (`health < max`).
  Test: `--kill_roombas=N [--kill_bosses]`.
  Heat is the DISTRICT CLOCK (never cools: cooling exports are 0; ~10 min up top to 100). Exit open + every cat in the hub
  = `heat_per_second_when_all_home` (5/s) and `_run_deep_clean` ends at once when `_anyone_up_top()` is false.
  Boss is also on collision layer 3; the car's mask = 1+3 and `_integrate_forces` stops it dead on boss contact.
- ONE TRIP PER DISTRICT: host marks `FishHeist.went_up` (`_mark_went_up` RPC, cleared in `place_items`) when a player is
  up top; `hub.deploy` refuses `has_been_up` (extracted or KO'd). Heat races home (`heat_per_second_when_all_home`) when all
  are in the hub and (exit open OR `everyone_has_been_up()`). Story: Don's crew digs for a way down; exit at 75 = they broke
  through; payphone too-early line has NO direction hint. Koi has no `heat_on_pickup`. Test: `--deploy --down=0 --deploy_again=300`.
- Districts (`fish_heist.gd`): per-gang ENTRY `Manhole` (`scripts/manhole.gd`, code-built disc, textures/manhole_*.png) at
  `entry_position(team)` (one-way), per-gang EXIT at `exit_for(team)` (street spot from the heist rng), open while
  `exit_is_open(team)` (heat >= `Mainframe.exit_heat(team)` or sticky `exit_opened[team]`, not `sealed`; `every_exit_is_open()` gates the all-home rush). `Payphone` NPCs (`scenes/props/payphone.tscn`,
  `scripts/npcs/payphone.gd`, `Npc.prompt_verb` "USE") ring while open + some gang not `is_revealed`; a call ->
  `request_reveal_exit` -> host `_set_state(sealed, revealed)`; HUD `DropOff` arrow only when revealed.
  Heat 100: host seals, `RoombaPatrol.deep_clean_extra` swarm (spawns near cats, `swarm_sight_multiplier`),
  after `deep_clean_seconds` knocks out everyone up top, then `Game.new_district()` (new seed RPC, heat reset,
  `GameSystems` `start_district`). Hub `deploy` refuses while sealed. place_items `remove_child`s old nodes (names stay
  `Payphone0..`). Test: `--heat=80 --talk=Payphone0`, `--near_exit=D`, `--heat=100 --heat_hold=30 --frames=4800`.
  BLUE ARROW: HUD `Compass` (`HudCompassArrow`, scripts/ui/hud_compass_arrow.gd, software-projected 3D, `point_at(yaw, text, urgent)` /
  `hide_arrow`), driven by `fish_heist._update_hud_for`: up top + own exit open + not sealed -> nearest payphone (`nearest_payphone`)
  until `is_revealed(team)`, then `exit_for(team)`; urgent at `seal_warning_at_heat`. DropOff now only = sewers / breach text. `DevCapture compass`.
