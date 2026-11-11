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
## some sidewalk corners, in the yards' junk piles and by Meow-Mart's door. THE STREET PROPS PACK
## adds fish vending machines (shopfronts + Meow-Mart), fire hydrants and neon A-frame signs (corners),
## shopping carts (Meow-Mart, yards, corners) and dumpsters (yards + Meow-Mart's side): all MESS props.
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
## STREET PROPS PACK models (tools/make_street_prop_specs.py builds them):
@export_file("*.glb") var vending_machine_model: String = "res://models/vending_machine.glb"
@export_file("*.glb") var fire_hydrant_model: String = "res://models/fire_hydrant.glb"
@export_file("*.glb") var shopping_cart_model: String = "res://models/shopping_cart.glb"
@export_file("*.glb") var neon_sign_model: String = "res://models/neon_sign_prop.glb"
@export_file("*.glb") var dumpster_model: String = "res://models/dumpster.glb"
## Chance (0-1) that a building gets a FISH VENDING MACHINE against one of its street-facing walls.
@export_range(0.0, 1.0) var vending_chance: float = 0.18
## Chance (0-1) that an empty yard has a DUMPSTER, and how many SHOPPING CARTS its junk pile gets.
@export_range(0.0, 1.0) var yard_dumpster_chance: float = 0.6
@export_range(0, 4) var yard_carts_min: int = 0
@export_range(0, 4) var yard_carts_max: int = 1
## Vending machines, hydrants and dumpsters are solid for cats (like bins). Off = walk through them.
@export var heavy_props_are_solid: bool = true
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

@export_group("Loudspeakers (OVERCLEAN's PA poles)")
## The loudspeaker pole scene (OVERCLEAN's announcements type out beside its horns).
@export_file("*.tscn") var loudspeaker_scene: String = "res://scenes/props/loudspeaker.tscn"
## Chance (0-1) that a city block gets a loudspeaker pole on one of its corners (36 blocks in a
## 6x6 city, so 0.4 = about 14 poles). 0 = no loudspeakers at all.
@export_range(0.0, 1.0) var loudspeaker_chance: float = 0.4
## How far along the kerb from the very corner a pole stands (metres; corners are ~11.5 m from
## the middle of the side, loot and payphones stay within 9 m of it).
@export var loudspeaker_along: float = 10.8

## Every MESS prop (bins, standing cones, boxes, posters, vending machines, hydrants, carts, neon
## signs, dumpsters) in the order they were built: a prop's
## place in this list is its id, the same on every computer (scripts/mess_manager.gd).
var mess_props: Array[MessProp] = []
## Every loudspeaker pole built for this city (scripts/loudspeaker.gd).
var loudspeakers: Array[Node3D] = []
## Spots already used by lamps and corner props, so a loudspeaker pole doesn't stand in them.
var _taken_spots: Array[Vector3] = []

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
## Which way is "out into the street" from Meow-Mart's door (a flat unit vector, +z or -z).
var meow_mart_outward: Vector3 = Vector3.BACK
## DISTRICT TWISTS (scripts/district_twist.gd), read when the city is built: BIN DAY's prop
## multiplier and whether it's a BLACKOUT. (The twist is set before generate() on every computer.)
var _props_x: float = 1.0
var _blackout: bool = false
## BIN DAY's EXTRA props draw their random numbers from this one (not _rng), so the rest of the
## city (buildings, lamps, the normal props) comes out exactly as it would on any other day.
var _bin_rng := RandomNumberGenerator.new()
## A street lamp's bulb with the power cut (BLACKOUT): dark grey, no glow. Made once, shared.
var _dead_bulb: ShaderMaterial
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
	loudspeakers.clear()
	_taken_spots.clear()
	# (Showcase cities = the start menu / tutorial: never twisted.)
	_props_x = 1.0 if showcase else DistrictTwist.prop_multiplier()
	_bin_rng.seed = new_seed ^ 0xB1DA7
	_blackout = DistrictTwist.is_blackout() and not showcase

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
	_place_loudspeakers(pitch)
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
	var poster_face := -1  # (0 = the x face, 1 = the z face, -1 = no poster)
	if _rng.randf() < poster_chance:
		# An OVERCLEAN poster at cat height on one of the two street-facing walls.
		var on_x_face := _rng.randf() < 0.5
		var slide := _rng.randf_range(-1, 1)
		_add_poster(center, size, street_side, on_x_face, slide)
		poster_face = 0 if on_x_face else 1
	if _rng.randf() < vending_chance:
		# A FISH VENDING MACHINE snug against a street-facing wall (the one without a poster).
		var on_x := _rng.randf() < 0.5
		if poster_face != -1:
			on_x = poster_face == 1
		_add_shopfront_vending(lot_center, lot_size, street_side, center, size, on_x, _rng.randf())


