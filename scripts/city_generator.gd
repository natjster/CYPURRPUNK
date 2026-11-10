class_name CityGenerator
extends Node3D
## CYPURRPUNK — builds the whole city from a single number, the "seed".
##
## The same seed always makes exactly the same city. In multiplayer the host only sends
## that one number, and every computer builds an identical city by itself.
##
## Layout: a grid of square blocks separated by streets. The very centre of the map is
## always a crossroads (cats spawn there), and the street just north of it always has
## room for the getaway car. Each block is cut into 4 lots; each lot becomes a building
## (taller towards downtown), or an empty yard with crates, bins and cones. Some buildings get
## glowing neon signs, and every crossroads gets a street lamp. One random lot is MEOW-MART
## (a "point of interest": it's somewhere different in every district).
## Trash bins and traffic cones (real low-poly models made in Blockbench, res://models/) stand on
## some sidewalk corners, in the yards' junk piles and by Meow-Mart's door.
## The manholes and payphones (the other points of interest) are placed by fish_heist.gd.
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

@export_group("Street props (Blockbench models)")
## The trash bin model (made in Blockbench: models/blockbench/trash_bin.bbmodel).
@export_file("*.glb") var trash_bin_model: String = "res://models/trash_bin.glb"
## The traffic cone model (models/blockbench/traffic_cone.bbmodel).
@export_file("*.glb") var traffic_cone_model: String = "res://models/traffic_cone.glb"
## The cardboard box model (models/blockbench/cardboard_box.bbmodel).
@export_file("*.glb") var cardboard_box_model: String = "res://models/cardboard_box.glb"
## The OVERCLEAN poster model (models/blockbench/overclean_poster.bbmodel), pasted on shop walls.
@export_file("*.glb") var poster_model: String = "res://models/overclean_poster.glb"
## Empty yards: how many trash bins in the junk pile (a random number between these two).
@export_range(0, 6) var yard_bins_min: int = 1
@export_range(0, 6) var yard_bins_max: int = 3
## Empty yards: how many traffic cones in the junk pile (some lie knocked over).
@export_range(0, 6) var yard_cones_min: int = 0
@export_range(0, 6) var yard_cones_max: int = 3
## Empty yards: how many cardboard boxes in the junk pile.
@export_range(0, 6) var yard_boxes_min: int = 1
@export_range(0, 6) var yard_boxes_max: int = 2
## Chance (0-1) that a building gets an OVERCLEAN poster on its street-facing wall (cats scratch them).
@export_range(0.0, 1.0) var poster_chance: float = 0.35
## Chance (0-1) that a sidewalk corner gets a bin, a cone, or both. There are 4 corners per block
## (144 in a 6x6 city), so 0.3 = roughly 40 corners with something on them.
@export_range(0.0, 1.0) var corner_prop_chance: float = 0.3
## A bin and a couple of cones by Meow-Mart's front door (either side, out of the loot's way).
@export var props_at_meow_mart: bool = true
## Trash bins are solid for cats (they bump into them; zoomies knock them over). Cars and VAC-COPs
## never crash into props (MessProp.SOLID_LAYER), and cones, boxes and posters are never solid.
@export var bins_are_solid: bool = true

## Every MESS prop (bins, standing cones, boxes, posters) in the order they were built: a prop's
## place in this list is its id, the same on every computer (scripts/mess_manager.gd).
var mess_props: Array[MessProp] = []

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
## Front door of Meow-Mart (fish_heist.gd lines fish up outside it).
var meow_mart_position: Vector3
var _meow_mart_lot: Vector3  # centre of the lot Meow-Mart is built on (picked in generate)

var _rng := RandomNumberGenerator.new()
# Boxes, ground pieces and lights come from the level kit (scripts/level_kit.gd): it cuts big
# surfaces into ~2.5 m pieces (giant triangles make the PS1 texture warp extreme and the windows
# "swim") and shares one mesh between boxes of the same shape.
# (The trash-bag blob is only a stand-in for when a model file is missing: see _add_trash_bag.)
var _trash_mesh := SphereMesh.new()


