extends "res://scripts/dev_tests/dev_test.gd"
## DevCapture test module: --tutorial_auto: plays the tutorial by itself.
## Made by scripts/dev_capture.gd `_add_module`; its options are listed at the top of dev_capture.gd.


## --tutorial --tutorial_auto: play the whole TUTORIAL (scripts/tutorial.gd) the quick way (moving
## the cat, asking the host like a player's buttons would), checking each step advances. Quits with
## 0 when it reaches TUTORIAL COMPLETE and the start menu comes back, 1 if a step got stuck.
func _tutorial_auto(player: CatPlayer) -> void:
	var tutorial := Tutorial.instance
	var me := player.player_id
	var items := ItemManager.instance
	var hub := UndergroundHub.of(player)
	await _seconds(0.5)
	var profile_file := PlayerProfile.PROFILES_FOLDER + str(Settings.current_cat().get("id", "")).validate_filename() + ".cfg"
	var profile_time := FileAccess.get_modified_time(profile_file) if FileAccess.file_exists(profile_file) else 0
	print("DevCapture tutorial start: step=%d cash=$%d stash=%s pack_size=%d mainframe=%d%% in_hub=%s box=%s \"%s\" | \"%s\"" % [
		tutorial.step, Wallet.instance.cash_of(me), items.get_stash(me), items.pack_size_for(me),
		int(Mainframe.instance.charge_of(player.team)), UndergroundHub.is_in_hub(player.global_position),
		Hud.element("TutorialBox").visible, (Hud.element("TutorialStep") as Label).text, (Hud.element("TutorialHint") as Label).text])
	await _tutorial_arrow("step1", "tutorial_step1_arrow.png")
	# Too early for Don: he should refuse.
	hub.deploy(player)
	await _seconds(0.3)
	print("DevCapture tutorial early deploy refused: %s" % UndergroundHub.is_in_hub(player.global_position))
	# 1. The quest (as if MITTENS' FISH was clicked in Lil' Mittens' talk box).
	player.teleport_to(hub.get_node("LilMittens").global_position + Vector3(0, 0, 2), 0.0)
	QuestManager.instance.start_quest(me, tutorial.quest_id)
	if not await _until_step(2): return
	# 2. Buy a PAW-PISTOL.
	player.teleport_to(hub.shopkeeper.global_position + hub.shopkeeper.global_basis.z * 2.0, 0.0)
	items.request_buy.rpc_id(1, me, "pistol")
	if not await _until_step(3): return
	# 3. Open the stash lockers (E), then close them.
	player.teleport_to(hub.to_global(hub.stash_spot), 0.0)
	await _seconds(0.3)
	print("DevCapture tutorial stash E: %s" % Interactable.try_use(player))
	await _seconds(0.5)
	print("DevCapture tutorial stash open=%s pack slots=%d" % [InventoryScreen.for_seat(0).visible, InventoryScreen.for_seat(0)._pack_buttons.size()])
	InventoryScreen.for_seat(0)._set_open(false)
	if not await _until_step(4): return
	# 4. Stand at the Mainframe.
	player.teleport_to(hub.to_global(hub.mainframe_spot) + Vector3(1.5, 0, 0), 0.0)
	if not await _until_step(5): return
	# 5. Don: SEND ME UP TOP.
	hub.deploy(player)
	if not await _until_step(6): return
	# 6. Three fish.
	for i in 10:
		if items.count_in_bag(me, "fish") >= tutorial.fish_needed:
			break
		await _grab_nearest(player, "fish")
	if not await _until_step(7): return
	print("DevCapture tutorial fish in bag: %d, heat=%.1f (frozen)" % [items.count_in_bag(me, "fish"), HeatMeter.instance.heat])
	# 7. Wait for a VAC-COP to be brought over, smash it, grab the scrap.
	await _seconds(1.0)
	var bot := tutorial._nearest_bot(player)
	print("DevCapture tutorial bot %s at %.1fm" % [bot.name if bot != null else "none", bot.global_position.distance_to(player.global_position) if bot != null else -1.0])
	if bot != null:
		bot.take_hit(me, 500)
	await _seconds(0.5)
	await _grab_nearest(player, "scrap")
	if not await _until_step(8): return
	# 8. A payphone (E), then the exit.
	await _seconds(0.5)
	print("DevCapture tutorial heat=%.1f exit_open=%s" % [HeatMeter.instance.heat, FishHeist.instance.exit_is_open(player.team)])
	await _tutorial_arrow("step8 phase0", "tutorial_step8_payphone.png")
	var phone := tutorial._nearest_payphone(player)
	var phone_npc: Node3D = null
	for node in FishHeist.instance.get_children():
		if node is Payphone and (node as Node3D).global_position.distance_to(phone) < 0.1:
			phone_npc = node
	player.teleport_to(phone_npc.global_position + phone_npc.global_basis.z * 1.8, 0.0)
	for i in 15:
		await get_tree().physics_frame
	print("DevCapture tutorial payphone E: %s line=\"%s\" talk box open=%s" % [Interactable.try_use(player), (phone_npc as Payphone).last_line, NpcDialog.is_open_for(player.slot)])
	await _seconds(0.5)
	await _tutorial_arrow("step8 phase1", "tutorial_step8_exit.png")
	print("DevCapture tutorial revealed=%s phase=%d hint=\"%s\"" % [FishHeist.instance.is_revealed(player.team), tutorial.phase, (Hud.element("TutorialHint") as Label).text])
	player.teleport_to(FishHeist.instance.exit_for(player.team) + Vector3(0, 0.2, 0), 0.0)
	if not await _until_step(9): return
	print("DevCapture tutorial extracted: cash=$%d bag=%s in_hub=%s" % [Wallet.instance.cash_of(me), items.get_inventory(me).pack, UndergroundHub.is_in_hub(player.global_position)])
	# 9. Feed the scrap.
	await _seconds(1.0)
	player.teleport_to(hub.to_global(hub.mainframe_spot) + Vector3(1.5, 0, 0), 0.0)
	for i in 15:
		await get_tree().physics_frame
	print("DevCapture tutorial mainframe E: %s" % Interactable.try_use(player))
	if not await _until_step(Tutorial.DONE): return
	print("DevCapture tutorial done: mainframe=%d%% banner=\"%s\"" % [int(Mainframe.instance.charge_of(player.team)), (Hud.element("Banner") as Label).text.replace("\n", " ")])
	var old_game := Game.instance
	var give_up := Time.get_ticks_msec() + 10000
	while Game.instance == old_game and Time.get_ticks_msec() < give_up:
		await get_tree().process_frame
	await _seconds(0.5)
	var touched := FileAccess.file_exists(profile_file) and FileAccess.get_modified_time(profile_file) != profile_time
	print("DevCapture tutorial back at menu: %s tutorial=%s real save touched=%s" % [
		Game.instance != old_game and Game.instance.main_menu.visible, Game.is_tutorial(), touched])
	get_tree().quit(0)


