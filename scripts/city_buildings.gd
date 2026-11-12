class_name CityBuildings
extends RefCounted
## CYPURRPUNK — the different BUILDING STYLES the city is made of (called by city_generator.gd).
##
## Every building used to be one plain box. Now each lot rolls one of five styles:
##   BOX       the old plain block (still the most common).
##   SETBACK   a stepped "wedding cake" skyscraper: 3 shrinking tiers with ledges + a red-tipped antenna.
##   SHOPHOUSE a short noodle-shop walk-up: a glowing coloured awning over the sidewalk, AC units
##             stuck on the back walls and a wooden-looking water tower on the roof.
##   TWIN      twin towers on a shared base, joined high up by a glowing SKYBRIDGE.
##   CORP      an OVERCLEAN office block: neon strips running up its corners and a lit
##             BILLBOARD on the roof shouting a slogan at the street.
##
## They're all built from the same PS1 boxes as before (LevelKit), with the same window texture
## (the building material maps its windows in world space, so any shape gets neat window rows).
##
## IMPORTANT (multiplayer): every random choice comes from the city's own random number generator
## (city._rng), always in the same order, so every computer builds the exact same buildings.
##
## The GROUND FLOOR of every style is the full footprint the old box had (and at least 10 m tall for
## the tall styles), so neon signs, OVERCLEAN posters and vending machines still sit flat on a wall.
## The tuning knobs (how common each style is) are on the City node: Inspector > Building styles.

enum Style { BOX, SETBACK, SHOPHOUSE, TWIN, CORP }

## Slogans for the CORP billboards (OVERCLEAN's propaganda).
const BILLBOARD_SLOGANS: Array[String] = [
	"STAY CLEAN", "OVERCLEAN", "OBEY THE VAC", "NO PAWS", "SCRUB. SMILE.", "LITTER = CRIME",
]
## The spot under a tall style's upper floors: always at least this tall (neon signs go up to 9 m).
const BASE_MIN_HEIGHT: float = 10.0

# Materials made once and shared by every building (a fresh material per building would be slow).
static var _trim: ShaderMaterial       # plain dark concrete: ledges, posts, legs
static var _awning: ShaderMaterial     # softly glowing awning cloth (colour per awning via instance_tint)
static var _billboard: ShaderMaterial  # the billboard's lit panel (dimmer than neon, so text reads)
static var _dead: ShaderMaterial       # BLACKOUT: unlit dark grey instead of any glow


## Builds one building of "style". center/size = the old plain box (centre at half height).
## Returns the box the decorations (neon sign, poster, vending machine) should use: the ground floor.
static func build(city: CityGenerator, style: Style, center: Vector3, size: Vector3, street_side: Vector2, tint: Color) -> Dictionary:
	match style:
		Style.SETBACK:
			return _setback(city, center, size, tint)
		Style.SHOPHOUSE:
			return _shophouse(city, center, size, street_side, tint)
		Style.TWIN:
			return _twin(city, center, size, tint)
		Style.CORP:
			return _corp(city, center, size, street_side, tint)
	_walls(city, center, size, tint)
	return {"center": center, "size": size}


## Which style a lot gets. Tall styles fall back to a plain BOX on buildings too short for them,
## so short buildings at the edge of town stay simple and downtown gets the skyline.
static func pick_style(city: CityGenerator, height: float, size: Vector3) -> Style:
	var weights := {
		Style.BOX: city.style_box_weight,
		Style.SETBACK: city.style_setback_weight if height >= 16.0 else 0.0,
		Style.SHOPHOUSE: city.style_shophouse_weight,
		Style.TWIN: city.style_twin_weight if height >= 18.0 and maxf(size.x, size.z) >= 8.0 else 0.0,
		Style.CORP: city.style_corp_weight if height >= 12.0 else 0.0,
	}
	var total := 0.0
	for w in weights.values():
		total += maxf(w, 0.0)
	var roll := city._rng.randf() * total  # (always drawn, so the city's numbers stay in order)
	for style in weights:
		roll -= maxf(weights[style], 0.0)
		if roll < 0.0:
			return style
	return Style.BOX


# --- the styles ---