func _init() -> void:
	_trash_mesh.radius = 0.4
	_trash_mesh.height = 0.6
	_trash_mesh.radial_segments = 7
	_trash_mesh.rings = 3


## Throw away the old city (if any) and build a new one from this seed.
## showcase = true: the START MENU's city (game.gd): Meow-Mart goes on the lot by the centre
## crossroads, where the menu camera looks, instead of a random one. Districts are never showcases.
func generate(new_seed: int, showcase: bool = false) -> void:
	city_seed = new_seed
	_rng.seed = new_seed
	for child in get_children():
		child.queue_free()
	mess_props.clear()

	var pitch := block_size + street_width  # distance from one block to the next
	var city_half_width := blocks_per_side * pitch * 0.5
	# Meow-Mart's lot: a random block, a random corner of it.
	var mart_block := Vector3((_rng.randi_range(0, blocks_per_side - 1) + 0.5 - blocks_per_side / 2.0) * pitch, 0,
		(_rng.randi_range(0, blocks_per_side - 1) + 0.5 - blocks_per_side / 2.0) * pitch)
	_meow_mart_lot = mart_block + Vector3(_rng.randi_range(0, 1) * 2 - 1, 0, _rng.randi_range(0, 1) * 2 - 1) * block_size * 0.25
	if showcase:
		# The start menu: the lot on the north-west corner of the centre crossroads (in view).
		# (The random numbers above are still drawn, so the rest of the city is the same.)
		var corner := -(street_width * 0.5 + block_size * 0.25)
		_meow_mart_lot = Vector3(corner, 0, corner)
	_build_ground(city_half_width, pitch)
	for bx in blocks_per_side:
		for bz in blocks_per_side:
			var block_center := Vector3((bx + 0.5 - blocks_per_side / 2.0) * pitch, 0, (bz + 0.5 - blocks_per_side / 2.0) * pitch)
			_build_block(block_center)
	_place_street_lamps(pitch)
	_place_corner_props(pitch)
	print("[City] Built city #%d" % new_seed)
	generated.emit(new_seed)


# --- Ground, sidewalks and the invisible walls at the edge of the map ---

func _build_ground(city_half_width: float, pitch: float) -> void:
	var size := city_half_width * 2.0 + 24.0
	var edge := size * 0.5
	var ground := StaticBody3D.new()
	add_child(ground)
	# What you walk and drive on: one smooth invisible floor.
	LevelKit.add_collision(ground, Vector3(0, -0.5, 0), Vector3(size, 1, size))

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
	LevelKit.add_collision(ground, Vector3(0, 3, edge), Vector3(size, 6, 1))
	LevelKit.add_collision(ground, Vector3(0, 3, -edge), Vector3(size, 6, 1))
	LevelKit.add_collision(ground, Vector3(edge, 3, 0), Vector3(1, 6, size))
	LevelKit.add_collision(ground, Vector3(-edge, 3, 0), Vector3(1, 6, size))


