class_name GetawayCar
extends RigidBody3D
## CYPURRPUNK — arcade getaway car.
## Attach to the root "GetawayCar" (RigidBody3D). Expected node tree:
##   GetawayCar (RigidBody3D)   <- this script
##   ├── CollisionShape3D       <- box around the car body
##   ├── Model (Node3D)         <- all the car's meshes
##   ├── GroundRay (RayCast3D)  <- points down; tells us if the wheels are on the ground
##   ├── DoorZone (Area3D)      <- "press E" range
##   │   └── CollisionShape3D
##   └── CameraRig (Node3D, Top Level ON)  <- follows the car with a slight lag
##       └── SpringArm3D        <- the cat's camera gets moved here while driving
##
## This is ARCADE physics, not a simulation: instead of real tyres we nudge the
## body's velocity directly each physics step. The body's X/Z rotation is locked
## in the scene so it can never flip over.
##
## Network sync: MultiplayerSynchronizer (child node) shares sync_position + sync_rotation.
##
## Controls while driving: W = gas, S = brake / reverse, A/D = steer,
## Space = handbrake (drift), E = get out. Mouse / right stick = look around (the camera swings
## back behind the car by itself a moment after you stop looking, while driving forward).
## Passengers: once someone drives, other cats by the door get "RIDE ALONG" (E); they share the
## driver's chase view and press E again to hop out (see "Passengers" in the Inspector).

@export_group("Parking")
## Which gang's corner this car waits in (scripts/teams.gd: 0 = Catleone Family, 1 = Burrow Gang;
## -1 = the old spot by the centre crossroads). Only decides WHERE it parks: anyone can drive it.
## main.tscn has one car per gang: GetawayCar (0) and GangCar (1). In a SOLO game only GetawayCar
## is kept, parked by the centre crossroads (game.gd is_solo).
@export var team: int = -1
## How far (metres) up the street from its gang's entry manhole it parks, towards the middle.
@export var park_distance: float = 10.0

@export_group("Engine")
@export var max_speed: float = 26.0          ## m/s (~95 km/h)
@export var engine_accel: float = 14.0
@export var max_reverse_speed: float = 8.0
@export var reverse_accel: float = 7.0
@export var brake_decel: float = 24.0
## How fast the car rolls to a stop when you let go of the gas.
@export var coast_drag: float = 0.6

@export_group("Steering")
## Max turning rate in radians per second.
@export var turn_speed: float = 2.4
## How quickly the steering reaches full lock (higher = twitchier).
@export var steer_response: float = 8.0
## Below this speed steering is weaker (no spinning on the spot).
@export var full_steer_speed: float = 6.0

@export_group("Drift")
## How hard the tyres resist sliding sideways normally. Higher = grippier.
@export var normal_grip: float = 10.0
## Sideways grip while holding the handbrake. Low = big slides.
@export var drift_grip: float = 1.2
## Extra turning while drifting.
@export var drift_turn_boost: float = 1.5
## How much the handbrake slows you down.
@export var handbrake_drag: float = 1.2

@export_group("Crashing into the MEGA VAC-COP")
## Driving into the boss is a crash: the car stops dead and bounces back at this speed (m/s).
## (The boss is on collision layer 3, which the car's Mask includes; small Roombas are only on
## layer 2, so the car still drives over / smashes those.)
@export var boss_crash_bounce: float = 1.5

@export_group("Camera & Exit")
@export var camera_follow_speed: float = 5.0
## Mouse look while driving (same feel as on foot; MOUSE SPEED in Settings multiplies it).
@export var mouse_sensitivity: float = 0.0025
## Right stick look while driving, radians per second at full tilt (STICK SPEED multiplies it).
@export var stick_turn_speed: float = 3.2
## How far up / down you can tilt the camera (degrees; negative = looking down at the car).
@export var min_look_pitch_degrees: float = -60.0
@export var max_look_pitch_degrees: float = 10.0
## Seconds after you stop moving the camera before it swings back behind the car.
@export var recenter_delay: float = 1.5
## How quickly it swings back (higher = snappier).
@export var recenter_speed: float = 2.5
## It only swings back while driving forward faster than this (m/s), so you can stop and look around.
@export var recenter_min_speed: float = 3.0
## Where the cat pops out, relative to the car (-X = driver's side / left).
@export var exit_offset: Vector3 = Vector3(-2.2, 0.2, 0.0)