## A vending machine against a building's street-facing wall (on_x = the wall facing along x),
## its back to the wall, facing the street. "t" 0..1 = where along the wall. It stays between 1.2 m
## and 8.6 m from the middle of the block's side: clear of the mid-block lamp post (at 0) and of
## the corner props / loudspeakers (9.6 m and further out).
func _add_shopfront_vending(lot_center: Vector3, lot_size: float, street_side: Vector2, center: Vector3, size: Vector3, on_x: bool, t: float) -> void:
	if not ResourceLoader.exists(vending_machine_model):
		return
	var block_center := lot_center - Vector3(street_side.x, 0, street_side.y) * lot_size * 0.5
	var outward: Vector3
	var wall_mid: float   # the wall's middle, along the wall (world z for the x face, x for the z face)
	var wall_half: float  # half the wall's length
	var block_mid: float  # the block's middle along that same line
	if on_x:
		outward = Vector3(street_side.x, 0, 0)
		wall_mid = center.z
		wall_half = size.z * 0.5
		block_mid = block_center.z
	else:
		outward = Vector3(0, 0, street_side.y)
		wall_mid = center.x
		wall_half = size.x * 0.5
		block_mid = block_center.x
	# The allowed stretch: on the wall (0.7 m in from its ends) AND 1.2..8.6 m from the block's
	# middle, on this lot's side of it.
	var lot_sign := 1.0 if wall_mid > block_mid else -1.0
	var near := block_mid + lot_sign * 1.2
	var far := block_mid + lot_sign * 8.6
	var low := maxf(wall_mid - wall_half + 0.7, minf(near, far))
	var high := minf(wall_mid + wall_half - 0.7, maxf(near, far))
	if high <= low:
		return
	var along := lerpf(low, high, t)
	var face := center + outward * ((size.x if on_x else size.z) * 0.5)
	var spot := Vector3(face.x, 0, along) if on_x else Vector3(along, 0, face.z)
	spot += outward * 0.4  # (its back 2 cm off the wall: it's 0.75 m deep)
	_add_mess_prop(MessProp.Kind.VENDING, vending_machine_model, spot, atan2(-outward.x, -outward.z), heavy_props_are_solid)


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
	meow_mart_outward = Vector3(0, 0, street_side.y)

	# Meow-Mart's props (the loot lines up by the door, up to 2.6 m either side of it, so all of
	# these stand 3.2+ m from the door or round the side). The front pavement is only ~1 m deep, so
	# the bigger things go down the STREET-SIDE wall of the shop:
	#   front, inner half:  a FISH VENDING MACHINE against the wall + a bin at the corner
	#   front, street half: a NEON A-FRAME sign + a cone at the corner
	#   street-side wall (front to back): 1-2 SHOPPING CARTS, a box, a DUMPSTER
	if props_at_meow_mart:
		var sx := street_side.x          # +1 / -1: which side of the shop faces the street
		var o := street_side.y           # +1 / -1: which way is out of the front door
		var by_wall := front_z + o * 0.45
		var side_x := center.x + sx * 5.5  # down the street-side wall (1 m of pavement there)
		var facing_out := atan2(0.0, -o)   # a model's front (-Z) pointing out of the door
		_add_vending(Vector3(center.x - sx * 3.6, 0, front_z + o * 0.4), facing_out)
		_add_bin(Vector3(center.x - sx * 4.6, 0, by_wall), _rng.randf() * TAU)
		_add_aframe_sign(Vector3(center.x + sx * 3.5, 0, front_z + o * 0.5), facing_out + _rng.randf_range(-0.2, 0.2))
		_add_cone(Vector3(center.x + sx * 4.6, 0, by_wall), _rng.randf() * TAU, false)
		_add_cart(Vector3(side_x, 0, front_z - o * 1.2), facing_out + _rng.randf_range(-0.25, 0.25))
		if _rng.randf() < 0.5:
			_add_cart(Vector3(side_x, 0, front_z - o * 2.4), facing_out + PI + _rng.randf_range(-0.25, 0.25))
		_add_box(Vector3(side_x, 0, front_z - o * 5.4), _rng.randf() * TAU)
		# The dumpster: its back against the side wall, its front (and lid) facing the street.
		_add_dumpster(Vector3(center.x + sx * 5.66, 0, front_z - o * 7.0), atan2(-sx, 0.0))
		if _props_x > 1.0:
			# BIN DAY: more junk down the side (still clear of the fish by the door), from _bin_rng.
			_add_cone(Vector3(side_x, 0, front_z - o * 3.4), _bin_rng.randf() * TAU, false)
			_add_box(Vector3(side_x, 0, front_z - o * 4.4), _bin_rng.randf() * TAU)
			_add_bin(Vector3(side_x, 0, front_z - o * 8.7), _bin_rng.randf() * TAU)
			_add_cart(Vector3(side_x, 0, front_z - o * 9.8), facing_out + PI + _bin_rng.randf_range(-0.25, 0.25))


