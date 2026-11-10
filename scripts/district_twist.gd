class_name DistrictTwist
extends Node
## CYPURRPUNK — DISTRICT TWISTS: from the second district of a game on, each new district has a
## chance (Twist Chance, 60%) to roll a special rule for that one district. Attach to the "Twist"
## node in main.tscn (it must stay ABOVE City and Items in the scene tree).
##
## The four twists:
##   BLACKOUT     the power grid is down: street lamps are off, the night is darker, and the
##                VAC-COPs see 25% less far (Blackout Sight Multiplier).
##   BIN DAY      twice the trash bins, cones and boxes on the streets (Bin Day Prop Multiplier),
##                and the boss pays $10 a mess (Bin Day Cash Per Mess) when you extract.
##   CLEARANCE    Meow-Mart's sale: twice the fish outside its door plus a GOLDEN KOI right in
##                front of it, but the heat climbs 25% faster (Clearance Heat Multiplier).
##   HIGH ALERT   50% more patrol bots (High Alert Bot Multiplier), and any regular bot that
##                blows up has a 35% chance to drop SCRAP (High Alert Scrap Chance).
##
## How players find out: down in the sewers. The boss (Don / Pawnie) announces it when the new
## district is ready, and THE MAINFRAME's CRT shows an INTEL line under its charge. There is NO
## pop-up when you climb out up top. The RAID REPORT's header names the twist at the end.
##
## How it's picked: the HOST rolls it when a district starts (Game.new_district), from a random
## number generator seeded with the city's seed, so the same city number always rolls the same
## way. District 1 of a game and the TUTORIAL never get a twist. The same twist never comes two
## districts in a row (if another one is allowed). The host sends the twist along with the city
## seed (game.gd _receive_city_seed), so every computer builds the same twisted city.
##
## Other scripts just ask: DistrictTwist.is_blackout() / is_bin_day() / is_clearance() /
## is_high_alert(), or current_kind(). Every tuning knob below is in the Inspector (click Twist).
##
## Testing: --twist=blackout|bin_day|clearance|high_alert|none (scripts/dev_capture.gd) forces it
## for every district, the first one included.

## The kinds of district. (Keep the numbers: they're sent over the network.)
enum Kind { NONE = 0, BLACKOUT = 1, BIN_DAY = 2, CLEARANCE = 3, HIGH_ALERT = 4 }

## The one Twist node, so any script can ask about the twist (null at the very start).
static var instance: DistrictTwist
## Testing only (--twist=...): every district gets this kind. -1 = roll normally.
static var forced_kind: int = -1

@export_group("Rolling")
## Chance (0-1) that a district from the second one on gets a twist. 0 = never, 1 = always.
@export_range(0.0, 1.0) var twist_chance: float = 0.60
## Which twists can be rolled (untick one to take it out of the game).
@export var can_roll_blackout: bool = true
@export var can_roll_bin_day: bool = true
@export var can_roll_clearance: bool = true
@export var can_roll_high_alert: bool = true

@export_group("Blackout")
## How far the VAC-COPs can see in the dark (1 = as usual, 0.75 = a quarter less far).
@export_range(0.1, 1.0) var blackout_sight_multiplier: float = 0.75
## How bright the city's ambient (background) light is in a blackout (1 = as usual).
@export_range(0.0, 1.0) var blackout_ambient_multiplier: float = 0.55
## How bright the moonlight is in a blackout (1 = as usual).
@export_range(0.0, 1.0) var blackout_moonlight_multiplier: float = 0.5

@export_group("Bin Day")
## How many more trash bins, cones and boxes on the streets (2 = twice as many).
@export_range(1.0, 4.0) var bin_day_prop_multiplier: float = 2.0
## Cash the boss pays per mess you made when you extract (the CHAOS BONUS).
@export var bin_day_cash_per_mess: int = 10

