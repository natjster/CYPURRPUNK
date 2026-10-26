extends Node
## DEV TOOL — takes a screenshot of the running game, saves it, then quits.
## Does nothing during normal play (it only wakes up when given --capture).
##
## Run from a terminal in the project folder, e.g.:
##   C:\GoDot\Godot_v4.7.2-stable_win64_console.exe --path . -- --host --capture=shots/street.png --pos=0,0,6 --yaw=0 --pitch=-12
## Options (everything after the lone "--"):
##   --capture=PATH    where to save the PNG (relative to the project folder)
##   --solo / --host / --join   start a game (otherwise you get the start menu)
##   --wait=N          wait N frames after our cat appears before doing anything else
##   --add_local=N     split screen: N more players join in on this computer (slots 1..N,
##                     named COUCH 2, COUCH 3... with random looks; their cats stand still)
##   --as_local=S      (with --add_local) every action below (--pos, --give, --grab, --drive,
##                     --goto_dropoff_after, --bait_roomba, --talk...) uses the cat in slot S instead
##   --remove_local=S  (at the very end, before the snap) the player in slot S drops out
##   --join_pad=N      couch co-op: press START on fake controller N (1, 2, 3) right after our cat
##                     appears = a new player drops in on it (scripts/seats.gd). Repeat: --join_pad=1,2
##   --pad_device=N    which fake controller --pad and --pad_press use (default 0)
##   --pos=X,Y,Z       move the cat here first
##   --yaw=DEG         turn the camera left/right
##   --pitch=DEG       tilt the camera up/down
##   --drive           put the cat in the car (car view)
##   --car_mouse=PX    (with --drive) move the mouse PX screen pixels to the right while driving
##                     (the car camera turns); prints the camera's look angle
##   --car_watch=N     print the car camera's look angle every N frames until the snap
##   --talk[=NAME]     walk up to an NPC (node name, e.g. LilMittens; default Don Catleone)
##                     and press E (talk box open)
##   --choose=N,M      (with --talk) click talk-box button N, then M... (0 = top button)
##   --click_choice=N  (with --talk) a REAL mouse click on button N (tests clicks reach the HUD)
##   --talk_again_after=N  N frames after --goto_dropoff_after, talk to that NPC again
##   --bait_roomba=D   (host) put the nearest Roomba D metres in front of our cat
##   --zap_roomba=N    (host) hit the nearest Roomba N times, as if shot
##   --roomba=boss     (with --bait_roomba / --zap_roomba) use the MEGA VAC-COP instead of the nearest
##   --deploy          ask Don to send us up top (cat moves from the hub to the city)
##   --give=A,B        (host) put items straight into our paws/backpack (e.g. --give=pistol,catnip)
##   --to_stash=hand:0,pack:0   walk to the stash lockers and put those items in the stash
##   --from_stash=N    (at the lockers) take stash slot N into the backpack
##   --fresh_profile   start this test's saved cash + stash from scratch (user://test_profiles/)
##   --cash=N          (host) set our cash, and every joining player's, to $N (to test the Black Markitten shop:
##                     --cash=500 --talk=ComradeWhiskers --choose=0,3 buys the 4th item)
##   --grab=ITEM       walk to the nearest ITEM lying around (fish, or something dropped) and press E.
##                     Repeat with a comma list: --grab=catnip,catnip (fire/use with --hold=shoot)
##   --drop_after=N    drop what's in the paws (G) N frames after the --hold finishes
##   --equip=N         take backpack slot N into the paws (what clicking it in the inventory does)
##   --inventory       open the inventory screen (Tab) before the snap
##   --press_key=KEY   press and release a real key, e.g. --press_key=Tab (inventory) or Escape
##   --hold=ACTION     hold a control for --hold_frames (default 60), e.g. move_forward,
##                     starting after --hold_delay frames (default 30)
##   --exit_after=N    get out of the car N frames after the --hold finishes
##   --goto_dropoff_after=N   jump into the extraction beam after N more frames (in the car if driving)
##   --mouse_test      check mouse-look gets the mouse through the game screen (prints how far it turned)
##   --track=N       measure how smoothly other players' cats move over N frames
##   --net_interval=S  simulate a laggy connection: send our cat's position only every S seconds
##   --frames=N        frames to wait before the snap (default 90 = 1.5 s)
##   --scale=N         size of the saved image: each game pixel = N pixels (default 4 = 960 tall)
##   --window=WxH      window size for this run, e.g. --window=1720x720 to test an ultrawide shape
##   --menu=NAME       open a menu first: cat (CHOOSE YOUR CAT; MY CAT in a game), mode (SOLO / MULTIPLAYER), play (host / join), settings or pause (--settings_tab=N picks the tab)
##   --look=N          wear a random cat look made from seed N (as if picked in MY CAT; never saved)
##   --heat=N          (host) set the HEAT to N (0-100; 100 = MEGA VAC-COP) at the start and
##                     keep it there for --heat_hold frames (default: until the snap)
##   --rebind=A,S,KEY  (with --menu=settings) set key slot S (0/1) of control A to KEY, as if
##                     the player clicked the box and pressed it, e.g. --rebind=drop,0,Space
##                     (slot 2 = the PAD box: --rebind=jump,2,Pad_B  - use _ for spaces)
##   --pad=NAME,NAME   push controller sticks / triggers / buttons (fake but REAL controller events)
##                     for --hold_frames after --hold_delay, e.g. --pad=Right_Stick_Right or
##                     --pad=Left_Stick_Up,RT (names from Controls.PAD_BUTTONS / PAD_AXES, _ = space)
##   --pad_press=A,B   press + release controller buttons one by one (after --menu), printing
##                     which menu is open and which button is highlighted after each,
##                     e.g. --pad_press=Start,D-Pad_Down,A


