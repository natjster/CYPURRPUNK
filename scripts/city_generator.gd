class_name CityGenerator
extends Node3D
## MEOW-CITY 1999 — builds the whole city from a single number, the "seed".
##
## The same seed always makes exactly the same city. In multiplayer the host only sends
## that one number, and every computer builds an identical city by itself.
##
## Layout: a grid of square blocks separated by streets. The very centre of the map is
## always a crossroads (cats spawn there), and the street just north of it always has
## room for the getaway car. Each block is cut into 4 lots; each lot becomes a building
## (taller towards downtown), or an empty yard with crates and trash. Some buildings get
## glowing neon signs, and every crossroads gets a street lamp. One shop near the centre
## is always MEOW-MART.
##
## All tuning knobs are in the Inspector when you select the City node in main.tscn.

## Emitted after a city is built.
signal generated(city_seed: int)

@export_group("Layout")
## Blocks along each side. Keep it EVEN so the map centre is a crossroads.
@export var blocks_per_side: int = 6
## Width of one block (metres).
@export var block_size: float = 24.0
## Width of the streets between blocks (metres).
@export var street_width: float = 12.0

@export_group("Buildings")
@export var min_height: float = 6.0
@export var max_height: float = 32.0
## Chance (0-1) that a lot stays an empty yard with crates and trash.
@export_range(0.0, 1.0) var empty_lot_chance: float = 0.2
## Chance (0-1) that a building gets a glowing neon sign.
@export_range(0.0, 1.0) var neon_chance: float = 0.55
## Chance (0-1) of a little box (vents, water tank) on a roof.
@export_range(0.0, 1.0) var rooftop_chance: float = 0.5

@export_group("Materials")
@export var street_material: Material
@export var sidewalk_material: Material
@export var building_material: Material
@export var neon_material: Material
@export var crate_material: Material
@export var trash_material: Material

## Where the getaway car is parked at the start (always open street).
const CAR_SPAWN: Vector3 = Vector3(3, 0.5, -10)
const STREET_LAMP: PackedScene = preload("res://scenes/props/street_lamp.tscn")
const NEON_COLORS: Array[Color] = [
	Color(1, 0.1, 0.65),   # hot pink
	Color(0.1, 0.85, 1),   # cyan
	Color(1, 0.75, 0.15),  # amber
	Color(0.3, 1, 0.45),   # acid green
	Color(0.6, 0.3, 1),    # purple
]
const BUILDING_TINTS: Array[Color] = [
	Color(1, 1, 1),
	Color(0.8, 0.85, 1),
	Color(1, 0.85, 0.8),
	Color(0.75, 0.7, 0.9),
	Color(0.85, 0.95, 0.9),
]

## The seed of the city currently built.
var city_seed: int = 0
## Front door of Meow-Mart — handy for the upcoming heist gameplay.
var meow_mart_position: Vector3

var _rng := RandomNumberGenerator.new()
# Shared 1x1x1 boxes, stretched to size per object (saves memory). Each box is cut into
# pieces of about WALL_PIECE_SIZE metres, so big walls aren't two giant triangles —
# giant triangles make the PS1 texture warp extreme and the windows "swim".
# Boxes needing the same number of cuts share one mesh (see _box_mesh_for).
const WALL_PIECE_SIZE: float = 2.5
var _box_meshes := {}
var _trash_mesh := SphereMesh.new()


func _init() -> void:
	_trash_mesh.radius = 0.4
	_trash_mesh.height = 0.6
	_trash_mesh.radial_segments = 7
	_trash_mesh.rings = 3


## Throw away the old city (if any) and build a new one from this seed.
func generate(new_seed: int) -> void:
	city_seed = new_seed
	_rng.seed = new_seed
	for child in get_children():
		child.queue_free()

	var pitch := block_size + street_width  # distance from one block to the next
	var city_half_width := blocks_per_side * pitch * 0.5
	_build_ground(city_half_width, pitch)
	for bx in blocks_per_side:
		for bz in blocks_per_side:
			var block_center := Vector3((bx + 0.5 - blocks_per_side / 2.0) * pitch, 0, (bz + 0.5 - blocks_per_side / 2.0) * pitch)
			_build_block(block_center)
	_place_street_lamps(pitch)
	print("[City] Built city #%d" % new_seed)
	generated.emit(new_seed)


# --- Ground, sidewalks and the invisible walls at the edge of the map ---

