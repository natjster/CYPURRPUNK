# Couch co-op: lobby, Seats, controls, split screen, per-player settings

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- Phase 6: couch LOBBY = `Seats.lobby_cats` (START on an unclaimed pad while main_menu mode/play screen is up;
  `cycle_lobby_cat`, `leave_lobby`; MainMenu eats seat>0 events; `Seats.start_lobby_players()` from
  `_start_playing`). Host refuses a couch player over `Net.MAX_PLAYERS` (`_add_player_refused` -> `Seats.refused`)
  or a whole computer (`_game_full` -> `Game.leave_reason`, shown on the menu). Per-player pause:
  `PlayerPause` in hud.tscn (only when `PlayerPause.split_active()`; else the big PauseMenu); blocks only that
  seat (`cat._menu_open`, `car._driver_paused`). Test: `--saved_cats=A,B`, `--pad_press=1:Start` on `--menu=mode`.
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
