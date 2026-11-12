# Sewer upgrades, workbench, rebellion, rides

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)


SEWER UPGRADES (SETUP_GUIDE §25): `scripts/upgrades.gd` (`Upgrades.instance`, node `Upgrades` under Main right below Wallet, GameSystems).
`player_upgrades` {player_id: {id: tier}} synced (`_set_tier`/`_set_all`), `costs` export (id -> [[cash, scrap] per tier]), `INFO`/`WORKBENCH_TABS`.
Host `request_buy(player_id, id)` = Wallet.spend + `ItemManager.spend_scrap` (bag first, then stash; `scrap_count_of`). Read with static
`Upgrades.level(pid, id)` / `best_in_team(team, id)` (CREW: mainframe_capacitor, turbo_engine, insider_tunnel, afterburner = car boost charges, tab 3). Hooks: `ItemManager.bag/pack/stash/
quick_stack_size_for(pid)` (NEVER read pack_size etc. directly; `bag_size_for` = old alias of `pack_size_for`), `CatHealth.max_health_for`, `Upgrades.shop_allows` (crates; also refused in
request_buy), `zoomies/engine/gourmet/melee_multiplier`, `scrap_magnet_chance` (enemy.explode), `Mainframe.exit_heat`/`charge_per_electronics_for`.
NO upgrades in NPC chat any more (no upgrade_page / open_page): EVERYTHING is bought at the TINKER WORKBENCH = hub `_build_workbench`
(`models/workbench.glb`) -> `WorkbenchScreen` (`scripts/ui/workbench_screen.gd`, HUD `Frame/Workbench`, in `Hud.wants_input` + `cat._menu_open`;
7 portrait tabs = `Upgrades.WORKBENCH_TABS` [boss, shopkeeper, rebellion tiers 1-5] via `npc_for_tab` (hub.npc / hub.shopkeeper / child Npc
with that `rebellion_tier`), portraits `ui/icons/npcs/<scene file name>.png`, "?" = locked_mystery; CardFace = name, pips, BUY pill; ride buttons
on tab 6; `note()` gets `_buy_result`). SEWER REBELLION: recruits picked in ANY order; each = upgrade `recruit_1..5` (max tier 1, price =
`costs.rebellion_tier[rebellion_level]`, `request_buy("rebellion_tier")` = lowest missing one; old saves migrate in `_merge_old_upgrades`);
`Upgrades.is_recruited(team, n)` (best in gang, tutorial = all, test `rebellion_override` = 1..N), `rebellion_level` = count,
`RECRUIT_TYPES`/`RECRUIT_SHORT` (what a locked "?" tab shows), `tab_unlocked`, host refuses locked tabs, `_recruited` RPC ->
`recruited(team, n)` signal. `Npc.rebellion_tier` (export = recruit number, set on the 10 recruit scenes) + `is_recruited()`/`present`: hidden, collision off, no E,
no breach fighting until recruited (checked every 0.25 s in `_process`, never in `_ready`: Game.players isn't ready yet). RIDES: `team_vehicle[team]`,
`request_select_vehicle` (car must be empty) -> `GetawayCar.set_vehicle(id)` swaps Model/CarModel (`cyber_bike.glb`/`fish_van.glb`), box, stats
(`bike_*`/`van_*` exports, `smash_speed_factor`); any `Trim*` part glows gang colour. Profile saves "upgrades" + "vehicle"; tutorial sends {}.
Models from `tools/make_upgrade_specs.py`. InventoryScreen grids resize per cat (`_match_sizes`; slots shrink to fit).
Test: `--buy_upgrade=a,b --select_vehicle=X --upgrade_log --vehicles_lineup`, `--workbench [--workbench_recruit=N --workbench_pick=5,3 --workbench_buy=a,b
--workbench_tab=N]` ("DevCapture workbench"), `--rebellion_tier=N` (`--talk=<recruit>` sets 5 by itself).
RECRUIT HOMES (`scripts/recruit_home.gd`, `RecruitHome`, Node3D children of a hub in main.tscn): each recruit's own furniture,
`npc` export -> hidden + collision off until `npc.is_recruited()` (polled 0.25 s, pop tween on join). Catleone only so far:
MittensHome/PaulieHome/SalHome/NonnaHome/FrankieHome, models from `tools/make_recruit_home_specs.py` (mittens_box,
paulie_scrapheap, sal_heavy_bag, nonna_kitchen, frankie_garage). Part names: Glow/Lamp/Burner lit, Sign soft, Trim gang colour,
Swing sways. `extra_model` (+offset/yaw/solid) = a 2nd model that hides/pops with it (Mittens: `box_shanty`;
the Catleone Hub's own `shanty_spots` export is empty, GangHub keeps 3). `show_ride` (Frankie) parks `Upgrades.vehicle_of(hub.team)` (RIDE_MODELS) and swaps it live; `prompt` set = an
Interactable that opens WorkbenchScreen on tab `rebellion_tier + 1`. Burrow recruits have no homes yet.
RECRUIT REVEAL (`scripts/recruit_reveal.gd`, `RecruitReveal`, one per hub, added in hub `_ready`): on `Upgrades.recruited` (every
computer) for its gang -> `Npc.pop_in(delay, tag_hidden)` (squash/elastic + `_pop_burst`: sparks parented to Game, OmniLight flash,
voice meow) + `RecruitHome.pop_delay`; local gang cats in that hub (`_shows_to`) get a camera shot via static `camera_for(cat)`
(first in game_screen `view_override_for`), `is_watching` freezes the cat (`_menu_open`), open workbenches close and reopen on the
recruit's tab after. Cats in the city only get a feed line. Test: `--reveal_test=N [--reveal_wait=F]` (menus.gd).
Tests can host on another port with `--port=N` (`Net.game_port()`) while the game is already open on this PC.
