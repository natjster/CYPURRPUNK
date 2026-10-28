class_name LevelKit
## THE LEVEL-BUILDING KIT: the building blocks every code-built place uses (the city,
## THE SEWERS hub, the manholes...), so they all follow the same PS1 rules. Static: call them as
## LevelKit.add_box(self, ...) from any Node3D script; "parent" is the node the piece goes under.
##
##   LevelKit.psx_material({"albedo_color": Color.RED, "specular": 0.5})  - the game's PS1 look
##   LevelKit.add_box(parent, center, size, material, solid)    - a box (solid = cats bump into it)
##   LevelKit.add_cylinder(parent, center, radius, length, material) - a pipe / pillar (no collision)
##   LevelKit.add_light(parent, at, color, energy, light_range[, fade_from])  - a glowing light pool
##   LevelKit.add_sign(parent, text, at, color, font_size, facing)  - glowing neon letters
##   LevelKit.subdivided_plane(size)                             - a flat ground piece
##
## THE TWO RULES these keep for you:
##   1. Big surfaces are cut into pieces of about PIECE_SIZE metres. The PS1 shader's wobbly
##      texture mapping makes textures on big triangles shear and "swim", so never build a big
##      wall or floor from one plain BoxMesh / PlaneMesh: use these.
##   2. Boxes needing the same number of cuts SHARE one mesh (stretched to size), which saves
##      memory in a city of hundreds of boxes. Per-box colour = the shader's "instance_tint"
##      (box.set_instance_shader_parameter("instance_tint", Color(...))), not a new material.
## And one rule they can't keep for you: never put two visible surfaces a few cm apart (e.g. a
## floor on top of a floor). They fight over which is in front and flicker.
##
## The kit has no randomness, so the city (which must come out identical on every computer
## from its seed) can use it freely.

## Roughly how big each cut piece of a surface is (metres).
const PIECE_SIZE: float = 2.5
const PSX_SHADER: Shader = preload("res://shaders/psx_lit.gdshader")

## The shared 1x1x1 boxes, by how many cuts they have (see box_mesh_for).
static var _box_meshes := {}


## A material with the game's PS1 look (shaders/psx_lit.gdshader). "params" = the shader's
## settings, e.g. {"albedo_texture": tex, "albedo_color": Color(...), "world_uv": true,
## "specular": 0.4, "roughness": 0.4, "emission_color": Color.WHITE, "emission_energy": 5.0}.
static func psx_material(params: Dictionary = {}) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PSX_SHADER
	for key in params:
		material.set_shader_parameter(key, params[key])
	return material


## Adds a box. "solid" = cats and cars bump into it (it gets a StaticBody3D + collision box).
static func add_box(parent: Node3D, center: Vector3, size: Vector3, material: Material, solid: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = box_mesh_for(size)
	mesh.scale = size
	mesh.material_override = material
	if solid:
		var body := StaticBody3D.new()
		body.position = center
		parent.add_child(body)
		add_collision(body, Vector3.ZERO, size)
		body.add_child(mesh)
	else:
		mesh.position = center
		parent.add_child(mesh)
	return mesh


## A box-shaped collision (no look) on "body", centred at "at" (relative to the body).
static func add_collision(body: CollisionObject3D, at: Vector3, size: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = at
	body.add_child(shape)


## A 1x1x1 box cut so that, once stretched to "size", its pieces are ~PIECE_SIZE metres.
static func box_mesh_for(size: Vector3) -> BoxMesh:
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


## A flat ground piece of "size" metres (x by z), cut into ~PIECE_SIZE pieces. Two pieces with
## an edge of the same length share their corner points exactly, so no cracks appear between.
static func subdivided_plane(size: Vector2) -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = maxi(0, ceili(size.x / PIECE_SIZE) - 1)
	plane.subdivide_depth = maxi(0, ceili(size.y / PIECE_SIZE) - 1)
	return plane


## A six-sided pipe or pillar along its Y axis (rotate the result to lay it down). No collision.
static func add_cylinder(parent: Node3D, center: Vector3, radius: float, length: float, material: Material) -> MeshInstance3D:
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
	parent.add_child(mesh)
	return mesh


## A coloured light that glows into the fog. fade_from > 0 = it fades out between fade_from and
## fade_from + 10 metres from the camera (use it when there are lots of them: lights are the
## expensive part).
static func add_light(parent: Node3D, at: Vector3, color: Color, energy: float, light_range: float, fade_from: float = 0.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.light_volumetric_fog_energy = 1.5
	light.omni_range = light_range
	if fade_from > 0.0:
		light.distance_fade_enabled = true
		light.distance_fade_begin = fade_from
		light.distance_fade_length = 10.0
	parent.add_child(light)
	return light


## Glowing neon letters (a Label3D), facing = turn around the vertical axis (radians).
static func add_sign(parent: Node3D, text: String, at: Vector3, color: Color, font_size: int, facing: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.02
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.modulate = Color(color * 2.5, 1)  # brighter than white = it glows
	label.position = at
	label.rotation.y = facing
	parent.add_child(label)
	return label