## SETBACK: three tiers, each smaller than the one below, a ledge on each step, an antenna on top.
static func _setback(city: CityGenerator, center: Vector3, size: Vector3, tint: Color) -> Dictionary:
	var rng := city._rng
	var base_h := maxf(BASE_MIN_HEIGHT, size.y * rng.randf_range(0.4, 0.5))
	var mid_h := (size.y - base_h) * rng.randf_range(0.5, 0.65)
	var top_h := size.y - base_h - mid_h
	var ground := Vector3(center.x, 0, center.z)
	# Tier 1: the full footprint.
	var base_size := Vector3(size.x, base_h, size.z)
	_walls(city, ground + Vector3(0, base_h * 0.5, 0), base_size, tint)
	_ledge(city, ground + Vector3(0, base_h, 0), size.x, size.z)
	# Tier 2 and 3 shrink towards the middle.
	var mid_scale := rng.randf_range(0.68, 0.78)
	var mid_size := Vector3(size.x * mid_scale, mid_h, size.z * mid_scale)
	_walls(city, ground + Vector3(0, base_h + mid_h * 0.5, 0), mid_size, tint)
	_ledge(city, ground + Vector3(0, base_h + mid_h, 0), mid_size.x, mid_size.z)
	var top_size := Vector3(size.x * mid_scale * 0.65, top_h, size.z * mid_scale * 0.65)
	_walls(city, ground + Vector3(0, base_h + mid_h + top_h * 0.5, 0), top_size, tint)
	# The antenna: a thin mast with a red warning light (just a glowing tip: no real light, it's cheap).
	var mast_h := rng.randf_range(3.0, 6.0)
	LevelKit.add_box(city, ground + Vector3(0, size.y + mast_h * 0.5, 0), Vector3(0.25, mast_h, 0.25), _trim_material(), false)
	_glow_box(city, ground + Vector3(0, size.y + mast_h + 0.2, 0), Vector3(0.45, 0.4, 0.45), Color(1, 0.12, 0.1))
	return {"center": ground + Vector3(0, base_h * 0.5, 0), "size": base_size}


## SHOPHOUSE: a short walk-up with a glowing awning out front, AC boxes round the back, a water tower.
static func _shophouse(city: CityGenerator, center: Vector3, size: Vector3, street_side: Vector2, tint: Color) -> Dictionary:
	var rng := city._rng
	var height := rng.randf_range(6.0, 12.0)
	var ground := Vector3(center.x, 0, center.z)
	var box_size := Vector3(size.x, height, size.z)
	_walls(city, ground + Vector3(0, height * 0.5, 0), box_size, tint)

	# THE AWNING: a tilted strip of glowing cloth over the sidewalk, along one street-facing wall.
	# It stops 2 m short of the street corner, so it never pokes through a lamp or a loudspeaker pole.
	var awning_color := CityGenerator.NEON_COLORS[rng.randi() % CityGenerator.NEON_COLORS.size()]
	var on_x := rng.randf() < 0.5
	var out := Vector3(street_side.x, 0, 0) if on_x else Vector3(0, 0, street_side.y)
	var along_dir := Vector3(0, 0, street_side.y) if on_x else Vector3(street_side.x, 0, 0)  # towards the corner
	var wall_len := size.z if on_x else size.x
	var wall_depth := size.x if on_x else size.z
	var awning_len := wall_len - 2.5
	var awning_on_x := -1  # (told back to the city, so its neon sign goes on the OTHER wall)
	if awning_len > 2.0:
		awning_on_x = 1 if on_x else 0
		var awning_depth := city.awning_depth
		var mid := ground + out * (wall_depth * 0.5 + awning_depth * 0.5) + along_dir * (0.5 - 2.0) * 0.5
		mid.y = city.awning_height
		var awning_size := Vector3(awning_depth, 0.25, awning_len) if on_x else Vector3(awning_len, 0.25, awning_depth)
		var cloth := LevelKit.add_box(city, mid, awning_size, _dead_material() if city._blackout else _awning_material(), false)
		cloth.set_instance_shader_parameter("instance_tint", awning_color)
		# Tilt it down towards the street (turn it around the wall's line).
		if on_x:
			cloth.rotation.z = -street_side.x * 0.22
		else:
			cloth.rotation.x = street_side.y * 0.22
		if not city._blackout:
			LevelKit.add_light(city, mid + out * 0.4 - Vector3(0, 0.8, 0), awning_color, 1.2, 5.0, 30.0)

	# AC UNITS on the two BACK walls (the alley side): never where posters / signs / vending go.
	var units := rng.randi_range(2, 4)
	for i in units:
		var back_x := rng.randf() < 0.5
		var back := Vector3(-street_side.x, 0, 0) if back_x else Vector3(0, 0, -street_side.y)
		var slide := rng.randf_range(-0.35, 0.35) * (size.z if back_x else size.x)
		var y := rng.randf_range(3.0, maxf(3.2, height - 1.5))
		var spot := ground + back * ((size.x if back_x else size.z) * 0.5 + 0.3)
		spot += Vector3(0, y, slide) if back_x else Vector3(slide, y, 0)
		var unit_size := Vector3(0.6, 0.55, 0.85) if back_x else Vector3(0.85, 0.55, 0.6)
		LevelKit.add_box(city, spot, unit_size, _trim_material(), false)

	# THE WATER TOWER: a fat six-sided tank with a pointy lid on four stubby legs, towards the back.
	if rng.randf() < city.water_tower_chance:
		var tank_spot := ground + Vector3(-street_side.x * size.x * 0.2, height, -street_side.y * size.z * 0.2)
		for lx in [-1, 1]:
			for lz in [-1, 1]:
				LevelKit.add_box(city, tank_spot + Vector3(lx * 0.75, 0.6, lz * 0.75), Vector3(0.2, 1.2, 0.2), _trim_material(), false)
		var tank := LevelKit.add_cylinder(city, tank_spot + Vector3(0, 2.1, 0), 1.15, 1.8, city.crate_material)
		tank.set_instance_shader_parameter("instance_tint", Color(0.55, 0.4, 0.3))
		_cone(city, tank_spot + Vector3(0, 3.35, 0), 1.3, 0.7)
	return {"center": ground + Vector3(0, height * 0.5, 0), "size": box_size, "awning_on_x": awning_on_x}


