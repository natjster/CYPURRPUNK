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
##   - THE LOOK: "Model" can be a Blockbench model (models/*.glb): it gets the PS1 material
##     (psx_lit) and the parts named in Glow Parts glow (eye, sirens, tanks).
##   - THE EYE WEAK SPOT: a bolt that goes into the glowing Eye (Eye Path) is ALWAYS a critical
##     hit (is_eye_hit). Aim for the visor!
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
## Parts of the Model (node names) that GLOW, and in which colour. White = the script tints it
## while playing (the VAC-COP's eye goes cyan / red, the sirens red / blue). A Blockbench part's
## painted pixels still show inside the glow.
@export var glow_parts: Dictionary = {"Eye": Color.WHITE, "SirenRed": Color.WHITE, "SirenBlue": Color.WHITE}
## How bright the Glow Parts are (0 = no glow, 5 = neon).
@export var glow_energy: float = 5.0

@export_group("Eye Weak Spot")
## The glowing eye / visor: a shot into it is always a CRITICAL HIT.
@export var eye_path: NodePath = ^"Model/Eye"
## How close (metres) the bolt must pass to the middle of the Eye to count. Grows with the
## Model's scale, so the 2.6x MEGA VAC-COP's eye is a 2.6x bigger target too.
@export var eye_crit_radius: float = 0.22
## Damage multiplier for an eye shot that the gun hadn't already rolled as a crit (a gun with a
## bigger Crit Multiplier uses its own).
@export var eye_crit_multiplier: float = 2.0
## How deep past where the bolt struck the body it may still find the eye (metres, times the
## Model's scale): the hit box can be bigger than the model (the drone's is a ball).
@export var eye_ray_depth: float = 0.9
## Sound file (res://sounds/sfx/, without .wav) for an eye crit, heard by the shooter.
@export var eye_crit_sound: String = "eye_crit"

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
var _eye_flash_time: float = 0.0  # this computer: the eye just got crit (flashes white-hot)
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
	_set_up_model()
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
	_eye_flash_time = maxf(_eye_flash_time - delta, 0.0)
	if _flash_mesh != null:
		_flash_mesh.set_instance_shader_parameter("instance_tint", Color(3, 0.6, 0.6) if _flash_time > 0.0 else Color.WHITE)


## The PS1 look for a Blockbench Model (LevelKit.psx_ify keeps its painted texture), then each
## Glow Part gets its own glowing copy of the material.
func _set_up_model() -> void:
	if model == null:
		return
	LevelKit.psx_ify(model)
	for part_name in glow_parts:
		var part := model.get_node_or_null(NodePath(str(part_name)))
		if part == null:
			continue
		var meshes: Array[Node] = part.find_children("*", "MeshInstance3D", true, false)
		if part is MeshInstance3D:
			meshes.append(part)
		for node in meshes:
			var mesh := node as MeshInstance3D
			if mesh.mesh == null or not mesh.get_active_material(0) is ShaderMaterial:
				continue
			var glow := (mesh.get_active_material(0) as ShaderMaterial).duplicate() as ShaderMaterial
			glow.set_shader_parameter("albedo_color", Color(0.2, 0.2, 0.2))
			glow.set_shader_parameter("emission_color", glow_parts[part_name])
			glow.set_shader_parameter("emission_energy", glow_energy)
			glow.set_shader_parameter("emission_textured", true)  # the pixel-art scanlines show in the glow
			mesh.set_surface_override_material(0, glow)


# --- Getting hurt ---

## The hit framework (hit.gd): a bolt hit us. Runs on the SHOOTER's computer, which sends the
## damage to the host (the host keeps score of enemy health). true = show a damage number.
## A bolt into the glowing EYE is always a crit: hit.crit / hit.damage are changed right here, so
## the gun's damage number (shown after this) is the big yellow CRIT one and the host gets the
## crit damage.
func receive_hit(hit: Hit) -> bool:
	var blast := hit.weapon != null and hit.weapon.blast_radius > 0.0  # (explosions have no aim)
	if not blast and is_eye_hit(hit.position, hit.direction):
		if not hit.crit:
			var multiplier := maxf(eye_crit_multiplier, hit.weapon.crit_multiplier if hit.weapon != null else 2.0)
			hit.damage = roundi(hit.damage * multiplier)
			hit.crit = true
		_eye_flash_time = 0.25
		Sound.play_at(eye_crit_sound, hit.position)
	take_hit.rpc_id(1, hit.shooter_id(), hit.damage, hit.stun_seconds, hit.enemy_push, hit.city_heat)
	return true


## Did a bolt that struck us at "where", flying along "direction", go into the Eye? The eye counts
## from the front (or the side), not through the back of the body. No direction = just how close
## "where" is.
func is_eye_hit(where: Vector3, direction: Vector3 = Vector3.ZERO) -> bool:
	var eye := get_node_or_null(eye_path) as Node3D
	if eye == null or not eye.is_visible_in_tree():
		return false
	var centre := eye_centre()
	var size := absf(model.scale.x) if model != null else 1.0
	var radius := eye_crit_radius * size
	if direction == Vector3.ZERO:
		return where.distance_to(centre) <= radius
	var flying := direction.normalized()
	var looking := -eye.global_basis.z.normalized()  # (models face -Z)
	if flying.dot(looking) > 0.2:
		return false  # flying the same way the eye looks = shot from behind
	# The point on the bolt's path closest to the eye (from just before it struck to a bit inside).
	var along := clampf((centre - where).dot(flying), -radius, eye_ray_depth * size)
	return (where + flying * along).distance_to(centre) <= radius


## The middle of the Eye in the world (the middle of its mesh, or the node itself).
func eye_centre() -> Vector3:
	var eye := get_node_or_null(eye_path) as Node3D
	if eye == null:
		return global_position
	var mesh := eye as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		return mesh.global_transform * mesh.get_aabb().get_center()
	return eye.global_position


## True for a moment after this computer's bolt crit the eye (roomba.gd flashes it white-hot).
func eye_flashing() -> bool:
	return _eye_flash_time > 0.0


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
		if car.driver_id != 0 and car_speed > car_smash_speed * car.smash_speed_factor and car_speed < 60.0 \
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
	elif not is_boss and killed_by != 0:
		if DistrictTwist.roll_scrap_drop():
			# HIGH ALERT (scripts/district_twist.gd): even the little ones carry SCRAP, sometimes.
			ItemManager.instance.drop_on_street(Mainframe.SCRAP_ID, global_position)
			print("[Enemy] %s dropped SCRAP (HIGH ALERT)" % name)
		# SCRAP MAGNET (scripts/upgrades.gd): the cat who smashed a regular bot may get a SCRAP out of it.
		if randf() < Upgrades.scrap_magnet_chance(killed_by):
			ItemManager.instance.drop_on_street(Mainframe.SCRAP_ID, global_position + Vector3(0.6, 0, 0.6))
			print("[Enemy] SCRAP MAGNET: %s dropped scrap for player %d" % [name, killed_by])
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
