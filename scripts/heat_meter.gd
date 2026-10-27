class_name HeatMeter
extends Node
## HEAT — how angry the city is. The longer cats stay up top (and the more trouble they cause),
## the hotter it gets, and the harder the VAC-COPs come for you.
## Attach to the "Heat" node in main.tscn. One meter, shared by every player.
##
## How it plays:
##   - Heat goes 0..100. It creeps up every second while any cat is up in the city.
##   - Trouble adds heat on top: grabbing the golden koi (its item card's heat_on_pickup),
##     shooting Roombas, blowing them up.
##   - Every 25 heat is one HEAT LEVEL (1-4). Each level brings extra Roombas (roomba_patrol.gd)
##     that drive faster and spot cats from further away.
##   - At 100 heat: level 5, the MEGA VAC-COP comes out (scenes/roomba_boss.tscn). It always
##     knows where you are. Smash it and it spits out a golden koi and the heat drops.
##   - Heat cools when you extract (each extraction cools it a bit) and drains away fast
##     while nobody is up top.
##   - There is NO heat bar on the HUD (kept simple on purpose): players only HEAR it go up
##     (the heat_up / boss_siren sounds) and feel it in how many Roombas come.
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
## 0.5 = about 3 minutes from cool to the MEGA VAC-COP if you cause no trouble at all.
@export var heat_per_second: float = 0.5
## More cats up top heat the city faster: +this much (0.1 = +10%) for every cat up there beyond
## the first. (8 cats up top with 0.1 = 1.7x as fast.)
@export var heat_per_extra_cat: float = 0.1
## Heat added each time a gun hits a Roomba.
@export var heat_per_roomba_hit: float = 1.0
## Heat added each time a Roomba is destroyed.
@export var heat_per_roomba_destroyed: float = 6.0

@export_group("Cooling down")
## Heat taken away when a cat extracts ("the cops lose your trail").
@export var cool_per_extraction: float = 15.0
## Heat lost every second while NO cat is up top.
@export var cool_per_second_when_empty: float = 3.0
## Heat taken away when the MEGA VAC-COP is destroyed.
@export var cool_when_boss_destroyed: float = 45.0

@export_group("What each level does")
## Extra Roombas on patrol per level above 1 (level 3 = 2 x this extra).
@export var extra_roombas_per_level: int = 2
## Roomba chase speed goes up by this much per level above 1 (0.07 = +7% per level).
@export var speed_per_level: float = 0.07
## Roomba spotting distance goes up by this much per level above 1.
@export var sight_per_level: float = 0.1

## The heat right now (everyone has a copy; the host's is the real one).
var heat: float = 0.0

var _send_timer: float = 0.0
var _last_level: int = 1


func _enter_tree() -> void:
	instance = self


## 1..5. 5 = the MEGA VAC-COP is out.
func level() -> int:
	if heat >= MAX_HEAT:
		return MAX_LEVEL
	return mini(1 + int(heat / HEAT_PER_LEVEL), MAX_LEVEL - 1)


## How much faster Roombas chase at this heat (1.0 at level 1).
func speed_multiplier() -> float:
	return 1.0 + speed_per_level * (level() - 1)


## How much further Roombas see at this heat (1.0 at level 1).
func sight_multiplier() -> float:
	return 1.0 + sight_per_level * (level() - 1)


## How many EXTRA Roombas the patrol should have out at this heat.
func extra_roombas() -> int:
	return extra_roombas_per_level * (level() - 1)


## Host: add (or, with a negative number, remove) heat.
func add_heat(amount: float) -> void:
	if not multiplayer.is_server():
		return
	heat = clampf(heat + amount, 0.0, MAX_HEAT)
	_send_timer = 0.0  # tell everyone right away


## Host: back to zero (a new game).
func reset() -> void:
	heat = 0.0
	_last_level = 1
	_send_timer = 0.0


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or Game.instance == null:
		return
	var cats_up := 0
	for cat in Game.instance.players.get_children():
		var where := (cat as Node3D).global_position
		if Game.instance.car.driver_id == (cat as CatPlayer).player_id:
			where = Game.instance.car.global_position
		if not UndergroundHub.is_in_hub(where):
			cats_up += 1
	if cats_up > 0:
		var crowd := 1.0 + heat_per_extra_cat * (cats_up - 1)
		heat = minf(heat + heat_per_second * crowd * delta, MAX_HEAT)
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


# --- Level-up sounds (every computer; no heat bar on the HUD) ---

func _process(_delta: float) -> void:
	var lvl := level()
	# A sound (no text on screen) when the heat goes UP a level.
	if lvl > _last_level:
		if lvl == MAX_LEVEL:
			Sound.play("boss_siren")  # sounds/sfx/boss_siren.wav
		else:
			Sound.play("heat_up")  # sounds/sfx/heat_up.wav
	_last_level = lvl

