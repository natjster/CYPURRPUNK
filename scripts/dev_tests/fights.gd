extends "res://scripts/dev_tests/dev_test.gd"
## DevCapture test module: PvP, blasts, downed / revive and Sewer Breach tests.
## Made by scripts/dev_capture.gd `_add_module`; its options are listed at the top of dev_capture.gd.


## --breach_log=N: a line every N frames: the gangs breached, the clock, cats, bots, gates, camera.
func _breach_log(every: int) -> void:
	while is_instance_valid(Game.instance):
		for i in every:
			await get_tree().process_frame
		if not is_instance_valid(Game.instance):
			return
		var mainframe := Mainframe.instance
		var bots := []
		for node in RoombaPatrol.instance.get_children():
			if UndergroundHub.is_in_hub(node.global_position):
				bots.append(node)
		var chasing := bots.filter(func(bot): return bot.state == Roomba.State.CHASE).size()
		var cats := []
		for cat in Game.instance.players.get_children():
			cats.append("%s team=%d hp=%d ko=%s pos=%s feed=%s" % [cat.name, cat.team, CatHealth.instance.get_health(cat.player_id), cat.knocked_out, cat.global_position.snapped(Vector3.ONE * 0.1), mainframe.is_spectating(cat)])
		var camera := GameScreen.instance.game_viewport.get_camera_3d()
		print("DevCapture breach: busy=%s teams=%s left=%.1f charges=%s heat=%.0f sewer bots=%d chasing=%d hurt=%d east_bank=%d queue=%d gates=%s safe=%s camera=%s line=\"%s\" cats=%s" % [mainframe.breach_busy, mainframe.breached_teams, mainframe.breach_left, mainframe.charges, HeatMeter.instance.heat, bots.size(), chasing, bots.filter(func(bot): return bot.health < bot.max_health).size(), bots.filter(func(bot): return UndergroundHub.hub_at(bot.global_position).to_local(bot.global_position).x > 2.0).size(), RoombaPatrol.instance._breach_queue.size(),
			[UndergroundHub.for_team(0)._gate.position.y, UndergroundHub.for_team(1)._gate.position.y], [UndergroundHub.is_safe(UndergroundHub.for_team(0).global_position), UndergroundHub.is_safe(UndergroundHub.for_team(1).global_position)], camera.name if camera != null else "none", (Hud.element("DropOff") as Label).text, cats])

		var fighters := get_tree().get_nodes_in_group(Npc.GROUP).filter(func(npc): return npc.fighting)
		var shots := 0
		var hits := 0
		for npc in fighters:
			shots += npc.breach_shots
			hits += npc.breach_hits
		print("DevCapture breach npcs: fighting=%d guns=%d down=%d shots=%d hits=%d" % [fighters.size(), fighters.filter(func(npc): return npc._gun != null).size(), fighters.filter(func(npc): return npc.is_knocked_down).size(), shots, hits])


