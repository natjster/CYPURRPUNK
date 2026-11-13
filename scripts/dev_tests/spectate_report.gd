extends "res://scripts/dev_tests/dev_test.gd"
## DevCapture test module: Cat-cam (spectating) and Raid Report tests.
## Made by scripts/dev_capture.gd `_add_module`; its options are listed at the top of dev_capture.gd.


## --spectate / --spectate_ko / --heckle / --spectate_switch / --spectate_exit: THE CAT-CAM (scripts/spectator.gd).
func _spectate_tests(scene: Node, args: Dictionary) -> void:
	var seat := int(args.get("spectate", "0")) if args.get("spectate", "true") != "true" else 0
	var me: CatPlayer = scene.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat))
	var spectator := Spectator.instance
	var others: Array = scene.local_cats().filter(func(c): return c != me)
	if others.is_empty():
		# Online: wait for another computer's cat to come up top (e.g. a client with --deploy).
		for i in 900:
			if not Spectator.instance.watchable_for(me).is_empty():
				break
			await get_tree().physics_frame
		others = Spectator.instance.watchable_for(me)
		for other in others:
			print("DevCapture spectate remote: %s yaw=%.2f (sent %.2f) pitch=%.2f (sent %.2f)" % [other.display_name(),
				other.camera_pivot.rotation.y, other.sync_camera_yaw, other.spring_arm.rotation.x, other.sync_camera_pitch])
	if me == null or others.is_empty():
		print("DevCapture spectate: needs --add_local=1 or a client up top (no other cat)")
		return
	var friend: CatPlayer = others[0]
	for other in others:  # (every other couch cat goes up: --spectate_switch needs two)
		other.unseen_by_bots = true  # (so the parked bot LISTENS instead of chasing straight away)
		if other.is_multiplayer_authority():
			UndergroundHub.of(other).deploy(other)
	if args.has("spectate_ko"):
		UndergroundHub.of(me).deploy(me)
	for i in 30:
		await get_tree().physics_frame
	# A VAC-COP 10 m from the friend (out of sight behind them), for the heckle.
	if multiplayer.is_server():
		var bot: Roomba = null
		for node in scene.get_node("Roombas").get_children():
			if node is Roomba and not (node as Roomba).is_boss:
				bot = node
				break
		if bot != null:
			bot.global_position = friend.global_position + Vector3(10, 0.1, 0)
	if args.has("spectate_ko"):
		CatHealth.instance.damage(me.player_id, 99999, "A VAC-COP", true)
		var waited := 0
		while not Spectator.is_watching(seat) and waited < 900:
			await get_tree().physics_frame
			waited += 1
		print("DevCapture spectate ko: watching=%s after %d frames in_hub=%s" % [Spectator.is_watching(seat), waited,
			UndergroundHub.is_in_hub(me.global_position)])
	else:
		me.teleport_to(UndergroundHub.of(me).to_global(UndergroundHub.of(me).catcam_spot) + Vector3(-0.8, 0.2, 0), -PI / 2)
		for i in 15:
			await get_tree().physics_frame
		print("DevCapture spectate prompt: \"%s\"" % Interactable.prompt_for(me))
		await _tap_action(seat, "interact")
	await get_tree().create_timer(spectator.button_grace_seconds + 0.2).timeout  # (headless frames are quick)
	_print_spectate("watching", seat)
	if args.has("spectate_car"):
		# --spectate_car: the watched cat climbs into the getaway car: the view should be the car's chase cam.
		var watched := spectator.watched_cat(seat)
		var car: GetawayCar = scene.cars()[0]
		watched.teleport_to(car.global_position + Vector3(2, 0.2, 0), 0.0)
		for i in 10:
			await get_tree().physics_frame
		car.request_enter.rpc_id(1, watched.player_id)
		for i in 30:
			await get_tree().physics_frame
		var camera := GameScreen.instance.camera_for_seat(seat)
		print("DevCapture spectate car: in_car=%s watching=%s cam_to_car=%.1f cam_y_above_car=%.1f" % [scene.car_of(watched.player_id) != null,
			Spectator.is_watching(seat), camera.global_position.distance_to(car.global_position), camera.global_position.y - car.global_position.y])
	if args.has("spectate_switch"):
		await _tap_action(seat, "move_right")
		await get_tree().create_timer(spectator.button_grace_seconds + 0.2).timeout
		_print_spectate("after switch", seat)
	if args.has("heckle"):
		await _tap_action(seat, "meow")
		for i in 40:
			await get_tree().process_frame
		print("DevCapture heckle: seen=%d text=\"%s\" bots_heard=%d" % [spectator.heckles_seen, spectator.last_heckle_text, spectator.last_heckle_heard])
		await _tap_action(seat, "meow")  # (cooldown: must not heckle again yet)
		print("DevCapture heckle again (cooldown): seen=%d" % spectator.heckles_seen)
	if args.has("spectate_exit"):
		for i in int(args["spectate_exit"]):
			await get_tree().process_frame
		await _tap_action(seat, "interact")
		for i in 10:
			await get_tree().process_frame
		_print_spectate("after exit", seat)


