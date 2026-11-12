class_name CarHealth
extends Node3D
## CYPURRPUNK — CAR HEALTH: the getaway car can be beaten up, smoke, catch fire and WRECK.
## Attach to the "Health" node under GetawayCar in scenes/getaway_car.tscn. Its knobs: open that
## scene, click Health, and look at the Inspector.
##
## What hurts the car (the HOST counts every point, as always):
##   - VAC-COPs RAMMING it: bots still chase cats who jump in a car (roomba.gd _bonk_car; how hard
##     = the bot's Bonk Damage x Car Damage Multiplier, in its scene's Inspector).
##   - SQUIRT-DRONE zaps that land on it (squirt_drone.gd).
##   - CRASHING (OFF by default: Crashes Hurt): losing a lot of speed at once (a wall...). Worked out on
##     the DRIVER's computer (it runs the car's physics), then sent to the host: report_crash.
##   - The OTHER gang's guns (TURF WAR only: your own gang's bolts never hurt your ride).
##
## Every computer sees: a health bar over the car once it's damaged (scripts/ui/hud_health_bars.gd,
## your own gang's car gets the friendly blue one), grey smoke from the bonnet under half health,
## fire under a fifth. At 0 HP it WRECKS: a fireball, everyone inside is thrown out (and a bit
## hurt), and the burning wreck can't be driven. After Wreck Seconds it's towed back to its parking
## spot, good as new. A new district (start_district) also repairs it.

@export_group("Toughness")
## Full health. (A VAC-COP ram takes ~20, a squirt ~9, a pistol bolt ~40.)
@export var max_health: int = 300
## Off (the default) = hitting walls, buildings or anything else NEVER dents the car: only enemies
## (VAC-COP rams, squirt-drone zaps, the other gang's guns) do. Tick it to bring crash damage back.
@export var crashes_hurt: bool = false
## A crash = losing at least this much speed (metres per second) almost at once. Normal braking
## never counts; hitting a wall at full speed does.
@export var crash_speed_loss: float = 9.0
## Damage per m/s of speed lost in a crash (above half of Crash Speed Loss).
@export var crash_damage_per_speed: float = 4.0

@export_group("Wreck")
## How long the burning wreck sits there before it's towed back (seconds).
@export var wreck_seconds: float = 10.0
## The blast throws the wreck up this fast (metres per second).
@export var wreck_hop: float = 6.0
## HP every cat inside loses when the car blows up (they get thrown out either way).
@export var wreck_occupant_damage: int = 20

@export_group("Look")
## Smoke pours out of the bonnet below this share of health (0.5 = half).
@export var smoke_below: float = 0.5
## Fire below this share of health (and always on a wreck).
@export var fire_below: float = 0.2
## Health bar height over the car's middle (metres).
@export var bar_height: float = 1.9

@onready var car: GetawayCar = get_parent()

## Health right now (every computer has the host's number).
var health: int = 0
## True while the car is a burning wreck (nobody can get in).
var wrecked: bool = false

## Host: seconds until the wreck is towed back.
var _wreck_left: float = 0.0
## Car's simulator: the fastest it went lately (eases down at braking speed), to spot crashes.
var _recent_speed: float = 0.0
var _crash_cooldown: float = 0.0
var _smoke: CPUParticles3D
var _fire: CPUParticles3D


func _ready() -> void:
	health = max_health
	add_to_group(GameSystems.GROUP)  # new district = repaired; late joiners get the number (game_systems.gd)
	car.add_to_group(HudHealthBars.GROUP)  # the floating health bar (getaway_car.gd health_bar_info)
	_smoke = CarFx.particles(self, PackedColorArray([Color(0.5, 0.5, 0.5, 0.8), Color(0.15, 0.15, 0.15, 0.0)]),
		0.35, 24, 1.6, 2.5, Vector3.UP, 25.0, 1.5)
	_fire = CarFx.particles(self, PackedColorArray([Color(1, 0.9, 0.4), Color(1, 0.4, 0.05), Color(0.4, 0.05, 0.0, 0.0)]),
		0.25, 30, 0.6, 3.5, Vector3.UP, 20.0, 3.0)


## Share of health left (0..1).
func fraction() -> float:
	return clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)


## For the floating health bar (getaway_car.gd health_bar_info -> scripts/ui/hud_health_bars.gd).
func bar_info() -> Dictionary:
	return {"hp": health, "max": max_health, "name": Upgrades.VEHICLE_NAMES.get(car.vehicle, "CAR"),
		"position": car.global_position + Vector3.UP * bar_height, "show": health < max_health}


func _process(_delta: float) -> void:
	# The smoke + fire pour out of the front (bonnet), wherever the current ride's front is.
	var box := (car.get_node("CollisionShape3D").shape as BoxShape3D).size
	var bonnet := car.to_global(Vector3(0, box.y * 0.5 + 0.1, -box.z * 0.3))
	_smoke.global_position = bonnet
	_fire.global_position = bonnet
	_smoke.emitting = wrecked or fraction() < smoke_below
	_fire.emitting = wrecked or fraction() < fire_below


