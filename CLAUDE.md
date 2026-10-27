# CYPURRPUNK — notes for Claude

Godot 4.7.2 multiplayer PS1-style cyberpunk cat game. The user is a non-coder: keep code heavily
commented, expose tuning as `@export`, give Godot editor click-paths, and update `SETUP_GUIDE.md`
(the user-facing guide) whenever behaviour or node trees change.

## Layout
- Main scene = `scenes/game_screen.tscn` (`scripts/ui/game_screen.gd`, `GameScreen.instance`): `main.tscn`
  runs inside `GameView/GameViewport` (SubViewport, 240 tall, width from `Settings.widescreen`/
  `pixel_perfect`), blown up with nearest filtering; `_input` forwards events into it (push_input).
  Root window = stretch `canvas_items`, keep_height, 960x720 base ("HUD units").
- HUD = `scenes/ui/hud.tscn` (`scripts/ui/hud.gd`, class `Hud`), a CanvasLayer OUTSIDE the game viewport,
  so it's sharp at real resolution and not CRT'd. Use the statics: `Hud.set_text/show_element/set_color/
  show_message/popup/set_in_game/element` by label name (Health, DropOff, Scoreboard [sewers only] |
  Popup, Crosshair, Message, Prompt, Held). `Frame/Top` stays during NPC talk, `Frame/Middle` hides;
  whole HUD hides under full-screen menus (`Hud.menu_open()`). Never reference HUD nodes by path.
  HUD windows `Inventory` (`InventoryScreen`) + `NpcDialog` live in hud.tscn: while `Hud.wants_input()`
  GameScreen stops forwarding input so the root GUI gets it (HUD `_input` runs before GameScreen's).
  ONE HUD PER LOCAL PLAYER: `Hud.seat`; `Hud.of(seat)`; every static takes an optional seat (labels default
  to seat 0; `show_message`/`popup` default -1 = all). Players 2-4's HUDs are hud.tscn copies in SubViewports
  (`GameScreen._seat_huds`, own GUI focus); GameScreen._input pushes seat>0 pad events to that HUD first.
  HUD scripts filter `Seats.seat_of_event(e) != seat` (player 1's root HUD hears every event). Per-player
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
  runs after `start_patrol` (the start menu counts as "server": it used to spawn Roombas that broke joining).
  A real controller on this PC can disturb `--hold` tests (its events mix into actions). Test: `--net_stats=N`,
  `--pad_press_delay=N`.
- Phase 8: `Seats.color(seat)` (SEAT_COLORS) = split-screen frame + "Pn" tag (GameScreen `_frames/_tags`).
  Per-player stick settings: `Seats.stick_speed/invert_stick_y/rumble_on(seat)` (seat 0 = Settings; others =
  saved cat's "controls" dict) set via `Seats.set_player_setting`; rows in PlayerPause (`_add_setting`; SeatFocus
  "adjust" meta = left/right changes a row). Unplugged pad: `Seats._on_joy_connection_changed` opens that
  player's PlayerPause(reason) (or the big pause solo), replug closes it; START on a free pad takes over an
  unplugged seat. Test: `--unplug=D [--replug]`.
  Overhead names: Label3Ds in group `hud_name_tags` are markers (made transparent; don't use
  `layers = 0`, it trips an engine light-pairing bug), `HudNameTags` (`Frame/Names`) projects them
  via the game camera. Test: `--mouse_test`, `--click_choice=N`, `--press_key=Tab`.
- `scenes/main.tscn` (script `scripts/game.gd`, class `Game`, `Game.instance`): starts games, spawns
  cats via `MultiplayerSpawner` → `Players/` (cats named by PLAYER id; look up with
  `Game.instance.cat_for(id)` / `my_cat()` (first local player) / `local_cats()`), late-joiner catch-up, CRT/fog settings.
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
  `_process`) on UDP 7778, the MULTIPLAYER screen `start_listening()` -> `found_games` / `games_changed`), `Settings` (`scripts/settings.gd`: all player settings,
  saved to `user://settings.cfg` = `%APPDATA%\MeowCity1999` (old name kept on purpose so saves survive the rename to CYPURRPUNK); test runs with `--capture` use
  defaults and never save), `Controls`, `DevCapture` (debug builds only).
- Sound: autoload `Sound` (`scripts/sound.gd`): files in `res://sounds/{sfx,ambience,music}/` load by
  name (`meow_1/_2` = random variants of "meow"); `play` (2D, local), `play_at` (3D, local: use where
  every peer already runs the code), `play_everywhere` (3D, RPC to all), `attach_loop`, `play_music` /
  `play_ambience` (crossfade; hub.gd picks per area). Missing files are silent. Split screen: only player 1's
  camera listens, so 3D sounds / loops nearer another local player are moved via `Sound.hearing_position`. Never hand-build
  AudioStreamPlayers elsewhere. Sound table in SETUP_GUIDE.md section 12. Test: `--sound_log`.