## Press and let go of a seat's button with real input (Seats' per-seat action), a few frames each.
## Seat 0: its first bound KEY, through the game screen like a real player's. Others: the action.
func _tap_action(seat: int, action_name: String) -> void:
	var key: InputEvent = Controls.event_for(Controls.bindings[action_name][0]) if seat == 0 else null
	for pressed in [true, false]:
		if key != null:
			var event := key.duplicate() as InputEvent
			event.set("pressed", pressed)
			Input.parse_input_event(event)
		elif pressed:
			Input.action_press(Seats.action(seat, action_name))
		else:
			Input.action_release(Seats.action(seat, action_name))
		for i in 3:
			await get_tree().process_frame


func _print_spectate(when: String, seat: int) -> void:
	var spectator := Spectator.instance
	var me := Game.instance.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat))
	var watched := spectator.watched_cat(seat)
	var camera := GameScreen.instance.camera_for_seat(seat)
	print("DevCapture spectate %s: watching=%s who=%s camera=%s cam_pos=%s cam_to_watched=%.1f me_pos=%s me_in_hub=%s hud=\"%s\"" % [when,
		Spectator.is_watching(seat), watched.display_name() if watched != null else "-", camera.name if camera != null else "-",
		camera.global_position.snapped(Vector3.ONE * 0.1) if camera != null else Vector3.ZERO,
		camera.global_position.distance_to(watched.global_position) if camera != null and watched != null else -1.0,
		me.global_position.snapped(Vector3.ONE * 0.1), UndergroundHub.is_in_hub(me.global_position),
		Hud.element("DropOff", seat).get("text") if Hud.element("DropOff", seat) != null else "?"])
	if watched != null:
		print("DevCapture spectate look: %s yaw=%.2f (sent %.2f) pitch=%.2f (sent %.2f)" % [watched.display_name(),
			watched.camera_pivot.rotation.y, watched.sync_camera_yaw, watched.spring_arm.rotation.x, watched.sync_camera_pitch])


