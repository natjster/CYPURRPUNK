# CYPURRPUNK — notes for Claude

Godot 4.7.2 multiplayer PS1-style cyberpunk cat game. The user is a non-coder: keep code heavily
commented, expose tuning as `@export`, give Godot editor click-paths, and update `SETUP_GUIDE.md`
(the user-facing guide) whenever behaviour or node trees change.

## Layout
- Main scene = `scenes/game_screen.tscn` (`scripts/ui/game_screen.gd`, `GameScreen.instance`): `main.tscn`
  runs inside `GameView/GameViewport` (SubViewport, 240 tall, width from `Settings.widescreen`/
  `pixel_perfect`), blown up with nearest filtering; `_input` forwards events into it (push_input).
  Root window = stretch `canvas_items`, keep_height, 960x720 base ("HUD units").
- UI LOOKS: `Settings.modern_ui` (SETTINGS > EFFECTS > UI STYLE). false = PS1: `menu_viewport` and every HUD SubViewport render at game pixels
  (size = the pane's game viewport, `size_2d_override` keeps the layout), blown up nearest, and `CRTOverlay` (top-level ColorRect, psx_post with `pixel_scale`/`area_offset`/`area_scale`) covers game+HUD+menus; the per-pane CRT is off (`_game_dither` hidden, panes show the raw viewport). true (default) = MODERN: real-res UI, overlay hidden, per-pane CRT on. One player + PS1: `hud_scale_for` = fit * `ps1_hud_scale` (1.33). Thin lines in HUD `_draw` need `Hud.line(w)`, text outlines `Hud.outline(w)`, small font sizes `Hud.text_size(n)` (PS1 min 18). TOP ROW (Health | DropOff | Heat) is laid out every frame by hud.gd `_layout_top_row` (bars shrink, DropOff drops under them on narrow screens; `_second_row_shift` moves Feed/Scoreboard/StatusIcons): never set those widths elsewhere. `limits/global_shader_variables/buffer_size` is raised on purpose (city `instance_tint` overflowed it).
- HUD = `scenes/ui/hud.tscn` (`scripts/ui/hud.gd`, class `Hud`), a CanvasLayer OUTSIDE the game viewport, in a SubViewport (`GameScreen._seat_huds[seat]`, seat 0 too: GameScreen._input pushes each seat's events to its HUD first; player 1's mouse only while `Hud.wants_input(0)`). Use the statics: `Hud.set_text/show_element/set_color/
  show_message/popup/set_in_game/element` by label name (Health, StatusIcons [HudStatusIcons, buff badges, fed by hud.gd
  `_update_status` from `cat.sticky/boost/air_jump_fraction()`; drops under the bar when the heat bar is in the way],
  Heat [HudHeatBar, top-right, fed by heat_meter], DropOff, Scoreboard [sewers only] |
  Popup, Crosshair, Message, Prompt, Held [HudWeaponDisplay: gun side-profile icons heat blue->red per paw, dual = stacked,
  2 quick-use squares; fed by `ItemManager._update_hud_for` -> `show_loadout(paws, quick)`]).
  OCEAN-BLUE STYLE = `HudStyle` (`scripts/ui/hud_style.gd`, settings `ui/hud_style.tres`): `HudStyle.current()`, `draw_panel`,
  `heat_color(heat)` (`heat_blend`), `item_icon/status_icon/npc_portrait(id)`, `draw_icon` (fits the PNG's used rect). Use it for
  phases 2-4 (Inventory, Shop, Workbench). Test: `--hud_heat=R,L --hud_buffs=sticky,catnip,catdip` ("DevCapture hud loadout"). `Frame/Top` stays during NPC talk, `Frame/Middle` hides;
  whole HUD hides under full-screen menus (`Hud.menu_open()`). Never reference HUD nodes by path.
  HUD windows `Inventory` (`InventoryScreen`) + `NpcDialog` live in hud.tscn: while `Hud.wants_input()`
  GameScreen keeps that player's input for their HUD.
  ONE HUD PER LOCAL PLAYER: `Hud.seat`; `Hud.of(seat)`; every static takes an optional seat (labels default
  to seat 0; `show_message`/`popup` default -1 = all). Players 2-4's HUDs are hud.tscn copies (own GUI focus).
  HUD scripts filter `Seats.seat_of_event(e) != seat`. Per-player
  producers loop `Game.instance.playing_cats()`; windows: `NpcDialog.for_cat(cat)/for_seat`,
  `InventoryScreen.for_seat`, `Hud.wants_input(seat)`. `hud.fit_to(rect, scale)` (`hud_scale_for`).
  Name tags use `GameScreen.camera_for_seat/screen_size_for_seat`.
  HUD windows must NOT use grab_focus (Godot keeps one focus per Window, across SubViewports): each keeps a
  `SeatFocus` (`scripts/ui/seat_focus.gd`: set_buttons/handle(event)/clear, highlight = "hover" stylebox).
- Phase 6: couch LOBBY = `Seats.lobby_cats` (START on an unclaimed pad while main_menu mode/play screen is up;
  `cycle_lobby_cat`, `leave_lobby`; MainMenu eats seat>0 events; `Seats.start_lobby_players()` from
  `_start_playing`). Host refuses a couch player over `Net.MAX_PLAYERS` (`_add_player_refused` -> `Seats.refused`)
  or a whole computer (`_game_full` -> `Game.leave_reason`, shown on the menu). Per-player pause:
  `PlayerPause` in hud.tscn (only when `PlayerPause.split_active()`; else the big PauseMenu); blocks only that
  seat (`cat._menu_open`, `car._driver_paused`). Test: `--saved_cats=A,B`, `--pad_press=1:Start` on `--menu=mode`.
- Phase 7 (8 players): balance scales with `Game.player_count()` (Roombas `extra_roombas_per_player`, heat
  `heat_per_extra_cat`, Items `regrow_faster_per_player`). Hub `free_spawn_position`.
  Sync: cat/car `replication_interval` 0.033, roomba 0.05 (host sends ~12 KB/s for 8 players). RoombaPatrol only
  runs after `start_district` (the start menu counts as "server": it used to spawn Roombas that broke joining).
  A real controller on this PC can disturb `--hold` tests (its events mix into actions). Test: `--net_stats=N`,
  `--pad_press_delay=N`.
- Phase 8: `Seats.color(seat)` (SEAT_COLORS) = pause title / lobby row colour (no split-screen frames or tags).
  Split panes render at full detail: `GameScreen._place` scales a pane's viewport by round(240/pane height)
  (`split_full_detail`), so viewport sizes != rect sizes (use `screen_size_for_seat`).
  MY CAT per player: `CatCreator.open(true, seat)` edits `Seats.saved_cat(seat)` for seat>0 (`_editing_cat/_update_cat`),
  `GameScreen._menu_driver()` = only that seat's events reach it; `back_to_player_pause` reopens their PlayerPause.
  SeatFocus: stick (JoypadMotion) moves one step per push (`_stick_pushed` edge detect); the same for the
  game-viewport menus: GameScreen `_stick_pushed_again` drops held-stick motion while `_in_menus()`.
  Lobby: A on a couch row = `Seats.lobby_cat_for_editing` + `MainMenu.lobby_cat_pressed(seat)` -> `CatCreator.open(false, seat)`
  (seat>0 is always restyle mode; `Seats.saved_cat` reads `lobby_cats` in the lobby). RULE: stick/d-pad NEVER change a value,
  only move the highlight (rows are separate < > buttons with explicit focus_neighbor links; A presses). CatCreator
  `_link_focus` wires every row's up/down by hand (Godot's guess fails there). TEXT BOXES: Godot 4.7 never d-pad-focuses
  a LineEdit, so `OnScreenKeyboard.hook(line_edit, menu[, DIGITS|ADDRESS])` hides it behind a Button (`keyboard.field`;
  point focus neighbours at that) that opens an on-screen keyboard (also takes real typing). Used by the cat name and
  the ONLINE city #/address boxes.
  Per-player stick settings: `Seats.stick_speed/invert_stick_y/rumble_on(seat)` (seat 0 = Settings; others =
  saved cat's "controls" dict) set via `Seats.set_player_setting`; rows in PlayerPause (`_add_setting` = < value >
  buttons; SeatFocus only moves/presses, no adjust). Unplugged pad: `Seats._on_joy_connection_changed` opens that
  player's PlayerPause(reason) (or the big pause solo), replug closes it; START on a free pad takes over an
  unplugged seat. Test: `--unplug=D [--replug]`.
  Overhead names: Label3Ds in group `hud_name_tags` are markers (made transparent; don't use
  `layers = 0`, it trips an engine light-pairing bug), `HudNameTags` (`Frame/Names`) projects them
  via the game camera. Street items too (`ItemManager._make_item_tag`, tag meta `max_distance`; name only, the button is the "[E] PICKUP" Prompt). Test: `--mouse_test`, `--click_choice=N`, `--press_key=Tab`.
- `scenes/main.tscn` (script `scripts/game.gd`, class `Game`, `Game.instance`): starts games, spawns
  cats via `MultiplayerSpawner` → `Players/` (cats named by PLAYER id; look up with
  `Game.instance.cat_for(id)` / `my_cat()` (first local player) / `local_cats()`), late-joiner catch-up, CRT/fog settings.
- GAME SYSTEMS (`scripts/game_systems.gd`, static `GameSystems`): host-run nodes join group `GameSystems.GROUP`
  and implement any of `start_district()` (new game / new district), `send_state_to(peer)` (late joiner),
  `player_left(player_id, last_position)`; game.gd calls `GameSystems.call_all(tree, method, args)` in main.tscn tree
  order (Items above the rest). Members: GetawayCar (`park()`), Items, Quests, Heist, Wallet, Health, Heat, Roombas. Never
  add per-system calls to game.gd. SETUP_GUIDE §16 = the frameworks.
- PLAYER IDs (`scripts/player_id.gd`, static `PlayerId`): a player id = network peer + slot*2^32 (slot 0..3,
  max 4 per PC, 8 total = `Net.MAX_PLAYERS`); slot 0's id == the peer id. Every per-player dict (cash, HP,
  quests, inventories, stash, `car.driver_id`, profiles) is keyed by player id, never peer id. Client->host
  `request_*` RPCs take the player id as their FIRST arg and the host checks `PlayerId.sender_owns(id)`;
  host->owner RPCs go to `rpc_id(PlayerId.peer_of(id), ...)`; `send_state_to(peer)` really is per computer.
  Cat: `player_id`, `slot`, `reads_input()` (authority AND `Seats.taken[slot]`; a test-added couch cat with no
  seat stands still). Couch players: `Game.add_local_player(slot, {name, look, cat_id})` / `remove_local_player(slot)`;
  `PlayerProfile.restore(player_id, cat_id, name)` per local player. Per-player HUD feedback currently only
  for `PlayerId.first_local()`. Test: `--add_local=N --as_local=S`, `--remove_local=S`.
