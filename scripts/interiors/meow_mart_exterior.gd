class_name MeowMartExterior
extends RefCounted
## CYPURRPUNK — THE OUTSIDE OF MEOW-MART (and its big 3D set dressing).
##
## The store itself (walls, aisles, back room...) is scripts/interiors/meow_mart_interior.gd. This file
## only DRESSES it, once, when the store is built (MeowMartInterior._ready calls build):
##
##   - CLADDING: corrugated plum-metal skin over every outside wall, a parapet round the roof, and a
##     tall SIGN FACADE over the front with MEOW-MART in giant glowing letters
##   - a pink NEON FRAME round the glass front, a steel AWNING over the doors
##   - the GIANT NEON CAT HEAD on the roof (models/mart_cat_sign.glb): glowing eyes that blink
##   - OVERCLEAN SECURITY CAMERAS (models/security_cam.glb): two on the front corners, three inside,
##     slowly sweeping, red eyes glowing
##   - ROOFTOP AC UNITS (models/rooftop_ac.glb) with spinning fans
##   - inside: a row of glowing FREEZER CASES (models/freezer_case.glb) and a nest of shopping carts
##
## Nothing here is random (every computer builds the same store). Colours and sizes are on the
## MeowMart node: Main > MeowMart > Inspector > "Outside". The models are made from recipes:
## tools/make_meow_mart_specs.py (then `python tools/cypurr_models.py all tools/model_specs/<name>.json`).

const CLAD := 0.12            ## how thick the outside skin is (metres)
const PARAPET := 0.7          ## how far the walls stand up above the roof
const FACADE_TOP := 7.2       ## the top of the sign facade over the front (store coordinates)


## Dress the store (called once from MeowMartInterior._ready, after the inside is built).
static func build(mart: MeowMartInterior) -> void:
	var outside := StaticBody3D.new()  # (cats and cars bump into the skin, not 12 cm inside it)
	outside.name = "Outside"
	mart.add_child(outside)
	var clad_mat := LevelKit.psx_material({"albedo_texture": preload("res://textures/mart_cladding.png"),
		"world_uv": true, "world_uv_scale": 0.5, "specular": 0.35, "roughness": 0.5})
	var roof_mat := LevelKit.psx_material({"albedo_texture": preload("res://textures/asphalt.png"),
		"world_uv": true, "world_uv_scale": 0.4, "albedo_color": Color(0.55, 0.5, 0.6)})
	var neon_mat := LevelKit.psx_material({"emission_color": Color.WHITE, "emission_energy": 5.0})
	var steel_mat := LevelKit.psx_material({"albedo_color": Color(0.22, 0.22, 0.27), "specular": 0.6, "roughness": 0.35})
	_build_skin(mart, outside, clad_mat, roof_mat, steel_mat)
	_build_front_dressing(mart, outside, neon_mat, steel_mat)
	_build_roof_pieces(mart, outside)
	_build_cameras(mart)
	_build_inside_pieces(mart)


# --- The skin: walls, roof, parapet, sign facade ---

