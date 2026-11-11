class_name Upgrades
extends Node
## CYPURRPUNK — SEWER UPGRADES: things you buy from the cats in the sewers (and the TINKER
## WORKBENCH) with CASH + SCRAP, that stay with your cat forever (saved in your profile).
## Attach to the "Upgrades" node in main.tscn (right under Wallet). Reach it with Upgrades.instance.
##
## WHERE THEY'RE BOUGHT: ONLY at the TINKER WORKBENCH on the east wall of each sewer (hub.gd
## _build_workbench -> scripts/ui/workbench_screen.gd). NPCs just talk and hand out quests now.
## The workbench has 7 tabs, one per sewer NPC (WORKBENCH_TABS below):
##   tab 0  Don Catleone / Pawnie (always)        BIGGER BACKPACK, MAINFRAME CAPACITOR
##   tab 1  Comrade Whiskers / Clawd (always)     WEAPON CRATES, DELUXE LITTERBOX
##   tab 2  REBELLION TIER 1: Lil' Mittens / Billy the Kitten        STUFFED CHEEKS, INSIDER TUNNEL
##   tab 3  REBELLION TIER 2: Paulie No-Brooms / Bumper-Car Benny    THICK FUR, SCRAP MAGNET, AFTERBURNER
##   tab 4  REBELLION TIER 3: Sal the Slapper / Calamity Clara       HEAVY PAWS
##   tab 5  REBELLION TIER 4: Nonna Catleone / Gold-Tooth Gus        GOURMET FENCE
##   tab 6  REBELLION TIER 5: Frankie Espresso / Jittery Jax         ESPRESSO BLOODSTREAM, TWIN-TURBO
##                            ENGINE, NEON ZOOM-BIKE, ARMORED MEOW-VAN (+ choosing your gang's ride)
##
## THE SEWER REBELLION: each sewer starts with only its boss and its shopkeeper. The other five cats
## are RECRUITED, one tier at a time, with the "rebellion_tier" upgrade (5 tiers, cash + scrap, bought
## on the next locked "?" tab). A recruit appears in the sewer (npc.gd rebellion_tier), offers their
## quest, fights in a SEWER BREACH, and opens their workbench tab. It's a CREW thing: a sewer shows
## everyone up to the best tier anyone in that gang has recruited (rebellion_level), and buying
## the next tier continues from there. Saved in your profile like every upgrade.
##
## PERSONAL vs CREW: most upgrades only help the cat who bought them. Four are CREW upgrades
## (MAINFRAME CAPACITOR, TWIN-TURBO ENGINE, INSIDER TUNNEL, AFTERBURNER): your whole gang gets the BEST tier
## anybody in it owns (best_in_team). So in co-op one rich cat upgrades everyone's car.
##
## How buying works (the HOST is the referee, as always):
##   1. You click an upgrade button: request_buy goes to the host.
##   2. The host checks your cash (Wallet) and your SCRAP (backpack + litterbox, ItemManager.scrap_count_of),
##      takes both, raises your tier and tells every computer (_set_tier).
##   3. Your computer saves it (player_profile.gd) and redraws the page.
##
## Where the upgrades are USED (each just asks Upgrades.level / best_in_team):
##   item_manager.gd  pack_size_for / stash_size_for / quick_stack_size_for, sell_price (gourmet)
##   shopkeeper.gd    shop_allows (weapon crates)       cat_player.gd   zoomies_multiplier
##   getaway_car.gd   engine_multiplier, set_vehicle   cat_health.gd   max_health_for
##   car/car_boost.gd "afterburner" tier = boost charges
##   enemy.gd         scrap_magnet_chance
##   melee_weapon.gd  melee_multiplier                 mainframe.gd    charge_per_scrap_for, exit_heat
##
## Prices: select the Upgrades node in main.tscn > Inspector > Costs. Each upgrade has one
## [cash, scrap] pair per tier, e.g. "thick_fur": [[150, 1], [350, 2]] = tier 1 costs $150 +
## 1 scrap, tier 2 $350 + 2 scrap. The number of pairs IS the number of tiers.
## Tutorial runs start with no upgrades at all (player_profile.gd), so they're always the same.

## Emitted on EVERY computer when anyone's upgrades or a gang's vehicle change.
signal changed
## Emitted on EVERY computer when a gang recruits a new REBELLION tier (1-5).
signal recruited(team: int, tier: int)

## The one upgrades node (Upgrades.instance).
static var instance: Upgrades

