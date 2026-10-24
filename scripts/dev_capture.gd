extends Node
## DEV TOOL — takes a screenshot of the running game, saves it, then quits.
## Does nothing during normal play (it only wakes up when given --capture).
##
## Run from a terminal in the project folder, e.g.:
##   C:\GoDot\Godot_v4.7.2-stable_win64_console.exe --path . -- --host --capture=shots/street.png --pos=0,0,6 --yaw=0 --pitch=-12
## Options (everything after the lone "--"):
##   --capture=PATH    where to save the PNG (relative to the project folder)
##   --host / --join   start a game (otherwise you get the lobby menu)
##   --pos=X,Y,Z       move the cat here first
##   --yaw=DEG         turn the camera left/right
##   --pitch=DEG       tilt the camera up/down
##   --drive           put the cat in the car (car view)
##   --talk            walk up to Don Catleone in the hub and press E (talk box open)
##   --bait_roomba=D   (host) put the nearest Roomba D metres in front of our cat
##   --zap_roomba=N    (host) hit the nearest Roomba N times, as if shot
##   --deploy          ask Don to send us up top (cat moves from the hub to the city)
##   --grab=ITEM       walk to the nearest ITEM (e.g. tommy_gun, catnip) and press E on it.
##                     Repeat with a comma list: --grab=catnip,catnip (fire/use with --hold=shoot)
##   --drop_after=N    drop what's in the paws (G) N frames after the --hold finishes
##   --equip=N         take backpack slot N into the paws (what clicking it in the inventory does)
##   --inventory       open the inventory screen (Tab) before the snap
##   --hold=ACTION     hold a control for --hold_frames (default 60), e.g. move_forward,
##                     starting after --hold_delay frames (default 30)
##   --exit_after=N    get out of the car N frames after the --hold finishes
##   --goto_dropoff_after=N   jump into the extraction beam after N more frames (in the car if driving)
##   --track=N        measure how smoothly other players' cats move over N frames
##   --net_interval=S  simulate a laggy connection: send our cat's position only every S seconds
##   --frames=N        frames to wait before the snap (default 90 = 1.5 s)
##   --scale=N         upscale factor for the saved image (default 4)
##   --menu=NAME       open a menu first: play, settings or pause (--settings_tab=N picks the tab)


