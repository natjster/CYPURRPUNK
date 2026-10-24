class_name GetawayCar
extends RigidBody3D
## MEOW-CITY 1999 — arcade getaway car.
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
## Space = handbrake (drift), E = get out.

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

@export_group("Camera & Exit")
@export var camera_follow_speed: float = 5.0
## Where the cat pops out, relative to the car (-X = driver's side / left).
@export var exit_offset: Vector3 = Vector3(-2.2, 0.2, 0.0)

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

## Network ID of the player driving, or 0 when the car is empty.
var driver_id: int = 0
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


# --- MULTIPLAYER ---
# Whoever is driving is the car's "authority": their computer runs the physics
# and the MultiplayerSynchronizer sends the car's position to everyone else.
# On every other computer the car is frozen and simply follows those updates.
# When nobody drives, the host is the authority.

func _ready() -> void:
	camera_arm.add_excluded_object(get_rid())
	door_zone.body_entered.connect(_on_door_zone_body_entered)
	door_zone.body_exited.connect(_on_door_zone_body_exited)
	camera_rig.global_position = global_position
	camera_rig.rotation.y = global_rotation.y
	add_to_group("cars")  # lets late-joining cats check if they're inside a car
	sync_position = global_position
	sync_rotation = global_rotation
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
	var weight := 1.0 - exp(-network_smoothing * delta)
	global_position = global_position.lerp(sync_position, weight)
	global_rotation.y = lerp_angle(global_rotation.y, sync_rotation.y, weight)


## Fill in the drive input from the keyboard — only when OUR cat is behind the wheel,
## and not while the pause menu is open (then the car just rolls to a stop).
func _read_driver_keys() -> void:
	if driver_id == multiplayer.get_unique_id() and not PauseMenu.is_open:
		throttle = Input.get_axis("move_back", "move_forward")  # W = +1, S = -1
		steer = Input.get_axis("move_right", "move_left")       # A = +1 (left), D = -1
		handbrake = Input.is_action_pressed("handbrake")
	else:
		throttle = 0.0
		steer = 0.0
		handbrake = false


func _unhandled_input(event: InputEvent) -> void:
	if driver_id == multiplayer.get_unique_id() and event.is_action_pressed("interact") and not PauseMenu.is_open:
		request_exit.rpc_id(1)
		get_viewport().set_input_as_handled()


## A cat asks to get in. Runs on the host only, which decides.
@rpc("any_peer", "call_local", "reliable")
func request_enter() -> void:
	if not multiplayer.is_server() or driver_id != 0:
		return
	var sender := multiplayer.get_remote_sender_id()
	var cat := Game.instance.cat_for(sender)
	if cat != null and cat.global_position.distance_to(global_position) <= MAX_ENTER_DISTANCE:
		set_driver.rpc(sender)


## The driver asks to get out. Runs on the host only.
@rpc("any_peer", "call_local", "reliable")
func request_exit() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == driver_id:
		set_driver.rpc(0)


## The host tells EVERY computer who is driving now (0 = nobody).
@rpc("any_peer", "call_local", "reliable")
func set_driver(peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return  # only the host may decide this
	var previous_driver := Game.instance.cat_for(driver_id)
	driver_id = peer_id
	set_multiplayer_authority(peer_id if peer_id != 0 else 1)
	_update_freeze()

	if peer_id == 0 and previous_driver != null:
		previous_driver.exit_car(to_global(exit_offset))
	var new_driver := Game.instance.cat_for(peer_id)
	if new_driver != null:
		new_driver.enter_car(self)


## A tommy gun bolt hit the car. Sent to whoever simulates the car, who applies the push.
@rpc("any_peer", "call_local", "unreliable")
func take_hit(impulse: Vector3, hit_position: Vector3) -> void:
	if is_multiplayer_authority() and not freeze:
		apply_impulse(impulse, hit_position - global_position)


func _process(delta: float) -> void:
	# CameraRig is "Top Level", so it doesn't automatically move with the car.
	# We drag it along ourselves and let its turning lag a little behind — a nice chase cam.
	camera_rig.global_position = global_position
	camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y, global_rotation.y, 1.0 - exp(-camera_follow_speed * delta))


## Runs every physics step. "state" lets us read/write the car's velocity safely.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
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

	state.linear_velocity = velocity


func _on_door_zone_body_entered(body: Node3D) -> void:
	var cat := body as CatPlayer  # null if it's not the cat (e.g. the ground)
	if cat != null:
		cat.nearby_car = self


func _on_door_zone_body_exited(body: Node3D) -> void:
	var cat := body as CatPlayer
	if cat != null and cat.nearby_car == self:
		cat.nearby_car = null
