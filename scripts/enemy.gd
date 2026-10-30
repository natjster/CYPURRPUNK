class_name Enemy
extends CharacterBody3D
## THE ENEMY FRAMEWORK: everything every enemy shares. The VAC-COP (roomba.gd) is built on it;
## a new enemy script starts with "extends Enemy" and only writes its own BEHAVIOUR (how it
## moves and attacks). This script already handles:
##
##   - HEALTH: max_health, synced to everyone, a floating health bar once it's been shot
##     (health_bar_info, scripts/ui/hud_health_bars.gd).
##   - GETTING SHOT: receive_hit (the hit framework, hit.gd) -> take_hit on the host -> hit
##     flash + sound + heat; at 0 HP explode().
##   - GETTING RUN OVER by the getaway car: call run_over_by_car(delta) from your brain.
##   - EXPLODING: drops everything in "stomach" plus drop_on_destroy, adds heat (a boss cools
##     it instead), plays the sound, emits "destroyed" (the spawner listens), and is removed.
##   - NETWORK: the HOST runs the brain (_physics_process). Everyone else's copy glides to
##     sync_position / sync_yaw (turning the "Model" child node).
##
## A new enemy's scene needs (copy scenes/roomba.tscn as a start):
##   YourEnemy (CharacterBody3D)       <- your script ("extends Enemy")
##   ├── CollisionShape3D
##   ├── Model (Node3D)                <- the look; turns to face sync_yaw on other computers
##   │   └── Body (MeshInstance3D)     <- flashes when shot (change Flash Mesh to pick another)
##   └── MultiplayerSynchronizer       <- replicate: position (spawn only), sync_position,
##                                        sync_yaw, health (both "on change")
## and something on the host must spawn it under a MultiplayerSpawner (see roomba_patrol.gd).
##
## Writing your script (all optional, "super" = run the shared part first):
##   func _ready() -> void:            super() ... your setup
##   func _physics_process(delta):     the brain (host only); set sync_position / sync_yaw
##   func _process(delta) -> void:     super(delta) ... your animations (every computer)
##   func _on_hurt(shooter: CatPlayer): got shot but still alive (e.g. chase the shooter)
##   func _on_stunned(seconds: float):  a stun gun hit it (e.g. the YARN-ZOOKA)

## Every enemy joins this group, on every computer (the sewer NPCs look for targets in it).
const GROUP := "enemies"

## The most one hit may stun (seconds) or shove (metres per second) an enemy.
const MAX_STUN_SECONDS := 10.0
const MAX_PUSH := 40.0

## Host only: this enemy just blew up (before it's removed). The spawner listens to this.
signal destroyed(enemy: Enemy)

@export_group("Toughness")
## Health. Each bolt takes the gun's Damage (pistol ~40, tommy gun ~25: see the gun scenes).
@export var max_health: int = 100
## The name over its health bar.
@export var display_name: String = "VAC-COP"
## How high over its middle the health bar floats (metres; the boss's is higher).
@export var health_bar_height: float = 0.55
## The getaway car smashes it if driving faster than this (m/s). (999 = can't be run over.)
@export var car_smash_speed: float = 7.0
## How far from its middle the car counts as hitting it (metres).
@export var car_smash_radius: float = 2.8
## How much of a gun's Enemy Knockback it feels (1 = all of it, 0 = can't be shoved).
@export var knockback_taken: float = 1.0

@export_group("Boss")
## A boss: destroying it COOLS the heat instead of raising it (and the patrol sends no
## replacement). Also its health bar is the big gold one.
@export var is_boss: bool = false
## Item dropped on the street when it's destroyed, on top of whatever it vacuumed
## (e.g. "golden_koi" for the boss). "" = nothing extra.
@export var drop_on_destroy: String = ""

@export_group("Sounds")
## Sound files in res://sounds/sfx/ (without .wav).
@export var hit_sound: String = "roomba_hit"
@export var explode_sound: String = "explode"

@export_group("Look")
## The mesh that flashes when shot.
@export var flash_mesh: NodePath = ^"Model/Body"

@export_group("Network Smoothing")
## Other computers: how tightly our copy follows the host's (higher = tighter, jerkier).
@export var network_smoothing: float = 12.0
## Further off than this (metres) = jump instead of glide.
@export var snap_distance: float = 6.0

## Synced to everyone: where the host says it is and which way its Model faces.
var sync_position: Vector3
var sync_yaw: float
## Health left. The HOST changes it; the MultiplayerSynchronizer copies it to everyone (for the
## health bars).
var health: int = -1  # -1 = not set yet (a late joiner gets the host's number when it spawns)
## Host only: items inside it (the VAC-COP's vacuumed loot), dropped when it explodes.
var stomach: Array = []
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _flash_time: float = 0.0
## Host: where each car was last time we looked (car instance id -> position), to work out its speed.
var _last_car_positions := {}

## Host: the player who last hurt us (or ran us over). Read by the quests when we explode.
## 0 = nobody in particular.
var killed_by: int = 0

@onready var model: Node3D = get_node_or_null("Model")
@onready var _flash_mesh: MeshInstance3D = get_node_or_null(flash_mesh)


func _ready() -> void:
	if health < 0:
		health = max_health
	add_to_group(HudHealthBars.GROUP)  # a floating health bar on everyone's HUD
	add_to_group(GROUP)
	sync_position = global_position
	if model != null:
		sync_yaw = model.rotation.y
	if is_multiplayer_authority():
		for car in Game.instance.cars():
			_last_car_positions[car.get_instance_id()] = car.global_position
	else:
		set_physics_process(false)  # only the host thinks; we just glide (see _process)