## Every RAID REPORT that goes up (any computer): one line for the crew, one per card.
func _print_report(report: Dictionary) -> void:
	print("DevCapture report: district %d twist=\"%s\" ending=\"%s\" total=$%d turf=%s cards=%d seconds=%.1f reveal=%.1f invite=\"%s\" mess_shown=%s" % [
		int(report.district), str(report.get("twist", "")), report.ending, int(report.total), report.turf, report.rows.size(),
		float(report.seconds_left), float(report.reveal_end), report.invite, report.show_mess])
	for gang in report.gangs:
		print("DevCapture report gang: %s $%d" % [gang.name, int(gang.total)])
	for row in report.rows:
		print("DevCapture report row: %s id=%d team=%d went_up=%d %s cash=$%d (loot %d + quest %d) bots=%d bosses=%d downs=%d revives=%d damage=%d vacuumed=%d robbed=%d mess=%d left=%d award=%s \"%s\" / \"%s\"" % [
			row.name, int(row.id), int(row.team), int(row.went_up), row.ending, int(row.cash), int(row.loot), int(row.bonus), int(row.bots),
			int(row.bosses), int(row.downs), int(row.revives), int(row.damage), int(row.vacuumed), int(row.robbed), int(row.get("mess", 0)),
			int(row.left), row.award_id, row.award_title, row.award_line])
	var ids: Array = report.rows.map(func(row): return row.award_id)
	var unique := {}
	for id in ids:
		unique[id] = true
	print("DevCapture report awards: %d cards, %d different awards (%s)" % [ids.size(), unique.size(), "OK" if unique.size() == ids.size() else "DUPLICATE!"])
	# The ONE report screen on this computer (scripts/ui/raid_report_screen.gd).
	await get_tree().create_timer(0.5).timeout
	var screen := RaidReportScreen.instance
	var hud_frames: Array = []
	for seat in 4:
		hud_frames.append(Hud.of(seat) != null and Hud.of(seat).frame.visible)
	print("DevCapture report screen: up=%s size=%s scale=%.2f rows=%d shown_seats=%s hud_frames=%s menu_view=%s" % [
		RaidReportScreen.is_up(), screen.size, screen._panel.scale.x, screen._row_cells.size(),
		GameScreen.instance.shown_seats(), hud_frames, GameScreen.instance.menu_view.visible])
	# ...and once it has gone: split screen, HUDs and moving cats should all be back.
	while RaidReportScreen.is_up():
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	hud_frames.clear()
	for seat in 4:
		hud_frames.append(Hud.of(seat) != null and Hud.of(seat).frame.visible)
	print("DevCapture after report: up=%s shown_seats=%s hud_frames=%s cats=%s" % [RaidReportScreen.is_up(),
		GameScreen.instance.shown_seats(), hud_frames,
		Game.instance.local_cats().map(func(c): return "slot %d can_move=%s" % [c.slot, not c._input_blocked()])])


# --- MESS-MAKING tests (scripts/mess_manager.gd) ---


## --raid_report[=N]: (host) made-up numbers, then the report (scripts/raid_report.gd test_report).
func _force_report(cards: int, after: int) -> void:
	for i in after:
		await get_tree().physics_frame
	RaidReport.instance.test_report(cards)


## --report_ready=A,B,...: once the report is up (after --report_ready_delay frames), press these
## one by one with REAL input events, printing who is ready after each:
##   S         seat S presses their own READY button (E for seat 0 on the keyboard, A on a pad)
##   S:pad     seat S presses A on their controller (seat 0: the first controller)
##   S:stick   seat S pushes their stick down (must change nothing)
##   spare:D   A on controller D, which nobody has claimed (must change nothing)
##   S:pause   seat S presses Esc / START (player 1: the pause menu opens over the report; others: nothing)
func _report_ready(presses: PackedStringArray, delay: int) -> void:
	for i in 3000:
		if RaidReport.instance.showing:
			break
		await get_tree().physics_frame
	for i in delay:
		await get_tree().process_frame
	for press in presses:
		var parts := press.split(":")
		var events: Array[InputEvent] = []
		for pressed in [true, false]:
			var event: InputEvent
			if parts[0] == "spare":
				event = Controls._event_from_name("Pad A")
				event.device = int(parts[1])
				event.pressed = pressed
			else:
				var seat := int(parts[0])
				var how := parts[1] if parts.size() > 1 else ("key" if seat == 0 and Seats.pads[0] < 0 else "pad")
				var device: int = Seats.pads[seat] if Seats.pads[seat] >= 0 else int(_args.get("pad_device", "0"))
				if how == "pause" and seat == 0 and Seats.pads[0] < 0:
					event = InputEventKey.new()  # player 1's Esc
					event.keycode = KEY_ESCAPE
					event.physical_keycode = KEY_ESCAPE
					event.pressed = pressed
				elif how == "pause":
					event = Controls._event_from_name("Pad Start")
					event.device = device
					event.pressed = pressed
				elif how == "key":
					event = InputEventKey.new()
					event.keycode = KEY_E
					event.physical_keycode = KEY_E
					event.pressed = pressed
				elif how == "stick":
					event = Controls._event_from_name("Pad Left Stick Down")
					event.device = device
					if not pressed:
						event.axis_value = 0.0
				else:
					event = Controls._event_from_name("Pad A")
					event.device = device
					event.pressed = pressed
			events.append(event)
		for event in events:
			Input.parse_input_event(event)
			await get_tree().process_frame
		for i in 10:
			await get_tree().process_frame
		var counts := RaidReport.instance.ready_count()
		print("DevCapture report_ready %s: ready=%d/%d ready_ids=%s showing=%s report_up=%s paused=%s" % [press, counts[0], counts[1],
			RaidReport.instance.ready_ids, RaidReport.instance.showing, RaidReportScreen.is_up(), PauseMenu.is_open])


