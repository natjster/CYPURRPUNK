class_name Mainframe
extends Node
## CYPURRPUNK — THE MAINFRAMES: each gang's giant CRT computer down in its sewer, and how much
## power it has left. Attach to the "Mainframe" node in main.tscn. Reach it with
## Mainframe.instance. This ONE node keeps a charge for EVERY gang (charges, by team number:
## Teams.CATLEONE in "Hub", Teams.BURROW in "GangHub").
##
## How it plays:
##   - A charge goes 0..100%, in 25% steps. A new game starts both gangs at starting_charge (75%),
##     so the first SCRAP you bring home already has room to top it up.
##   - Every time a district is SEALED (max heat, the DEEP CLEAN: Events.district_sealed) each
##     ACTIVE gang (at least 1 player in the game) loses drain_per_district (25%).
##   - SCRAP (res://items/scrap.tres) only drops from a destroyed MEGA VAC-COP. Bring it home
##     in your loot bag (it isn't cashed in at the exit: it stays in the bag), walk up to your
##     gang's MAINFRAME on the west wall of your sewer and press E. 1 scrap does one of these:
##       FEED  (under 100%)  your gang's Mainframe +charge_per_scrap (25%)
##       HACK  (your gang is at 100%, an active rival above 0%)  the RIVAL's Mainframe
##             -hack_per_scrap (25%), and everyone sees it in the HUD feed
##       FULL  (100%, nobody left to hack)  it refuses: keep your scrap in the stash.
##   - Each gang's OWN charge decides when ITS exit opens, live (exit_heat):
##       100% OVERCLOCK ACTIVE (cyan)   exit at 60 heat
##        75% SYSTEM ONLINE (green)     exit at 75 heat
##        50% POWER LOW (yellow)        exit at 82 heat
##        25% WARNING (orange)          exit at 90 heat
##         0% CRITICAL (flashing red)   exit at 95 heat
##   - The LOWEST active gang's charge decides how the shared city starts (starting_heat):
##       100%  0 heat, and heat rises 20% slower (overclock_heat_multiplier)
##        75%  0 heat (normal)
##        50%  15 heat (heat_at_50)
##        25%  30 heat (heat_at_25: heat level 2)
##         0%  50 heat (heat_at_0: heat level 3) + 1 MEGA VAC-COP already up top
##                                (roomba_patrol.gd), so you can hunt it for scrap.
##   - Anything that changes the lowest charge BEFORE anyone has gone up in the current district
##     (feeding, hacking, a gang's first player arriving) counts for this district straight away
##     (_refresh_district updates its starting heat and overclock).
##
## Who reads it:
##   heat_meter.gd     starting_heat() at each district start, heat_multiplier() while heating
##   fish_heist.gd     exit_heat(team): when each gang's exit opens
##   roomba_patrol.gd  boss_at_start() at each district start
##   hub.gd            each sewer's CRT prop (text, screen tint, light) + the E prompt
##   hud_heat_bar.gd   the top-right bar: your gang's Mainframe in the sewers, your exit tick up top
##
## MULTIPLAYER: only the HOST changes the charges. It tells everyone with _set_charges (and a
## player who joins late with send_state_to). Feeding and hacking ask the host with request_feed.

## The one Mainframe node (Mainframe.instance).
static var instance: Mainframe

## The item id of scrap (its card is res://items/scrap.tres).
const SCRAP_ID: String = "scrap"
const MAX_CHARGE: float = 100.0

## Fired on every computer when a charge (or overclock) changes.
signal charge_changed

@export_group("Charge")
## Each gang's charge (0..100) at the start of a NEW GAME.
@export_range(0.0, 100.0, 25.0) var starting_charge: float = 75.0
## Charge each active gang loses every time a district is sealed (the DEEP CLEAN).
@export var drain_per_district: float = 25.0
## Charge added by each scrap fed in.
@export var charge_per_scrap: float = 25.0
## Charge a rival loses for each scrap used to HACK them (only possible at 100%).
@export var hack_per_scrap: float = 25.0