func _build_ground(city_half_width: float, pitch: float) -> void:
	var size := city_half_width * 2.0 + 24.0
	var edge := size * 0.5
	var ground := StaticBody3D.new()
	add_child(ground)
	# What you walk and drive on: one smooth invisible floor.
	_add_collision(ground, Vector3(0, -0.5, 0), Vector3(size, 1, size))

	# What you SEE: the ground cut into a chessboard of tiles along every block edge.
	# Tiles where a block sits are sidewalk, the rest are street. They never overlap —
	# two surfaces stacked on top of each other flicker as the graphics card can't decide
	# which is in front (worst when the camera is low, looking along the ground).
	var lines: Array[float] = [-edge]
	for b in blocks_per_side:
		var block_center := (b + 0.5 - blocks_per_side / 2.0) * pitch
		lines.append(block_center - block_size * 0.5)
		lines.append(block_center + block_size * 0.5)
	lines.append(edge)
	for ix in lines.size() - 1:
		for iz in lines.size() - 1:
			var is_block := ix % 2 == 1 and iz % 2 == 1  # odd spans are blocks, even are streets
			_add_ground_tile(ground, lines[ix], lines[ix + 1], lines[iz], lines[iz + 1], sidewalk_material if is_block else street_material)

	# Invisible walls so nobody drives off the edge of the world.
	_add_collision(ground, Vector3(0, 3, edge), Vector3(size, 6, 1))
	_add_collision(ground, Vector3(0, 3, -edge), Vector3(size, 6, 1))
	_add_collision(ground, Vector3(edge, 3, 0), Vector3(1, 6, size))
	_add_collision(ground, Vector3(-edge, 3, 0), Vector3(1, 6, size))


## One flat ground tile, cut into ~WALL_PIECE_SIZE pieces. Neighbouring tiles share an
## edge of the same length, so their corner points line up exactly and no cracks appear.
func _add_ground_tile(parent: Node3D, x0: float, x1: float, z0: float, z1: float, material: Material) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(x1 - x0, z1 - z0)
	plane.subdivide_width = maxi(0, ceili(plane.size.x / WALL_PIECE_SIZE) - 1)
	plane.subdivide_depth = maxi(0, ceili(plane.size.y / WALL_PIECE_SIZE) - 1)
	var tile := MeshInstance3D.new()
	tile.mesh = plane
	tile.material_override = material
	tile.position = Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
	parent.add_child(tile)


func _build_block(block_center: Vector3) -> void:
	# (The block's sidewalk is one of the ground tiles — see _build_ground.)
	var lot_size := block_size / 2.0
	for lx in [-1, 1]:
		for lz in [-1, 1]:
			# lx / lz also tell us which way this lot faces the street.
			var lot_center := block_center + Vector3(lx, 0, lz) * lot_size * 0.5
			var street_side := Vector2(lx, lz)
			if _is_meow_mart_lot(lot_center):
				_build_meow_mart(lot_center, street_side)
			elif _rng.randf() < empty_lot_chance:
				_build_yard(lot_center, lot_size)
			else:
				_build_building(lot_center, lot_size, street_side)


# --- Buildings ---

func _build_building(lot_center: Vector3, lot_size: float, street_side: Vector2) -> void:
	var width := _rng.randf_range(lot_size * 0.6, lot_size - 1.5)
	var depth := _rng.randf_range(lot_size * 0.6, lot_size - 1.5)

	# Downtown (near the centre) gets the tallest towers.
	var map_half := blocks_per_side * (block_size + street_width) * 0.5
	var downtown := 1.0 - clampf(Vector2(lot_center.x, lot_center.z).length() / map_half, 0.0, 1.0)
	var height := lerpf(min_height, max_height, _rng.randf() * 0.5 + downtown * 0.5)

	var center := _front_aligned_center(lot_center, lot_size, street_side, width, depth, height)
	var size := Vector3(width, height, depth)
	var walls := _add_box(center, size, building_material, true)
	walls.set_instance_shader_parameter("instance_tint", BUILDING_TINTS[_rng.randi() % BUILDING_TINTS.size()])

	if _rng.randf() < rooftop_chance:
		var roof_box := Vector3(_rng.randf_range(1.5, 3.0), _rng.randf_range(1.0, 2.0), _rng.randf_range(1.5, 3.0))
		var roof_spot := center + Vector3(_rng.randf_range(-1, 1) * (width - roof_box.x) * 0.4, height * 0.5 + roof_box.y * 0.5, _rng.randf_range(-1, 1) * (depth - roof_box.z) * 0.4)
		_add_box(roof_spot, roof_box, building_material, false)

	if _rng.randf() < neon_chance:
		_add_neon_sign(center, size, street_side)