# --- Empty yards ---

func _build_yard(lot_center: Vector3, lot_size: float) -> void:
	var spread := lot_size * 0.5 - 2.0
	for i in _rng.randi_range(1, 4):
		var spot := lot_center + Vector3(_rng.randf_range(-spread, spread), 0.5, _rng.randf_range(-spread, spread))
		LevelKit.add_box(self, spot, Vector3.ONE, crate_material, true)
		if _rng.randf() < 0.35:  # stack one on top
			LevelKit.add_box(self, spot + Vector3(0, 1, 0), Vector3.ONE, crate_material, true)
	var dumpster_at := Vector3.INF
	if _rng.randf() < yard_dumpster_chance:  # a DUMPSTER (a MESS prop: rummage it)
		dumpster_at = lot_center + Vector3(_rng.randf_range(-spread, spread), 0, _rng.randf_range(-spread, spread))
		_add_dumpster(dumpster_at, _rng.randi_range(0, 3) * PI * 0.5)
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
	# Nothing in the pile may stand inside or right in front of the dumpster (2.1 m long: keep 2.3 m
	# from its middle, so a cat can get at it without a bin stealing the E).
	if dumpster_at != Vector3.INF:
		spots = spots.filter(func(spot: Vector3) -> bool: return Vector2(spot.x - dumpster_at.x, spot.z - dumpster_at.z).length() > 2.3)
	var bins := _rng.randi_range(yard_bins_min, maxi(yard_bins_min, yard_bins_max))
	for i in bins:
		if not spots.is_empty():
			_add_bin(spots.pop_back() + _jiggle(_rng), _rng.randf() * TAU)
	var cones := _rng.randi_range(yard_cones_min, maxi(yard_cones_min, yard_cones_max))
	for i in cones:
		if not spots.is_empty():
			_add_cone(spots.pop_back() + _jiggle(_rng), _rng.randf() * TAU, _rng.randf() < 0.4)
	var boxes := _rng.randi_range(yard_boxes_min, maxi(yard_boxes_min, yard_boxes_max))
	for i in boxes:
		if not spots.is_empty():
			_add_box(spots.pop_back() + _jiggle(_rng), _rng.randf() * TAU)
	var carts := _rng.randi_range(yard_carts_min, maxi(yard_carts_min, yard_carts_max))
	for i in carts:
		if not spots.is_empty():
			_add_cart(spots.pop_back() + _jiggle(_rng), _rng.randf() * TAU)
	# BIN DAY (scripts/district_twist.gd): the pile grows (2x = as many again), in the spots left over.
	if _props_x > 1.0:
		for i in _extra(bins):
			if not spots.is_empty():
				_add_bin(spots.pop_back() + _jiggle(_bin_rng), _bin_rng.randf() * TAU)
		for i in _extra(cones):
			if not spots.is_empty():
				_add_cone(spots.pop_back() + _jiggle(_bin_rng), _bin_rng.randf() * TAU, false)
		for i in _extra(boxes):
			if not spots.is_empty():
				_add_box(spots.pop_back() + _jiggle(_bin_rng), _bin_rng.randf() * TAU)
		for i in _extra(carts):
			if not spots.is_empty():
				_add_cart(spots.pop_back() + _jiggle(_bin_rng), _bin_rng.randf() * TAU)


## BIN DAY: how many EXTRA props to add to a normal count (2x multiplier: as many again).
func _extra(count: int) -> int:
	return roundi(count * _props_x) - count


## A small random nudge (up to 0.2 m) so a pile doesn't look laid out on a grid.
func _jiggle(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))


# --- Street props: trash bins and traffic cones (real models, made in Blockbench) ---