static func _build_skin(mart: MeowMartInterior, body: StaticBody3D, clad_mat: Material, roof_mat: Material, steel_mat: Material) -> void:
	var half := MeowMartInterior.outer_size() * 0.5            # the inside walls' outer faces
	var low := -MeowMartInterior.FLOOR_LIFT                   # street level
	var roof := MeowMartInterior.ROOM.y + MeowMartInterior.WALL
	var wall_top := roof + PARAPET
	var tint := mart.cladding_tint
	var long_x := half.x * 2.0 + CLAD * 2.0
	# Sides and back (from the street up to the parapet).
	for side in [-1.0, 1.0]:
		_skin_box(mart, body, Vector3(side * (half.x + CLAD * 0.5), (low + wall_top) * 0.5, 0),
			Vector3(CLAD, wall_top - low, half.z * 2.0 + CLAD * 2.0), clad_mat, tint)
	_skin_box(mart, body, Vector3(0, (low + wall_top) * 0.5, -half.z - CLAD * 0.5), Vector3(long_x, wall_top - low, CLAD), clad_mat, tint)
	# The front: round the glass, and up to the top of the sign facade.
	var z := half.z + CLAD * 0.5
	var glass := MeowMartInterior.GLASS_HALF
	var glass_top := MeowMartInterior.GLASS_HEIGHT
	var piece := half.x + CLAD - glass
	for side in [-1.0, 1.0]:
		_skin_box(mart, body, Vector3(side * (glass + piece * 0.5), (low + FACADE_TOP) * 0.5, z),
			Vector3(piece, FACADE_TOP - low, CLAD), clad_mat, tint)
	_skin_box(mart, body, Vector3(0, (glass_top + FACADE_TOP) * 0.5, z), Vector3(glass * 2.0, FACADE_TOP - glass_top, CLAD), clad_mat, tint)
	# The roof (a dark tar skin on top of the ceiling), with a steel cap along the parapet tops.
	LevelKit.add_box(mart, Vector3(0, roof + 0.05, 0), Vector3(half.x * 2.0, 0.1, half.z * 2.0), roof_mat, false)
	LevelKit.add_collision(body, Vector3(0, roof + 0.05, 0), Vector3(half.x * 2.0, 0.1, half.z * 2.0))
	for side in [-1.0, 1.0]:
		LevelKit.add_box(mart, Vector3(side * (half.x + CLAD * 0.5), wall_top + 0.04, 0), Vector3(CLAD + 0.06, 0.08, half.z * 2.0 + CLAD * 2.0), steel_mat, false)
	LevelKit.add_box(mart, Vector3(0, wall_top + 0.04, -half.z - CLAD * 0.5), Vector3(long_x + 0.06, 0.08, CLAD + 0.06), steel_mat, false)
	LevelKit.add_box(mart, Vector3(0, FACADE_TOP + 0.05, z), Vector3(long_x + 0.06, 0.1, CLAD + 0.08), steel_mat, false)
	# The doorway sill (the store's floor is 6 cm up: this fills the step under the glass front).
	var sill := LevelKit.add_box(mart, Vector3(0, low * 0.5, half.z - MeowMartInterior.WALL * 0.5 + CLAD * 0.5),
		Vector3(glass * 2.0, -low, MeowMartInterior.WALL + CLAD), steel_mat, false)
	sill.set_instance_shader_parameter("instance_tint", Color(0.7, 0.7, 0.75))


static func _skin_box(mart: MeowMartInterior, body: StaticBody3D, center: Vector3, size: Vector3, material: Material, tint: Color) -> void:
	var mesh := LevelKit.add_box(mart, center, size, material, false)
	mesh.set_instance_shader_parameter("instance_tint", tint)
	LevelKit.add_collision(body, center, size)


# --- The front: big letters, the neon door frame, the awning, the glow ---