## Every computer: glide (non-host copies) and the hit flash.
func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		var weight := Motion.glide_weight(network_smoothing, delta)
		global_position = Motion.glide(global_position, sync_position, weight, snap_distance)
		if model != null:
			model.rotation.y = lerp_angle(model.rotation.y, sync_yaw, weight)
	_flash_time = maxf(_flash_time - delta, 0.0)
	if _flash_mesh != null:
		_flash_mesh.set_instance_shader_parameter("instance_tint", Color(3, 0.6, 0.6) if _flash_time > 0.0 else Color.WHITE)


# --- Getting hurt ---

## The hit framework (hit.gd): a bolt hit us. Runs on the SHOOTER's computer, which sends the
## damage to the host (the host keeps score of enemy health). true = show a damage number.
func receive_hit(hit: Hit) -> bool:
	take_hit.rpc_id(1, hit.shooter_id(), hit.damage, hit.stun_seconds, hit.enemy_push, hit.city_heat)
	return true


## Host: take "amount" health off (sent by receive_hit above; the test tool calls it directly).
## shooter_id = the player who fired (0 = nobody in particular). stun = seconds stunned, push =
## shove, city_heat = how much of the usual heat this hit adds (see hit.gd).
@rpc("any_peer", "call_local", "reliable")
func take_hit(shooter_id: int = 0, amount: int = 34, stun: float = 0.0, push: Vector3 = Vector3.ZERO, city_heat: float = 1.0) -> void:
	if not multiplayer.is_server() or health <= 0:
		return
	health -= clampi(amount, 1, 500)  # (clamped: a broken / cheating client can't one-shot the boss)
	if PlayerId.sender_owns(shooter_id):
		killed_by = shooter_id
	_hit_flash.rpc()
	HeatMeter.instance.add_heat(HeatMeter.instance.heat_per_roomba_hit * clampf(city_heat, 0.0, 1.0))  # gunfire makes the city angry
	if health <= 0:
		explode()
		return
	# (Clamped too: a broken / cheating client can't freeze or fling an enemy for ever.)
	if stun > 0.0:
		_on_stunned(minf(stun, MAX_STUN_SECONDS))
	if push != Vector3.ZERO:
		_on_pushed(push.limit_length(MAX_PUSH) * knockback_taken)
	_on_hurt(Game.instance.cat_for(shooter_id) if PlayerId.sender_owns(shooter_id) else null)


## Host: shot but still alive. Override it to react (the VAC-COP chases whoever shot it).
## shooter = their cat, or null.
func _on_hurt(_shooter: CatPlayer) -> void:
	pass


## Host: a stun gun hit us and we're still alive. Override it to stop moving (the VAC-COP does).
func _on_stunned(_seconds: float) -> void:
	pass


## Host: a gun shoved us. Every enemy slides (and hops, if the push points up) by default.
func _on_pushed(push: Vector3) -> void:
	velocity += push


## Host: did a getaway car (any gang's) just run us over? Call it from your brain every physics
## frame. (The host's copy of a car may be frozen and gliding when someone else drives, so measure
## its speed from how far it moved.)
func run_over_by_car(delta: float) -> bool:
	var hit := false
	for car in Game.instance.cars():
		var id := car.get_instance_id()
		var last: Vector3 = _last_car_positions.get(id, car.global_position)
		var car_speed := car.global_position.distance_to(last) / maxf(delta, 0.001)
		_last_car_positions[id] = car.global_position
		if car.driver_id != 0 and car_speed > car_smash_speed and car_speed < 60.0 \
				and Motion.flat_distance(car.global_position, global_position) < car_smash_radius:
			hit = true
			killed_by = car.driver_id
	return hit


## Host: boom. Spit out everything inside, tell the spawner, disappear everywhere.
func explode() -> void:
	# Shot dead and run over in the same frame? Only blow up once (or two replacements come).
	if is_queued_for_deletion():
		return
	if health > 0:
		health = 0
	for i in stomach.size():
		ItemManager.instance.drop_on_street(stomach[i], global_position + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 1.2)
	stomach.clear()
	if drop_on_destroy != "":
		ItemManager.instance.drop_on_street(drop_on_destroy, global_position)
	# Smashing an enemy makes the city angrier... but smashing a boss cools it right down.
	var heat := HeatMeter.instance
	heat.add_heat(-heat.cool_when_boss_destroyed if is_boss else heat.heat_per_roomba_destroyed)
	Sound.play_everywhere(explode_sound, global_position)
	print("[Enemy] %s exploded" % name)
	destroyed.emit(self)
	Events.enemy_destroyed.emit(self)  # host only (scripts/events.gd)
	queue_free()  # the spawner removes it on everyone's screen


## Host: blow up with nobody to thank for it (THE 1% MIRACLE): no quest kill and no boss drop.
func self_destruct() -> void:
	killed_by = 0
	drop_on_destroy = ""
	explode()


## For the floating health bar (scripts/ui/hud_health_bars.gd): hidden until a player SHOOTS it
## (health is synced, so everyone's HUD shows it once anybody has hit it).
func health_bar_info() -> Dictionary:
	return {"hp": maxi(health, 0), "max": max_health, "name": display_name, "boss": is_boss,
		"position": global_position + Vector3.UP * health_bar_height,
		"show": health < max_health}


## Host -> everyone: flash and make the hit sound.
@rpc("authority", "call_local", "unreliable")
func _hit_flash() -> void:
	_flash_time = 0.15
	Sound.play_at(hit_sound, global_position)