## TWIN: two towers on one base, joined high up by a glowing skybridge.
static func _twin(city: CityGenerator, center: Vector3, size: Vector3, tint: Color) -> Dictionary:
	var rng := city._rng
	var ground := Vector3(center.x, 0, center.z)
	var base_h := BASE_MIN_HEIGHT - 0.5
	var base_size := Vector3(size.x, base_h, size.z)
	_walls(city, ground + Vector3(0, base_h * 0.5, 0), base_size, tint)
	_ledge(city, ground + Vector3(0, base_h, 0), size.x, size.z)
	# Split along the longer side, with a 2 m gap between the towers.
	var along_x := size.x >= size.z
	var long_len := size.x if along_x else size.z
	var short_len := (size.z if along_x else size.x) * 0.85
	var gap := 2.0
	var tower_len := (long_len - gap) * 0.5
	var axis := Vector3.RIGHT if along_x else Vector3.BACK
	var heights := [size.y, size.y * rng.randf_range(0.7, 0.95)]
	if rng.randf() < 0.5:
		heights.reverse()
	for i in 2:
		var h: float = heights[i] - base_h
		var side := -1.0 if i == 0 else 1.0
		var tower_center := ground + axis * side * (gap + tower_len) * 0.5 + Vector3(0, base_h + h * 0.5, 0)
		var tower_size := Vector3(tower_len, h, short_len) if along_x else Vector3(short_len, h, tower_len)
		_walls(city, tower_center, tower_size, tint)
	# THE SKYBRIDGE: a box across the gap (its ends tucked into both towers), a glowing strip under it.
	var low: float = minf(heights[0], heights[1])
	var bridge_y := base_h + (low - base_h) * rng.randf_range(0.45, 0.7)
	var bridge_len := gap + 0.8
	var bridge_size := Vector3(bridge_len, 1.6, 2.6) if along_x else Vector3(2.6, 1.6, bridge_len)
	LevelKit.add_box(city, ground + Vector3(0, bridge_y, 0), bridge_size, _trim_material(), false)
	var strip_size := Vector3(gap, 0.15, 1.8) if along_x else Vector3(1.8, 0.15, gap)
	var strip_color := CityGenerator.NEON_COLORS[rng.randi() % CityGenerator.NEON_COLORS.size()]
	_glow_box(city, ground + Vector3(0, bridge_y - 0.875, 0), strip_size, strip_color)
	if not city._blackout:
		LevelKit.add_light(city, ground + Vector3(0, bridge_y - 2.0, 0), strip_color, 1.5, 7.0, 40.0)
	return {"center": ground + Vector3(0, base_h * 0.5, 0), "size": base_size}