static func _build_front_dressing(mart: MeowMartInterior, _body: StaticBody3D, neon_mat: Material, steel_mat: Material) -> void:
	var half := MeowMartInterior.outer_size() * 0.5
	var face_z := half.z + CLAD                                # the outside of the front skin
	var glass := MeowMartInterior.GLASS_HALF
	var glass_top := MeowMartInterior.GLASS_HEIGHT
	var pink := mart.sign_color
	var cyan := mart.trim_color
	# MEOW-MART in giant glowing letters across the facade...
	var title := LevelKit.add_sign(mart, "MEOW-MART", Vector3(0, 5.75, face_z + 0.06), pink, 64, 0.0)
	title.pixel_size = 0.032
	# ...and the small print under it.
	var strap := LevelKit.add_sign(mart, "24/7  *  FISH  *  CATNIP  *  NO DOGS", Vector3(0, 4.3, face_z + 0.06), cyan, 32, 0.0)
	strap.pixel_size = 0.016
	# Neon strips: along the top of the facade, down both front corners, and a frame round the glass.
	var strips: Array = [
		[Vector3(0, FACADE_TOP - 0.15, face_z + 0.04), Vector3(half.x * 2.0, 0.1, 0.06), pink],
		[Vector3(0, 3.75, face_z + 0.04), Vector3(half.x * 2.0 - 1.0, 0.06, 0.06), cyan],
		[Vector3(-half.x - CLAD + 0.08, FACADE_TOP * 0.5, face_z + 0.04), Vector3(0.1, FACADE_TOP - 0.2, 0.06), pink],
		[Vector3(half.x + CLAD - 0.08, FACADE_TOP * 0.5, face_z + 0.04), Vector3(0.1, FACADE_TOP - 0.2, 0.06), pink],
		[Vector3(0, glass_top + 0.06, face_z + 0.04), Vector3(glass * 2.0 + 0.24, 0.1, 0.06), pink],
		[Vector3(-glass - 0.06, glass_top * 0.5, face_z + 0.04), Vector3(0.1, glass_top, 0.06), pink],
		[Vector3(glass + 0.06, glass_top * 0.5, face_z + 0.04), Vector3(0.1, glass_top, 0.06), pink],
	]
	for strip in strips:
		var box := LevelKit.add_box(mart, strip[0], strip[1], neon_mat, false)
		box.set_instance_shader_parameter("instance_tint", strip[2])
	# The awning: a slab of steel over the doors (high enough for cars and cats to pass under),
	# with a neon strip along its edge and a light under it.
	var awning := LevelKit.add_box(mart, Vector3(0, glass_top + 0.32, face_z + 0.75), Vector3(glass * 2.0 + 0.8, 0.12, 1.5), steel_mat, false)
	awning.rotation.x = deg_to_rad(-8.0)
	var lip := LevelKit.add_box(mart, Vector3(0, glass_top + 0.2, face_z + 1.5), Vector3(glass * 2.0 + 0.8, 0.08, 0.06), neon_mat, false)
	lip.set_instance_shader_parameter("instance_tint", cyan)
	for side in [-1.0, 1.0]:  # two steel struts holding it to the wall
		var strut := LevelKit.add_box(mart, Vector3(side * (glass + 0.2), glass_top + 0.85, face_z + 0.6), Vector3(0.06, 0.06, 1.4), steel_mat, false)
		strut.rotation.x = deg_to_rad(35.0)
	LevelKit.add_light(mart, Vector3(0, glass_top - 0.2, face_z + 1.0), Color(1, 0.75, 0.95), 1.6, 5.0)
	# The glow on the street: pink washing the facade, cyan pools at the corners.
	LevelKit.add_light(mart, Vector3(0, 5.5, face_z + 2.2), pink, 3.0, 11.0)
	for side in [-1.0, 1.0]:
		LevelKit.add_light(mart, Vector3(side * (half.x - 1.0), 2.0, face_z + 1.2), cyan, 1.4, 6.0)


# --- The roof: the giant cat head, the AC units ---

static func _build_roof_pieces(mart: MeowMartInterior, body: StaticBody3D) -> void:
	var roof := MeowMartInterior.ROOM.y + MeowMartInterior.WALL + 0.1
	# THE CAT HEAD (its front is -Z in the model: turned round to face the street).
	var head := LevelKit.instantiate_model("res://models/mart_cat_sign.glb", mart, Vector3(0, roof, 1.2), PI)
	if head != null:
		head.scale = Vector3.ONE * mart.cat_sign_scale
		LevelKit.make_neon_paint_glow(head, {"Neon": 4.0, "Eyes": 6.0})
		var eyes := head.find_child("Eyes", true, false) as Node3D
		if eyes != null:  # the eyes blink now and then (looks only)
			var blink := mart.create_tween().set_loops()
			blink.tween_interval(3.6)
			blink.tween_property(eyes, "scale:y", 0.08, 0.07)
			blink.tween_property(eyes, "scale:y", 1.0, 0.09)
			blink.tween_interval(0.25)
			blink.tween_property(eyes, "scale:y", 0.08, 0.07)
			blink.tween_property(eyes, "scale:y", 1.0, 0.09)
		LevelKit.add_light(mart, Vector3(0, roof + 3.2 * mart.cat_sign_scale, 3.2), mart.sign_color, 3.5, 12.0)
		LevelKit.add_light(mart, Vector3(0, roof + 3.2 * mart.cat_sign_scale, 2.2), Color(0.35, 1, 0.7), 1.5, 5.0)
	# The AC units, with spinning fans.
	var units: Array = [[Vector3(-7.0, roof, -3.0), 0.0], [Vector3(-4.6, roof, -3.4), 0.2], [Vector3(6.8, roof, -2.6), PI / 2], [Vector3(8.6, roof, -3.8), PI / 2]]
	for i in units.size():
		var unit := LevelKit.instantiate_model("res://models/rooftop_ac.glb", mart, units[i][0], units[i][1])
		if unit == null:
			continue
		LevelKit.add_collision(body, units[i][0] + Vector3(0, 0.55, 0), Vector3(1.5, 1.1, 1.5))
		var fan := unit.find_child("Fan", true, false) as Node3D
		if fan != null:
			var spin := mart.create_tween().set_loops()
			spin.tween_property(fan, "rotation:y", TAU * (1.0 if i % 2 == 0 else -1.0), 0.9 + 0.2 * i).as_relative()


