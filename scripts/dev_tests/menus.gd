extends "res://scripts/dev_tests/dev_test.gd"
## DevCapture test module: Shop, workbench, upgrades, inventory and NPC talk tests.
## Made by scripts/dev_capture.gd `_add_module`; its options are listed at the top of dev_capture.gd.


## SEWER UPGRADES test (--buy_upgrade / --select_vehicle / --upgrade_log): one "DevCapture upgrades"
## line before, after each buy, and after the ride is picked.
func _upgrades_test(player: CatPlayer, args: Dictionary) -> void:
	for i in 30:
		await get_tree().physics_frame  # the save (cash, stash, upgrades) arrives first
	_print_upgrades(player, "start")
	if args.has("buy_upgrade"):
		for upgrade_id in args["buy_upgrade"].split(","):
			Upgrades.instance.request_buy.rpc_id(1, player.player_id, upgrade_id)
			for i in 15:
				await get_tree().physics_frame
			_print_upgrades(player, "bought " + upgrade_id)
	if args.has("select_vehicle"):
		Upgrades.instance.request_select_vehicle.rpc_id(1, player.player_id, args["select_vehicle"])
		for i in 15:
			await get_tree().physics_frame
		var car := _car_for(player)
		print("DevCapture vehicle: %s is %s max_speed=%.1f (x%.2f turbo) accel=%.1f turn=%.1f mass=%.0f seats=%d smash x%.1f box=%s model=%s wheels=%d" % [
			car.name, car.vehicle, car.max_speed, Upgrades.engine_multiplier(maxi(0, car.team)), car.engine_accel,
			car.turn_speed, car.mass, car.passenger_seats, car.smash_speed_factor,
			(car.get_node("CollisionShape3D").shape as BoxShape3D).size, car.get_node("Model/CarModel").scene_file_path.get_file(), car._wheels.size()])


func _print_upgrades(player: CatPlayer, when: String) -> void:
	var me := player.player_id
	var items := ItemManager.instance
	var inv := items.get_inventory(me)
	var shop := PackedStringArray()
	var whiskers := UndergroundHub.of(player).shopkeeper as Shopkeeper
	if whiskers != null:
		for item_id in whiskers.stock:
			if Upgrades.shop_allows(me, item_id):
				shop.append(item_id)
	print("DevCapture upgrades (%s): %s cash=$%d scrap=%d (pack %d, litterbox %d) bag=%d pack=%d stash=%d quick=%d max_hp=%d hp=%d zoom=x%.2f gourmet=x%.2f paws=x%.2f magnet=%.2f exit_heat=%.0f feed=+%.0f%% ride=%s shop=%s" % [
		when, Upgrades.instance.player_upgrades.get(me, {}), Wallet.instance.cash_of(me), items.scrap_count_of(me),
		inv.pack.count("scrap"), (inv.get("stash", []) as Array).count("scrap"), items.bag_size_for(me), items.pack_size_for(me),
		items.stash_size_for(me), items.quick_stack_size_for(me), CatHealth.instance.max_health_for(me), CatHealth.instance.get_health(me),
		Upgrades.zoomies_multiplier(me), Upgrades.gourmet_multiplier(me), Upgrades.melee_multiplier(me), Upgrades.scrap_magnet_chance(me),
		Mainframe.instance.exit_heat(player.team), Mainframe.instance.charge_per_scrap_for(player.team),
		Upgrades.instance.vehicle_of(player.team), ",".join(shop)])