## The command line options (so helper functions can read them too).
var _args: Dictionary = {}


func _ready() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	_args = args
	# Never runs in a release build (the exported .exe players get), only in Godot / debug builds.
	if not args.has("capture") or not OS.is_debug_build():
		queue_free()
		return

	# --window=WxH   open the game window at that size (e.g. 1720x720 = ultrawide shape; never saved)
	if args.has("window"):
		var parts: PackedStringArray = args["window"].split("x")
		Settings.set_value("resolution", Vector2i(int(parts[0]), int(parts[1])))

	# Let the main scene finish loading.
	await get_tree().process_frame
	var scene: Node = Game.instance  # the game (main.tscn), inside scenes/game_screen.tscn

	# Wait (up to ~10 s) for OUR cat to exist — a joining game needs time to connect.
	# Without --host / --join no cat ever appears, and we just photograph the lobby.
	var player: CatPlayer = null
	if args.has("host") or args.has("join") or args.has("solo"):
		var give_up_at := Time.get_ticks_msec() + 10000  # seconds, not frames: fps varies a lot
		while Time.get_ticks_msec() < give_up_at:
			player = scene.get_node_or_null("Players/%d" % multiplayer.get_unique_id()) as CatPlayer
			if player != null:
				break
			await get_tree().process_frame
		if player != null and args.has("add_local"):
			# Split screen test: more players on this computer (scripts/player_id.gd, game.gd).
			var look_rng := RandomNumberGenerator.new()
			look_rng.seed = 7
			for slot in range(1, int(args["add_local"]) + 1):
				scene.add_local_player(slot, {"name": "COUCH %d" % (slot + 1), "look": CatLook.random_look(look_rng), "cat_id": ""})
			for i in 120:  # wait for the host to make their cats
				if scene.local_cats().size() > int(args["add_local"]):
					break
				await get_tree().process_frame
			print("DevCapture add_local: our cats = %s" % [scene.local_cats().map(func(c): return "%s (slot %d)" % [c.name, c.slot])])
			if args.has("as_local"):
				player = scene.cat_for(PlayerId.make(multiplayer.get_unique_id(), int(args["as_local"])))
		if player != null and args.has("join_pad"):
			# Couch co-op: START on another controller = a new player drops in (scripts/seats.gd).
			for i in 20:
				await get_tree().process_frame
			for device in args["join_pad"].split(","):
				for pressed in [true, false]:
					var start := _pad_event("Start", pressed)
					start.device = int(device)
					Input.parse_input_event(start)
					for i in 3:
						await get_tree().process_frame
			for i in 60:  # wait for the host to make their cats
				if scene.local_cats().size() > args["join_pad"].split(",").size():
					break
				await get_tree().process_frame
			print("DevCapture join_pad: seats pads=%s taken=%s paused=%s cats=%s" % [Seats.pads, Seats.taken, PauseMenu.is_open,
				scene.local_cats().map(func(c): return "%s slot %d \"%s\" reads_input=%s" % [c.name, c.slot, c.player_name, c.reads_input()])])
			if args.has("as_local"):
				player = scene.cat_for(PlayerId.make(multiplayer.get_unique_id(), int(args["as_local"])))

	# Diagnostics: switch PS1 effects off on the city's materials for this run only.
	#   --no_affine        perspective-correct textures
	#   --no_snap          no vertex wobble (snaps to a very fine grid)
	var city_node := scene.get_node_or_null("City") as CityGenerator
	if city_node != null:
		for material in [city_node.building_material, city_node.street_material, city_node.sidewalk_material]:
			var shader_material := material as ShaderMaterial
			if args.has("no_affine"):
				shader_material.set_shader_parameter("affine_mapping", false)
			if args.has("no_snap"):
				shader_material.set_shader_parameter("snap_resolution", Vector2(100000, 100000))

	if player != null:
		for i in int(args.get("wait", 0)):
			await get_tree().process_frame
		if args.has("net_interval"):
			# Simulate a bad connection: only send our cat's position every N seconds.
			(player.get_node("MultiplayerSynchronizer") as MultiplayerSynchronizer).replication_interval = float(args["net_interval"])
		if args.has("cash") and multiplayer.is_server():
			FishHeist.instance._set_cash.rpc(player.player_id, int(args["cash"]))
			multiplayer.peer_connected.connect(func(peer_id: int) -> void:
				await get_tree().create_timer(0.2).timeout  # after the joiner has the cash list
				FishHeist.instance._set_cash.rpc(peer_id, int(args["cash"])))
		if args.has("heat") and multiplayer.is_server():
			# (host) force the heat, e.g. --heat=100 brings out the MEGA VAC-COP.
			var hold := int(args.get("heat_hold", args.get("frames", 90)))
			var heat_meter := HeatMeter.instance
			var force_heat := func() -> void:
				for i in hold:
					heat_meter.heat = float(args["heat"])
					await get_tree().physics_frame
			force_heat.call()
		if args.has("give") and multiplayer.is_server():
			# (host) put items straight into our paws/backpack, e.g. --give=pistol,catnip
			for item_id in args["give"].split(","):
				ItemManager.instance._put_in_inventory(player.player_id, item_id, player.global_position)
		if args.has("to_stash") or args.has("from_stash"):
			# Walk to THE STASH lockers, then click slots the way the inventory screen does:
			#   --to_stash=hand:0,pack:0   (each moves that item into the stash; indexes shift as you go)
			#   --from_stash=0             (stash slot 0 into the backpack)
			var hub := (scene as Game).hub
			player.teleport_to(hub.to_global(hub.stash_spot), 0.0)
			for i in 20:
				await get_tree().process_frame  # let the host see our new position first
			if args.has("to_stash"):
				for slot in args["to_stash"].split(","):
					var parts: PackedStringArray = slot.split(":")
					ItemManager.instance.request_to_stash.rpc_id(1, player.player_id, parts[0], int(parts[1]))
					for i in 10:
						await get_tree().process_frame
			if args.has("from_stash"):
				ItemManager.instance.request_from_stash.rpc_id(1, player.player_id, int(args["from_stash"]))
				for i in 10:
					await get_tree().process_frame
		if args.has("deploy"):
			# Before --pos, so --pos can still pick an exact spot in the city.
			(scene as Game).hub.deploy(player)
			for i in 20:
				await get_tree().process_frame  # let the host see our new position first
		if args.has("pos"):
			var p: PackedFloat64Array = args["pos"].split_floats(",")
			player.global_position = Vector3(p[0], p[1], p[2])
		if args.has("yaw"):
			player.camera_pivot.rotation.y = deg_to_rad(float(args["yaw"]))
		if args.has("pitch"):
			player.spring_arm.rotation.x = deg_to_rad(float(args["pitch"]))
		if args.has("mouse_test"):
			# Move the mouse 100 real screen pixels to the right (as if the player did) and print
			# how far that is in game pixels (should be 100 x 240 / window height).
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			var yaw_before := player.camera_pivot.rotation.y
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(100, 0)  # real screen pixels, like a real mouse
			motion.position = Vector2(get_window().size) / 2.0
			Input.parse_input_event(motion)
			for i in 3:
				await get_tree().process_frame
			var moved := (yaw_before - player.camera_pivot.rotation.y) / (player.mouse_sensitivity * Settings.mouse_speed)
			print("DevCapture mouse: 100 screen px = %.2f game px (expected %.2f)" % [moved, 100.0 * 240.0 / get_window().size.y])
		if args.has("talk"):
			await _talk(player, args)
		if args.has("drive"):
			for i in 20:
				await get_tree().process_frame  # let the host see our new position first
			(scene.get_node("GetawayCar") as GetawayCar).request_enter.rpc_id(1, player.player_id)
			if args.has("car_mouse"):
				for i in 20:
					await get_tree().process_frame  # wait until we're behind the wheel
				var car := scene.get_node("GetawayCar") as GetawayCar
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				var motion := InputEventMouseMotion.new()
				motion.relative = Vector2(float(args["car_mouse"]), 0)
				motion.position = Vector2(get_window().size) / 2.0
				Input.parse_input_event(motion)
				for i in 3:
					await get_tree().process_frame
				print("DevCapture car_mouse: driver=%d look_yaw=%.2f look_pitch=%.2f" % [car.driver_id, car.look_yaw, car.look_pitch])
		if args.has("car_watch"):
			_watch_car_camera(scene.get_node("GetawayCar") as GetawayCar, int(args["car_watch"]))
		if args.has("grab"):
			# For each item named: stand next to the nearest one and press E (send what E sends).
			var items := ItemManager.instance
			for item_id in args["grab"].split(","):
				var best := -1
				for id in items.world:
					if items.world[id].item == item_id and (best < 0 or player.global_position.distance_to(items.world[id].pos) < player.global_position.distance_to(items.world[best].pos)):
						best = id
				if best < 0:
					print("DevCapture: no '%s' lying anywhere" % item_id)
					continue
				player.global_position = items.world[best].pos + Vector3(0.5, 0, 0.5)
				for i in 20:
					await get_tree().process_frame  # let the host see our new position first
				items.try_interact(player)
				for i in 10:
					await get_tree().process_frame
		if args.has("equip"):
			# Click backpack slot N in the inventory screen (take it into the paws).
			ItemManager.instance.request_equip.rpc_id(1, player.player_id, int(args["equip"]))
			for i in 10:
				await get_tree().process_frame
		if args.has("put_away"):
			# Click paw N in the inventory screen (0 = right, 1 = left): put it in the backpack.
			ItemManager.instance.request_put_away.rpc_id(1, player.player_id, int(args["put_away"]))
			for i in 10:
				await get_tree().process_frame
		if args.has("drop_slot"):
			# Right-click a slot in the inventory screen, e.g. --drop_slot=pack:0 or bag:0 or hand:1
			var parts: PackedStringArray = args["drop_slot"].split(":")
			ItemManager.instance.request_drop_item.rpc_id(1, player.player_id, parts[0], int(parts[1]), ItemManager.instance.ground_in_front_of(player))
			for i in 10:
				await get_tree().process_frame
		if args.has("bait_roomba"):
			# --bait_roomba=4: 4 m in front of the cat.  --bait_roomba=aim: right under the crosshair
			# (where the camera's centre line meets the ground), stunned so it stays put a moment.
			for i in 20:
				await get_tree().process_frame  # let the camera settle (over-the-shoulder slide)
			var roomba: Roomba = await _pick_roomba(scene, player.global_position, args)
			if not multiplayer.is_server():
				# A client can't move the host's Roombas, so walk our cat up to one instead.
				player.teleport_to(roomba.global_position + Vector3(float(args["bait_roomba"]), 0, 0), 0.0)
			elif args["bait_roomba"] == "aim":
				var camera := player.camera
				var aim := -camera.global_basis.z
				var t := (camera.global_position.y - 0.15) / maxf(-aim.y, 0.01)
				roomba.global_position = camera.global_position + aim * t - Vector3(0, 0.05, 0)
				roomba.state = Roomba.State.STUNNED
				roomba._stun_left = 3.0
			else:
				var ahead := -player.camera_pivot.global_basis.z
				roomba.global_position = player.global_position + Vector3(ahead.x, 0, ahead.z).normalized() * float(args["bait_roomba"]) + Vector3(0, 0.1, 0)
			print("DevCapture bait: %s placed at %s" % [roomba.name, roomba.global_position.snapped(Vector3.ONE * 0.1)])
		if args.has("zap_roomba"):
			var roomba: Roomba = await _pick_roomba(scene, player.global_position, args)
			for i in int(args["zap_roomba"]):
				roomba.take_hit()
		if args.has("hold"):
			# Pretend a key is held down, e.g. --hold=move_forward --hold_frames=60
			for i in int(args.get("hold_delay", "30")):
				await get_tree().process_frame
			# Several at once with a comma list, e.g. --hold=shoot,use_left (fire both pistols).
			for action in args["hold"].split(","):
				Input.action_press(Seats.action(player.slot, action))  # the test player's own controls
			for i in int(args.get("hold_frames", "60")):
				await get_tree().process_frame
			if not args.has("keep_holding"):  # --keep_holding = still held when the snap is taken
				for action in args["hold"].split(","):
					Input.action_release(Seats.action(player.slot, action))
		if args.has("pad"):
			# Push the controller like a player would, e.g. --pad=Right_Stick_Right --hold_frames=30
			for i in int(args.get("hold_delay", "30")):
				await get_tree().process_frame
			var yaw_before := player.camera_pivot.rotation.y
			var pos_before := player.global_position
			var all_before := {}
			for cat in scene.local_cats():
				all_before[cat] = cat.global_position
			var pads: PackedStringArray = args["pad"].replace("_", " ").split(",")
			for pad in pads:
				Input.parse_input_event(_pad_event(pad, true))
			for i in int(args.get("hold_frames", "60")):
				await get_tree().process_frame
			var car := scene.get_node("GetawayCar") as GetawayCar
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
			# Wait, then drop what's in the paws (what G does).
			for i in int(args["drop_after"]):
				await get_tree().process_frame
			ItemManager.instance.drop_from(player)
		if args.has("jump_test"):
			# Jump, press jump again in mid-air, and report the highest point reached.
			var ground_y := player.global_position.y
			var peak := ground_y
			for i in 100:
				if i == 0 or i == 18:
					Input.action_press(Seats.action(player.slot, "jump"))
				elif i == 2 or i == 20:
					Input.action_release(Seats.action(player.slot, "jump"))
				await get_tree().physics_frame
				peak = maxf(peak, player.global_position.y)
			print("DevCapture jump: peak height %.2f m (air jumps active: %d)" % [peak - ground_y, player.air_jumps])
		if args.has("exit_after"):
			for i in int(args["exit_after"]):
				await get_tree().process_frame
			(scene.get_node("GetawayCar") as GetawayCar).request_exit.rpc_id(1)
		if args.has("goto_dropoff_after"):
			# Wait, then jump our cat into the fish drop-off.
			for i in int(args["goto_dropoff_after"]):
				await get_tree().process_frame
			var heist_node := scene.get_node("Heist") as FishHeist
			var beam := heist_node.beam_positions[heist_node.nearest_open_beam(player.global_position)] + Vector3(1, 0, 1)
			var car := scene.get_node("GetawayCar") as GetawayCar
			if car.driver_id == player.player_id:
				car.global_position = beam + Vector3(0, 0.5, 0)  # driving: take the car there
			else:
				player.global_position = beam
		if args.has("talk_again_after"):
			# After extracting: walk back up to the same NPC and press E again.
			for i in int(args["talk_again_after"]):
				await get_tree().process_frame
			args.erase("choose")
			await _talk(player, args)

	if args.has("look"):
		# --look=N: a random cat look from seed N, as if picked in the MY CAT screen
		# (our cat wears it and shares it; test runs never save it).
		var rng := RandomNumberGenerator.new()
		rng.seed = int(args["look"])
		Settings.update_current_cat({"look": CatLook.random_look(rng)})
		for i in 10:
			await get_tree().process_frame
	if args.has("inventory"):
		InventoryScreen.instance._set_open(true)  # same as pressing Tab
	if args.has("press_key"):
		# --press_key=Tab: a REAL key press + release (goes through the game screen like a player's).
		for pressed in [true, false]:
			var key := InputEventKey.new()
			key.physical_keycode = OS.find_keycode_from_string(args["press_key"])
			key.keycode = key.physical_keycode
			key.pressed = pressed
			Input.parse_input_event(key)
			await get_tree().process_frame
		print("DevCapture press_key %s: inventory open=%s talk box open=%s paused=%s" % [args["press_key"], InventoryScreen.instance.visible, NpcDialog.is_open, PauseMenu.is_open])
	# --menu=play / settings / pause   open that menu before the snap
	# --settings_tab=N                  which settings tab to show (0 = DISPLAY)
	if args.has("menu") and scene is Game:
		match args["menu"]:
			"play": scene.main_menu.show_play_screen()
			"mode": scene.main_menu.show_mode_screen()
			"settings": scene.settings_menu.open()
			"pause": scene.pause_menu.open()
			"cat": scene.cat_creator.open(scene.pause_menu.enabled)
		if args.has("settings_tab"):
			scene.settings_menu._show_tab(int(args["settings_tab"]))
		# --rebind=ACTION,SLOT,KEY   click a box on the KEYS tab and press KEY (e.g. jump,1,J)
		if args.has("rebind"):
			var parts: PackedStringArray = args["rebind"].split(",")
			scene.settings_menu._start_listening(parts[0], int(parts[1]))
			await get_tree().process_frame
			if parts[2].begins_with("Pad_"):
				Input.parse_input_event(_pad_event(parts[2].trim_prefix("Pad_").replace("_", " "), true))
			else:
				var press := InputEventKey.new()
				press.physical_keycode = OS.find_keycode_from_string(parts[2])
				press.keycode = press.physical_keycode
				press.pressed = true
				Input.parse_input_event(press)
			await get_tree().process_frame
			print("DevCapture rebind %s -> %s | hint: %s" % [parts[0], Controls.bindings[parts[0]], scene.settings_menu.hint_label.text])
			for entry in Controls.ACTIONS:
				print("DevCapture key %s = %s" % [entry.action, Controls.bindings[entry.action]])

	if args.has("pad_press"):
		# --pad_press=Start,D-Pad_Down,A : real controller presses, one every few frames.
		# "1:Start" = START on fake controller 1 (otherwise --pad_device, default 0).
		for pad in args["pad_press"].replace("_", " ").split(","):
			for pressed in [true, false]:
				var event := _pad_event(pad.get_slice(":", 1) if ":" in pad else pad, pressed)
				if ":" in pad:
					event.device = int(pad.get_slice(":", 0))
				Input.parse_input_event(event)
				for i in 4:
					await get_tree().process_frame
			await get_tree().process_frame  # (a join happens a moment later)
			var game_focus := GameScreen.instance.game_viewport.gui_get_focus_owner()
			var hud_focus := get_viewport().gui_get_focus_owner()
			print("DevCapture pad_press %s: paused=%s settings=%s inventory=%s talk=%s using_pad=%s focus=%s hud_focus=%s" % [
				pad, PauseMenu.is_open, Game.instance.settings_menu.visible, InventoryScreen.instance.visible,
				NpcDialog.is_open, Controls.using_pad, _describe_focus(game_focus), _describe_focus(hud_focus)])

	if args.has("remove_local") and Game.instance != null:
		Game.instance.remove_local_player(int(args["remove_local"]))
		print("DevCapture remove_local: slot %s dropped out" % args["remove_local"])

	for i in int(args.get("frames", "90")):
		await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# The scene may have been reloaded meanwhile (e.g. the host quit), so look it up again.
	scene = Game.instance
	if args.has("track"):
		await _track_other_cats(scene, int(args["track"]))

	print("DevCapture fps=%d" % Engine.get_frames_per_second())
	var city := scene.get_node_or_null("City") as CityGenerator
	if city != null:
		# Fingerprint of where every city object is: identical cities print identical numbers.
		var layout := ""
		for child in city.get_children():
			if not child.is_queued_for_deletion():
				layout += str((child as Node3D).position.snapped(Vector3.ONE * 0.01))
		print("DevCapture city: seed=%d objects=%d fingerprint=%d meow_mart=%s" % [city.city_seed, layout.count("("), layout.hash(), city.meow_mart_position.snapped(Vector3.ONE * 0.1)])
	var heist := scene.get_node_or_null("Heist") as FishHeist
	if heist != null:
		print("DevCapture heist: beams=%s open=%s cash=%s" % [heist.beam_positions, heist.beam_time_left, heist.cash])
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
				lines.append("%s %s %s hp=%d stomach=%s" % [roomba.name, Roomba.State.keys()[roomba.state], roomba.global_position.snapped(Vector3.ONE * 0.1), roomba.health, roomba.stomach])
		print("DevCapture roombas (%d): %s" % [lines.size(), " | ".join(lines)])
	var car := scene.get_node_or_null("GetawayCar") as GetawayCar
	if car != null:
		print("DevCapture car: position=%s driver=%d frozen=%s" % [car.global_position.snapped(Vector3.ONE * 0.1), car.driver_id, car.freeze])
	var players := scene.get_node_or_null("Players")
	if players != null:
		for cat in players.get_children():
			print("DevCapture cat %s: name=\"%s\" tag=\"%s\" visible=%s position=%s in_hub=%s speed_boost=%.1f hp=%d knocked_out=%s" % [cat.name, cat.player_name, cat.get_node("NameTag").text, cat.visible, cat.position.snapped(Vector3.ONE * 0.1), UndergroundHub.is_in_hub(cat.global_position), cat.speed_boost, CatHealth.instance.get_health(cat.player_id), cat.knocked_out])
			# What it's wearing, as seen on THIS computer (fur colour as hex + accessories).
			var model: Node3D = cat.cat_model
			var worn := PackedStringArray()
			for slot in CatLook.SLOTS:
				var part := model.get_node_or_null("Look_" + slot.capitalize())
				worn.append("%s=%s" % [slot, part.get_meta("part_id") if part != null else "-"])
			var fur: Color = ((model.get_node("Body") as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("albedo_color")
			print("DevCapture look %s: fur=#%s %s" % [cat.name, fur.to_html(false), " ".join(worn)])

	# The whole window: the blown-up game picture plus the sharp HUD on top.
	# --scale=N saves it as if each game pixel were N screen pixels (N x 240 tall).
	var image := get_viewport().get_texture().get_image()
	var screen := GameScreen.instance
	var game_pixels_tall := screen.game_view.size.y / get_viewport().get_visible_rect().size.y * image.get_height()
	var factor := float(args.get("scale", "4")) * screen.game_height / game_pixels_tall
	image.resize(roundi(image.get_width() * factor), roundi(image.get_height() * factor),
		Image.INTERPOLATE_BILINEAR if factor < 1.0 else Image.INTERPOLATE_NEAREST)
	var path := ProjectSettings.globalize_path("res://" + args["capture"])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("DevCapture saved: ", path)
	get_tree().quit()


## Watches every OTHER player's cat for a number of frames and prints how smoothly it
## moved on screen, next to how the raw network updates arrived.
## "still" = frames where it didn't move at all; "jump" = biggest single-frame move.
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


## The Roomba --bait_roomba / --zap_roomba act on: the nearest one, or the MEGA VAC-COP
## with --roomba=boss (waits for it to appear).
func _pick_roomba(scene: Node, near: Vector3, args: Dictionary) -> Roomba:
	if args.get("roomba", "") == "boss":
		for wait in 300:
			for roomba in scene.get_node("Roombas").get_children():
				if roomba is Roomba and (roomba as Roomba).is_boss:
					return roomba
			await get_tree().physics_frame
	return _nearest_roomba(scene, near)


func _nearest_roomba(scene: Node, from: Vector3) -> Roomba:
	var best: Roomba = null
	for roomba in scene.get_node("Roombas").get_children():
		if best == null or from.distance_to(roomba.global_position) < from.distance_to(best.global_position):
			best = roomba
	return best


## Turns ["--capture=a.png", "--drive"] into {"capture": "a.png", "drive": "true"}.
## --talk[=NODE_NAME]: stand in front of that NPC (default Don) and press E,
## then click the --choose buttons in order (0 = top button), as if the player did.
func _talk(player: CatPlayer, args: Dictionary) -> void:
	var npc: Npc = Game.instance.hub.npc
	for node in get_tree().get_nodes_in_group(Npc.GROUP):
		if node.name == args["talk"]:
			npc = node
	player.teleport_to(npc.global_position + npc.global_basis.z * 2.2, 0.0)
	await get_tree().physics_frame
	print("DevCapture talk: %s started=%s line=\"%s\"" % [npc.name, Npc.try_talk(player), NpcDialog.instance.line_label.text.left(50)])
	if args.has("click_choice"):
		# --click_choice=N: a REAL mouse click on talk-box button N (through the game screen and
		# the HUD, like a player's click), instead of --choose's direct button press.
		for i in 3:
			await get_tree().process_frame  # let the talk box lay out its buttons first
		var button := NpcDialog.instance.choices_box.get_child(int(args["click_choice"])) as Button
		var at := get_viewport().get_final_transform() * button.get_global_rect().get_center()
		var button_text := button.text
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = at
			click.global_position = at
			Input.parse_input_event(click)
			await get_tree().process_frame
		for i in 5:
			await get_tree().process_frame
		print("DevCapture click_choice %s (\"%s\"): open=%s line=\"%s\"" % [args["click_choice"], button_text, NpcDialog.is_open, NpcDialog.instance.line_label.text.left(40)])
	if args.has("choose"):
		for n in args["choose"].split(","):
			var buttons := NpcDialog.instance.choices_box.get_children()
			if not NpcDialog.is_open or int(n) >= buttons.size():
				print("DevCapture choose: no button %s" % n)
				break
			(buttons[int(n)] as Button).pressed.emit()
			for i in 5:
				await get_tree().process_frame
			print("DevCapture choose %s: open=%s line=\"%s\" buttons=%d" % [n, NpcDialog.is_open,
				NpcDialog.instance.line_label.text.left(40), NpcDialog.instance.choices_box.get_child_count()])


## --car_watch=N: every N frames, print where the car camera is looking (runs alongside the rest).
func _watch_car_camera(car: GetawayCar, every: int) -> void:
	while is_instance_valid(car):
		for i in every:
			await get_tree().process_frame
		if is_instance_valid(car):
			print("DevCapture car_watch: look_yaw=%.2f look_pitch=%.2f speed=%.1f" % [car.look_yaw, car.look_pitch, -car.global_basis.z.dot(car.linear_velocity)])


## A fake controller event: "A" / "Start" press or release, or a stick / trigger pushed all
## the way (pressed) or let go (not pressed). Same names as Controls.PAD_BUTTONS / PAD_AXES.
func _pad_event(pad_name: String, pressed: bool) -> InputEvent:
	var event := Controls._event_from_name("Pad " + pad_name)
	assert(event != null, "unknown controller name: " + pad_name)
	event.device = int(_args.get("pad_device", "0"))
	if event is InputEventJoypadButton:
		event.pressed = pressed
	elif not pressed:
		event.axis_value = 0.0
	return event


## "Button 'RESUME'" for the focus printout (or "-" when nothing is highlighted).
func _describe_focus(control: Control) -> String:
	if control == null:
		return "-"
	var text: String = control.get("text") if control.get("text") != null else ""
	return "%s '%s'" % [control.get_class(), text]


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var result := {}
	for arg in raw:
		var parts := arg.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return result