@export_group("Exit opens at heat (your gang's charge)")
## Heat at which a gang's EXIT opens while its Mainframe is at 100% (OVERCLOCK).
@export var exit_at_100: float = 60.0
## ...at 75% (SYSTEM ONLINE).
@export var exit_at_75: float = 75.0
## ...at 50% (POWER LOW).
@export var exit_at_50: float = 82.0
## ...at 25% (WARNING).
@export var exit_at_25: float = 90.0
## ...at 0% (CRITICAL).
@export var exit_at_0: float = 95.0

@export_group("Starting heat per tier (lowest active gang)")
## Heat (0..100) a district starts with when the lowest active gang is at 50% (POWER LOW).
@export var heat_at_50: float = 15.0
## ...at 25% (WARNING). 30 = already heat level 2.
@export var heat_at_25: float = 30.0
## ...at 0% (CRITICAL). 50 = already heat level 3.
@export var heat_at_0: float = 50.0

@export_group("Overclock (100%)")
## While a district runs OVERCLOCKED (every active gang at 100%), heat rises at this much of the
## normal speed (0.8 = 20% slower). Doesn't slow the "everyone's home, hurry up" rush at the end.
@export_range(0.1, 1.0, 0.05) var overclock_heat_multiplier: float = 0.8

## Tiers, from the top. tier_of() returns one of these.
enum Tier { CRITICAL, WARNING, POWER_LOW, ONLINE, OVERCLOCK }
## What the sewer CRT says for each tier (by Tier number).
const TIER_NAMES: Array[String] = ["CRITICAL", "WARNING", "POWER LOW", "SYSTEM ONLINE", "OVERCLOCK ACTIVE"]
## Terminal colours for each tier (CRT screen, its light, the HUD bar).
const TIER_COLORS: Array[Color] = [
	Color(1.0, 0.12, 0.1),   # CRITICAL: red (flashes)
	Color(1.0, 0.5, 0.1),    # WARNING: orange
	Color(1.0, 0.85, 0.2),   # POWER LOW: yellow
	Color(0.2, 1.0, 0.45),   # SYSTEM ONLINE: terminal green
	Color(0.2, 0.9, 1.0),    # OVERCLOCK: cyan
]

## What 1 scrap would do at a gang's Mainframe right now (use_for).
enum ScrapUse { FEED, HACK, FULL }

## Each gang's charge right now, 0..100, by team number (everyone has a copy; the host's is real).
var charges: Array[float] = []
## True while the CURRENT district runs overclocked (every active gang started it at 100%).
var overclock_active: bool = false

## Host: a district is running, and the lowest charge it was started on (see _refresh_district).
var _district_running: bool = false
var _district_lowest: float = 0.0
var _refresh_timer: float = 0.0


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	for team in Teams.count():
		charges.append(starting_charge)
	add_to_group(GameSystems.GROUP)  # new districts / late joiners (game_systems.gd)
	Events.district_sealed.connect(_on_district_sealed)  # (scripts/events.gd)


# --- Questions anyone can ask ---

## This gang's charge, 0..100.
func charge_of(team: int) -> float:
	return charges[clampi(team, 0, charges.size() - 1)]


## Which tier a charge number is in (Tier.CRITICAL .. Tier.OVERCLOCK).
static func tier_of(charge: float) -> Tier:
	if charge >= 100.0:
		return Tier.OVERCLOCK
	if charge >= 75.0:
		return Tier.ONLINE
	if charge >= 50.0:
		return Tier.POWER_LOW
	if charge >= 25.0:
		return Tier.WARNING
	return Tier.CRITICAL


## This gang's tier.
func tier(team: int) -> Tier:
	return tier_of(charge_of(team))


## "SYSTEM ONLINE" etc.
func tier_name(team: int) -> String:
	return TIER_NAMES[tier(team)]