## Watches every OTHER player's cat for a number of frames and prints how smoothly it
## moved on screen, next to how the raw network updates arrived.
func _track_other_cats(scene: Node, frame_count: int) -> void:
	var cats: Array[CatPlayer] = []
	for node in scene.get_node("Players").get_children():
		if not node.is_multiplayer_authority():
			cats.append(node)
	var last_shown := {}
	var last_raw := {}
	var shown_steps := {}
	var raw_steps := {}
	for cat in cats:
		last_shown[cat] = cat.position
		last_raw[cat] = cat.sync_position
		shown_steps[cat] = []
		raw_steps[cat] = []
	for i in frame_count:
		await get_tree().process_frame
		for cat in cats:
			shown_steps[cat].append(cat.position.distance_to(last_shown[cat]))
			raw_steps[cat].append(cat.sync_position.distance_to(last_raw[cat]))
			last_shown[cat] = cat.position
			last_raw[cat] = cat.sync_position
	for cat in cats:
		print("DevCapture track cat %s: on screen %s | raw network %s" % [cat.name, _describe(shown_steps[cat]), _describe(raw_steps[cat])])


func _describe(steps: Array) -> String:
	var still := 0
	var biggest := 0.0
	var total := 0.0
	for step in steps:
		if step < 0.0005:
			still += 1
		biggest = maxf(biggest, step)
		total += step
	return "still %d/%d frames, avg %.3f m, jump %.3f m" % [still, steps.size(), total / maxf(steps.size(), 1), biggest]


