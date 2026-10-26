class_name CatPlayer
extends CharacterBody3D
## MEOW-CITY 1999 — third-person cat controller.
## Attach to the root "Player" (CharacterBody3D). Expected node tree:
##   Player (CharacterBody3D)  <- this script
##   ├── CollisionShape3D
##   ├── CatModel (Node3D)     <- all the cat's meshes live under here
##   └── CameraPivot (Node3D)  <- turns left/right with the mouse
##       └── SpringArm3D       <- tilts up/down, pulls the camera in if a wall is in the way
##           └── Camera3D
##
## Only CatModel rotates to face where the cat runs. The Player body itself never
## spins, so the camera (also a child) isn't dragged around with it.

# --- Tuning knobs: all of these show up in the Inspector, no code needed ---
@export_group("Movement")
@export var walk_speed: float = 4.5
@export var zoomies_speed: float = 9.0
## How quickly the cat reaches full speed / stops. Higher = snappier.
@export var acceleration: float = 10.0
## How quickly the cat model turns to face its running direction.
@export var turn_speed: float = 12.0
@export var jump_velocity: float = 6.0

@export_group("Camera")
@export var mouse_sensitivity: float = 0.0025
## Controller: how fast the right stick turns the camera at full tilt (radians per second,
## about 3 = half a turn per second). STICK SPEED in SETTINGS > CONTROLS multiplies this.
@export var stick_turn_speed: float = 3.2
## Controller: up/down look speed compared to left/right (looking up/down needs less).
@export var stick_pitch_ratio: float = 0.6
@export var min_pitch_degrees: float = -70.0
@export var max_pitch_degrees: float = 20.0
## While holding the tommy gun, the camera slides this far to the right (over the shoulder)
## so the cat isn't blocking the crosshair.
@export var gun_shoulder_offset: float = 0.7

@export_group("Zoomies Juice")
## Cat leans its nose forward while sprinting.
@export var zoomies_lean_degrees: float = 15.0
## Camera rolls slightly when you strafe during zoomies.
@export var zoomies_camera_tilt_degrees: float = 6.0
## Field-of-view widens while sprinting for a sense of speed.
@export var zoomies_fov_boost: float = 12.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var cat_model: Node3D = $CatModel
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## False while driving — the cat ignores input and stays hidden.
var is_controlled: bool = true
## Set by a car's DoorZone when the cat is standing close enough to hop in.
var nearby_car: GetawayCar = null
## Items (see scripts/items/): weapons set this while firing, so the cat turns to face the shot.
var aim_until: float = 0.0
## Set by the item system while a held item wants the over-the-shoulder camera.
var shoulder_view: bool = false
## Catnip etc.: speed multiplier and how long it lasts (see start_boost).
var speed_boost: float = 1.0
var _boost_time_left: float = 0.0
## Catdip: extra jumps allowed in mid-air while it lasts (see start_double_jump).
var air_jumps: int = 0
var _air_jumps_left: int = 0
var _air_jump_time_left: float = 0.0
## Owner only: true while knocked out (0 HP, see cat_health.gd). The cat flops onto its side
## and ignores the keyboard until it wakes up in the sewers.
var knocked_out: bool = false

var _base_fov: float

## Fur colours handed out to each player so cats are easy to tell apart.
const FUR_COLORS: Array[Color] = [
	Color(0.95, 0.55, 0.2),   # ginger (always the host)
	Color(0.55, 0.56, 0.62),  # grey
	Color(0.95, 0.9, 0.8),    # cream
	Color(0.22, 0.2, 0.26),   # black
	Color(0.85, 0.72, 0.4),   # tabby gold
]