@export_group("Passengers")
## How many cats can ride along besides the driver (they press E by the door once someone's
## driving, and E again to hop out). They can't steer: they just enjoy the chase view.
@export var passenger_seats: int = 3
## Where the FIRST passenger pops out (+X = the right-hand side). Each next one is this much further back.
@export var passenger_exit_offset: Vector3 = Vector3(2.2, 0.2, -0.8)
@export var passenger_exit_spacing: Vector3 = Vector3(0.0, 0.0, 1.4)

@export_group("Engine Sound")
## Engine pitch when idling, and at top speed (1.0 = the file's own pitch).
## The sound is sounds/sfx/engine_loop.wav (it loops).
@export var engine_idle_pitch: float = 0.7
@export var engine_top_pitch: float = 2.2
## Engine loudness in decibels while someone is in the car. Empty + parked = silent.
@export var engine_volume_db: float = -6.0

@export_group("Network Smoothing")
## How quickly other players' copies of the car catch up. Higher = snappier.
@export var network_smoothing: float = 12.0
## Further off than this = jump instantly (e.g. someone who just joined).
@export var snap_distance: float = 8.0

## How close (in metres) a cat must be for the host to let it in.
const MAX_ENTER_DISTANCE: float = 5.0

@onready var ground_ray: RayCast3D = $GroundRay
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var door_zone: Area3D = $DoorZone

## Player ID of the cat driving (scripts/player_id.gd), or 0 when the car is empty.
var driver_id: int = 0
## Player IDs of the cats riding along (not driving), in the order they got in.
var passenger_ids: Array[int] = []
## True while sliding sideways with the handbrake (handy later for tyre smoke / sounds).
var is_drifting: bool = false

# --- Drive input: what the "driver" wants right now. The physics below only reads these. ---
# The player's keyboard fills them in (_read_driver_keys). Later an AI driver (Dog Patrol)
# can fill in the same three numbers instead and drive with the exact same physics.
## -1 = full brake / reverse, 0 = coast, +1 = full gas.
var throttle: float = 0.0
## -1 = full right, +1 = full left.
var steer: float = 0.0
var handbrake: bool = false

## Where the car's simulator (driver, or host when empty) says it is. Sent over the network.
var sync_position: Vector3
var sync_rotation: Vector3
## A move waiting for the next physics step (park): a Transform3D, or null (see _teleport).
var _pending_teleport: Variant = null

## Driver's look-around: how far the camera is turned away from straight behind the car
## (radians, left/right and up/down). 0, 0 = the normal chase view.
var look_yaw: float = 0.0
var look_pitch: float = 0.0
## Seconds since the driver last moved the camera (see recenter_delay).
var _since_look: float = 0.0
## Where the chase camera points before the look-around is added (lags behind the car's turning).
var _chase_yaw: float = 0.0
## The spring arm's tilt in the scene (the normal chase view).
var _base_pitch: float = 0.0

## Engine sound (every computer). Speed is measured from how far the car moved, because
## other players' copies are frozen and have no real velocity.
var _engine: AudioStreamPlayer3D
var _sound_last_position: Vector3
var _sound_speed: float = 0.0


# --- MULTIPLAYER ---
# Whoever is driving is the car's "authority": their computer runs the physics
# and the MultiplayerSynchronizer sends the car's position to everyone else.
# On every other computer the car is frozen and simply follows those updates.
# When nobody drives, the host is the authority.

func _ready() -> void:
	camera_arm.add_excluded_object(get_rid())
	# Report what we touch, so _integrate_forces can notice crashing into the MEGA VAC-COP.
	contact_monitor = true
	max_contacts_reported = 4
	door_zone.body_entered.connect(_on_door_zone_body_entered)
	door_zone.body_exited.connect(_on_door_zone_body_exited)
	camera_rig.global_position = global_position
	camera_rig.rotation.y = global_rotation.y
	_chase_yaw = global_rotation.y
	_base_pitch = camera_arm.rotation.x
	add_to_group("cars")  # lets late-joining cats check if they're inside a car
	add_to_group(Interactable.GROUP)  # E by the door gets in (scripts/interactable.gd)
	add_to_group(GameSystems.GROUP)  # late joiners / quitting players / new districts (game_systems.gd)
	sync_position = global_position
	sync_rotation = global_rotation
	_engine = Sound.attach_loop("engine_loop", self, -80.0)
	_sound_last_position = global_position
	# Our network ID changes when we join a game, so re-check who simulates the car.
	multiplayer.connected_to_server.connect(_update_freeze)
	_update_freeze()