func _ready() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	# Never runs in a release build (the exported .exe players get), only in Godot / debug builds.
	if not args.has("capture") or not OS.is_debug_build():
		queue_free()
		return

	# Let the main scene finish loading.
	await get_tree().process_frame
	var scene := get_tree().current_scene

	# Wait (up to ~10 s) for OUR cat to exist — a joining game needs time to connect.
	# Without --host / --join no cat ever appears, and we just photograph the lobby.
	var player: CatPlayer = null
	if args.has("host") or args.has("join"):
		var give_up_at := Time.get_ticks_msec() + 10000  # seconds, not frames: fps varies a lot
		while Time.get_ticks_msec() < give_up_at:
			player = scene.get_node_or_null("Players/%d" % multiplayer.get_unique_id()) as CatPlayer
			if player != null:
				break
			await get_tree().process_frame

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
		if args.has("net_interval"):
			# Simulate a bad connection: only send our cat's position every N seconds.
			(player.get_node("MultiplayerSynchronizer") as MultiplayerSynchronizer).replication_interval = float(args["net_interval"])
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
		if args.has("talk"):
			var don := (scene as Game).hub.npc
			player.teleport_to(don.global_position + Vector3(0, 0, 2.2), 0.0)
			await get_tree().physics_frame
			print("DevCapture talk: started=%s" % (scene as Game).hub.try_talk(player))
		if args.has("drive"):
			for i in 20:
				await get_tree().process_frame  # let the host see our new position first
			(scene.get_node("GetawayCar") as GetawayCar).request_enter.rpc_id(1)
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
			ItemManager.instance.request_equip.rpc_id(1, int(args["equip"]))
			for i in 10:
				await get_tree().process_frame
		if args.has("stash"):
			# Click paw N in the inventory screen (0 = right, 1 = left): put it in the backpack.
			ItemManager.instance.request_stash.rpc_id(1, int(args["stash"]))
			for i in 10:
				await get_tree().process_frame
		if args.has("drop_slot"):
			# Right-click a slot in the inventory screen, e.g. --drop_slot=pack:0 or bag:0 or hand:1
			var parts: PackedStringArray = args["drop_slot"].split(":")
			ItemManager.instance.request_drop_item.rpc_id(1, parts[0], int(parts[1]), ItemManager.instance.ground_in_front_of(player))
			for i in 10:
				await get_tree().process_frame
		if args.has("bait_roomba"):
			# --bait_roomba=4: 4 m in front of the cat.  --bait_roomba=aim: right under the crosshair
			# (where the camera's centre line meets the ground), stunned so it stays put a moment.
			for i in 20:
				await get_tree().process_frame  # let the camera settle (over-the-shoulder slide)
			var roomba := _nearest_roomba(scene, player.global_position)
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
			var roomba := _nearest_roomba(scene, player.global_position)
			for i in int(args["zap_roomba"]):
				roomba.take_hit()
		if args.has("hold"):
			# Pretend a key is held down, e.g. --hold=move_forward --hold_frames=60
			for i in int(args.get("hold_delay", "30")):
				await get_tree().process_frame
			# Several at once with a comma list, e.g. --hold=shoot,use_left (fire both pistols).
			for action in args["hold"].split(","):
				Input.action_press(action)
			for i in int(args.get("hold_frames", "60")):
				await get_tree().process_frame
			if not args.has("keep_holding"):  # --keep_holding = still held when the snap is taken
				for action in args["hold"].split(","):
					Input.action_release(action)
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
					Input.action_press("jump")
				elif i == 2 or i == 20:
					Input.action_release("jump")
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
			var beam := (scene.get_node("Heist") as FishHeist).dropoff_position + Vector3(1, 0, 1)
			var car := scene.get_node("GetawayCar") as GetawayCar
			if car.driver_id == multiplayer.get_unique_id():
				car.global_position = beam + Vector3(0, 0.5, 0)  # driving: take the car there
			else:
				player.global_position = beam

	if args.has("inventory"):
		scene.get_node("PS1Overlay/Inventory")._set_open(true)  # same as pressing Tab
	# --menu=play / settings / pause   open that menu before the snap
	# --settings_tab=N                  which settings tab to show (0 = DISPLAY)
	if args.has("menu") and scene is Game:
		match args["menu"]:
			"play": scene.main_menu.show_play_screen()
			"settings": scene.settings_menu.open()
			"pause": scene.pause_menu.open()
		if args.has("settings_tab"):
			scene.settings_menu._show_tab(int(args["settings_tab"]))

	for i in int(args.get("frames", "90")):
		await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# The scene may have been reloaded meanwhile (e.g. the host quit), so look it up again.
	scene = get_tree().current_scene
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
		print("DevCapture heist: dropoff=%s cash=%s" % [heist.dropoff_position, heist.cash])
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
			print("DevCapture cat %s: name=\"%s\" tag=\"%s\" visible=%s position=%s in_hub=%s speed_boost=%.1f" % [cat.name, cat.player_name, cat.get_node("NameTag").text, cat.visible, cat.position.snapped(Vector3.ONE * 0.1), UndergroundHub.is_in_hub(cat.global_position), cat.speed_boost])

	var image := get_viewport().get_texture().get_image()
	var scale := int(args.get("scale", "4"))
	image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
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


func _nearest_roomba(scene: Node, from: Vector3) -> Roomba:
	var best: Roomba = null
	for roomba in scene.get_node("Roombas").get_children():
		if best == null or from.distance_to(roomba.global_position) < from.distance_to(best.global_position):
			best = roomba
	return best


## Turns ["--capture=a.png", "--drive"] into {"capture": "a.png", "drive": "true"}.
func _parse_args(raw: PackedStringArray) -> Dictionary:
	var result := {}
	for arg in raw:
		var parts := arg.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return result
