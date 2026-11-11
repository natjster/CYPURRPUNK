# 8-player balance + network sync

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- Phase 7 (8 players): balance scales with `Game.player_count()` (Roombas `extra_roombas_per_player`, heat
  `heat_per_extra_cat`, Items `regrow_faster_per_player`). Hub `free_spawn_position`.
  Sync: cat/car `replication_interval` 0.033, roomba 0.05 (host sends ~12 KB/s for 8 players). RoombaPatrol only
  runs after `start_district` (the start menu counts as "server": it used to spawn Roombas that broke joining).
  A real controller on this PC can disturb `--hold` tests (its events mix into actions). Test: `--net_stats=N`,
  `--pad_press_delay=N`.
