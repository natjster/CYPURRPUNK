# 8-player balance + network sync

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- Phase 7 (8 players): balance scales with `Game.player_count()` (Roombas `extra_roombas_per_player`, heat
  `heat_per_extra_cat`, Items `regrow_faster_per_player`). Hub `free_spawn_position`.
  Sync: cat/car `replication_interval` 0.033, roomba 0.05 (host sends ~12 KB/s for 8 players). RoombaPatrol only
  runs after `start_district` (the start menu counts as "server": it used to spawn Roombas that broke joining).
  A real controller on this PC can disturb `--hold` tests (its events mix into actions). Test: `--net_stats=N`,
  `--pad_press_delay=N`.

## Net autoload (`scripts/net.gd`) — transport, LAN, internet
(Moved out of CLAUDE.md on 11 Nov 2026 to keep every session cheaper.)
- ENet host/join/leave on port 7777. The ONLY file that knows the transport; Steam swaps in here.
- LAN discovery: hosts broadcast `Net.advert` (set by game.gd `_process`) on UDP 7778; the MULTIPLAYER screen calls
  `start_listening()` -> `found_games` / `games_changed`.
- INTERNET: `host()` starts a UPnP Thread; `upnp_status` ""/opening/ready/unavailable + `room_code`, signal
  `upnp_updated`, `ip_to_code`/`code_to_ip`; `join` takes a code or address; `_close_router` runs in
  `_go_offline`/`_exit_tree`. Invite rows live in PauseMenu + PlayerPause. Test runs never touch the real router.
- Test: `--test-room-code`, `--fake_upnp=IP|off`, `--address=`.
