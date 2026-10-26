class_name Roomba
extends CharacterBody3D
## VAC-COP — a police Roomba that patrols the city and hunts cats on foot.
## Attach to the root of scenes/roomba.tscn. Expected node tree:
##   Roomba (CharacterBody3D)       <- this script
##   ├── CollisionShape3D
##   ├── Model (Node3D)             <- turns to face where it drives
##   │   ├── Body, Cap, Bumper      <- MeshInstance3D (Body flashes when shot)
##   │   ├── Eye                    <- glows red while chasing
##   │   ├── SirenRed, SirenBlue    <- flash while chasing
##   │   └── Brush (Node3D)         <- the little side brush, spins
##   ├── SirenLight (OmniLight3D)   <- red/blue light on the street while chasing
##   └── MultiplayerSynchronizer    <- shares sync_position, sync_yaw, state
##
## What it does:
##   PATROL  — drives slowly between random sidewalk spots.
##   CHASE   — spots a cat on foot within sight_range and drives at it (faster than a walking
##             cat, slower than zoomies — so SHIFT saves you).
##   BONK    — touching a cat knocks it flying, VACUUMS UP one piece of loot from its bag and
##             takes bonk_damage HP. A cat at 0 HP is knocked out and drops everything
##             (cat_health.gd). Then the Roomba backs off for a moment (STUNNED).
##   Shoot it (max_health hits) or ram it with the car (faster than car_smash_speed) and it
##   explodes, spitting out everything it vacuumed.
## Cats in the car and cats down in the hub are ignored.
## Roombas sit on collision LAYER 2 (Inspector > CollisionObject3D > Collision > Layer) and
## only bump into layer 1 (the city). So cats and the car pass over them instead of getting
## stuck on them, and guns still hit them (bolts check every layer).
##
## MULTIPLAYER: the HOST runs every Roomba's brain (this script's _physics_process). Everyone
## else's copy just glides to the synced position, like other players' cats. Roombas are
## created by the host (roomba_patrol.gd) and copied to everyone by a MultiplayerSpawner.

enum State { PATROL, CHASE, STUNNED }

@export_group("Driving")
@export var patrol_speed: float = 2.2
## Cats walk at 4.5 and zoom at 9 (cat_player.gd), so 5.5 catches walkers but not zoomers.
@export var chase_speed: float = 5.5
## How quickly it turns (higher = twitchier).
@export var turn_speed: float = 5.0

@export_group("Hunting")
## Starts chasing a cat on foot closer than this (metres).
@export var sight_range: float = 14.0
## Gives up the chase when the cat gets further than this.
@export var lose_range: float = 22.0
## How close counts as touching a cat.
@export var bump_range: float = 1.0
## How hard a bonk knocks the cat (metres per second), and the little hop.
@export var bump_push: float = 10.0
@export var bump_hop: float = 4.5
## Seconds it backs off after a bonk (so it doesn't bonk the same cat 60 times a second).
@export var stun_seconds: float = 2.5
## Does a bonk vacuum one piece of loot out of the cat's bag?
@export var steals_loot: bool = true
## HP a bonk takes off the cat (cats have 3, see the Health node). At 0 the cat is knocked out
## and drops EVERYTHING it carries (cat_health.gd). 0 = bonks never hurt.
@export var bonk_damage: int = 1

@export_group("Toughness")
## Hits from any gun before it explodes.
@export var max_health: int = 3
## The getaway car smashes it if driving faster than this (m/s).
@export var car_smash_speed: float = 7.0

@export_group("Network Smoothing")
@export var network_smoothing: float = 12.0

## Synced to everyone: where the host says it is, which way it faces, and what it's doing.
var sync_position: Vector3
var sync_yaw: float
var state: State = State.PATROL

## Host only: health left, and the loot it has vacuumed (dropped when it explodes).
var health: int
var stomach: Array = []

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _target: Vector3
var _chase_id: int = 0
var _stun_left: float = 0.0
var _stuck_check_at: Vector3
var _stuck_time: float = 0.0
var _last_car_position: Vector3
var _clock: float = 0.0
var _flash_time: float = 0.0
## Sounds (every computer): the vacuum hum, and what we were doing last frame (to hear the siren
## start the moment a chase begins).
var _hum: AudioStreamPlayer3D
var _last_state: State = State.PATROL
var _rng := RandomNumberGenerator.new()  # patrol choices only — NOT the city's RNG