# --- OVERCLEAN's security cameras (they sweep; they don't do anything... yet) ---

static func _build_cameras(mart: MeowMartInterior) -> void:
	var half := MeowMartInterior.outer_size() * 0.5
	var room := MeowMartInterior.ROOM * 0.5
	# [where (the wall plate), facing (the yaw the lens looks along), sweep phase]
	var cams: Array = [
		[Vector3(-half.x + 0.4, 3.4, half.z + CLAD), PI + 0.5, 0.0],    # outside, front-left corner, looking out at the street
		[Vector3(half.x - 0.4, 3.4, half.z + CLAD), PI - 0.5, 1.7],     # outside, front-right corner
		[Vector3(-room.x + 0.5, 3.9, room.z), -0.6, 0.6],               # inside, by the door, looking up the store
		[Vector3(room.x - 0.5, 3.9, room.z), 0.6, 2.4],
		[Vector3(-2.5, 3.6, -room.z), PI - 0.4, 1.1],                   # the back room, watching the koi tank
	]
	for cam in cams:
		# The model's wall plate is on its +Z side: its yaw puts the lens (-Z) along "facing".
		var model := LevelKit.instantiate_model("res://models/security_cam.glb", mart, cam[0], cam[1])
		if model == null:
			continue
		model.scale = Vector3.ONE * 1.3
		LevelKit.make_neon_paint_glow(model, {"Lens": 6.0})
		var head := model.find_child("Head", true, false) as Node3D
		if head != null:
			head.rotation = Vector3(deg_to_rad(-20.0), -mart.camera_sweep, 0)
			var sweep := mart.create_tween().set_loops()
			sweep.tween_interval(float(cam[2]))  # (so they don't all turn together)
			sweep.tween_property(head, "rotation:y", mart.camera_sweep, 3.2).set_trans(Tween.TRANS_SINE)
			sweep.tween_interval(1.2)
			sweep.tween_property(head, "rotation:y", -mart.camera_sweep, 3.2).set_trans(Tween.TRANS_SINE)
			sweep.tween_interval(1.2)


# --- Inside: freezers along the back wall, a nest of shopping carts by the door ---

static func _build_inside_pieces(mart: MeowMartInterior) -> void:
	var body := StaticBody3D.new()
	body.name = "Fittings"
	mart.add_child(body)
	var back := MeowMartInterior.BACK_WALL_Z + MeowMartInterior.WALL * 0.5   # the shop side of the back wall
	# Freezer cases (2 m wide, 0.8 m deep; turned round so their doors face the shop).
	for x in [-8.9, -6.8]:
		var at := Vector3(x, 0, back + 0.42)
		var freezer := LevelKit.instantiate_model("res://models/freezer_case.glb", mart, at, PI)
		if freezer == null:
			continue
		LevelKit.make_neon_paint_glow(freezer, {"Glow": 2.2})
		LevelKit.add_collision(body, at + Vector3(0, 1.1, 0), Vector3(2.0, 2.2, 0.8))
	LevelKit.add_light(mart, Vector3(-7.85, 1.6, back + 1.6), Color(0.5, 0.85, 1.0), 1.4, 4.5)
	# Shopping carts nested by the door (east of it, out of the way).
	var front := MeowMartInterior.FRONT_Z
	for i in 3:
		var at := Vector3(4.4 + i * 0.32, 0, front - 0.75)
		var cart := LevelKit.instantiate_model("res://models/shopping_cart.glb", mart, at, -PI / 2)
		if cart == null:
			break
	LevelKit.add_collision(body, Vector3(4.72, 0.5, front - 0.75), Vector3(1.5, 1.0, 0.6))