## This gang's terminal colour.
func tier_color(team: int) -> Color:
	return TIER_COLORS[tier(team)]


## The heat at which this gang's EXIT opens (fish_heist.gd, and the tick on the HUD heat bar).
func exit_heat(team: int) -> float:
	match tier(team):
		Tier.OVERCLOCK:
			return exit_at_100
		Tier.POWER_LOW:
			return exit_at_50
		Tier.WARNING:
			return exit_at_25
		Tier.CRITICAL:
			return exit_at_0
	return exit_at_75


## The gangs with at least 1 player in the game (nobody here yet = just the Catleone Family).
func active_gangs() -> Array[int]:
	var gangs: Array[int] = []
	if Game.instance != null:
		for player_id in Game.instance.player_ids():
			var team := Teams.team_of(player_id)
			if not team in gangs:
				gangs.append(team)
	if gangs.is_empty():
		gangs.append(Teams.CATLEONE)
	return gangs


## The lowest charge of any active gang: this sets how the shared city starts.
func lowest_charge() -> float:
	var lowest := MAX_CHARGE
	for team in active_gangs():
		lowest = minf(lowest, charge_of(team))
	return lowest


## The active rival gang a hack would hit (the fullest one above 0%), or -1 if there is none.
func hack_target(team: int) -> int:
	var target := -1
	for other in active_gangs():
		if other != team and charge_of(other) > 0.0 and (target < 0 or charge_of(other) > charge_of(target)):
			target = other
	return target


## What 1 scrap would do at this gang's Mainframe right now.
func use_for(team: int) -> ScrapUse:
	if charge_of(team) < MAX_CHARGE:
		return ScrapUse.FEED
	return ScrapUse.HACK if hack_target(team) >= 0 else ScrapUse.FULL


## Heat a district should start with right now.
func starting_heat() -> float:
	match tier_of(lowest_charge()):
		Tier.POWER_LOW:
			return heat_at_50
		Tier.WARNING:
			return heat_at_25
		Tier.CRITICAL:
			return heat_at_0
	return 0.0


## Heat-rise speed for the current district (heat_meter.gd multiplies by this).
func heat_multiplier() -> float:
	return overclock_heat_multiplier if overclock_active else 1.0


## Should a MEGA VAC-COP already be up top when this district starts? (lowest gang at 0%)
func boss_at_start() -> bool:
	return tier_of(lowest_charge()) == Tier.CRITICAL


# --- Host: the rules ---

## Host: a new game or a new district (game_systems.gd). The charges carry over; only the
## overclock is decided again from them. (heat_meter.gd / roomba_patrol.gd ask starting_heat()
## and boss_at_start() in their own start_district.)
func start_district() -> void:
	_district_running = true
	_district_lowest = lowest_charge()
	_set_charges.rpc(charges, _district_lowest >= MAX_CHARGE)
	print("[Mainframe] District starts: charges %s, lowest active %d%%" % [charges, int(_district_lowest)])


## Host: a gang can turn up after the district began (couch and online cats arrive a moment
## later), so keep checking until someone goes up.
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 1.0
		_refresh_district()


## Host: if nobody has gone up yet and the lowest active charge changed, this district starts over
## on the new number (its heat, its overclock, its 0% boss).
func _refresh_district() -> void:
	var heist := FishHeist.instance
	if not _district_running or heist == null or not heist.went_up.is_empty() or heist.sealed:
		return
	var lowest := lowest_charge()
	if lowest == _district_lowest:
		return
	_district_lowest = lowest
	_set_charges.rpc(charges, lowest >= MAX_CHARGE)
	HeatMeter.instance.restart_district_heat()  # (reads starting_heat() at the new charge)
	RoombaPatrol.instance.restart_heat_levels()  # level bosses follow the new starting heat
	print("[Mainframe] District restarts on lowest active %d%%: heat %d" % [int(lowest), int(starting_heat())])