## Some sidewalk corners get a bin, a cone, a box, a bin AND a cone, a fire hydrant, a neon A-frame
## sign or a stray shopping cart. They stand 1.6-2 m along the
## kerb from the very corner: clear of the corner lamp posts, and outside the middle stretch of
## each sidewalk where loot and payphones go (ItemManager.random_sidewalk_spot: up to 9 m from
## the middle of a side; corners are 11.5 m out).
func _place_corner_props(pitch: float) -> void:
	# BIN DAY (scripts/district_twist.gd): a bare corner may get something after all, so that
	# (with a 2x multiplier) about twice as many corners have props. Those extra props draw their
	# random numbers from _bin_rng: the normal corners are exactly the same as on any other day.
	var extra_chance := 0.0
	if _props_x > 1.0 and corner_prop_chance < 1.0:
		extra_chance = clampf((_props_x - 1.0) * corner_prop_chance / (1.0 - corner_prop_chance), 0.0, 1.0)
	for bx in blocks_per_side:
		for bz in blocks_per_side:
			var block_center := Vector3((bx + 0.5 - blocks_per_side / 2.0) * pitch, 0, (bz + 0.5 - blocks_per_side / 2.0) * pitch)
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				if _rng.randf() < corner_prop_chance:
					_corner_prop(block_center, corner, _rng)
				elif extra_chance > 0.0 and _bin_rng.randf() < extra_chance:
					_corner_prop(block_center, corner, _bin_rng)


## One sidewalk corner's prop(s), drawn from "rng" (_rng normally, _bin_rng for BIN DAY extras).
func _corner_prop(block_center: Vector3, corner: Vector2, rng: RandomNumberGenerator) -> void:
	var in_from_edge := block_size * 0.5 - 0.5  # half a metre in from the kerb
	var along := rng.randf_range(9.6, 10.2)
	# Which of the corner's two kerbs: the one along the z axis or the one along x.
	# "back" = the way along that kerb towards the middle of the sidewalk.
	var spot: Vector3
	var back: Vector3
	var to_street: Vector3  # from this kerb out into the road
	if rng.randf() < 0.5:
		spot = block_center + Vector3(corner.x * in_from_edge, 0, corner.y * along)
		back = Vector3(0, 0, -corner.y)
		to_street = Vector3(corner.x, 0, 0)
	else:
		spot = block_center + Vector3(corner.x * along, 0, corner.y * in_from_edge)
		back = Vector3(-corner.x, 0, 0)
		to_street = Vector3(0, 0, corner.y)
	_taken_spots.append(spot)
	var roll := rng.randf()
	if roll < 0.24:
		_add_bin(spot, rng.randf() * TAU)
	elif roll < 0.42:
		_add_cone(spot, rng.randf() * TAU, rng.randf() < 0.25)
	elif roll < 0.50:
		_add_box(spot, rng.randf() * TAU)
	elif roll < 0.58:  # a bin with a cone next to it (towards the corner, away from the loot)
		_add_bin(spot, rng.randf() * TAU)
		_add_cone(spot - back * 0.8, rng.randf() * TAU, false)
	elif roll < 0.78:  # a FIRE HYDRANT right by the kerb, its front nozzle to the road
		_add_hydrant(spot + to_street * 0.15, atan2(-to_street.x, -to_street.z))
	elif roll < 0.90:  # a NEON A-FRAME SIGN facing along the pavement
		_add_aframe_sign(spot, atan2(-back.x, -back.z) + rng.randf_range(-0.3, 0.3))
	else:  # a stray SHOPPING CART somebody dumped on the corner
		_add_cart(spot, rng.randf() * TAU)