- Autoloads: `Net` (`scripts/net.gd`: ENet host/join/leave on port 7777 — the only file that knows
  the transport; Steam swaps in here; LAN discovery: hosts broadcast `Net.advert` (set by game.gd
  `_process`) on UDP 7778, the MULTIPLAYER screen `start_listening()` -> `found_games` / `games_changed`; INTERNET: `host()` starts a UPnP Thread, `upnp_status` ""/opening/ready/unavailable + `room_code`, signal `upnp_updated`, `ip_to_code`/`code_to_ip`; `join` takes a code or address; `_close_router` in `_go_offline`/`_exit_tree`; invite rows in PauseMenu + PlayerPause; test runs never touch the real router. Test: `--test-room-code`, `--fake_upnp=IP|off`, `--address=`), `Settings` (`scripts/settings.gd`: all player settings,
  saved to `user://settings.cfg` = `%APPDATA%\MeowCity1999` (old name kept on purpose so saves survive the rename to CYPURRPUNK); test runs with `--capture` use
  defaults and never save), `Controls`, `Events`, `DevCapture` (debug builds only).
- EVENTS: autoload `Events` (`scripts/events.gd`): signals `district_sealed`, `player_extracted`, `player_knocked_out`,
  `heat_level_changed` (every computer), `item_picked_up`, `enemy_destroyed` (host only). Announce moments there instead of
  calling other systems (RoombaPatrol listens to `district_sealed` for the swarm, `deep_clean_roombas` is on Roombas). Test: `--event_log`.
