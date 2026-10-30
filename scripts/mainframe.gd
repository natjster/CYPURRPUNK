class_name Mainframe
extends Node
## CYPURRPUNK — THE MAINFRAME: the rebellion's giant CRT computer down in the sewers, and how
## much power it has left. Attach to the "Mainframe" node in main.tscn. Reach it with
## Mainframe.instance. ONE shared charge for every player (both gangs' sewers have a terminal,
## but they feed the same pool).
##
## How it plays:
##   - The charge goes 0..100%, in 25% steps. A new game starts at starting_charge (75%), so
##     the first SCRAP you bring home already has room to top it up.
##   - Every time a district is SEALED (max heat, the DEEP CLEAN: Events.district_sealed) the
##     Mainframe loses drain_per_district (25%).
##   - SCRAP (res://items/scrap.tres) only drops from a destroyed MEGA VAC-COP. Bring it home
##     in your loot bag (it isn't cashed in at the exit: it stays in the bag), walk up to THE
##     MAINFRAME on the west wall of the sewer and press E: 1 scrap = +charge_per_scrap (25%).
##     At 100% it refuses your scrap - put spare scrap in your stash for later.
##   - The charge when a district STARTS sets how that district begins:
##       100%  OVERCLOCK ACTIVE   0 heat, and heat rises 20% slower (overclock_heat_multiplier)
##        75%  SYSTEM ONLINE      0 heat (normal)
##        50%  POWER LOW         15 heat (heat_at_50)
##        25%  WARNING           30 heat (heat_at_25: heat level 2)
##         0%  CRITICAL          50 heat (heat_at_0: heat level 3) + 1 MEGA VAC-COP already up
##                               top (roomba_patrol.gd), so you can hunt it for scrap.
##     (100% is also a 1-district buffer: the seal only takes it down to 75%, still normal.)
##   - Feeding scrap BEFORE anyone has gone up in the current district counts for this district
##     straight away (its starting heat and overclock are updated).
##
## Who reads it:
##   heat_meter.gd     starting_heat() at each district start, heat_multiplier() while heating
##   roomba_patrol.gd  boss_at_start() at each district start
##   hub.gd            the CRT prop on the west wall (text, screen tint, light) + the E prompt
##   hud_heat_bar.gd   the top-right bar becomes the Mainframe bar while you're in the sewers
##
## MULTIPLAYER: only the HOST changes the charge. It tells everyone with _set_charge (and a
## player who joins late with send_state_to). Feeding asks the host with request_feed.

## The one Mainframe (Mainframe.instance).
static var instance: Mainframe

## The item id of scrap (its card is res://items/scrap.tres).
const SCRAP_ID: String = "scrap"
const MAX_CHARGE: float = 100.0

## Fired on every computer when the charge (or overclock) changes, e.g. for the CRT prop.
signal charge_changed(charge: float)

@export_group("Charge")
## Charge (0..100) at the start of a NEW GAME.
@export_range(0.0, 100.0, 25.0) var starting_charge: float = 75.0
## Charge lost every time a district is sealed (the DEEP CLEAN).
@export var drain_per_district: float = 25.0
## Charge added by each scrap fed in.
@export var charge_per_scrap: float = 25.0

@export_group("Starting heat per tier")
## Heat (0..100) a district starts with when the Mainframe is at 50% (POWER LOW).
@export var heat_at_50: float = 15.0
## ...at 25% (WARNING). 30 = already heat level 2.
@export var heat_at_25: float = 30.0
## ...at 0% (CRITICAL). 50 = already heat level 3.
@export var heat_at_0: float = 50.0

@export_group("Overclock (100%)")
## While a district runs OVERCLOCKED, heat rises at this much of the normal speed
## (0.8 = 20% slower). Doesn't slow the "everyone's home, hurry up" rush at the end.
@export_range(0.1, 1.0, 0.05) var overclock_heat_multiplier: float = 0.8

## Tiers, from the top. tier() returns one of these.
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

## The charge right now, 0..100 (everyone has a copy; the host's is the real one).
var charge: float = 75.0
## True while the CURRENT district runs overclocked (it started at 100%).
var overclock_active: bool = false


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	charge = starting_charge
	add_to_group(GameSystems.GROUP)  # new districts / late joiners (game_systems.gd)
	Events.district_sealed.connect(_on_district_sealed)  # (scripts/events.gd)