## OVERCLEAN's loudspeaker poles: each block may get one (Loudspeaker Chance), on a random corner,
## on one of that corner's two kerbs, horns facing the street. A spot too close to a lamp post or a
## corner prop tries the other kerb, then gives up. All on _rng, in a fixed order, so every
## computer builds the same poles in the same spots.
func _place_loudspeakers(pitch: float) -> void:
	if loudspeaker_chance <= 0.0 or not ResourceLoader.exists(loudspeaker_scene):
		return
	var scene := load(loudspeaker_scene) as PackedScene
	var in_from_edge := block_size * 0.5 - 0.6
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for bx in blocks_per_side:
		for bz in blocks_per_side:
			var block_center := Vector3((bx + 0.5 - blocks_per_side / 2.0) * pitch, 0, (bz + 0.5 - blocks_per_side / 2.0) * pitch)
			if _rng.randf() >= loudspeaker_chance:
				continue
			var corner: Vector2 = corners[_rng.randi_range(0, 3)]
			var first_kerb := _rng.randi_range(0, 1)
			for k in 2:
				var kerb := (first_kerb + k) % 2
				var spot: Vector3
				var outward: Vector3  # from the pole out into the street
				if kerb == 0:  # the kerb along the z axis (street to the east or west)
					spot = block_center + Vector3(corner.x * in_from_edge, 0, corner.y * loudspeaker_along)
					outward = Vector3(corner.x, 0, 0)
				else:  # the kerb along the x axis (street to the north or south)
					spot = block_center + Vector3(corner.x * loudspeaker_along, 0, corner.y * in_from_edge)
					outward = Vector3(0, 0, corner.y)
				if not _spot_is_clear(spot, 1.4):
					continue
				var pole := scene.instantiate() as Node3D
				pole.name = "Loudspeaker%d" % loudspeakers.size()
				pole.position = spot
				pole.rotation.y = atan2(-outward.x, -outward.z)  # the horns (the model's -Z) face the street
				add_child(pole)
				loudspeakers.append(pole)
				_taken_spots.append(spot)
				break


## Is nothing already standing within "room" metres of this spot (lamps, corner props, poles)?
func _spot_is_clear(spot: Vector3, room: float) -> bool:
	for taken in _taken_spots:
		if Vector2(taken.x - spot.x, taken.z - spot.z).length() < room:
			return false
	return true


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


## STREET PROPS PACK adders: each is a MESS prop (scripts/mess_prop.gd). "yaw" turns the model's
## front (-Z) to face that way. A missing model file = nothing placed (no random numbers are drawn
## in here, so the rest of the city comes out the same either way).

## A FISH VENDING MACHINE (solid for cats; kick it and a fish drops out once a district).
func _add_vending(at: Vector3, yaw: float) -> void:
	if ResourceLoader.exists(vending_machine_model):
		_add_mess_prop(MessProp.Kind.VENDING, vending_machine_model, at, yaw, heavy_props_are_solid)


## A FIRE HYDRANT (solid for cats; wrench it open for a water geyser).
func _add_hydrant(at: Vector3, yaw: float) -> void:
	if ResourceLoader.exists(fire_hydrant_model):
		_add_mess_prop(MessProp.Kind.HYDRANT, fire_hydrant_model, at, yaw, heavy_props_are_solid)


## A MEOW-MART SHOPPING CART (never solid: shove it and it rolls).
func _add_cart(at: Vector3, yaw: float) -> void:
	if ResourceLoader.exists(shopping_cart_model):
		_add_mess_prop(MessProp.Kind.CART, shopping_cart_model, at, yaw, false)


## A NEON A-FRAME sandwich-board sign (never solid: a walk knocks it flat).
func _add_aframe_sign(at: Vector3, yaw: float) -> void:
	if ResourceLoader.exists(neon_sign_model):
		_add_mess_prop(MessProp.Kind.NEON_SIGN, neon_sign_model, at, yaw, false)


## A DUMPSTER (solid for cats; rummage it: the lid flies open, maybe there's scrap).
func _add_dumpster(at: Vector3, yaw: float) -> void:
	if ResourceLoader.exists(dumpster_model):
		_add_mess_prop(MessProp.Kind.DUMPSTER, dumpster_model, at, yaw, heavy_props_are_solid)


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
	mess.powered = not _blackout  # (BLACKOUT: vending screens and neon signs stay dark)
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
	_taken_spots.append(at)
	lamp.position = at
	lamp.rotation.y = facing
	add_child(lamp)
	if _blackout:
		# BLACKOUT (scripts/district_twist.gd): the power's cut. No light, a dead grey bulb.
		(lamp.get_node("LightCone") as Light3D).visible = false
		(lamp.get_node("Bulb") as MeshInstance3D).set_surface_override_material(0, _dead_bulb_material())


## The dark grey, unlit bulb of a lamp with no power (made once, shared by every lamp).
func _dead_bulb_material() -> ShaderMaterial:
	if _dead_bulb == null:
		_dead_bulb = ShaderMaterial.new()
		_dead_bulb.shader = LevelKit.PSX_SHADER
		_dead_bulb.set_shader_parameter("albedo_color", Color(0.16, 0.15, 0.17))
		_dead_bulb.set_shader_parameter("emission_energy", 0.0)
	return _dead_bulb
