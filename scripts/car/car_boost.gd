class_name CarBoost
extends Node3D
## CYPURRPUNK — AFTERBURNER BOOST: press BOOST while driving (Shift / pad A) and the car SHOOTS
## forward with fire roaring out of the exhaust. Anything the fire touches, or the car rams while
## boosting, isn't smashed: it's SENT FLYING (bots tumble through the air and lie dazed, cats on
## foot get launched, bins and cones go over). Pure chaos, no damage.
## Attach to the "Boost" node under GetawayCar in scenes/getaway_car.tscn. Its knobs: open that
## scene, click Boost, and look at the Inspector.
##
## CHARGES: every car starts with ONE (Base Charges). The AFTERBURNER sewer upgrade (scripts/upgrades.gd,
## bought at the TINKER WORKBENCH on Paulie No-Brooms / Bumper-Car Benny's tab) adds more:
## tier 1 = 2 charges, tier 2 = 3 charges.
## It's a CREW upgrade: the gang's best tier counts, whoever drives. A used charge slowly comes
## back (Recharge Seconds each). The driver sees the BOOST bar bottom-left (scripts/ui/hud_boost_bar.gd):
## one bar, split into a piece per charge, the next piece filling up while it recharges.
##
## Network: the HOST owns the charges. The driver's computer asks (request_boost), the host checks
## a charge is there and tells EVERY computer (_start_boost): they all show the flames, the
## driver's computer (which runs the car's physics) kicks the car forward, and the host does the
## launching (_exhaust_blast + enemy.gd run_over_by_car / launch).

@export_group("Boost")
## How long one boost lasts (seconds).
@export var boost_seconds: float = 1.6
## The instant kick when it fires (metres per second added straight away).
@export var kick_speed: float = 9.0
## Extra push while it lasts (metres per second, each second) - the car floors it by itself.
@export var boost_accel: float = 30.0
## Top speed while boosting, compared to normal (1.7 = 70% faster).
@export var top_speed_multiplier: float = 1.7
## Charges every car has before any upgrade (each AFTERBURNER tier adds one more).
@export var base_charges: int = 1
## Seconds for ONE used charge to come back.
@export var recharge_seconds: float = 25.0

@export_group("Sending stuff flying")
## How far the exhaust fire reaches behind the car (metres)...
@export var exhaust_length: float = 7.0
## ...and how wide it is at its far end (metres from the middle; narrower near the car).
@export var exhaust_radius: float = 2.2
## Bots caught in the fire fly back (away from the car) this fast and up this fast (m/s).
@export var exhaust_launch_back: float = 12.0
@export var exhaust_launch_up: float = 11.0
## Bots RAMMED while boosting (instead of being smashed) fly forward / up this fast (m/s).
@export var ram_launch_forward: float = 15.0
@export var ram_launch_up: float = 12.0
## Cats on foot caught in the fire (any gang - no damage, just a flight) fly back / up this fast.
@export var cat_launch_back: float = 11.0
@export var cat_launch_up: float = 9.0

@export_group("Look")
## The flame's outer colour, and its white-hot core.
@export var flame_color: Color = Color(1.0, 0.42, 0.06)
@export var flame_core_color: Color = Color(1.0, 0.92, 0.55)
## How long the exhaust flames are (metres) and how wide at the pipe.
@export var flame_length: float = 1.9
@export var flame_radius: float = 0.24
## How brightly they glow, and the orange light they throw on the street.
@export var flame_glow: float = 5.0
@export var light_energy: float = 7.0
## The camera of everyone in the car widens this many degrees for a sense of speed...
@export var fov_kick: float = 18.0
## ...and shakes this hard (0..1, scripts/feedback.gd).
@export var shake: float = 0.55

## TESTS ONLY (DevCapture --car_test): pretend every car has this many charges. -1 = off (the real rule).
static var test_charges: int = -1

@onready var car: GetawayCar = get_parent()

## Charges ready right now, and how far the next one has recharged (0..1). Host's numbers.
var charges: int = 0
var recharge: float = 0.0

## Seconds of boost left (every computer: the flames show while > 0).
var _boost_left: float = 0.0
## Host: the max charges last time we looked (to notice a new upgrade).
var _last_max: int = 0
## Host: cats the fire already launched this boost (player id -> true), so each flies once.
var _blasted := {}
var _flames: Array[Node3D] = []
var _light: OmniLight3D
var _fire: CPUParticles3D