func _physics_process(delta: float) -> void:
	_check_for_crash(delta)
	if multiplayer.is_server() and wrecked:
		_wreck_left -= delta
		if _wreck_left <= 0.0:
			repair()


## The car's simulator (driver's computer): a sudden loss of speed = a crash. Ask the host to dent it.
func _check_for_crash(delta: float) -> void:
	_crash_cooldown = maxf(_crash_cooldown - delta, 0.0)
	if not crashes_hurt or not car.is_multiplayer_authority() or car.freeze or car.driver_id == 0 or wrecked:
		_recent_speed = 0.0
		return
	var speed := Vector3(car.linear_velocity.x, 0, car.linear_velocity.z).length()
	if Engine.get_physics_frames() - car.teleport_frame < 5:
		_recent_speed = speed  # (parked / teleported: that's not a crash)
		return
	# Remember the top speed lately, easing down at hard-braking speed (40 m/s each second).
	_recent_speed = maxf(speed, _recent_speed - 40.0 * delta)
	var lost := _recent_speed - speed
	if lost > crash_speed_loss and _crash_cooldown <= 0.0:
		_crash_cooldown = 0.6
		_recent_speed = speed
		report_crash.rpc_id(1, roundi((lost - crash_speed_loss * 0.5) * crash_damage_per_speed))


## Driver's computer -> host: we crashed this hard.
@rpc("any_peer", "call_local", "reliable")
func report_crash(amount: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != car.get_multiplayer_authority():
		return  # only whoever simulates the car can say it crashed
	damage(clampi(amount, 1, 120), "A CRASH")
	print("[CarHealth] %s crashed: -%d (now %d)" % [car.name, clampi(amount, 1, 120), health])


## Shooter's computer -> host: a rival's bolt hit our car (getaway_car.gd receive_hit).
@rpc("any_peer", "call_local", "reliable")
func request_shot(shooter_id: int, amount: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(shooter_id):
		return
	if Teams.team_of(shooter_id) == car.gang():
		return  # friendly fire never dents your own gang's ride
	damage(clampi(amount, 1, 150), "GUNFIRE")


## Host: take "amount" off. 0 = WRECKED. "cause" is just for the log.
func damage(amount: int, cause: String = "") -> void:
	if not multiplayer.is_server() or wrecked or amount <= 0:
		return
	var hp := maxi(health - amount, 0)
	_set_health.rpc(hp, false)
	if hp == 0:
		_wreck(cause)


## Host: BOOM. Everyone out, the wreck hops up in a fireball and burns for Wreck Seconds.
func _wreck(cause: String) -> void:
	var inside: Array[int] = []
	if car.driver_id != 0:
		inside.append(car.driver_id)
	inside.append_array(car.passenger_ids)
	car.empty_car()  # (the host simulates the empty car now, so it can throw it)
	_wreck_left = wreck_seconds
	_set_health.rpc(0, true)
	_boom.rpc()
	for player_id in inside:
		if CatHealth.instance != null:
			CatHealth.instance.damage(player_id, wreck_occupant_damage, "A CAR WRECK")
	if not car.freeze:
		car.apply_central_impulse(Vector3.UP * wreck_hop * car.mass)
		car.apply_torque_impulse(Vector3.UP * car.mass * 3.0)
	print("[CarHealth] %s WRECKED by %s (threw out %s)" % [car.name, cause, inside])


## Host: fixed and towed back to the parking spot.
func repair() -> void:
	if not multiplayer.is_server():
		return
	_wreck_left = 0.0
	if wrecked:
		car.park()
	_set_health.rpc(max_health, false)


## Host -> everyone: the car's health now, and whether it's a wreck.
@rpc("any_peer", "call_local", "reliable")
func _set_health(hp: int, is_wrecked: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return  # only the host may decide this
	var lost := health - hp
	health = hp
	if is_wrecked != wrecked:
		wrecked = is_wrecked
		_show_wreck(wrecked)
	# Our own cats inside feel the hit (scripts/feedback.gd).
	if lost > 0 and Game.instance != null:
		for cat in Game.instance.local_cats():
			if car.has_occupant(cat.player_id):
				Feedback.shake(cat.player_id, clampf(lost / 60.0, 0.15, 0.6))
				Seats.rumble(cat.player_id, 0.5, 0.7, 0.15)


## Every computer: the wreck slumps on one side with its headlight off (and back again when fixed).
func _show_wreck(on: bool) -> void:
	var model := car.get_node("Model") as Node3D
	model.rotation.z = 0.12 if on else 0.0
	model.position.y = -0.15 if on else 0.0
	(car.get_node("Model/HeadlightBeam") as Light3D).visible = not on


## Host -> everyone: the fireball.
@rpc("any_peer", "call_local", "reliable")
func _boom() -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	Sound.play_at("explode", car.global_position, 4.0)
	CarFx.burst(car.get_parent(), car.global_position + Vector3.UP * 0.5)
	Feedback.shake_near(car.global_position, 0.9, 20.0)


# --- Game system hooks (scripts/game_systems.gd) ---

## Host: a new game / new district - good as new.
func start_district() -> void:
	repair()


## Host -> a computer that just joined: the car's health.
func send_state_to(peer: int) -> void:
	_set_health.rpc_id(peer, health, wrecked)