# --- MULTIPLAYER ---
# Every computer has a copy of every cat. Each cat node is named after its
# PLAYER ID (scripts/player_id.gd; the host's first player = "1"), and only the
# computer that player sits at is its "authority": it reads the keyboard and moves
# the cat. It writes where the cat is into sync_position / sync_model_rotation,
# which the MultiplayerSynchronizer sends to everyone else. Their copies then GLIDE
# toward those values every frame instead of jumping, so other players' cats move smoothly.
# One computer can own several cats (split screen): each has its own SLOT (0 = first player).

## This cat's player ID (= its node name). See scripts/player_id.gd.
var player_id: int = 0
## Which player on its computer: 0 = the first one, 1 = the second (split screen)...
var slot: int = 0

## The name floating above this cat. Chosen by its owner in the lobby, sent to everyone.
var player_name: String = "":
	set(value):
		player_name = value.strip_edges().left(12)
		if is_node_ready():
			_update_name_tag()

## How this cat looks (colours + accessories), made in the CHOOSE YOUR CAT screen. A CatLook
## dictionary (scripts/cat/cat_look.gd). The owner sets it from Settings.current_cat(); the synchronizer
## sends it to everyone, and setting it re-dresses the model on every computer.
var look: Dictionary = {}:
	set(value):
		look = CatLook.clean(value)
		if is_node_ready():
			_apply_look()

## Where the owner says this cat is. Sent over the network.
var sync_position: Vector3
## How the owner's cat model is turned/leaning. Sent over the network.
var sync_model_rotation: Vector3

@export_group("Sounds")
## Seconds between footsteps at walking speed (faster running = quicker steps).
## The sound is any sounds/sfx/footstep_N.wav file.
@export var footstep_interval: float = 0.32
## Footstep loudness in decibels (0 = the file's own volume, -6 = about half).
@export var footstep_volume_db: float = -8.0
## Shortest time between two meows (seconds), so holding M doesn't spam everyone.
@export var meow_cooldown: float = 0.5

var _step_timer: float = 0.0
var _step_last_position: Vector3
var _next_meow_at: float = 0.0

@export_group("Network Smoothing")
## How quickly other players' cats catch up to their real position.
## Higher = snappier but choppier, lower = smoother but slightly behind.
@export var network_smoothing: float = 15.0
## If a cat is further than this from where it should be, jump there instantly
## (e.g. after getting out of a car) instead of sliding across the map.
@export var teleport_distance: float = 4.0


func _enter_tree() -> void:
	if name.is_valid_int():
		player_id = name.to_int()
		slot = PlayerId.slot_of(player_id)
		set_multiplayer_authority(PlayerId.peer_of(player_id))  # the computer this player sits at


## True if someone at THIS computer steers this cat: our first player (keyboard, mouse and a
## controller), or a couch player who joined in with their own controller (scripts/seats.gd).
## Every button this cat reads is its SEAT's: Seats.is_pressed(slot, "jump") etc.
func reads_input() -> bool:
	return is_multiplayer_authority() and Seats.taken[slot]


func _ready() -> void:
	# FIELD OF VIEW comes from the Settings menu (the Camera3D's own fov is ignored).
	_base_fov = Settings.field_of_view
	camera.fov = _base_fov
	Settings.changed.connect(_on_settings_changed)
	# Stop the spring arm from "hitting" the cat's own collision and zooming in.
	spring_arm.add_excluded_object(get_rid())
	_apply_look()

	if is_multiplayer_authority():
		# One of OUR cats: its name and look come from the player sitting at this slot
		# (game.gd local_player_info); the synchronizer shares them with everyone.
		var info := Game.instance.local_player_info(slot)
		player_name = info.get("name", "")
		look = info.get("look", {})
		if slot == 0:
			# Our first player's cat: its camera is the main screen's, and it gets the mouse.
			# (Couch players 2-4 see through a copy of their cat's camera on their own part of
			# the screen: scripts/ui/game_screen.gd.)
			camera.make_current()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			# (Your own name isn't shown on YOUR screen: hud_name_tags.gd skips it. Couch
			# players next to you still see it on theirs.)
		# Start in the sewers. The OWNER places its own cat here: the host's spawn spot
		# doesn't reach a joining player (the network only sends a new cat's starting
		# values when the host owns it), so without this a joiner would start up top.
		teleport_to(UndergroundHub.instance.spawn_position(get_index()), 0.0)
		# (_process does the controller's right-stick camera for our own cat.)
	else:
		# Someone else's cat: no input, no physics — _process glides it to the synced spot.
		set_physics_process(false)
		set_process_unhandled_input(false)
		_update_name_tag()
		# Joined while this cat was already in a car? Hide it now.
		for node in get_tree().get_nodes_in_group("cars"):
			var car := node as GetawayCar
			if car.driver_id == player_id:
				enter_car(car)