## CORP: an OVERCLEAN office block with neon corner strips and a lit billboard on the roof.
static func _corp(city: CityGenerator, center: Vector3, size: Vector3, street_side: Vector2, tint: Color) -> Dictionary:
	var rng := city._rng
	var ground := Vector3(center.x, 0, center.z)
	_walls(city, center, size, tint)
	# Neon strips up all four corners (half sunk into the walls, so there's no thin gap to flicker).
	var strip_color := CityGenerator.NEON_COLORS[rng.randi() % CityGenerator.NEON_COLORS.size()]
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			var corner := ground + Vector3(cx * size.x * 0.5, size.y * 0.5 + 0.5, cz * size.z * 0.5)
			_glow_box(city, corner, Vector3(0.3, size.y - 1.0, 0.3), strip_color)
	# THE BILLBOARD: two posts and a lit panel facing one of the streets, with a slogan on it.
	var on_x := rng.randf() < 0.5
	var out := Vector3(street_side.x, 0, 0) if on_x else Vector3(0, 0, street_side.y)
	var panel_w := minf(7.0, (size.z if on_x else size.x) - 1.0)
	var front := ground + out * ((size.x if on_x else size.z) * 0.5 - 1.0)
	front.y = size.y
	var sideways := Vector3(0, 0, 1) if on_x else Vector3(1, 0, 0)
	for s in [-1, 1]:
		LevelKit.add_box(city, front + sideways * s * panel_w * 0.35 + Vector3(0, 1.0, 0), Vector3(0.3, 2.0, 0.3), _trim_material(), false)
	var panel_size := Vector3(0.3, 2.6, panel_w) if on_x else Vector3(panel_w, 2.6, 0.3)
	var panel_spot := front + Vector3(0, 3.3, 0)
	var panel := LevelKit.add_box(city, panel_spot, panel_size, _dead_material() if city._blackout else _billboard_material(), false)
	var panel_color := Color(0.9, 0.95, 1.0) if rng.randf() < 0.5 else strip_color.lerp(Color.WHITE, 0.5)
	panel.set_instance_shader_parameter("instance_tint", panel_color)
	var slogan := BILLBOARD_SLOGANS[rng.randi() % BILLBOARD_SLOGANS.size()]
	if not city._blackout:
		var label := LevelKit.add_sign(city, slogan, panel_spot + out * 0.25, Color(0.05, 0.05, 0.08), 32, atan2(out.x, out.z))
		label.modulate = Color(0, 0, 0)  # black letters on the bright panel (not glowing)
		label.outline_size = 6  # (a fat black outline = bold letters that still read through the fog)
		label.outline_modulate = Color(0, 0, 0)
		# Letters as big as fit: the slogan fills ~90% of the panel's width (and at most ~1.6 m tall).
		label.pixel_size = minf(panel_w * 0.9 / (slogan.length() * 32.0 * 0.6), 1.6 / 32.0)
		LevelKit.add_light(city, panel_spot + out * 2.5, panel_color, 2.0, 10.0, 50.0)
	return {"center": center, "size": size}


# --- little helpers ---

## Solid window-textured walls (cats and cars bump into them) in this building's tint.
static func _walls(city: CityGenerator, center: Vector3, size: Vector3, tint: Color) -> void:
	var walls := LevelKit.add_box(city, center, size, city.building_material, true)
	walls.set_instance_shader_parameter("instance_tint", tint)


## A concrete ledge sitting ON a roof edge at "top_y", 20 cm wider than the walls on every side.
static func _ledge(city: CityGenerator, top: Vector3, width: float, depth: float) -> void:
	LevelKit.add_box(city, top + Vector3(0, 0.2, 0), Vector3(width + 0.4, 0.4, depth + 0.4), _trim_material(), false)


## A glowing neon box in "color" (dead grey in a BLACKOUT).
static func _glow_box(city: CityGenerator, center: Vector3, size: Vector3, color: Color) -> void:
	var box := LevelKit.add_box(city, center, size, _dead_material() if city._blackout else city.neon_material, false)
	box.set_instance_shader_parameter("instance_tint", color)


## A six-sided pointy lid (the water tower's roof).
static func _cone(city: CityGenerator, center: Vector3, radius: float, height: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 0
	var cone := MeshInstance3D.new()
	cone.mesh = mesh
	cone.material_override = _trim_material()
	cone.position = center
	city.add_child(cone)


static func _trim_material() -> ShaderMaterial:
	if _trim == null:
		_trim = LevelKit.psx_material({"albedo_color": Color(0.22, 0.22, 0.27)})
	return _trim


static func _awning_material() -> ShaderMaterial:
	if _awning == null:
		_awning = LevelKit.psx_material({"albedo_color": Color(0.8, 0.8, 0.8),
			"emission_color": Color.WHITE, "emission_energy": 0.9})
	return _awning


static func _billboard_material() -> ShaderMaterial:
	if _billboard == null:
		_billboard = LevelKit.psx_material({"albedo_color": Color.WHITE,
			"emission_color": Color.WHITE, "emission_energy": 1.6})
	return _billboard


static func _dead_material() -> ShaderMaterial:
	if _dead == null:
		_dead = LevelKit.psx_material({"albedo_color": Color(0.16, 0.15, 0.17), "emission_energy": 0.0})
	return _dead
