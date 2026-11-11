extends "res://scripts/dev_tests/dev_test.gd"
## DevCapture test module: Meow-Mart interior heist tests.
## Made by scripts/dev_capture.gd `_add_module`; its options are listed at the top of dev_capture.gd.


func _meow_mart_test(player: CatPlayer, args: Dictionary) -> void:
	var mart := MeowMartInterior.instance
	if mart == null:
		print("DevCapture mart: no MeowMart node")
		return
	if args.has("mart_log"):
		_mart_log(player, maxi(1, int(args["mart_log"]) if args["mart_log"] != "true" else 60))
	if args.has("test_meow_mart"):
		var distance := float(args["test_meow_mart"]) if args["test_meow_mart"] != "true" else 4.0
		var out := mart.street_outward()
		player.teleport_to(mart.street_spot(distance) + Vector3(0, 0.3, 0), atan2(out.x, out.z))  # facing the doors
		print("DevCapture mart door: door=%s outward=%s cat=%s" % [mart.street_door().snapped(Vector3.ONE * 0.1), out, player.global_position.snapped(Vector3.ONE * 0.1)])
	if args.has("inside_meow_mart"):
		var where: String = args["inside_meow_mart"]
		var spots := {"plate": MeowMartInterior.PLATE_SPOT + Vector3(1.6, 0.2, 0), "aisle": Vector3(-0.75, 0.2, 3.6),
			"tank": MeowMartInterior.TANK_SPOT + Vector3(0, 0.2, 1.6), "backroom": Vector3(4.0, 0.2, -5.0),
			"counter": Vector3(8.4, 0.2, 0.0), "door": Vector3(0, 0.2, 7.0)}
		var local: Vector3 = spots.get(where, MeowMartInterior.FOYER_SPOT)
		player.teleport_to(mart.to_global(local), PI if where == "door" else 0.0)
		for i in 10:
			await get_tree().physics_frame
		print("DevCapture mart inside: at %s contains=%s prompt=\"%s\"" % [where, MeowMartInterior.contains(player.global_position), Interactable.prompt_for(player)])
	if args.has("mart_swat"):
		var done := 0
		for stack in mart._stacks:
			if done >= int(args["mart_swat"]):
				break
			var home: Vector3 = stack.get_meta("home").origin
			if home.y > 0.5:
				continue  # (the low ledges: reachable from the floor)
			var side := signf(home.x - MeowMartInterior.AISLE_X[stack.get_meta("aisle")])
			player.teleport_to(mart.to_global(Vector3(home.x + side * 0.5, 0.2, home.z)), 0.0)
			for i in 4:
				await get_tree().physics_frame
			var prompt := Interactable.prompt_for(player)
			mart.cat_bump(player, Vector3(-side * 4.5, 0, 0))  # walk into it (E would grab loot first, if any is near)
			for i in 6:
				await get_tree().physics_frame
			print("DevCapture mart swat: stack %d prompt=\"%s\" swatted=%s" % [stack.get_meta("id"), prompt, mart.swatted.has(stack.get_meta("id"))])
			done += 1
	if args.has("mart_topple"):
		var aisle := clampi(int(args["mart_topple"]) - 1, 0, 1)
		player.teleport_to(mart.to_global(Vector3(MeowMartInterior.AISLE_X[aisle] - 0.3, 0.2, MeowMartInterior.AISLE_LENGTH * 0.5 + 0.5)), 0.0)
		for i in 4:
			await get_tree().physics_frame
		mart.cat_bump(player, Vector3(0, 0, -9.0))  # as if the cat ran at it with zoomies
		for i in 90:
			await get_tree().physics_frame
		print("DevCapture mart topple: aisle %d toppled=%s swatted=%d" % [aisle + 1, mart.toppled, mart.swatted.size()])
	if args.has("mart_plate"):
		player.teleport_to(mart.to_global(MeowMartInterior.PLATE_SPOT + Vector3(0, 0.2, 0)), 0.0)
		for i in 30:
			await get_tree().physics_frame
		print("DevCapture mart plate on: plate=%s door=%s" % [mart.plate_pressed, mart.security_open])
		player.teleport_to(mart.to_global(MeowMartInterior.FOYER_SPOT), 0.0)
		for i in 60:
			await get_tree().physics_frame
		print("DevCapture mart plate off 1s: plate=%s door=%s" % [mart.plate_pressed, mart.security_open])
		for i in 60:
			await get_tree().physics_frame
		print("DevCapture mart plate off 2s: plate=%s door=%s" % [mart.plate_pressed, mart.security_open])
	if args.has("mart_drag"):
		var start := mart.crate_pos
		var goal := MeowMartInterior.PLATE_SPOT
		var heading := Motion.flat(goal - start).normalized()
		player.teleport_to(mart.to_global(start + heading * 1.0 + Vector3(0, 0.2, 0)), 0.0)
		for i in 6:
			await get_tree().physics_frame
		print("DevCapture mart drag prompt: \"%s\" best=%s cat=%s" % [Interactable.prompt_for(player), mart._best_action(player), mart.to_local(player.global_position).snapped(Vector3.ONE * 0.1)])
		Interactable.try_use(player)
		for i in 6:
			await get_tree().physics_frame
		var walk_from := start + heading * 1.0
		var walk_to := goal + heading * mart.crate_drag_distance
		var steps := int(walk_from.distance_to(walk_to) / 0.06)
		for i in steps:
			var at := walk_from.lerp(walk_to, float(i + 1) / steps)
			player.global_position = mart.to_global(at + Vector3(0, 0.05, 0))
			await get_tree().physics_frame
		for i in 10:
			await get_tree().physics_frame
		Interactable.try_use(player)  # (let go)
		player.teleport_to(mart.to_global(MeowMartInterior.FOYER_SPOT), 0.0)
		for i in 150:
			await get_tree().physics_frame
		print("DevCapture mart drag: crate=%s dragger=%d plate=%s door=%s" % [mart.crate_pos.snapped(Vector3.ONE * 0.1), mart.crate_dragger, mart.plate_pressed, mart.security_open])
	if args.has("mart_tank_hits"):
		player.teleport_to(mart.to_global(MeowMartInterior.TANK_SPOT + Vector3(0, 0.2, 1.2)), 0.0)
		for i in int(args["mart_tank_hits"]):
			for f in 70:  # (one ask per second per thing)
				await get_tree().physics_frame
			var prompt := Interactable.prompt_for(player)
			Interactable.try_use(player)
			for f in 5:
				await get_tree().physics_frame
			print("DevCapture mart tank hit: prompt=\"%s\" hits=%d shattered=%s" % [prompt, mart.tank_hits, mart.shattered])
	if args.has("shatter_tank") and multiplayer.is_server():
		for i in (int(args["shatter_tank"]) if args["shatter_tank"] != "true" else 30):
			await get_tree().physics_frame
		var heat_before := HeatMeter.instance.heat
		var bots_before := RoombaPatrol.instance.get_child_count()
		mart.test_shatter(player.player_id)
		for i in 30:
			await get_tree().physics_frame
		var investigating := 0
		for bot in RoombaPatrol.instance.get_children():
			if bot is Roomba and (bot as Roomba).state == Roomba.State.INVESTIGATE:
				investigating += 1
		var koi := 0
		for id in ItemManager.instance.world:
			if ItemManager.instance.world[id].item == mart.tank_item and MeowMartInterior.contains(ItemManager.instance.world[id].pos):
				koi += 1
		print("DevCapture mart shatter: shattered=%s alarm=%.0f heat %.1f -> %.1f bots %d -> %d investigating=%d koi_on_floor=%d" % [mart.shattered,
			mart.alarm_left, heat_before, HeatMeter.instance.heat, bots_before, RoombaPatrol.instance.get_child_count(), investigating, koi])


## --mart_log=N: the store's state every N frames, for as long as the run lasts.
func _mart_log(player: CatPlayer, every: int) -> void:
	while is_inside_tree():
		for i in every:
			await get_tree().physics_frame
		if MeowMartInterior.instance == null or not is_instance_valid(player):
			return
		print("DevCapture mart: %s cat=%s in=%s" % [MeowMartInterior.instance.debug_line(), player.global_position.snapped(Vector3.ONE * 0.1), MeowMartInterior.contains(player.global_position)])
