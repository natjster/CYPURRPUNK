extends "res://scripts/dev_tests/dev_test.gd"
## DevCapture test module: Mess-making + street prop tests.
## Made by scripts/dev_capture.gd `_add_module`; its options are listed at the top of dev_capture.gd.


## --mess / --ram_prop / --scratch / --shoot_prop / --ghost / --bait_mess / --meow / --mess_log.
func _mess_tests(scene: Node, player: CatPlayer, args: Dictionary) -> void:
	var mess := MessManager.instance
	for i in 20:
		await get_tree().physics_frame
	if args.has("ghost"):
		player.unseen_by_bots = true  # (roomba.gd _can_chase skips us)
		if not multiplayer.is_server():
			print("DevCapture mess: --ghost only hides us from the HOST's bots on the host")
	if args.has("mess_log"):
		_mess_log(int(args["mess_log"]))
	_print_mess("start")
	var first: MessProp = null
	if args.has("mess"):
		for i in int(args["mess"]):
			var p := _nearest_prop(player.global_position, "")
			if p == null:
				break
			first = p if first == null else first
			mess.knock(player.player_id, p.id, Motion.flat(p.global_position - player.global_position).normalized())
			for f in 15:
				await get_tree().physics_frame
		_print_mess("after --mess")
	if args.has("ram_prop"):
		var p := _nearest_prop(player.global_position, str(args["ram_prop"]))
		if p != null:
			first = p if first == null else first
			# Stand 4 m away along the pavement-facing side, and run straight at it.
			var away := Motion.flat(player.global_position - p.global_position).normalized()
			if p.kind == MessProp.Kind.NEON_SIGN:
				away = -p.global_basis.z  # (signs face along the pavement: run at one from the front)
			if away == Vector3.ZERO:
				away = Vector3.BACK
			var dir := -away
			player.teleport_to(p.global_position + away * 4.0 + Vector3.UP * 0.2, atan2(-dir.x, -dir.z))
			for f in 10:
				await get_tree().physics_frame
			var keys: Array[String] = ["move_forward"]
			if p.kind == MessProp.Kind.BIN:
				keys.append("sprint")
			for key in keys:
				Input.action_press(Seats.action(player.slot, key))
			for f in 70:
				await get_tree().physics_frame
				if args.has("ram_trace") and f % 3 == 0:
					print("DevCapture ram trace: f=%d gap=%.2f speed=%.2f pos=%s" % [f, Motion.flat_distance(player.global_position, p.global_position),
						Vector3(player.velocity.x, 0, player.velocity.z).length(), player.global_position.snapped(Vector3.ONE * 0.1)])
				if p.knocked:
					break
			for key in keys:
				Input.action_release(Seats.action(player.slot, key))
			for f in 15:
				await get_tree().physics_frame
			print("DevCapture mess ram: %s %s knocked=%s cat now %.1f m from it" % [p.name, MessProp.Kind.keys()[p.kind], p.knocked,
				Motion.flat_distance(player.global_position, p.global_position)])
	if args.has("scratch"):
		var p := _nearest_prop(player.global_position, "poster")
		if p != null:
			first = p if first == null else first
			var front := -p.global_basis.z
			player.teleport_to(p.tidy_spot() + Vector3.UP * 0.2, atan2(front.x, front.z))
			for f in 12:
				await get_tree().physics_frame
			var prompt := Interactable.prompt_for(player)
			var used := Interactable.try_use(player)
			for f in 15:
				await get_tree().physics_frame
			print("DevCapture mess scratch: %s prompt=\"%s\" used=%s knocked=%s" % [p.name, prompt, used, p.knocked])
	if args.has("use_prop"):
		var used_prop := await _use_prop_test(scene, player, args)
		first = used_prop if first == null else first
	if args.has("shoot_prop"):
		var p := _nearest_prop(player.global_position, "" if str(args["shoot_prop"]) == "true" else str(args["shoot_prop"]))
		if p != null:
			first = p if first == null else first
			var hit := Hit.new()
			hit.shooter = player
			hit.damage = 10
			hit.direction = Motion.flat(p.global_position - player.global_position).normalized()
			(p.get_node("Hitbox").get_parent() as MessProp).receive_hit(hit)
			for f in 15:
				await get_tree().physics_frame
			print("DevCapture mess shoot: %s %s knocked=%s" % [p.name, MessProp.Kind.keys()[p.kind], p.knocked])
			_print_prop(p, "after shot")
	if args.has("bait_mess") and multiplayer.is_server() and first != null:
		var bot: Roomba = null
		var best := INF
		for node in scene.get_node("Roombas").get_children():
			var r := node as Roomba
			if r != null and r.tidies_messes and not r.is_boss and r.breach_hub == null and not r.is_queued_for_deletion():
				var d := Motion.flat_distance(r.global_position, first.global_position)
				if d < best:
					best = d
					bot = r
		if bot != null:
			var side := Motion.flat(first.tidy_spot() - player.global_position).normalized()
			if side == Vector3.ZERO:
				side = Vector3.RIGHT
			bot.global_position = first.tidy_spot() + side.cross(Vector3.UP) * float(args["bait_mess"]) + Vector3.UP * 0.1
			bot.state = Roomba.State.PATROL
			bot._mess_check_left = 0.0
			print("DevCapture mess bait: %s placed %.1f m from %s" % [bot.name, float(args["bait_mess"]), first.name])
	if args.has("instant_props"):
		# --instant_props: what a LATE JOINER sees (show_knocked instant) for every street-pack kind, then tidied.
		for k in ["vending", "hydrant", "cart", "neon_sign", "dumpster"]:
			var p := _nearest_prop(player.global_position, k)
			if p != null:
				p.show_knocked(0.7, true)
				await get_tree().physics_frame
				_print_prop(p, "instant")
				p.show_standing(true)
				await get_tree().physics_frame
				_print_prop(p, "instant tidied")
	if args.has("look_prop"):
		# --look_prop=KIND: stand 3 m in front of the nearest standing one and look at it (screenshots).
		var p := _nearest_prop(player.global_position, str(args["look_prop"]))
		if p != null:
			var front := -p.global_basis.z
			player.teleport_to(p.global_position + front * 3.0 + p.global_basis.x * 1.2 + Vector3.UP * 0.2, atan2(front.x + 0.4 * p.global_basis.x.x, front.z + 0.4 * p.global_basis.x.z))
			print("DevCapture prop look: %s %s at %s front %s" % [p.name, MessProp.Kind.keys()[p.kind], p.global_position.snapped(Vector3.ONE * 0.01), front.snapped(Vector3.ONE * 0.01)])
	if args.has("face_mess") and first != null:
		# Stand 4.5 m from the first mess and look at it (for screenshots).
		var away := Motion.flat(player.global_position - first.tidy_spot()).normalized()
		if away.length() < 0.5:
			away = -first.global_basis.z
		player.teleport_to(first.tidy_spot() + away * 4.5 + Vector3.UP * 0.2, atan2(away.x, away.z))
	if args.has("meow"):
		for f in (30 if args["meow"] == "true" else int(args["meow"])):
			await get_tree().physics_frame
		player._next_meow_at = 0.0
		player.meow()
		for f in 30:
			await get_tree().physics_frame
		_print_mess("after --meow")


