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
##   LevelKit.instantiate_model("res://models/trash_bin.glb", parent, pos, yaw) - a Blockbench model
##   LevelKit.psx_ify(node)                                      - give a model the PS1 look
##   LevelKit.make_parts_glow(model, {"Eye": Color.CYAN}, 5.0)   - whole parts of a model glow
##   LevelKit.make_neon_paint_glow(model, {"Barrel": 3.0})       - only a part's bright painted pixels glow
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
## Models already loaded from res://models/: path -> PackedScene (each file is read once).
static var _models := {}
## PS1 materials made from a model's own materials: original material -> ShaderMaterial, so every
## copy of a trash bin shares ONE material (cheap to draw, like the shared boxes).
static var _psx_copies := {}


# --- Real models (.glb files made in Blockbench, see SETUP_GUIDE "Models from Blockbench") ---

## Puts a copy of a .glb model under "parent" at "pos", turned "yaw" radians around the vertical
## axis, with the game's PS1 look already on it (psx_ify). "path" can be the full
## "res://models/trash_bin.glb" or just "trash_bin". Returns the new model (null if the file is
## missing). parent = null: the model isn't added anywhere; add it yourself.
## The model has NO collision: add one with LevelKit.add_collision on a StaticBody3D if cats
## should bump into it (city_generator.gd does that for the trash bins).
static func instantiate_model(path: String, parent: Node3D = null, pos: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> Node3D:
	if not path.begins_with("res://"):
		path = "res://models/%s%s" % [path, "" if path.ends_with(".glb") else ".glb"]
	if not _models.has(path):
		var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
		if scene == null:
			push_warning("[LevelKit] No model at %s (export it from Blockbench as .glb into res://models/)" % path)
			_models[path] = null
		else:
			_models[path] = scene
	var packed: PackedScene = _models[path]
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	psx_ify(model)
	model.position = pos
	model.rotation.y = yaw
	if parent != null:
		parent.add_child(model)
	return model


## Gives every mesh under "root" the PS1 look (shaders/psx_lit.gdshader): wobbly vertices, flat
## shading, crisp pixels. Each surface keeps its painted texture (albedo_texture), its colour
## (albedo_color) and its own UV map (world_uv = false), so a model painted in Blockbench looks
## like it did there, just PS1. Per-copy colour still works with "instance_tint".
static func psx_ify(root: Node) -> void:
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var original := mesh_instance.get_active_material(surface)
			mesh_instance.set_surface_override_material(surface, _psx_copy_of(original))


## Makes parts of a psx_ify'd model GLOW. "parts" = {part name: Color}: a part is a Blockbench
## group (= a node in the .glb, found anywhere under "root"). The whole part glows that colour at
## "energy" brightness and its painted pixels still show inside the glow. Each part gets its own
## material copy, so a script may change the colour later (the VAC-COP's eye, a gun's laser).
static func make_parts_glow(root: Node, parts: Dictionary, energy: float) -> void:
	for part_name in parts:
		for mesh in _part_meshes(root, str(part_name)):
			for surface in mesh.mesh.get_surface_count():
				var glow := (mesh.get_active_material(surface) as ShaderMaterial).duplicate() as ShaderMaterial
				glow.set_shader_parameter("albedo_color", Color(0.2, 0.2, 0.2))
				glow.set_shader_parameter("emission_color", parts[part_name])
				glow.set_shader_parameter("emission_energy", energy)
				glow.set_shader_parameter("emission_textured", true)  # the pixel-art scanlines show in the glow
				mesh.set_surface_override_material(surface, glow)


## Makes only the BRIGHT pixels painted on some parts glow, each in its own painted colour: neon
## tubes, frost, lit vent slits. "parts" = {part name: strength} (1 = soft, 4 = blazing). The dark
## metal around them stays dark.
static func make_neon_paint_glow(root: Node, parts: Dictionary) -> void:
	for part_name in parts:
		for mesh in _part_meshes(root, str(part_name)):
			for surface in mesh.mesh.get_surface_count():
				var neon := (mesh.get_active_material(surface) as ShaderMaterial).duplicate() as ShaderMaterial
				neon.set_shader_parameter("texture_glow", float(parts[part_name]))
				mesh.set_surface_override_material(surface, neon)


## Recolours one part of a psx_ify'd model: its painted pixels are multiplied by "color" (paint the
## part in greys/white in Blockbench, then the Inspector colour decides its real colour).
## Used by the litterbox (hub.gd _build_stash: Litterbox Color, Sand Color).
static func tint_part(root: Node, part_name: String, color: Color) -> void:
	for mesh in _part_meshes(root, part_name):
		mesh.set_instance_shader_parameter("instance_tint", color)


## Tints and lights up one MeshInstance3D part by name (cars, recruit homes): tinted_glow = true
## makes the whole part emit "tint"; false makes only its bright painted pixels glow ("texture_glow").
static func glow_part(root: Node, part_name: String, tint: Color, energy: float, tinted_glow: bool) -> void:
	var part := root.find_child(part_name, true, false) as MeshInstance3D
	if part == null or part.mesh == null:
		return
	for surface in part.mesh.get_surface_count():
		var material := part.get_active_material(surface)
		if not material is ShaderMaterial:
			continue
		var copy := material.duplicate() as ShaderMaterial
		copy.set_shader_parameter("albedo_color", tint)
		if tinted_glow:
			copy.set_shader_parameter("emission_color", tint)
			copy.set_shader_parameter("emission_energy", energy)
		else:
			copy.set_shader_parameter("texture_glow", energy)
		part.set_surface_override_material(surface, copy)


## The meshes of one part: the node with that name (a path from root, or found anywhere below it)
## plus every mesh under it. Only meshes that already have the PS1 material (psx_ify first).
static func _part_meshes(root: Node, part_name: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var part := root.get_node_or_null(NodePath(part_name))
	if part == null:
		part = root.find_child(part_name, true, false)
	if part == null:
		return out
	var nodes: Array[Node] = part.find_children("*", "MeshInstance3D", true, false)
	if part is MeshInstance3D:
		nodes.append(part)
	for node in nodes:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.get_active_material(0) is ShaderMaterial:
			out.append(mesh)
	return out


## The shared PS1 version of a model's material (made the first time it's asked for).
static func _psx_copy_of(original: Material) -> ShaderMaterial:
	if original is ShaderMaterial and (original as ShaderMaterial).shader == PSX_SHADER:
		return original  # already PS1
	var key: Variant = "none"
	if original != null:
		key = original
	if _psx_copies.has(key):
		return _psx_copies[key]
	var params := {"world_uv": false}
	var standard := original as BaseMaterial3D
	if standard != null:
		if standard.albedo_texture != null:
			params["albedo_texture"] = standard.albedo_texture
		params["albedo_color"] = standard.albedo_color
		if standard.emission_enabled:
			params["emission_color"] = standard.emission
			params["emission_energy"] = standard.emission_energy_multiplier
	var material := psx_material(params)
	_psx_copies[key] = material
	return material


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
static func add_collision(body: CollisionObject3D, at: Vector3, size: Vector3) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = at
	body.add_child(shape)
	return shape


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


## Unshaded, additive, vertex-colored ImmediateMesh in world space (speed streaks, claw marks, swing trails).
static func add_trail_mesh(parent: Node, node_name: String) -> Dictionary:
	var mesh := ImmediateMesh.new()
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.top_level = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	node.material_override = material
	parent.add_child(node)
	return {"mesh": mesh, "node": node}