- Sound: autoload `Sound` (`scripts/sound.gd`): files in `res://sounds/{sfx,ambience,music}/` load by
  name (`meow_1/_2` = random variants of "meow"); `play` (2D, local), `play_at` (3D, local: use where
  every peer already runs the code), `play_everywhere` (3D, RPC to all), `attach_loop`, `play_music` /
  `play_ambience` (crossfade; hub.gd picks hub/city per area by `view_cameras()`). The 4-stage synth soundtrack was REVERTED
  (user's call, 10 Nov 2026: liked the original music): don't bring it back unasked. Missing files are silent. Split screen: only player 1's
  camera listens, so 3D sounds / loops nearer another local player are moved via `Sound.hearing_position`. Never hand-build
  AudioStreamPlayers elsewhere. Sound table in SETUP_GUIDE.md section 12. Test: `--sound_log`.
- UI under `PS1Overlay` (theme `ui/menu_theme.tres`): `Lobby` = `MainMenu` (`scripts/ui/main_menu.gd`,
  emits host/join/settings signals), `PauseMenu` (`PauseMenu.is_open` → cat/car/inventory ignore
  keys), `SettingsMenu` (`scenes/ui/settings_menu.tscn`, rows from its `TABS` list), `CatCreator`,
  then `ColorDepthDither` LAST. MENU VIEW: at start `GameScreen._build_menu_view` reparents `ColorDepthDither`
  into a new `Main/CRT` CanvasLayer and the whole `PS1Overlay` into `GameScreen/MenuView/MenuViewport`
  (size_2d_override = game pixels; see UI LOOKS); `_input` pushes events there first, then to the game
  viewport if unhandled. Menu focus lives in `GameScreen.menu_viewport` (not game_viewport). (`NpcDialog.is_open_for(seat)` -> cat ignores keys; it and `Inventory` are in the HUD.) Each menu handles its own Esc in `_input`; tree order decides who
  sees Esc first. (The HUD is not here: see `Hud` above.)
  Widescreen: the game viewport is always 240 tall but can be wider (`Settings.widescreen`).
  `PS1Overlay` (`scripts/ui/ps1_overlay.gd`) centres every menu child in a 320-wide column (full-rect
  ColorRect backgrounds stretched back out); ColorDepthDither is full width. HUD labels must use
  anchors (the HUD Frame matches the game picture's shape). Test: `--window=1720x720`.
- `scripts/city_generator.gd` (`CityGenerator`, the `City` node): the whole level is generated from a
  seed with one seeded RNG — keep all randomness on `_rng` and in a fixed order, or players' cities
  diverge. Host sends only the seed (`Game._receive_city_seed`). Centre crossroads and car spot
  (`CAR_SPAWN`) are fixed for every seed; Meow-Mart's lot is random (`meow_mart_position`), except the start menu's
  showcase city (`generate(PREVIEW_SEED, true)`: Meow-Mart by the centre; `car.park_for_menu()` at CAR_SPAWN). Nothing
  may tick game rules behind the menu: `everyone_has_been_up()` is false with 0 players (it used to race the heat). Buildings share
  materials; per-object colour comes from the shader's `instance_tint` instance uniform.
  Determinism check: DevCapture prints a city `fingerprint`; host and client must match.
  Large surfaces must stay subdivided (~2.5 m: build with `LevelKit` (`scripts/level_kit.gd`: add_box/add_cylinder/add_light/add_sign/psx_material/subdivided_plane, shared box-mesh cache) — city, hub, manhole and gun bolts all use it): affine texture mapping on big
  triangles makes textures shear and swim. DevCapture `--no_affine` / `--no_snap` help diagnose.
  Never stack visible surfaces a few cm apart (e.g. sidewalk over street): they z-fight and
  flicker/streak at low camera angles. Ground is a non-overlapping tile grid (`_build_ground`).
- GAME MODE: `Game.is_turf_war()` (static, `_turf_war_game`, reset in `_ready`) = the ONE answer to "classic one-crew layout or
  gangs?". CO-OP (default; SOLO + TUTORIAL always) = everyone gang 0 (`Teams.picked` returns CATLEONE), one centre entry, one exit,
  GangCar freed (`_set_mode`, on clients too), no hack (`hack_target` -1), no rival live feed (`is_spectating`), no "WINS" banner.
  Host sets it in `_begin_game` from `Teams.turf_war_pick` (landing MODE row `[<] MODE [>]`, P1 only; online the host's wins) and
  `_receive_mode` RPC goes to every joiner BEFORE `_receive_city_seed`. `Seats.coop` is only about controllers. `NpcPage.coop_lines`
  (said instead of `lines` outside TURF WAR: Sal's respect quest). Advert `turf_war`. Test: `--mode=coop|turf` (`--teams=` implies turf;
  `--mode` wins), `DevCapture mode:` line (cats id:gang, entries, exits, cars). Old PvP / two-gang recipes need `--teams=`.
- GANGS (PvP phase 1, TURF WAR only): `scripts/teams.gd` static `Teams` (0 CATLEONE / 1 BURROW, NAMES/COLORS, `picks[seat]` set on the
  landing page: P1 GANG button, P2-4 LB/RB; SOLO resets to 0). `CatPlayer.team` (synced, set from `local_player_info`
  "team"; name tag colour). One `UndergroundHub` per gang: `Hub` (team 0, Don + Comrade Whiskers) and `GangHub` (team 1,
  x=200, Pawnie + Clawd shopkeeper; exports team/leader/shopkeeper/leader_glow/boss_name/lines). Use `UndergroundHub.of(cat)`
  / `for_team(t)` for spawn/return/deploy/stash; `instance` = team 0 and alone runs mood/music. Only gang-mates revive
  (`_anyone_could_help`/`_can_hold`/`downed_distance` check team); HudHealthBars friend = same team.
  PvP (phase 3): `CatPlayer.receive_hit` = own gang nothing; rival = shove + `CatHealth.request_shot(shooter, target, dmg)`
  (host checks gangs, up top, not in car, `pvp_max_range`, clamps `pvp_max_damage`; downed target = `_knock_out` if
  `shots_finish_downed`). Holding E on a downed RIVAL with loot = rob (`reviving[id].rob`, `rob_seconds`, `_rob` ->
  `ItemManager.steal_bag`, event `player_robbed`, red meter via health_bar_info `progress_color`). `CatPlayer.display_name()`.
  FEED: `Hud.feed(text, color)` -> `Frame/Top/Feed` RichTextLabel (downs/KOs/revives/robs, gang colour).
  Phase 4: `FishHeist.entry_position(team)` (outermost corner crossroads: 0 SW, 1 NE; hub.deploy pops out
  `surface_distance` towards the middle), `exit_positions[team]` / `exit_for(team)` (heist rng, `exit_min_distance` from
  every entry, `exit_spacing` apart; Manhole `glow_color` = gang colour), `revealed[team]` / `is_revealed(team)` via
  `request_reveal_exit` (caller's gang) and `_set_state(sealed, revealed_array)`; extraction only at your own gang's exit;
  phones ring until every gang in the game has called. Phone lines live on the hubs (`phone_too_early/exit_open/sealed`,
  payphone title = `boss_name`). Test: `--near_exit=3 --exit_team=1`, `--teams=1 --heat=80 --talk=Payphone0`.
  Not yet: team score / results, spawn protection.
  Test: `--teams=0,1,1 --add_local=2 --deploy --hold_all --give=pistol --shoot_rival=5 [--shoot_friend]`,
  `--down=1 --down_loot=fish --revive=150` (rob); a client's `--give` goes through the host's DevCapture `_test_give`.
- Extraction loop: cats spawn in the hub `Hub` (`scripts/hub.gd`, `UndergroundHub.instance`), a fixed
  code-built sewer at y=-200 (anything below y=-100 is "in the hub" = safe zone, guns don't fire).
  Don Catleone (`scenes/npcs/don_catleone.tscn`) is an `Npc`; his "send_up_top" action calls
  `hub.deploy(cat)`. Host detects cats/driver at the beam in `fish_heist.gd` -> `_extracted` RPC ->
  owner calls `hub.return_cat`. Owners move their own cat with `CatPlayer.teleport_to`. The hub swaps
  the local mood (moon/rain off, green fog) when the camera is below the line.
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
- MAINFRAME = `scripts/mainframe.gd` (`Mainframe.instance`, `Mainframe` node ABOVE Heat/Roombas: GameSystems order sets overclock
  first; in `GameSystems.GROUP`): one node, PER-GANG `charges[team]` 0-100 (`charge_of/tier/tier_name/tier_color(team)`, `_set_charges`, start 75),
  -25 on `Events.district_sealed` for `active_gangs()` (>=1 player), `request_feed(player_id)` (hub `MainframeTerminal`, `near_mainframe`) does
  `use_for(team)`: FEED +25 / HACK `hack_target(team)` -25 at 100% (feed line `_hacked`) / FULL refuses. `exit_heat(team)` = that gang's exit, live;
  `lowest_charge()` sets city-wide `starting_heat()` / `heat_multiplier()` / `boss_at_start()`. `_refresh_district` (host, each second + after a feed):
  while `went_up.is_empty()` a changed lowest restarts the district (covers late-arriving gangs too; `RoombaPatrol.restart_heat_levels` spawns the 0% boss).
  Not saved. The seal drains BEFORE `start_district`, so overclock needs a pre-trip feed. Heat bar: `set_heat(..., exit_heat)` draws the EXIT tick. SCRAP = $0 loot (`items/scrap.tres`), only the boss drops it: the shop won't buy it, it stays in
  the bag at the exit; `ItemManager.is_stashable` lets it in the stash. Hub CRT `_update_mainframe_crt` runs on every hub. Test: `--mainframe=N` or `=A,B`
  (client feed: `--wait=120 --give=scrap --pos=-11,-199.5,0 --press_key=E`).
- SEWER BREACH (`mainframe.gd`, host `_run_breach`): a gang reaching 0% gets one LAST RAID first (`_had_last_raid[team]` = at 0% as the district starts, `_note_last_raids`, banner; a hack before anyone goes up counts). `doomed_gangs()` = at 0% AND had it. Doomed + `sealed` + `players_up_top()==0` -> siren `_run_warning` / `_set_warning` RPC (`warning_teams`, `warning_left`, `breach_warning_seconds`, line = `breach_text`); `FishHeist._run_deep_clean` holds `new_district` while `breach_coming()`; scrap in time = cancelled. Time up -> `_start_breach` RPC (`breached_teams`, `breach_left`,
  `breach_busy` until the next district; Events `sewer_breached`/`sewer_breach_ended`). `hub.set_breached` = BlastGate (StaticBody, north tunnel `_build_breach_tunnel`) + red pulse. Use `UndergroundHub.is_safe(pos)` (not is_in_hub) for
  "nothing can hurt you" (damage, healing, guns). Horde: `RoombaPatrol._breach_queue`, bots have `breach_hub` (host only): `_can_chase` = anyone in that hub, route `hub.next_stop` (mouth, bridges), `ground_height()` for the drone, no respawns;
  patrol + FishHeist referee pause on `breach_busy`. Wipeout `_wiped_out` -> banner -> `_after_banner` (all reset to `starting_charge`); miracle = `_miracle` (reboot; `RoombaPatrol._set_off_bots` stuns the bots, then `Enemy.self_destruct()` one by one over `miracle_blast_seconds`: no kill credit, no drop). `HeatMeter.add_heat` ignores everything while `breach_busy`; breach bots don't steal loot; `ItemManager._on_city_generated` keeps drops on sewer floors. Both end in `Game.new_district()`. KO in a hub keeps gear and
  stays lying (`_knocked_out`), `_on_sewer_breach_ended` wakes + heals. LIVE FEED: `feed_camera_for(cat)`, `is_spectating(cat)` (blocks via `cat._menu_open`), `GameScreen._show_live_feed`, line = `breach_text` in DropOff, `Hud.banner`.
  NPCs FIGHT (`npc.gd`, parent is a hub + `breach_weapon`, polls `hub.breached`; `Npc.fighting` blocks E): instance a real gun scene on Model, draw with `Weapon.draw_shot`/`draw_blast`
  (no holder, no RPC: each computer sprays locally, only the host's shots call `take_hit`, city_heat 0). Blast guns = `Weapon.lob(from, to, height, seconds, on_landed)` for players and NPCs alike (exports `lob_*`, bounces in the gun scene; `draw_shot` lobs, the holder's computer `_blast`s on landing; a shot in the air dies with the gun), NPC host hits on landing. Knockdown is host-decided (`_knocked_down` RPC).
  Targets = group `Enemy.GROUP`. Cries = `BattleCryLabel`, a `hud_name_tags` marker (a real 3D label is unreadable at 240p). Loadouts on the NPC instances in main.tscn.
  Test: `--mainframe=0|75,0 --breach_seconds=S --breach_wipe=N --breach_log=N --breach_knock=N`.
- Districts (`fish_heist.gd`): per-gang ENTRY `Manhole` (`scripts/manhole.gd`, code-built disc, textures/manhole_*.png) at
  `entry_position(team)` (one-way), per-gang EXIT at `exit_for(team)` (street spot from the heist rng), open while
  `exit_is_open(team)` (heat >= `Mainframe.exit_heat(team)` or sticky `exit_opened[team]`, not `sealed`; `every_exit_is_open()` gates the all-home rush). `Payphone` NPCs (`scenes/props/payphone.tscn`,
  `scripts/npcs/payphone.gd`, `Npc.prompt_verb` "USE") ring while open + some gang not `is_revealed`; a call ->
  `request_reveal_exit` -> host `_set_state(sealed, revealed)`; HUD `DropOff` arrow only when revealed.
  Heat 100: host seals, `RoombaPatrol.deep_clean_extra` swarm (spawns near cats, `swarm_sight_multiplier`),
  after `deep_clean_seconds` knocks out everyone up top, then `Game.new_district()` (new seed RPC, heat reset,
  `GameSystems` `start_district`). Hub `deploy` refuses while sealed. place_items `remove_child`s old nodes (names stay
  `Payphone0..`). Test: `--heat=80 --talk=Payphone0`, `--near_exit=D`, `--heat=100 --heat_hold=30 --frames=4800`.
  GREEN ARROW: HUD `Compass` (`HudCompassArrow`, scripts/ui/hud_compass_arrow.gd, software-projected 3D, `point_at(yaw, text, urgent)` /
  `hide_arrow`), driven by `fish_heist._update_hud_for`: up top + own exit open + not sealed -> nearest payphone (`nearest_payphone`)
  until `is_revealed(team)`, then `exit_for(team)`; urgent at `seal_warning_at_heat`. DropOff now only = sewers / breach text. `DevCapture compass`.
- Health: `scripts/cat_health.gd` (`CatHealth.instance`, `Health` node, HUD label `Health`): host-only
  `damage(player_id, n, cause, instant=false)` (Roomba `bonk_damage`). 0 HP = DOWNED (`downed` {id: bleed secs left},
  `is_downed`; keeps loot, crawls at `crawl_speed`, no jump/drop/items/E) unless `instant` (DEEP CLEAN) or nobody else
  is on their feet (`_anyone_could_help`; solo = instant). Revive: a downed CatPlayer is an Interactable (priority 40,
  methods hand on to `downed_distance/downed_prompt/start_hold`); reviver holds interact -> `request_hold(helper, downed, on)`;
  host times it (`reviving` {downed: {by, left}}, bleed clock paused) -> `_revive` (`revive_health`). Bleed out /
  `request_give_up` (downed holds interact) -> `_knock_out` = `drop_everything` + `_knocked_out` RPC (owner flops via
  `CatPlayer.knocked_out`, then `hub.return_cat`). `is_down` = 0 HP (downed OR knocked out). Host heals cats in the hub.
  Events `player_downed`/`player_revived`/`player_knocked_out`. Downed bar uses health_bar_info `see_from`/`through_walls`.
  `Hud.key_for(action, seat)` = pad-aware button name. Roombas/extraction ignore `is_down` cats.
  Test: `--add_local=1 --deploy --down=1 [--revive=200 | --bleed_out=2]`; client `--join --deploy --revive=220`.
  Old: `--give=pistol --pos=-12,0,-6.5 --yaw=180 --bait_roomba=3 --frames=1500`.
  HP is 100 (Roomba 100, boss 600, bonk 34/67). Cyberpunk-style bars, all on the HUD: own bar = `HudHealthBar`
  (`Frame/Top/Health`, fed by cat_health `_process`); floating bars = `HudHealthBars` (`Frame/Bars`) for nodes in
  group `hud_health_bars` with `health_bar_info() -> {hp, max, position, show, name, boss}` (Roomba, other cats;
  boss = same floating bar, `boss_size` x bigger, out to `boss_distance`); damage numbers = `Hud.damage_number(pos, amount, crit, seat)` (`Frame/Damage`).
  Weapon rolls `damage`/`crit_chance` on the shooter and sends it in `roomba.take_hit(shooter_id, amount)`;
  Roomba `health` is synced (synchronizer, on change).
- CASH = `scripts/wallet.gd` (`Wallet.instance`, `Wallet` node): host `earn(id, n, why)` / `spend(id, n) -> bool` /
  `set_cash`; anyone `cash_of(id)`, signal `cash_changed`; draws the sewer `Scoreboard`. Never keep cash elsewhere.
- Stash + saves: inventories also hold `"stash"` (use `get_stash`; keep it when rewriting inventories).
  Players see it as THE LITTERBOX (code names stay "stash"; prompt `hub.stash_prompt` "STORE YOUR SHIT").
  Host `request_to_stash`/`request_from_stash` need `hub.near_stash(cat)` (litterbox on the east wall,
  `hub._build_stash`); the inventory screen (`InventoryScreen`) opens a LITTERBOX box there. ANY item is stashable (fish too).
  (`request_put_away` = paw -> backpack.) `scripts/player_profile.gd` (`Profile` node): each player saves
  their OWN cash + stash to `user://profiles/<name>.cfg`, sends it to the host on start/join
  (`_request_restore`, host validates), and saves only after `_restore_done`. Test runs use
  `user://test_profiles/` (`--fresh_profile`). Test: `--to_stash=hand:0`, `--from_stash=N`.
- `scenes/player.tscn` + `scripts/cat_player.gd` (`CatPlayer`): owner-authoritative cat. Owner writes
  `sync_position` / `sync_model_rotation` / `player_name`; remote copies glide toward them in `_process`.
  Only `CatModel` rotates; body never does (camera is a child). Remote copies start with `sync_position = position`
  (else they snap to (0,0,0) = the city for a moment, and the host marked new joiners `went_up`).
  8-player stress test recipe: SETUP_GUIDE §6 (host `--add_local=3 --heat=95`, clients 2+1+1, `--net_stats`).
- SOLO / CO-OP layout (`not Game.is_turf_war()`; local co-op also starts via solo_game, so never use "offline" for this):
  classic layout: `entry_position` = centre, one exit, GangCar freed in `_set_mode`, GetawayCar at CAR_SPAWN.
  `FishHeist.corner_position(team)` = a gang's corner regardless. Move cars ONLY via `_teleport` (done in
  `_integrate_forces`; plain `global_transform =` on a resting RigidBody is undone by physics).
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
- `shaders/psx_lit.gdshader` (all 3D: jitter, affine UVs, flat shading, emission, specular) and
  `shaders/psx_post.gdshader` (CRT + 15-bit dither, on a ColorRect). Renders at 320x240.
- `scripts/controls.gd` autoload `Controls` = the controls framework: `ACTIONS` list (action, menu label,
  context foot/car/any, default keys) registers every input action in code (not in project.godot);
  players rebind in SETTINGS > KEYS (saved to `user://controls.cfg`). Prompts must show
  `Controls.key_text("action")`, never a hard-coded key; no key-hint bar on the HUD. Test: `--rebind=A,S,KEY`.
  Controllers: each action also has a `pad` default (slot `PAD_SLOT` = 2, names "Pad A", "Pad RT",
  "Pad Left Stick Up"); `FIXED` = unbindable menu actions (`pause` = Esc/Start; pad A/B/LB/RB/X added
  to ui_accept/ui_cancel/ui_tab_left/right/ui_drop). Menus open/close the pause menu on `pause`, back
  out on `ui_cancel` (B). `Controls.using_pad` (last device touched; key_text follows it),
  `Controls.rumble(weak, strong, s)`. Every menu must work by focus (grab_focus on open).
  Test: `--pad=Right_Stick_Right`, `--pad_press=Start,D-Pad_Down,A`.
- `scripts/seats.gd` autoload `Seats` (after Settings): couch seats 0-3 = player slots. PLAYER 1 OWNS THE PC: seat 0 =
  keyboard+mouse + `pads[0]` = the first pad touched in the start menu (claimed in `_seatless_press`; -1 = keyboard
  only); others one pad each (`pads[]`, `taken[]`). `Seats.coop` (set by main_menu: SOLO false, landing true;
  --host/--join true): SOLO game = every pad is player 1's (`_any_pad_is_p1`), no joining. Seatless pads:
  `seat_of_event` -1 -> GameScreen._input swallows them (never reach menus); only START does something (lobby
  join / taking over an UNPLUGGED seat). `Controls.notice_device` is fed ONLY player 1's events by Seats (prompts/rumble/mouse rule
  follow player 1). `Seats.game_started()` from `_start_playing`; tests skipping menus: `Seats.claim_for_p1`. Per-seat copies of every action
  (`jump@1`) are built from Controls.bindings; gameplay input MUST go through `Seats.is_pressed/is_just_pressed/
  get_axis/get_vector(cat.slot, ...)` / `Seats.event_is(slot, event, ...)` (plain actions = any device, menus only).
  Rebuilding seat actions releases held buttons: only rebuild when bindings/pads change (`_built_from`).
  Landing page: START on PLAYER 1's own pad = `_give_p1_pad_to_new_player` (pads[0] = -1, P1 keeps keyboard+mouse,
  the pad joins the lobby; `_joining` hides that START from menus). Test: `--menu=mode --pad_press=0:D-Pad_Down,0:A,0:A,0:Start`.
  NO DROP-IN / DROP-OUT mid-game (user's call: couch players only join on the landing page, where gangs are picked):
  in a game, START on an unclaimed pad only `_take_over_unplugged`; no DROP OUT (PlayerPause seats > 0 have no leave,
  PauseMenu LeaveButton only for opened_by 0). Tests seat couch players with `Seats.test_seat_player(device)`
  (`--join_pad`); `--spare_start=D` = a real START mid-game (should do nothing). `Seats.seat_of_event(e)` (-1 =
  unclaimed pad: menus ignore it). Rumble: `Seats.rumble(player_id, ...)`. `InventoryScreen.owner_cat`.
  Test: `--join_pad=1`, `--pad_device=1`, `--pad_press=1:Start`.
- Split screen (`game_screen.gd`): pane 0 = GameView/GameViewport (player 1; only a slot-0 cat may
  `make_current`). Panes 2-4 are built in code: SubViewport sharing `game_viewport.find_world_3d()` + a Camera3D
  copying the cat's `camera` each frame (GameScreen process_priority 100), and a separate "Post" SubViewport
  whose Dither reads it via psx_post `use_source_texture` (a hint_screen_texture ColorRect inside a shared-world
  viewport showed player 1's picture). Layout from `shown_seats()` (cats with `reads_input`; [0] while
  `Hud.menu_open()`), `Settings.split_side_by_side`. Per-pane fog: `hub.environment_for(camera position)` (null = world's; `UndergroundHub.mood_at`: city or that sewer's gang; each hub's Mood + Gang Look exports);
  moon/music: anyone up top (`view_cameras()`). HUD frame = pane 0 (whole picture while `Hud.wants_input()`).
  Test: `--join_pad=1,2,3`, `--setting=split_side_by_side:false`.
- TUTORIAL (SETUP_GUIDE §19): `scripts/tutorial.gd` (`Tutorial.instance`, node `Tutorial` under Main, in `GameSystems.GROUP`),
  menu PLAY > TUTORIAL (`MainMenu.tutorial_pressed` -> `Game.tutorial_game()`; `Game.is_tutorial()` static, reset in `_ready`).
  9 steps (`step` 1..9, `phase` for sub-steps, DONE=10 -> banner -> `_back_to_menu(false)`), HUD `Frame/Top/TutorialBox`
  (`TutorialStep`/`TutorialHint`), code-built cyan beacon. Training rules: `PlayerProfile.restore` sends $starting_cash + empty
  stash and never reads/writes the save; heat held each physics frame (priority 100; step 8 = `exit_heat`); `Tutorial.health_floor()`
  in `CatHealth.damage`; `Tutorial.allows_deploy()` in `hub.deploy`; `prepare()` sets the Mainframe charge (the 6-slot backpack fits 3 fish + scrap); city via `_begin_game(seed, showcase=true)`. Test: `--headless -- --tutorial --tutorial_auto --capture=shots/tut.png` (needs --capture or DevCapture never runs; exit 0 = pass).
  GREEN ARROW: tutorial `_point_compass` drives HUD `Compass` on steps 1-7/9 (fish_heist nulls its compass then); step 8 = fish_heist's
  real PAYPHONE -> EXIT arrow, no beacon, `step8_exit_title` at phase 1. `--tutorial_shots` (windowed) saves shots/tutorial_step*.png.
- Hand-written `.tscn` files: use `position`/`rotation` properties, not Transform3D matrices.

- ANDROID (SETUP_GUIDE §17): `export_presets.cfg` preset "Android" (arm64, immersive, net + multicast permissions,
  -> `build/android/cypurrpunk.apk`); `rendering_method.mobile="forward_plus"` on purpose (Mobile renderer has no
  volumetric fog = no light pools); settings.gd skips window sizing on `OS.has_feature("mobile")`. Controller only,
  no touch controls. Export from CLI: `--headless --path . --export-debug "Android" build/android/cypurrpunk.apk`.

- CI (SETUP_GUIDE §18): `.github/workflows/build.yml` builds on every push to `main` and refreshes the rolling `latest`
  release (`CYPURRPUNK-Windows.zip`, `-Linux.zip`, `-Android.apk`; README links). Android = debug export, key from secret
  `ANDROID_DEBUG_KEYSTORE_BASE64` (throwaway key + warning if unset). A Godot upgrade must also change `GODOT_VERSION` there.
  `editor/export/convert_text_resources_to_binary=false` in project.godot is ON PURPOSE: the binary conversion dropped every
  scene's `PackedStringArray` values (NPC `lines` came out empty) in exports only. Editor runs never show this: test
  data-driven text in an export too (`--export-debug` build accepts the `-- --host --talk=` test args; add `--capture` or it never quits).

## Models + tool servers + OVERCLEAN (Phase 0, SETUP_GUIDE §20-21)
- ICONS: `tools/cypurr_icons.py` + MCP `tools/icon_mcp.py` ("cypurrpunk-icons"): a numpy rasteriser that reads .tscn primitives +
  .glb -> `ui/icons/items/<id>.png` (64px WHITE orthographic side profiles, seams/texture = darker lines; `ITEMS` table = source +
  view side/high/melee + yaw), `status/<id>.png` (32px, drawn in code), `npcs/<id>.png` (64px coloured 3/4 portraits from the
  NPC scene's `Model`, + `locked_mystery`). `python tools/cypurr_icons.py all`, then `--headless --import`.
- `.mcp.json` = two local stdio MCP servers (Python, mcp 2.x `MCPServer` with 1.x `FastMCP` fallback): `tools/model_mcp.py`
  (logic `tools/cypurr_models.py`: spec JSON -> `.bbmodel` (Blockbench 4.10 "free" format, groups inline in outliner, cubes +
  "prism" meshes + locators, embedded PNG painted by ops) -> `.glb` (group = node, locator = empty node, 16 px = 1 m, NEAREST,
  writes a minimal `.glb.import`: embedded uncompressed image, no LODs) + `inspect` (props <150 tris, chars <600, 64/128 tex))
  and `tools/sound_mcp.py` (`tools/cypurr_sound.py`: edge-tts + ffmpeg decode + numpy robot/PA/chime; cat blips; modal PS1 sfx).
  Recipes: `tools/model_specs/*.json` (`python tools/cypurr_models.py all <spec>`), `tools/sound_specs/overclean.json` (`batch`).
  `tools/` has a .gdignore. Building a model = edit the spec, rerun `all` (or user edits the .bbmodel, then `export`).
- `LevelKit.instantiate_model(path|name, parent, pos, yaw)` (cached PackedScene) + `psx_ify(root)` (shared psx_lit copy per source
  material, keeps albedo texture/colour, world_uv false). City props: `_add_bin` (StaticBody box) / `_add_cone` (no collision,
  `knocked_over`), yard pile = shuffled 4x4 grid, `_place_corner_props` (sidewalk corners, along 9.6-10.2 m: outside loot's ±9 m
  and clear of lamps), Meow-Mart door ±4.4 m; all on `_rng`. DevCapture prints `DevCapture props:` counts.
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
  boss/breach. MEOW: `CatPlayer.meow()` -> `_meow` RPC (`TauntBubble` name-tag marker under CatModel, plain outlined text, meta
  `typed` (visible_characters); `_type_taunt` types it and plays `CatLook.voice_sound(look)`
  blips at `voice_pitch()`; voice = look key `voice` (`CatLook.VOICES` male/female, `voice_of`, MY CAT VOICE row)) -> host `RoombaPatrol.hear_noise(pos, meow_heard_from)` -> `Roomba.hear`. Test-only `CatPlayer.unseen_by_bots`.
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
- CAT-CAM / SPECTATING (SETUP_GUIDE §24): `scripts/spectator.gd` (`Spectator.instance`, node `Spectator` under Main, GameSystems:
  host `start_district` -> `_stop_everyone` RPC). LOCAL per computer: `watching` {seat: player id}, `Spectator.is_watching(seat)`
  (cat `_menu_open` + `Interactable.best_for` block that seat), `camera_for(cat)` = own Camera3D per seat copying the watched
  cat's `camera` (or the car's `camera_arm` end). GameScreen `view_override_for(cat)` = breach feed first, then this (P1 make_current,
  panes copy). `watchable_for(me)` (up top, not KO'd; TURF WAR own gang first, rivals once none). Enter: `Events.player_knocked_out`
  (local, up top, not "THE DEEP CLEAN") -> after back in hub + `knockout_spectate_delay`; hub `_build_catcam` TV Interactable
  (`catcam_spot`); JUMP after `has_been_up`. Buttons polled with `Seats.is_just_pressed` (`button_grace_seconds`). Heckle = `_radio` RPC
  (`sender_owns`) -> `FloatingLine` per watched cat under Spectator + `radio_squawk`; host `RoombaPatrol.hear_noise(heckle_heard_from)`.
  HUD: fish_heist `_update_hud_for` -> `hud_text(seat)` in DropOff. CatPlayer `sync_camera_yaw/pitch` (synced, remote copies lerp).
  Test: `--add_local=2 --spectate [--heckle --spectate_switch --spectate_car --spectate_exit=F]`, `--spectate_ko`.
- RAID REPORT (SETUP_GUIDE §22): `scripts/raid_report.gd` (`RaidReport.instance`, node `RaidReport` under Main, in `GameSystems.GROUP`).
  Host counts per PLAYER id from Events (went_up, extracted, downed, revived, robbed, knocked_out, enemy_destroyed+`killed_by`,
  sewer_breach_ended, NEW `player_hurt` (CatHealth.damage), `loot_vacuumed` (ItemManager.take_one_loot), `mess_made` (MessManager;
  MESS on rows, export `show_mess_stat` now true)). District endings call `RaidReport.end_district()` (fish_heist `_run_deep_clean`,
  mainframe `_after_banner`) instead of `Game.new_district()`; ignored while `showing`; skipped (straight to new_district) in tutorial / 0 players /
  `enabled` false. Host `build_report()` (rows, endings, awards, gangs, timing) -> one `_show_report` RPC (late joiner: `send_state_to`,
  skip_reveal) -> `Events.raid_report_shown`; READY = `request_report_ready(player_id)` -> `_set_ready(ready, waiting_for)`; host `_process`
  ends at `seconds_left` or all ready after `reveal_end + read_seconds_after_awards`, then `_hide_report` + `Game.new_district()`. `player_left`
  keeps the row (`left`). Awards = `RaidAward` .tres cards in `res://raid_awards/` (`assign_awards`: by `order`, best unawarded qualifier,
  tie = earlier row; 8 empty-stat safety nets). SCREEN = ONE per computer (not per seat): `RaidReportScreen` (`scripts/ui/raid_report_screen.gd`,
  main.tscn `PS1Overlay/RaidReportScreen`, above PauseMenu, in PS1Overlay `full_width_children`; laid out in game pixels, table built in code,
  roomy text for <=4 rows only if it fits, `line_squeeze` so 8 rows fit 240 unscaled). THE check = `RaidReportScreen.is_up()`: in `Hud.menu_open()`
  (HUDs hide, split folds; `Hud.big_menu_open()` = pause/settings/MY CAT only), cat `_menu_open`. GameScreen `_input`: report up and no big menu ->
  every seat's event -> `seat_input(event, seat)` (interact / ui_accept readies `PlayerId.make(me, seat)` only; nothing else does anything), except
  seat 0 `pause` -> menu viewport (PauseMenu on top; while it's open only player 1 drives). Local rows: P1..P4 tag + `Seats.color`; READY cell shows
  `Hud.key_for("interact", seat)` blinking. Reveal + sounds `report_open/row/award` once per computer. Test: `--raid_report[=N] [--raid_report_after=F]`,
  `--report_ready=S,S:pad,S:key,S:stick,spare:D,S:pause [--report_ready_delay=N]`, `DevCapture report` / `report screen` / `after report` lines.

- DISTRICT TWISTS (SETUP_GUIDE §26): `scripts/district_twist.gd` (`DistrictTwist.instance`, node `Twist` under Main ABOVE City/Items).
  `Kind` NONE/BLACKOUT/BIN_DAY/CLEARANCE/HIGH_ALERT. Host `roll(seed, number)` in `Game.new_district` (rng `seed ^ 0x77157`, `twist_chance`,
  no repeat of `kind`; district 1 + tutorial = NONE), sent WITH the seed: `_receive_city_seed(seed, twist, district)` -> `set_twist` before
  `city.generate`. Ask `is_blackout()/...` or `sight/prop/heat/bot_multiplier()`, `roll_scrap_drop()`. BIN DAY extras use city `_bin_rng`
  (layout unchanged); chaos bonus = `MessManager.player_messes_this_trip` in fish_heist (`_extracted` 4th arg). Boss news `news_line()`,
  send-off `send_off_line()` (npc.gd), hub CRT `_crt_intel`, report `twist`. No up-top popup (user's call). Test: `--twist=NAME`, `--twist_rolls`, `--twist_heat=F`.

- MEOW-MART INTERIOR (SETUP_GUIDE §27): `scripts/interiors/meow_mart_interior.gd` (`MeowMartInterior.instance`, node `Main/MeowMart` at
  y=-50 (above `DEPTH_LINE`: counts as up top), GameSystems + Interactable (one `_best_action` dispatcher, prio 5)). Code-built, no randomness:
  aisles (stepped `TIERS`, 4 segments each, `_stacks` can stacks), checkouts, FRESH CATCH counter, security SCALE (`PLATE_SPOT`), HEAVY basket
  (`crate_pos`, host `_move_crate` cast_motion, drag = leash), EMPLOYEES ONLY roller door (`security_open`), back room KOI TANK (`HitRelay`
  `scripts/interiors/hit_relay.gd`; other walls hand hits to the interior's `receive_hit`). Walk-through = each computer teleports its own cats
  (`_check_doorways`: city glass line `city.meow_mart_door_spot` / interior `LEAVE_Z`). City storefront = `CityGenerator._build_meow_mart_storefront`
  (no `_rng` draws; `meow_mart_doors` leaves with metas home_x/open_x, `storefront_doors` export). `contains(pos)`; hub `mood_at` -> `MART_MOOD` (-2:
  no rain, store fog/ambient/ambience, moon only if someone's outdoors); `Roomba._can_chase` ignores cats inside; `cat_player` calls
  `MeowMartInterior.cat_bump` after MessManager's. Host requests `request_swat/topple/tank_hit/drag/push/exit_button` -> RPCs; messes via
  `MessManager.count_mess`; shatter -> `ItemManager.drop_on_street(tank_item)`, `trip_alarm` = `HeatMeter.add_heat(alarm_heat, true)` (instant),
  `RoombaPatrol.ambush(spot, bots, reach)` + `hear_noise` every `ambush_call_every`, `Events.store_alarm_tripped`. Late join `_receive_state`,
  new district `_reset`. Loot: LootSpawn `MEOW_MART_SHELF`/`MEOW_MART_COUNTER` (ItemManager `_free_mart_spots`), sidewalk koi line skipped via
  `MeowMartInterior.koi_in_tank`. Lambdas capture locals by value: `_best_action`'s `offer` fills the dict in place. Test: `--test_meow_mart[=D]`,
  `--inside_meow_mart[=W]`, `--shatter_tank[=F]`, `--mart_swat/topple/plate/drag/tank_hits/log`.

CHARACTER + BOT MODELS (Phase 1, 10 Nov 2026): CATS = the ORIGINAL code-built cat (`scenes/cat_model.tscn` primitive meshes;
each NPC scene builds its own Model with hat/cigar etc.), accessories ON (`CatLook.SLOTS` hat/face/neck). The Blockbench mascot cat
(`models/blockbench/cat.bbmodel`) was REVERTED (user's call: liked the original cats); don't swap it back unasked.
Bots: each scene's `Model` = `models/roomba|lint_trapper|squirt_drone.glb`; `Enemy._set_up_model` psx_ifies + `glow_parts` (part -> colour,
`glow_energy`). EYE WEAK SPOT: `Enemy.receive_hit` -> `is_eye_hit(pos, dir)` (closest approach of the bolt's path to `eye_centre()`
<= `eye_crit_radius` * model scale, not from behind, never blasts) forces crit + `eye_crit_multiplier`, `eye_flashing()` (roomba.gd tints
the eye white-hot); `eye_crit_sound` "" = silent (the eye_crit sound was removed on request). Recipes: `tools/make_creature_specs.py` -> tools/model_specs/*.json (re-running REPLACES the
.bbmodel). Test: `--eye_test [--roomba=vac|boss|drone|trapper]`, `--portrait=bot --roomba=X`.

`scripts/cat/cat_look.gd` (`CatLook`, static): a look = Dictionary of colours (`COLOR_KEYS`, painted onto
`scenes/cat_model.tscn` meshes by name via `COLOR_PARTS`) + part id per slot (`SLOTS`, at `SLOT_ANCHORS`).
Options are data: `CatPart` .tres cards in `res://cat_parts/` (scenes in `scenes/cat_parts/`) and
`cat_parts/palette.tres` (`CatPalette`). `CatLook.apply(model, look)` / `clean()` / `random_look()`.
Players have several cats: `Settings.cats` ([{id, name, look}]) + `current_cat_id`; use
`current_cat()/new_cat()/select_cat()/update_current_cat()/delete_cat()` (old player_name/cat_look keys are
migrated in `load_settings`). Profiles (cash + stash) are per cat id. `CatPlayer.look`/`player_name` come
from `current_cat()`; the look is synced by the cat's MultiplayerSynchronizer (on change).
Menu flow: Lobby MainScreen (PLAY/SETTINGS/QUIT) -> ModeScreen (SOLO / MULTIPLAYER). SOLO -> `cat_pressed` ->
`CatCreator.open(false)` (NEXT needs a name) -> `main_menu.cat_done()` -> `Game.solo_game`. MULTIPLAYER -> CoopScreen
(LOCAL / ONLINE CO-OP, built in main_menu.gd) -> LandingScreen (built in code: P1 row button = cycle cat /
A = cat creator, P2-4 rows from `Seats.lobby_cats`; LOCAL START GAME = `solo_pressed` with lobby players,
ONLINE NEXT = PlayScreen host/join, its BACK -> landing). Leaving the landing page `Seats.clear_lobby()`.
Cat creator NEXT/BACK route by `main_menu._cat_from` (`cat_done` / `cat_closed`). Pause > MY CAT = `open(true)`.
Test: `--solo`, `--name=`, `--look=N`, `--menu=cat|mode|coop|local|online|play`; prints `DevCapture look`.

SEWER UPGRADES (SETUP_GUIDE §25): `scripts/upgrades.gd` (`Upgrades.instance`, node `Upgrades` under Main right below Wallet, GameSystems).
`player_upgrades` {player_id: {id: tier}} synced (`_set_tier`/`_set_all`), `costs` export (id -> [[cash, scrap] per tier]), `INFO`/`WORKBENCH_TABS`.
Host `request_buy(player_id, id)` = Wallet.spend + `ItemManager.spend_scrap` (bag first, then stash; `scrap_count_of`). Read with static
`Upgrades.level(pid, id)` / `best_in_team(team, id)` (CREW: mainframe_capacitor, turbo_engine, insider_tunnel). Hooks: `ItemManager.bag/pack/stash/
quick_stack_size_for(pid)` (NEVER read pack_size etc. directly; `bag_size_for` = old alias of `pack_size_for`), `CatHealth.max_health_for`, `Upgrades.shop_allows` (crates; also refused in
request_buy), `zoomies/engine/gourmet/melee_multiplier`, `scrap_magnet_chance` (enemy.explode), `Mainframe.exit_heat`/`charge_per_scrap_for`.
NO upgrades in NPC chat any more (no upgrade_page / open_page): EVERYTHING is bought at the TINKER WORKBENCH = hub `_build_workbench`
(`models/workbench.glb`) -> `WorkbenchScreen` (`scripts/ui/workbench_screen.gd`, HUD `Frame/Workbench`, in `Hud.wants_input` + `cat._menu_open`;
7 portrait tabs = `Upgrades.WORKBENCH_TABS` [boss, shopkeeper, rebellion tiers 1-5] via `npc_for_tab` (hub.npc / hub.shopkeeper / child Npc
with that `rebellion_tier`), portraits `ui/icons/npcs/<scene file name>.png`, "?" = locked_mystery; CardFace = name, pips, BUY pill; ride buttons
on tab 6; `note()` gets `_buy_result`). SEWER REBELLION: crew upgrade `rebellion_tier` (5 tiers); `Upgrades.rebellion_level(team)` (best in gang,
tutorial = 5, test `rebellion_override`), `tab_unlocked`, `current_tier` (rebellion = gang's), host refuses locked tabs, `_recruited` RPC ->
`recruited` signal. `Npc.rebellion_tier` (export, set on the 10 recruit scenes) + `is_recruited()`/`present`: hidden, collision off, no E,
no breach fighting until recruited (checked every 0.25 s in `_process`, never in `_ready`: Game.players isn't ready yet). RIDES: `team_vehicle[team]`,
`request_select_vehicle` (car must be empty) -> `GetawayCar.set_vehicle(id)` swaps Model/CarModel (`cyber_bike.glb`/`fish_van.glb`), box, stats
(`bike_*`/`van_*` exports, `smash_speed_factor`); any `Trim*` part glows gang colour. Profile saves "upgrades" + "vehicle"; tutorial sends {}.
Models from `tools/make_upgrade_specs.py`. InventoryScreen grids resize per cat (`_match_sizes`; slots shrink to fit).
Test: `--buy_upgrade=a,b --select_vehicle=X --upgrade_log --vehicles_lineup`, `--workbench [--workbench_recruit=N --workbench_buy=a,b
--workbench_tab=N]` ("DevCapture workbench"), `--rebellion_tier=N` (`--talk=<recruit>` sets 5 by itself).

WEAPON MODELS (ROADMAP §5 #6, SETUP_GUIDE §9 "The weapon models"): the 8 weapon scenes' `Model/Mesh` = `models/<weapon>.glb` from
`tools/make_weapon_specs.py` (recipes in CM, `--build` runs cypurr_models `all`; REPLACES the .bbmodels). One shared 128x128 atlas
(`atlas_paint()`, 16x16 swatches, layout in the script docstring; `can()` maps a swatch's X ALONG a round part, Y ROUND it, via the
kit's new poly face `"uvs"` = exact per-corner UVs). Groups: Body, `HeatCoil` (tommy; weapon.gd `find_child`), glow groups. weapon.gd
`_ready`: `LevelKit.psx_ify(Model)` + exports `glow_parts` {part: Color} (`LevelKit.make_parts_glow`, also used by Enemy) / `neon_parts`
{part: strength} (`LevelKit.make_neon_paint_glow` = shader `texture_glow`); `_snap_muzzle_to_model` moves Model/Muzzle onto the glb's
`Muzzle` locator. Melee models stand along +Y (handle at origin). Test: `--weapons_lineup[=a,b] [--lineup_dist --lineup_yaw]`
("DevCapture weapon" lines), `--give=X --portrait=me --portrait_side=1.3 --portrait_dist=1.5 --portrait_height=0.55`.

## Items framework
ONE BACKPACK (Phase 2 UI overhaul): inventory = `{"hands", "pack", "stash", "quick"}` (NO "bag" any more). `pack` holds loot AND
spare gear, 1 slot each, `pack_size_for(pid)` = 6 + 2 per `bigger_pack` tier (3 tiers; old `deep_pockets` merged in
`Upgrades._merge_old_upgrades`). Full pack = `_can_take` false for loot. NOTHING is sold at the exit: fish_heist reports
`loot_value`/`loot_in_pack` (`_extracted(pid, worth, quest, chaos, count)`, Events.player_extracted loot_value = worth) and pays only
quest/chaos; the SHOP buys loot: `ItemManager.request_sell(pid, pack_index | -1)` (`sell_price` incl. gourmet, `pack_sell_value`,
Events.loot_sold), Shopkeeper `_sell_buttons`. Helpers `take_all_loot` (rob), `take_one_loot` (last LOOT only), `count_in_bag`/
`take_from_bag`/`bag_used` (= loot count) read the pack. Cats wear `models/cat_backpack.glb` (`tools/make_backpack_spec.py`) at
`CatModel/BackPack` (`ItemManager.BACKPACK_SPOT`, `_update_backpack`: "Strip" glow cyan->amber->red by fullness; `PackAnchor` locator,
`backpack_anchor(cat)`). INVENTORY = NMS backpack view: `CatPlayer.inventory_open()` blocks moving/looking and glides the camera
(`_update_inventory_camera`, "Inventory Camera" exports, side offset scaled by pane aspect, `inventory_view_amount()`); `inventory_ui.gd`
lays out ocean-blue boxes on the right (`_layout`), draws callout lines from projected 3D anchors (`_project` via
`GameScreen.camera_for_seat`), slots = Buttons + `SlotFace` (icon, name, price badge). Hud hides Names/Scoreboard while it's open.
Test: `--inventory[=0,1]` ("DevCapture inventory"), `--to_stash=pack:0`.
SHOP (Phase 3): `Shopkeeper.interact` -> `ShopScreen` (`scripts/ui/shop_screen.gd`, HUD `Frame/Shop`, `for_seat/is_open_for`; in
`Hud.wants_input` + `cat._menu_open`): right half = 3 tabs (exports melee/consumable/firearm_items, filtered by keeper.stock), rows =
Button + `RowFace` (icon or black silhouette when `!Upgrades.shop_allows`, BUY pill), SELL ALL; it opens the inventory in `shop_mode`
(`open_for_shop`: left column at `shop_column_start`, SELL badges, click = `request_sell(pid, where, index)`, cat camera `shop_camera_side`)
and drives ONE SeatFocus over both (inventory `_input` returns while the shop is open). Prices = `ItemManager.sell_price_for` (loot
100% x gourmet, gear max(1, price/2), scrap 0); `request_sell_all_loot`; `_buy_result`/`_sell_result` -> `ShopScreen.note`. WEAPON CRATES
moved to the workbench page (`Upgrades.PAGES.workbench`). Test: `--talk=ComradeWhiskers --shop_tab/--shop_buy/--shop_sell/--shop_sell_all/
--shop_pad/--shop_close` ("DevCapture shop").
All items go through `scripts/items/item_manager.gd` (`ItemManager.instance`, the `Items` node):
item cards are `ItemData` .tres files in `res://items/` (auto-loaded); held items with behaviour
extend `HeldItem`, guns extend `Weapon` (data-driven via exports). Host referees pickup/drop/
consume; inventories are `{"hands": [right, left], "bag": [...]}` (a 2-paw item fills both slots).
Held scenes are named `HeldR`/`HeldL` under each cat's `CatModel` so their RPCs line up.
World item IDs: city-placed items 0..N in placement order (deterministic), drops from 100000.
Other systems place items by joining group `item_placers` and implementing `place_items()`.
Don't add per-item pickup/sync code elsewhere. User-facing how-to: SETUP_GUIDE.md section 9.
QUICK USE: inventories also hold `"quick": [[ids], [ids]]` (two stacks, `quick_stack_size`; read via `quick_slots(id)` /
`quick_slots_of(inv)`); `ItemData.quick_use` items go there first; keys `quick_1/quick_2` -> host `request_quick_use` ->
owner `_quick_used` calls the scene script's `HeldItem.quick_use(cat)` on a spare copy. Catdip air jump = front flip
(`_flip_time_left`, `_spin_around_middle` shifts CatModel). Test: `--give=catdip --jump_test [--flip_snap=x.png]`, `--press_key=1`.

MELEE: `scripts/items/melee_weapon.gd` (`MeleeWeapon extends Weapon`, overrides `_fire` with a forward BoxShape
query (`swing_radius`/`swing_height`, `max_range` deep, reaches below the feet for flat Roombas), skips own-gang cats,
rpc `show_swing` tweens `Model`). Item `neon_bat` ($20, in `Shopkeeper.stock`). Starting money: `PlayerProfile.starting_cash`
(100) for new saves / once for older ones (`progress/starter` key; `save_now` forces the first save).
Weapon extras (exports, all `_make_hit` -> `Hit`): `pellets_per_shot`, `blast_radius` (`_blast`: sphere query, outward direction; replaces the
direct hit), `stun_seconds` -> `Enemy.take_hit(id, amount, stun, push, city_heat)` -> `_on_stunned`/`_on_pushed`, `enemy_knockback` (`knockback_taken`), `car_launch`
(m/s, x mass), `city_heat_per_hit`, `shots_per_sound`. `show_shot(ends, heat)` = one RPC per pull. STUNNED Roombas ignore `_on_hurt`. `CatHealth.finish_grace_seconds` = no finishing right after going down. Test: SETUP_GUIDE §9, `--rival_volley=N`, `--blast_car`, `--blast_probe`.

## NPC framework
Talking characters: `scripts/npcs/npc.gd` (`Npc`, StaticBody3D, group `npcs`), conversation data =
`pages: Array[NpcPage]` (first = greeting; empty choices reuse page 1's) of `NpcChoice` (text,
message, action, go_to). Built-in actions in `Npc._run_action`; custom ones via subclass
`_on_action` or the `action_chosen` signal. NPCs are Interactables (below): E -> `talk(cat)`. New NPCs start from
`scenes/npcs/npc_template.tscn`. Not networked (local per peer). Test: `--talk[=NodeName] --choose=N,M`.
Pages can gate the greeting on quest state (`only_if_quest`/`only_if_state`); action `quest:<id>` starts one.
Shops: `Shopkeeper` (`scripts/npcs/shopkeeper.gd`, extends Npc) — choice action `shop` opens BUY buttons for
its `stock`; prices = `ItemData.price` (0 = not for sale); host `ItemManager.request_buy` -> `Wallet.spend`.
Comrade Whiskers (`scenes/npcs/comrade_whiskers.tscn`) runs THE BLACK MARKITTEN on the hub's west wall
(decor in `hub._build_shop`). The loot table places only loot; gear (guns too) is scavenged from props (`MessManager` finds tables).
LOOT TABLE: `ItemManager.loot_table` = `res://loot/city.tres` (`LootTable` of `LootSpawn` lines: item_id, count, where
SIDEWALK/OUTSIDE_MEOW_MART/FIXED_SPOT, min_distance_from_meow_mart, respawn_seconds), placed first in `_on_city_generated`
(own rng, `LOOT_SEED_SALT`); then `item_placers` (the heist: manholes + payphones). Never hard-code loot spots in code.
Test: `--cash=N --talk=ComradeWhiskers --choose=0,K` (client: add `--wait=120`).

## Interaction framework (E key)
`scripts/interactable.gd` (`Interactable`): anything in group `interactables` answers `interact_distance(cat)` (-1 = not
now), `interact_prompt(cat)` ("" = no HUD line), `interact(cat)`, optional `interact_priority()` (items 30, NPCs 20, stash 10,
car 0). cat_player E -> `Interactable.try_use(cat)`; hud.gd `_update_prompt` shows `Interactable.prompt_for(cat)` in `Prompt`.
`Interactable` is also a node (Prompt/Radius/Priority exports, `used(cat)` signal; `Interactable.make(parent, at, text, r, prio)`):
the stash lockers are one. Members: ItemManager (nearest press-E street item), Npc (+ Payphone/Shopkeeper), GetawayCar
(`nearby_car` door zone, "GET IN"). Runs on the presser's computer; game changes go through host RPCs. Never add
interact branches to cat_player. Test: `--press_key=E` (waits 10 physics frames after `--pos`), `--talk`, `--grab`.

## Quest framework
`scripts/quests/quest_manager.gd` (`QuestManager.instance`, `Quests` node): cards = `QuestData` .tres in
`res://quests/` (auto-loaded). Host-authoritative `active`/`completed` per peer, synced via `_set_quests`;
progress is counted from the backpack (`count_in_bag`, not synced separately). `fish_heist.gd` calls
`complete_on_extract` at the exit (items stay in the backpack) and adds the bonus in `_extracted`. (No HUD quest line any more.)
ONE QUEST AT A TIME: `current_quest(id)`, `giver_of(id)` (`givers`, 5th arg of `_set_quests`), `progress_text(id)`;
host `_request_start` refuses while one is active; `Npc._choose` says `busy_lines` instead; inventory JOB box + ABANDON
(`abandon_quest`, hub only, two presses). Test: `--quest=X --abandon_quest`.
Five shared cards (table in SETUP_GUIDE §8), `QuestData.kind`: CARRY_ITEM (bag), DESTROY_ROOMBAS, EXTRACT_AT_HEAT
(`heat_needed`), DISRESPECT. Kill / disrespect counts = host `tallies` from Events (`enemy_destroyed` + `Enemy.killed_by`,
`player_robbed`, `player_slapped` from `request_shot`'s melee flag), synced in `_set_quests`, wiped by `player_knocked_out`.
Quest givers = 5 per sewer in matching spots (REBELLION recruits: only there once recruited at the workbench), both gangs use the same quest ids; pages ready/waiting/thanks/hello/ask/about/
blame/remind (Frankie and Jax have no "ready" page: their progress is live heat). Story: SETUP_GUIDE "Night of the Big Red Button".
Test: `--talk=PaulieNoBrooms --choose=0,0 --kill_roombas=5 --heat=80 --goto_dropoff_after=60 --talk_again_after=40`;
`--quest=ID` skips the NPC (use it with `--deploy`, `--talk` pulls the cat back to the hub).

## Git
Git for Windows is NOT on PATH in Claude's shell: use `& "$env:ProgramFiles\Git\cmd\git.exe"`.
Branch `main`. Commit after each finished, tested piece of work (commit messages via a no-BOM
message file — PowerShell here-strings piped to git break). The owner pushes to GitHub with
GitHub Desktop; don't push or change remotes unless asked.

## Testing without the user (dev_capture.gd autoload)
Godot console exe: `C:\GoDot\Godot_v4.7.2-stable_win64_console.exe`. Run from the project folder:
- Script check: `--headless --path . --import`
- Screenshot: `--path . -- --host --capture=shots/x.png [--pos=x,y,z --yaw=deg --pitch=deg --drive]`
- Multiplayer: start a `--host` process with `Start-Process` (redirect output), wait ~4 s, start a
  `--join` one. Host's `--frames` must outlast the client's. Useful: `--name=`, `--hold=ACTION
  --hold_delay=N --hold_frames=N`, `--exit_after=N`, `--track=N`, `--net_interval=S`.
- DevCapture finds the game via `Game.instance` (current_scene is GameScreen). Captures save the whole
  window (HUD included); `--scale=N` = N screen px per game px.
- Captures print car/cat state (`DevCapture ...` lines) — prefer checking those over viewing images;
  view screenshots only when judging visuals, and use `--scale=2` to keep them small.
- `shots/` has a `.gdignore`, so Godot ignores it.
- Trailers (`trailer/`, gdignored, SETUP_GUIDE §15): `record.py` = shot list run through Movie Maker
  (`--write-movie`, temp `override.cfg` for 16:9, music muted, `--seed=1999`) using DevCapture's film camera
  (`--no_hud --cam_from/to --look_from/to --cam_follow --cam_orbit --near_beam --hold_all`); `music.py` = numpy
  synthwave (bars of 2 s); `edit.py` = ffmpeg edits -> `shots/trailer/out/`; `contact.py` = contact sheets.

## Style references
`C:\Users\Nathaniel\Desktop\Game Styling` — fog, glowing light pools in darkness, OSRS flat-shaded
low-poly, dithering, CRT.

## Direction
Extraction game. Story: OVERCLEAN (the AI) runs the city; the cat rebellion hides in the sewers. Spawn in
the hub, go up the entry manhole, loot, find the exit via a payphone, extract. Heat 100 = hatch sealed +
DEEP CLEAN, then a new district (new seed). Scrap + per-gang MAINFRAMES + the SEWER BREACH (0%) are in.

## Patch notes (Discord) — in chat, NO file
There is no PATCH_NOTES.md any more (user's call, 10 Nov 2026: it was deleted; old drafts are in git history before
that date). At the END OF EVERY TURN that changed something players would notice (features, balance, fixes; not test
tools, refactors or guide edits), finish the reply with a ready-to-paste Discord post inside a ```text code block:
`## 🐾 New` / `## 🔧 Changes` / `## 🐛 Fixes` sections (only the ones used), `-` bullets with a **bold** lead, plain player
language (no code names, no file names), under 2000 characters (split into "part 1/2" blocks if longer). The user
posts it to Discord by hand. Don't keep a running draft anywhere.
