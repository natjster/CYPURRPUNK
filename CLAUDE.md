# CYPURRPUNK — notes for Claude

Godot 4.7.2 multiplayer PS1-style cyberpunk cat game. The user is a non-coder: keep code heavily
commented, expose tuning as `@export`, give Godot editor click-paths, and update the user-facing guide
(`SETUP_GUIDE.md` = contents page, the sections live in `guide/NN-*.md`) whenever behaviour or node trees change.

## READ THIS FIRST: the notes are split by system (keeps every session cheap)
This file only holds what EVERY task needs. Each system's notes live in `docs/claude/<topic>.md`.
Before changing or debugging a system, read ONLY the topic file(s) it touches (they are 1-7 KB each):

| Topic file (`docs/claude/`) | Covers |
|---|---|
| `ui-hud.md` | UI LOOKS (PS1 / MODERN), the HUD + its statics, top row, HudStyle, menu view / PS1Overlay, PLAYER FEEDBACK (shake, hitmarker, hurt edges, loot toasts) |
| `couch-coop.md` | lobby, Seats, Controls + rebinding, SeatFocus, on-screen keyboard, PlayerPause, split screen |
| `networking.md` | 8-player balance scaling, replication intervals, net stats, Net autoload (ENet, LAN, UPnP room codes) |
| `interaction.md` | the E-key Interactable framework (prompts, priorities, members) |
| `city.md` | CityGenerator (determinism!), LevelKit models + street props, DISTRICT TWISTS, MEOW-MART interior |
| `gangs-modes.md` | CO-OP vs TURF WAR, Teams, gang hubs, PvP, robbing, feed, solo/co-op layout |
| `heist.md` | extraction loop, hub deploy/return, loot tiers, HEAT + bosses, one trip per district, manholes, payphones, exits, green arrow |
| `enemies.md` | Enemy + Hit frameworks, VAC-COP Roomba, drones/trappers, bot models, eye weak spot |
| `mainframe-breach.md` | per-gang Mainframe charge, scrap, SEWER BREACH, NPCs fighting |
| `health-cash-saves.md` | CatHealth (downed / revive / KO), Wallet, stash (litterbox), profiles |
| `cat-and-cars.md` | CatPlayer sync, cars, passengers (GUNNER seat, riding), car model, CAR HEALTH + wrecks, AFTERBURNER boost |
| `cat-look.md` | cat models (original cats stay!), CatLook, several cats per player, menu flow |
| `items.md` | items framework, ONE BACKPACK, inventory view, SHOP, quick use, melee, weapon extras + models |
| `npcs-quests.md` | NPC framework, shopkeepers, loot table, quest framework |
| `upgrades.md` | sewer upgrades, Tinker Workbench, Sewer Rebellion, rides |
| `mess.md` | mess-making, street props pack, scavenging, meow taunt |
| `sound-voices.md` | Sound autoload, OVERCLEAN announcer + loudspeakers, NPC voices |
| `spectator.md` | cat-cam / spectating, heckles |
| `raid-report.md` | raid report, awards, report screen |
| `tutorial.md` | the tutorial |
| `tools-pipeline.md` | Android export, CI builds, icon/model/sound tool servers, trailers |

When you ADD a system: give it its own topic file (or extend the closest one) and one row above. Keep this file
short; detail goes in topic files. When notes in a topic file go stale, fix them there.

## Keeping usage low (the user asked for this, 11 Nov 2026)
- Don't read whole big files. `guide/` sections, `dev_capture.gd`, `item_manager.gd`, `meow_mart_interior.gd` etc.:
  grep for the function/heading, then Read with offset/limit around it.
- Updating the guide = edit only the matching `guide/NN-*.md` section file (grep it first), never re-read all of it.
- Prefer `DevCapture ...` text lines over screenshots; when a picture is needed use `--scale=2` and view only that one.
- Don't spawn subagents / workflows unless the user asks: each one re-reads all of this from scratch.
- Run long test batches in one command and print only the lines you need (pipe through `Select-String "DevCapture"`).
- `.claude/worktrees/` holds old copies of the whole project: never search inside it.
- The art/sound tool servers (`.mcp.json`) are off by default; see `docs/claude/tools-pipeline.md` to turn them on.
- Files over ~800 lines (`meow_mart_interior.gd`, `item_manager.gd`, `hub.gd`, `cat_player.gd`, `city_generator.gd`,
  guide sections over ~25 KB): when a task already touches one, split a self-contained chunk into its own file (like
  `scripts/dev_tests/`), so later sessions read less. Don't split files just for the sake of it.
