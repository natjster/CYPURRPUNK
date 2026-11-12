extends "res://scripts/dev_tests/dev_test.gd"
## CAR tests (debug-only, run by DevCapture): car HEALTH + wrecks (scripts/car/car_health.gd), the
## AFTERBURNER boost (scripts/car/car_boost.gd), bots chasing cats in cars (roomba.gd), and the
## GUNNER seat (scripts/cat/cat_ride.gd). Host only, with --drive (we're behind the wheel):
##   --car_test     boost + launch + ram + wreck + repair, "DevCapture car_test ..." lines
##   --car_chase    a VAC-COP 10 m away: does it chase the car and dent it? "DevCapture car_chase ..."
##   --car_juice    launch, a handbrake drift, the DRIFT TURBO kick, body lean (scripts/car/car_juice.gd)
##   --gunner_test  (with --add_local=1 --ride_along=1) the passenger shoots a bot from the car


## --car_juice: floor it, drift left with the handbrake, let go, and print what the juice did.
func _car_juice_test(player: CatPlayer) -> void:
	var car := await _wait_for_wheel(player)
	if car == null:
		return
	var juice := car.juice
	var keys := func(actions: Array, down: bool) -> void:
		for action in actions:
			if down:
				Input.action_press(Seats.action(player.slot, action))
			else:
				Input.action_release(Seats.action(player.slot, action))
	keys.call(["gas"], true)
	var launch_streaks := 0
	for i in 60:
		await get_tree().physics_frame
		launch_streaks = maxi(launch_streaks, car.get_node("Streaks").streak_count())
	print("DevCapture car_juice launch streaks: up to %d on screen in the first second" % launch_streaks)
	var speed_1s := -car.global_basis.z.dot(car.linear_velocity)
	for i in 60:
		await get_tree().physics_frame
	print("DevCapture car_juice launch: %.1f m/s after 1 s, %.1f after 2 s (top %.1f)" % [speed_1s,
		-car.global_basis.z.dot(car.linear_velocity), car.max_speed])
	keys.call(["move_left", "handbrake"], true)
	var best_level := 0
	var roll := 0.0
	for i in 110:
		await get_tree().physics_frame
		best_level = maxi(best_level, juice.turbo_level(juice._drift_time))
		var model := car.get_node("Model/CarModel") as Node3D
		roll = maxf(roll, absf(model.rotation.z))
		if i % 15 == 0:
			print("DevCapture car_juice t=%d fwd=%.1f side=%.1f drift_time=%.2f contacts=%d" % [i,
				-car.global_basis.z.dot(car.linear_velocity), car.global_basis.x.dot(car.linear_velocity), juice._drift_time,
				car.get_contact_count()])
	var before := -car.global_basis.z.dot(car.linear_velocity)
	keys.call(["move_left", "handbrake"], false)
	for i in 3:
		await get_tree().physics_frame
	var after := -car.global_basis.z.dot(car.linear_velocity)
	print("DevCapture car_juice drift: turbo level %d (1 blue, 2 orange), sparks=%s, body roll %.1f deg, speed %.1f -> %.1f after letting go" % [
		best_level, juice.sparks_on or best_level > 0, rad_to_deg(roll), before, after])
	keys.call(["gas"], false)


