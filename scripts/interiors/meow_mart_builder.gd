class_name MeowMartBuilder
extends RefCounted
## CYPURRPUNK — Builds the inside of MEOW-MART (walls, sliding glass doors, checkouts, stepped
## aisles, can stacks, seafood counter, pressure-plate scale, heavy basket, back room and golden
## koi tank) and animates its collapsing shelves, spilled cans, tank shatter bursts and flickering
## fluorescent tubes. Called by MeowMartInterior (scripts/interiors/meow_mart_interior.gd).


## Builds the entire store interior once when MeowMartInterior._ready() runs.
static func build(mart: MeowMartInterior) -> void:
	var floor_mat := LevelKit.psx_material({"albedo_texture": preload("res://textures/mart_tiles.png"), "world_uv": true, "world_uv_scale": 0.5, "specular": 0.6, "roughness": 0.25})
	var wall_mat := LevelKit.psx_material({"albedo_color": Color(0.82, 0.86, 0.8), "specular": 0.2})
	var metal_mat := LevelKit.psx_material({"albedo_color": Color(0.35, 0.38, 0.42), "specular": 0.6, "roughness": 0.35})
	var shelf_mat := LevelKit.psx_material({"albedo_color": Color(0.9, 0.92, 0.95), "specular": 0.4, "roughness": 0.4})
	var neon_mat := LevelKit.psx_material({"emission_color": Color.WHITE, "emission_energy": 5.0})
	var tube_mat := LevelKit.psx_material({"albedo_color": Color.WHITE, "emission_color": Color.WHITE, "emission_energy": 3.0})
	mart._can_mat = LevelKit.psx_material({"albedo_color": Color.WHITE, "specular": 0.7, "roughness": 0.25})
	var ice_mat := LevelKit.psx_material({"albedo_color": Color(0.85, 0.95, 1.0), "emission_color": Color(0.5, 0.8, 1.0), "emission_energy": 0.6, "specular": 0.9, "roughness": 0.1})
	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.55, 0.85, 1.0, 0.22)
	glass_mat.metallic_specular = 0.9
	glass_mat.roughness = 0.05
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var water_mat := StandardMaterial3D.new()
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color = Color(0.15, 0.5, 1.0, 0.4)
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.05, 0.25, 0.6)
	water_mat.roughness = 0.1
	water_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mart._can_mesh = CylinderMesh.new()
	mart._can_mesh.top_radius = 0.065
	mart._can_mesh.bottom_radius = 0.065
	mart._can_mesh.height = 0.13
	mart._can_mesh.radial_segments = 6
	mart._can_mesh.rings = 0

	var shell := StaticBody3D.new()
	shell.name = "Shell"
	mart.add_child(shell)
	var room := MeowMartInterior.ROOM
	var wall := MeowMartInterior.WALL
	var half := room * 0.5
	# Floor (seen) + floor (walked on), ceiling, outer walls.
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = LevelKit.subdivided_plane(Vector2(room.x, room.z))
	floor_mesh.material_override = floor_mat
	mart.add_child(floor_mesh)
	LevelKit.add_collision(shell, Vector3(0, -0.5, 0), Vector3(room.x + wall * 2.0, 1, room.z + wall * 2.0))
	_solid_box(mart, shell, Vector3(0, room.y + wall * 0.5, 0), Vector3(room.x + wall * 2, wall, room.z + wall * 2), wall_mat)
	_solid_box(mart, shell, Vector3(-half.x - wall * 0.5, half.y, 0), Vector3(wall, room.y, room.z), wall_mat)
	_solid_box(mart, shell, Vector3(half.x + wall * 0.5, half.y, 0), Vector3(wall, room.y, room.z), wall_mat)
	_solid_box(mart, shell, Vector3(0, half.y, -half.z - wall * 0.5), Vector3(room.x, room.y, wall), wall_mat)
	_build_front(mart, shell, wall_mat, glass_mat, neon_mat, metal_mat)
	_build_back_wall(mart, shell, wall_mat, metal_mat, neon_mat)
	_build_lights(mart, tube_mat)
	_build_checkouts(mart, shell, metal_mat, neon_mat)
	for aisle in MeowMartInterior.AISLE_X.size():
		_build_aisle(mart, aisle, shelf_mat)
	_build_counter(mart, shell, metal_mat, ice_mat, glass_mat)
	_build_plate(mart, metal_mat, neon_mat)
	_build_crate(mart, metal_mat)
	_build_back_room(mart, shell, metal_mat, neon_mat, shelf_mat)
	_build_tank(mart, metal_mat, water_mat, glass_mat, ice_mat)
	mart._alarm_speaker = Node3D.new()
	mart._alarm_speaker.name = "AlarmSpeaker"
	mart._alarm_speaker.position = Vector3(0, 3.5, 0)
	mart.add_child(mart._alarm_speaker)
	mart._street_alarm = Node3D.new()
	mart._street_alarm.name = "StreetAlarm"
	mart._street_alarm.top_level = true
	mart._street_alarm.visible = false
	mart.add_child(mart._street_alarm)
	mart._street_alarm_light = LevelKit.add_light(mart._street_alarm, Vector3.ZERO, Color(1, 0.05, 0.05), 4.0, 12.0)
	var beacon := LevelKit.add_box(mart._street_alarm, Vector3.ZERO, Vector3(0.5, 0.3, 0.3), neon_mat, false)
	beacon.set_instance_shader_parameter("instance_tint", Color(1, 0.1, 0.1))