func _ready() -> void:
	add_to_group(GameSystems.GROUP)  # new district = full charges; late joiners (game_systems.gd)
	# Two exhaust flames (outer cone + white-hot core each), an orange light and a trail of fire cubes.
	for side in [-1, 1]:
		var pipe := Node3D.new()
		pipe.set_meta("side", side)
		add_child(pipe)
		CarFx.flame_cone(pipe, flame_color, flame_length, flame_radius, flame_glow)
		CarFx.flame_cone(pipe, flame_core_color, flame_length * 0.55, flame_radius * 0.55, flame_glow * 1.6)
		pipe.visible = false
		_flames.append(pipe)
	_light = OmniLight3D.new()
	_light.light_color = flame_color
	_light.omni_range = 7.0
	_light.light_energy = 0.0
	_light.visible = false
	add_child(_light)
	_fire = CarFx.particles(self, PackedColorArray([flame_core_color, flame_color, Color(0.25, 0.04, 0.0, 0.0)]),
		0.22, 48, 0.4, 9.0, Vector3.BACK, 12.0, 2.0)


## Is it boosting right now? (getaway_car.gd floors it; enemy.gd launches instead of smashing.)
func is_boosting() -> bool:
	return _boost_left > 0.0


## Top-speed multiplier right now (getaway_car.gd _integrate_forces).
func speed_multiplier() -> float:
	return top_speed_multiplier if is_boosting() else 1.0


## How many charges this car can hold: Base Charges + the gang's best AFTERBURNER tier (scripts/upgrades.gd).
func max_charges() -> int:
	if test_charges >= 0:
		return test_charges
	return base_charges + Upgrades.best_in_team(car.gang(), "afterburner")


func _physics_process(delta: float) -> void:
	_boost_left = maxf(_boost_left - delta, 0.0)
	if multiplayer.is_server():
		_host_recharge(delta)
		if is_boosting():
			_exhaust_blast()
	elif charges < max_charges():
		recharge = minf(recharge + delta / maxf(recharge_seconds, 0.1), 0.99)  # (just for the badge)
	# The driver's BOOST key (their own keys / pad: scripts/seats.gd).
	if car._driver_reads_input() and not car._driver_paused() \
			and Seats.is_just_pressed(PlayerId.slot_of(car.driver_id), "boost") and charges > 0 and not is_boosting():
		request_boost.rpc_id(1, car.driver_id)


## Host: top up charges when someone buys the upgrade, and slowly win back used ones.
func _host_recharge(delta: float) -> void:
	var most := max_charges()
	if most != _last_max:
		if most > _last_max:
			charges += most - _last_max  # just bought it: those charges are ready straight away
		_last_max = most
		charges = clampi(charges, 0, most)
		_set_charges.rpc(charges, recharge)
	if charges >= most:
		recharge = 0.0
		return
	if is_boosting():
		return  # (the clock waits while the fire's still burning)
	recharge += delta / maxf(recharge_seconds, 0.1)
	if recharge >= 1.0:
		recharge = 0.0
		charges += 1
		_set_charges.rpc(charges, recharge)


## Driver's computer -> host: BOOST, please.
@rpc("any_peer", "call_local", "reliable")
func request_boost(player_id: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id) or car.driver_id != player_id:
		return
	if charges <= 0 or is_boosting() or (car.health != null and car.health.wrecked):
		return
	charges -= 1
	_blasted.clear()
	_start_boost.rpc(charges, recharge)


## Host -> everyone: the charges now (one came back, or the upgrade changed).
@rpc("any_peer", "call_local", "reliable")
func _set_charges(count: int, progress: float) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return  # only the host may decide this
	var gained := count > charges
	charges = count
	recharge = progress
	if gained and _local_rider() != null:
		Sound.play_at("pickup", car.global_position, -4.0)  # a charge is ready (only our own car's)


