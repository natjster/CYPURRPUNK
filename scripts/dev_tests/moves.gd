extends "res://scripts/dev_tests/dev_test.gd"
## DevCapture test module: CAT MOVES (scripts/cat/cat_moves.gd): jumps, short hops, pounces,
## wall kicks and clambering. Made by scripts/dev_capture.gd `_add_module`.
##
## --moves_test builds a little test yard high in the sky (a floor, a tall wall and a 2.4 m crate,
## only on this computer) and tries each move there, printing one "DevCapture moves ..." line each.
## Add --moves_shot=NAME to finish standing on the crate (for a --capture screenshot).

const YARD := Vector3(0, 300, 0)  # far above the city, so nothing else is in the way


func _moves_test(player: CatPlayer, args: Dictionary) -> void:
	_build_yard()
	for i in 10:
		await get_tree().physics_frame

	# 1. Full jump (jump held) vs 2. short hop (tapped for 2 frames).
	var full := await _jump_and_measure(player, YARD + Vector3(6, 0.1, 6), 0.0, ["jump"], 40)
	print("DevCapture moves full_jump: apex=%.2f m air=%.2f s" % [full.apex, full.air])
	var hop := await _jump_and_measure(player, YARD + Vector3(6, 0.1, 6), 0.0, ["jump"], 2)
	print("DevCapture moves short_hop: apex=%.2f m air=%.2f s (should be lower than the full jump)" % [hop.apex, hop.air])

	# 3. Normal running jump vs 4. POUNCE (zoomies + jump): how far do they fly?
	var run := await _run_jump(player, false)
	print("DevCapture moves run_jump: distance=%.2f m apex=%.2f m" % [run.distance, run.apex])
	var pounce := await _run_jump(player, true)
	print("DevCapture moves pounce: distance=%.2f m apex=%.2f m (should be further than run_jump)" % [pounce.distance, pounce.apex])

	# 4b. BUNNY HOP: hold zoomies + forward + jump for 4 s (a pounce every landing). Top speed must stay
	# capped (zoomies 9 + pounce boost * pounce_max_stack), not keep climbing.
	player.teleport_to(YARD + Vector3(-12, 0.1, -12), PI * 0.75)
	await _frames(10)
	_hold(player, ["move_forward", "sprint"], true)
	await _frames(30)
	_hold(player, ["jump"], true)
	var top := 0.0
	var speeds := []
	for i in 240:
		await get_tree().physics_frame
		var flat := Motion.flat(player.velocity).length()
		top = maxf(top, flat)
		if i % 60 == 59:
			speeds.append("%.1f" % top)
	_hold(player, ["move_forward", "sprint", "jump"], false)
	print("DevCapture moves bhop: top speed per second %s (zoomies=%.1f, cap=%.1f)" % [speeds, player.zoomies_speed,
		player.zoomies_speed + player.moves.pounce_boost * player.moves.pounce_max_stack])
	await _frames(30)

	# 5. WALL KICK: jump up next to the tall wall (it's 1 m to the north = -Z), press jump again.
	player.teleport_to(YARD + Vector3(-6, 0.1, -8.1), 0.0)  # facing the wall, 0.4 m from it
	await _frames(10)
	_hold(player, ["jump"], true)
	await _frames(14)
	_hold(player, ["jump"], false)
	await _frames(1)
	var before := player.velocity
	await _press(player, ["jump"], 3)
	var after := player.velocity
	print("DevCapture moves wall_kick: vy %.1f -> %.1f, away from wall vz %.1f -> %.1f (vz should be + = away)" % [
		before.y, after.y, before.z, after.z])
	await _frames(60)

	# 6. CLAMBER: run at the 2.4 m crate (a normal jump only reaches ~1.8 m) and jump.
	player.teleport_to(YARD + Vector3(6, 0.1, 2.0), 0.0)
	await _frames(10)
	_hold(player, ["move_forward"], true)
	await _frames(8)
	_hold(player, ["jump"], true)
	# Watch for the highest spot we STAND on (keep pushing forward and we'd walk off the far side).
	var stood := 0.0
	for i in 70:
		await get_tree().physics_frame
		if i > 3 and player.is_on_floor():
			stood = maxf(stood, player.global_position.y - YARD.y)
			if stood > 2.2:
				break
	_hold(player, ["jump", "move_forward"], false)
	print("DevCapture moves clamber: stood at height %.2f m (crate top is 2.40) -> %s" % [
		stood, "ON THE CRATE" if stood > 2.2 else "did NOT get up"])
	if args.has("moves_shot"):
		await _frames(30)  # let the squash settle for the screenshot
	print("DevCapture moves squash: model scale %s" % player.cat_model.scale.snapped(Vector3.ONE * 0.01))


## A floor, a tall wall at the north end, and a crate, all plain grey boxes.
func _build_yard() -> void:
	var yard := Node3D.new()
	yard.name = "MovesTestYard"
	Game.instance.add_child(yard)
	yard.global_position = YARD
	_box(yard, Vector3(0, -0.25, 0), Vector3(30, 0.5, 30))     # floor
	_box(yard, Vector3(-6, 3, -9), Vector3(6, 6, 1))           # tall wall (front face at z = -8.5)
	_box(yard, Vector3(6, 1.2, -1.0), Vector3(2, 2.4, 2))      # crate (front face at z = 0)