## --use_prop=KIND (+ --cart_bowl, --geyser_jump, --geyser_bot, --prop_twice): the STREET PROPS PACK.
func _use_prop_test(scene: Node, player: CatPlayer, args: Dictionary) -> MessProp:
	var p := _nearest_prop(player.global_position, str(args["use_prop"]))
	if p == null:
		print("DevCapture prop: no standing %s in this city" % args["use_prop"])
		return null
	# Stand where a cat would: in front of wall-backed props, else on the pavement side we came from.
	var away := Motion.flat(player.global_position - p.global_position).normalized()
	if p.kind in [MessProp.Kind.VENDING, MessProp.Kind.DUMPSTER]:
		away = -p.global_basis.z
	if away == Vector3.ZERO:
		away = Vector3.BACK
	var stand := p.global_position + away * (p.radius() + 0.7)
	if args.has("from_below"):  # (straight under the prop at sewer depth: E must NOT reach it)
		stand.y += UndergroundHub.DEPTH_LINE * 2.0
	player.teleport_to(stand + Vector3.UP * 0.2, atan2(away.x, away.z))
	for f in 12:
		await get_tree().physics_frame
	var push := Motion.flat(p.global_position - player.global_position).normalized()
	if args.has("cart_bowl") and multiplayer.is_server() and p.kind == MessProp.Kind.CART:
		var bot := _nearest_tidy_bot(scene, p.global_position)
		var cone := _nearest_prop(p.global_position + push * 4.0, "cone")
		if bot != null:
			bot.global_position = p.global_position + push * 3.0 + Vector3.UP * 0.1
			bot.state = Roomba.State.PATROL
			print("DevCapture prop bowl: %s put 3 m down the cart's path (hp %d)" % [bot.name, bot.health])
		if cone != null:
			cone.global_position = p.global_position + push * 5.5
			print("DevCapture prop bowl: %s moved 5.5 m down the path" % cone.name)
	var prompt := Interactable.prompt_for(player)
	var used := Interactable.try_use(player)
	for f in 20:
		await get_tree().physics_frame
	print("DevCapture prop use: %s %s prompt=\"%s\" used=%s knocked=%s" % [p.name, MessProp.Kind.keys()[p.kind], prompt, used, p.knocked])
	for f in 40:
		await get_tree().physics_frame
	_print_prop(p, "after use")
	if args.has("cart_bowl"):
		for node in scene.get_node("Roombas").get_children():
			var r := node as Roomba
			if r != null and Motion.flat_distance(r.global_position, p.tidy_spot()) < 12.0:
				print("DevCapture prop bowl: %s state=%s hp=%d %.1f m from the cart's rest spot" % [r.name, Roomba.State.keys()[r.state], r.health,
					Motion.flat_distance(r.global_position, p.tidy_spot())])
		_print_mess("after bowl")
	if args.has("geyser_jump") and p.kind == MessProp.Kind.HYDRANT:
		player.teleport_to(p.global_position + away * 0.6 + Vector3.UP * 0.2, atan2(away.x, away.z))
		var top := player.global_position.y
		for f in 70:
			await get_tree().physics_frame
			top = maxf(top, player.global_position.y)
		print("DevCapture prop geyser_jump: geyser=%s cat flew to %.1f m (from %.1f)" % [p.geyser_active(), top, p.global_position.y])
	if args.has("geyser_bot") and multiplayer.is_server() and p.kind == MessProp.Kind.HYDRANT:
		var bot := _nearest_tidy_bot(scene, p.global_position)
		if bot != null:
			bot.global_position = p.global_position + Vector3.RIGHT * 1.5 + Vector3.UP * 0.1
			bot.state = Roomba.State.PATROL
			for f in 20:
				await get_tree().physics_frame
			print("DevCapture prop geyser_bot: %s state=%s %.1f m from the hydrant, could claim it=%s" % [bot.name, Roomba.State.keys()[bot.state],
				Motion.flat_distance(bot.global_position, p.global_position), MessManager.instance.claim_nearest(p.global_position, 20.0, bot) == p])
	if args.has("prop_twice") and multiplayer.is_server():
		MessManager.instance.tidy(p.id)
		for f in 30:
			await get_tree().physics_frame
		_print_prop(p, "tidied")
		MessManager.instance._asked.clear()
		MessManager.instance.knock(player.player_id, p.id, push)
		for f in 30:
			await get_tree().physics_frame
		_print_prop(p, "busted again")
	return p


