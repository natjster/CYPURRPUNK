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
  drops electronics per cat, no scrap) at each heat level in `boss_on_levels` (2-4, stacks; no boss below `boss_min_heat` 25 except DEEP CLEAN; HUD heat bar = Mainframe bar in the hub), every `boss_every_kills` (3) regular kills when no boss is out (max `bosses_per_district` 4), plus at max heat.
  Roomba perf: far (>60 m from all cats) patrollers think every 4th frame (velocity scaled for move_and_slide),
  chase route replanned 10/s, mesh `visibility_range_end`, siren light distance fade, hum paused when far;
  sync_position/yaw are ON_CHANGE (`delta_interval` 0.05). Health bars show only once shot (`health < max`).
  Test: `--kill_roombas=N [--kill_bosses]`.
  Heat is the DISTRICT CLOCK (never cools: cooling exports are 0; ~10 min up top to 100). Mainframe heat passed + every cat in the hub
  = `heat_per_second_when_all_home` (5/s) and `_run_deep_clean` ends at once when `_anyone_up_top()` is false.
  Boss is also on collision layer 3; the car's mask = 1+3 and `_integrate_forces` stops it dead on boss contact.
- ONE TRIP PER DISTRICT: host marks `FishHeist.went_up` (`_mark_went_up` RPC, cleared in `place_items`) when a player is
  up top; `hub.deploy` refuses `has_been_up` (extracted or KO'd). Heat races home (`heat_per_second_when_all_home`) when all
  are in the hub and (`every_payphone_hint_is_on()` OR `everyone_has_been_up()`). Payphone too-early line only with `exit_open_from_start` off. Koi has no `heat_on_pickup`. Test: `--deploy --down=0 --deploy_again=300`.
- Districts (`fish_heist.gd`): per-gang ENTRY `Manhole` (`scripts/manhole.gd`, code-built disc, textures/manhole_*.png) at
  `entry_position(team)` (one-way; `_entries[team]`), per-gang EXIT at `exit_for(team)` (street spot from the heist rng).
  EXIT OPEN FROM THE START (11 Nov 2026, export `exit_open_from_start`): `exit_is_open(team)` = not `sealed` (off = old
  heat >= `Mainframe.exit_heat(team)` rule). `Mainframe.exit_heat` now = when the Mainframe's CHEAT kicks in:
  `payphone_hint_is_on(team)` -> blue arrow to nearest payphone + one feed line (`_announce_hints`); `every_payphone_hint_is_on()`
  gates the all-home heat rush (heat_meter.gd). HUD heat-bar tick says PHONE. `Payphone` NPCs (`scenes/props/payphone.tscn`,
  `scripts/npcs/payphone.gd`, look = `scripts/props/payphone_model.gd` on Model, `set_ringing` rattles the handset; `Npc.prompt_verb` "USE") ring while
  some gang up top is not `is_revealed`; a call -> `request_reveal_exit` -> host `_set_state(sealed, revealed)`.
  POP-OUT + LID SLAM: `hub.deploy` teleports into the hole and flings the cat (`pop_out_speed`, `moves.lock_steering(air time)`;
  cat_moves only clears the lock on the floor when velocity.y <= 0). `Events.player_went_up` (every computer, once per player
  per district) -> `fish_heist._on_player_went_up` -> `Manhole.play_slam()` (tween: lid flies, flips, slams, dust, shake_near).
  Heat 100: LAST CALL first (12 Nov 2026): host `_start_last_call` rpc (every computer: `hatch_closes_in` counts down locally,
  siren, feed, `Events.district_sealed` = the swarm/drain/announcer NOW), exits still work for `hatch_closing_seconds` (10);
  `hatch_closing()` / `deep_clean_on()` (hub deploy refuses on it); arrow points at `exit_for(team)` unrevealed + urgent; no
  payphone hint line. Countdown is drawn by the HUD heat bar (`HudHeatBar.set_hatch/set_hatch_sealed/clear_hatch`, fed by
  `_update_hatch_clock`); card at seal = SAFE if `escaped` (set in `_extracted`) or never `went_up`, else SHUT/TOO LATE.
  Host `_seal_hatch()` at time or when `players_up_top()==0`; `_set_state` newly_sealed slams every exit lid (`play_slam`) and
  only emits `district_sealed` if no last call ran (late joiner / 0 s). Test: `--deploy --heat=100 --heat_delay=60 --frames=170`.
  Then the seal: `RoombaPatrol.deep_clean_extra` swarm (spawns near cats, `swarm_sight_multiplier`),
  after `deep_clean_seconds` knocks out everyone up top, then `Game.new_district()` (new seed RPC, heat reset,
  `GameSystems` `start_district`). Hub `deploy` refuses while sealed. place_items `remove_child`s old nodes (names stay
  `Payphone0..`). Test: `--heat=80 --talk=Payphone0`, `--near_exit=D`, `--heat=100 --heat_hold=30 --frames=4800`.
  BLUE ARROW: HUD `Compass` (`HudCompassArrow`, scripts/ui/hud_compass_arrow.gd, software-projected 3D, `point_at(yaw, text, urgent)` /
  `hide_arrow`), driven by `fish_heist._update_hud_for`: up top + not sealed -> `exit_for(team)` once `is_revealed(team)`, else
  nearest payphone only if `payphone_hint_is_on` (or tutorial step 8), else hidden; urgent at `seal_warning_at_heat`. DropOff now only = sewers / breach text. `DevCapture compass`.