## Our own cat: turn the camera with the controller's right stick.
## Other players' cats: ease toward the latest position from the network.
func _process(delta: float) -> void:
	if is_multiplayer_authority():
		_stick_look(delta)
		return
	var weight := 1.0 - exp(-network_smoothing * delta)
	if position.distance_to(sync_position) > teleport_distance:
		position = sync_position
	else:
		position = position.lerp(sync_position, weight)
	cat_model.rotation.x = lerp_angle(cat_model.rotation.x, sync_model_rotation.x, weight)
	cat_model.rotation.y = lerp_angle(cat_model.rotation.y, sync_model_rotation.y, weight)
	cat_model.rotation.z = lerp_angle(cat_model.rotation.z, sync_model_rotation.z, weight)  # knocked-out flop
	_update_footsteps(delta, false)


## Owner only: go faster for a while (catnip). Counts as zoomies for the camera effects.
func start_boost(multiplier: float, seconds: float) -> void:
	speed_boost = multiplier
	_boost_time_left = seconds


## Owner only: allow extra jumps in mid-air for a while (catdip). extra = 1 is a double jump.
func start_double_jump(extra: int, seconds: float) -> void:
	air_jumps = extra
	_air_jumps_left = extra
	_air_jump_time_left = seconds


## The player changed a setting: pick up the new field of view.
## (While walking, _update_zoomies_juice eases the camera to it; in the car, set it directly.)
func _on_settings_changed() -> void:
	_base_fov = Settings.field_of_view
	if not is_controlled:
		camera.fov = _base_fov
	# Changed our cat in the MY CAT screen (from the pause menu): wear it, and share it.
	if is_multiplayer_authority() and slot == 0:
		var my_cat := Settings.current_cat()
		if look != CatLook.clean(my_cat.get("look", {})):
			look = my_cat.get("look", {})
		if player_name != str(my_cat.get("name", player_name)).strip_edges().left(12):
			Game.local_player_name = my_cat.get("name", "")
			player_name = Game.local_player_name


## Show the chosen name, or a stand-in if the player left the name box empty.
func _update_name_tag() -> void:
	if not player_name.is_empty():
		$NameTag.text = player_name
	else:
		$NameTag.text = "HOST" if name == "1" else "CAT " + name.right(3)


## Dress the model in our look. A player who never used the MY CAT screen gets a fur colour
## from FUR_COLORS picked by their network ID, so cats are still easy to tell apart.
func _apply_look() -> void:
	var index := 0 if player_id <= 1 else 1 + player_id % (FUR_COLORS.size() - 1)
	CatLook.apply(cat_model, {"fur": FUR_COLORS[index]}.merged(look, true))


