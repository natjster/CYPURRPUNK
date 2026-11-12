# UI looks, HUD, menus

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- UI LOOKS: `Settings.modern_ui` (SETTINGS > EFFECTS > UI STYLE). false = PS1: `menu_viewport` and every HUD SubViewport render at game pixels
  (size = the pane's game viewport, `size_2d_override` keeps the layout), blown up nearest, and `CRTOverlay` (top-level ColorRect, psx_post with `pixel_scale`/`area_offset`/`area_scale`) covers game+HUD+menus; the per-pane CRT is off (`_game_dither` hidden, panes show the raw viewport). true (default) = MODERN: real-res UI, overlay hidden, per-pane CRT on. One player + PS1: `hud_scale_for` = fit * `ps1_hud_scale` (1.33). Thin lines in HUD `_draw` need `Hud.line(w)`, text outlines `Hud.outline(w)`, small font sizes `Hud.text_size(n)` (PS1 min 18). TOP ROW (Health | DropOff | Heat) is laid out every frame by hud.gd `_layout_top_row` (bars shrink, DropOff drops under them on narrow screens; `_second_row_shift` moves Feed/Scoreboard/StatusIcons): never set those widths elsewhere. `limits/global_shader_variables/buffer_size` is raised on purpose (city `instance_tint` overflowed it).
- HUD = `scenes/ui/hud.tscn` (`scripts/ui/hud.gd`, class `Hud`), a CanvasLayer OUTSIDE the game viewport, in a SubViewport (`GameScreen._seat_huds[seat]`, seat 0 too: GameScreen._input pushes each seat's events to its HUD first; player 1's mouse only while `Hud.wants_input(0)`). Use the statics: `Hud.set_text/show_element/set_color/
  show_message/popup/set_in_game/element` by label name (Health, StatusIcons [HudStatusIcons, buff badges, fed by hud.gd
  `_update_status` from `cat.sticky/boost/air_jump_fraction()`; drops under the bar when the heat bar is in the way],
  Heat [HudHeatBar, top-right, fed by heat_meter], DropOff, Scoreboard [sewers only] |
  Popup, Crosshair, Message, Prompt, Held [HudWeaponDisplay: gun side-profile icons heat blue->red per paw, dual = stacked,
  gun name + fire key hidden (`show_weapon_name`/`show_fire_key` = false), 2 quick-use squares; fed by `ItemManager._update_hud_for` -> `show_loadout(paws, quick)`], Boost [HudBoostBar, bottom-left above Held,
  driver only, `_update_boost`]).
  OCEAN-BLUE STYLE = `HudStyle` (`scripts/ui/hud_style.gd`, settings `ui/hud_style.tres`): `HudStyle.current()`, `draw_panel`,
  `heat_color(heat)` (`heat_blend`), `item_icon/status_icon/npc_portrait(id)`, `draw_icon` (fits the PNG's used rect). Use it for
  phases 2-4 (Inventory, Shop, Workbench). `ui/hud_theme.tres` (talk box + pause buttons/panels) uses the same ocean-blue
  values by hand (+ `HudStyle.draw_corners` on NpcDialog's Panel); the Compass arrow reads HudStyle (`use_hud_style`).
  Heat bar = health-bar mirror (number box + thin bar); ticks / EXIT tick / MAINFRAME tag exports default OFF.
  CARDS (`hud_cards.gd`, first child of Middle) draw HudStyle panels behind Banner / Popup / Message sized to their text
  (`draw_panel(..., alpha)` fades with them). Popup = right-side reward card (anchor 0.36); `Hud.banner` clears the popup.
  No crosshair in `UndergroundHub.is_safe` (item_manager); empty quick slots aren't drawn; sewer title hidden while TutorialBox shows. Feed lines: `feed_seconds` 4 + `feed_fade_seconds`.
  Sewer title (DropOff in the hub) fades after `FishHeist.sewer_title_seconds` (`_show_sewer_title`, per seat; hidden after = bars get the row).
  Test: `--hud_heat=R,L --hud_buffs=sticky,catnip,catdip` ("DevCapture hud loadout"). `Frame/Top` stays during NPC talk, `Frame/Middle` hides;
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
- MENU LOOK (12 Nov 2026) = the HUD's ocean blue: `ui/menu_theme.tres` (Consolas bold 8, boxes = `HudStyleBox`
  `scripts/ui/hud_style_box.gd`, a scripted StyleBox with fill/border/corner brackets/glow, menu units = 1/3 HUD units).
  Titles soft pink `Color(1, 0.55, 0.85)`, values `Color(0.55, 0.9, 1)`. CatCreator node now carries the theme too.
  Start-menu logo = `Lobby/Logo` (`MenuLogo`, `scripts/ui/menu_logo.gd`, drawn; main_menu flickers its alpha); the tagline is gone.
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
- PLAYER FEEDBACK: autoload `Feedback` (`scripts/feedback.gd`). `shake(player_id, 0..1)` / `shake_near(pos, amt, radius)` = camera
  `h_offset/v_offset` trauma (local players only, x `Settings.screen_shake`; game_screen.gd copies the offsets onto couch panes).
  `hit_landed(seat, crit)` is called by `Hud.damage_number` (hitmarker + throttled "hitmarker" sound). Host: `enemy_smashed(killer, pos,
  boss)` from `Enemy.explode` -> `_boom` rpc (shake near) + `_kill_confirmed` rpc_id to the killer (red `HudHitmarker`). `hurt(id, amount)`
  from cat_health `_set_health` -> `HudHurtFlash` (also pulses <30% HP by itself). Host `Events.item_picked_up` -> `_got_item` rpc ->
  `HudLootToast.add`. Gun `camera_kick` (Feel group), melee `hit_shake`. Sounds from `tools/make_feedback_sfx.py`. Test: `--feedback_test`
  (fights.gd; the snap waits for the test, so use `--frames=4`).
  Hurt numbers: `Feedback.hurt` -> `Hud.hurt_number(where, amount, seat)` -> `HudDamageNumbers.spawn(..., hurt=true)` (red). Crits have
  no "!" any more. MELEE JUICE lives in `melee_weapon.gd` ("Swing Juice" group): Y-sweep slash, hit-stop (tween_interval), lunge
  (owner, velocity), world-space ImmediateMesh trail from the bat ends (`_find_bat_ends`), `show_swing(connected, hit_spots)` ->
  `_impact` sparks + light on every computer. Test: `--give=neon_bat --swing_test[=S] --frames=2`.
  COMBO ("Combo" group): owner `combo_step` 0 forehand / 1 backhand / 2 SLAM (HOLD-to-charge, see items.md; full in the air = slam + dive), `show_swing(connected,
  spots, step, slam_spot)`; slam = box x`finisher_reach` + sphere at `_ground_below`, `Hit.push_scale` (cat/car shove x), stun,
  `_shockwave` (open CylinderMesh wall, a flat torus was invisible at 240p). Test: `--deploy --give=neon_bat --bait_roomba=2
  --combo_test [--air_slam] --frames=2` (DevCapture waits all --frames AFTER the test).
