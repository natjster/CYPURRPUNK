class_name SquirtDrone
extends Roomba
## SQUIRT-DRONE — OVERCLEAN's "BAD-KITTY" quadcopter. It hovers over the street, holds a cat in its
## spotlight (which raises the HEAT) and fires pressurised water zaps at it. Everything else
## (patrolling, spotting cats, finding its way down the streets, saving CPU far away) comes from
## the VAC-COP (roomba.gd). Cars drive under it and can't smash it (Car Smash Speed 999).
## Attach to the root of scenes/squirt_drone.tscn. Expected node tree:
##   SquirtDrone (CharacterBody3D)  <- this script
##   ├── CollisionShape3D
##   ├── Model (Node3D)             <- turns to face where it flies
##   │   ├── Body, Tank, arms       <- Body flashes when shot, Tank = the glowing squirt bottle
##   │   ├── Eye, SirenRed, SirenBlue
##   │   └── Rotors (Node3D)        <- every child spins (four rotors)
##   ├── SirenLight (SpotLight3D)   <- cyan looking down; red and on the cat while chasing
##   └── MultiplayerSynchronizer    <- shares sync_position, sync_yaw, state, health
##
## What it does while chasing a cat:
##   SPOTLIGHT — with a clear line to the cat, adds Heat Per Second to the HEAT.
##   WATER ZAP — every Squirt Seconds, aims where the cat is NOW and fires. The stream takes
##               Squirt Travel Seconds to land, so weaving or turning a corner dodges it. A hit
##               takes Squirt Damage and gives a little knockback hop. It never steals loot.
## A STUN (the YARN-ZOOKA) makes its rotors sputter: it sinks to Stunned Height, in reach of melee.

@export_group("Flight")
## How high it hovers above the street (metres), and how high while stunned.
@export var hover_height: float = 3.8
@export var stunned_height: float = 1.0
## How quickly it rises and sinks to that height (higher = snappier).
@export var climb_strength: float = 4.0
## The most it rises or sinks per second (metres).
@export var max_climb_speed: float = 6.0
## It holds this far from the cat it's chasing (metres along the ground).
@export var stand_off: float = 6.0

@export_group("Spotlight and Water Zap")
## HEAT added per second while it has a cat in sight.
@export var heat_per_second: float = 0.5
## Seconds between water zaps.
@export var squirt_seconds: float = 2.0
## How long a zap takes to land (seconds): the warning that lets you dodge.
@export var squirt_travel_seconds: float = 0.25
## How close to where it lands a cat gets hit (metres), and the HP it takes.
@export var squirt_radius: float = 1.4
@export var squirt_damage: int = 15
## The small shove and hop a hit gives (metres per second).
@export var squirt_push: float = 3.0
@export var squirt_hop: float = 3.0
## The spotlight's colour on patrol and while tracking a cat.
@export var patrol_light_color: Color = Color(0.2, 0.9, 1)
@export var chase_light_color: Color = Color(1, 0.08, 0.1)

var _squirt_left: float = 0.0
## Spotlight pointing straight down, as set in the scene.
var _light_home: Vector3

@onready var rotors: Node3D = $Model/Rotors


func _ready() -> void:
	super()
	_light_home = siren_light.rotation


## Host: no gravity, just hold the right height. (Replaces the VAC-COP's fall.)
func _fall(_delta: float) -> void:
	var wanted := ground_height() + (stunned_height if state == State.STUNNED else hover_height)
	velocity.y = clampf((wanted - global_position.y) * climb_strength, -max_climb_speed, max_climb_speed)


## Host: with a clear view, hold stand_off from the cat. Otherwise follow the streets like a VAC-COP.
func _chase_point(cat: CatPlayer) -> Vector3:
	if not _clear_line_to(cat):
		return super(cat)
	var away := Motion.flat(global_position - cat.global_position)
	return global_position if away == Vector3.ZERO else cat.global_position + away.normalized() * stand_off


