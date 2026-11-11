# The tutorial

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- TUTORIAL (SETUP_GUIDE §19): `scripts/tutorial.gd` (`Tutorial.instance`, node `Tutorial` under Main, in `GameSystems.GROUP`),
  menu PLAY > TUTORIAL (`MainMenu.tutorial_pressed` -> `Game.tutorial_game()`; `Game.is_tutorial()` static, reset in `_ready`).
  9 steps (`step` 1..9, `phase` for sub-steps, DONE=10 -> banner -> `_back_to_menu(false)`), HUD `Frame/Top/TutorialBox`
  (`TutorialStep`/`TutorialHint`), code-built cyan beacon. Training rules: `PlayerProfile.restore` sends $starting_cash + empty
  stash and never reads/writes the save; heat held each physics frame (priority 100; step 8 = `exit_heat`); `Tutorial.health_floor()`
  in `CatHealth.damage`; `Tutorial.allows_deploy()` in `hub.deploy`; `prepare()` sets the Mainframe charge (the 6-slot backpack fits 3 fish + the electronics; step 7's bot drops ELECTRONICS, step 9 = E then the window's FEED); city via `_begin_game(seed, showcase=true)`. Test: `--headless -- --tutorial --tutorial_auto --capture=shots/tut.png` (needs --capture or DevCapture never runs; exit 0 = pass).
  BLUE ARROW: tutorial `_point_compass` drives HUD `Compass` on steps 1-7/9 (fish_heist nulls its compass then); step 8 = fish_heist's
  real PAYPHONE -> EXIT arrow, no beacon, `step8_exit_title` at phase 1. `--tutorial_shots` (windowed) saves shots/tutorial_step*.png.