## One flat ground tile, cut into ~2.5 m pieces (LevelKit). Neighbouring tiles share an
## edge of the same length, so their corner points line up exactly and no cracks appear.
func _add_ground_tile(parent: Node3D, x0: float, x1: float, z0: float, z1: float, material: Material) -> void:
	var tile := MeshInstance3D.new()
	tile.mesh = LevelKit.subdivided_plane(Vector2(x1 - x0, z1 - z0))
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
	var walls := LevelKit.add_box(self, center, size, building_material, true)
	walls.set_instance_shader_parameter("instance_tint", BUILDING_TINTS[_rng.randi() % BUILDING_TINTS.size()])

	if _rng.randf() < rooftop_chance:
		var roof_box := Vector3(_rng.randf_range(1.5, 3.0), _rng.randf_range(1.0, 2.0), _rng.randf_range(1.5, 3.0))
		var roof_spot := center + Vector3(_rng.randf_range(-1, 1) * (width - roof_box.x) * 0.4, height * 0.5 + roof_box.y * 0.5, _rng.randf_range(-1, 1) * (depth - roof_box.z) * 0.4)
		LevelKit.add_box(self, roof_spot, roof_box, building_material, false)

	if _rng.randf() < neon_chance:
		_add_neon_sign(center, size, street_side)
	if _rng.randf() < poster_chance:
		# An OVERCLEAN poster at cat height on one of the two street-facing walls.
		var on_x_face := _rng.randf() < 0.5
		var slide := _rng.randf_range(-1, 1)
		_add_poster(center, size, street_side, on_x_face, slide)


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

	var neon := LevelKit.add_box(self, sign_pos, sign_size, neon_material, false)
	neon.set_instance_shader_parameter("instance_tint", color)
	_add_glow_light(sign_pos + outward * 1.2, color)


## A coloured light that spills the sign's glow onto the street and into the fog.
## It fades out with distance so a big city doesn't have to draw every light at once.
func _add_glow_light(at: Vector3, color: Color) -> void:
	LevelKit.add_light(self, at, color, 2.5, 9.0, 40.0)


# --- Meow-Mart: a random lot in every district ---

func _is_meow_mart_lot(lot_center: Vector3) -> bool:
	return lot_center.is_equal_approx(_meow_mart_lot)


func _build_meow_mart(lot_center: Vector3, street_side: Vector2) -> void:
	var size := Vector3(10, 7, 10)
	var center := _front_aligned_center(lot_center, block_size / 2.0, street_side, size.x, size.z, size.y)
	var walls := LevelKit.add_box(self, center, size, building_material, true)
	walls.set_instance_shader_parameter("instance_tint", Color(1, 0.75, 0.9))

	var front_z := center.z + street_side.y * (size.z * 0.5)
	var pink := NEON_COLORS[0]
	var strip := LevelKit.add_box(self, Vector3(center.x, 3.6, front_z + street_side.y * 0.12), Vector3(8, 0.3, 0.2), neon_material, false)
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

	# A bin on one side of the door, cones on the other (the loot lines up in the middle, about
	# 2.6 m either side of the door, so these stand 4.4 m out, by the corners of the shop).
	if props_at_meow_mart:
		var bin_side := 1.0 if _rng.randf() < 0.5 else -1.0
		var by_wall := front_z + street_side.y * 0.45
		_add_bin(Vector3(center.x + bin_side * 4.4, 0, by_wall), _rng.randf() * TAU)
		_add_cone(Vector3(center.x - bin_side * 4.4, 0, by_wall), _rng.randf() * TAU, false)
		_add_cone(Vector3(center.x - bin_side * 3.7, 0, by_wall), _rng.randf() * TAU, _rng.randf() < 0.3)
		_add_box(Vector3(center.x + bin_side * 3.6, 0, by_wall), _rng.randf() * TAU)


# --- Empty yards ---