@export_group("Meow-Mart Clearance")
## How many more fish outside Meow-Mart's door (2 = twice as many).
@export_range(1, 4) var clearance_fish_multiplier: int = 2
## The extra item placed right in front of Meow-Mart's door ("" = none).
@export var clearance_prize_item: String = "golden_koi"
## How much faster the heat climbs while cats are up top (1.25 = 25% faster).
@export_range(1.0, 3.0) var clearance_heat_multiplier: float = 1.25

@export_group("High Alert")
## How many patrol bots compared to usual (1.5 = half as many again).
@export_range(1.0, 3.0) var high_alert_bot_multiplier: float = 1.5
## Chance (0-1) that a regular (not boss) bot drops SCRAP when it blows up.
@export_range(0.0, 1.0) var high_alert_scrap_chance: float = 0.35

@export_group("What the boss says")
## The boss's news when a new district has no twist.
@export_multiline var news_none: String = "We're movin' to a new part of town. Hatch is ready when you are."
@export_multiline var news_blackout: String = "New district, kid. Power grid's blown up there - total BLACKOUT. Stick to the shadows, the bots can barely see!"
@export_multiline var news_bin_day: String = "New district! It's BIN DAY up top - streets are packed with trash cans. Wreck the place and I'll pay $10 a mess when you extract!"
@export_multiline var news_clearance: String = "New district! Meow-Mart's havin' a CLEARANCE SALE - double fish and a Golden Koi right out front, but the heat's gonna climb fast!"
@export_multiline var news_high_alert: String = "Watch your tail, kid - new district is on HIGH ALERT. Crawlin' with bots, but even the little ones are carryin' SCRAP!"
## What the boss says instead of the usual send-off when you pick SEND ME UP TOP in a twisted
## district (a quick reminder). Empty = the normal send-off line.
@export_multiline var send_off_blackout: String = "Go. It's pitch black up there - stay outta their lights."
@export_multiline var send_off_bin_day: String = "Go make a mess, kid. $10 a can, on extraction."
@export_multiline var send_off_clearance: String = "Go hit that sale. And watch the heat - it climbs fast today."
@export_multiline var send_off_high_alert: String = "Go. Bots everywhere - but bring me back their scrap."

@export_group("Mainframe CRT intel line")
@export var intel_none: String = "SECTOR: STANDARD PATROL"
@export var intel_blackout: String = "INTEL: GRID BLACKOUT (DARK STREETS)"
@export var intel_bin_day: String = "INTEL: MUNICIPAL BIN DAY (2X TRASH)"
@export var intel_clearance: String = "INTEL: MEOW-MART CLEARANCE (2X FISH)"
@export var intel_high_alert: String = "INTEL: OVERCLEAN HIGH ALERT (+SCRAP)"

## The twist of the district being played now (every computer).
var kind: int = Kind.NONE
## Which district of this game it is (1 = the first). Every computer (sent with the city seed).
var district_number: int = 1
## Random numbers for the scrap drops (host only; nothing else depends on them).
var _drop_rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	_drop_rng.randomize()


# --- Picking the twist (host) ---

## Host: pick the twist for district "number" built from "city_seed". Same seed (and the same
## twist last time) = the same answer. District 1 and the tutorial: none (unless a test forces one).
func roll(city_seed: int, number: int) -> int:
	if forced_kind >= 0:
		return forced_kind
	if Game.is_tutorial() or number <= 1:
		return Kind.NONE
	var rng := RandomNumberGenerator.new()
	rng.seed = city_seed ^ 0x77157
	if rng.randf() >= twist_chance:
		return Kind.NONE
	var allowed: Array[int] = []
	for each in [Kind.BLACKOUT, Kind.BIN_DAY, Kind.CLEARANCE, Kind.HIGH_ALERT]:
		if _can_roll(each):
			allowed.append(each)
	if allowed.is_empty():
		return Kind.NONE
	# Not the same twist twice in a row (kind = the district just played), unless it's the only one allowed.
	if allowed.size() > 1 and allowed.has(kind):
		allowed.erase(kind)
	return allowed[rng.randi_range(0, allowed.size() - 1)]


func _can_roll(each: int) -> bool:
	match each:
		Kind.BLACKOUT: return can_roll_blackout
		Kind.BIN_DAY: return can_roll_bin_day
		Kind.CLEARANCE: return can_roll_clearance
		Kind.HIGH_ALERT: return can_roll_high_alert
	return false