@onready var model: Node3D = $Model
@onready var body_mesh: MeshInstance3D = $Model/Body
@onready var eye: MeshInstance3D = $Model/Eye
@onready var siren_red: MeshInstance3D = $Model/SirenRed
@onready var siren_blue: MeshInstance3D = $Model/SirenBlue
@onready var brush: Node3D = $Model/Brush
@onready var siren_light: OmniLight3D = $SirenLight


func _ready() -> void:
	health = max_health
	sync_position = global_position
	_stuck_check_at = global_position
	_rng.randomize()
	_hum = Sound.attach_loop("roomba_hum", self, -12.0)  # sounds/sfx/roomba_hum.wav
	if is_multiplayer_authority():
		_last_car_position = Game.instance.car.global_position
		_pick_patrol_target()
	else:
		set_physics_process(false)  # only the host thinks; we just glide (see _process)


# --- The host's brain ---

func _physics_process(delta: float) -> void:
	_clock += delta
	if not is_on_floor():
		velocity.y -= gravity * delta

	if _smashed_by_car(delta):
		explode()
		return

	var move := Vector3.ZERO
	var speed := 0.0
	match state:
		State.STUNNED:
			_stun_left -= delta
			if _stun_left <= 0.0:
				state = State.PATROL
				_pick_patrol_target()
		State.PATROL:
			var cat := _find_cat_to_chase()
			if cat != null:
				_chase_id = cat.name.to_int()
				state = State.CHASE
			else:
				move = _flat(_target - global_position)
				speed = patrol_speed
				if move.length() < 1.5 or is_on_wall() or _is_stuck(delta):
					_pick_patrol_target()
		State.CHASE:
			var cat := Game.instance.cat_for(_chase_id)
			if not _can_chase(cat, lose_range):
				state = State.PATROL
				_pick_patrol_target()
			else:
				move = _flat(cat.global_position - global_position)
				speed = chase_speed
				if move.length() < bump_range:
					_bonk(cat)

	# Drive: ease toward the wanted velocity and turn to face where we're going.
	var wanted := move.normalized() * speed
	var weight := 1.0 - exp(-6.0 * delta)
	velocity.x = lerpf(velocity.x, wanted.x, weight)
	velocity.z = lerpf(velocity.z, wanted.z, weight)
	if wanted.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-wanted.x, -wanted.z), 1.0 - exp(-turn_speed * delta))
	move_and_slide()

	sync_position = global_position
	sync_yaw = model.rotation.y


## The nearest cat worth chasing, or null.
func _find_cat_to_chase() -> CatPlayer:
	var best: CatPlayer = null
	for node in Game.instance.players.get_children():
		var cat := node as CatPlayer
		if _can_chase(cat, sight_range) and (best == null or _flat(cat.global_position - global_position).length() < _flat(best.global_position - global_position).length()):
			best = cat
	return best


## A cat on foot (visible = not in the car), up in the city, not knocked out, within "reach" metres.
func _can_chase(cat: CatPlayer, reach: float) -> bool:
	return cat != null and cat.visible and not UndergroundHub.is_in_hub(cat.global_position) \
		and not CatHealth.instance.is_down(cat.name.to_int()) \
		and _flat(cat.global_position - global_position).length() < reach


## Knock the cat flying and vacuum one piece of loot out of its bag.
func _bonk(cat: CatPlayer) -> void:
	var peer_id := cat.name.to_int()
	var push := _flat(cat.global_position - global_position).normalized() * bump_push + Vector3.UP * bump_hop
	cat.get_zapped.rpc_id(peer_id, push)  # the cat's owner moves it
	Sound.play_everywhere("bonk", cat.global_position)
	if steals_loot:
		var item_id := ItemManager.instance.take_one_loot(peer_id)
		if item_id != "":
			stomach.append(item_id)
			_vacuumed.rpc_id(peer_id, (ItemManager.instance.catalog[item_id] as ItemData).display_name)
	# After the vacuuming, so a knockout drops whatever is left (the stolen one stays inside us).
	CatHealth.instance.damage(peer_id, bonk_damage, "A VAC-COP")
	print("[Roomba] %s bonked player %d (stomach: %s)" % [name, peer_id, stomach])
	state = State.STUNNED
	_stun_left = stun_seconds
	velocity = -push.normalized() * 3.0  # bounce back a little
	velocity.y = 0.0


