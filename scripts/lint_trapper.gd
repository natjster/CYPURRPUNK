class_name LintTrapper
extends Roomba
## LINT-TRAPPER — OVERCLEAN's sticky mop-bot. It doesn't bonk or steal: it GLUES the street so
## the VAC-COPs can catch you. Everything else (patrolling, spotting cats, finding its way down the
## streets, being stunned or run over, saving CPU far away) comes from the VAC-COP (roomba.gd).
## Attach to the root of scenes/lint_trapper.tscn. Expected node tree (same names as the VAC-COP):
##   LintTrapper (CharacterBody3D)  <- this script
##   ├── CollisionShape3D
##   ├── Model (Node3D)             <- turns to face where it drives
##   │   ├── Body, Tank             <- Body flashes when shot, Tank = the glowing glue tank
##   │   ├── Eye, SirenRed, SirenBlue
##   │   └── Brush                  <- the hot-pink roller on the front, spins
##   ├── SirenLight (OmniLight3D)   <- purple/pink light on the street while chasing
##   └── MultiplayerSynchronizer    <- shares sync_position, sync_yaw, state, health
##
## What it does while chasing a cat:
##   TRAIL — drops a sticky puddle behind itself every Trail Seconds while it's moving.
##   LOB   — within Lob Range, with a clear line, lobs a glob that lands at the cat's feet.
## A cat that steps in a puddle has STICKY PAWS (half speed for 3 seconds: Sticky Slow / Sticky
## Seconds on the cat, scenes/player.tscn). A jump clears a puddle.
##
## MULTIPLAYER: the host decides when and where; _spawn_patch / _lob_patch make the same puddle on
## every computer, and each cat's own computer checks its own paws (scripts/sticky_patch.gd).

@export_group("Sticky Glue")
## How big a puddle is (metres from its middle) and how long it lasts (seconds).
@export var patch_radius: float = 1.6
@export var patch_seconds: float = 6.0
## While chasing, one puddle every this many seconds.
@export var trail_seconds: float = 1.2
## It only leaves a new puddle if it has moved this far since the last one (metres).
@export var trail_spacing: float = 1.0
## Lobs a glob at a cat closer than this (metres), every Lob Seconds.
@export var lob_range: float = 7.5
@export var lob_seconds: float = 3.5
## How long a glob is in the air (seconds), and how high it arcs (metres).
@export var lob_flight_seconds: float = 0.6
@export var lob_height: float = 2.5
## It stops driving this close to the cat it's chasing (metres): it's here to glue, not to bonk.
@export var keep_distance: float = 3.0

var _trail_left: float = 0.0
var _lob_left: float = 0.0
var _last_patch_at := Vector3.INF


## Host: stay keep_distance back from the cat; further away, drive like a VAC-COP.
func _chase_point(cat: CatPlayer) -> Vector3:
	if Motion.flat_distance(cat.global_position, global_position) < keep_distance:
		return global_position
	return super(cat)


## Host, every frame of a chase: the trail and the lob (replaces the VAC-COP's bonk).
func _attack(cat: CatPlayer, delta: float) -> void:
	_trail_left -= delta
	if _trail_left <= 0.0 and is_on_floor() and global_position.distance_to(_last_patch_at) > trail_spacing:
		_trail_left = trail_seconds
		_last_patch_at = global_position
		_spawn_patch.rpc(global_position)
	_lob_left -= delta
	if _lob_left <= 0.0 and Motion.flat_distance(cat.global_position, global_position) < lob_range and _clear_line_to(cat):
		_lob_left = lob_seconds
		_lob_patch.rpc(global_position + Vector3.UP * 0.5, _ground_under(cat.global_position))


## Host: the street below "where" (a cat may be in mid-jump).
func _ground_under(where: Vector3) -> Vector3:
	var down := PhysicsRayQueryParameters3D.create(where + Vector3.UP * 0.5, where + Vector3.DOWN * 20.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(down)
	return hit.position if not hit.is_empty() else where


## Host -> everyone: a puddle right here.
@rpc("authority", "call_local", "reliable")
func _spawn_patch(at: Vector3) -> void:
	StickyPatch.make(get_parent().get_parent(), at, patch_radius, patch_seconds)


## Host -> everyone: a glob flies from "from" to "to" and turns into a puddle where it lands.
@rpc("authority", "call_local", "reliable")
func _lob_patch(from: Vector3, to: Vector3) -> void:
	Sound.play_at("splat", from, -4.0)
	var glob := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.22
	ball.height = 0.44
	ball.radial_segments = 6
	ball.rings = 3
	glob.mesh = ball
	glob.material_override = LevelKit.psx_material({"albedo_color": Color(0.3, 0.02, 0.2),
		"emission_color": Color(1, 0.12, 0.65), "emission_energy": 3.0})
	glob.position = from
	# (Parked on the Main node, so the glob still lands if this Lint-Trapper is destroyed mid-air.)
	var world := get_parent().get_parent()
	world.add_child(glob)
	var radius := patch_radius
	var seconds := patch_seconds
	var height := lob_height
	var flight := glob.create_tween()
	flight.tween_method(func(t: float) -> void:
		glob.position = from.lerp(to, t) + Vector3.UP * height * 4.0 * t * (1.0 - t), 0.0, 1.0, lob_flight_seconds)
	flight.tween_callback(func() -> void:
		Sound.play_at("splat", to)
		StickyPatch.make(world, to, radius, seconds)
		glob.queue_free())