## DISTRICT TWISTS (scripts/district_twist.gd): what this district's twist did to the city.
func _print_twist(scene: Node, args: Dictionary) -> void:
	var twist := DistrictTwist.instance
	if args.has("twist_rolls"):
		var counts := {}
		var saved := twist.kind
		var saved_forced := DistrictTwist.forced_kind
		DistrictTwist.forced_kind = -1
		var repeats := 0
		for city_seed in range(1, 1001):
			var rolled := twist.roll(city_seed, 2)
			if rolled != DistrictTwist.Kind.NONE and rolled == twist.kind:
				repeats += 1
			twist.kind = rolled
			counts[DistrictTwist.name_of(rolled) if rolled != 0 else "NONE"] = int(counts.get(DistrictTwist.name_of(rolled) if rolled != 0 else "NONE", 0)) + 1
		twist.kind = saved
		DistrictTwist.forced_kind = saved_forced
		print("DevCapture twist rolls (1000 districts): %s back-to-back repeats=%d district1=%s tutorial-safe" % [counts, repeats,
			DistrictTwist.name_of(twist.roll(42, 1)) if DistrictTwist.forced_kind < 0 else "(forced)"])
	var bots := 0
	var sight := 0.0
	for node in scene.get_node("Roombas").get_children():
		var bot := node as Roomba
		if bot != null and not bot.is_boss:
			bots += 1
			sight = bot.sight_range * DistrictTwist.sight_multiplier()
	for i in 30:
		await get_tree().physics_frame
	var city := scene.get_node("City") as CityGenerator
	var lamps_lit := 0
	var lamps := 0
	for child in city.get_children():
		var cone := child.get_node_or_null("LightCone") as Light3D
		if cone != null:
			lamps += 1
			lamps_lit += 1 if cone.visible else 0
	var door := city.meow_mart_position
	var mart_fish := 0
	var mart_koi := 0
	for id in ItemManager.instance.world:
		var entry: Dictionary = ItemManager.instance.world[id]
		if (entry.pos as Vector3).distance_to(door) < 7.0:
			mart_fish += 1 if entry.item == "fish" else 0
			mart_koi += 1 if entry.item == "golden_koi" else 0
	var kinds := {}
	for p in city.mess_props:
		var key: String = MessProp.Kind.keys()[p.kind]
		kinds[key] = int(kinds.get(key, 0)) + 1
	var intel: Array = [DistrictTwist.intel_line()]
	print("DevCapture twist: %s district=%d city=#%d lamps lit %d/%d ambient=%.2f moon=%.2f bot sight=%.1f m (x%.2f) mess props=%d %s" % [
		DistrictTwist.name_of(twist.kind) if twist.kind != 0 else "NONE", twist.district_number, city.city_seed, lamps_lit, lamps,
		(scene.get_node("WorldEnvironment") as WorldEnvironment).environment.ambient_light_energy,
		(scene.get_node("Moonlight") as Light3D).light_energy, sight, DistrictTwist.sight_multiplier(), city.mess_props.size(), kinds])
	print("DevCapture twist: meow-mart fish=%d koi=%d | regular bots=%d (x%.2f) | heat x%.2f | CRT intel %s | boss news \"%s\" | send-off \"%s\"" % [
		mart_fish, mart_koi, bots, DistrictTwist.bot_multiplier(), DistrictTwist.heat_multiplier(), intel, twist.news_line(),
		DistrictTwist.send_off_line("(usual)")])
	if args.has("twist_heat") and multiplayer.is_server():
		var frames := int(args["twist_heat"])
		var before := HeatMeter.instance.heat
		for i in frames:
			await get_tree().physics_frame
		var rise := HeatMeter.instance.heat - before
		print("DevCapture twist heat: +%.2f in %d frames = %.3f/s (base %.3f/s, twist x%.2f, up top %d)" % [rise, frames,
			rise / (frames / float(Engine.physics_ticks_per_second)), HeatMeter.instance.heat_per_second,
			DistrictTwist.heat_multiplier(), Game.instance.players_up_top()])


