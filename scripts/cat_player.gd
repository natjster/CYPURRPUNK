class_name CatPlayer
extends CharacterBody3D
## CYPURRPUNK — third-person cat controller.
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

## Which gang this cat plays for this game (scripts/teams.gd: 0 = Catleone Family, 1 = Burrow
## Gang). The owner sets it from the landing-page pick; the synchronizer sends it to everyone.
## It decides which sewer the cat lives in (UndergroundHub.of) and its name colour.
var team: int = Teams.CATLEONE:
	set(value):
		team = value
		if is_node_ready():
			_update_name_tag()

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

@export_group("Running Animation")
## How far the legs swing forward/back at full running speed (radians, 0.6 = about 35 degrees).
@export var leg_swing: float = 0.6
## Leg swings per second at walking speed (running faster = quicker steps).
@export var leg_swing_speed: float = 2.2
## How far the tail sways side to side (radians). Same idea as an NPC's Tail Swish.
@export var tail_swish: float = 0.35
## Tail sways per second while standing still (NPC cats use 1.6).
@export var tail_idle_speed: float = 1.6
## Extra tail sway speed per metre-per-second of running: the faster you go, the faster it swishes.
@export var tail_speed_per_mps: float = 0.9

var _leg_l: Node3D
var _leg_r: Node3D
var _tail: Node3D
var _leg_l_home: Vector3  # where each leg sits in cat_model.tscn (we swing them from the hip)
var _leg_r_home: Vector3
var _tail_home_z: float
var _tail_base: Vector3  # the tail's root on the cat's bum (set in _ready)
const TAIL_HALF_LENGTH := 0.225  # half of Mesh_tail's height (0.45) in cat_model.tscn
var _leg_phase: float = 0.0
var _tail_phase: float = 0.0
var _leg_amount: float = 0.0  # 0 = legs still, 1 = full swing (eases in and out)

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


## For the floating health bars over OTHER players' heads (scripts/ui/hud_health_bars.gd):
## a slim cyan bar just under the name, only once this cat is hurt. (Your own health is the big
## bar top-left of your HUD instead.)
## DOWNED: the bar shows the bleed-out time draining instead, with "DOWNED" over it, and it's
## seen from far away and through walls so friends can find you. While a friend revives you,
## the REVIVE METER fills it ("progress").
func health_bar_info() -> Dictionary:
	var health := CatHealth.instance
	if health == null:
		return {}
	if health.is_downed(player_id):
		var robbed := health.is_being_robbed(player_id)
		var label := "DOWNED %d" % ceili(health.bleed_out_left(player_id))
		if health.reviver_of(player_id) != 0:
			label = "BEING ROBBED!" if robbed else "REVIVING..."
		var info := {"hp": health.bleed_out_left(player_id), "max": health.bleed_out_seconds,
			"position": global_position + Vector3.UP * 1.0, "show": true, "name": label,
			"progress": health.revive_progress(player_id),
			"see_from": health.downed_seen_from, "through_walls": true}
		if robbed:
			info["progress_color"] = Color(1, 0.25, 0.2)  # a rival's robbery fills it red
		return info
	var hp := health.get_health(player_id)
	return {"hp": hp, "max": health.max_health, "position": global_position + Vector3.UP * 1.3,
		"show": hp < health.max_health, "name": ""}


## True while this cat is DOWNED (0 HP, waiting for a teammate: scripts/cat_health.gd).
## It can only crawl and meow.
func is_downed() -> bool:
	return CatHealth.instance != null and CatHealth.instance.is_downed(player_id)


## The name everyone sees over this cat (a stand-in like "CAT 123" if the player left it empty).
func display_name() -> String:
	return $NameTag.text


# --- A DOWNED cat is something other cats can use with E (scripts/interactable.gd) ---
# Your own gang: "HOLD: REVIVE <NAME>". The other gang: "HOLD: ROB <NAME>" (their loot bag).
# (The rules are all in cat_health.gd.)

func interact_distance(helper: CatPlayer) -> float:
	return CatHealth.instance.downed_distance(self, helper) if CatHealth.instance != null else -1.0


func interact_prompt(helper: CatPlayer) -> String:
	return CatHealth.instance.downed_prompt(self, helper)


func interact(helper: CatPlayer) -> void:
	CatHealth.instance.start_hold(self, helper)


func interact_priority() -> int:
	return 40  # beats items (30): picking up a friend (or robbing a rival) comes first