## The hatch was sealed (every computer hears it): the host drains every active gang.
func _on_district_sealed() -> void:
	if not multiplayer.is_server():
		return
	var drained := charges.duplicate()
	for team in active_gangs():
		drained[team] = maxf(charge_of(team) - drain_per_district, 0.0)
	_set_charges.rpc(drained, overclock_active)
	print("[Mainframe] District sealed: drained to %s" % [charges])


## A player pressed E at their gang's MAINFRAME (hub.gd). Host only: takes 1 scrap from their loot
## bag, then feeds their gang or hacks the rival (use_for). Refuses when there's nothing to do.
@rpc("any_peer", "call_local", "reliable")
func request_feed(player_id: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var cat := Game.instance.cat_for(player_id)
	if cat == null or not UndergroundHub.of(cat).near_mainframe(cat):
		return
	var items := ItemManager.instance
	if items.count_in_bag(player_id, SCRAP_ID) <= 0:
		_feed_result.rpc_id(PlayerId.peer_of(player_id), player_id, false, "No SCRAP in your loot bag. Smash a MEGA VAC-COP for some.")
		return
	var team := cat.team
	var use := use_for(team)
	if use == ScrapUse.FULL:
		_feed_result.rpc_id(PlayerId.peer_of(player_id), player_id, false, "MAINFRAME FULL (100%). Stash your scrap for later.")
		return
	if not items.take_from_bag(player_id, SCRAP_ID):
		return
	var changed := charges.duplicate()
	var target := team if use == ScrapUse.FEED else hack_target(team)
	if use == ScrapUse.FEED:
		changed[team] = minf(charge_of(team) + charge_per_scrap, MAX_CHARGE)
	else:
		changed[target] = maxf(charge_of(target) - hack_per_scrap, 0.0)
	_set_charges.rpc(changed, overclock_active)
	_refresh_district()  # nobody up yet? Then it counts for THIS district straight away
	print("[Mainframe] Player %d used 1 scrap on gang %d: %s" % [player_id, target, charges])
	var text := ""
	if use == ScrapUse.HACK:
		_hacked.rpc(team, target)
		text = "HACKED! %s MAINFRAME -%d%%  ->  %d%%" % [Teams.SHORT_NAMES[target], int(hack_per_scrap), int(charge_of(target))]
	else:
		text = "MAINFRAME +%d%%  ->  %d%%  %s\nYour exit opens at %d heat." % [int(charge_per_scrap), int(charge_of(team)), tier_name(team), int(exit_heat(team))]
	if FishHeist.instance != null and FishHeist.instance.went_up.is_empty():
		text += "\nThis district starts with %d heat%s." % [int(starting_heat()), " - OVERCLOCKED" if overclock_active else ""]
	_feed_result.rpc_id(PlayerId.peer_of(player_id), player_id, true, text)


## Host -> everyone: every gang's charge (by team number), and is the current district overclocked?
@rpc("authority", "call_local", "reliable")
func _set_charges(values: Array, overclock: bool) -> void:
	for team in mini(values.size(), charges.size()):
		charges[team] = clampf(values[team], 0.0, MAX_CHARGE)
	overclock_active = overclock
	charge_changed.emit()


## Host -> the feeder's computer: how it went (a message on their screen + a sound).
@rpc("authority", "call_local", "reliable")
func _feed_result(player_id: int, ok: bool, text: String) -> void:
	Sound.play("buy" if ok else "error")
	Hud.show_message(text, 4.0, PlayerId.slot_of(player_id))


## Host -> everyone: a gang hacked a rival. A line in the HUD feed, in the hacker's colour.
@rpc("authority", "call_local", "reliable")
func _hacked(team: int, target: int) -> void:
	Hud.feed("%s HACKED THE %s MAINFRAME (-%d%%)" % [Teams.name_of(team), Teams.SHORT_NAMES[target], int(hack_per_scrap)], Teams.color_of(team))


## Host -> a computer that just joined.
func send_state_to(peer: int) -> void:
	_set_charges.rpc_id(peer, charges, overclock_active)
