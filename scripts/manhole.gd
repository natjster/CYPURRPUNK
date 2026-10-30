class_name Manhole
extends Node3D
## CYPURRPUNK — a sewer manhole in the street: the rebellion's way in and out of the city.
## Built by fish_heist.gd for every district (you don't place these by hand):
##   - the ENTRY manhole in the centre crossroads, where Don Catleone sends you up. It's one-way:
##     it always looks closed (the rebels slam it shut behind you).
##   - the EXIT manhole somewhere else in the city. It looks closed until the heat reaches 3/4
##     (mainframe.gd exit_heat), then the lid slides aside, a green glow comes up out
##     of the hole, and walking onto it takes you (and your loot) back down to the sewers.
##
## The lid and the hole are two little pictures you can repaint:
##   textures/manhole_closed.png and textures/manhole_open.png (any size, square, round art
##   in the middle). Double-click them in the FileSystem dock to see them.
##
## The manhole is a short raised disc (a drain collar), not a flat sticker on the road: two
## flat surfaces a few centimetres apart flicker against each other (see city_generator.gd).

const CLOSED_TEXTURE: String = "res://textures/manhole_closed.png"
const OPEN_TEXTURE: String = "res://textures/manhole_open.png"
## Radius of the manhole (metres).
const RADIUS: float = 0.8
## How far it sticks up out of the road (metres).
const HEIGHT: float = 0.1
## Colour of the glow that comes up out of an open manhole.
const GLOW_COLOR: Color = Color(0.3, 1, 0.5)

## The glow colour for THIS manhole (set before it's added; fish_heist.gd gives each gang's exit
## its gang colour, so you can tell yours from the rival's).
var glow_color: Color = GLOW_COLOR
## True = lid off, glowing, and you can climb down.
var is_open: bool = false

var _closed_disc: MeshInstance3D
var _open_disc: MeshInstance3D
var _lid_aside: MeshInstance3D  # the lid, slid off to one side, while it's open
var _glow: OmniLight3D


func _ready() -> void:
	var disc := _make_disc_mesh(RADIUS, HEIGHT)
	_closed_disc = _add_disc(disc, _material(CLOSED_TEXTURE, 0.0), Vector3.ZERO)
	_open_disc = _add_disc(disc, _material(OPEN_TEXTURE, 1.5), Vector3.ZERO)
	# The lid lying next to the hole (a thinner disc, so it looks like it was shoved aside).
	_lid_aside = _add_disc(_make_disc_mesh(RADIUS, HEIGHT * 0.6), _material(CLOSED_TEXTURE, 0.0), Vector3(RADIUS * 1.9, 0, 0.3))
	_lid_aside.rotation.y = 0.7

	_glow = OmniLight3D.new()
	_glow.light_color = glow_color
	_glow.light_energy = 2.5
	_glow.light_volumetric_fog_energy = 3.0  # a green haze rising out of the hole
	_glow.omni_range = 6.0
	_glow.position = Vector3(0, 0.6, 0)
	add_child(_glow)
	set_open(is_open)


## Open (lid aside, glowing) or closed (lid on).
func set_open(open: bool) -> void:
	is_open = open
	if _closed_disc == null:
		return  # not built yet: _ready() calls this again
	_closed_disc.visible = not open
	_open_disc.visible = open
	_lid_aside.visible = open
	_glow.visible = open


func _add_disc(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node


## The game's PS1 look (psx_lit shader) with the picture on top. "glow" makes the picture
## light up by itself (the open hole's green sewer light).
func _material(texture_path: String, glow: float) -> ShaderMaterial:
	return LevelKit.psx_material({"albedo_texture": load(texture_path), "texture_glow": glow, "specular": 0.3})


## A flat-topped disc: a 16-sided top showing the whole picture (the picture's middle at the
## disc's middle), plus a thin side wall down to the road (which shows the rim colour).
func _make_disc_mesh(radius: float, height: float) -> ArrayMesh:
	const SIDES := 16
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		var p0 := Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := Vector3(cos(a1), 0, sin(a1)) * radius
		var top := Vector3(0, height, 0)
		# Top: a slice of pie from the centre (clockwise seen from above = faces up in Godot).
		tool.set_uv(Vector2(0.5, 0.5))
		tool.add_vertex(top)
		tool.set_uv(Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5))
		tool.add_vertex(p0 + top)
		tool.set_uv(Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5))
		tool.add_vertex(p1 + top)
		# Side wall: a thin strip from the road up to the top, using the picture's edge (the rim).
		var rim := Vector2(0.5 + cos(a0) * 0.49, 0.5 + sin(a0) * 0.49)
		for corner in [p0, p1, p1 + top, p0, p1 + top, p0 + top]:
			tool.set_uv(rim)
			tool.add_vertex(corner)
	tool.generate_normals()
	return tool.commit()