## Each upgrade's price per tier: id -> [[cash, scrap], ...] (see the top of this file).
@export var costs: Dictionary = {
	"rebellion_tier": [[100, 1], [150, 1], [200, 2], [250, 2], [320, 3]],
	"shop_crates": [[100, 1], [200, 2], [320, 3]],
	"bigger_pack": [[80, 1], [160, 2], [260, 3]],
	"deluxe_litterbox": [[100, 1], [200, 2]],
	"mainframe_capacitor": [[130, 1], [260, 2]],
	"espresso_zoomies": [[100, 1], [200, 2]],
	"turbo_engine": [[100, 1], [200, 2]],
	"afterburner": [[120, 1], [240, 2]],
	"unlock_cyber_bike": [[160, 2]],
	"unlock_fish_van": [[230, 2]],
	"thick_fur": [[100, 1], [200, 2]],
	"scrap_magnet": [[130, 1], [260, 2]],
	"gourmet_fence": [[100, 1], [200, 2]],
	"stuffed_cheeks": [[80, 1], [160, 1]],
	"heavy_paws": [[80, 1], [160, 2]],
	"insider_tunnel": [[130, 1], [260, 2]],
}

@export_group("Weapon crates (Comrade Whiskers / Clawd)")
## Always for sale, even with no crates (the tutorial and brand-new cats need these).
@export var starter_stock: PackedStringArray = ["neon_bat", "catnip", "catdip", "pistol"]
## Tier 1 STREET SMUGGLER CRATE adds these to the shop...
@export var crate_1_items: PackedStringArray = ["hairball_blaster", "red_dot"]
## ...tier 2 MOB SYNDICATE CRATE these...
@export var crate_2_items: PackedStringArray = ["tommy_gun", "frozen_tuna"]
## ...and tier 3 EXPERIMENTAL CRATE these. (An item in none of the lists is always for sale.)
@export var crate_3_items: PackedStringArray = ["yarn_zooka", "cucumber_launcher"]

@export_group("What each tier gives")
## Backpack slots per BIGGER BACKPACK tier (6 -> 8 -> 10 -> 12).
@export var pack_slots_per_tier: int = 2
## Litterbox slots per DELUXE LITTERBOX tier (9 -> 15 -> 21).
@export var stash_slots_per_tier: int = 6
## Max HP per THICK FUR tier (100 -> 125 -> 150).
@export var hp_per_tier: int = 25
## Walk + zoomies speed per ESPRESSO BLOODSTREAM tier (0.12 = +12%).
@export var zoomies_per_tier: float = 0.12
## Vehicle top speed + acceleration per TWIN-TURBO ENGINE tier (0.15 = +15%).
@export var engine_per_tier: float = 0.15
## Chance per SCRAP MAGNET tier that a smashed (non-boss) bot drops a SCRAP (0.15 = 15%).
@export var scrap_magnet_per_tier: float = 0.15
## Extra cash for loot sold at the shop per GOURMET FENCE tier (0.2 = +20%).
@export var gourmet_per_tier: float = 0.2
## Extra melee damage + knockback per HEAVY PAWS tier (0.25 = +25%).
@export var heavy_paws_per_tier: float = 0.25
## Heat the exit opens earlier per INSIDER TUNNEL tier.
@export var insider_heat_per_tier: float = 5.0
## Mainframe charge for 1 scrap at MAINFRAME CAPACITOR tier 0, 1, 2.
@export var capacitor_charge: Array[float] = [25.0, 35.0, 50.0]