func _update_freeze() -> void:
	freeze = not is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	_read_driver_keys()
	if is_multiplayer_authority():
		# We simulate the car: publish where it is.
		sync_position = global_position
		sync_rotation = global_rotation
		return

	# Someone else simulates it: glide our frozen copy toward their latest position.
	if global_position.distance_to(sync_position) > snap_distance:
		global_position = sync_position
		global_rotation = sync_rotation
		return
	var weight := Motion.glide_weight(network_smoothing, delta)
	global_position = global_position.lerp(sync_position, weight)
	global_rotation.y = lerp_angle(global_rotation.y, sync_rotation.y, weight)


## Fill in the drive input from the keyboard — only when OUR cat is behind the wheel,
## and not while the pause menu is open (then the car just rolls to a stop).
func _read_driver_keys() -> void:
	if _driver_reads_input() and not _driver_paused():
		# W = +1, S = -1. On a controller the triggers work too (RT = GAS, LT = BRAKE), and
		# they're analog: squeeze RT halfway for half gas.
		var seat := PlayerId.slot_of(driver_id)  # the driver's own keys / controller (scripts/seats.gd)
		throttle = clampf(Seats.get_axis(seat, "move_back", "move_forward") + Seats.get_axis(seat, "brake", "gas"), -1.0, 1.0)
		steer = Seats.get_axis(seat, "move_right", "move_left")       # A = +1 (left), D = -1
		handbrake = Seats.is_pressed(seat, "handbrake")
	else:
		throttle = 0.0
		steer = 0.0
		handbrake = false


func _unhandled_input(event: InputEvent) -> void:
	# A passenger on THIS computer pressed E: hop out (each passenger checks their own keys / pad).
	for passenger_id in passenger_ids:
		var passenger := Game.instance.cat_for(passenger_id) if Game.instance != null else null
		if passenger == null or not passenger.reads_input() or PauseMenu.is_open or passenger._menu_open():
			continue
		if Seats.event_is(passenger.slot, event, "interact"):
			request_exit.rpc_id(1, passenger_id)
			get_viewport().set_input_as_handled()
			return
	if not _driver_reads_input() or _driver_paused():
		return
	var seat := PlayerId.slot_of(driver_id)
	if Seats.event_is(seat, event, "interact"):
		request_exit.rpc_id(1, driver_id)
		get_viewport().set_input_as_handled()
	elif seat == 0 and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Mouse look while driving (MOUSE SPEED and INVERT MOUSE Y from Settings, like on foot).
		var sensitivity := mouse_sensitivity * Settings.mouse_speed
		var pitch_sign := -1.0 if Settings.invert_y else 1.0
		_turn_camera(-event.relative.x * sensitivity, -event.relative.y * sensitivity * pitch_sign)


## True if the driver is a cat THIS computer's keyboard / controller steers (cat_player.gd reads_input).
func _driver_reads_input() -> bool:
	var driver := Game.instance.cat_for(driver_id) if driver_id != 0 and Game.instance != null else null
	return driver != null and driver.reads_input()


## Is the driver's player in a menu (the pause menu, or their own split-screen pause)?
func _driver_paused() -> bool:
	var driver := Game.instance.cat_for(driver_id) if driver_id != 0 and Game.instance != null else null
	return PauseMenu.is_open or (driver != null and driver._menu_open())


## Is this player in the car at all (driving OR riding along)?
func has_occupant(player_id: int) -> bool:
	return player_id != 0 and (driver_id == player_id or passenger_ids.has(player_id))


## Is there a free seat (the driver's seat first, then the passenger seats)?
func has_free_seat() -> bool:
	return driver_id == 0 or passenger_ids.size() < passenger_seats


## A cat (player ID) asks to get in. Runs on the host only, which decides.
## Empty car = they drive. Someone already driving = they ride along (if a seat is free).
@rpc("any_peer", "call_local", "reliable")
func request_enter(player_id: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id) or has_occupant(player_id):
		return
	var cat := Game.instance.cat_for(player_id)
	if cat == null or cat.global_position.distance_to(global_position) > MAX_ENTER_DISTANCE:
		return
	if driver_id == 0:
		set_driver.rpc(player_id)
	elif passenger_ids.size() < passenger_seats:
		var riders := passenger_ids.duplicate()
		riders.append(player_id)
		set_passengers.rpc(riders)