## Host: did the getaway car just run us over? (The host's copy of the car may be frozen
## and gliding when someone else drives, so measure its speed from how far it moved.)
func _smashed_by_car(delta: float) -> bool:
	var car := Game.instance.car
	var car_speed := car.global_position.distance_to(_last_car_position) / maxf(delta, 0.001)
	_last_car_position = car.global_position
	return car.driver_id != 0 and car_speed > car_smash_speed and car_speed < 60.0 \
		and _flat(car.global_position - global_position).length() < 2.8


func _pick_patrol_target() -> void:
	# A random sidewalk spot not too far away, so it wanders its own neighbourhood.
	for attempt in 8:
		var spot := ItemManager.instance.random_sidewalk_spot(_rng)
		if _flat(spot - global_position).length() < 35.0:
			_target = spot
			return
	_target = global_position + Vector3(_rng.randf_range(-10, 10), 0, _rng.randf_range(-10, 10))


## Host: true if we've barely moved for 2 seconds (wedged on a corner).
func _is_stuck(delta: float) -> bool:
	_stuck_time += delta
	if _stuck_time < 2.0:
		return false
	var stuck := global_position.distance_to(_stuck_check_at) < 0.5
	_stuck_check_at = global_position
	_stuck_time = 0.0
	return stuck


# --- Getting hurt ---

## A bolt hit us. Sent to the host by the shooter's gun (weapon.gd).
@rpc("any_peer", "call_local", "reliable")
func take_hit() -> void:
	if not multiplayer.is_server() or health <= 0:
		return
	health -= 1
	_hit_flash.rpc()
	if health <= 0:
		explode()
		return
	# Angry now: chase whoever shot us (if they're on foot).
	var shooter := Game.instance.cat_for(multiplayer.get_remote_sender_id())
	if _can_chase(shooter, lose_range):
		_chase_id = shooter.name.to_int()
		state = State.CHASE


## Host: boom. Spit out everything we vacuumed, tell the patrol to send a new one later.
func explode() -> void:
	# Shot dead and run over in the same frame? Only blow up once (or two replacements come).
	if is_queued_for_deletion():
		return
	if health > 0:
		health = 0
	for i in stomach.size():
		ItemManager.instance.drop_on_street(stomach[i], global_position + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 1.2)
	stomach.clear()
	Sound.play_everywhere("explode", global_position)
	print("[Roomba] %s exploded" % name)
	(get_parent() as RoombaPatrol).roomba_destroyed(global_position)
	queue_free()  # the spawner removes it on everyone's screen


# --- Messages from the host ---

@rpc("authority", "call_local", "unreliable")
func _hit_flash() -> void:
	_flash_time = 0.15
	Sound.play_at("roomba_hit", global_position)


## Host -> the bonked cat's owner: tell them what got vacuumed.
@rpc("authority", "call_local", "reliable")
func _vacuumed(display_name: String) -> void:
	Game.instance.show_message("A VAC-COP VACUUMED YOUR %s!  Smash it to get it back." % display_name, 3.0)


# --- Every computer: gliding (non-host) and the flashing lights ---

func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		var weight := 1.0 - exp(-network_smoothing * delta)
		if global_position.distance_to(sync_position) > 6.0:
			global_position = sync_position
		else:
			global_position = global_position.lerp(sync_position, weight)
		model.rotation.y = lerp_angle(model.rotation.y, sync_yaw, weight)

	brush.rotate_y(delta * 14.0)
	var chasing := state == State.CHASE
	# Sounds: a siren whoop when a chase starts, and the hum revs higher while chasing.
	if chasing and _last_state != State.CHASE:
		Sound.play_at("alert", global_position, -2.0)
	_last_state = state
	if _hum != null:
		_hum.pitch_scale = 1.4 if chasing else 1.0
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.4) < 0.2
	var off := Color(0.08, 0.08, 0.1)
	siren_red.set_instance_shader_parameter("instance_tint", Color(1, 0.1, 0.15) if chasing and blink else off)
	siren_blue.set_instance_shader_parameter("instance_tint", Color(0.15, 0.3, 1) if chasing and not blink else off)
	siren_light.visible = chasing
	siren_light.light_color = Color(1, 0.1, 0.15) if blink else Color(0.15, 0.3, 1)
	eye.set_instance_shader_parameter("instance_tint", Color(1, 0.1, 0.1) if chasing else Color(0.2, 0.9, 1))

	_flash_time = maxf(_flash_time - delta, 0.0)
	body_mesh.set_instance_shader_parameter("instance_tint", Color(3, 0.6, 0.6) if _flash_time > 0.0 else Color.WHITE)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)