## Building centre so its street-facing walls sit 1 m back from the sidewalk edge,
## like a row of shopfronts. The leftover space at the back becomes alleys.
func _front_aligned_center(lot_center: Vector3, lot_size: float, street_side: Vector2, width: float, depth: float, height: float) -> Vector3:
	return Vector3(
		lot_center.x + street_side.x * (lot_size * 0.5 - 1.0 - width * 0.5),
		height * 0.5,
		lot_center.z + street_side.y * (lot_size * 0.5 - 1.0 - depth * 0.5))


func _add_neon_sign(building_center: Vector3, building_size: Vector3, street_side: Vector2) -> void:
	var color := NEON_COLORS[_rng.randi() % NEON_COLORS.size()]
	var vertical := _rng.randf() < 0.5
	var long_side := 3.0 if vertical else 3.5
	var short_side := 0.9
	var on_x_face := _rng.randf() < 0.5  # which street-facing wall gets the sign
	var y := _rng.randf_range(3.0, minf(building_size.y - 1.0, 9.0))
	var sign_size: Vector3
	var sign_pos: Vector3
	var outward: Vector3
	if on_x_face:
		outward = Vector3(street_side.x, 0, 0)
		var slide := _rng.randf_range(-1, 1) * (building_size.z * 0.5 - 1.5)
		sign_pos = Vector3(building_center.x + street_side.x * (building_size.x * 0.5 + 0.12), y, building_center.z + slide)
		sign_size = Vector3(0.2, long_side, short_side) if vertical else Vector3(0.2, short_side, long_side)
	else:
		outward = Vector3(0, 0, street_side.y)
		var slide := _rng.randf_range(-1, 1) * (building_size.x * 0.5 - 1.5)
		sign_pos = Vector3(building_center.x + slide, y, building_center.z + street_side.y * (building_size.z * 0.5 + 0.12))
		sign_size = Vector3(short_side, long_side, 0.2) if vertical else Vector3(long_side, short_side, 0.2)

	var neon := _add_box(sign_pos, sign_size, neon_material, false)
	neon.set_instance_shader_parameter("instance_tint", color)
	_add_glow_light(sign_pos + outward * 1.2, color)


## A coloured light that spills the sign's glow onto the street and into the fog.
## It fades out with distance so a big city doesn't have to draw every light at once.
func _add_glow_light(at: Vector3, color: Color) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = 2.5
	light.light_volumetric_fog_energy = 1.5
	light.omni_range = 9.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 40.0
	light.distance_fade_length = 10.0
	add_child(light)


# --- Meow-Mart: always the shop on the corner nearest the centre ---

func _is_meow_mart_lot(lot_center: Vector3) -> bool:
	var corner := -(street_width * 0.5 + block_size * 0.25)
	return lot_center.is_equal_approx(Vector3(corner, 0, corner))


func _build_meow_mart(lot_center: Vector3, street_side: Vector2) -> void:
	var size := Vector3(10, 7, 10)
	var center := _front_aligned_center(lot_center, block_size / 2.0, street_side, size.x, size.z, size.y)
	var walls := _add_box(center, size, building_material, true)
	walls.set_instance_shader_parameter("instance_tint", Color(1, 0.75, 0.9))

	var front_z := center.z + street_side.y * (size.z * 0.5)
	var pink := NEON_COLORS[0]
	var strip := _add_box(Vector3(center.x, 3.6, front_z + street_side.y * 0.12), Vector3(8, 0.3, 0.2), neon_material, false)
	strip.set_instance_shader_parameter("instance_tint", pink)

	var label := Label3D.new()
	label.text = "MEOW-MART"
	label.font_size = 64
	label.pixel_size = 0.02
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.modulate = Color(3, 0.6, 2.2)  # brighter than white = it glows
	label.position = Vector3(center.x, 5.0, front_z + street_side.y * 0.15)
	add_child(label)

	_add_glow_light(Vector3(center.x, 4.0, front_z + street_side.y * 1.5), pink)
	meow_mart_position = Vector3(center.x, 0, front_z + street_side.y * 1.0)


