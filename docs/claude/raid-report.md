# Raid report screen + awards

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

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