## A box cats bump into (its collision goes on "body", the store's shell: hits come to mart).
static func _solid_box(mart: MeowMartInterior, body: StaticBody3D, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := LevelKit.add_box(mart, center, size, material, false)
	LevelKit.add_collision(body, center, size)
	return mesh


## The front wall: the glass front with the sliding doors in the middle.
static func _build_front(mart: MeowMartInterior, shell: StaticBody3D, wall_mat: Material, glass_mat: Material, neon_mat: Material, metal_mat: Material) -> void:
	var room := MeowMartInterior.ROOM
	var wall := MeowMartInterior.WALL
	var glass_half := MeowMartInterior.GLASS_HALF
	var glass_h := MeowMartInterior.GLASS_HEIGHT
	var entry_half := MeowMartInterior.ENTRY_HALF_WIDTH
	var half_x := room.x * 0.5
	var z := MeowMartInterior.FRONT_Z + wall * 0.5
	for side in [-1.0, 1.0]:
		var width := half_x - glass_half
		_solid_box(mart, shell, Vector3(side * (glass_half + width * 0.5), room.y * 0.5, z), Vector3(width, room.y, wall), wall_mat)
		LevelKit.add_box(mart, Vector3(side * (entry_half + (glass_half - entry_half) * 0.5), glass_h * 0.5, z),
			Vector3(glass_half - entry_half, glass_h, 0.06), glass_mat, false)
		LevelKit.add_collision(shell, Vector3(side * (entry_half + (glass_half - entry_half) * 0.5), glass_h * 0.5, z), Vector3(glass_half - entry_half, glass_h, wall))
	_solid_box(mart, shell, Vector3(0, glass_h + (room.y - glass_h) * 0.5, z), Vector3(glass_half * 2.0, room.y - glass_h, wall), wall_mat)
	for side in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.position = Vector3(side * entry_half * 0.5, 0, z - 0.12)
		leaf.set_meta("home_x", leaf.position.x)
		leaf.set_meta("open_x", leaf.position.x + side * entry_half * 0.95)
		mart.add_child(leaf)
		LevelKit.add_box(leaf, Vector3(0, (glass_h - 0.2) * 0.5, 0), Vector3(entry_half - 0.04, glass_h - 0.2, 0.05), glass_mat, false)
		for face in [-1.0, 1.0]:
			var bar := LevelKit.add_box(leaf, Vector3(-side * entry_half * 0.35, 1.0, face * 0.045), Vector3(0.06, 0.5, 0.04), neon_mat, false)
			bar.set_instance_shader_parameter("instance_tint", Color(1, 0.1, 0.65))
		mart._door_leaves.append(leaf)
	var mat := LevelKit.add_box(mart, Vector3(0, 0.025, MeowMartInterior.FRONT_Z - 0.9), Vector3(2.2, 0.05, 1.0), metal_mat, false)
	mat.set_instance_shader_parameter("instance_tint", Color(1.0, 0.45, 0.8))


## The wall between the shop floor and the back room, with the EMPLOYEES ONLY roller door.
static func _build_back_wall(mart: MeowMartInterior, shell: StaticBody3D, wall_mat: Material, metal_mat: Material, neon_mat: Material) -> void:
	var room := MeowMartInterior.ROOM
	var wall := MeowMartInterior.WALL
	var back_z := MeowMartInterior.BACK_WALL_Z
	var door_x := MeowMartInterior.SECURITY_DOOR_X
	var door_w := MeowMartInterior.SECURITY_DOOR_WIDTH
	var door_h := MeowMartInterior.SECURITY_DOOR_HEIGHT
	var half_x := room.x * 0.5
	var door_left := door_x - door_w * 0.5
	var door_right := door_x + door_w * 0.5
	_solid_box(mart, shell, Vector3((-half_x + door_left) * 0.5, room.y * 0.5, back_z), Vector3(door_left + half_x, room.y, wall), wall_mat)
	_solid_box(mart, shell, Vector3((door_right + half_x) * 0.5, room.y * 0.5, back_z), Vector3(half_x - door_right, room.y, wall), wall_mat)
	_solid_box(mart, shell, Vector3(door_x, door_h + (room.y - door_h) * 0.5, back_z), Vector3(door_w, room.y - door_h, wall), wall_mat)
	mart._security_door = StaticBody3D.new()
	mart._security_door.name = "SecurityDoor"
	mart.add_child(mart._security_door)
	var door_z := back_z + wall * 0.5 + 0.1
	var slab := LevelKit.add_box(mart._security_door, Vector3(door_x, door_h * 0.5, door_z), Vector3(door_w + 0.1, door_h, 0.12), metal_mat, false)
	slab.set_instance_shader_parameter("instance_tint", Color(0.8, 0.8, 0.85))
	for i in 5:
		LevelKit.add_box(mart._security_door, Vector3(door_x, 0.3 + i * 0.5, door_z + 0.07), Vector3(door_w + 0.1, 0.05, 0.03), metal_mat, false)
	var stripe := LevelKit.add_box(mart._security_door, Vector3(door_x, 0.12, door_z + 0.07), Vector3(door_w + 0.1, 0.18, 0.03), neon_mat, false)
	stripe.set_instance_shader_parameter("instance_tint", Color(1, 0.75, 0.1))
	mart._security_shape = LevelKit.add_collision(mart._security_door, Vector3(door_x, door_h * 0.5, back_z), Vector3(door_w, door_h, wall + 0.3))
	var bar := LevelKit.add_box(mart, MeowMartInterior.EXIT_BUTTON_SPOT - Vector3(0, 0, 0.05), Vector3(0.6, 0.15, 0.1), neon_mat, false)
	bar.set_instance_shader_parameter("instance_tint", Color(0.2, 1, 0.4))


static func _build_lights(mart: MeowMartInterior, tube_mat: Material) -> void:
	var spots: Array[Vector3] = [Vector3(-7, 0, -0.6), Vector3(-0.75, 0, -0.6), Vector3(5.5, 0, -0.6),
		Vector3(-7, 0, 3.6), Vector3(-0.75, 0, 3.6), Vector3(5.5, 0, 3.6), Vector3(-5, 0, -3.8), Vector3(5, 0, -3.8)]
	for spot in spots:
		var tube := LevelKit.add_box(mart, Vector3(spot.x, MeowMartInterior.ROOM.y - 0.12, spot.z), Vector3(2.4, 0.08, 0.25), tube_mat, false)
		tube.set_instance_shader_parameter("instance_tint", mart.light_color)
		mart._tubes.append(tube)
		mart._lights.append(LevelKit.add_light(mart, Vector3(spot.x, MeowMartInterior.ROOM.y - 0.5, spot.z), mart.light_color, mart.light_energy, mart.light_range))
	LevelKit.add_light(mart, Vector3(-4.0, 3.4, MeowMartInterior.BACK_WALL_Z + 1.0), Color(1, 0.15, 0.6), 1.5, 6.0)
	LevelKit.add_light(mart, Vector3(MeowMartInterior.COUNTER_X - 1.2, 2.6, (MeowMartInterior.COUNTER_Z.x + MeowMartInterior.COUNTER_Z.y) * 0.5), Color(0.3, 0.8, 1), 1.4, 6.0)


static func _build_checkouts(mart: MeowMartInterior, shell: StaticBody3D, metal_mat: Material, neon_mat: Material) -> void:
	var z := MeowMartInterior.CHECKOUT_Z
	var length := MeowMartInterior.CHECKOUT_LENGTH
	for lane in MeowMartInterior.CHECKOUT_X.size():
		var x: float = MeowMartInterior.CHECKOUT_X[lane]
		var counter := _solid_box(mart, shell, Vector3(x, 0.42, z), Vector3(0.8, 0.84, length), metal_mat)
		counter.set_instance_shader_parameter("instance_tint", Color(0.5, 0.45, 0.6))
		LevelKit.add_box(mart, Vector3(x, 0.88, z + 0.25), Vector3(0.55, 0.08, length - 0.7), metal_mat, false)
		var register := LevelKit.add_box(mart, Vector3(x, 1.06, z - 0.9), Vector3(0.45, 0.4, 0.4), metal_mat, false)
		register.set_instance_shader_parameter("instance_tint", Color(0.25, 0.25, 0.3))
		var screen := LevelKit.add_box(mart, Vector3(x, 1.38, z - 0.95), Vector3(0.35, 0.22, 0.05), neon_mat, false)
		screen.set_instance_shader_parameter("instance_tint", Color(0.2, 1, 0.5))
		var scanner := LevelKit.add_box(mart, Vector3(x, 0.9, z - 0.55), Vector3(0.3, 0.04, 0.2), neon_mat, false)
		scanner.set_instance_shader_parameter("instance_tint", Color(1, 0.1, 0.1))


## One aisle: four sections (each falls on its own, dominoes), stepped like stairs.
static func _build_aisle(mart: MeowMartInterior, aisle: int, shelf_mat: Material) -> void:
	var x: float = MeowMartInterior.AISLE_X[aisle]
	var aisle_z := MeowMartInterior.AISLE_Z
	var aisle_len := MeowMartInterior.AISLE_LENGTH
	var body := StaticBody3D.new()
	body.name = "Aisle%d" % (aisle + 1)
	mart.add_child(body)
	var bottom := 0.0
	for tier in MeowMartInterior.TIERS:
		var width: float = tier[0]
		var top: float = tier[1]
		var shape := LevelKit.add_collision(body, Vector3(x, (top + bottom) * 0.5, aisle_z), Vector3(width, top - bottom, aisle_len))
		mart._aisle_shapes[aisle].append(shape)
		bottom = top
	var rubble := LevelKit.add_collision(body, Vector3.ZERO, Vector3(1.6, 0.6, aisle_len))
	rubble.disabled = true
	mart._aisle_rubble.append(rubble)

	var seg_length := aisle_len / MeowMartInterior.AISLE_SEGMENTS
	for seg in MeowMartInterior.AISLE_SEGMENTS:
		var seg_z := aisle_z - aisle_len * 0.5 + seg_length * (seg + 0.5)
		var pivot := Node3D.new()
		pivot.position = Vector3(x, 0, seg_z)
		mart.add_child(pivot)
		var inner := Node3D.new()
		pivot.add_child(inner)
		mart._segments[aisle].append({"pivot": pivot, "inner": inner, "home": pivot.position})
		bottom = 0.0
		for tier in MeowMartInterior.TIERS:
			var shelf := LevelKit.add_box(inner, Vector3(0, (float(tier[1]) + bottom) * 0.5, 0), Vector3(tier[0], float(tier[1]) - bottom, seg_length - 0.02), shelf_mat, false)
			shelf.set_instance_shader_parameter("instance_tint", Color(0.95, 0.95, 1.0) if (seg + aisle) % 2 == 0 else Color(0.85, 0.9, 1.0))
			bottom = tier[1]
		for side in [-1, 1]:
			var stack_tier := (seg + (1 if side > 0 else 0) + aisle) % 3
			var loot_tier := (stack_tier + 1) % 3
			var stock_tier := (stack_tier + 2) % 3
			var z_shift := 0.25 if side > 0 else -0.25
			_add_stack(mart, aisle, _ledge_spot(x, side, stack_tier, seg_z + z_shift))
			mart._loot_shelf.append(_ledge_spot(x, side, loot_tier, seg_z - z_shift) + Vector3(0, 0.15, 0))
			for n in 3:
				var at := _ledge_spot(0.0, side, stock_tier, (n - 1) * 0.28)
				var product := LevelKit.add_box(inner, at + Vector3(0, 0.14, 0), Vector3(0.12, 0.28, 0.2), mart._can_mat, false)
				product.set_instance_shader_parameter("instance_tint", MeowMartInterior.PRODUCT_COLORS[(seg * 3 + n + aisle * 2 + side) % MeowMartInterior.PRODUCT_COLORS.size()])


static func _ledge_spot(x: float, side: int, tier: int, z: float) -> Vector3:
	var tiers := MeowMartInterior.TIERS
	var outer: float = tiers[tier][0] * 0.5
	var inner: float = tiers[tier + 1][0] * 0.5 if tier + 1 < tiers.size() else 0.0
	return Vector3(x + side * (outer + inner) * 0.5, tiers[tier][1], z)


static func _add_stack(mart: MeowMartInterior, aisle: int, at: Vector3) -> void:
	var stack := Node3D.new()
	stack.position = at
	mart.add_child(stack)
	var id := mart._stacks.size()
	for i in 3:
		var can := MeshInstance3D.new()
		can.mesh = mart._can_mesh
		can.material_override = mart._can_mat
		can.set_instance_shader_parameter("instance_tint", MeowMartInterior.PRODUCT_COLORS[(id + i) % MeowMartInterior.PRODUCT_COLORS.size()])
		can.position = Vector3(-0.07 + 0.14 * i, 0.065, 0) if i < 2 else Vector3(0, 0.195, 0)
		can.set_meta("home", can.transform)
		stack.add_child(can)
	stack.set_meta("id", id)
	stack.set_meta("aisle", aisle)
	stack.set_meta("home", stack.transform)
	mart._stacks.append(stack)


static func _build_counter(mart: MeowMartInterior, shell: StaticBody3D, metal_mat: Material, ice_mat: Material, glass_mat: Material) -> void:
	var cx := MeowMartInterior.COUNTER_X
	var cz := MeowMartInterior.COUNTER_Z
	var length := cz.y - cz.x
	var mid := (cz.x + cz.y) * 0.5
	var body := _solid_box(mart, shell, Vector3(cx, 0.5, mid), Vector3(1.2, 1.0, length), metal_mat)
	body.set_instance_shader_parameter("instance_tint", Color(0.55, 0.7, 0.8))
	LevelKit.add_box(mart, Vector3(cx + 0.05, 1.05, mid), Vector3(1.0, 0.1, length - 0.1), ice_mat, false)
	var guard := LevelKit.add_box(mart, Vector3(cx - 0.62, 1.35, mid), Vector3(0.05, 0.5, length - 0.2), glass_mat, false)
	guard.rotation.z = deg_to_rad(-15.0)
	var show_fish := preload("res://scenes/items/sardine.tscn")
	for i in 6:
		var fish := show_fish.instantiate() as Node3D
		fish.position = Vector3(cx + 0.25, 1.13, cz.x + 0.4 + i * (length - 0.8) / 5.0)
		fish.rotation = Vector3(0, PI / 2 + (0.3 if i % 2 == 0 else -0.3), PI / 2)
		mart.add_child(fish)
	for i in 5:
		mart._loot_counter.append(Vector3(cx - 0.2, 1.25, cz.x + 0.6 + i * (length - 1.2) / 4.0))


static func _build_plate(mart: MeowMartInterior, metal_mat: Material, neon_mat: Material) -> void:
	var spot := MeowMartInterior.PLATE_SPOT
	var half := MeowMartInterior.PLATE_HALF
	var frame := LevelKit.add_box(mart, Vector3(spot.x, 0.02, spot.z), Vector3(half * 2.0 + 0.2, 0.04, half * 2.0 + 0.2), metal_mat, false)
	frame.set_instance_shader_parameter("instance_tint", Color(0.3, 0.3, 0.32))
	mart._plate_top = LevelKit.add_box(mart, Vector3(spot.x, 0.07, spot.z), Vector3(half * 2.0, 0.06, half * 2.0), neon_mat, false)
	mart._plate_light = LevelKit.add_light(mart, spot + Vector3(0, 0.8, 0), Color(1, 0.2, 0.2), 1.2, 3.5)


static func _build_crate(mart: MeowMartInterior, metal_mat: Material) -> void:
	var csize := MeowMartInterior.CRATE_SIZE
	mart._crate = StaticBody3D.new()
	mart._crate.name = "Basket"
	mart._crate.position = mart.crate_pos + Vector3(0, csize * 0.5, 0)
	mart.add_child(mart._crate)
	LevelKit.add_collision(mart._crate, Vector3.ZERO, Vector3.ONE * csize)
	var model := LevelKit.instantiate_model("res://models/cardboard_box.glb", mart._crate, Vector3(0, -csize * 0.5, 0), 0.3)
	if model != null:
		model.scale = Vector3.ONE * 1.15
	else:
		LevelKit.add_box(mart._crate, Vector3.ZERO, Vector3.ONE * csize, metal_mat, false)
	var tag := LevelKit.add_sign(mart._crate, "HEAVY", Vector3(0, csize * 0.5 + 0.25, 0), Color(1, 0.8, 0.2), 20, 0.0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED


static func _build_back_room(mart: MeowMartInterior, shell: StaticBody3D, metal_mat: Material, neon_mat: Material, shelf_mat: Material) -> void:
	var desk := _solid_box(mart, shell, Vector3(-8.5, 0.4, -4.6), Vector3(2.2, 0.8, 1.0), metal_mat)
	desk.set_instance_shader_parameter("instance_tint", Color(0.3, 0.3, 0.35))
	var monitor := LevelKit.add_box(mart, Vector3(-8.5, 1.15, -4.85), Vector3(0.9, 0.65, 0.4), metal_mat, false)
	monitor.set_instance_shader_parameter("instance_tint", Color(0.15, 0.15, 0.18))
	var screen := LevelKit.add_box(mart, Vector3(-8.5, 1.15, -4.64), Vector3(0.75, 0.5, 0.02), neon_mat, false)
	screen.set_instance_shader_parameter("instance_tint", Color(0.05, 0.3, 0.15))
	mart._monitor_label = LevelKit.add_sign(mart, "", Vector3(-8.5, 1.15, -4.6), Color(0.3, 1, 0.6), 12, 0.0)
	mart._monitor_label.pixel_size = 0.006
	LevelKit.add_light(mart, Vector3(-8.5, 1.4, -4.0), Color(0.3, 1, 0.6), 0.8, 3.0)
	for level in 3:
		_solid_box(mart, shell, Vector3(9.3, 0.05 + level * 0.8, -3.8), Vector3(1.6, 0.06, 2.6), metal_mat)
		for n in 3:
			var crate := LevelKit.add_box(mart, Vector3(9.3, 0.08 + level * 0.8 + 0.25, -4.7 + n * 0.9), Vector3(0.9, 0.5, 0.7), shelf_mat, false)
			crate.set_instance_shader_parameter("instance_tint", Color(0.7, 0.5, 0.3))
	for post in [Vector3(8.55, 0, -5.05), Vector3(10.05, 0, -5.05), Vector3(8.55, 0, -2.55), Vector3(10.05, 0, -2.55)]:
		_solid_box(mart, shell, post + Vector3(0, 1.1, 0), Vector3(0.08, 2.2, 0.08), metal_mat)


static func _build_tank(mart: MeowMartInterior, metal_mat: Material, water_mat: Material, glass_mat: StandardMaterial3D, ice_mat: Material) -> void:
	var tspot := MeowMartInterior.TANK_SPOT
	var tsize := MeowMartInterior.TANK_SIZE
	var tstand := MeowMartInterior.TANK_STAND
	var tank := HitRelay.new()
	tank.name = "KoiTank"
	tank.position = tspot
	tank.on_hit = mart._on_tank_hit
	mart.add_child(tank)
	var stand := LevelKit.add_box(tank, Vector3(0, tstand * 0.5, 0), Vector3(tsize.x + 0.2, tstand, tsize.z + 0.2), metal_mat, false)
	stand.set_instance_shader_parameter("instance_tint", Color(0.2, 0.18, 0.15))
	var plaque := LevelKit.add_sign(tank, "GOLDEN KOI\nNOT FOR SALE", Vector3(0, tstand * 0.5, tsize.z * 0.5 + 0.12), Color(1, 0.8, 0.2), 14, 0.0)
	plaque.pixel_size = 0.01
	mart._tank_water = LevelKit.add_box(tank, Vector3(0, tstand + 0.48, 0), Vector3(tsize.x - 0.08, 0.95, tsize.z - 0.08), water_mat, false)
	var glass_material := glass_mat.duplicate() as StandardMaterial3D
	mart._tank_glass = LevelKit.add_box(tank, Vector3(0, tstand + tsize.y * 0.5, 0), tsize, glass_material, false)
	mart._tank_glass.material_override = glass_material
	mart._koi = preload("res://scenes/items/golden_koi.tscn").instantiate() as Node3D
	mart._koi.scale = Vector3.ONE * 1.3
	tank.add_child(mart._koi)
	LevelKit.add_light(tank, Vector3(0, 2.8, 0.4), Color(1, 0.75, 0.25), 2.5, 6.0)
	var body := StaticBody3D.new()
	body.name = "TankBody"
	tank.add_child(body)
	mart._tank_shape = CollisionShape3D.new()
	mart._tank_shape.shape = BoxShape3D.new()
	body.add_child(mart._tank_shape)
	var water_floor := StandardMaterial3D.new()
	water_floor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_floor.albedo_color = Color(0.2, 0.5, 1.0, 0.45)
	water_floor.roughness = 0.05
	water_floor.metallic_specular = 1.0
	var puddle_mesh := CylinderMesh.new()
	puddle_mesh.top_radius = 1.5
	puddle_mesh.bottom_radius = 1.5
	puddle_mesh.height = 0.04
	puddle_mesh.radial_segments = 10
	puddle_mesh.rings = 0
	mart._puddle = MeshInstance3D.new()
	mart._puddle.mesh = puddle_mesh
	mart._puddle.material_override = water_floor
	mart._puddle.position = tspot + Vector3(0, 0.02, 0.6)
	mart._puddle.visible = false
	mart.add_child(mart._puddle)
	for i in 14:
		var shard := LevelKit.add_box(mart, tspot + Vector3(cos(i * 2.4) * (0.9 + 0.1 * (i % 4)), 0.02, sin(i * 2.4) * (0.6 + 0.1 * (i % 3)) + 0.3),
			Vector3(0.12, 0.04, 0.07), ice_mat, false)
		shard.rotation.y = i * 0.7
		shard.visible = false
		mart._shards.append(shard)


# --- Interior prop animations (can stacks, domino shelves, tank burst, flickering lights) ---

## A can stack knocked off its ledge: the cans tumble to the floor and lie there.
static func show_swatted(mart: MeowMartInterior, stack: Node3D, direction: Vector3, instant: bool) -> void:
	var home: Transform3D = stack.get_meta("home")
	var id: int = stack.get_meta("id")
	var landing := home.origin + direction * 0.8
	landing.y = 0.06
	var cans := stack.get_children()
	for i in cans.size():
		var can := cans[i] as Node3D
		var spread := Vector3(cos(id * 2.1 + i * 2.3), 0, sin(id * 1.7 + i * 2.3)) * (0.18 + 0.12 * i)
		var lying := Transform3D(Basis.from_euler(Vector3(PI / 2, id * 0.9 + i * 1.4, 0)), spread - Vector3(0, can.get_meta("home").origin.y, 0))
		if instant:
			can.transform = lying
		else:
			mart.create_tween().tween_property(can, "transform", lying, 0.35 + 0.05 * i)
	var target := Transform3D(Basis.IDENTITY, landing)
	if instant:
		stack.transform = target
	else:
		var tween := mart.create_tween()
		tween.tween_property(stack, "position", (home.origin + landing) * 0.5 + Vector3(0, 0.35, 0), 0.15)
		tween.tween_property(stack, "position", landing, 0.25).set_ease(Tween.EASE_IN)


## An aisle going down like dominoes, one section after another from the end that was hit.
static func show_toppled(mart: MeowMartInterior, aisle: int, side: int, from_end: int, instant: bool) -> void:
	var segments: Array = mart._segments[aisle]
	var order := range(segments.size())
	if from_end > 0:
		order.reverse()
	var half_base: float = MeowMartInterior.TIERS[0][0] * 0.5
	for n in order.size():
		var seg: Dictionary = segments[order[n]]
		var pivot := seg.pivot as Node3D
		pivot.position = seg.home + Vector3(side * half_base, 0, 0)
		(seg.inner as Node3D).position = Vector3(-side * half_base, 0, 0)
		var lying := Vector3(0, 0, -side * deg_to_rad(80.0))
		if instant:
			pivot.rotation = lying
		else:
			pivot.rotation = Vector3.ZERO
			var tween := mart.create_tween()
			tween.tween_interval(mart.domino_delay * n)
			tween.tween_property(pivot, "rotation", lying, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	for shape: CollisionShape3D in mart._aisle_shapes[aisle]:
		shape.disabled = true
	var rubble := mart._aisle_rubble[aisle]
	rubble.position = Vector3(MeowMartInterior.AISLE_X[aisle] + side * (half_base + 0.8), 0.3, MeowMartInterior.AISLE_Z)
	rubble.disabled = false
	for stack in mart._stacks:
		var id: int = stack.get_meta("id")
		if stack.get_meta("aisle") == aisle and not mart.swatted.has(id):
			mart.swatted[id] = true
			show_swatted(mart, stack, Vector3(side, 0, 0), instant)
	var rng := RandomNumberGenerator.new()
	rng.seed = aisle * 977 + side * 13
	var ax := MeowMartInterior.AISLE_X[aisle]
	var az := MeowMartInterior.AISLE_Z
	var alen := MeowMartInterior.AISLE_LENGTH
	for i in mart.topple_cans:
		var can := MeshInstance3D.new()
		can.mesh = mart._can_mesh
		can.material_override = mart._can_mat
		can.set_instance_shader_parameter("instance_tint", MeowMartInterior.PRODUCT_COLORS[i % MeowMartInterior.PRODUCT_COLORS.size()])
		mart.add_child(can)
		mart._spilled.append(can)
		var start := Vector3(ax, rng.randf_range(0.4, 1.5), az + rng.randf_range(-alen * 0.5, alen * 0.5))
		var land := Vector3(ax + side * rng.randf_range(0.6, 3.2), 0.06, start.z + rng.randf_range(-1.2, 1.2))
		land.z = clampf(land.z, MeowMartInterior.BACK_WALL_Z + 0.4, MeowMartInterior.FRONT_Z - 1.0)
		var lying := Basis.from_euler(Vector3(PI / 2, rng.randf() * TAU, 0))
		if instant:
			can.transform = Transform3D(lying, land)
		else:
			can.position = start
			var tween := mart.create_tween()
			tween.tween_interval(mart.domino_delay * rng.randf_range(0.0, MeowMartInterior.AISLE_SEGMENTS))
			tween.tween_property(can, "transform", Transform3D(lying, land), rng.randf_range(0.35, 0.6)).set_ease(Tween.EASE_IN)


## A one-off spray of little bits out of the tank (glass or water).
static func burst_tank(mart: MeowMartInterior, color: Color, amount: int, size: float, speed: float) -> void:
	var particles := CPUParticles3D.new()
	particles.position = MeowMartInterior.TANK_SPOT + Vector3(0, MeowMartInterior.TANK_STAND + MeowMartInterior.TANK_SIZE.y * 0.5, 0)
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = 1.2
	particles.direction = Vector3(0, 0.6, 1)
	particles.spread = 75.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -12, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.mesh = mesh
	mart.add_child(particles)
	particles.emitting = true
	mart.get_tree().create_timer(2.0).timeout.connect(particles.queue_free)


## Updates the fluorescent tubes (flicker in calm mode, red strobes during the alarm) and back-room monitor.
static func animate_lights(mart: MeowMartInterior, delta: float) -> void:
	var alarm := mart.alarm_left > 0.0
	var strobe := 0.5 + 0.5 * sin(mart._clock * TAU * 1.6)
	for i in mart._lights.size():
		var light := mart._lights[i]
		if alarm:
			light.light_color = Color(1, 0.08, 0.06)
			light.light_energy = mart.light_energy * lerpf(0.25, 1.6, strobe)
			continue
		light.light_color = mart.light_color
		if mart._fx_rng.randf() < mart.flicker_chance * delta / maxf(mart._lights.size(), 1) * 4.0:
			mart._flicker_left[i] = mart._fx_rng.randf_range(0.15, 0.5)
		var flicker := float(mart._flicker_left.get(i, 0.0))
		if flicker > 0.0:
			mart._flicker_left[i] = flicker - delta
			light.light_energy = mart.light_energy * (0.15 if mart._fx_rng.randf() < 0.5 else 1.0)
		else:
			light.light_energy = mart.light_energy
	var tube_colour := Color(1, 0.1, 0.08) * lerpf(0.3, 1.0, strobe) if alarm else mart.light_color
	for tube in mart._tubes:
		tube.set_instance_shader_parameter("instance_tint", Color(tube_colour, 1))
	if mart._monitor_label != null:
		mart._monitor_label.text = ("!! ALARM !!\nALL UNITS" if fmod(mart._clock, 1.0) < 0.6 else "") if alarm \
			else ("CAM 01  AISLE 2\nCAM 02  KOI DISPLAY\nSTATUS: CALM" if not mart.shattered else "CAM 02\nNO SIGNAL")
		mart._monitor_label.modulate = Color(Color(1, 0.15, 0.1) * 2.5, 1) if alarm or mart.shattered else Color(Color(0.3, 1, 0.6) * 2.0, 1)


## Updates the sliding front doors, security shutter, pressure plate, koi fish, basket, and street alarm.
static func animate_store(mart: MeowMartInterior, delta: float) -> void:
	if mart._placed:
		var door := mart.to_global(Vector3(0, 0, MeowMartInterior.FRONT_Z))
		var want := 0.0
		for node in Game.instance.players.get_children():
			var cat := node as Node3D
			if cat.visible and Motion.flat_distance(cat.global_position, door) < mart.door_open_distance and absf(cat.global_position.y - door.y) < 2.0:
				want = 1.0
		if want > 0.0 and mart._doors_open == 0.0:
			Sound.play_at("door_slide", door + Vector3(0, 1.5, 0), -4.0)
		mart._doors_open = move_toward(mart._doors_open, want, mart.door_slide_speed * delta)
		for leaf in mart._door_leaves:
			leaf.position.x = lerpf(leaf.get_meta("home_x"), leaf.get_meta("open_x"), MeowMartInterior._smooth(mart._doors_open))
	mart._security_amount = move_toward(mart._security_amount, 1.0 if mart.security_open else 0.0, delta * 1.6)
	mart._security_door.position.y = MeowMartInterior._smooth(mart._security_amount) * (MeowMartInterior.SECURITY_DOOR_HEIGHT - 0.35)
	animate_lights(mart, delta)
	if not mart.shattered and mart._koi != null:
		var t := mart._clock * 0.9
		mart._koi.position = Vector3(cos(t) * 0.45, MeowMartInterior.TANK_STAND + 0.55 + sin(t * 2.3) * 0.08, sin(t) * 0.3)
		mart._koi.rotation.y = -t + PI
	mart._plate_top.position.y = 0.035 if mart.plate_pressed else 0.07
	var colour := Color(0.2, 1, 0.35) if mart.plate_pressed else Color(1, 0.2, 0.2)
	mart._plate_top.set_instance_shader_parameter("instance_tint", colour)
	mart._plate_light.light_color = colour
	if mart._crate != null:
		mart._crate.position = mart._crate.position.lerp(mart.crate_pos + Vector3(0, MeowMartInterior.CRATE_SIZE * 0.5, 0), 1.0 - exp(-14.0 * delta))
	if mart.alarm_left > 0.0:
		mart.alarm_left = maxf(mart.alarm_left - delta, 0.0)
		if mart.alarm_left <= 0.0:
			mart._alarm_sounds(false)
	var street_door := mart.street_door()
	var on := mart.alarm_left > 0.0 and street_door != Vector3.INF
	mart._street_alarm.visible = on
	if on:
		mart._street_alarm.global_position = street_door + mart.street_outward() * 0.6 + Vector3(0, 3.4, 0)
		mart._street_alarm_light.light_energy = 4.0 * (0.5 + 0.5 * sin(mart._clock * TAU * 1.6))
		if mart._street_alarm_loop == null or not is_instance_valid(mart._street_alarm_loop):
			mart._street_alarm_loop = Sound.attach_loop("store_alarm", mart._street_alarm, mart.alarm_volume_db - 2.0)