## Every computer, just BEFORE the city is built (game.gd): this district's twist and number.
func set_twist(new_kind: int, number: int) -> void:
	kind = new_kind
	district_number = number
	print("[Twist] District %d: %s" % [number, name_of(new_kind) if new_kind != Kind.NONE else "NONE"])


# --- Asking about the twist (anyone, any time) ---

static func current_kind() -> int:
	return instance.kind if instance != null else Kind.NONE


static func is_blackout() -> bool:
	return current_kind() == Kind.BLACKOUT


static func is_bin_day() -> bool:
	return current_kind() == Kind.BIN_DAY


static func is_clearance() -> bool:
	return current_kind() == Kind.CLEARANCE


static func is_high_alert() -> bool:
	return current_kind() == Kind.HIGH_ALERT


## The twist's name for screens: "BLACKOUT", "BIN DAY", "MEOW-MART CLEARANCE", "HIGH ALERT" ("" = none).
static func name_of(which: int) -> String:
	match which:
		Kind.BLACKOUT: return "BLACKOUT"
		Kind.BIN_DAY: return "BIN DAY"
		Kind.CLEARANCE: return "MEOW-MART CLEARANCE"
		Kind.HIGH_ALERT: return "HIGH ALERT"
	return ""


## The kind called "name" on the command line (blackout, bin_day, clearance, high_alert, none), or -1.
static func kind_from_text(text: String) -> int:
	match text.to_lower():
		"none": return Kind.NONE
		"blackout": return Kind.BLACKOUT
		"bin_day", "binday": return Kind.BIN_DAY
		"clearance": return Kind.CLEARANCE
		"high_alert", "highalert": return Kind.HIGH_ALERT
	return -1


## What the boss says when this district is ready (game.gd _district_news).
func news_line() -> String:
	match kind:
		Kind.BLACKOUT: return news_blackout
		Kind.BIN_DAY: return news_bin_day
		Kind.CLEARANCE: return news_clearance
		Kind.HIGH_ALERT: return news_high_alert
	return news_none


## The SEND ME UP TOP send-off: the twist's reminder, or "usual" in a normal district.
static func send_off_line(usual: String) -> String:
	if instance == null:
		return usual
	var line := ""
	match instance.kind:
		Kind.BLACKOUT: line = instance.send_off_blackout
		Kind.BIN_DAY: line = instance.send_off_bin_day
		Kind.CLEARANCE: line = instance.send_off_clearance
		Kind.HIGH_ALERT: line = instance.send_off_high_alert
	return line if line != "" else usual


## THE MAINFRAME CRT's intel line (hub.gd).
static func intel_line() -> String:
	if instance == null:
		return ""
	match instance.kind:
		Kind.BLACKOUT: return instance.intel_blackout
		Kind.BIN_DAY: return instance.intel_bin_day
		Kind.CLEARANCE: return instance.intel_clearance
		Kind.HIGH_ALERT: return instance.intel_high_alert
	return instance.intel_none


# --- The numbers other scripts multiply by (1 = no change) ---

## VAC-COP sight range (roomba.gd).
static func sight_multiplier() -> float:
	return instance.blackout_sight_multiplier if is_blackout() else 1.0


## Street props: bins, cones, boxes (city_generator.gd).
static func prop_multiplier() -> float:
	return instance.bin_day_prop_multiplier if is_bin_day() else 1.0


## Passive heat while cats are up top (heat_meter.gd).
static func heat_multiplier() -> float:
	return instance.clearance_heat_multiplier if is_clearance() else 1.0


## Patrol bots (roomba_patrol.gd).
static func bot_multiplier() -> float:
	return instance.high_alert_bot_multiplier if is_high_alert() else 1.0


## Host, when a regular bot blows up (enemy.gd): should it drop SCRAP?
static func roll_scrap_drop() -> bool:
	return is_high_alert() and instance._drop_rng.randf() < instance.high_alert_scrap_chance
