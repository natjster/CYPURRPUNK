class_name UndergroundHub
extends Node3D
## MEOW-CITY 1999 — THE SEWERS: the underground hub where every cat starts.
## Attach to the "Hub" node in main.tscn. That node sits 200 m BELOW the city
## (position 0, -200, 0), so the hub and the city are one world and one multiplayer game:
## going "up top" or "back down" is just moving your cat between the two.
##
## How it plays:
##   - Joining or hosting puts your cat here, at the south end of the tunnel.
##   - It's a SAFE ZONE: guns don't fire down here (see ItemManager._use_held_items).
##   - Walk up to DON CATLEONE (the boss cat at the north end) and press E to talk.
##     Pick "SEND ME UP TOP" and he sends you into the city (deploy()).
##   - COMRADE WHISKERS runs THE BLACK MARKITTEN on the west wall: the only place to get
##     gear (guns, catnip, catdip). Pay with the cash you earn extracting fish.
##     He's a Shopkeeper NPC (scripts/npcs/shopkeeper.gd); his shop is built in _build_shop().
##   - In the city, reach the green EXTRACTION beam (fish_heist.gd): your loot is cashed in
##     and you're brought back down here (return_cat()).
##
## The tunnel is built from code in _ready() (like the city), but it is always the SAME:
## it doesn't use the city seed or any randomness, so every computer builds it identically.
## Don Catleone himself is a normal NPC scene placed under this node in main.tscn
## (scenes/npcs/don_catleone.tscn, built on the NPC framework in scripts/npcs/npc.gd),
## so you can move him in the editor. Talking and the "[E] TALK" prompt are handled there.
##
## Mood: while YOUR camera is down here, the moon and rain switch off and the fog turns
## sewer-green on your screen only (_update_mood). Back up top, the night city returns.

## The one hub, so cats, items and the heist can find it (UndergroundHub.instance).
static var instance: UndergroundHub

## Anything below this height is "in the hub" (the city floor is at 0, the hub at -200).
const DEPTH_LINE: float = -100.0

@export_group("Size")
## Half the tunnel's width (metres, east-west).
@export var half_width: float = 14.0
## Half the tunnel's length (metres, north-south).
@export var half_length: float = 20.0
## Floor to ceiling (metres).
@export var height: float = 7.0
## Width of the sewage channel running down the middle.
@export var channel_width: float = 4.0

@export_group("Spawning")
## Where new cats appear, relative to the Hub node (south end, west walkway).
@export var spawn_spot: Vector3 = Vector3(-8, 0, 14)
## Where Don Catleone sends you in the city (the centre crossroads).
@export var surface_spot: Vector3 = Vector3(0, 0, 4)

@export_group("Mood")
## Fog and ambient colours while you're down here.
@export var sewer_fog_color: Color = Color(0.03, 0.07, 0.05)
@export var sewer_fog_albedo: Color = Color(0.55, 0.85, 0.65)
@export var sewer_ambient_color: Color = Color(0.35, 0.55, 0.45)
@export var sewer_ambient_energy: float = 0.6

## Don Catleone: only used here to decorate his corner (sign, lights, crates).
@onready var npc: Npc = $DonCatleone
## Comrade Whiskers: only used here to build his shop, the Black Markitten, around him.
@onready var shopkeeper: Npc = $ComradeWhiskers
@onready var _environment: Environment = $"../WorldEnvironment".environment
@onready var _moonlight: Light3D = $"../Moonlight"
@onready var _rain: GPUParticles3D = $"../Rain"

# Same trick as the city: big surfaces are cut into ~2.5 m pieces, or the PS1 texture warp
# makes them shear and swim. Boxes needing the same cuts share one mesh.
const PIECE_SIZE: float = 2.5
## Glow colours of the boxes on the Black Markitten's shelves.
const SHOP_GOODS_COLORS: Array[Color] = [Color(1, 0.35, 0.7), Color(0.3, 1, 0.35), Color(0.3, 0.8, 1), Color(1, 0.8, 0.2)]
var _box_meshes := {}
var _in_hub_view: bool = false
var _city_mood := {}  # the night-city fog/ambient values, to put back when you go up

