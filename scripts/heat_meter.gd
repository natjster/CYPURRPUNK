class_name HeatMeter
extends Node
## HEAT — how angry the city is, and the CLOCK of each district. The longer cats stay up top (and
## the more trouble they cause), the hotter it gets, and the harder the VAC-COPs come for you.
## Attach to the "Heat" node in main.tscn. One meter, shared by every player.
##
## How it plays:
##   - Heat goes 0..100. It creeps up every second while any cat is up in the city.
##     A district doesn't always start at 0: THE MAINFRAME (scripts/mainframe.gd) decides
##     (0 when it's charged, 15 / 30 / 50 when it runs low), and at 100% charge (OVERCLOCK)
##     heat rises 20% slower for that district.
##   - Trouble adds heat on top: shooting Roombas, blowing them up, and grabbing any item whose
##     card has a heat_on_pickup (none do right now; the golden koi used to).
##   - Every 25 heat is one HEAT LEVEL (1-4). Each level brings extra Roombas (roomba_patrol.gd)
##     that drive faster and spot cats from further away.
##   - Each gang's EXIT manhole opens at the heat its own MAINFRAME says (60-95, 75 at the start:
##     mainframe.gd exit_heat, fish_heist.gd).
##   - At 100 heat: level 5. The hatch is SEALED and the DEEP CLEAN begins (fish_heist.gd): the
##     MEGA VAC-COP (scenes/roomba_boss.tscn) plus a swarm. Then a new district starts at 0.
##   - Heat does NOT go down by itself any more (the cooling numbers below are 0): it's the
##     district's clock. Going home doesn't reset it - only a new district does.
##   - Once the exit is open (or every cat has used its one trip up), if EVERY cat is back in the
##     hub, the heat races to 100
##     (heat_per_second_when_all_home) so the next district comes quickly.
##   - The HUD shows it as the red/blue flashing HEAT bar, top-right (scripts/ui/hud_heat_bar.gd,
##     fed from _process below; down in the sewers the same bar shows THE MAINFRAME's charge).
##     Players also HEAR it go up (the heat_up / boss_siren sounds).
##
## MULTIPLAYER: only the HOST changes the heat. It sends the number to everyone a few times a
## second (for the HUD); Roombas run on the host, so they read it directly.

## The one heat meter (HeatMeter.instance).
static var instance: HeatMeter

const MAX_HEAT: float = 100.0
## Heat per level: 0-24 = level 1, 25-49 = 2, 50-74 = 3, 75-99 = 4, 100 = 5 (MEGA VAC-COP).
const HEAT_PER_LEVEL: float = 25.0
const MAX_LEVEL: int = 5

@export_group("Heating up")
## Heat added every second while at least one cat is up in the city.
## 0.167 = about 10 minutes up top from a fresh district to the DEEP CLEAN, if you cause no
## trouble at all (the exit opens after about 7.5).
@export var heat_per_second: float = 0.167
## More cats up top heat the city faster: +this much (0.1 = +10%) for every cat up there beyond
## the first. (8 cats up top with 0.1 = 1.7x as fast.)
@export var heat_per_extra_cat: float = 0.1
## Heat added each time a gun hits a Roomba.
@export var heat_per_roomba_hit: float = 0.5
## Heat added each time a Roomba is destroyed.
@export var heat_per_roomba_destroyed: float = 3.0

## Once the exit is open (or every cat has used its one trip up) and EVERY cat is back down in
## the hub (all extracted or knocked out), the heat races up by this much per second instead, so the DEEP CLEAN and the next district
## come quickly instead of everyone waiting. (5 = from 75 to 100 in 5 seconds; 0 = off.)
@export var heat_per_second_when_all_home: float = 5.0

@export_group("Cooling down")
## Heat taken away when a cat extracts ("the cops lose your trail").
@export var cool_per_extraction: float = 0.0
## Heat lost every second while NO cat is up top.
@export var cool_per_second_when_empty: float = 0.0
## Heat taken away when the MEGA VAC-COP is destroyed. (0: it only comes out in the DEEP CLEAN,
## and smashing it doesn't stop that.)
@export var cool_when_boss_destroyed: float = 0.0

@export_group("What each level does")
## Extra Roombas on patrol per level above 1 (level 3 = 2 x this extra).
@export var extra_roombas_per_level: int = 5
## Roomba chase speed goes up by this much per level above 1 (0.07 = +7% per level).
@export var speed_per_level: float = 0.07
## Roomba spotting distance goes up by this much per level above 1.
@export var sight_per_level: float = 0.1

## The heat right now (everyone has a copy; the host's is the real one).
var heat: float = 0.0

var _send_timer: float = 0.0
var _last_level: int = 1
var _announced_level: int = 1  # every computer: the level Events.heat_level_changed last said


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	add_to_group(GameSystems.GROUP)  # late joiners / quitting players / new districts (game_systems.gd)