## Names, what they do, and which page sells them. ("crew" = shared by the whole gang.)
const INFO := {
	"rebellion_tier": {"name": "REBELLION RECRUIT", "crew": true, "about": "Recruit the next cat to your sewer: they move in, hand out a quest, fight in breaches and open their workbench tab."},
	"shop_crates": {"name": "WEAPON CRATES", "tiers": ["STREET SMUGGLER CRATE", "MOB SYNDICATE CRATE", "EXPERIMENTAL CRATE"],
		"about": "Unlocks better guns in the shop: 1 = HAIRBALL BLASTER + RED DOT, 2 = TOMMY GUN + FROZEN TUNA, 3 = YARN-ZOOKA + CUCUMBER LAUNCHER."},
	"bigger_pack": {"name": "BIGGER BACKPACK", "about": "Backpack (loot + gear) 6 -> 8 -> 10 -> 12 slots."},
	"deluxe_litterbox": {"name": "DELUXE LITTERBOX", "about": "Litterbox 9 -> 15 -> 21 slots."},
	"mainframe_capacitor": {"name": "MAINFRAME CAPACITOR", "crew": true, "about": "1 scrap charges the Mainframe +35% / +50% (not +25%)."},
	"espresso_zoomies": {"name": "ESPRESSO BLOODSTREAM", "about": "You walk and zoom +12% / +24% faster."},
	"turbo_engine": {"name": "TWIN-TURBO ENGINE", "crew": true, "about": "Your gang's ride: +15% / +30% top speed and pickup."},
	"unlock_cyber_bike": {"name": "NEON ZOOM-BIKE", "about": "Fast, twitchy, 1 passenger."},
	"unlock_fish_van": {"name": "ARMORED MEOW-VAN", "about": "Heavy, smashes bots slower, 3 passengers."},
	"thick_fur": {"name": "THICK FUR", "about": "Max HP 100 -> 125 -> 150."},
	"scrap_magnet": {"name": "SCRAP MAGNET", "about": "Bots you smash: 15% / 30% chance to drop a SCRAP."},
	"gourmet_fence": {"name": "GOURMET FENCE", "about": "The shop pays +20% / +40% for fish, sardines and koi."},
	"stuffed_cheeks": {"name": "STUFFED CHEEKS", "about": "Quick-use snack stacks 3 -> 4 -> 5."},
	"heavy_paws": {"name": "HEAVY PAWS", "about": "Melee hits +25% / +50% damage and knockback."},
	"insider_tunnel": {"name": "INSIDER TUNNEL", "crew": true, "about": "Your gang's exit opens 5 / 10 heat earlier."},
	"afterburner": {"name": "AFTERBURNER", "crew": true, "about": "BOOST your ride (Shift / pad A): fire out the exhaust sends bots and cats flying! 1 / 2 charges, slowly recharging."},
}

## The TINKER WORKBENCH's 7 tabs (scripts/ui/workbench_screen.gd): which upgrades each sewer NPC's tab
## sells. Tab 0 = the boss, tab 1 = the shopkeeper (always open), tabs 2-6 = REBELLION TIERS 1-5 (open
## once that tier is recruited).
const WORKBENCH_TABS := [
	["bigger_pack", "mainframe_capacitor"],
	["shop_crates", "deluxe_litterbox"],
	["stuffed_cheeks", "insider_tunnel"],
	["thick_fur", "scrap_magnet", "afterburner"],
	["heavy_paws"],
	["gourmet_fence"],
	["espresso_zoomies", "turbo_engine", "unlock_cyber_bike", "unlock_fish_van"],
]
## A short job title for each tab's cat (shown under their name on the workbench).
const TAB_ROLES := ["THE BOSS", "THE BLACK MARKITTEN", "STREET RUNNER", "THE MUSCLE", "ENFORCER", "THE KITCHEN & THE FENCE", "WHEELCAT"]
const REBELLION_TIERS := 5

## TESTS ONLY (DevCapture --rebellion_tier=N, or --talk on a recruit): pretend every sewer has
## recruited this many tiers. -1 = off (the real rule).
static var rebellion_override: int = -1


## The rides a gang can drive (getaway_car.gd VEHICLES has their models and stats).
## id -> the upgrade that unlocks it ("" = everyone has it).
const VEHICLE_UNLOCKS := {"interceptor": "", "cyber_bike": "unlock_cyber_bike", "fish_van": "unlock_fish_van"}
const VEHICLE_NAMES := {"interceptor": "INTERCEPTOR", "cyber_bike": "ZOOM-BIKE", "fish_van": "MEOW-VAN"}

## Player ID -> {upgrade id: tier}. Every computer has a copy; only the host changes it.
var player_upgrades := {}
## Each gang's ride (by team number): "interceptor" / "cyber_bike" / "fish_van".
var team_vehicle: Array = ["interceptor", "interceptor"]
## Player ID -> the ride they last picked (saved in their profile, picked again next game).
var chosen_vehicle := {}



func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	add_to_group(GameSystems.GROUP)  # late joiners and quitting players (game_systems.gd)


# --- Questions anyone can ask (every computer has the answers) ---

## A player's tier in one upgrade (0 = not bought). Safe to call before the node exists.
static func level(player_id: int, upgrade_id: String) -> int:
	if instance == null:
		return 0
	return int(instance.player_upgrades.get(player_id, {}).get(upgrade_id, 0))