## --car_test
func _car_test(scene: Node, player: CatPlayer) -> void:
	var car := await _wait_for_wheel(player)
	if car == null:
		return
	var boost := car.boost
	var health := car.health
	print("DevCapture car_test start: hp=%d/%d charges=%d max=%d" % [health.health, health.max_health, boost.charges, boost.max_charges()])
	# Pretend the crew bought AFTERBURNER tier 1 (2 charges: 1 to start + 1). (A test switch, not a real upgrade:
	# real upgrades would be saved into the test cat's profile.)
	CarBoost.test_charges = 2
	for i in 5:
		await get_tree().physics_frame
	print("DevCapture car_test upgrade: charges=%d max=%d" % [boost.charges, boost.max_charges()])

	# Two bots: one in the exhaust (3 m behind), one right in front (4 m ahead).
	var bots: Array[Roomba] = []
	for node in scene.get_node("Roombas").get_children():
		if node is Roomba and not (node as Roomba).is_boss and bots.size() < 3:
			bots.append(node)
	if bots.size() < 3:
		print("DevCapture car_test: not enough bots (%d)" % bots.size())
		return
	var back := Motion.flat(car.global_basis.z).normalized()
	if not _args.has("boost_snap"):  # (the picture: keep the view of the flames clear)
		bots[0].global_position = car.global_position + back * 4.0
		bots[1].global_position = car.global_position - back * 5.0
	for bot in bots:
		bot.velocity = Vector3.ZERO
	for i in 3:
		await get_tree().physics_frame
	boost.request_boost.rpc_id(1, car.driver_id)
	if _args.has("boost_snap"):
		return  # --boost_snap: stop here so the picture (--frames=N later) catches the flames
	await get_tree().physics_frame
	await get_tree().physics_frame
	var speed_after := -car.global_basis.z.dot(car.linear_velocity)
	var top_y := [bots[0].global_position.y, bots[1].global_position.y]
	var flew := [false, false]
	for i in 40:
		await get_tree().physics_frame
		for b in 2:
			flew[b] = flew[b] or bots[b].is_flying
			top_y[b] = maxf(top_y[b], bots[b].global_position.y)
	print("DevCapture car_test boost: speed_after=%.1f boosting_during=%s charges=%d flame_visible=%s streaks=%d" % [speed_after,
		boost._flames[0].visible or not boost.is_boosting(), boost.charges, boost._flames[0].visible or not boost.is_boosting(),
		car.get_node("Streaks").streak_count()])
	print("DevCapture car_test launch: exhaust_bot flew=%s top_y=%.1f alive=%s | front_bot flew=%s top_y=%.1f alive=%s" % [flew[0], top_y[0],
		is_instance_valid(bots[0]) and bots[0].health > 0, flew[1], top_y[1], is_instance_valid(bots[1]) and bots[1].health > 0])

	# A VAC-COP rams the car.
	bots[2]._bonk_car(car)
	await get_tree().physics_frame
	print("DevCapture car_test ram: hp=%d (expect %d)" % [health.health, health.max_health - roundi(bots[2].bonk_damage * bots[2].car_damage_multiplier)])

	# A fake CRASH (30 m/s to a dead stop): with Crashes Hurt off (the default) the car must NOT lose HP.
	var hp_before := health.health
	health._recent_speed = 30.0
	car.linear_velocity = Vector3.ZERO
	health._check_for_crash(1.0 / 60.0)
	for i in 3:
		await get_tree().physics_frame
	var bins := 0
	for p in MessManager.instance.props():
		if p.kind == MessProp.Kind.BIN:
			bins += 1
	print("DevCapture car_test crash: hp=%d (expect %d, crashes_hurt=%s) trash_bins_in_city=%d" % [health.health, hp_before,
		health.crashes_hurt, bins])

	# WRECK it: everyone out, can't get back in, then towed back fixed.
	health.wreck_seconds = 1.5
	health.damage(9999, "TEST")
	for i in 5:
		await get_tree().physics_frame
	print("DevCapture car_test wreck: wrecked=%s driver=%d cat_visible=%s cat_hp=%d smoke=%s fire=%s can_enter=%.1f" % [health.wrecked,
		car.driver_id, player.visible, CatHealth.instance.get_health(player.player_id), health._smoke.emitting, health._fire.emitting,
		car.interact_distance(player)])
	car.request_enter.rpc_id(1, player.player_id)
	await get_tree().physics_frame
	print("DevCapture car_test wreck_enter: driver=%d (expect 0)" % car.driver_id)
	await _seconds(2.0)
	print("DevCapture car_test repaired: wrecked=%s hp=%d at_spot=%s" % [health.wrecked, health.health,
		car.global_position.distance_to(car.parking_spot().origin) < 2.0])