func _nearest_tidy_bot(scene: Node, to: Vector3) -> Roomba:
	var bot: Roomba = null
	var best := INF
	for node in scene.get_node("Roombas").get_children():
		var r := node as Roomba
		if r != null and r.tidies_messes and not r.is_boss and r.breach_hub == null and not r.is_queued_for_deletion():
			var d := Motion.flat_distance(r.global_position, to)
			if d < best:
				best = d
				bot = r
	return bot


## One "DevCapture prop" line: everything a STREET PROPS PACK prop is doing right now.
func _print_prop(p: MessProp, when: String) -> void:
	var drops: Array = []
	for world_id in ItemManager.instance.world:
		var entry: Dictionary = ItemManager.instance.world[world_id]
		if Motion.flat_distance(entry.pos, p.global_position) < 3.0 and int(world_id) >= 100000:
			drops.append(entry.item)
	var glow := "-"
	if not p._glow_meshes.is_empty():
		glow = "%.2f" % (p._glow_meshes[0].get_instance_shader_parameter("instance_tint") as Color).r
	var lid := "-"
	if p._lid != null:
		lid = "%.0f deg" % rad_to_deg(p._lid_home.basis.get_rotation_quaternion().angle_to(p._lid.transform.basis.get_rotation_quaternion()))
	var cap := "-"
	if p._cap != null:
		cap = "%.2f m" % p._cap.position.distance_to(p._cap_home.origin)
	var flap := "-"
	if p._flap != null:
		flap = "%.0f deg" % rad_to_deg(p._flap_home.basis.get_rotation_quaternion().angle_to(p._flap.transform.basis.get_rotation_quaternion()))
	print("DevCapture prop (%s): %s %s knocked=%s geyser=%s (%.1f s) rest=%s moved=%.1f m lid=%s cap=%s flap=%s glow=%s light=%s looted=%s drops=%s debris=%d layer=%d" % [
		when, p.name, MessProp.Kind.keys()[p.kind], p.knocked, p.geyser_active(), p._geyser_left, p.tidy_spot().snapped(Vector3.ONE * 0.1),
		Motion.flat_distance(p.tidy_spot(), p.global_position), lid, cap, flap, glow, str(p._light.visible) if p._light != null else "-",
		MessManager.instance.was_looted(p.id), drops, p._debris.get_child_count() if p._debris != null else 0, p._body.collision_layer])


