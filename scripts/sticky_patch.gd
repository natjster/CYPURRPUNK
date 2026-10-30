class_name StickyPatch
extends Node3D
## A glowing pink puddle of LINT-TRAPPER glue on the street (scripts/lint_trapper.gd). It only
## exists on this computer: the host tells every computer to make one (an RPC), and each cat's OWN
## computer checks if its paws touched one (cat_player.gd _sticky_paws). It's built in code, there
## is no scene to edit. Radius and lifetime are on the LINT-TRAPPER (Sticky Glue group).

## How long the puddle takes to shrink away at the end of its life (seconds).
const FADE_SECONDS := 0.5
## How close above or below a puddle a cat's feet must be to touch it (metres).
const TOUCH_HEIGHT := 0.6
## Puddles sit this far above the ground, each a little higher than the last (up to LAYERS
## steps), so two that overlap don't flicker.
const LIFT := 0.04
const LIFT_STEP := 0.012
const LAYERS := 8

static var _active: Array[StickyPatch] = []
static var _next_layer: int = 0
static var _mesh: CylinderMesh
static var _material: ShaderMaterial

var _radius: float = 1.6


## Every computer: put a puddle on the ground at "at". "parent" holds it (it isn't a child of the
## Lint-Trapper, because the puddle stays when the Lint-Trapper is destroyed).
static func make(parent: Node, at: Vector3, radius: float, seconds: float) -> void:
	if _mesh == null:
		_mesh = CylinderMesh.new()
		_mesh.top_radius = 1.0
		_mesh.bottom_radius = 1.0
		_mesh.height = 0.01
		_mesh.radial_segments = 10
		_mesh.rings = 1
		_material = LevelKit.psx_material({"albedo_color": Color(0.3, 0.02, 0.2),
			"emission_color": Color(1, 0.12, 0.65), "emission_energy": 0.9})
	var patch := StickyPatch.new()
	patch._radius = radius
	var look := MeshInstance3D.new()
	look.mesh = _mesh
	look.material_override = _material
	look.scale = Vector3(radius, 1, radius)
	patch.add_child(look)
	_next_layer = (_next_layer + 1) % LAYERS
	patch.position = at + Vector3.UP * (LIFT + _next_layer * LIFT_STEP)
	parent.add_child(patch)
	var life := patch.create_tween()
	life.tween_interval(maxf(seconds - FADE_SECONDS, 0.0))
	life.tween_property(look, "scale", Vector3(0.01, 1, 0.01), FADE_SECONDS)
	life.tween_callback(patch.queue_free)


## How many puddles are on the street on this computer (for the test tool).
static func count() -> int:
	return _active.size()


## True if feet at "where" are standing in any puddle on this computer.
static func touches(where: Vector3) -> bool:
	for patch in _active:
		if absf(patch.global_position.y - where.y) < TOUCH_HEIGHT \
				and Motion.flat_distance(patch.global_position, where) < patch._radius:
			return true
	return false


func _enter_tree() -> void:
	_active.append(self)


func _exit_tree() -> void:
	_active.erase(self)