- UI under `PS1Overlay` (theme `ui/menu_theme.tres`): `Lobby` = `MainMenu` (`scripts/ui/main_menu.gd`,
  emits host/join/settings signals), `PauseMenu` (`PauseMenu.is_open` → cat/car/inventory ignore
  keys), `SettingsMenu` (`scenes/ui/settings_menu.tscn`, rows from its `TABS` list), `CatCreator`,
  then `ColorDepthDither` LAST. (`NpcDialog.is_open_for(seat)` -> cat ignores keys; it and `Inventory` are in the HUD.) Each menu handles its own Esc in `_input`; tree order decides who
  sees Esc first. (The HUD is not here: see `Hud` above.)
  Widescreen: the game viewport is always 240 tall but can be wider (`Settings.widescreen`).
  `PS1Overlay` (`scripts/ui/ps1_overlay.gd`) centres every menu child in a 320-wide column (full-rect
  ColorRect backgrounds stretched back out); ColorDepthDither is full width. HUD labels must use
  anchors (the HUD Frame matches the game picture's shape). Test: `--window=1720x720`.
- `scripts/city_generator.gd` (`CityGenerator`, the `City` node): the whole level is generated from a
  seed with one seeded RNG — keep all randomness on `_rng` and in a fixed order, or players' cities
  diverge. Host sends only the seed (`Game._receive_city_seed`). Centre crossroads and car spot
  (`CAR_SPAWN`) are fixed for every seed; Meow-Mart's lot is random (`meow_mart_position`). Buildings share
  materials; per-object colour comes from the shader's `instance_tint` instance uniform.
  Determinism check: DevCapture prints a city `fingerprint`; host and client must match.
  Large surfaces must stay subdivided (~2.5 m, `_box_mesh_for`): affine texture mapping on big
  triangles makes textures shear and swim. DevCapture `--no_affine` / `--no_snap` help diagnose.
  Never stack visible surfaces a few cm apart (e.g. sidewalk over street): they z-fight and
  flicker/streak at low camera angles. Ground is a non-overlapping tile grid (`_build_ground`).
- Extraction loop: cats spawn in the hub `Hub` (`scripts/hub.gd`, `UndergroundHub.instance`), a fixed
  code-built sewer at y=-200 (anything below y=-100 is "in the hub" = safe zone, guns don't fire).
  Don Catleone (`scenes/npcs/don_catleone.tscn`) is an `Npc`; his "send_up_top" action calls
  `hub.deploy(cat)`. Host detects cats/driver at the beam in `fish_heist.gd` -> `_extracted` RPC ->
  owner calls `hub.return_cat`. Owners move their own cat with `CatPlayer.teleport_to`. The hub swaps
  the local mood (moon/rain off, green fog) when the camera is below the line.
- Enemy: VAC-COP `Roomba` (`scenes/roomba.tscn`, `scripts/roomba.gd`), host-simulated CharacterBody on
  collision layer 2 (mask 1), others glide to `sync_position`/`sync_yaw`/`state`. `RoombaPatrol`
  (`Roombas` node + `RoombaSpawner`) spawns them at host start with its own RNG (not the city seed).
  Bonk = `get_zapped` + `ItemManager.take_one_loot` into `stomach`; guns call `take_hit` on the host;
  explode drops stomach via `ItemManager.drop_on_street`. Test: `--bait_roomba=D|aim`, `--zap_roomba=N`.
- Greed + pressure: loot tiers sardine $20 / fish $50 / `golden_koi` $400 (ItemData `carry_speed`,
  `noise`, `heat_on_pickup`, `pickup_announcement`; `ItemManager.carry_speed/loot_noise`). HEAT =
  `scripts/heat_meter.gd` (`HeatMeter.instance`, `Heat` node, host-only `add_heat`, shared 0..100,
  levels 1-5, NOT shown on the HUD: level-ups are sounds only): `RoombaPatrol._follow_the_heat` adds Roombas per level and spawns
  the boss `scenes/roomba_boss.tscn` (inherits roomba.tscn, `is_boss`, drops a koi) at 100.
  Heat is the DISTRICT CLOCK (never cools: cooling exports are 0; ~15 min up top to 100).
- Districts (`fish_heist.gd`): ENTRY `Manhole` (`scripts/manhole.gd`, code-built disc, textures/manhole_*.png) at
  the centre (one-way), EXIT manhole at `FishHeist.exit_position` (street spot from the heist rng), open while
  `exit_is_open()` (heat >= `exit_opens_at_heat` 75, not `sealed`). `Payphone` NPCs (`scenes/props/payphone.tscn`,
  `scripts/npcs/payphone.gd`, `Npc.prompt_verb` "USE") ring while open + not `exit_revealed`; a call ->
  `request_reveal_exit` -> host `_set_state(sealed, revealed)`; HUD `DropOff` arrow only when revealed.
  Heat 100: host seals, `RoombaPatrol.deep_clean_extra` swarm (spawns near cats, `swarm_sight_multiplier`),
  after `deep_clean_seconds` knocks out everyone up top, then `Game.new_district()` (new seed RPC, heat reset,
  `start_patrol`). Hub `deploy` refuses while sealed. place_items `remove_child`s old nodes (names stay
  `Payphone0..`). Test: `--heat=80 --talk=Payphone0`, `--near_exit=D`, `--heat=100 --heat_hold=30 --frames=4800`.
- Health: `scripts/cat_health.gd` (`CatHealth.instance`, `Health` node, HUD label `Health`): host-only
  `damage(peer, n, cause)` (Roomba `bonk_damage`); 0 HP = `ItemManager.drop_everything` + `_knocked_out`
  RPC to owner (`CatPlayer.knocked_out` flop, then `hub.return_cat`). Host heals cats in the hub.
  Roombas/extraction ignore `is_down` cats. Test: `--give=pistol --pos=-12,0,-6.5 --yaw=180 --bait_roomba=3 --frames=1500`.
  HP is 100 (Roomba 100, boss 600, bonk 34/67). Cyberpunk-style bars, all on the HUD: own bar = `HudHealthBar`
  (`Frame/Top/Health`, fed by cat_health `_process`); floating bars = `HudHealthBars` (`Frame/Bars`) for nodes in
  group `hud_health_bars` with `health_bar_info() -> {hp, max, position, show, name, boss}` (Roomba, other cats;
  boss = pinned top-middle); damage numbers = `Hud.damage_number(pos, amount, crit, seat)` (`Frame/Damage`).
  Weapon rolls `damage`/`crit_chance` on the shooter and sends it in `roomba.take_hit(shooter_id, amount)`;
  Roomba `health` is synced (synchronizer, on change).
- Stash + saves: inventories also hold `"stash"` (use `get_stash`; keep it when rewriting inventories).
  Host `request_to_stash`/`request_from_stash` need `hub.near_stash(cat)` (lockers on the east wall,
  `hub._build_stash`); the inventory screen (`InventoryScreen`) swaps the loot bag for the stash there.
  (`request_put_away` = paw -> backpack.) `scripts/player_profile.gd` (`Profile` node): each player saves
  their OWN cash + stash to `user://profiles/<name>.cfg`, sends it to the host on start/join
  (`_request_restore`, host validates), and saves only after `_restore_done`. Test runs use
  `user://test_profiles/` (`--fresh_profile`). Test: `--to_stash=hand:0`, `--from_stash=N`.
- `scenes/player.tscn` + `scripts/cat_player.gd` (`CatPlayer`): owner-authoritative cat. Owner writes
  `sync_position` / `sync_model_rotation` / `player_name`; remote copies glide toward them in `_process`.
  Only `CatModel` rotates; body never does (camera is a child).
- `scenes/getaway_car.tscn` + `scripts/getaway_car.gd` (`GetawayCar`): arcade RigidBody3D. Authority =
  driver (host when empty); non-authority copies are frozen (kinematic) and glide to `sync_*`.
  Enter/exit go through host-validated RPCs (`request_enter`/`request_exit` → `set_driver`).
  Drive input (`throttle`/`steer`/`handbrake`) is filled by `_read_driver_keys()`; physics only reads it.
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
  join / co-op drop-in). `Controls.notice_device` is fed ONLY player 1's events by Seats (prompts/rumble/mouse rule
  follow player 1). `Seats.game_started()` from `_start_playing`; tests skipping menus: `Seats.claim_for_p1`. Per-seat copies of every action
  (`jump@1`) are built from Controls.bindings; gameplay input MUST go through `Seats.is_pressed/is_just_pressed/
  get_axis/get_vector(cat.slot, ...)` / `Seats.event_is(slot, event, ...)` (plain actions = any device, menus only).
  Rebuilding seat actions releases held buttons: only rebuild when bindings/pads change (`_built_from`).
  START on an unclaimed pad in a CO-OP game = join (next unused saved cat, else `Settings.new_cat(false, "PLAYER N")`);
  `PauseMenu.opened_by` seat: LEAVE = `Seats.leave(seat)` for seats > 0. `Seats.seat_of_event(e)` (-1 =
  unclaimed pad: menus ignore it). Rumble: `Seats.rumble(player_id, ...)`. `InventoryScreen.owner_cat`.
  Test: `--join_pad=1`, `--pad_device=1`, `--pad_press=1:Start`.