func _build_yard(lot_center: Vector3, lot_size: float) -> void:
	var spread := lot_size * 0.5 - 2.0
	for i in _rng.randi_range(1, 4):
		var spot := lot_center + Vector3(_rng.randf_range(-spread, spread), 0.5, _rng.randf_range(-spread, spread))
		LevelKit.add_box(self, spot, Vector3.ONE, crate_material, true)
		if _rng.randf() < 0.35:  # stack one on top
			LevelKit.add_box(self, spot + Vector3(0, 1, 0), Vector3.ONE, crate_material, true)
	if _rng.randf() < 0.6:  # dumpster
		var spot := lot_center + Vector3(_rng.randf_range(-spread, spread), 0.65, _rng.randf_range(-spread, spread))
		var dumpster := LevelKit.add_box(self, spot, Vector3(2.2, 1.3, 1.2), building_material, true)
		dumpster.set_instance_shader_parameter("instance_tint", Color(0.3, 0.6, 0.45))
	# The junk pile: a cluster of trash bins and traffic cones (Blockbench models) around one spot,
	# some cones knocked over. (Every random number comes from _rng, in a fixed order: the city
	# must come out the same on every computer.)
	var pile := lot_center + Vector3(_rng.randf_range(-spread, spread) * 0.6, 0, _rng.randf_range(-spread, spread) * 0.6)
	# The pile's spots: a 4x4 grid 1.2 m apart, shuffled, so two things never stand inside each other.
	var spots: Array[Vector3] = []
	for gx in 4:
		for gz in 4:
			spots.append(pile + Vector3((gx - 1.5) * 1.2, 0, (gz - 1.5) * 1.2))
	for i in range(spots.size() - 1, 0, -1):  # shuffle with the city's own random numbers
		var j := _rng.randi_range(0, i)
		var swap := spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	for i in _rng.randi_range(yard_bins_min, maxi(yard_bins_min, yard_bins_max)):
		if not spots.is_empty():
			_add_bin(spots.pop_back() + _jiggle(), _rng.randf() * TAU)
	for i in _rng.randi_range(yard_cones_min, maxi(yard_cones_min, yard_cones_max)):
		if not spots.is_empty():
			_add_cone(spots.pop_back() + _jiggle(), _rng.randf() * TAU, _rng.randf() < 0.4)
	for i in _rng.randi_range(yard_boxes_min, maxi(yard_boxes_min, yard_boxes_max)):
		if not spots.is_empty():
			_add_box(spots.pop_back() + _jiggle(), _rng.randf() * TAU)


## A small random nudge (up to 0.2 m) so a pile doesn't look laid out on a grid.
func _jiggle() -> Vector3:
	return Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2))


# --- Street props: trash bins and traffic cones (real models, made in Blockbench) ---

## Some sidewalk corners get a bin, a cone, or a bin AND a cone. They stand 1.6-2 m along the
## kerb from the very corner: clear of the corner lamp posts, and outside the middle stretch of
## each sidewalk where loot and payphones go (ItemManager.random_sidewalk_spot: up to 9 m from
## the middle of a side; corners are 11.5 m out).
func _place_corner_props(pitch: float) -> void:
	var in_from_edge := block_size * 0.5 - 0.5  # half a metre in from the kerb
	for bx in blocks_per_side:
		for bz in blocks_per_side:
			var block_center := Vector3((bx + 0.5 - blocks_per_side / 2.0) * pitch, 0, (bz + 0.5 - blocks_per_side / 2.0) * pitch)
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				if _rng.randf() >= corner_prop_chance:
					continue
				var along := _rng.randf_range(9.6, 10.2)
				# Which of the corner's two kerbs: the one along the z axis or the one along x.
				# "back" = the way along that kerb towards the middle of the sidewalk.
				var spot: Vector3
				var back: Vector3
				if _rng.randf() < 0.5:
					spot = block_center + Vector3(corner.x * in_from_edge, 0, corner.y * along)
					back = Vector3(0, 0, -corner.y)
				else:
					spot = block_center + Vector3(corner.x * along, 0, corner.y * in_from_edge)
					back = Vector3(-corner.x, 0, 0)
				var roll := _rng.randf()
				if roll < 0.42:
					_add_bin(spot, _rng.randf() * TAU)
				elif roll < 0.72:
					_add_cone(spot, _rng.randf() * TAU, _rng.randf() < 0.25)
				elif roll < 0.85:
					_add_box(spot, _rng.randf() * TAU)
				else:  # a bin with a cone next to it (towards the corner, away from the loot)
					_add_bin(spot, _rng.randf() * TAU)
					_add_cone(spot - back * 0.8, _rng.randf() * TAU, false)