func _unhandled_input(event: InputEvent) -> void:
	# Esc opens the pause menu (see game.gd), which frees the mouse.
	# If the mouse got freed some other way (e.g. alt-tab), clicking the game grabs it again.
	if _menu_open() or not reads_input():
		return
	if slot == 0 and event is InputEventMouseButton and event.pressed:  # (the mouse is player 1's)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if not is_controlled:
		return
	if knocked_out and not event is InputEventMouseMotion:
		return  # seeing stars: you can look around, but not grab, drop or talk

	# Mouse look: left/right turns the pivot, up/down tilts the spring arm.
	# MOUSE SPEED and INVERT MOUSE Y come from the Settings menu.
	if slot == 0 and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := mouse_sensitivity * Settings.mouse_speed
		var pitch_sign := -1.0 if Settings.invert_y else 1.0
		camera_pivot.rotate_y(-event.relative.x * sensitivity)
		spring_arm.rotation.x = clamp(
			spring_arm.rotation.x - event.relative.y * sensitivity * pitch_sign,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)
	elif Seats.event_is(slot, event, "interact") and ItemManager.instance.try_interact(self):
		# Grabbed an item lying here (the host decides). Items come before the car,
		# so E near both picks up the item first.
		get_viewport().set_input_as_handled()
	elif Seats.event_is(slot, event, "drop"):
		ItemManager.instance.drop_from(self)
	elif Seats.event_is(slot, event, "meow") and Time.get_ticks_msec() / 1000.0 >= _next_meow_at:
		# Everyone nearby hears it (sounds/sfx/meow_1.wav, meow_2.wav... a random one each time).
		_next_meow_at = Time.get_ticks_msec() / 1000.0 + meow_cooldown
		Sound.play_everywhere("meow", global_position)
	elif Seats.event_is(slot, event, "interact") and Npc.try_talk(self):
		# Standing next to an NPC (e.g. Don Catleone in the hub): the talk box opens.
		get_viewport().set_input_as_handled()
	elif Seats.event_is(slot, event, "interact") and UndergroundHub.instance.near_stash(self):
		# At THE STASH lockers in the sewers: the inventory opens with your stash in it.
		InventoryScreen.for_seat(slot).open(self)
		get_viewport().set_input_as_handled()
	elif Seats.event_is(slot, event, "interact") and nearby_car != null:
		# Ask the host for the keys — it decides, so two cats can't grab the car at once.
		nearby_car.request_enter.rpc_id(1, player_id)
		# Mark the E press as used so the car doesn't instantly treat it as "exit".
		get_viewport().set_input_as_handled()


## Controller camera: the right stick (LOOK UP / DOWN / LEFT / RIGHT in SETTINGS > KEYS) turns
## the camera like the mouse does. Gentle near the middle (for aiming), fast at full tilt.
## STICK SPEED and INVERT STICK Y come from SETTINGS > CONTROLS.
func _stick_look(delta: float) -> void:
	if not is_controlled or not reads_input() or _menu_open() or _pad_in_inventory():
		return
	var stick := Seats.get_vector(slot, "look_left", "look_right", "look_up", "look_down")
	if stick == Vector2.ZERO:
		return
	stick *= stick.length()  # response curve: half tilt = quarter speed
	var turn := stick_turn_speed * Settings.stick_speed * delta
	var pitch_sign := -1.0 if Settings.invert_stick_y else 1.0
	camera_pivot.rotate_y(-stick.x * turn)
	spring_arm.rotation.x = clamp(
		spring_arm.rotation.x - stick.y * turn * stick_pitch_ratio * pitch_sign,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)


