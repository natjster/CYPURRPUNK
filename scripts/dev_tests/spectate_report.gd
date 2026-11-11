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
		RaidReportScreen.is_up(), screen.size, screen._content.scale.x, screen._row_cells.size(),
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