## Print what the green arrow + beacon show right now ("DevCapture tutorial arrow ..." line) and,
## with --tutorial_shots, save the whole window to shots/<file>.
func _tutorial_arrow(when: String, file: String) -> void:
	await _seconds(0.4)  # (let the arrow turn + the box settle)
	var compass := Hud.element("Compass") as HudCompassArrow
	print("DevCapture tutorial arrow %s: visible=%s text=\"%s\" beacon=%s step_line=\"%s\"" % [when,
		compass.visible, compass._text, Tutorial.instance._beacon.visible, (Hud.element("TutorialStep") as Label).text])
	if _args.has("tutorial_shots") and DisplayServer.get_name() != "headless":
		var path := ProjectSettings.globalize_path("res://shots/" + file)
		get_viewport().get_texture().get_image().save_png(path)
		print("DevCapture saved: ", path)


## Wait until the tutorial reaches this step (up to 15 s). False (and quits with 1) if it never does.
func _until_step(wanted: int) -> bool:
	var give_up := Time.get_ticks_msec() + 15000
	while Tutorial.instance.step < wanted and Time.get_ticks_msec() < give_up:
		await get_tree().process_frame
	if Tutorial.instance.step < wanted:
		print("DevCapture tutorial STUCK on step %d (phase %d), wanted %d" % [Tutorial.instance.step, Tutorial.instance.phase, wanted])
		get_tree().quit(1)
		return false
	return true


## Teleport next to the nearest ITEM on the ground and ask the host for it, like pressing E.
func _grab_nearest(player: CatPlayer, item_id: String) -> void:
	var items := ItemManager.instance
	var best := -1
	for id in items.world:
		if items.world[id].item == item_id and (best == -1 or items.world[id].pos.distance_to(player.global_position) < items.world[best].pos.distance_to(player.global_position)):
			best = id
	if best == -1:
		print("DevCapture tutorial: no %s lying around" % item_id)
		await _seconds(3.5)  # (the tutorial drops spare fish every few seconds)
		return
	player.teleport_to(items.world[best].pos + Vector3(0.8, 0.3, 0), 0.0)
	for i in 12:
		await get_tree().physics_frame
	items.request_pickup.rpc_id(1, player.player_id, best)
	await _seconds(0.3)
