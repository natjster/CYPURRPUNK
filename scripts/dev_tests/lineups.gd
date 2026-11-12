extends "res://scripts/dev_tests/dev_test.gd"
## DevCapture test module: Lineups + photo tools: vehicle / cat / weapon racks, portraits, MY CAT looks, the film camera, HUD preview.
## Made by scripts/dev_capture.gd `_add_module`; its options are listed at the top of dev_capture.gd.


## --vehicles_lineup (host, TURF WAR so both cars exist, e.g. --teams=0): the Catleone car becomes the
## ZOOM-BIKE and the Burrow car the MEOW-VAN (straight onto every computer, no unlock needed: test only),
## parked side by side in front of us, three-quarter on. Then a "DevCapture lineup" line.
func _vehicles_lineup(player: CatPlayer) -> void:
	if UndergroundHub.is_in_hub(player.global_position):
		UndergroundHub.of(player).deploy(player)  # (up to the street first)
		for i in 30:
			await get_tree().physics_frame
	# Face north, so a film camera can find them: they park 5.5 m north of the cat, 4.6 m apart, e.g.
	#   --vehicles_lineup --no_hud --cam_follow --cam_from=0,1.8,-1 --look_from=0,0.4,-5.5
	player.camera_pivot.rotation.y = 0.0
	var cars := Game.instance.cars()
	var rides := ["cyber_bike", "fish_van", "interceptor"]
	var forward := -player.camera_pivot.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var ground := player.global_position
	for i in cars.size():
		var car := cars[i]
		Upgrades.instance._set_team_vehicle.rpc(maxi(0, car.team), rides[mini(i, rides.size() - 1)])
		var spot := ground + forward * 5.5 + right * (i * 4.6 - 2.3) + Vector3(0, 0.5, 0)
		car._teleport(Transform3D(Basis(Vector3.UP, player.camera_pivot.global_rotation.y + PI * 0.7), spot))
	# A work light over the pair (test only), so the photo shows the models and not just their neon.
	LevelKit.add_light(Game.instance, ground + forward * 4.0 + Vector3(0, 4.0, 0), Color(1, 0.92, 0.8), 6.0, 14.0)
	for i in 30:
		await get_tree().physics_frame
	for car in cars:
		print("DevCapture lineup: %s = %s at %s max_speed=%.1f seats=%d wheels=%d trim=%s" % [car.name, car.vehicle,
			car.global_position.snapped(Vector3.ONE * 0.1), car.max_speed, car.passenger_seats, car._wheels.size(), car.trim_color()])


## --cat_lineup[=res://a.tscn,...]: the cat model (scenes/cat_model.tscn) plus any other cat scenes
## named, standing in a row under a work light with their own camera (no HUD), wearing the player's
## look (classic orange tabby where it sets nothing). For judging cat model changes side by side.
func _cat_lineup(player: CatPlayer) -> void:
	var paths: Array[String] = ["res://scenes/cat_model.tscn"]
	for extra in str(_args.get("cat_lineup", "")).split(","):
		if extra.ends_with(".tscn"):
			paths.append(extra)
	# --coat_lineup: one cat per COAT pattern (CatLook.coat_ids()), all in the same colours.
	# --coat_lineup=tiger,calico: only those.
	var coats: Array[String] = CatLook.coat_ids() if _args.has("coat_lineup") else []
	var wanted := str(_args.get("coat_lineup", "")).split(",")
	if coats.any(func(id): return id in wanted):
		coats = coats.filter(func(id): return id in wanted)
	if not coats.is_empty():
		paths.clear()
		for id in coats:
			paths.append("res://scenes/cat_model.tscn")
	if UndergroundHub.is_in_hub(player.global_position):
		UndergroundHub.of(player).deploy(player)
		for i in 30:
			await get_tree().physics_frame
	for seat in 4:
		if Hud.of(seat) != null:
			Hud.of(seat).visible = false
	player.visible = false
	var look := {"fur": Color(0.95, 0.55, 0.2), "markings": Color(1, 0.93, 0.82), "eyes": Color(0.04, 0.03, 0.06),
		"nose": Color(1, 0.45, 0.6)}
	look.merge(player.look, true)
	var row := Node3D.new()
	row.name = "CatLineup"
	Game.instance.add_child(row)
	row.global_position = player.global_position + Vector3(0, 0, -3.0)
	for i in paths.size():
		var cat := (load(paths[i]) as PackedScene).instantiate() as Node3D
		cat.position = Vector3((i - (paths.size() - 1) / 2.0) * 1.05, 0, 0)
		cat.rotation.y = PI + deg_to_rad(float(_args.get("lineup_yaw", "20")))  # cats face -Z: turn to the camera
		row.add_child(cat)
		var cat_look := look.duplicate()
		if not coats.is_empty():
			cat_look[CatLook.COAT_KEY] = coats[i]
		CatLook.apply(cat, cat_look)
		print("DevCapture cat_model: %d %s coat=%s" % [i, paths[i], CatLook.coat_of(cat_look)])
	LevelKit.add_light(row, Vector3(0, 2.2, 1.8), Color(1, 0.94, 0.85), 5.0, 9.0)
	var camera := Camera3D.new()
	camera.fov = float(_args.get("lineup_fov", "45"))
	row.add_child(camera)
	camera.position = Vector3(0, 0.75, float(_args.get("lineup_dist", "2.2")))
	camera.rotation.x = deg_to_rad(-8)
	camera.make_current()
	for i in 20:
		await get_tree().process_frame