## 1..5. 5 = the MEGA VAC-COP is out.
func level() -> int:
	return level_of(heat)


## The heat level (1..5) for any heat number.
static func level_of(heat_value: float) -> int:
	if heat_value >= MAX_HEAT:
		return MAX_LEVEL
	return mini(1 + int(heat_value / HEAT_PER_LEVEL), MAX_LEVEL - 1)


## How much faster Roombas chase at this heat (1.0 at level 1).
func speed_multiplier() -> float:
	return 1.0 + speed_per_level * (level() - 1)


## How much further Roombas see at this heat (1.0 at level 1).
func sight_multiplier() -> float:
	return 1.0 + sight_per_level * (level() - 1)


## How many EXTRA Roombas the patrol should have out at this heat.
func extra_roombas() -> int:
	return extra_roombas_per_level * (level() - 1)


## Host: add (or, with a negative number, remove) heat. Added heat is slowed while the district
## is OVERCLOCKED (scripts/mainframe.gd heat_multiplier).
func add_heat(amount: float) -> void:
	if not multiplayer.is_server():
		return
	if amount > 0.0:
		amount *= _mainframe_multiplier()
	heat = clampf(heat + amount, 0.0, MAX_HEAT)
	_send_timer = 0.0  # tell everyone right away


## Host: a new game or a new district (game_systems.gd). The heat starts where THE MAINFRAME
## says (scripts/mainframe.gd starting_heat: 0 when it's healthy, up to 50 at 0%).
func start_district() -> void:
	restart_district_heat()


## Host: put the heat back to this district's starting heat (start_district, or scrap fed into
## THE MAINFRAME before anyone went up).
func restart_district_heat() -> void:
	heat = Mainframe.instance.starting_heat() if Mainframe.instance != null else 0.0
	_last_level = level()  # (no level-up sound for starting high)
	_send_timer = 0.0


## 1.0 normally, less while THE MAINFRAME has the district OVERCLOCKED.
func _mainframe_multiplier() -> float:
	return Mainframe.instance.heat_multiplier() if Mainframe.instance != null else 1.0


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or Game.instance == null:
		return
	var cats_up := Game.instance.players_up_top()
	if cats_up > 0:
		var crowd := 1.0 + heat_per_extra_cat * (cats_up - 1)
		heat = minf(heat + heat_per_second * crowd * _mainframe_multiplier() * delta, MAX_HEAT)
	elif heat < MAX_HEAT and FishHeist.instance != null \
			and (FishHeist.instance.every_exit_is_open() or FishHeist.instance.everyone_has_been_up()):
		# Everyone's done (extracted / knocked out) after every gang's exit opened, or every cat has used
		# its one trip up (all knocked out early): hurry to the next district.
		heat = minf(heat + heat_per_second_when_all_home * delta, MAX_HEAT)
	else:
		heat = maxf(heat - cool_per_second_when_empty * delta, 0.0)
	# Share the number a few times a second (just for everyone's HUD).
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = 0.25
		_set_heat.rpc(heat)


## Host -> everyone: the heat is now this.
@rpc("authority", "call_local", "unreliable_ordered")
func _set_heat(value: float) -> void:
	heat = value


## Host -> a player who just joined.
func send_state_to(peer_id: int) -> void:
	_set_heat.rpc_id(peer_id, heat)


# --- HUD heat bar + level-up sounds (every computer) ---

func _process(_delta: float) -> void:
	var lvl := level()
	# Every player on this computer gets the bar top-right of their HUD. Up in the city it's the
	# HEAT bar (with a tick where YOUR gang's exit opens); down in the sewers it turns into YOUR
	# gang's MAINFRAME charge (scripts/mainframe.gd).
	var mainframe := Mainframe.instance
	for cat in Game.instance.playing_cats():
		var bar := Hud.element("Heat", cat.slot) as HudHeatBar
		if bar != null:
			bar.visible = true
			if mainframe == null:
				bar.visible = false
			elif not UndergroundHub.is_in_hub(cat.global_position):
				bar.set_heat(heat, MAX_HEAT, lvl, mainframe.exit_heat(cat.team))
			else:
				bar.set_mainframe(mainframe.charge_of(cat.team), Mainframe.MAX_CHARGE, mainframe.tier_color(cat.team), mainframe.tier(cat.team) == Mainframe.Tier.CRITICAL)
	# A sound (no text on screen) when the heat goes UP a level.
	if lvl > _last_level:
		if lvl < MAX_LEVEL:  # (max level = the DEEP CLEAN, which has its own siren)
			Sound.play("heat_up")  # sounds/sfx/heat_up.wav
	_last_level = lvl
	if lvl != _announced_level:
		_announced_level = lvl
		Events.heat_level_changed.emit(lvl)  # (scripts/events.gd)