## --breach_knock=N: after N frames, a bot right beside every fighting NPC.
func _breach_knock(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	var bots := get_tree().get_nodes_in_group(Enemy.GROUP).filter(func(bot): return UndergroundHub.is_in_hub(bot.global_position))
	var fighters := get_tree().get_nodes_in_group(Npc.GROUP).filter(func(npc): return npc.fighting)
	for i in mini(bots.size(), fighters.size()):
		bots[i].global_position = fighters[i].global_position + Vector3(1.0, 0.1, 0.0)


## --breach_wipe=N: after N frames, a killing blow for every cat in a breached sewer.
func _breach_wipe(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	for player_id in Game.instance.player_ids():
		if Mainframe.instance.is_breached(Teams.team_of(player_id)):
			CatHealth.instance.damage(player_id, 99999, "THE TEST")


## --shoot_rival=N [--rival_wait=F]: stand 4 m from the nearest cat of the OTHER gang (waits up to
## F frames for one, default 600) and hit it N times with the gun in our right paw (--give=pistol),
## exactly like a real bolt does (Hit -> receive_hit). Prints its health after each hit.
func _shoot_rival(scene: Node, player: CatPlayer, args: Dictionary) -> void:
	var health := CatHealth.instance
	var rival: CatPlayer = null
	for i in int(args.get("rival_wait", "600")):
		for other in scene.players.get_children():
			var cat := other as CatPlayer
			# (--shoot_friend: aim at our own gang instead, to check friendly fire is off)
			if cat != player and (cat.team != player.team) != args.has("shoot_friend") \
					and Game.instance.is_up_top(cat.player_id) and not health.is_down(cat.player_id) \
					and (rival == null or cat.global_position.distance_to(player.global_position) < rival.global_position.distance_to(player.global_position)):
				rival = cat
		if rival != null:
			break
		await get_tree().physics_frame
	if rival == null:
		print("DevCapture shoot: no rival up top to shoot")
		return
	player.teleport_to(rival.global_position + Vector3(4, 0.2, 0), 0.0)
	for i in 20:
		await get_tree().physics_frame  # let the host see our new position first
	var gun := ItemManager.instance.held_item(player, 0) as Weapon
	for shot in int(args["shoot_rival"]):
		if gun != null and gun.blast_radius > 0.0:
			# A blast gun: set it off right on them, the way a real shot lands.
			gun._blast(rival.global_position + Vector3(0.5, 0, 0), Vector3.LEFT)
			for i in 15:
				await get_tree().physics_frame
			print("DevCapture blast %d at %s (gang %d): hp=%d at %s" % [shot + 1, rival.display_name(), rival.team,
				health.get_health(rival.player_id), rival.global_position.snapped(Vector3.ONE * 0.1)])
			continue
		for volley in int(args.get("rival_volley", "1")) - 1:
			var pellet := gun._make_hit((rival.global_position - player.global_position).normalized(), rival.global_position)
			rival.receive_hit(pellet)
		var hit := Hit.new()
		hit.shooter = player
		hit.weapon = gun
		hit.damage = gun.damage if gun != null else 40
		hit.direction = (rival.global_position - player.global_position).normalized()
		hit.position = rival.global_position + Vector3.UP * 0.5
		var number := rival.receive_hit(hit) if gun != null else false
		for i in 15:
			await get_tree().physics_frame
		print("DevCapture shoot %d at %s (gang %d): number=%s hp=%d downed=%s knocked_out_or_down=%s" % [shot + 1,
			rival.display_name(), rival.team, number, health.get_health(rival.player_id), health.is_downed(rival.player_id),
			health.is_down(rival.player_id)])


## --blast_car: blast beside the nearest car and print where it was, its speed and where it landed.
func _blast_car(scene: Node, player: CatPlayer) -> void:
	for i in 30:
		await get_tree().physics_frame
	var gun := ItemManager.instance.held_item(player, 0) as Weapon
	var car: GetawayCar = null
	for candidate: GetawayCar in (scene as Game).cars():
		if car == null or candidate.global_position.distance_to(player.global_position) < car.global_position.distance_to(player.global_position):
			car = candidate
	var before := car.global_position
	gun._blast(before + Vector3(1, 0, 0), Vector3.LEFT)
	for i in 30:
		await get_tree().physics_frame
	print("DevCapture blast_car %s driver=%d: from %s to %s speed=%.1f" % [car.name, car.driver_id, before.snapped(Vector3.ONE * 0.1),
		car.global_position.snapped(Vector3.ONE * 0.1), car.linear_velocity.length()])


## --blast_probe: everything a blast's sphere finds at our feet, and how many of those can be hit.
func _blast_probe(player: CatPlayer) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = 5.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, player.global_position)
	var found := player.get_world_3d().direct_space_state.intersect_shape(query, 2048)
	var hittable := 0
	for result in found:
		if Hit.target_of(result.collider) != null:
			hittable += 1
	print("DevCapture blast_probe: %d found, %d hittable" % [found.size(), hittable])


## --down=S [--revive=N] [--bleed_out=SEC]: knock the cat in slot S down in front of us, then
## (with --revive) press and hold E on it like a teammate would. Prints what happened.
func _down_and_revive(scene: Node, player: CatPlayer, args: Dictionary) -> void:
	var health := CatHealth.instance
	if args.has("bleed_out"):
		health.bleed_out_seconds = float(args["bleed_out"])
	var victim: CatPlayer = null
	if multiplayer.is_server():
		victim = scene.cat_for(PlayerId.make(multiplayer.get_unique_id(), int(args["down"])))
	else:
		# A client with --revive=N: wait (up to ~10 s) for any downed cat, then walk up to it.
		for i in 600:
			for other in scene.players.get_children():
				if health.is_downed((other as CatPlayer).player_id):
					victim = other
			if victim != null:
				break
			await get_tree().physics_frame
		if victim != null:
			player.teleport_to(victim.global_position + Vector3(1.0, 0.2, 0), 0.0)
			for i in 20:
				await get_tree().physics_frame  # let the host see our new position first
	if victim == null:
		print("DevCapture down: no cat to down / revive")
		return
	var report := func(label: String) -> void:
		print("DevCapture down %s: %s hp=%d downed=%s bleed_left=%.1f reviver=%d robbed=%s knocked_out=%s their_bag=%s our_bag=%s" % [
			label, victim.name, health.get_health(victim.player_id), health.is_downed(victim.player_id),
			health.bleed_out_left(victim.player_id), health.reviver_of(victim.player_id), health.is_being_robbed(victim.player_id),
			victim.knocked_out, ItemManager.instance.loot_in_pack(victim.player_id), ItemManager.instance.loot_in_pack(player.player_id)])
	if multiplayer.is_server():
		if victim != player:
			var ahead := -player.camera_pivot.global_basis.z
			victim.teleport_to(player.global_position + Vector3(ahead.x, 0, ahead.z).normalized() * 1.5, 0.0)
		for i in 10:
			await get_tree().physics_frame
		if args.has("down_loot"):
			for item_id in args["down_loot"].split(","):
				ItemManager.instance._put_in_inventory(victim.player_id, item_id, victim.global_position)
		health.damage(victim.player_id, 100, "A TEST")
		for i in 5:
			await get_tree().physics_frame
	report.call("after hit")
	if victim != player:
		print("DevCapture down prompt for us: \"%s\"" % Interactable.prompt_for(player))
	if args.has("revive") and victim != player:
		Interactable.try_use(player)  # what pressing E does...
		Input.action_press(Seats.action(player.slot, "interact"))  # ...and keep holding it
		for i in int(args["revive"]):
			await get_tree().physics_frame
			if i == 60:
				report.call("1 s into revive (prompt \"%s\")" % Interactable.prompt_for(player))
			if i == 100 and args.has("revive_snap"):  # --revive_snap=PATH: a picture mid-revive
				get_tree().root.get_texture().get_image().save_png("res://" + args["revive_snap"])
		Input.action_release(Seats.action(player.slot, "interact"))
		for i in 10:
			await get_tree().physics_frame
		report.call("after revive")


## --feedback_test: PLAYER FEEDBACK (scripts/feedback.gd). Host only, our cat must be up top.
func _feedback_test(player: CatPlayer) -> void:
	var id := player.player_id
	await _seconds(0.3)
	CatHealth.instance.damage(id, 80, "TEST")
	await get_tree().process_frame
	await get_tree().process_frame
	var flash := Hud.element("HurtFlash", player.slot) as HudHurtFlash
	print("DevCapture feedback hurt: hp=%d shake_h=%.3f shake_v=%.3f flash=%.2f" % [CatHealth.instance.get_health(id),
		player.camera.h_offset, player.camera.v_offset, flash._flash if flash != null else -1.0])
	Events.item_picked_up.emit(id, "golden_koi")
	Events.item_picked_up.emit(id, "catnip")
	Events.item_picked_up.emit(id, "catnip")
	var toast := Hud.element("LootToast", player.slot) as HudLootToast
	print("DevCapture feedback toasts: %s" % [toast._toasts.map(func(t): return "%s x%d $%d" % [t.name, t.count, t.cash]) if toast != null else "MISSING"])
	var marker := Hud.element("Hitmarker", player.slot) as HudHitmarker
	var ahead := player.global_position - player.camera.global_basis.z * 4.0 + Vector3.UP
	for i in 8:
		Hud.damage_number(ahead, 30, i % 3 == 1, player.slot)
		await _seconds(0.1)
		Feedback.enemy_smashed(id, ahead, i == 5)
		await get_tree().process_frame
		if i < 2 or i == 5:
			print("DevCapture feedback kill %d: marker_kind=%d left=%.2f shake_h=%.3f low_pulse=%.2f" % [i,
				marker._kind if marker != null else -1, marker._left if marker != null else -1.0,
				player.camera.h_offset, flash._low if flash != null else -1.0])
		await _seconds(0.2)
	# (The snap waits for this test: end with everything on screen for it.)
	Events.item_picked_up.emit(id, "golden_koi")
	Events.item_picked_up.emit(id, "fish")
	CatHealth.instance.damage(id, 5, "TEST")
	await _seconds(0.25)
	Feedback.enemy_smashed(id, ahead, false)
	await get_tree().process_frame
	print("DevCapture feedback final: marker visible=%s rect=%s left=%.2f, flash=%.2f low=%.2f" % [marker.is_visible_in_tree(),
		marker.get_global_rect(), marker._left, flash._flash, flash._low])


## --swing_test[=SECONDS]: (needs --give=neon_bat) play one CONNECTING bat swing with sparks in front of
## us, plus a red "you lost health" number, then wait SECONDS (default 0.09) so the snap lands mid-slash.
## Prints a "DevCapture swing" line (trail samples, bat ends).
func _swing_test(player: CatPlayer, args: Dictionary) -> void:
	await _seconds(0.6)
	var bats := player.find_children("*", "MeleeWeapon", true, false)
	if bats.is_empty():
		print("DevCapture swing: no melee weapon (add --give=neon_bat)")
		return
	var bat := bats[0] as MeleeWeapon
	var ahead := player.global_position - player.cat_model.global_basis.z * 1.4 + Vector3.UP * 0.4
	bat.show_swing.rpc(true, PackedVector3Array([ahead]))
	Feedback.hurt(player.player_id, 23)
	var wait := str(args["swing_test"])
	await _seconds(float(wait) if wait.is_valid_float() else 0.09)
	print("DevCapture swing: trail_points=%d base=%s tip=%s" % [bat._trail_points.size(), bat._trail_base, bat._trail_tip])


## --combo_test[=GAP]: (needs --give=neon_bat; add --bait_roomba=2 for something to hit) swing the bat for
## real 3 times, GAP seconds apart (default 0.5): forehand, backhand, SLAM. Prints a "DevCapture combo"
## line per swing (step, the nearest VAC-COP's health and stun) and waits a moment so the snap shows the
## slam's shockwave. --air_slam: jump first, so the first swing is an AIR SLAM.
func _combo_test(player: CatPlayer, args: Dictionary) -> void:
	await _seconds(0.8)
	var bats := player.find_children("*", "MeleeWeapon", true, false)
	if bats.is_empty():
		print("DevCapture combo: no melee weapon (add --give=neon_bat)")
		return
	var bat := bats[0] as MeleeWeapon
	var gap_arg := str(args["combo_test"])
	var gap := float(gap_arg) if gap_arg.is_valid_float() else 0.5
	var target := _nearest_roomba(Game.instance, player.global_position)
	if args.has("slam_charged"):
		bat.slam_charge = 1.0  # --slam_charged: start with the SLAM METER full (frozen tuna)
	if args.has("air_slam"):
		player.velocity.y = 9.0
		await _seconds(0.25)
	for i in 3:
		var step := 2 if (args.has("air_slam") and not player.is_on_floor()) else bat.combo_step
		var hp_before: int = target.health if target != null and is_instance_valid(target) else -1
		bat._fire()
		await _seconds(0.05)
		var hp: int = target.health if target != null and is_instance_valid(target) else -1
		print("DevCapture combo: swing=%d step=%d next=%d vy=%.1f target_hp=%d->%d slam_spot=%s can_slam=%s charge=%.2f" % [
			i + 1, step, bat.combo_step, player.velocity.y, hp_before, hp, bat.last_slam_spot, bat.can_slam, bat.slam_charge])
		if i < 2:
			await _seconds(gap)
	var rings := Game.instance.find_children("SlamShockwave", "MeshInstance3D", false, false)
	for ring in rings:
		var r := ring as MeshInstance3D
		print("DevCapture combo: shockwave at %s scale=%s alpha=%.2f visible=%s" % [r.global_position, r.scale,
			((r.mesh as PrimitiveMesh).material as StandardMaterial3D).albedo_color.a, r.is_visible_in_tree()])
	await _seconds(0.06)


## --melee_test=scratch[:N] / throw: the MELEE button (scripts/cat/cat_melee.gd). scratch = N claw swipes
## (default 3: right, left, X RAKE), 0.2 s apart; throw = throw the bat in the LEFT paw (needs
## --give=neon_bat). Add --bait_roomba=1.5 for something to hit. Prints "DevCapture melee" lines: what
## each did, the nearest VAC-COP's health, our paws, and (after a throw) where the bat landed.
func _melee_test(player: CatPlayer, args: Dictionary) -> void:
	await _seconds(0.8)
	var melee := player.melee
	var what := str(args["melee_test"])
	var target := _nearest_roomba(Game.instance, player.global_position)
	var items := ItemManager.instance
	print("DevCapture melee: hands=%s" % [items.get_inventory(player.player_id).hands])
	if what.begins_with("throw"):
		var left := items.held_item(player, 1)
		if not left is MeleeWeapon:
			print("DevCapture melee: nothing throwable in the LEFT paw")
			return
		var hp_before: int = target.health if target != null else -1
		melee._throw(left as MeleeWeapon)
		print("DevCapture melee: %s" % melee.last_result)
		await _seconds(0.15)
		var flying := Game.instance.get_node_or_null("Thrown")
		print("DevCapture melee: mid-flight thrown=%s at=%s" % [flying != null, (flying as Node3D).global_position if flying != null else Vector3.ZERO])
		await _seconds(1.4)
		print("DevCapture melee: after throw hands=%s target_hp=%d->%d world_bats=%d" % [items.get_inventory(player.player_id).hands,
			hp_before, target.health if target != null and is_instance_valid(target) else -1,
			items.world.values().filter(func(w): return w.item == "neon_bat").size()])
		return
	var count := int(what.get_slice(":", 1)) if what.contains(":") else 3
	await _seconds(1.0)  # (let the cat land after popping out of the manhole)
	for i in count:
		if target != null and is_instance_valid(target) and args.has("bait_roomba"):
			# Keep the bot right in front of the claws for every swipe (it gets shoved away).
			var ahead := -player.camera.global_basis.z
			target.global_position = player.global_position + Vector3(ahead.x, 0, ahead.z).normalized() * float(args["bait_roomba"]) + Vector3(0, 0.1, 0)
			await _seconds(0.02)
		var hp_before: int = target.health if target != null and is_instance_valid(target) else -1
		melee._scratch()
		await _seconds(0.05)
		var off := (target.global_position - player.global_position) if target != null and is_instance_valid(target) else Vector3.ZERO
		var look := -player.camera.global_basis.z
		print("DevCapture melee: target offset=%s dist=%.2f look=%s" % [off, Vector2(off.x, off.z).length(), Vector3(look.x, 0, look.z).normalized()])
		print("DevCapture melee: %s target_hp=%d->%d marks=%d pitch=%.2f" % [melee.last_result, hp_before,
			target.health if target != null and is_instance_valid(target) else -1, melee._marks.size(), melee.body_pitch()])
		if i < count - 1:
			await _seconds(0.15)