func _box(parent: Node3D, where: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	body.add_child(mesh)
	parent.add_child(body)
	body.position = where


## Stand at `where`, press `actions` for `frames` physics frames, and watch until we land.
func _jump_and_measure(player: CatPlayer, where: Vector3, yaw: float, actions: Array, frames: int) -> Dictionary:
	player.teleport_to(where, yaw)
	await _frames(10)
	var start_y := player.global_position.y
	var apex := 0.0
	var air := 0.0
	_hold(player, actions, true)
	for i in 120:
		await get_tree().physics_frame
		if i == frames:
			_hold(player, actions, false)
		apex = maxf(apex, player.global_position.y - start_y)
		if i > 3 and player.is_on_floor():
			break
		air += get_physics_process_delta_time()
	_hold(player, actions, false)
	return {"apex": apex, "air": air}


## Run south at full speed (with zoomies if `zoomies`), jump, and measure how far we fly.
func _run_jump(player: CatPlayer, zoomies: bool) -> Dictionary:
	player.teleport_to(YARD + Vector3(-10, 0.1, -4), PI)  # facing south (+Z), lots of room
	await _frames(10)
	var keys := ["move_forward"]
	if zoomies:
		keys.append("sprint")
	_hold(player, keys, true)
	await _frames(45)  # get up to speed
	var start := player.global_position
	var result := await _jump_and_measure_running(player, start)
	_hold(player, keys, false)
	await _frames(20)
	return result


func _jump_and_measure_running(player: CatPlayer, start: Vector3) -> Dictionary:
	var apex := 0.0
	_hold(player, ["jump"], true)
	for i in 150:
		await get_tree().physics_frame
		apex = maxf(apex, player.global_position.y - start.y)
		if i > 3 and player.is_on_floor():
			break
	_hold(player, ["jump"], false)
	return {"distance": Motion.flat(player.global_position - start).length(), "apex": apex}


func _press(player: CatPlayer, actions: Array, frames: int) -> void:
	_hold(player, actions, true)
	await _frames(1)
	_hold(player, actions, false)
	await _frames(frames)


func _hold(player: CatPlayer, actions: Array, down: bool) -> void:
	for action in actions:
		if down:
			Input.action_press(Seats.action(player.slot, action))
		else:
			Input.action_release(Seats.action(player.slot, action))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## --hold / --pad / --drop_after / --jump_test: hold actions or controller sticks/buttons, drop held
## items, or run the double-jump + front-flip measurement.
func _input_and_jump_actions(scene: Node, player: CatPlayer, args: Dictionary) -> void:
	if args.has("hold"):
		for i in int(args.get("hold_delay", "30")):
			await get_tree().process_frame
		var slots: Array = [player.slot]
		if args.has("hold_all"):
			slots = scene.local_cats().map(func(c): return c.slot)
		for action in args["hold"].split(","):
			for slot in slots:
				Input.action_press(Seats.action(slot, action))
		for i in int(args.get("hold_frames", "60")):
			await get_tree().process_frame
		if not args.has("keep_holding"):
			for action in args["hold"].split(","):
				for slot in slots:
					Input.action_release(Seats.action(slot, action))
	if args.has("pad"):
		for i in int(args.get("hold_delay", "30")):
			await get_tree().process_frame
		var yaw_before := player.camera_pivot.rotation.y
		var pos_before := player.global_position
		var all_before := {}
		for cat in scene.local_cats():
			all_before[cat] = cat.global_position
		var pads: PackedStringArray = args["pad"].replace("_", " ").split(",")
		if player.slot == 0:
			Seats.claim_for_p1(int(args.get("pad_device", "0")))
		for pad in pads:
			Input.parse_input_event(_pad_event(pad, true))
		for i in int(args.get("hold_frames", "60")):
			await get_tree().process_frame
		var car := _car_for(player)
		var held: Array = []
		for entry in Controls.ACTIONS:
			if Input.is_action_pressed(entry.action):
				held.append(entry.action)
		print("DevCapture pad held: %s" % [held])
		for cat in all_before:
			print("DevCapture pad moved: %s (slot %d) %.2f m" % [cat.name, cat.slot, cat.global_position.distance_to(all_before[cat])])
		print("DevCapture pad %s: using_pad=%s yaw turned %.2f rad, cat moved %.2f m, car throttle %.2f steer %.2f, speed %.1f, prompt key=%s" % [
			args["pad"], Controls.using_pad, player.camera_pivot.rotation.y - yaw_before,
			player.global_position.distance_to(pos_before), car.throttle, car.steer,
			car.linear_velocity.length(), Controls.key_text("interact")])
		if not args.has("keep_holding"):
			for pad in pads:
				Input.parse_input_event(_pad_event(pad, false))
	if args.has("drop_after"):
		for i in int(args["drop_after"]):
			await get_tree().process_frame
		ItemManager.instance.drop_from(player)
	if args.has("jump_test"):
		var quick := ItemManager.instance.quick_slots(player.player_id)
		for slot in 2:
			if player.air_jumps == 0 and not quick[slot].is_empty() and quick[slot][0] == "catdip":
				ItemManager.instance.request_quick_use.rpc_id(1, player.player_id, slot)
				for f in 20:
					await get_tree().physics_frame
		var ground_y := player.global_position.y
		var peak := ground_y
		var spin := 0.0
		for i in 100:
			if i == 0 or i == 18:
				Input.action_press(Seats.action(player.slot, "jump"))
			elif i == 2 or i == 20:
				Input.action_release(Seats.action(player.slot, "jump"))
			await get_tree().physics_frame
			peak = maxf(peak, player.global_position.y)
			spin = minf(spin, player.cat_model.rotation.x)
			if args.has("flip_snap") and i == int(args.get("flip_frame", "26")):
				await RenderingServer.frame_post_draw
				get_tree().root.get_texture().get_image().save_png("res://" + args["flip_snap"])
		print("DevCapture jump: peak height %.2f m (air jumps active: %d) flip %d degrees" % [peak - ground_y, player.air_jumps, roundi(rad_to_deg(-spin))])
