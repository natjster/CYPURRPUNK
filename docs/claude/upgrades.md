# Sewer upgrades, workbench, rebellion, rides

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)


SEWER UPGRADES (SETUP_GUIDE §25): `scripts/upgrades.gd` (`Upgrades.instance`, node `Upgrades` under Main right below Wallet, GameSystems).
`player_upgrades` {player_id: {id: tier}} synced (`_set_tier`/`_set_all`), `costs` export (id -> [[cash, scrap] per tier]), `INFO`/`WORKBENCH_TABS`.
Host `request_buy(player_id, id)` = Wallet.spend + `ItemManager.spend_scrap` (bag first, then stash; `scrap_count_of`). Read with static
`Upgrades.level(pid, id)` / `best_in_team(team, id)` (CREW: mainframe_capacitor, turbo_engine, insider_tunnel, afterburner = car boost charges, tab 3). Hooks: `ItemManager.bag/pack/stash/
quick_stack_size_for(pid)` (NEVER read pack_size etc. directly; `bag_size_for` = old alias of `pack_size_for`), `CatHealth.max_health_for`, `Upgrades.shop_allows` (crates; also refused in
request_buy), `zoomies/engine/gourmet/melee_multiplier`, `scrap_magnet_chance` (enemy.explode), `Mainframe.exit_heat`/`charge_per_scrap_for`.
NO upgrades in NPC chat any more (no upgrade_page / open_page): EVERYTHING is bought at the TINKER WORKBENCH = hub `_build_workbench`
(`models/workbench.glb`) -> `WorkbenchScreen` (`scripts/ui/workbench_screen.gd`, HUD `Frame/Workbench`, in `Hud.wants_input` + `cat._menu_open`;
7 portrait tabs = `Upgrades.WORKBENCH_TABS` [boss, shopkeeper, rebellion tiers 1-5] via `npc_for_tab` (hub.npc / hub.shopkeeper / child Npc
with that `rebellion_tier`), portraits `ui/icons/npcs/<scene file name>.png`, "?" = locked_mystery; CardFace = name, pips, BUY pill; ride buttons
on tab 6; `note()` gets `_buy_result`). SEWER REBELLION: crew upgrade `rebellion_tier` (5 tiers); `Upgrades.rebellion_level(team)` (best in gang,
tutorial = 5, test `rebellion_override`), `tab_unlocked`, `current_tier` (rebellion = gang's), host refuses locked tabs, `_recruited` RPC ->
`recruited` signal. `Npc.rebellion_tier` (export, set on the 10 recruit scenes) + `is_recruited()`/`present`: hidden, collision off, no E,
no breach fighting until recruited (checked every 0.25 s in `_process`, never in `_ready`: Game.players isn't ready yet). RIDES: `team_vehicle[team]`,
`request_select_vehicle` (car must be empty) -> `GetawayCar.set_vehicle(id)` swaps Model/CarModel (`cyber_bike.glb`/`fish_van.glb`), box, stats
(`bike_*`/`van_*` exports, `smash_speed_factor`); any `Trim*` part glows gang colour. Profile saves "upgrades" + "vehicle"; tutorial sends {}.
Models from `tools/make_upgrade_specs.py`. InventoryScreen grids resize per cat (`_match_sizes`; slots shrink to fit).
Test: `--buy_upgrade=a,b --select_vehicle=X --upgrade_log --vehicles_lineup`, `--workbench [--workbench_recruit=N --workbench_buy=a,b
--workbench_tab=N]` ("DevCapture workbench"), `--rebellion_tier=N` (`--talk=<recruit>` sets 5 by itself).