## THE BLACK MARKITTEN (scripts/ui/shop_screen.gd): --talk=ComradeWhiskers presses E on him (the shop
## screen opens), then, in this order:
##   --shop_tab=N               switch tab (0 MELEE, 1 CONSUMABLES, 2 FIREARMS)
##   --shop_buy=a,b             click those items' rows (locked ones should refuse)
##   --shop_sell=pack:0,hand:0  click those backpack / paw / quick slots (sells them)
##   --shop_sell_all            click SELL ALL LOOT
##   --shop_pad=right,down,...  move the d-pad highlight (prints what it lands on)
##   --shop_close=Tab|Esc       a real key press that should close it
## Prints "DevCapture shop" lines (tab, rows, locked, cash, backpack, highlight, message).
func _shop_test(player: CatPlayer, keeper: Shopkeeper, args: Dictionary) -> void:
	var used := Interactable.try_use(player)
	var shop := ShopScreen.for_seat(player.slot)
	var items := ItemManager.instance
	var report := func(when: String) -> void:
		var rows := shop._rows.filter(func(r): return r.visible).map(func(r): return "%s%s" % [r.get_node("Face").item_id, "(LOCKED)" if r.get_node("Face").locked else ""])
		var focus: Button = shop._focus.current
		var focus_name := "-"
		if focus != null:
			focus_name = focus.text if focus.text != "" else (focus.get_node("Face").item_id if focus.has_meta("row") else "%s%d:%s" % [focus.get_meta("where", "?"), focus.get_meta("index", 0), focus.get_meta("item", "")])
		var inventory := InventoryScreen.for_seat(player.slot)
		print("DevCapture shop (%s): open=%s tab=%d rows=%s cash=$%d pack=%s hands=%s inventory_open=%s shop_mode=%s focus=%s note=\"%s\" sell_all=\"%s\"" % [
			when, shop.visible, shop.tab, rows, Wallet.instance.cash_of(player.player_id), items.get_inventory(player.player_id).pack,
			items.get_inventory(player.player_id).hands, inventory.visible, inventory.shop_mode, focus_name, shop._note, shop._sell_all.text])
	for i in 30:
		await get_tree().process_frame
	print("DevCapture shop: %s used=%s menu_blocks_cat=%s wants_input=%s" % [keeper.name, used, player._menu_open(), Hud.wants_input(player.slot)])
	report.call("open")
	if args.has("shop_tab"):
		shop._set_tab(int(args["shop_tab"]))
		report.call("tab")
	if args.has("shop_buy"):
		for item_id in str(args["shop_buy"]).split(","):
			for tab_index in 3:
				if item_id in shop._tab_items(tab_index):
					shop._set_tab(tab_index)
			for row in shop._rows:
				if row.visible and row.get_node("Face").item_id == item_id:
					shop._press_row(row)
			for i in 20:
				await get_tree().process_frame
			report.call("buy " + item_id)
	if args.has("shop_sell"):
		var inventory := InventoryScreen.for_seat(player.slot)
		for slot in str(args["shop_sell"]).split(","):
			var parts: PackedStringArray = slot.split(":")
			var list: Array = {"pack": inventory._pack_buttons, "hand": inventory._paw_buttons, "quick": inventory._quick_buttons}[parts[0]]
			for button in list:
				if button.get_meta("index") == int(parts[1]):
					inventory._use_slot(button, parts[0], int(parts[1]), false)
					break
			for i in 20:
				await get_tree().process_frame
			report.call("sell " + slot)
	if args.has("shop_sell_all"):
		shop._sell_all_loot()
		for i in 20:
			await get_tree().process_frame
		report.call("sell all")
	if args.has("shop_pad"):
		for direction in str(args["shop_pad"]).split(","):
			var move := InputEventAction.new()
			move.action = "ui_" + direction
			move.pressed = true
			shop._focus.handle(move)
			report.call("pad " + direction)
	if args.has("shop_close"):
		for pressed in [true, false]:
			var key := InputEventKey.new()
			key.physical_keycode = OS.find_keycode_from_string(args["shop_close"])
			key.keycode = key.physical_keycode
			key.pressed = pressed
			Input.parse_input_event(key)
			await get_tree().process_frame
		for i in 10:
			await get_tree().process_frame
		report.call("after " + str(args["shop_close"]))


## --workbench (after walking there and pressing E): print the TINKER WORKBENCH screen, then
## --workbench_recruit=N / --workbench_buy=a,b / --workbench_tab=N ("DevCapture workbench" lines).
func _workbench_test(player: CatPlayer, args: Dictionary) -> void:
	var bench := WorkbenchScreen.for_seat(player.slot)
	var hub := UndergroundHub.of(player)
	var report := func(when: String) -> void:
		var tabs := []
		for i in bench._tabs.size():
			var npc := bench.npc_for_tab(i)
			tabs.append("%d:%s=%s" % [i, npc.name if npc != null else "-", bench.tab_state(i)])
		var cards := bench._cards.filter(func(c): return c.visible).map(func(c): return "%s(%d)" % [c.get_node("Face").upgrade_id,
			Upgrades.instance.current_tier(player.player_id, c.get_node("Face").upgrade_id)])
		var present := hub.get_children().filter(func(n): return n is Npc and n.rebellion_tier > 0 and n.present).map(func(n): return n.name)
		print("DevCapture workbench (%s): open=%s tab=%d tabs=%s cards=%s recruit=%s cash=$%d scrap=%d rebellion=%d npcs_present=%s note=\"%s\"" % [
			when, bench.visible, bench.tab, tabs, cards, ("\"%s\"" % bench._recruit.text) if bench._recruit.visible else "-",
			Wallet.instance.cash_of(player.player_id), ItemManager.instance.scrap_count_of(player.player_id),
			Upgrades.rebellion_level(player.team), present, bench._note])
	for i in 10:
		await get_tree().process_frame
	report.call("open")
	for n in int(args.get("workbench_recruit", "0")):
		bench._set_tab(Upgrades.rebellion_level(player.team) + 2)
		bench._press_recruit()
		for i in 30:
			await get_tree().process_frame
		report.call("recruit %d" % (n + 1))
	if args.has("workbench_buy"):
		for upgrade_id in str(args["workbench_buy"]).split(","):
			bench._set_tab(maxi(0, Upgrades.tab_of(upgrade_id)))
			for card in bench._cards:
				if card.visible and card.get_node("Face").upgrade_id == upgrade_id:
					bench._press_card(card)
			for i in 20:
				await get_tree().process_frame
			report.call("buy " + upgrade_id)
	if args.has("workbench_tab"):
		bench._set_tab(int(args["workbench_tab"]))
		for i in 5:
			await get_tree().process_frame
		report.call("tab")


