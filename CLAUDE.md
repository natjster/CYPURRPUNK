# MEOW-CITY 1999 — notes for Claude

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
  show_message/popup/set_in_game/element` by label name (Cash, Carrying, Health, DropOff, Scoreboard |
  Popup, Crosshair, Message, Prompt, Held). `Frame/Top` stays during NPC talk, `Frame/Middle` hides;
  whole HUD hides under full-screen menus (`Hud.menu_open()`). Never reference HUD nodes by path.
  HUD windows `Inventory` (`InventoryScreen`) + `NpcDialog` live in hud.tscn: while `Hud.wants_input()`
  GameScreen stops forwarding input so the root GUI gets it (HUD `_input` runs before GameScreen's).
  Overhead names: Label3Ds in group `hud_name_tags` are markers (made transparent; don't use
  `layers = 0`, it trips an engine light-pairing bug), `HudNameTags` (`Frame/Names`) projects them
  via the game camera. Test: `--mouse_test`, `--click_choice=N`, `--press_key=Tab`.
- `scenes/main.tscn` (script `scripts/game.gd`, class `Game`, `Game.instance`): starts games, spawns
  cats via `MultiplayerSpawner` → `Players/` (cats named by peer id; look up with
  `Game.instance.cat_for(id)` / `my_cat()`), late-joiner catch-up, CRT/fog settings.
- Autoloads: `Net` (`scripts/net.gd`: ENet host/join/leave on port 7777 — the only file that knows
  the transport; Steam swaps in here), `Settings` (`scripts/settings.gd`: all player settings,
  saved to `user://settings.cfg` = `%APPDATA%\MeowCity1999`; test runs with `--capture` use
  defaults and never save), `Controls`, `DevCapture` (debug builds only).
- Sound: autoload `Sound` (`scripts/sound.gd`): files in `res://sounds/{sfx,ambience,music}/` load by
  name (`meow_1/_2` = random variants of "meow"); `play` (2D, local), `play_at` (3D, local: use where
  every peer already runs the code), `play_everywhere` (3D, RPC to all), `attach_loop`, `play_music` /
  `play_ambience` (crossfade; hub.gd picks per area). Missing files are silent. Never hand-build
  AudioStreamPlayers elsewhere. Sound table in SETUP_GUIDE.md section 12. Test: `--sound_log`.
- UI under `PS1Overlay` (theme `ui/menu_theme.tres`): `Lobby` = `MainMenu` (`scripts/ui/main_menu.gd`,
  emits host/join/settings signals), `PauseMenu` (`PauseMenu.is_open` → cat/car/inventory ignore
  keys), `SettingsMenu` (`scenes/ui/settings_menu.tscn`, rows from its `TABS` list), `CatCreator`,
  then `ColorDepthDither` LAST. (`NpcDialog.is_open` -> cat ignores keys; it and `Inventory` are in the HUD.) Each menu handles its own Esc in `_input`; tree order decides who
  sees Esc first. (The HUD is not here: see `Hud` above.)
  Widescreen: the game viewport is always 240 tall but can be wider (`Settings.widescreen`).
  `PS1Overlay` (`scripts/ui/ps1_overlay.gd`) centres every menu child in a 320-wide column (full-rect
  ColorRect backgrounds stretched back out); ColorDepthDither is full width. HUD labels must use
  anchors (the HUD Frame matches the game picture's shape). Test: `--window=1720x720`.
- `scripts/city_generator.gd` (`CityGenerator`, the `City` node): the whole level is generated from a
  seed with one seeded RNG — keep all randomness on `_rng` and in a fixed order, or players' cities
  diverge. Host sends only the seed (`Game._receive_city_seed`). Centre crossroads, car spot
  (`CAR_SPAWN`) and Meow-Mart (`meow_mart_position`) are fixed for every seed. Buildings share
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
- Health: `scripts/cat_health.gd` (`CatHealth.instance`, `Health` node, HUD label `Health`): host-only
  `damage(peer, n, cause)` (Roomba `bonk_damage`); 0 HP = `ItemManager.drop_everything` + `_knocked_out`
  RPC to owner (`CatPlayer.knocked_out` flop, then `hub.return_cat`). Host heals cats in the hub.
  Roombas/extraction ignore `is_down` cats. Test: `--give=pistol --pos=-12,0,-6.5 --yaw=180 --bait_roomba=3 --frames=1500`.
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
Menu flow: Lobby MainScreen (PLAY/SETTINGS/QUIT) -> `CatCreator.open(false)` = CHOOSE YOUR CAT (NEXT
needs a name) -> Lobby ModeScreen (SOLO = `Game.solo_game`, offline peer, no Net.host / MULTIPLAYER ->
PlayScreen host/join). Pause > MY CAT = `open(true)` (no switching). Test: `--solo`, `--name=`, `--look=N`,
`--menu=cat|mode|play`; prints `DevCapture look`.

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
`complete_on_extract` BEFORE `take_bag` and adds the bonus in `_extracted`. HUD line `HUD/Carrying` shows
`hud_text()` when a quest is active. Lil' Mittens (`scenes/npcs/lil_mittens.tscn`, in the Hub) gives
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

## Style references
`C:\Users\Nathaniel\Desktop\Game Styling` — fog, glowing light pools in darkness, OSRS flat-shaded
low-poly, dithering, CRT.

## Direction
The game is now an extraction game: spawn in the underground hub, go up to the city for loot,
extract back down, with VAC-COP Roombas as the threat.