func _physics_process(delta: float) -> void:
	if not is_controlled:
		return

	# Gravity: fall when not standing on something.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Catdip wears off over time; landing refills the mid-air jumps.
	_air_jump_time_left = maxf(_air_jump_time_left - delta, 0.0)
	if _air_jump_time_left <= 0.0:
		air_jumps = 0
	if is_on_floor():
		_air_jumps_left = air_jumps

	# Jump (or, with catdip, jump again in mid-air). No keyboard while a menu is open.
	if Seats.is_just_pressed(slot, "jump") and not _input_blocked():
		if is_on_floor():
			velocity.y = jump_velocity
			Sound.play_everywhere("jump", global_position, -6.0)
		elif _air_jumps_left > 0:
			velocity.y = jump_velocity
			_air_jumps_left -= 1
			Sound.play_everywhere("jump", global_position, -6.0)

	# Read WASD (or the controller's left stick) as a 2D direction (x = left/right, y = forward/back).
	# The stick is analog: push it halfway and the cat walks at half speed.
	var input_dir := Seats.get_vector(slot, "move_left", "move_right", "move_forward", "move_back")
	if _input_blocked():
		input_dir = Vector2.ZERO

	# Convert it so "forward" means "where the camera is looking", flattened onto the ground.
	var cam_basis := camera_pivot.global_transform.basis
	var direction := cam_basis.x * input_dir.x + cam_basis.z * input_dir.y
	direction.y = 0.0
	direction = direction.normalized()  # (how far the stick is pushed is put back below)

	# Catnip (or any boost) wears off over time.
	_boost_time_left = maxf(_boost_time_left - delta, 0.0)
	if _boost_time_left <= 0.0:
		speed_boost = 1.0

	# Zoomies = holding Shift while actually moving (or being boosted).
	var is_zooming := (Seats.is_pressed(slot, "sprint") or speed_boost > 1.0) and direction != Vector3.ZERO
	var target_speed := zoomies_speed if is_zooming else walk_speed
	# HEAVY loot (the golden koi) slows you down: see ItemData.carry_speed.
	var heavy := ItemManager.instance.carry_speed(player_id) if ItemManager.instance != null else 1.0
	var target_velocity := direction * minf(input_dir.length(), 1.0) * target_speed * speed_boost * heavy

	# Ease horizontal speed toward the target (smooth start/stop, same feel at any frame rate).
	var weight := 1.0 - exp(-acceleration * delta)
	velocity.x = lerp(velocity.x, target_velocity.x, weight)
	velocity.z = lerp(velocity.z, target_velocity.z, weight)

	move_and_slide()

	# Smoothly turn the cat model to face where it's going. (Godot's "forward" is -Z.)
	# While firing a weapon, face where the camera looks instead, so the gun points at the target.
	var is_aiming := Time.get_ticks_msec() / 1000.0 < aim_until
	if is_aiming:
		cat_model.rotation.y = lerp_angle(cat_model.rotation.y, camera_pivot.rotation.y, 1.0 - exp(-turn_speed * 2.0 * delta))
	elif direction != Vector3.ZERO:
		var target_yaw := atan2(-direction.x, -direction.z)
		cat_model.rotation.y = lerp_angle(cat_model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	_update_zoomies_juice(is_zooming, input_dir.x, delta)
	# Knocked out: flop over onto its side (and back up when it wakes).
	cat_model.rotation.z = lerp(cat_model.rotation.z, PI / 2.0 if knocked_out else 0.0, 1.0 - exp(-10.0 * delta))

	# Publish where we are for the other players.
	sync_position = position
	sync_model_rotation = cat_model.rotation
	_update_footsteps(delta, is_on_floor())


## Pitter-patter. Every computer does this for every cat it can see (our own cat from
## _physics_process, other players' cats from _process), working out how fast the cat moves
## from how far it went - so footsteps need no network messages at all.
## on_floor: our own cat knows for sure; for other cats we guess "not going up or down".
func _update_footsteps(delta: float, on_floor: bool) -> void:
	var moved := position - _step_last_position
	_step_last_position = position
	var speed := Vector2(moved.x, moved.z).length() / maxf(delta, 0.0001)
	var grounded := on_floor if is_multiplayer_authority() else absf(moved.y / maxf(delta, 0.0001)) < 1.0
	# Standing still, in the air, in the car, or a teleport (a huge one-frame "speed"): no steps.
	if not grounded or not visible or knocked_out or speed < 1.0 or speed > 30.0:
		_step_timer = 0.0  # so the first step comes straight away when walking starts
		return
	_step_timer -= delta * speed / walk_speed
	if _step_timer <= 0.0:
		_step_timer = footstep_interval
		Sound.play_at("footstep", global_position, footstep_volume_db)


## True while a menu or the hub talk box is up: the cat ignores the keyboard then.
func _menu_open() -> bool:
	return PauseMenu.is_open or NpcDialog.is_open_for(slot)


## True when the cat shouldn't move from the keyboard: a menu is open, or it's knocked out.
## (Also while a controller player has the inventory open: their stick and A button are
## moving around the inventory then, not the cat. And for a split-screen cat with no
## controller yet: see reads_input.)
func _input_blocked() -> bool:
	return _menu_open() or knocked_out or _pad_in_inventory() or not reads_input()


func _pad_in_inventory() -> bool:
	var inventory := InventoryScreen.for_seat(slot)
	return inventory != null and inventory.visible and Seats.uses_pad(slot)


## Owner only: jump this cat somewhere else in the world (hub <-> city), facing "yaw".
## Other players' copies see a big jump in sync_position and snap there (teleport_distance).
func teleport_to(where: Vector3, yaw: float) -> void:
	global_position = where
	velocity = Vector3.ZERO
	camera_pivot.rotation.y = yaw
	cat_model.rotation.y = yaw
	sync_position = position
	sync_model_rotation = cat_model.rotation


## Lean the cat, roll the camera and widen the FOV while sprinting; ease back otherwise.
func _update_zoomies_juice(is_zooming: bool, strafe: float, delta: float) -> void:
	var weight := 1.0 - exp(-8.0 * delta)
	var lean := deg_to_rad(zoomies_lean_degrees) if is_zooming else 0.0
	var tilt := -strafe * deg_to_rad(zoomies_camera_tilt_degrees) if is_zooming else 0.0
	var fov := _base_fov + zoomies_fov_boost if is_zooming else _base_fov

	cat_model.rotation.x = lerp(cat_model.rotation.x, -lean, weight)
	camera.rotation.z = lerp(camera.rotation.z, tilt, weight)
	camera.fov = lerp(camera.fov, fov, weight)
	# Over-the-shoulder view while holding a weapon that asks for it. (We slide the whole
	# spring arm, because a SpringArm3D always puts its camera back on its own centre line.)
	spring_arm.position.x = lerp(spring_arm.position.x, gun_shoulder_offset if shoulder_view else 0.0, weight)


## Someone's weapon hit this cat. Sent to the cat's OWNER, who shoves it (owner moves its cat).
@rpc("any_peer", "call_local", "unreliable")
func get_zapped(push: Vector3) -> void:
	if not is_multiplayer_authority() or not is_controlled:
		return
	velocity.x += push.x
	velocity.z += push.z
	velocity.y = maxf(velocity.y, push.y)  # a little hop, but never cancel a jump


## Called by the car on EVERY computer when this cat gets in.
## Everyone hides the cat; only the owner's computer hands its camera to the car.
func enter_car(car: GetawayCar) -> void:
	visible = false
	collision_shape.set_deferred("disabled", true)
	if not is_multiplayer_authority():
		return

	is_controlled = false
	velocity = Vector3.ZERO
	cat_model.rotation.x = 0.0
	camera.fov = _base_fov

	# Move the camera node under the car's camera arm.
	camera.reparent(car.camera_arm, false)
	camera.transform = Transform3D.IDENTITY
	if slot == 0:
		camera.make_current()  # (players 2-4: game_screen.gd follows this camera wherever it is)


## Called by the car on EVERY computer when this cat gets out.
func exit_car(exit_position: Vector3) -> void:
	visible = true
	collision_shape.set_deferred("disabled", false)
	if not is_multiplayer_authority():
		return  # the owner moves it; the new position arrives via the synchronizer

	global_position = exit_position
	sync_position = position
	# Take the camera back.
	camera.reparent(spring_arm, false)
	camera.transform = Transform3D.IDENTITY
	if slot == 0:
		camera.make_current()
	is_controlled = true