# --- Questions anyone can ask ---

## Which tier the charge is in now (Tier.CRITICAL .. Tier.OVERCLOCK).
func tier() -> Tier:
	if charge >= 100.0:
		return Tier.OVERCLOCK
	if charge >= 75.0:
		return Tier.ONLINE
	if charge >= 50.0:
		return Tier.POWER_LOW
	if charge >= 25.0:
		return Tier.WARNING
	return Tier.CRITICAL


## "SYSTEM ONLINE" etc.
func tier_name() -> String:
	return TIER_NAMES[tier()]


## The tier's terminal colour.
func tier_color() -> Color:
	return TIER_COLORS[tier()]


## Heat a district should start with at the current charge.
func starting_heat() -> float:
	match tier():
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


## Should a MEGA VAC-COP already be up top when this district starts? (0% = CRITICAL)
func boss_at_start() -> bool:
	return tier() == Tier.CRITICAL


# --- Host: the rules ---

## Host: a new game or a new district (game_systems.gd). The charge carries over; only the
## overclock is decided again from it. (heat_meter.gd / roomba_patrol.gd ask starting_heat()
## and boss_at_start() in their own start_district.)
func start_district() -> void:
	_set_charge.rpc(charge, charge >= MAX_CHARGE)
	print("[Mainframe] District starts at %d%% (%s)" % [int(charge), tier_name()])


## The hatch was sealed (every computer hears it): the host drains the Mainframe.
func _on_district_sealed() -> void:
	if not multiplayer.is_server():
		return
	_set_charge.rpc(maxf(charge - drain_per_district, 0.0), overclock_active)
	print("[Mainframe] District sealed: drained to %d%%" % int(charge))


## A player pressed E at THE MAINFRAME (hub.gd). Host only: takes 1 scrap from their loot bag
## and adds charge_per_scrap. Refuses at 100% (keep it for later: the stash).
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
	if charge >= MAX_CHARGE:
		_feed_result.rpc_id(PlayerId.peer_of(player_id), player_id, false, "MAINFRAME FULL (100%). Stash your scrap for later.")
		return
	if not items.take_from_bag(player_id, SCRAP_ID):
		return
	var new_charge := minf(charge + charge_per_scrap, MAX_CHARGE)
	var overclock := overclock_active
	# Nobody has gone up yet this district? Then it counts for THIS district straight away.
	var counts_now := FishHeist.instance != null and FishHeist.instance.went_up.is_empty()
	if counts_now:
		overclock = new_charge >= MAX_CHARGE
	_set_charge.rpc(new_charge, overclock)
	if counts_now:
		HeatMeter.instance.restart_district_heat()  # (reads starting_heat() at the new charge)
		RoombaPatrol.instance.restart_heat_levels()  # level bosses follow the new starting heat
	print("[Mainframe] Player %d fed 1 scrap: %d%%%s" % [player_id, int(charge), " (counts for this district)" if counts_now else ""])
	var text := "MAINFRAME +%d%%  ->  %d%%  %s" % [int(charge_per_scrap), int(charge), tier_name()]
	if counts_now:
		text += "\nThis district starts with %d heat%s." % [int(starting_heat()), " - OVERCLOCKED" if overclock else ""]
	_feed_result.rpc_id(PlayerId.peer_of(player_id), player_id, true, text)


## Host -> everyone: the charge is now this (and is the current district overclocked?).
@rpc("authority", "call_local", "reliable")
func _set_charge(value: float, overclock: bool) -> void:
	charge = clampf(value, 0.0, MAX_CHARGE)
	overclock_active = overclock
	charge_changed.emit(charge)


## Host -> the feeder's computer: how it went (a message on their screen + a sound).
@rpc("authority", "call_local", "reliable")
func _feed_result(player_id: int, ok: bool, text: String) -> void:
	Sound.play("buy" if ok else "error")
	Hud.show_message(text, 4.0, PlayerId.slot_of(player_id))


## Host -> a computer that just joined.
func send_state_to(peer: int) -> void:
	_set_charge.rpc_id(peer, charge, overclock_active)