var _concrete: ShaderMaterial
var _wall: ShaderMaterial
var _water: ShaderMaterial
var _metal: ShaderMaterial
var _cardboard: ShaderMaterial
var _crate: ShaderMaterial
var _neon: ShaderMaterial


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	_make_materials()
	_build_tunnel()
	_build_props()
	_city_mood = {
		"fog_light_color": _environment.fog_light_color,
		"volumetric_fog_albedo": _environment.volumetric_fog_albedo,
		"ambient_light_color": _environment.ambient_light_color,
		"ambient_light_energy": _environment.ambient_light_energy,
	}


## True if this spot is down in the hub (the safe zone).
static func is_in_hub(where: Vector3) -> bool:
	return where.y < DEPTH_LINE


# --- Moving cats between the hub and the city (called on the cat OWNER's computer) ---

## Where cat number n appears when it joins: rows of three on the walkway, facing Don.
func spawn_position(n: int) -> Vector3:
	return to_global(spawn_spot + Vector3((n % 3) * 1.5 - 1.5, 0, (n / 3) * 1.5))


## "SEND ME UP TOP": pop the cat out at the city's centre crossroads.
func deploy(cat: CatPlayer) -> void:
	var spread := Vector3(randf_range(-3, 3), 0, randf_range(0, 3))  # don't land on each other
	cat.teleport_to(surface_spot + spread, 0.0)
	print("[Hub] %s went up to the city" % cat.name)


## Extracted: back down the drain to the hub.
func return_cat(cat: CatPlayer) -> void:
	cat.teleport_to(spawn_position(randi() % 6), 0.0)
	print("[Hub] %s extracted back to the hub" % cat.name)


# --- Every frame: the mood (this computer only) ---

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var in_hub := camera != null and is_in_hub(camera.global_position)
	if in_hub != _in_hub_view:
		_in_hub_view = in_hub
		_update_mood(in_hub)


## Underground: no moon, no rain, green fog. Up top: the night city as it was.
func _update_mood(in_hub: bool) -> void:
	_moonlight.visible = not in_hub
	_rain.visible = not in_hub
	_rain.emitting = not in_hub
	_environment.fog_light_color = sewer_fog_color if in_hub else _city_mood.fog_light_color
	_environment.volumetric_fog_albedo = sewer_fog_albedo if in_hub else _city_mood.volumetric_fog_albedo
	_environment.ambient_light_color = sewer_ambient_color if in_hub else _city_mood.ambient_light_color
	_environment.ambient_light_energy = sewer_ambient_energy if in_hub else _city_mood.ambient_light_energy


# --- Building the tunnel ---

func _make_materials() -> void:
	var asphalt := preload("res://textures/asphalt.png")
	_concrete = _psx({"albedo_texture": asphalt, "albedo_color": Color(0.45, 0.5, 0.46), "world_uv": true, "world_uv_scale": 0.4, "specular": 0.4, "roughness": 0.4})
	_wall = _psx({"albedo_texture": asphalt, "albedo_color": Color(0.3, 0.36, 0.33), "world_uv": true, "world_uv_scale": 0.3})
	_water = _psx({"albedo_color": Color(0.03, 0.12, 0.09), "specular": 0.7, "roughness": 0.15, "emission_color": Color(0.2, 1, 0.6), "emission_energy": 0.04})
	_metal = _psx({"albedo_color": Color(0.26, 0.28, 0.3), "specular": 0.5, "roughness": 0.4})
	_cardboard = _psx({"albedo_color": Color(0.55, 0.4, 0.22)})
	_crate = _psx({"albedo_texture": preload("res://textures/neon_grid.png"), "albedo_color": Color(0.3, 0.9, 0.8)})
	_neon = _psx({"emission_color": Color.WHITE, "emission_energy": 5.0})