## The best tier anyone in this gang owns (CREW upgrades: car engine, capacitor, insider tunnel).
static func best_in_team(team: int, upgrade_id: String) -> int:
	if instance == null or Game.instance == null:
		return 0
	var best := 0
	for player_id in Game.instance.player_ids():
		if Teams.team_of(player_id) == team:
			best = maxi(best, level(player_id, upgrade_id))
	return best


## How many tiers this upgrade has (= how many prices it has).
func max_tier(upgrade_id: String) -> int:
	return (costs.get(upgrade_id, []) as Array).size()


## [cash, scrap] for the NEXT tier this player would buy ([0, 0] when maxed).
func next_cost(player_id: int, upgrade_id: String) -> Array:
	var tier := current_tier(player_id, upgrade_id)
	var list: Array = costs.get(upgrade_id, [])
	return list[tier] if tier < list.size() else [0, 0]


## May this player buy this item at the shop yet? (WEAPON CRATES)
static func shop_allows(player_id: int, item_id: String) -> bool:
	if instance == null or item_id in instance.starter_stock:
		return true
	var crates := level(player_id, "shop_crates")
	if item_id in instance.crate_1_items:
		return crates >= 1
	if item_id in instance.crate_2_items:
		return crates >= 2
	if item_id in instance.crate_3_items:
		return crates >= 3
	return true  # not in any crate: always sold


## Which crate (1-3) unlocks this item, 0 = none needed.
static func crate_for(item_id: String) -> int:
	if instance == null:
		return 0
	for tier in 3:
		if item_id in [instance.crate_1_items, instance.crate_2_items, instance.crate_3_items][tier]:
			return tier + 1
	return 0


## The numbers the game systems use:
static func zoomies_multiplier(player_id: int) -> float:
	return 1.0 + (instance.zoomies_per_tier * level(player_id, "espresso_zoomies") if instance != null else 0.0)


static func engine_multiplier(team: int) -> float:
	return 1.0 + (instance.engine_per_tier * best_in_team(team, "turbo_engine") if instance != null else 0.0)


static func scrap_magnet_chance(player_id: int) -> float:
	return instance.scrap_magnet_per_tier * level(player_id, "scrap_magnet") if instance != null else 0.0


static func gourmet_multiplier(player_id: int) -> float:
	return 1.0 + (instance.gourmet_per_tier * level(player_id, "gourmet_fence") if instance != null else 0.0)


static func melee_multiplier(player_id: int) -> float:
	return 1.0 + (instance.heavy_paws_per_tier * level(player_id, "heavy_paws") if instance != null else 0.0)


static func extra_hp(player_id: int) -> int:
	return instance.hp_per_tier * level(player_id, "thick_fur") if instance != null else 0


static func exit_heat_discount(team: int) -> float:
	return instance.insider_heat_per_tier * best_in_team(team, "insider_tunnel") if instance != null else 0.0


static func charge_per_scrap_for(team: int, base: float) -> float:
	if instance == null or instance.capacitor_charge.is_empty():
		return base
	var tier := best_in_team(team, "mainframe_capacitor")
	if tier == 0:
		return base
	return instance.capacitor_charge[mini(tier, instance.capacitor_charge.size() - 1)]


## Has this player unlocked this ride? (the INTERCEPTOR is everyone's)
## THE SEWER REBELLION: how many tiers this gang's sewer has recruited (0-5): the best anyone in the
## gang has bought. The TUTORIAL always has everyone (its steps need Lil' Mittens).
static func rebellion_level(team: int) -> int:
	if rebellion_override >= 0:
		return rebellion_override
	if Game.is_tutorial():
		return REBELLION_TIERS
	return best_in_team(team, "rebellion_tier")


## Is workbench tab "tab" open for this gang? (0 boss and 1 shopkeeper always; 2..6 = tier 1..5.)
static func tab_unlocked(team: int, tab: int) -> bool:
	return tab < 2 or rebellion_level(team) >= tab - 1


## Which workbench tab sells this upgrade (-1 = none: rebellion_tier itself).
static func tab_of(upgrade_id: String) -> int:
	for tab in WORKBENCH_TABS.size():
		if upgrade_id in WORKBENCH_TABS[tab]:
			return tab
	return -1


## The tier a purchase continues from: your own for normal upgrades; for REBELLION RECRUIT the
## gang's (it's shared: a friend's recruits count, and you buy the NEXT one).
func current_tier(player_id: int, upgrade_id: String) -> int:
	if upgrade_id == "rebellion_tier":
		return best_in_team(Teams.team_of(player_id), upgrade_id)
	return level(player_id, upgrade_id)


