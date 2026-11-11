# Game modes (CO-OP / TURF WAR), gangs, PvP, solo layout

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- GAME MODE: `Game.is_turf_war()` (static, `_turf_war_game`, reset in `_ready`) = the ONE answer to "classic one-crew layout or
  gangs?". CO-OP (default; SOLO + TUTORIAL always) = everyone gang 0 (`Teams.picked` returns CATLEONE), one centre entry, one exit,
  GangCar freed (`_set_mode`, on clients too), no hack (`hack_target` -1), no rival live feed (`is_spectating`), no "WINS" banner.
  Host sets it in `_begin_game` from `Teams.turf_war_pick` (landing MODE row `[<] MODE [>]`, P1 only; online the host's wins) and
  `_receive_mode` RPC goes to every joiner BEFORE `_receive_city_seed`. `Seats.coop` is only about controllers. `NpcPage.coop_lines`
  (said instead of `lines` outside TURF WAR: Sal's respect quest). Advert `turf_war`. Test: `--mode=coop|turf` (`--teams=` implies turf;
  `--mode` wins), `DevCapture mode:` line (cats id:gang, entries, exits, cars). Old PvP / two-gang recipes need `--teams=`.
- GANGS (PvP phase 1, TURF WAR only): `scripts/teams.gd` static `Teams` (0 CATLEONE / 1 BURROW, NAMES/COLORS, `picks[seat]` set on the
  landing page: P1 GANG button, P2-4 LB/RB; SOLO resets to 0). `CatPlayer.team` (synced, set from `local_player_info`
  "team"; name tag colour). One `UndergroundHub` per gang: `Hub` (team 0, Don + Comrade Whiskers) and `GangHub` (team 1,
  x=200, Pawnie + Clawd shopkeeper; exports team/leader/shopkeeper/leader_glow/boss_name/lines). Use `UndergroundHub.of(cat)`
  / `for_team(t)` for spawn/return/deploy/stash; `instance` = team 0 and alone runs mood/music. Only gang-mates revive
  (`_anyone_could_help`/`_can_hold`/`downed_distance` check team); HudHealthBars friend = same team.
  PvP (phase 3): `CatPlayer.receive_hit` = own gang nothing; rival = shove + `CatHealth.request_shot(shooter, target, dmg)`
  (host checks gangs, up top, not in car, `pvp_max_range`, clamps `pvp_max_damage`; downed target = `_knock_out` if
  `shots_finish_downed`). Holding E on a downed RIVAL with loot = rob (`reviving[id].rob`, `rob_seconds`, `_rob` ->
  `ItemManager.steal_bag`, event `player_robbed`, red meter via health_bar_info `progress_color`). `CatPlayer.display_name()`.
  FEED: `Hud.feed(text, color)` -> `Frame/Top/Feed` RichTextLabel (downs/KOs/revives/robs, gang colour).
  Phase 4: `FishHeist.entry_position(team)` (outermost corner crossroads: 0 SW, 1 NE; hub.deploy pops out
  `surface_distance` towards the middle), `exit_positions[team]` / `exit_for(team)` (heist rng, `exit_min_distance` from
  every entry, `exit_spacing` apart; Manhole `glow_color` = gang colour), `revealed[team]` / `is_revealed(team)` via
  `request_reveal_exit` (caller's gang) and `_set_state(sealed, revealed_array)`; extraction only at your own gang's exit;
  phones ring until every gang in the game has called. Phone lines live on the hubs (`phone_too_early/exit_open/sealed`,
  payphone title = `boss_name`). Test: `--near_exit=3 --exit_team=1`, `--teams=1 --heat=80 --talk=Payphone0`.
  Not yet: team score / results, spawn protection.
  Test: `--teams=0,1,1 --add_local=2 --deploy --hold_all --give=pistol --shoot_rival=5 [--shoot_friend]`,
  `--down=1 --down_loot=fish --revive=150` (rob); a client's `--give` goes through the host's DevCapture `_test_give`.
- SOLO / CO-OP layout (`not Game.is_turf_war()`; local co-op also starts via solo_game, so never use "offline" for this):
  classic layout: `entry_position` = centre, one exit, GangCar freed in `_set_mode`, GetawayCar at CAR_SPAWN.
  `FishHeist.corner_position(team)` = a gang's corner regardless. Move cars ONLY via `_teleport` (done in
  `_integrate_forces`; plain `global_transform =` on a resting RigidBody is undone by physics).