func _ready() -> void:
	# FIELD OF VIEW comes from the Settings menu (the Camera3D's own fov is ignored).
	_base_fov = Settings.field_of_view
	camera.fov = _base_fov
	Settings.changed.connect(_on_settings_changed)
	# Stop the spring arm from "hitting" the cat's own collision and zooming in.
	spring_arm.add_excluded_object(get_rid())
	_apply_look()
	# The leg and tail meshes from scenes/cat_model.tscn (animated in _animate_legs_and_tail).
	_leg_l = cat_model.get_node_or_null("LegL")
	_leg_r = cat_model.get_node_or_null("LegR")
	_tail = cat_model.get_node_or_null("Tail")
	if _leg_l != null:
		_leg_l_home = _leg_l.position
	if _leg_r != null:
		_leg_r_home = _leg_r.position
	if _tail != null:
		_tail_home_z = _tail.rotation.z
		# Where the tail's thick end joins the body: the sway hinges here so it stays put.
		_tail_base = _tail.position + _tail.basis * (Vector3.DOWN * TAIL_HALF_LENGTH)
	add_to_group(HudHealthBars.GROUP)  # other players see a slim health bar over us once we're hurt
	add_to_group(Interactable.GROUP)  # teammates can revive us with E while we're downed

	if is_multiplayer_authority():
		# One of OUR cats: its name and look come from the player sitting at this slot
		# (game.gd local_player_info); the synchronizer shares them with everyone.
		var info := Game.instance.local_player_info(slot)
		player_name = info.get("name", "")
		look = info.get("look", {})
		team = int(info.get("team", Teams.CATLEONE))
		_update_name_tag()  # (couch players next to us see our tag in our gang's colour)
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
		teleport_to(UndergroundHub.of(self).free_spawn_position(self), 0.0)  # OUR gang's sewer
		# (_process does the controller's right-stick camera for our own cat.)
	else:
		# Someone else's cat: no input, no physics — _process glides it to the synced spot.
		set_physics_process(false)
		set_process_unhandled_input(false)
		_update_name_tag()
		# No position from its owner yet? Stay where we were made (down in the sewers) until it
		# arrives. Otherwise the copy jumps to (0, 0, 0) - the middle of the CITY - for a moment,
		# and the host would think a player who just joined had already been up top (their one
		# trip used up: fish_heist.gd went_up), and Roombas could chase a cat that isn't there.
		if sync_position == Vector3.ZERO:
			sync_position = position
		# Joined while this cat was already in a car? Hide it now.
		for node in get_tree().get_nodes_in_group("cars"):
			var car := node as GetawayCar
			if car.has_occupant(player_id):  # driving or riding along
				enter_car(car)


## Our own cat: turn the camera with the controller's right stick.
## Other players' cats: ease toward the latest position from the network.
func _process(delta: float) -> void:
	if is_multiplayer_authority():
		_stick_look(delta)
		return
	var weight := Motion.glide_weight(network_smoothing, delta)
	position = Motion.glide(position, sync_position, weight, teleport_distance)
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
	# (Player 1 plays Settings' current cat; couch players 2-4 their own saved cat.)
	if is_multiplayer_authority():
		var my_cat := Settings.current_cat() if slot == 0 else Seats.saved_cat(slot)
		if my_cat.is_empty():
			return
		if look != CatLook.clean(my_cat.get("look", {})):
			look = my_cat.get("look", {})
		if player_name != str(my_cat.get("name", player_name)).strip_edges().left(12):
			player_name = str(my_cat.get("name", "")).strip_edges().left(12)
			if slot == 0:
				Game.local_player_name = my_cat.get("name", "")
		if slot > 0 and Game.instance.extra_local_players.has(slot):
			# Keep game.gd's note of this couch player up to date too.
			Game.instance.extra_local_players[slot]["look"] = my_cat.get("look", {})
			Game.instance.extra_local_players[slot]["name"] = player_name