## --inventory: after a while, print what each open inventory screen shows ("DevCapture inventory").
func _inventory_report(seats: Array, frames: int) -> void:
	for i in mini(60, frames / 2):
		await get_tree().process_frame
	for seat in seats:
		var screen := InventoryScreen.for_seat(seat)
		if screen == null or screen.owner_cat == null:
			print("DevCapture inventory seat %d: none" % seat)
			continue
		var cat := screen.owner_cat
		var shown := func(list: Array) -> String:
			return ",".join(list.map(func(b):
				var count: int = (b.get_node("Face") as InventoryScreen.SlotFace).count
				return (str(b.get_meta("item")) + ("x%d" % count if count > 1 else "")) if b.get_meta("item") != "" else "-"))
		print("DevCapture inventory seat %d: open=%s view=%.2f at_stash=%s cam_len=%.2f paws=[%s] quick=[%s] pack=[%s] stash=[%s] info=\"%s\"" % [
			seat, screen.visible, cat.inventory_view_amount(), screen._at_stash, cat.spring_arm.spring_length,
			shown.call(screen._paw_buttons), shown.call(screen._quick_buttons), shown.call(screen._pack_buttons),
			shown.call(screen._stash_buttons.filter(func(b): return b.visible)), screen._info.text])


func _talk(player: CatPlayer, args: Dictionary) -> void:
	var npc: Npc = UndergroundHub.of(player).npc  # (our own gang's boss)
	for node in get_tree().get_nodes_in_group(Npc.GROUP):
		if node.name == args["talk"]:
			npc = node
	if npc.rebellion_tier > 0 and Upgrades.rebellion_override < 0:
		# THE SEWER REBELLION: a recruit nobody has recruited is hidden. Old quest tests just want to talk.
		Upgrades.rebellion_override = Upgrades.REBELLION_TIERS
		print("DevCapture talk: %s is a REBELLION TIER %d recruit: --rebellion_tier=5 for this test" % [npc.name, npc.rebellion_tier])
		for i in 20:
			await get_tree().process_frame  # (they check every quarter second)
	player.teleport_to(npc.global_position + npc.global_basis.z * 2.2, 0.0)
	await get_tree().physics_frame
	if npc is Payphone:
		# A payphone opens no talk box: the boss's line types out over the phone, and the cat can
		# keep moving. Face the phone (the line floats above it) and print what the boss said.
		var facing := npc.global_basis.z
		player.camera_pivot.rotation.y = atan2(facing.x, facing.z)
		var used := Interactable.try_use(player)
		print("DevCapture payphone: %s used=%s line=\"%s\" talk box open=%s" % [npc.name, used, (npc as Payphone).last_line, NpcDialog.is_open_for(player.slot)])
		for i in 20:
			await get_tree().physics_frame
		print("DevCapture payphone: revealed=%s typing=\"%s\"" % [FishHeist.instance.is_revealed(player.team), npc.get_node("Readout").text.replace("
", " / ")])
		return
	if npc is Shopkeeper:
		await _shop_test(player, npc as Shopkeeper, args)  # (E opens THE BLACK MARKITTEN shop screen, not a talk box)
		return
	print("DevCapture talk: %s started=%s line=\"%s\"" % [npc.name, Interactable.try_use(player), NpcDialog.for_cat(player).line_label.text.left(50)])
	if args.has("click_choice"):
		# --click_choice=N: a REAL mouse click on talk-box button N (through the game screen and
		# the HUD, like a player's click), instead of --choose's direct button press.
		for i in 3:
			await get_tree().process_frame  # let the talk box lay out its buttons first
		var button := NpcDialog.for_cat(player).choices_box.get_child(int(args["click_choice"])) as Button
		# (The HUD has its own viewport, drawn at Hud1's spot on the screen.)
		var hud_view := GameScreen.instance.get_node("Hud1") as Control
		var at := get_viewport().get_final_transform() * (hud_view.position + button.get_global_rect().get_center() * Hud.of(0).scale)
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
		print("DevCapture click_choice %s (\"%s\"): open=%s line=\"%s\"" % [args["click_choice"], button_text, NpcDialog.is_open_for(player.slot), NpcDialog.for_cat(player).line_label.text.left(40)])
	if args.has("choose"):
		for n in args["choose"].split(","):
			var buttons := NpcDialog.for_cat(player).choices_box.get_children()
			if not NpcDialog.is_open_for(0) or int(n) >= buttons.size():
				print("DevCapture choose: no button %s" % n)
				break
			(buttons[int(n)] as Button).pressed.emit()
			for i in 5:
				await get_tree().process_frame
			print("DevCapture choose %s: open=%s line=\"%s\" buttons=%d" % [n, NpcDialog.is_open_for(0),
				NpcDialog.for_cat(player).line_label.text.left(40), NpcDialog.for_cat(player).choices_box.get_child_count()])