- Split screen (`game_screen.gd`): pane 0 = GameView/GameViewport (player 1; only a slot-0 cat may
  `make_current`). Panes 2-4 are built in code: SubViewport sharing `game_viewport.find_world_3d()` + a Camera3D
  copying the cat's `camera` each frame (GameScreen process_priority 100), and a separate "Post" SubViewport
  whose Dither reads it via psx_post `use_source_texture` (a hint_screen_texture ColorRect inside a shared-world
  viewport showed player 1's picture). Layout from `shown_seats()` (cats with `reads_input`; [0] while
  `Hud.menu_open()`), `Settings.split_side_by_side`. Per-pane fog: `hub.environment_for(in_hub)` (null = world's);
  moon/music: anyone up top (`view_cameras()`). HUD frame = pane 0 (whole picture while `Hud.wants_input()`).
  Test: `--join_pad=1,2,3`, `--setting=split_side_by_side:false`.
- Hand-written `.tscn` files: use `position`/`rotation` properties, not Transform3D matrices.

## Character creator (MY CAT)
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

## Items framework
All items go through `scripts/items/item_manager.gd` (`ItemManager.instance`, the `Items` node):
item cards are `ItemData` .tres files in `res://items/` (auto-loaded); held items with behaviour
extend `HeldItem`, guns extend `Weapon` (data-driven via exports). Host referees pickup/drop/
consume; inventories are `{"hands": [right, left], "bag": [...]}` (a 2-paw item fills both slots).
Held scenes are named `HeldR`/`HeldL` under each cat's `CatModel` so their RPCs line up.
World item IDs: city-placed items 0..N in placement order (deterministic), drops from 100000.
Other systems place items by joining group `item_placers` and implementing `place_items()`.
Don't add per-item pickup/sync code elsewhere. User-facing how-to: SETUP_GUIDE.md section 9.

## NPC framework
Talking characters: `scripts/npcs/npc.gd` (`Npc`, StaticBody3D, group `npcs`), conversation data =
`pages: Array[NpcPage]` (first = greeting; empty choices reuse page 1's) of `NpcChoice` (text,
message, action, go_to). Built-in actions in `Npc._run_action`; custom ones via subclass
`_on_action` or the `action_chosen` signal. `Npc.try_talk(cat)` is called by cat_player on E;
`NpcDialog._process` drives the "[E] TALK TO" prompt. New NPCs start from
`scenes/npcs/npc_template.tscn`. Not networked (local per peer). Test: `--talk[=NodeName] --choose=N,M`.
Pages can gate the greeting on quest state (`only_if_quest`/`only_if_state`); action `quest:<id>` starts one.
Shops: `Shopkeeper` (`scripts/npcs/shopkeeper.gd`, extends Npc) — choice action `shop` opens BUY buttons for
its `stock`; prices = `ItemData.price` (0 = not for sale); host `ItemManager.request_buy` -> `FishHeist.spend`.
Comrade Whiskers (`scenes/npcs/comrade_whiskers.tscn`) runs THE BLACK MARKITTEN on the hub's west wall
(decor in `hub._build_shop`). The city places NO gear (`fixed_items`/`scattered_items` empty): only fish.
Test: `--cash=N --talk=ComradeWhiskers --choose=0,K` (client: add `--wait=120`).

## Quest framework
`scripts/quests/quest_manager.gd` (`QuestManager.instance`, `Quests` node): cards = `QuestData` .tres in
`res://quests/` (auto-loaded). Host-authoritative `active`/`completed` per peer, synced via `_set_quests`;
progress is counted from the loot bag (not synced separately). `fish_heist.gd` calls
`complete_on_extract` BEFORE `take_bag` and adds the bonus in `_extracted`. (No HUD quest line any more; `hud_text()` is unused.)
Lil' Mittens (`scenes/npcs/lil_mittens.tscn`, in the Hub) gives
`mittens_fish` (3 fish, +$100, repeatable). Test: `--talk=LilMittens --choose=0,0 --grab=fish,fish,fish
--goto_dropoff_after=20 --talk_again_after=40`.

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
DEEP CLEAN, then a new district (new seed). PLANNED next: scrap (Roomba drop, takes bag space: money vs
time) fed to a shared MAINFRAME in the hub that drains slowly + a chunk per sealed district; its level
sets the next district's starting heat; mainframe at 0 = boss-fight finale (design TBD).
