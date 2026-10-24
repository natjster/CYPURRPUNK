# MEOW-CITY 1999 — notes for Claude

Godot 4.7.2 multiplayer PS1-style cyberpunk cat game. The user is a non-coder: keep code heavily
commented, expose tuning as `@export`, give Godot editor click-paths, and update `SETUP_GUIDE.md`
(the user-facing guide) whenever behaviour or node trees change.

## Layout
- `scenes/main.tscn` (script `scripts/game.gd`, class `Game`, `Game.instance`): starts games, spawns
  cats via `MultiplayerSpawner` → `Players/` (cats named by peer id; look up with
  `Game.instance.cat_for(id)` / `my_cat()`), late-joiner catch-up, CRT/fog settings.
- Autoloads: `Net` (`scripts/net.gd`: ENet host/join/leave on port 7777 — the only file that knows
  the transport; Steam swaps in here), `Settings` (`scripts/settings.gd`: all player settings,
  saved to `user://settings.cfg` = `%APPDATA%\MeowCity1999`; test runs with `--capture` use
  defaults and never save), `InputSetup`, `DevCapture` (debug builds only).
- UI under `PS1Overlay` (theme `ui/menu_theme.tres`): `Lobby` = `MainMenu` (`scripts/ui/main_menu.gd`,
  emits host/join/settings signals), `PauseMenu` (`PauseMenu.is_open` → cat/car/inventory ignore
  keys), `SettingsMenu` (`scenes/ui/settings_menu.tscn`, rows from its `TABS` list), `Inventory`,
  `NpcDialog` (`NpcDialog.is_open` -> cat ignores keys), then `ColorDepthDither` LAST. Each menu handles its own Esc in `_input`; tree order decides who
  sees Esc first. HUD labels all live under `PS1Overlay/HUD`.
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
  `HubNpc` Don Catleone (`scenes/props/don_catleone.tscn`) opens `NpcDialog`; "SEND ME UP TOP" calls
  `hub.deploy(cat)`. Host detects cats/driver at the beam in `fish_heist.gd` -> `_extracted` RPC ->
  owner calls `hub.return_cat`. Owners move their own cat with `CatPlayer.teleport_to`. The hub swaps
  the local mood (moon/rain off, green fog) when the camera is below the line.
- `scenes/player.tscn` + `scripts/cat_player.gd` (`CatPlayer`): owner-authoritative cat. Owner writes
  `sync_position` / `sync_model_rotation` / `player_name`; remote copies glide toward them in `_process`.
  Only `CatModel` rotates; body never does (camera is a child).
- `scenes/getaway_car.tscn` + `scripts/getaway_car.gd` (`GetawayCar`): arcade RigidBody3D. Authority =
  driver (host when empty); non-authority copies are frozen (kinematic) and glide to `sync_*`.
  Enter/exit go through host-validated RPCs (`request_enter`/`request_exit` → `set_driver`).
  Drive input (`throttle`/`steer`/`handbrake`) is filled by `_read_driver_keys()`; physics only reads it.
- `shaders/psx_lit.gdshader` (all 3D: jitter, affine UVs, flat shading, emission, specular) and
  `shaders/psx_post.gdshader` (CRT + 15-bit dither, on a ColorRect). Renders at 320x240.
- `scripts/input_setup.gd` autoload registers all input actions in code (not in project.godot).
- Hand-written `.tscn` files: use `position`/`rotation` properties, not Transform3D matrices.

## Items framework
All items go through `scripts/items/item_manager.gd` (`ItemManager.instance`, the `Items` node):
item cards are `ItemData` .tres files in `res://items/` (auto-loaded); held items with behaviour
extend `HeldItem`, guns extend `Weapon` (data-driven via exports). Host referees pickup/drop/
consume; inventories are `{"hands": [right, left], "bag": [...]}` (a 2-paw item fills both slots).
Held scenes are named `HeldR`/`HeldL` under each cat's `CatModel` so their RPCs line up.
World item IDs: city-placed items 0..N in placement order (deterministic), drops from 100000.
Other systems place items by joining group `item_placers` and implementing `place_items()`.
Don't add per-item pickup/sync code elsewhere. User-facing how-to: SETUP_GUIDE.md section 9.

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
- Captures print car/cat state (`DevCapture ...` lines) — prefer checking those over viewing images;
  view screenshots only when judging visuals, and use `--scale=2` to keep them small.
- `shots/` has a `.gdignore`, so Godot ignores it.

## Style references
`C:\Users\Nathaniel\Desktop\Game Styling` — fog, glowing light pools in darkness, OSRS flat-shaded
low-poly, dithering, CRT.

## Roadmap
`ROADMAP.md` is the Steam MVP checklist the user tracks. Tick its boxes (`[x]`) when you finish
an item, and add new items there rather than in this file. `PLAN.md` is the plan behind it (scope,
Fish Heist design, architecture, networking/determinism rules, milestone gates, calendar): follow
it, and update it when a decision or milestone changes. `DESIGN_DOC.md` is the owner's long-term
vision (F2P PvPvE extraction, hub, proximity voice...); it conflicts with PLAN.md in places, and
PLAN.md wins until the owner decides otherwise.