## Show the chosen name, or a stand-in if the player left the name box empty.
## It's drawn in the cat's GANG colour (scripts/teams.gd), so you can tell friend from rival.
func _update_name_tag() -> void:
	$NameTag.modulate = Color(Teams.color_of(team), 0.9)
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
	elif Seats.event_is(slot, event, "interact") and Interactable.try_use(self):
		# Used the best thing in reach: grab an item, talk to an NPC or payphone, open the stash,
		# get in the car... (scripts/interactable.gd). Marking the press as used also stops the
		# car from treating the same E as "get out" straight away.
		get_viewport().set_input_as_handled()
	elif Seats.event_is(slot, event, "drop") and not is_downed():  # (downed: hold on to your loot!)
		ItemManager.instance.drop_from(self)
	elif Seats.event_is(slot, event, "meow") and Time.get_ticks_msec() / 1000.0 >= _next_meow_at:
		# Everyone nearby hears it (sounds/sfx/meow_1.wav, meow_2.wav... a random one each time).
		_next_meow_at = Time.get_ticks_msec() / 1000.0 + meow_cooldown
		Sound.play_everywhere("meow", global_position)


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
	var turn := stick_turn_speed * Seats.stick_speed(slot) * delta  # this player's own STICK SPEED
	var pitch_sign := -1.0 if Seats.invert_stick_y(slot) else 1.0
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

	# DOWNED cats can only crawl: no jumping, no zoomies (Downed and Revives on the Health node).
	var downed := is_downed()

	# Jump (or, with catdip, jump again in mid-air). No keyboard while a menu is open.
	if Seats.is_just_pressed(slot, "jump") and not _input_blocked() and not downed:
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
	var is_zooming := (Seats.is_pressed(slot, "sprint") or speed_boost > 1.0) and direction != Vector3.ZERO and not downed
	var target_speed := zoomies_speed if is_zooming else walk_speed
	if downed:
		target_speed = walk_speed * CatHealth.instance.crawl_speed
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
	# Downed / knocked out: flop over onto its side (and back up when revived or it wakes).
	cat_model.rotation.z = lerp(cat_model.rotation.z, PI / 2.0 if knocked_out or downed else 0.0, 1.0 - exp(-10.0 * delta))

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
	_animate_legs_and_tail(delta, speed if speed <= 30.0 else 0.0, grounded)
	# Standing still, in the air, in the car, or a teleport (a huge one-frame "speed"): no steps.
	if not grounded or not visible or knocked_out or speed < 1.0 or speed > 30.0:
		_step_timer = 0.0  # so the first step comes straight away when walking starts
		return
	_step_timer -= delta * speed / walk_speed
	if _step_timer <= 0.0:
		_step_timer = footstep_interval
		Sound.play_at("footstep", global_position, footstep_volume_db)


## Legs swing back and forth while running (left and right opposite, like walking), and the
## tail sways side to side all the time - slowly when standing, faster the faster the cat runs.
## Worked out from speed alone, so every computer animates every cat with no network messages.
## Tuning: the "Running Animation" group in the Player's Inspector.
func _animate_legs_and_tail(delta: float, speed: float, grounded: bool) -> void:
	# Legs: ease the swing in when running on the ground, out when stopped or in the air.
	var running := grounded and speed > 0.5 and not knocked_out
	_leg_amount = move_toward(_leg_amount, clampf(speed / walk_speed, 0.0, 1.0) if running else 0.0,
		delta * 6.0)
	_leg_phase += delta * TAU * leg_swing_speed * maxf(speed / walk_speed, 0.6)
	var swing := sin(_leg_phase) * leg_swing * _leg_amount
	_swing_leg(_leg_l, _leg_l_home, swing)
	_swing_leg(_leg_r, _leg_r_home, -swing)
	# Tail: always swaying, faster with speed.
	_tail_phase += delta * (tail_idle_speed + speed * tail_speed_per_mps)
	if _tail != null:
		_tail.rotation.z = _tail_home_z + sin(_tail_phase) * tail_swish
		# Turn around the tail's root, not its middle: slide it so the root stays centred on
		# the body and only the tip swings side to side.
		_tail.position = _tail_base - _tail.basis * (Vector3.DOWN * TAIL_HALF_LENGTH)


## Turn one leg by `angle`, hinging at its top (the hip) instead of its middle, so the paw
## swings forward and back while the top stays tucked under the body.
func _swing_leg(leg: Node3D, home: Vector3, angle: float) -> void:
	if leg == null:
		return
	var half := 0.1  # half the leg's height (Mesh_leg is 0.2 tall in cat_model.tscn)
	var hip := home + Vector3.UP * half
	leg.position = hip + Vector3.DOWN.rotated(Vector3.RIGHT, angle) * half
	leg.rotation.x = angle


## True while a menu or the hub talk box is up: the cat ignores the keyboard then.
## (Split screen: only THIS player's talk box / pause menu counts; the big pause menu stops everyone.)
func _menu_open() -> bool:
	return PauseMenu.is_open or NpcDialog.is_open_for(slot) or PlayerPause.is_open_for(slot)


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
## The hit framework (scripts/hit.gd): another cat's bolt hit us. Runs on the SHOOTER's
## computer; our OWN computer moves us, so ask it to do the shove. (No damage number.)
func receive_hit(hit: Hit) -> bool:
	# Our OWN gang's bolts do nothing at all (friendly fire is off: scripts/teams.gd).
	if hit.shooter != null and hit.shooter.team == team:
		return false
	# The other gang (or a test with no shooter): a shove...
	get_zapped.rpc_id(get_multiplayer_authority(), hit.direction * hit.weapon.cat_knockback + Vector3.UP * hit.weapon.cat_hop)
	if hit.shooter == null or CatHealth.instance == null or UndergroundHub.is_in_hub(global_position):
		return false
	# ...and real damage: the host checks the shot and takes the HP off (cat_health.gd).
	var standing := CatHealth.instance.get_health(player_id) > 0  # (asked BEFORE: on the host it's instant)
	CatHealth.instance.request_shot.rpc_id(1, hit.shooter.player_id, player_id, hit.damage)
	return standing  # a damage number, unless they were already down


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