# --- Empty yards ---

func _build_yard(lot_center: Vector3, lot_size: float) -> void:
	var spread := lot_size * 0.5 - 2.0
	for i in _rng.randi_range(1, 4):
		var spot := lot_center + Vector3(_rng.randf_range(-spread, spread), 0.5, _rng.randf_range(-spread, spread))
		_add_box(spot, Vector3.ONE, crate_material, true)
		if _rng.randf() < 0.35:  # stack one on top
			_add_box(spot + Vector3(0, 1, 0), Vector3.ONE, crate_material, true)
	if _rng.randf() < 0.6:  # dumpster
		var spot := lot_center + Vector3(_rng.randf_range(-spread, spread), 0.65, _rng.randf_range(-spread, spread))
		var dumpster := _add_box(spot, Vector3(2.2, 1.3, 1.2), building_material, true)
		dumpster.set_instance_shader_parameter("instance_tint", Color(0.3, 0.6, 0.45))
	for i in _rng.randi_range(2, 5):
		var bag := MeshInstance3D.new()
		bag.mesh = _trash_mesh
		bag.material_override = trash_material
		bag.position = lot_center + Vector3(_rng.randf_range(-spread, spread), 0.22, _rng.randf_range(-spread, spread))
		bag.rotation = Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, 0)
		add_child(bag)


# --- Street lamps at every crossroads, plus one halfway along each block ---

func _place_street_lamps(pitch: float) -> void:
	var edge := street_width * 0.5 + 0.6  # just onto the sidewalk
	for line in blocks_per_side - 1:
		var street_at := (line + 1 - blocks_per_side / 2.0) * pitch
		for block in blocks_per_side:
			var block_mid := (block + 0.5 - blocks_per_side / 2.0) * pitch
			var side := 1.0 if _rng.randf() < 0.5 else -1.0
			# Along an east-west street (arm points north/south into the road)...
			_add_lamp(Vector3(block_mid, 0, street_at + side * edge), atan2(0.0, side))
			# ...and along a north-south street (arm points east/west).
			side = 1.0 if _rng.randf() < 0.5 else -1.0
			_add_lamp(Vector3(street_at + side * edge, 0, block_mid), atan2(side, 0.0))
	for ix in blocks_per_side - 1:
		for iz in blocks_per_side - 1:
			var crossroads := Vector3((ix + 1 - blocks_per_side / 2.0) * pitch, 0, (iz + 1 - blocks_per_side / 2.0) * pitch)
			# Pick a random corner of the crossroads and point the lamp's arm at the middle.
			var corner_x := 1.0 if _rng.randf() < 0.5 else -1.0
			var corner_z := 1.0 if _rng.randf() < 0.5 else -1.0
			_add_lamp(crossroads + Vector3(corner_x, 0, corner_z) * edge, atan2(corner_x, corner_z))


## A lamp post; "facing" turns it so its arm hangs over the road.
func _add_lamp(at: Vector3, facing: float) -> void:
	var lamp := STREET_LAMP.instantiate() as Node3D
	lamp.position = at
	lamp.rotation.y = facing
	add_child(lamp)


# --- Helpers ---

## Adds a box. "solid" = cats and cars bump into it.
func _add_box(center: Vector3, size: Vector3, material: Material, solid: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box_mesh_for(size)
	mesh.scale = size
	mesh.material_override = material
	if solid:
		var body := StaticBody3D.new()
		body.position = center
		add_child(body)
		_add_collision(body, Vector3.ZERO, size)
		body.add_child(mesh)
	else:
		mesh.position = center
		add_child(mesh)
	return mesh


## A 1x1x1 box cut so that, once stretched to "size", its pieces are ~WALL_PIECE_SIZE metres.
func _box_mesh_for(size: Vector3) -> BoxMesh:
	var cuts := Vector3i(
		maxi(0, ceili(size.x / WALL_PIECE_SIZE) - 1),
		maxi(0, ceili(size.y / WALL_PIECE_SIZE) - 1),
		maxi(0, ceili(size.z / WALL_PIECE_SIZE) - 1))
	if not _box_meshes.has(cuts):
		var box := BoxMesh.new()
		box.subdivide_width = cuts.x
		box.subdivide_height = cuts.y
		box.subdivide_depth = cuts.z
		_box_meshes[cuts] = box
	return _box_meshes[cuts]


func _add_collision(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = at
	body.add_child(shape)