func _psx(params: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/psx_lit.gdshader")
	for key in params:
		material.set_shader_parameter(key, params[key])
	return material


## Floor, sewage channel, walls and ceiling. No two surfaces overlap (they'd flicker).
func _build_tunnel() -> void:
	var w := half_width
	var l := half_length
	var c := channel_width * 0.5
	var walkway := w - c  # width of each walkway

	# Walkways either side of the channel: 1 m thick slabs with their top at floor level (0).
	_add_box(Vector3(-(c + walkway * 0.5), -0.5, 0), Vector3(walkway, 1, l * 2), _concrete, true)
	_add_box(Vector3(c + walkway * 0.5, -0.5, 0), Vector3(walkway, 1, l * 2), _concrete, true)
	# Channel bottom (1 m lower) and the murky water in it (looks only — you can wade in it).
	_add_box(Vector3(0, -1.5, 0), Vector3(channel_width, 1, l * 2), _wall, true)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(channel_width, l * 2)
	plane.subdivide_width = 1
	plane.subdivide_depth = int(l * 2 / PIECE_SIZE)
	water.mesh = plane
	water.material_override = _water
	water.position = Vector3(0, -0.6, 0)
	add_child(water)
	# Two bridges over the channel (their tops line up with the walkways).
	for z in [-8.0, 8.0]:
		_add_box(Vector3(0, -0.25, z), Vector3(channel_width, 0.5, 3), _concrete, true)
		for side in [-1.0, 1.0]:  # railings
			_add_box(Vector3(0, 0.45, z + side * 1.4), Vector3(channel_width, 0.1, 0.1), _metal, false)

	# Walls and ceiling: 1 m thick boxes just outside the room.
	_add_box(Vector3(-w - 0.5, height * 0.5 - 1, 0), Vector3(1, height + 2, l * 2 + 2), _wall, true)
	_add_box(Vector3(w + 0.5, height * 0.5 - 1, 0), Vector3(1, height + 2, l * 2 + 2), _wall, true)
	_add_box(Vector3(0, height * 0.5 - 1, -l - 0.5), Vector3(w * 2, height + 2, 1), _wall, true)
	_add_box(Vector3(0, height * 0.5 - 1, l + 0.5), Vector3(w * 2, height + 2, 1), _wall, true)
	_add_box(Vector3(0, height + 0.5, 0), Vector3(w * 2 + 2, 1, l * 2 + 2), _wall, true)

	# Big pipes along the ceiling, and ribs across it every 5 m (makes it read as a tunnel).
	for x in [-w + 1.2, w - 1.2]:
		var pipe := _add_cylinder(Vector3(x, height - 1.0, 0), 0.45, l * 2, _metal)
		pipe.rotation.x = PI / 2
	for z in range(-int(l) + 5, int(l), 5):
		_add_box(Vector3(0, height - 0.3, z), Vector3(w * 2, 0.6, 0.6), _wall, false)


func _build_props() -> void:
	var w := half_width
	var l := half_length

	# Hanging work lights down both walkways: warm pools of light in the green murk.
	for z in range(-int(l) + 4, int(l), 8):
		for x in [-w + 5.0, w - 5.0]:
			_add_box(Vector3(x, height - 1.6, z), Vector3(0.05, 1.2, 0.05), _metal, false)  # cable
			var bulb := _add_box(Vector3(x, height - 2.3, z), Vector3(0.3, 0.2, 0.3), _neon, false)
			bulb.set_instance_shader_parameter("instance_tint", Color(1, 0.7, 0.35))
			_add_light(Vector3(x, height - 2.6, z), Color(1, 0.65, 0.32), 4.0, 12.0)
	# A cold cyan glow coming up off the water.
	for z in [-14.0, 0.0, 14.0]:
		_add_light(Vector3(0, -0.2, z), Color(0.2, 1, 0.7), 1.2, 6.0)

	# Signs.
	_add_sign("THE SEWERS", Vector3(0, height - 1.6, l - 0.2), Color(0.4, 1, 0.6), 64, PI)
	_add_sign("SAFE ZONE - NO SHOOTING", Vector3(0, height - 2.6, l - 0.2), Color(1, 0.8, 0.3), 32, PI)
	_add_sign("^ TO THE SURFACE ^", Vector3(-w + 6, 3.5, -l + 0.2), Color(0.4, 1, 1), 40, 0.0)

	# A ladder up the north wall to a drain grate (where Don "sends you up").
	for side in [-0.5, 0.5]:
		_add_box(Vector3(-w + 6 + side, height * 0.5, -l + 0.15), Vector3(0.08, height, 0.08), _metal, false)
	for y in range(1, int(height)):
		_add_box(Vector3(-w + 6, y, -l + 0.15), Vector3(1.0, 0.06, 0.06), _metal, false)

	# Don Catleone's corner: a sign over his spot and crates for a desk.
	var don := npc.position
	_add_sign("DON CATLEONE", Vector3(don.x, 4.2, -l + 0.2), Color(1, 0.35, 0.8), 48, 0.0)
	_add_sign("fixer - fish - favours", Vector3(don.x, 3.5, -l + 0.2), Color(1, 0.8, 0.3), 24, 0.0)
	_add_light(Vector3(don.x, 3.0, don.z + 1.0), Color(1, 0.4, 0.8), 3.0, 8.0)
	_add_light(Vector3(don.x - 1.0, 1.6, don.z + 2.0), Color(1, 0.85, 0.6), 2.0, 5.0)  # lights his face
	_add_box(Vector3(don.x + 2.2, 0.45, don.z + 0.3), Vector3(1.4, 0.9, 0.9), _crate, true)
	_add_box(Vector3(don.x + 2.2, 1.2, don.z + 0.3), Vector3(0.9, 0.6, 0.7), _crate, true)

	_build_shop()

	# THE MAINFRAME: a giant CRT computer on the west wall. Decoration for now — later,
	# players will feed it scrap for server-wide buffs.
	var frame_x := -w + 1.0
	_add_box(Vector3(frame_x, 2.5, 0), Vector3(2, 5, 6), _metal, true)
	var screen := _add_box(Vector3(frame_x + 1.15, 2.8, 0), Vector3(0.3, 2.2, 4.0), _neon, false)
	screen.set_instance_shader_parameter("instance_tint", Color(0.2, 1, 0.45))
	_add_light(Vector3(frame_x + 2.5, 2.8, 0), Color(0.2, 1, 0.45), 2.5, 8.0)
	_add_sign("THE MAINFRAME\nOVERCLOCK  OFFLINE", Vector3(frame_x + 1.35, 2.8, 0), Color(0.0, 0.06, 0.02), 32, PI / 2)

	# Cardboard-box shanties along the east wall (the "homes" of sewer cats).
	for z in [4.0, 9.0, 14.0]:
		_add_box(Vector3(w - 1.4, 0.6, z), Vector3(2.0, 1.2, 2.6), _cardboard, true)
		_add_box(Vector3(w - 1.4, 1.45, z - 0.3), Vector3(1.4, 0.5, 1.6), _cardboard, false)
	# Crates, trash and junk.
	for spot in [Vector3(-w + 1.0, 0.5, 10), Vector3(-w + 1.0, 0.5, 11.2), Vector3(-w + 1.0, 1.5, 10.6), Vector3(w - 1.0, 0.5, -4), Vector3(-4, 0.5, -17)]:
		_add_box(spot, Vector3.ONE, _crate, true)


## THE BLACK MARKITTEN: Comrade Whiskers' rebel shop on the west wall. Everything is placed
## around wherever he stands (move ComradeWhiskers under Hub in main.tscn and it follows).
## He faces east (+X); the counter is in front of him, the shelves behind him on the wall.
func _build_shop() -> void:
	var at := shopkeeper.position
	var wall_x := -half_width  # inside face of the west wall
	# The counter: a slab of metal on crates, between him and the customers.
	_add_box(Vector3(at.x + 1.3, 0.45, at.z), Vector3(0.7, 0.9, 3.2), _crate, true)
	_add_box(Vector3(at.x + 1.3, 0.95, at.z), Vector3(0.9, 0.1, 3.4), _metal, false)
	var strip := _add_box(Vector3(at.x + 1.76, 0.86, at.z), Vector3(0.04, 0.06, 3.4), _neon, false)  # glowing edge
	strip.set_instance_shader_parameter("instance_tint", Color(1, 0.15, 0.1))
	# Shelves on the wall behind him, stocked with glowing "goods".
	for shelf_y in [1.2, 2.0, 2.8]:
		_add_box(Vector3(wall_x + 0.35, shelf_y, at.z), Vector3(0.6, 0.08, 4.0), _metal, false)
		for i in 5:
			var goods := _add_box(Vector3(wall_x + 0.35, shelf_y + 0.17, at.z - 1.6 + i * 0.8), Vector3(0.3, 0.26, 0.3), _neon, false)
			goods.set_instance_shader_parameter("instance_tint", SHOP_GOODS_COLORS[(i + int(shelf_y * 10)) % SHOP_GOODS_COLORS.size()] * 0.5)
	# Crates of "merchandise that fell off a truck" stacked either side.
	for spot in [Vector3(at.x, 0.5, at.z - 2.6), Vector3(at.x, 0.5, at.z + 2.6), Vector3(at.x, 1.5, at.z + 2.6)]:
		_add_box(spot, Vector3.ONE, _crate, true)
	# A red rebel banner hanging over the shelves, and the neon shop signs above it.
	var banner := _add_box(Vector3(wall_x + 0.06, 4.0, at.z), Vector3(0.05, 1.3, 4.6), _neon, false)
	banner.set_instance_shader_parameter("instance_tint", Color(0.35, 0.02, 0.03))
	_add_sign("THE BLACK MARKITTEN", Vector3(wall_x + 0.15, 5.4, at.z), Color(1, 0.25, 0.2), 48, PI / 2)
	_add_sign("PURR-OLETARIAT
LIBERATION FRONT", Vector3(wall_x + 0.15, 4.0, at.z), Color(1, 0.8, 0.3), 24, PI / 2)
	_add_sign("NO VACUUMS
NO REFUNDS", Vector3(at.x + 1.7, 0.5, at.z), Color(1, 0.8, 0.3), 16, PI / 2)
	# Red light over the shop, and a warm one so you can see his face.
	_add_light(Vector3(at.x + 1.0, 3.2, at.z), Color(1, 0.2, 0.15), 3.0, 8.0)
	_add_light(Vector3(at.x + 2.0, 1.8, at.z), Color(1, 0.8, 0.55), 2.5, 4.5)


## A glowing text sign. "facing" turns it (0 = readable from the south / +Z side).
func _add_sign(text: String, at: Vector3, color: Color, size: int, facing: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.02
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.modulate = Color(color * 2.5, 1)  # brighter than white = it glows
	label.position = at
	label.rotation.y = facing
	add_child(label)


func _add_light(at: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.light_volumetric_fog_energy = 1.5
	light.omni_range = light_range
	add_child(light)


## Adds a box. "solid" = cats bump into it.
func _add_box(center: Vector3, size: Vector3, material: Material, solid: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _box_mesh_for(size)
	mesh.scale = size
	mesh.material_override = material
	if solid:
		var body := StaticBody3D.new()
		body.position = center
		add_child(body)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = size
		body.add_child(shape)
		body.add_child(mesh)
	else:
		mesh.position = center
		add_child(mesh)
	return mesh


func _add_cylinder(center: Vector3, radius: float, length: float, material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 6
	cylinder.rings = int(length / PIECE_SIZE)
	var mesh := MeshInstance3D.new()
	mesh.mesh = cylinder
	mesh.material_override = material
	mesh.position = center
	add_child(mesh)
	return mesh


## A 1x1x1 box cut so that, once stretched to "size", its pieces are ~PIECE_SIZE metres.
func _box_mesh_for(size: Vector3) -> BoxMesh:
	var cuts := Vector3i(
		maxi(0, ceili(size.x / PIECE_SIZE) - 1),
		maxi(0, ceili(size.y / PIECE_SIZE) - 1),
		maxi(0, ceili(size.z / PIECE_SIZE) - 1))
	if not _box_meshes.has(cuts):
		var box := BoxMesh.new()
		box.subdivide_width = cuts.x
		box.subdivide_height = cuts.y
		box.subdivide_depth = cuts.z
		_box_meshes[cuts] = box
	return _box_meshes[cuts]