## A cat in the car (driver or passenger) asks to get out. Runs on the host only.
## (It names WHICH cat: on split screen two cats in the car can belong to the same computer.)
@rpc("any_peer", "call_local", "reliable")
func request_exit(player_id: int) -> void:
	if multiplayer.is_server() and PlayerId.sender_owns(player_id):
		remove_occupant(player_id)


## Host: take this player out of the car, wherever they sit. (Leaves the others where they are:
## if the driver hops out the passengers stay put, and one of them can climb into the driver's seat.)
func remove_occupant(player_id: int) -> void:
	if driver_id == player_id:
		set_driver.rpc(0)
	elif passenger_ids.has(player_id):
		var riders := passenger_ids.duplicate()
		riders.erase(player_id)
		set_passengers.rpc(riders)


## Host: everybody out (the DEEP CLEAN, a new district...).
func empty_car() -> void:
	if not passenger_ids.is_empty():
		set_passengers.rpc([])
	if driver_id != 0:
		set_driver.rpc(0)


## The host tells EVERY computer who rides along now (the whole list). Cats that left the
## list get out on the right-hand side; new ones disappear into the back seat.
@rpc("any_peer", "call_local", "reliable")
func set_passengers(riders: Array) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return  # only the host may decide this
	var old := passenger_ids.duplicate()
	passenger_ids.clear()
	for id in riders:
		passenger_ids.append(int(id))
	for i in old.size():
		if not passenger_ids.has(old[i]):
			var leaving := Game.instance.cat_for(old[i])
			if leaving != null:
				Sound.play_at("car_door", global_position)
				leaving.exit_car(to_global(passenger_exit_offset + passenger_exit_spacing * i))
	for id in passenger_ids:
		if not old.has(id):
			var rider := Game.instance.cat_for(id)
			if rider != null:
				Sound.play_at("car_door", global_position)
				rider.enter_car(self)


