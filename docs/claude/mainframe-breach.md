# Mainframe charges, scrap, the Sewer Breach

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- MAINFRAME = `scripts/mainframe.gd` (`Mainframe.instance`, `Mainframe` node ABOVE Heat/Roombas: GameSystems order sets overclock
  first; in `GameSystems.GROUP`): one node, PER-GANG `charges[team]` 0-100 FLOAT (`charge_of/percent/cells/tier/tier_name/tier_color(team)`, `_set_charges`, start 75).
  CELLS (11 Nov 2026): tier = `cells_of(charge)` = ceil(charge/25) (4 battery cells; 60% = 3 cells = ONLINE), so 1 feed = 1 tier.
  SLOW DRAIN `_slow_drain` (host): `drain_per_minute` (1) while `players_up_top()>0` (`drain_only_while_raiding`), broadcasts only when a whole
  % changes; a cell running dry -> `_cell_ran_dry` RPC (HUD feed line). `_refresh_district` compares TIERS (not exact charges).
  -25 on `Events.district_sealed` for `active_gangs()` (>=1 player). FOOD = ELECTRONICS (`FUEL_ID` "electronics", `items/electronics.tres`, only the
  boss drops it: roomba_boss.tscn `drop_on_destroy=electronics`, once per cat; `drop_also` is empty since 11 Nov 2026: bosses drop no scrap). SCRAP (`SCRAP_ID`) = upgrade money ONLY.
  E at the hub `MainframeTerminal` (always shown, prompt has %) opens `MainframeScreen` (`scripts/ui/mainframe_screen.gd`, HUD `Frame/Mainframe`,
  `for_seat/is_open_for`, in `Hud.wants_input` + `cat._menu_open`; gauge, numbers, about text export, tier table, FEED/LEAVE + SeatFocus);
  FEED -> `request_feed(player_id)` (`near_mainframe`) does `use_for(team)` (`FeedUse`): FEED +25 under `full_at` (90) / HACK `hack_target(team)` -25
  (feed line `_hacked`) / FULL refuses; `_feed_result` -> `MainframeScreen.note` when open, else Hud message.
  MODEL `models/mainframe.glb` (`tools/make_mainframe_spec.py`, kind "set_piece" 500 tris): hub.gd `_build_mainframe` (west wall at mainframe_spot.z,
  yaw -PI/2) adds the screen box/signs, 4 gauge cells (`_gauge_cells`, scaled by charge in `_update_mainframe_model`), Fan group spin, StaticBody. `exit_heat(team)` = that gang's exit, live;
  `lowest_charge()` sets city-wide `starting_heat()` / `heat_multiplier()` / `boss_at_start()`. `_refresh_district` (host, each second + after a feed):
  while `went_up.is_empty()` a changed lowest restarts the district (covers late-arriving gangs too; `RoombaPatrol.restart_heat_levels` spawns the 0% boss).
  Not saved. The seal drains BEFORE `start_district`, so overclock needs a pre-trip feed. Heat bar: `set_heat(..., exit_heat)` draws the EXIT tick. SCRAP / ELECTRONICS = $0 loot (`sell_price_for` 0): the shop won't buy them, they stay in
  the bag at the exit; `ItemManager.is_stashable` lets them in the stash. Hub CRT `_update_mainframe_crt` runs on every hub. Test: `--mainframe=N` or `=A,B`, `--give=electronics --mainframe_window=N`
  ("DevCapture mainframe_window"), `--deploy --mainframe_drain=600`, `--mainframe=0 --deploy --kill_roombas=40 --kill_bosses` (drop counts).
- SEWER BREACH (`mainframe.gd`, host `_run_breach`): a gang reaching 0% gets one LAST RAID first (`_had_last_raid[team]` = at 0% as the district starts, `_note_last_raids`, banner; a hack before anyone goes up counts). `doomed_gangs()` = at 0% AND had it. Doomed + `sealed` + `players_up_top()==0` -> siren `_run_warning` / `_set_warning` RPC (`warning_teams`, `warning_left`, `breach_warning_seconds`, line = `breach_text`); `FishHeist._run_deep_clean` holds `new_district` while `breach_coming()`; electronics in time = cancelled. Time up -> `_start_breach` RPC (`breached_teams`, `breach_left`,
  `breach_busy` until the next district; Events `sewer_breached`/`sewer_breach_ended`). `hub.set_breached` = BlastGate (StaticBody, north tunnel `_build_breach_tunnel`) + red pulse. Use `UndergroundHub.is_safe(pos)` (not is_in_hub) for
  "nothing can hurt you" (damage, healing, guns). Horde: `RoombaPatrol._breach_queue`, bots have `breach_hub` (host only): `_can_chase` = anyone in that hub, route `hub.next_stop` (mouth, bridges), `ground_height()` for the drone, no respawns;
  patrol + FishHeist referee pause on `breach_busy`. Wipeout `_wiped_out` -> banner -> `_after_banner` (all reset to `starting_charge`); miracle = `_miracle` (reboot; `RoombaPatrol._set_off_bots` stuns the bots, then `Enemy.self_destruct()` one by one over `miracle_blast_seconds`: no kill credit, no drop). `HeatMeter.add_heat` ignores everything while `breach_busy`; breach bots don't steal loot; `ItemManager._on_city_generated` keeps drops on sewer floors. Both end in `Game.new_district()`. KO in a hub keeps gear and
  stays lying (`_knocked_out`), `_on_sewer_breach_ended` wakes + heals. LIVE FEED: `feed_camera_for(cat)`, `is_spectating(cat)` (blocks via `cat._menu_open`), `GameScreen._show_live_feed`, line = `breach_text` in DropOff, `Hud.banner`.
  NPCs FIGHT (`npc.gd`, parent is a hub + `breach_weapon`, polls `hub.breached`; `Npc.fighting` blocks E): instance a real gun scene on Model, draw with `Weapon.draw_shot`/`draw_blast`
  (no holder, no RPC: each computer sprays locally, only the host's shots call `take_hit`, city_heat 0). Blast guns = `Weapon.lob(from, to, height, seconds, on_landed)` for players and NPCs alike (exports `lob_*`, bounces in the gun scene; `draw_shot` lobs, the holder's computer `_blast`s on landing; a shot in the air dies with the gun), NPC host hits on landing. Knockdown is host-decided (`_knocked_down` RPC).
  Targets = group `Enemy.GROUP`. Cries = `BattleCryLabel`, a `hud_name_tags` marker (a real 3D label is unreadable at 240p). Loadouts on the NPC instances in main.tscn.
  Test: `--mainframe=0|75,0 --breach_seconds=S --breach_wipe=N --breach_log=N --breach_knock=N`.