## The nearest standing mess prop of a kind ("" = any; "bin", "cone", "box", "poster", "vending", "hydrant",
## "cart", "neon_sign", "dumpster").
func _nearest_prop(from: Vector3, kind: String) -> MessProp:
	var best: MessProp = null
	var best_distance := INF
	for p in MessManager.instance.props():
		if p.knocked or (kind != "" and MessProp.Kind.keys()[p.kind] != kind.to_upper()):
			continue
		var d := Motion.flat_distance(p.global_position, from)
		if d < best_distance:
			best = p
			best_distance = d
	return best


## One "DevCapture mess" line: the props, the counters and what every bot is up to.
func _print_mess(when: String) -> void:
	var mess := MessManager.instance
	if mess == null or Game.instance == null:
		return
	var kinds := {}
	var knocked: Array = []
	var layout := ""  # (every prop's number, kind and spot: must be the same on every computer)
	for p in mess.props():
		var k: String = MessProp.Kind.keys()[p.kind]
		kinds[k] = int(kinds.get(k, 0)) + 1
		layout += "%d%s%s;" % [p.id, k, p.global_position.snapped(Vector3.ONE * 0.01)]
		if p.knocked:
			knocked.append(p.id)
	var states := {}
	var roombas := Game.instance.get_node_or_null("Roombas")
	if roombas != null:
		for node in roombas.get_children():
			if node is Roomba:
				var st: String = Roomba.State.keys()[(node as Roomba).state]
				states[st] = int(states.get(st, 0)) + 1
	print("DevCapture mess (%s): props=%d layout=%08x %s knocked=%s made=%d tidied=%d heat=%.2f bots=%s (%s)" % [when, mess.props().size(), layout.hash(), kinds, knocked,
		mess.messes_made, mess.messes_tidied, HeatMeter.instance.heat if HeatMeter.instance != null else 0.0, states,
		"host" if multiplayer.is_server() else "client"])


func _mess_log(every: int) -> void:
	while is_inside_tree():
		for f in every:
			await get_tree().physics_frame
		_print_mess("log")