func has_vehicle(player_id: int, vehicle: String) -> bool:
	if not VEHICLE_UNLOCKS.has(vehicle):
		return false
	var needs: String = VEHICLE_UNLOCKS[vehicle]
	return needs == "" or level(player_id, needs) > 0


## This gang's ride right now.
func vehicle_of(team: int) -> String:
	return team_vehicle[clampi(team, 0, team_vehicle.size() - 1)]


# --- Buying (the host decides) ---

## A player clicked an upgrade button. Host only: check, charge cash + scrap, raise the tier.
@rpc("any_peer", "call_local", "reliable")
func request_buy(player_id: int, upgrade_id: String) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var cat := Game.instance.cat_for(player_id)
	if cat == null or not costs.has(upgrade_id):
		return
	var peer := PlayerId.peer_of(player_id)
	var title: String = INFO.get(upgrade_id, {}).get("name", upgrade_id)
	if not UndergroundHub.is_in_hub(cat.global_position):
		_buy_result.rpc_id(peer, player_id, false, "Upgrades are bought down in the sewers.")
		return
	if not tab_unlocked(Teams.team_of(player_id), tab_of(upgrade_id)):
		_buy_result.rpc_id(peer, player_id, false, "Recruit that cat to the Rebellion first.")
		return
	var tier := current_tier(player_id, upgrade_id)
	if tier >= max_tier(upgrade_id):
		_buy_result.rpc_id(peer, player_id, false, "%s is already maxed out." % title)
		return
	var price: Array = next_cost(player_id, upgrade_id)
	var cash_cost := int(price[0])
	var scrap_cost := int(price[1])
	var items := ItemManager.instance
	if Wallet.instance.cash_of(player_id) < cash_cost:
		_buy_result.rpc_id(peer, player_id, false, "%s costs $%d. You've got $%d." % [title, cash_cost, Wallet.instance.cash_of(player_id)])
		return
	if items.scrap_count_of(player_id) < scrap_cost:
		_buy_result.rpc_id(peer, player_id, false, "%s needs %d SCRAP. You've got %d (backpack + litterbox)." % [title, scrap_cost, items.scrap_count_of(player_id)])
		return
	if not Wallet.instance.spend(player_id, cash_cost) or not items.spend_scrap(player_id, scrap_cost):
		return
	_set_tier.rpc(player_id, upgrade_id, tier + 1)
	print("[Upgrades] Player %d bought %s tier %d for $%d + %d scrap" % [player_id, upgrade_id, tier + 1, cash_cost, scrap_cost])
	if upgrade_id == "rebellion_tier":
		_recruited.rpc(Teams.team_of(player_id), tier + 1)
	_buy_result.rpc_id(peer, player_id, true, "%s  TIER %d/%d!" % [title, tier + 1, max_tier(upgrade_id)])


## Host -> everyone: a gang recruited REBELLION TIER "tier" (the new cat walks into their sewer: npc.gd
## notices by itself; the workbench screen celebrates).
@rpc("authority", "call_local", "reliable")
func _recruited(team: int, tier: int) -> void:
	recruited.emit(team, tier)
	print("[Upgrades] Gang %d recruited REBELLION TIER %d" % [team, tier])


## Host -> the buyer: how it went. Plays the sound, says it, redraws the open page.
@rpc("authority", "call_local", "reliable")
func _buy_result(player_id: int, ok: bool, text: String) -> void:
	print("[Upgrades] %s" % text)
	Sound.play("buy" if ok else "error")
	var seat := PlayerId.slot_of(player_id)
	var bench := WorkbenchScreen.for_seat(seat)
	if bench != null and bench.visible:
		bench.note(("UPGRADED! " if ok else "") + text, ok)  # the workbench's own message line
	else:
		Hud.show_message(("UPGRADED! " if ok else "") + text, 3.0, seat)


## Host -> everyone: this player's tier in this upgrade.
@rpc("authority", "call_local", "reliable")
func _set_tier(player_id: int, upgrade_id: String, tier: int) -> void:
	var mine: Dictionary = player_upgrades.get(player_id, {}).duplicate()
	mine[upgrade_id] = tier
	player_upgrades[player_id] = mine
	changed.emit()


## Host -> everyone: all of one player's upgrades at once (their save came in).
@rpc("authority", "call_local", "reliable")
func _set_all(player_id: int, upgrades: Dictionary) -> void:
	player_upgrades[player_id] = upgrades
	changed.emit()