## A trash bin standing at "at" (feet on the ground), turned "yaw" radians: a MESS prop (cats
## knock it over: scripts/mess_prop.gd). Solid for cats unless bins_are_solid is off. Falls back to
## an old trash-bag blob if the model file is missing.
func _add_bin(at: Vector3, yaw: float) -> void:
	if not ResourceLoader.exists(trash_bin_model):
		_add_trash_bag(self, at + Vector3(0, 0.22, 0), yaw)
		return
	_add_mess_prop(MessProp.Kind.BIN, trash_bin_model, at, yaw, bins_are_solid)


## A traffic cone at "at", turned "yaw". A standing cone is a MESS prop; knocked_over = one that's
## already lying on its side (just scenery: OVERCLEAN's bots don't count it as a fresh mess).
func _add_cone(at: Vector3, yaw: float, knocked_over: bool) -> void:
	if not knocked_over and ResourceLoader.exists(traffic_cone_model):
		_add_mess_prop(MessProp.Kind.CONE, traffic_cone_model, at, yaw, false)
		return
	var cone := LevelKit.instantiate_model(traffic_cone_model, self, at, yaw)
	if cone == null:
		_add_trash_bag(self, at + Vector3(0, 0.22, 0), yaw)
		return
	# Tip it over a bit past flat (104 degrees around its own sideways axis) and lift it
	# 0.22 m: then the rim of the cone and its tip both rest on the pavement, like a real
	# fallen cone (the far edge of the square foot dips out of sight under the ground).
	cone.rotate_object_local(Vector3.RIGHT, deg_to_rad(104.0))
	cone.position.y += 0.22


## A cardboard box (a MESS prop: a walk knocks it over).
func _add_box(at: Vector3, yaw: float) -> void:
	if ResourceLoader.exists(cardboard_box_model):
		_add_mess_prop(MessProp.Kind.BOX, cardboard_box_model, at, yaw, false)


## An OVERCLEAN poster on a building's street-facing wall, its bottom 0.55 m up (cat height).
## on_x_face = the wall facing along x (else along z); slide -1..1 = where along that wall.
func _add_poster(building_center: Vector3, building_size: Vector3, street_side: Vector2, on_x_face: bool, slide: float) -> void:
	if not ResourceLoader.exists(poster_model):
		return
	var outward: Vector3
	var spot: Vector3
	if on_x_face:
		outward = Vector3(street_side.x, 0, 0)
		spot = Vector3(building_center.x + street_side.x * building_size.x * 0.5, 0.55,
			building_center.z + slide * (building_size.z * 0.5 - 1.5))
	else:
		outward = Vector3(0, 0, street_side.y)
		spot = Vector3(building_center.x + slide * (building_size.x * 0.5 - 1.5), 0.55,
			building_center.z + street_side.y * building_size.z * 0.5)
	# 3 cm off the wall (its front is 4 cm thick), facing the street (the model faces -Z).
	_add_mess_prop(MessProp.Kind.POSTER, poster_model, spot + outward * 0.03, atan2(-outward.x, -outward.z), false)


## One MESS prop (scripts/mess_prop.gd), numbered in build order (CityGenerator.mess_props).
func _add_mess_prop(kind: MessProp.Kind, model_path: String, at: Vector3, yaw: float, solid: bool) -> MessProp:
	var mess := MessProp.new()
	mess.position = at
	mess.rotation.y = yaw
	add_child(mess)
	mess.setup(mess_props.size(), kind, model_path, solid)
	mess_props.append(mess)
	return mess


## The old placeholder: a squashed sphere of trash (used only when a model file is missing).
func _add_trash_bag(parent: Node3D, at: Vector3, yaw: float) -> void:
	var bag := MeshInstance3D.new()
	bag.mesh = _trash_mesh
	bag.material_override = trash_material
	bag.position = at
	bag.rotation.y = yaw
	parent.add_child(bag)


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