## Host, every frame of a chase: the heat spotlight and the water zap.
func _attack(cat: CatPlayer, delta: float) -> void:
	_squirt_left -= delta
	if not _clear_line_to(cat):
		return
	# (A SEWER BREACH drone hunts from any distance, but has to get close before it may fire.)
	if breach_hub != null and Motion.flat_distance(cat.global_position, global_position) > lose_range:
		return
	HeatMeter.instance.add_heat(heat_per_second * delta)
	if _squirt_left <= 0.0:
		_squirt_left = squirt_seconds
		var aim := cat.global_position
		_show_squirt.rpc(global_position + Vector3.DOWN * 0.35, aim)
		get_tree().create_timer(squirt_travel_seconds).timeout.connect(_squirt_lands.bind(aim))


## Host: the zap landed. Every cat in the splash gets wet.
func _squirt_lands(aim: Vector3) -> void:
	for node in Game.instance.players.get_children():
		var cat := node as CatPlayer
		if not cat.visible or CatHealth.instance.is_down(cat.player_id) or cat.global_position.distance_to(aim) > squirt_radius:
			continue
		var push := Motion.flat(cat.global_position - aim).normalized() * squirt_push + Vector3.UP * squirt_hop
		cat.get_zapped.rpc_id(PlayerId.peer_of(cat.player_id), push)  # the cat's owner moves it
		CatHealth.instance.damage(cat.player_id, squirt_damage, "A SQUIRT-DRONE")


## Host -> everyone: the cyan stream shoots from the drone to the street, with a ring where it lands.
@rpc("authority", "call_local", "unreliable")
func _show_squirt(from: Vector3, to: Vector3) -> void:
	Sound.play_at("squirt", from)
	var glow := LevelKit.psx_material({"albedo_color": Color(0, 0.2, 0.3),
		"emission_color": Color(0.3, 0.9, 1), "emission_energy": 4.0})
	var world := get_parent().get_parent()  # (the Main node: survives the drone being destroyed)
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 1.0)
	var stream := MeshInstance3D.new()
	stream.mesh = box
	stream.material_override = glow
	world.add_child(stream)
	stream.look_at_from_position(from, to + Vector3.UP * 0.01)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = squirt_radius - 0.1
	ring_mesh.outer_radius = squirt_radius
	ring_mesh.rings = 12
	ring_mesh.ring_segments = 3
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = glow
	ring.position = to + Vector3.UP * 0.08
	world.add_child(ring)
	var length := from.distance_to(to)
	var shot := stream.create_tween()
	shot.tween_method(func(t: float) -> void:
		stream.position = from.lerp(to, t * 0.5)
		stream.scale.z = maxf(length * t, 0.01), 0.0, 1.0, squirt_travel_seconds)
	shot.tween_interval(0.1)
	shot.tween_callback(func() -> void:
		stream.queue_free()
		ring.queue_free())


## Every computer: spin the rotors (they sputter when stunned), and the VAC-COP's lights and hum.
func _process(delta: float) -> void:
	super(delta)
	var spin := 8.0 if state == State.STUNNED else 40.0
	for rotor in rotors.get_children():
		(rotor as Node3D).rotate_y(delta * spin)


## Every computer: always on, cyan looking down, or red and pointing at the nearest cat.
func _show_light(chasing: bool, _blink: bool) -> void:
	siren_light.visible = state != State.STUNNED
	siren_light.light_color = chase_light_color if chasing else patrol_light_color
	var cat := _nearest_cat() if chasing else null
	if cat != null and Motion.flat_distance(cat.global_position, global_position) > 0.5:
		siren_light.look_at(cat.global_position)
	else:
		siren_light.rotation = _light_home


## Every computer: which cat our light points at. (The host's chase target isn't synced; the
## nearest cat is the same one nearly always, and this is only the look.)
func _nearest_cat() -> CatPlayer:
	var best: CatPlayer = null
	for node in Game.instance.players.get_children():
		var cat := node as CatPlayer
		if cat.visible and (best == null or cat.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = cat
	return best