## The host tells EVERY computer who is driving now (0 = nobody).
@rpc("any_peer", "call_local", "reliable")
func set_driver(player_id: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return  # only the host may decide this
	var previous_driver := Game.instance.cat_for(driver_id)
	driver_id = player_id
	look_yaw = 0.0  # every ride starts with the normal chase view
	look_pitch = 0.0
	# The driver's computer simulates the car (the host when it's empty).
	set_multiplayer_authority(PlayerId.peer_of(player_id) if player_id != 0 else 1)
	_update_freeze()

	if player_id != 0 or previous_driver != null:
		Sound.play_at("car_door", global_position)
	if player_id == 0 and previous_driver != null:
		previous_driver.exit_car(to_global(exit_offset))
	var new_driver := Game.instance.cat_for(player_id)
	if new_driver != null:
		new_driver.enter_car(self)


## Host (and start menu): back to the parking spot, stopped. Also used when the driver
## extracts, so the car is waiting for the next trip up.
func park() -> void:
	_teleport(parking_spot())


## Move the car somewhere else, stopped. A RigidBody that's been resting ignores a plain
## "global_transform =" (the physics engine puts it straight back: cars stayed on the menu's
## centre spot instead of going to their corners), so the move is ALSO done inside the next
## physics step (_integrate_forces), which the engine respects.
func _teleport(where: Transform3D) -> void:
	global_transform = where  # (frozen copies on other computers, and anything reading it this frame)
	_pending_teleport = where
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sync_position = where.origin
	sync_rotation = where.basis.get_euler()


## The start menu only: wait by the centre crossroads (in the menu camera's shot, outside
## Meow-Mart). When a game starts, start_district parks it in its gang's corner.
func park_for_menu() -> void:
	_teleport(Transform3D(Basis(), CityGenerator.CAR_SPAWN))


## Where this car waits: park_distance up the north-south street from its gang's entry manhole
## (fish_heist.gd entry_position), nose pointing towards the middle of the city. No gang (-1),
## or no heist yet: the old spot by the centre crossroads.
func parking_spot() -> Transform3D:
	if team < 0 or FishHeist.instance == null or FishHeist.instance.city == null:
		return Transform3D(Basis(), CityGenerator.CAR_SPAWN)
	if team == 0 and Game.instance != null and Game.instance.is_solo():
		return Transform3D(Basis(), CityGenerator.CAR_SPAWN)  # SOLO: the classic spot by the centre (game.gd)
	var manhole := FishHeist.instance.corner_position(team)  # (its gang's corner, solo or not)
	var north_south := -signf(manhole.z) if manhole.z != 0.0 else -1.0  # +1 = drive south, -1 = north
	var spot := manhole + Vector3(0, 0.5, north_south * park_distance)
	# The car's nose is -Z: facing north is no turn, facing south is a half turn.
	return Transform3D(Basis(Vector3.UP, 0.0 if north_south < 0.0 else PI), spot)


# --- Game system hooks (scripts/game_systems.gd) ---

## Host: a new game / new district - the car waits at its spot.
func start_district() -> void:
	park()


## Host -> a computer that just joined: who's already driving, so that driver's cat is hidden
## and their copy of the car follows the right player.
func send_state_to(peer: int) -> void:
	if driver_id != 0:
		set_driver.rpc_id(peer, driver_id)
	if not passenger_ids.is_empty():
		set_passengers.rpc_id(peer, passenger_ids)


## Host: a player quit. If they were in the car, take them out before their cat disappears.
func player_left(player_id: int, _last_position: Vector3) -> void:
	remove_occupant(player_id)


## The hit framework (scripts/hit.gd): a bolt hit the car. Runs on the SHOOTER's computer;
## whoever simulates the car applies the push. (No damage number.)
func receive_hit(hit: Hit) -> bool:
	# Car Launch is a speed, so it's multiplied by the car's weight to throw it that fast.
	var launch := (hit.direction + Vector3.UP) * hit.weapon.car_launch * mass
	take_hit.rpc_id(get_multiplayer_authority(), hit.direction * hit.weapon.car_impulse + launch, hit.position)
	return false


## A tommy gun bolt hit the car. Sent to whoever simulates the car, who applies the push.
@rpc("any_peer", "call_local", "unreliable")
func take_hit(impulse: Vector3, hit_position: Vector3) -> void:
	if is_multiplayer_authority() and not freeze:
		apply_impulse(impulse, hit_position - global_position)


func _process(delta: float) -> void:
	# CameraRig is "Top Level", so it doesn't automatically move with the car.
	# We drag it along ourselves and let its turning lag a little behind — a nice chase cam.
	camera_rig.global_position = global_position
	_chase_yaw = lerp_angle(_chase_yaw, global_rotation.y, 1.0 - exp(-camera_follow_speed * delta))
	if _driver_reads_input():
		_update_look_around(delta)
	# The chase view plus however far the driver has turned the camera.
	camera_rig.rotation.y = _chase_yaw + look_yaw
	camera_arm.rotation.x = _base_pitch + look_pitch
	_update_engine_sound(delta)


## Driver only, every frame: right-stick look, and swinging the camera back behind the car.
func _update_look_around(delta: float) -> void:
	if not _driver_paused():
		var stick := Seats.get_vector(PlayerId.slot_of(driver_id), "look_left", "look_right", "look_up", "look_down")
		if stick != Vector2.ZERO:
			stick *= stick.length()  # gentle near the middle, fast at full tilt (like on foot)
			var turn := stick_turn_speed * Seats.stick_speed(PlayerId.slot_of(driver_id)) * delta
			var pitch_sign := -1.0 if Seats.invert_stick_y(PlayerId.slot_of(driver_id)) else 1.0
			_turn_camera(-stick.x * turn, -stick.y * turn * 0.6 * pitch_sign)
	_since_look += delta
	# Done looking and driving forward: ease back to the normal view behind the car.
	var forward_speed := -global_basis.z.dot(linear_velocity)
	if _since_look > recenter_delay and forward_speed > recenter_min_speed:
		var weight := 1.0 - exp(-recenter_speed * delta)
		look_yaw = lerp_angle(look_yaw, 0.0, weight)
		look_pitch = lerpf(look_pitch, 0.0, weight)


## Turn the driving camera by this much (radians), from the mouse or the right stick.
func _turn_camera(yaw: float, pitch: float) -> void:
	look_yaw = wrapf(look_yaw + yaw, -PI, PI)
	look_pitch = clampf(look_pitch + pitch,
		deg_to_rad(min_look_pitch_degrees) - _base_pitch, deg_to_rad(max_look_pitch_degrees) - _base_pitch)
	_since_look = 0.0


## Engine revs up with speed; silent when nobody's in it and it's standing still.
func _update_engine_sound(delta: float) -> void:
	var moved := global_position.distance_to(_sound_last_position) / maxf(delta, 0.0001)
	_sound_last_position = global_position
	if moved > 60.0:
		moved = _sound_speed  # a teleport (parked back at the start): ignore that frame
	_sound_speed = lerpf(_sound_speed, moved, 1.0 - exp(-6.0 * delta))
	if _engine == null:
		return
	var running := driver_id != 0 or _sound_speed > 0.5
	var target_db := engine_volume_db if running else -80.0
	_engine.volume_db = lerpf(_engine.volume_db, target_db, 1.0 - exp(-4.0 * delta))
	_engine.pitch_scale = lerpf(engine_idle_pitch, engine_top_pitch, clampf(_sound_speed / max_speed, 0.0, 1.0))


## Runs every physics step. "state" lets us read/write the car's velocity safely.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_teleport != null:
		# park() / park_for_menu(): jump there, stopped (see _teleport).
		state.transform = _pending_teleport
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_pending_teleport = null
		return
	var dt := state.step
	var forward := -state.transform.basis.z  # Godot's forward is -Z
	var right := state.transform.basis.x
	var velocity := state.linear_velocity
	var forward_speed := forward.dot(velocity)  # + going forward, - reversing
	var side_speed := right.dot(velocity)       # how much we're sliding sideways

	# throttle / steer / handbrake = the drive input (see _read_driver_keys).
	is_drifting = false
	if ground_ray.is_colliding():
		# --- Gas / brake / reverse ---
		if throttle > 0.0:
			if forward_speed < max_speed:
				velocity += forward * engine_accel * throttle * dt
		elif throttle < 0.0:
			if forward_speed > 0.5:
				velocity -= forward * brake_decel * dt          # still rolling forward: brake
			elif forward_speed > -max_reverse_speed:
				velocity += forward * reverse_accel * throttle * dt  # stopped: reverse
		else:
			velocity -= forward * forward_speed * min(coast_drag * dt, 1.0)

		if handbrake:
			velocity -= forward * forward_speed * min(handbrake_drag * dt, 1.0)

		# --- Grip: cancel some sideways sliding. Low grip (handbrake) = drift. ---
		var grip := drift_grip if handbrake else normal_grip
		velocity -= right * side_speed * min(grip * dt, 1.0)
		is_drifting = handbrake and absf(side_speed) > 2.0

		# --- Steering: turn faster the faster you go; flip direction when reversing. ---
		var speed_factor := clampf(absf(forward_speed) / full_steer_speed, 0.0, 1.0)
		var direction_sign := 1.0 if forward_speed >= 0.0 else -1.0
		var target_turn := steer * turn_speed * speed_factor * direction_sign
		if handbrake:
			target_turn *= drift_turn_boost
		var angular := state.angular_velocity
		angular.y = lerp(angular.y, target_turn, min(steer_response * dt, 1.0))
		state.angular_velocity = angular

	# --- Crashed into the MEGA VAC-COP: stop dead (like hitting a wall), bounce back a little ---
	for i in state.get_contact_count():
		var boss := state.get_contact_collider_object(i) as Enemy
		if boss == null or not boss.is_boss:
			continue
		var away := global_position - boss.global_position
		away.y = 0.0
		away = away.normalized()
		if velocity.dot(-away) > 0.0:  # only while driving INTO it (you can still back away)
			velocity = Vector3(away.x * boss_crash_bounce, velocity.y, away.z * boss_crash_bounce)
			state.angular_velocity.y = 0.0

	state.linear_velocity = velocity


# --- The E key (scripts/interactable.gd): a cat by the door can get in ---

func interact_distance(cat: CatPlayer) -> float:
	if cat.nearby_car != self or not has_free_seat():
		return -1.0  # too far, or every seat is taken
	return global_position.distance_to(cat.global_position)


func interact_prompt(_cat: CatPlayer) -> String:
	return "GET IN" if driver_id == 0 else "RIDE ALONG"


## Ask the host for a seat: it decides, so two cats can't grab the same seat at once.
func interact(cat: CatPlayer) -> void:
	request_enter.rpc_id(1, cat.player_id)


func interact_priority() -> int:
	return 0


func _on_door_zone_body_entered(body: Node3D) -> void:
	var cat := body as CatPlayer  # null if it's not the cat (e.g. the ground)
	if cat != null:
		cat.nearby_car = self


func _on_door_zone_body_exited(body: Node3D) -> void:
	var cat := body as CatPlayer
	if cat != null and cat.nearby_car == self:
		cat.nearby_car = null
