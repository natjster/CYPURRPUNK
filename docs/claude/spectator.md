# Cat-cam / spectating

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

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