## Host -> everyone: BOOST! Flames on every computer, the kick on the one running the car.
@rpc("any_peer", "call_local", "reliable")
func _start_boost(count: int, progress: float) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	charges = count
	recharge = progress
	_boost_left = boost_seconds
	Sound.play_at("boost", car.global_position, 3.0)
	if car.is_multiplayer_authority() and not car.freeze:
		car.apply_central_impulse(-car.global_basis.z * kick_speed * car.mass)
	# Everyone in the car on THIS computer: a wide, shaky, rumbly camera.
	for cat in Game.instance.local_cats():
		if not car.has_occupant(cat.player_id):
			continue
		Feedback.shake(cat.player_id, shake)
		Seats.rumble(cat.player_id, 0.7, 1.0, 0.4)
		var base: float = cat._base_fov
		var zoom := cat.camera.create_tween()
		zoom.tween_property(cat.camera, "fov", base + fov_kick, 0.12)
		zoom.tween_interval(maxf(boost_seconds - 0.5, 0.0))
		zoom.tween_property(cat.camera, "fov", base, 0.5)


## The first cat of THIS computer riding in this car, or null.
func _local_rider() -> CatPlayer:
	if Game.instance == null:
		return null
	for cat in Game.instance.local_cats():
		if car.has_occupant(cat.player_id):
			return cat
	return null


## Host, every physics frame of a boost: everything in the exhaust fire goes FLYING.
func _exhaust_blast() -> void:
	var back := Motion.flat(car.global_basis.z).normalized()  # the car's tail points +Z
	var rear := car.global_position + back * _box().z * 0.5
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var bot := node as Enemy
		if bot != null and not bot.is_boss and _in_fire(bot.global_position, rear, back):
			var side := Motion.flat(bot.global_position - rear) - back * Motion.flat(bot.global_position - rear).dot(back)
			bot.launch(back * exhaust_launch_back + side.limit_length(1.0) * 3.0 + Vector3.UP * exhaust_launch_up)
	for node in Game.instance.players.get_children():
		var cat := node as CatPlayer
		if cat == null or not cat.visible or cat.riding_car != null or _blasted.has(cat.player_id):
			continue
		if UndergroundHub.is_in_hub(cat.global_position) or not _in_fire(cat.global_position, rear, back):
			continue
		_blasted[cat.player_id] = true
		cat.get_zapped.rpc_id(PlayerId.peer_of(cat.player_id), back * cat_launch_back + Vector3.UP * cat_launch_up)
	if MessManager.instance != null:
		for prop in MessManager.instance.props():
			if not prop.knocked and _in_fire(prop.global_position, rear, back):
				MessManager.instance.knock(car.driver_id, prop.id, back)


## Is "where" inside the cone of fire behind the car (narrow at the pipes, wide at the far end)?
func _in_fire(where: Vector3, rear: Vector3, back: Vector3) -> bool:
	var offset := where - rear
	if absf(offset.y) > 3.0:
		return false
	var flat := Motion.flat(offset)
	var along := flat.dot(back)
	if along < -0.5 or along > exhaust_length:
		return false
	var sideways := (flat - back * along).length()
	return sideways < exhaust_radius * lerpf(0.45, 1.0, clampf(along / exhaust_length, 0.0, 1.0))


## The current ride's collision box (the bike and van are different sizes: getaway_car.gd set_vehicle).
func _box() -> Vector3:
	return ((car.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size


## Every computer, every frame: flicker the flames while boosting.
func _process(_delta: float) -> void:
	var on := is_boosting()
	var box := _box()
	var rear_z := box.z * 0.5
	for pipe in _flames:
		pipe.visible = on
		if not on:
			continue
		# Sit on the tail, left and right (closer together on the narrow bike).
		pipe.position = Vector3(float(pipe.get_meta("side")) * box.x * 0.25, -box.y * 0.1, rear_z)
		var fade := clampf(_boost_left / 0.3, 0.0, 1.0)  # shrinks away in the last moment
		pipe.scale = Vector3(1.0, 1.0, randf_range(0.7, 1.35) * fade)
	_light.visible = on
	_light.position = Vector3(0, 0.2, rear_z + 1.2)
	_light.light_energy = light_energy * randf_range(0.7, 1.2) if on else 0.0
	_fire.position = Vector3(0, -box.y * 0.1, rear_z + 0.3)
	_fire.emitting = on


# --- Game system hooks (scripts/game_systems.gd) ---

## Host: a new game / new district - every charge ready.
func start_district() -> void:
	_last_max = max_charges()
	charges = _last_max
	recharge = 0.0
	_boost_left = 0.0
	_set_charges.rpc(charges, recharge)


## Host -> a computer that just joined: the charges.
func send_state_to(peer: int) -> void:
	_set_charges.rpc_id(peer, charges, recharge)