# --- The save file (player_profile.gd) ---

## Host: a player's saved upgrades + ride arrived. Keep only real upgrades, tiers in range.
func restore(player_id: int, upgrades: Dictionary, vehicle: String) -> void:
	if not multiplayer.is_server():
		return
	upgrades = _merge_old_upgrades(upgrades)
	var clean := {}
	for upgrade_id in upgrades:
		if upgrade_id is String and costs.has(upgrade_id):
			var tier := clampi(int(upgrades[upgrade_id]), 0, max_tier(upgrade_id))
			if tier > 0:
				clean[upgrade_id] = tier
	_set_all.rpc(player_id, clean)
	print("[Upgrades] Player %d came back with upgrades %s, ride %s" % [player_id, clean, vehicle])
	# Their favourite ride: used if they still own it and their gang hasn't picked another one yet.
	if VEHICLE_UNLOCKS.has(vehicle) and has_vehicle(player_id, vehicle):
		_set_choice.rpc(player_id, vehicle)
		if vehicle_of(Teams.team_of(player_id)) == "interceptor":
			_set_team_vehicle.rpc(Teams.team_of(player_id), vehicle)


## Old saves: DEEP POCKETS (the loot bag's own upgrade, before loot moved into the one backpack)
## turns into BIGGER BACKPACK tiers, so nobody loses what they paid for. (A copy: the save's own
## dictionary isn't changed; the profile saves the merged one next time.)
static func _merge_old_upgrades(upgrades: Dictionary) -> Dictionary:
	if not upgrades.has("deep_pockets"):
		return upgrades
	var merged := upgrades.duplicate()
	var pockets := int(merged.get("deep_pockets", 0))
	merged.erase("deep_pockets")
	merged["bigger_pack"] = int(merged.get("bigger_pack", 0)) + pockets  # (restore clamps it to the top tier)
	return merged


# --- Choosing your gang's ride (Frankie / Jittery Jax) ---

@rpc("any_peer", "call_local", "reliable")
func request_select_vehicle(player_id: int, vehicle: String) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var peer := PlayerId.peer_of(player_id)
	if not has_vehicle(player_id, vehicle):
		_buy_result.rpc_id(peer, player_id, false, "Unlock the %s first." % VEHICLE_NAMES.get(vehicle, vehicle))
		return
	var team := Teams.team_of(player_id)
	for car in Game.instance.cars():
		if maxi(0, car.team) == team and (car.driver_id != 0 or not car.passenger_ids.is_empty()):
			_buy_result.rpc_id(peer, player_id, false, "Somebody's out driving it right now. Wait till it's parked.")
			return
	_set_choice.rpc(player_id, vehicle)
	_set_team_vehicle.rpc(team, vehicle)
	_buy_result.rpc_id(peer, player_id, true, "Your gang now rides the %s." % VEHICLE_NAMES.get(vehicle, vehicle))


@rpc("authority", "call_local", "reliable")
func _set_choice(player_id: int, vehicle: String) -> void:
	chosen_vehicle[player_id] = vehicle
	changed.emit()


## Host -> everyone: this gang's car becomes that ride (getaway_car.gd swaps model + stats).
@rpc("authority", "call_local", "reliable")
func _set_team_vehicle(team: int, vehicle: String) -> void:
	if team < 0 or team >= team_vehicle.size() or not VEHICLE_UNLOCKS.has(vehicle):
		return
	team_vehicle[team] = vehicle
	if Game.instance != null:
		for car in Game.instance.cars():
			if maxi(0, car.team) == team:
				car.set_vehicle(vehicle)
	changed.emit()


# --- Game systems (scripts/game_systems.gd) ---

func send_state_to(peer: int) -> void:
	_receive_state.rpc_id(peer, player_upgrades, team_vehicle, chosen_vehicle)


@rpc("authority", "call_remote", "reliable")
func _receive_state(upgrades_now: Dictionary, vehicles_now: Array, chosen_now: Dictionary) -> void:
	player_upgrades = upgrades_now
	chosen_vehicle = chosen_now
	for team in vehicles_now.size():
		_set_team_vehicle(team, vehicles_now[team])


## Host: a player quit. Their upgrades are safe in their own save file.
func player_left(player_id: int, _last_position: Vector3) -> void:
	_forget.rpc(player_id)


@rpc("authority", "call_local", "reliable")
func _forget(player_id: int) -> void:
	player_upgrades.erase(player_id)
	chosen_vehicle.erase(player_id)
	changed.emit()