- This file must stay under ~10 KB: new detail goes in a topic file, with at most a one-line pointer here.

## Layout
- Main scene = `scenes/game_screen.tscn` (`scripts/ui/game_screen.gd`, `GameScreen.instance`): `main.tscn`
  runs inside `GameView/GameViewport` (SubViewport, 240 tall, width from `Settings.widescreen`/
  `pixel_perfect`), blown up with nearest filtering; `_input` forwards events into it (push_input).
  Root window = stretch `canvas_items`, keep_height, 960x720 base ("HUD units").
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
- Autoloads: `Net` (`scripts/net.gd`: ENet/LAN/UPnP room codes, the only file that knows the transport;
  details in `docs/claude/networking.md`), `Settings` (`scripts/settings.gd`: all player settings,
  saved to `user://settings.cfg` = `%APPDATA%\MeowCity1999` (old name kept on purpose so saves survive the rename to CYPURRPUNK); test runs with `--capture` use
  defaults and never save), `Controls`, `Events`, `DevCapture` (debug builds only).
- EVENTS: autoload `Events` (`scripts/events.gd`): signals `district_sealed`, `player_extracted`, `player_knocked_out`,
  `heat_level_changed` (every computer), `item_picked_up`, `enemy_destroyed` (host only). Announce moments there instead of
  calling other systems (RoombaPatrol listens to `district_sealed` for the swarm, `deep_clean_roombas` is on Roombas). Test: `--event_log`.
- `shaders/psx_lit.gdshader` (all 3D: jitter, affine UVs, flat shading, emission, specular) and
  `shaders/psx_post.gdshader` (CRT + 15-bit dither, on a ColorRect). Renders at 320x240.
- Hand-written `.tscn` files: use `position`/`rotation` properties, not Transform3D matrices.

## Interaction framework (E key)
`scripts/interactable.gd` (`Interactable`, group `interactables`): never add interact branches to cat_player.
Details in `docs/claude/interaction.md`.

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
- dev_capture.gd = option list (header) + `_ready` flow + small checks. Bigger tests live in `scripts/dev_tests/`
  (lineups, menus, fights, tutorial, mess, spectate_report, meow_mart): child nodes made by `_add_module`, called as
  `_menus._shop_test(...)`; shared helpers + `_args` in `dev_test.gd` (base of all of them). New test = add it to the
  matching module (or a new one + an `_add_module` line), never back into dev_capture.gd. RPCs stay in dev_capture.gd.

## Style references
`C:\Users\Nathaniel\Desktop\Game Styling` — fog, glowing light pools in darkness, OSRS flat-shaded
low-poly, dithering, CRT.

## Direction
Extraction game. Story: OVERCLEAN (the AI) runs the city; the cat rebellion hides in the sewers. Spawn in
the hub, go up the entry manhole, loot, find the exit via a payphone, extract. Heat 100 = hatch sealed +
DEEP CLEAN, then a new district (new seed). Per-gang MAINFRAMES (fed ELECTRONICS from bosses, slow drain) + the SEWER BREACH (0%)
are in; SCRAP only pays for upgrades.

## Patch notes (Discord) — in chat, NO file
There is no PATCH_NOTES.md any more (user's call, 10 Nov 2026: it was deleted; old drafts are in git history before
that date). At the END OF EVERY TURN that changed something players would notice (features, balance, fixes; not test
tools, refactors or guide edits), finish the reply with a ready-to-paste Discord post inside a ```text code block:
`## 🐾 New` / `## 🔧 Changes` / `## 🐛 Fixes` sections (only the ones used), `-` bullets with a **bold** lead, plain player
language (no code names, no file names), under 2000 characters (split into "part 1/2" blocks if longer). The user
posts it to Discord by hand. Don't keep a running draft anywhere.

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- For cross-module "how does X relate to Y" questions, prefer the `graphify` MCP tools (`query_graph`, `get_node`, `shortest_path`) or `c:\Users\Nathaniel\graphify-godot\.venv\Scripts\graphify.exe query "<question>"`, `path "<A>" "<B>"`, or `explain "<concept>"` over grep — these traverse the graph's EXTRACTED + INFERRED edges instead of scanning files
- After modifying code files in this session, run `c:\Users\Nathaniel\graphify-godot\.venv\Scripts\graphify.exe update .` to keep the graph current (AST-only, no API cost)