## --weapons_lineup[=a,b,...]: a display rack of the weapons (default: every weapon card) floating
## side-on in a 4-wide grid in front of us, under a work light, with its own camera (no HUD), for
## judging the Blockbench models. --lineup_dist=M moves the camera back, --lineup_yaw=DEG turns them. Prints one
## "DevCapture weapon" line each: where its Muzzle ended up (snapped onto the model's own @Muzzle
## marker), whether a HeatCoil / glow parts were found, its triangles and the PS1 shader check.
func _weapons_lineup(player: CatPlayer) -> void:
	var ids: Array[String] = []
	if str(_args["weapons_lineup"]) not in ["", "true"]:
		for item_id in str(_args["weapons_lineup"]).split(","):
			ids.append(item_id)
	else:
		for item_id in ItemManager.instance.catalog:
			var data: ItemData = ItemManager.instance.catalog[item_id]
			if data.scene == null:
				continue
			var probe := data.scene.instantiate()
			if probe is Weapon:
				ids.append(item_id)
			probe.free()
		ids.sort()
	if UndergroundHub.is_in_hub(player.global_position):
		UndergroundHub.of(player).deploy(player)  # (up to the street: no sewer fog in the photo)
		for i in 30:
			await get_tree().physics_frame
	for seat in 4:
		if Hud.of(seat) != null:
			Hud.of(seat).visible = false
	player.visible = false
	var rack := Node3D.new()
	rack.name = "WeaponRack"
	Game.instance.add_child(rack)
	rack.global_position = player.global_position + Vector3(0, 1.8, -3.0)
	var columns := mini(4, ids.size())
	var guns: Array[Weapon] = []
	for i in ids.size():
		var data: ItemData = ItemManager.instance.catalog[ids[i]]
		var gun := data.scene.instantiate() as Weapon
		gun.position = Vector3(((i % columns) - (columns - 1) / 2.0) * 1.1, -floorf(i / float(columns)) * 0.9, 0)
		gun.rotation.y = -PI / 2 + deg_to_rad(float(_args.get("lineup_yaw", "0")))  # barrel (-Z) pointing right: we see its side
		rack.add_child(gun)
		guns.append(gun)
	LevelKit.add_light(rack, Vector3(0, 1.5, 1.5), Color(1, 0.94, 0.85), 4.0, 8.0)
	var camera := Camera3D.new()
	camera.fov = 50.0
	rack.add_child(camera)
	camera.position = Vector3(0, -0.45 if ids.size() > columns else 0.0, float(_args.get("lineup_dist", "3.4" if ids.size() > 2 else "1.4")))
	camera.make_current()
	for i in 20:
		await get_tree().process_frame
	for i in guns.size():
		var gun := guns[i]
		var tris := 0
		for mesh: MeshInstance3D in gun.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var count: int = mesh.mesh.surface_get_array_index_len(surface)
				tris += (count if count > 0 else mesh.mesh.surface_get_array_len(surface)) / 3
		print("DevCapture weapon: %s muzzle=%s coil=%s glow=%s neon=%s tris=%d psx=%s" % [ids[i],
			gun._muzzle.position.snapped(Vector3.ONE * 0.001) if gun._muzzle != null else "none", gun._coil != null,
			gun.glow_parts.keys(), gun.neon_parts.keys(), tris, _all_psx(gun)])