## End-of-run state summary printed right before saving the screenshot.
func _print_snapshot_summary(scene: Node, mess_module: Node, args: Dictionary) -> void:
	if args.has("track"):
		await _track_other_cats(scene, int(args["track"]))
	if args.has("net_stats") and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		var connection := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
		connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
		connection.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
		var started := Time.get_ticks_msec()
		var peer := multiplayer.multiplayer_peer
		for i in int(args["net_stats"]):
			await get_tree().process_frame
			if multiplayer.multiplayer_peer != peer:
				break
		var seconds := (Time.get_ticks_msec() - started) / 1000.0
		if multiplayer.multiplayer_peer != peer or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			print("DevCapture net: the game ended after %.1f s (host left?), no measurement" % seconds)
		else:
			var sent := connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
			var received := connection.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
			print("DevCapture net: sent %.1f KB/s, received %.1f KB/s over %.1f s | players=%d roombas=%d computers=%d" % [
				sent / 1024.0 / seconds, received / 1024.0 / seconds, seconds, Game.instance.player_count(),
				Game.instance.get_node("Roombas").get_child_count(), multiplayer.get_peers().size() + 1])
		scene = Game.instance
	print("DevCapture fps=%d process=%.1fms physics=%.1fms objects=%d" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	var showing: Array = []
	for seat in PlayerId.MAX_LOCAL:
		var message := Hud.element("Message", seat)
		if message != null:
			showing.append("P%d message=%s popup=%s" % [seat + 1, message.visible, Hud.element("Popup", seat).visible])
	print("DevCapture hud: %s" % [showing])
	if scene.main_menu.visible and scene.main_menu.status_label.text != "":
		print("DevCapture menu status: %s" % scene.main_menu.status_label.text)
	if scene.main_menu.visible and scene.main_menu.play_screen.visible:
		print("DevCapture found games: %s" % [Net.found_games])
	var city := scene.get_node_or_null("City") as CityGenerator
	if city != null:
		var layout := ""
		for child in city.get_children():
			if not child.is_queued_for_deletion():
				layout += str((child as Node3D).position.snapped(Vector3.ONE * 0.01))
		print("DevCapture city: seed=%d objects=%d fingerprint=%d meow_mart=%s" % [city.city_seed, layout.count("("), layout.hash(), city.meow_mart_position.snapped(Vector3.ONE * 0.1)])
		var styles := {}
		for style in city.building_style_counts:
			styles[CityBuildings.Style.keys()[style]] = city.building_style_counts[style]
		print("DevCapture buildings: %s" % styles)
		var props := {}
		for node in city.find_children("*", "Node3D", true, false):
			var file := node.scene_file_path.get_file().get_basename()
			if file in ["trash_bin", "traffic_cone"]:
				if not props.has(file):
					props[file] = []
				props[file].append((node as Node3D).global_position.snapped(Vector3.ONE * 0.1))
		for file in props:
			print("DevCapture props: %d x %s, e.g. %s" % [props[file].size(), file, props[file].slice(0, 4)])
		mess_module._print_mess("snap")
	var heist := scene.get_node_or_null("Heist") as FishHeist
	if heist != null:
		var manholes := heist.get_children().filter(func(n): return n is Manhole and not n.is_queued_for_deletion()).size()
		var cats_teams := []
		for cat_node in scene.players.get_children():
			cats_teams.append("%s:%d" % [cat_node.name, (cat_node as CatPlayer).team])
		var live_cars: Array = scene.cars().filter(func(c): return not c.is_queued_for_deletion())
		print("DevCapture mode: %s cats=%s entries=%d exits=%d manholes=%d cars=%s" % [
			"TURF WAR" if Game.is_turf_war() else "CO-OP", cats_teams,
			1 if heist.entry_position(0) == heist.entry_position(1) else 2, heist.exit_positions.size(), manholes,
			live_cars.map(func(c): return "%s(team %d)" % [c.name, c.team])])
		print("DevCapture heist: entries=%s exits=%s open=%s revealed=%s sealed=%s cash=%s" % [[heist.entry_position(0), heist.entry_position(1)], heist.exit_positions, [heist.exit_is_open(0), heist.exit_is_open(1)], heist.revealed, heist.sealed, Wallet.instance.cash])
	if HeatMeter.instance != null:
		var regulars := 0
		var bosses := 0
		for roomba in scene.get_node("Roombas").get_children():
			if roomba is Roomba and not roomba.is_queued_for_deletion():
				if (roomba as Roomba).is_boss:
					bosses += 1
				else:
					regulars += 1
		print("DevCapture heat: %.1f level=%d roombas=%d bosses=%d" % [HeatMeter.instance.heat, HeatMeter.instance.level(), regulars, bosses])
	var items := scene.get_node_or_null("Items") as ItemManager
	if items != null:
		var lying := {}
		for id in items.world:
			lying[items.world[id].item] = lying.get(items.world[id].item, 0) + 1
		print("DevCapture items: on street=%s inventories=%s" % [lying, items.inventories])
		for cat in scene.get_node("Players").get_children():
			for hand in 2:
				var weapon := items.held_item(cat, hand) as Weapon
				if weapon != null:
					print("DevCapture weapon: cat %s hand %d shots_seen=%d heat=%.2f overheated=%s" % [cat.name, hand, weapon.shots_seen, weapon.heat, weapon.is_overheated])
	var roombas := scene.get_node_or_null("Roombas")
	if roombas != null:
		var lines := PackedStringArray()
		for roomba in roombas.get_children():
			if roomba is Roomba and not roomba.is_queued_for_deletion():
				lines.append("%s %s %s %s hp=%d stomach=%s" % [roomba.name, roomba.display_name, Roomba.State.keys()[roomba.state], roomba.global_position.snapped(Vector3.ONE * 0.1), roomba.health, roomba.stomach])
		print("DevCapture roombas (%d): %s" % [lines.size(), " | ".join(lines)])
		for cat in scene.get_node("Players").get_children():
			print("DevCapture sticky: cat %s paws=%.1f s, patches=%d, speed=%.1f, hp=%d" % [cat.name, cat._sticky_left,
				StickyPatch.count(), Motion.flat(cat.velocity).length(), CatHealth.instance.get_health(cat.player_id)])
	for seat in 4:
		var compass := Hud.element("Compass", seat) as HudCompassArrow
		if compass != null:
			print("DevCapture compass seat %d: shown=%s text='%s' yaw=%.0f deg urgent=%s top=%.0f" % [seat, compass.visible,
				compass._text, rad_to_deg(compass._target_yaw), compass._urgent, compass.offset_top])
	for car in (scene as Game).cars():
		print("DevCapture car %s (gang %d): position=%s driver=%d passengers=%s frozen=%s" % [car.name, car.team,
			car.global_position.snapped(Vector3.ONE * 0.1), car.driver_id, car.passenger_ids, car.freeze])
		print("DevCapture car_look %s: trim=%s wheels=%d spin=%.2f steer=%.1f deg (input %.2f) speed=%.1f" % [car.name,
			car.trim_color().to_html(false), car._wheels.size(), car._wheel_spin, rad_to_deg(car._wheel_steer), car.steer, car._rolling_speed])
	var players := scene.get_node_or_null("Players")
	if players != null:
		for cat in players.get_children():
			print("DevCapture cat %s: name=\"%s\" tag=\"%s\" visible=%s position=%s in_hub=%s speed_boost=%.1f hp=%d knocked_out=%s team=%d" % [cat.name, cat.player_name, cat.get_node("NameTag").text, cat.visible, cat.position.snapped(Vector3.ONE * 0.1), UndergroundHub.is_in_hub(cat.global_position), cat.speed_boost, CatHealth.instance.get_health(cat.player_id), cat.knocked_out, cat.team])
			print("DevCapture aim %s: aiming=%s amount=%.2f bloom=%.2f fov=%.1f arm_len=%.2f arm_x=%.2f pitch=%.1f" % [cat.name,
				cat.aim.is_aiming(), cat.aim.amount(), cat.aim.bloom_degrees, cat.camera.fov, cat.spring_arm.spring_length,
				cat.spring_arm.position.x, rad_to_deg(cat.spring_arm.rotation.x)])
			var model: Node3D = cat.cat_model
			var worn := PackedStringArray()
			for slot in CatLook.SLOTS:
				var part := model.get_node_or_null("Look_" + slot.capitalize())
				worn.append("%s=%s" % [slot, part.get_meta("part_id") if part != null else "-"])
			var fur: Color = ((model.get_node("Body") as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("albedo_color")
			print("DevCapture look %s: fur=#%s %s voice=%s" % [cat.name, fur.to_html(false), " ".join(worn), CatLook.voice_of(cat.look)])