## --car_chase: a VAC-COP 10 m away should chase the CAR (cat inside) and dent it when it gets there.
func _car_chase(scene: Node, player: CatPlayer) -> void:
	var car := await _wait_for_wheel(player)
	if car == null:
		return
	var bot: Roomba = null
	for node in scene.get_node("Roombas").get_children():
		if node is Roomba and not (node is SquirtDrone or node is LintTrapper or (node as Roomba).is_boss):
			bot = node
			break
	if bot == null:
		print("DevCapture car_chase: no VAC-COP")
		return
	# Up the street in front of the car (beside it could be inside a building).
	bot.global_position = car.global_position - Motion.flat(car.global_basis.z).normalized() * 10.0
	bot.state = Roomba.State.PATROL
	var start_hp := car.health.health
	var chased := false
	for i in 400:
		await get_tree().physics_frame
		chased = chased or (bot.state == Roomba.State.CHASE and bot._chase_id == player.player_id)
		if car.health.health < start_hp:
			break
	print("DevCapture car_chase: cat_follows_car=%s chased=%s car_hp=%d->%d bot_dist=%.1f state=%d" % [
		player.global_position.distance_to(car.global_position) < 1.5, chased, start_hp, car.health.health,
		Motion.flat_distance(bot.global_position, car.global_position), bot.state])


## --gunner_test: couch player 2 rides along and shoots a bot standing next to the car.
func _gunner_test(scene: Node, player: CatPlayer) -> void:
	var car := await _wait_for_wheel(player)
	if car == null:
		return
	for i in 120:
		if not car.passenger_ids.is_empty():
			break
		await get_tree().physics_frame
	if car.passenger_ids.is_empty():
		print("DevCapture gunner_test: nobody rode along")
		return
	var rider := Game.instance.cat_for(car.passenger_ids[0])
	ItemManager.instance._put_in_inventory(rider.player_id, "pistol", rider.global_position)
	for i in 10:
		await get_tree().physics_frame
	var gun := ItemManager.instance.held_item(rider, 0) as Weapon
	var bot: Roomba = null
	for node in scene.get_node("Roombas").get_children():
		if node is Roomba and not (node as Roomba).is_boss:
			bot = node
			break
	print("DevCapture gunner_test seat: gunner=%s own_camera=%s body_in_car=%s gun=%s" % [rider.is_gunner(),
		rider.camera.get_parent() == rider.spring_arm, rider.global_position.distance_to(car.global_position) < 1.5,
		gun.data.id if gun != null else "none"])
	if gun == null or bot == null:
		return
	# Park the bot to the right of the car and turn the gunner's camera at it.
	bot.global_position = car.global_position - Motion.flat(car.global_basis.z).normalized() * 7.0
	bot.velocity = Vector3.ZERO
	bot.state = Roomba.State.STUNNED
	bot._stun_left = 5.0
	for i in 3:
		await get_tree().physics_frame
	# The camera sits on the spring arm's line, so a shot through the screen centre passes through the
	# arm's pivot: point the arm from there at the bot (yaw on the pivot, pitch on the arm).
	var aim := bot.global_position + Vector3.UP * 0.25 - rider.spring_arm.global_position
	rider.camera_pivot.global_rotation.y = atan2(-aim.x, -aim.z)
	rider.spring_arm.rotation.x = atan2(aim.y, Vector2(aim.x, aim.z).length())
	await get_tree().process_frame
	var hp_before := bot.health
	var car_hp := car.health.health
	gun._fire()
	for i in 5:
		await get_tree().physics_frame
	print("DevCapture gunner_test shot: bot_hp %d->%d car_hp %d->%d (car must not be hit)" % [hp_before, bot.health, car_hp, car.health.health])


## Wait until our cat is driving (the --drive flow gets it in). null = never got in.
func _wait_for_wheel(player: CatPlayer) -> GetawayCar:
	for i in 240:
		var car := Game.instance.car_of(player.player_id)
		if car != null and car.driver_id == player.player_id:
			return car
		await get_tree().physics_frame
	print("DevCapture car: never got behind the wheel")
	return null