## True if every mesh under node draws with the game's PS1 shader.
func _all_psx(node: Node) -> bool:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var material := mesh.get_active_material(0) as ShaderMaterial
		if material == null or material.shader != LevelKit.PSX_SHADER:
			return false
	return true


## Turns ["--capture=a.png", "--drive"] into {"capture": "a.png", "drive": "true"}.
## --talk[=NODE_NAME]: stand in front of that NPC (default Don) and press E,
## then click the --choose buttons in order (0 = top button), as if the player did.
## --portrait[=NAME]: a close-up of an NPC's face (for icons / posters). Hides the HUD and our
## own cat, and points a new camera at the NPC from the front. --portrait_dist / --portrait_height
## / --portrait_side (metres) move the camera; --portrait_fov sets the zoom.
func _portrait(player: CatPlayer, args: Dictionary) -> void:
	for seat in 4:
		var hud := Hud.of(seat)
		if hud != null:
			hud.visible = false
	var camera := Camera3D.new()
	camera.fov = float(args.get("portrait_fov", "40"))
	var face := Vector3(0, float(args.get("portrait_height", "0.95")), 0)
	var offset := Vector3(float(args.get("portrait_side", "0")), 0.05, float(args.get("portrait_dist", "1.6")))
	var target: Node3D
	if args["portrait"] == "me":
		# Our own cat: its model faces -Z (nose first), so the camera goes on that side.
		target = player.cat_model
		offset.z = -offset.z
	elif args["portrait"] == "bot":
		# --portrait=bot: the bot --roomba picks (vac / boss / drone / trapper). The camera hangs off
		# its Model (faces -Z), so the MEGA VAC-COP's 2.6x scale moves the camera back to match.
		var bot: Roomba = await _pick_roomba(Game.instance, player.global_position, args)
		target = bot.model
		offset.z = -offset.z
		player.visible = false
	else:
		target = Game.instance.hub.npc
		for node in get_tree().get_nodes_in_group(Npc.GROUP):
			if node.name == args["portrait"]:
				target = node
		player.visible = false
		# NPCs face their +Z (the way a cat walks up to talk to them).
	target.add_child(camera)
	camera.position = face + offset
	camera.look_at(target.to_global(face))
	camera.make_current()


## --look=N: a random cat look from seed N, as if picked in the MY CAT screen
## (our cat wears it and shares it; test runs never save it).
## --wear=hat:mohawk,neck:bandolier,fur:#808080 then sets exact parts / colours on top.
func _apply_look(args: Dictionary) -> void:
	if not (args.has("look") or args.has("wear")):
		return
	var look := CatLook.default_look()
	if args.has("look"):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(args["look"])
		look = CatLook.random_look(rng)
	if args.has("wear"):
		for pair in args["wear"].split(","):
			var bits: PackedStringArray = pair.split(":")
			look[bits[0]] = Color(bits[1]) if bits[0] in CatLook.COLOR_KEYS else bits[1]
	Settings.update_current_cat({"look": CatLook.clean(look)})
	for i in 10:
		await get_tree().process_frame


