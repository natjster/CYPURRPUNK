# Cat models, CatLook, several cats, menu flow

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

CHARACTER + BOT MODELS (Phase 1, 10 Nov 2026): CATS = the ORIGINAL code-built cat (`scenes/cat_model.tscn` primitive meshes;
each NPC scene builds its own Model with hat/cigar etc.), accessories ON (`CatLook.SLOTS` hat/face/neck). The Blockbench mascot cat
(`models/blockbench/cat.bbmodel`) was REVERTED (user's call: liked the original cats); don't swap it back unasked.

`scripts/cat/cat_look.gd` (`CatLook`, static): a look = Dictionary of colours (`COLOR_KEYS`, painted onto
`scenes/cat_model.tscn` meshes by name via `COLOR_PARTS`, plus any descendant mesh named `Fur_*`/`Markings_*`/`Eyes_*`/`Nose_*`:
paws, cheek tufts, inner ears, tail tip; legs stay 0.2 tall + tail 0.45 (walk hinges); test `--cat_lineup[=res://x.tscn]`)
+ part id per slot (`SLOTS`, at `SLOT_ANCHORS`). Nov 11 2026: user chose to KEEP the original cat and only smooth/detail it
(8 candidate redesigns, primitive + Blockbench, were rejected and deleted).
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