## Trailer camera (--cam_from / --cam_to / --look_* / --cam_follow / --cam_orbit): a new camera
## in the game world that glides between two spots (or circles a point) over --cam_frames.
func _film_camera(player: CatPlayer, args: Dictionary) -> void:
	var camera := Camera3D.new()
	camera.fov = float(args.get("cam_fov", "60"))
	Game.instance.add_child(camera)
	var vec := func(key: String, fallback: Vector3) -> Vector3:
		if not args.has(key):
			return fallback
		var p: PackedFloat64Array = args[key].split_floats(",")
		return Vector3(p[0], p[1], p[2])
	var cam_from: Vector3 = vec.call("cam_from", Vector3.ZERO)
	var cam_to: Vector3 = vec.call("cam_to", cam_from)
	var look_from: Vector3 = vec.call("look_from", Vector3.ZERO)
	var look_to: Vector3 = vec.call("look_to", look_from)
	var frames := maxi(1, int(args.get("cam_frames", args.get("frames", "90"))))
	var delay := int(args.get("cam_delay", "0"))
	var ease_on: bool = args.get("cam_ease", "true") != "false"
	var i := -delay
	var anchor := player.global_position  # what --cam_follow follows
	while is_instance_valid(camera):
		var t := clampf(float(i) / frames, 0.0, 1.0)
		if ease_on:
			t = smoothstep(0.0, 1.0, t)
		# Follow the cat, or the car while the cat drives it. A sudden jump of 30 m+ (extracted
		# down to the hub, say) is ignored, so the camera stays where the action was.
		var followed := Game.instance.player_position(player.player_id)
		if followed.distance_to(anchor) < 30.0:
			anchor = followed
		var head := anchor + Vector3(0, 0.6, 0)  # roughly the cat's head
		var at: Vector3
		var target: Vector3
		if args.has("cam_orbit"):
			var o: PackedFloat64Array = args["cam_orbit"].split_floats(",")
			var angle := deg_to_rad(lerpf(o[5], o[6], t))
			target = Vector3(o[0], o[1], o[2])
			at = target + Vector3(sin(angle) * o[3], o[4], cos(angle) * o[3])
		else:
			at = cam_from.lerp(cam_to, t)
			target = look_from.lerp(look_to, t) if args.has("look_from") else head
			if args.has("cam_follow"):
				at += anchor
				if args.has("look_from"):
					target += anchor
		camera.global_position = at
		if not at.is_equal_approx(target):
			camera.look_at(target)
		camera.make_current()  # (the cat's own camera may grab it back when it spawns)
		i += 1
		await get_tree().process_frame


## --hud_heat / --hud_buffs: hold the gun heat and buff timers still until the snap, so the new
## ocean-blue HUD pieces (scripts/ui/hud_weapon_display.gd, hud_status_icons.gd) can be checked.
func _hud_preview(player: CatPlayer, args: Dictionary) -> void:
	var heats: Array = []
	for value in str(args.get("hud_heat", "")).split(",", false):
		heats.append(clampf(float(value), 0.0, 1.0))
	var buffs: PackedStringArray = str(args.get("hud_buffs", "")).split(",", false)
	if "catnip" in buffs:
		player.start_boost(1.3, 30.0)
	if "catdip" in buffs:
		player.start_double_jump(1, 20.0)
	var frames := int(args.get("frames", "90"))
	for frame in frames:
		for hand in mini(heats.size(), 2):
			var weapon := ItemManager.instance.held_item(player, hand) as Weapon
			if weapon != null:
				weapon.heat = heats[hand]
				weapon.is_overheated = heats[hand] >= 1.0
		if "sticky" in buffs:
			player._sticky_left = player.sticky_seconds * 0.6
		if frame == mini(30, frames / 2):  # (physics frames can run slower than the snap's frames)
			var display := Hud.element("Held", player.slot) as HudWeaponDisplay
			var icons := Hud.element("StatusIcons", player.slot) as HudStatusIcons
			print("DevCapture hud loadout: paws=%s quick=%s badges=%s" % [
				", ".join(display._paws.map(func(p): return "%s heat=%.2f%s key=%s" % [p.id, p.heat, " OVERHEAT" if p.overheated else "", p.key])) if display != null else "?",
				", ".join(display._quick.map(func(q): return "%s x%d [%s]" % [q.id if q.id != "" else "-", q.count, q.key])) if display != null else "?",
				", ".join(icons._effects.map(func(e): return "%s %.0f%%" % [e.id, e.fraction * 100.0])) if icons != null and icons.visible else "none"])
		await get_tree().physics_frame
