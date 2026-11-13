class_name ItemVisuals
extends RefCounted
## CYPURRPUNK — Visuals, city loot placement, and local paw input for ItemManager
## (scripts/items/item_manager.gd):
##   - Places the district's LootTable on sidewalks and inside Meow-Mart (place_city_loot)
##   - Builds 3D street-item nodes, glow lights and floating HUD name-tag markers (spawn_world_node)
##   - Syncs 3D held items in every cat's paws and the backpack model on its back (sync_cat)
##   - Feeds the bottom-left weapon / quick-use HUD box and crosshair (update_hud)
##   - Drives local paw triggers, aim-down-sights, boomerang bat throws and quick-use keys (use_held_items)


## Places every line of the city's LootTable (and the Clearance prize) when a district is generated.
static func place_city_loot(items: ItemManager, city_seed: int) -> void:
	for id in items.world.keys():
		if id < ItemManager.FIRST_DROPPED_ID or not UndergroundHub.is_in_hub(items.world[id].pos):
			items._remove_world_local(id)
	items._spawns.clear()
	items._mart_spots_used.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(city_seed * 31 + ItemManager.LOOT_SEED_SALT)
	if items.loot_table != null:
		for line in items.loot_table.spawns:
			if line != null:
				_place_loot_line(items, line, rng)
	var twist := DistrictTwist.instance
	if DistrictTwist.is_clearance() and twist.clearance_prize_item != "" and items.catalog.has(twist.clearance_prize_item):
		items.add_spawn_point(twist.clearance_prize_item, items.city.meow_mart_position + items.city.meow_mart_outward * 3.0, 0.0)
	items.get_tree().call_group("item_placers", "place_items", items, city_seed)


static func _place_loot_line(items: ItemManager, line: LootSpawn, rng: RandomNumberGenerator) -> void:
	if not items.catalog.has(line.item_id):
		push_warning("[Items] Loot table: no item card called '%s' in res://items/" % line.item_id)
		return
	var door := items.city.meow_mart_position
	var count := line.count
	if line.where == LootSpawn.Where.SIDEWALK and MeowMartInterior.koi_in_tank(line.item_id):
		return
	if line.where == LootSpawn.Where.OUTSIDE_MEOW_MART and line.item_id == "fish" and DistrictTwist.is_clearance():
		count *= DistrictTwist.instance.clearance_fish_multiplier
	for i in count:
		var spot := Vector3.ZERO
		match line.where:
			LootSpawn.Where.OUTSIDE_MEOW_MART:
				var row := i / line.count
				var in_row := i % line.count
				spot = door + Vector3((in_row - (line.count - 1) / 2.0) * 1.3, 0, -0.5) + items.city.meow_mart_outward * 1.3 * row
			LootSpawn.Where.FIXED_SPOT:
				spot = line.spot + Vector3(i * 0.8, 0, 0)
			LootSpawn.Where.MEOW_MART_SHELF, LootSpawn.Where.MEOW_MART_COUNTER:
				var free := _free_mart_spots(items, line.where)
				if free.is_empty():
					push_warning("[Items] Meow-Mart has no free spot left for '%s'" % line.item_id)
					return
				spot = free[rng.randi_range(0, free.size() - 1)]
				items._mart_spots_used[spot] = true
			_:
				spot = random_sidewalk_spot(items.city, rng)
				for attempt in 20:
					if spot.distance_to(door) >= line.min_distance_from_meow_mart:
						break
					spot = random_sidewalk_spot(items.city, rng)
		items.add_spawn_point(line.item_id, spot, line.respawn_seconds)


static func _free_mart_spots(items: ItemManager, where: LootSpawn.Where) -> Array[Vector3]:
	var free: Array[Vector3] = []
	if MeowMartInterior.instance == null:
		return free
	var counter := where == LootSpawn.Where.MEOW_MART_COUNTER
	for spot in MeowMartInterior.instance.loot_spots(counter):
		if not items._mart_spots_used.has(spot):
			free.append(spot)
	return free


## A random spot on a sidewalk, along the street edge of a random block.
static func random_sidewalk_spot(city: CityGenerator, rng: RandomNumberGenerator) -> Vector3:
	var pitch := city.block_size + city.street_width
	var blocks := city.blocks_per_side
	var block_center := Vector3(
		(rng.randi_range(0, blocks - 1) + 0.5 - blocks / 2.0) * pitch, 0,
		(rng.randi_range(0, blocks - 1) + 0.5 - blocks / 2.0) * pitch)
	var outward: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK][rng.randi_range(0, 3)]
	var along := Vector3(outward.z, 0, outward.x)
	return block_center + outward * (city.block_size * 0.5 - 0.5) + along * rng.randf_range(-9.0, 9.0)


## Builds the 3D street node (model + optional OmniLight3D + HUD name-tag marker) for a world item.
static func spawn_world_node(items: ItemManager, data: ItemData, at: Vector3) -> Node3D:
	var spot := Node3D.new()
	spot.position = at
	items.add_child(spot)
	var model := data.scene.instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * data.world_scale
	spot.add_child(model)
	if data.glow_color.a > 0.0:
		var glow := OmniLight3D.new()
		glow.light_color = data.glow_color
		glow.light_energy = 1.5
		glow.omni_range = 3.0
		glow.distance_fade_enabled = true
		glow.distance_fade_begin = 35.0
		glow.position.y = 0.4
		spot.add_child(glow)
	var tag := Label3D.new()
	tag.add_to_group(HudNameTags.GROUP)
	tag.text = data.display_name
	tag.transparency = 1.0
	tag.position.y = 1.25
	tag.set_meta("max_distance", items.item_tag_distance)
	if data.kind == ItemData.Kind.LOOT:
		tag.modulate = data.glow_color.lightened(0.25) if data.glow_color.a > 0.0 else Color(0.95, 0.95, 1.0)
	else:
		tag.modulate = Color(1, 1, 1, 0.9)
	spot.add_child(tag)
	return spot


## Syncs a cat's 3D held paw items, backpack fill strip, and over-the-shoulder camera flag.
static func sync_cat(items: ItemManager, cat: CatPlayer) -> void:
	var inventory := items.get_inventory(cat.player_id)
	var hands_key := str(inventory.hands)
	if cat.get_meta("hands_key", "") != hands_key:
		cat.set_meta("hands_key", hands_key)
		_rebuild_paws(items, cat, inventory.hands)
	var used := items.pack_slots_used(cat.player_id, inventory.pack)
	var pack_key := "%d/%d" % [used, items.pack_size_for(cat.player_id)]
	if cat.get_meta("pack_key", "") != pack_key or cat.cat_model.get_node_or_null("BackPack") == null:
		cat.set_meta("pack_key", pack_key)
		_update_backpack(items, cat, used, items.pack_size_for(cat.player_id))
	var shoulder := false
	for item_id in items._held_ids(inventory.hands):
		shoulder = shoulder or items.catalog[item_id].shoulder_camera
	cat.shoulder_view = shoulder


static func _rebuild_paws(items: ItemManager, cat: CatPlayer, hands: Array) -> void:
	for slot in ["HeldR", "HeldL"]:
		var old := cat.cat_model.get_node_or_null(slot)
		if old != null:
			old.get_parent().remove_child(old)
			old.queue_free()
	for hand in 2:
		var item_id: String = hands[hand]
		if item_id == "" or (hand == 1 and items._is_two_handed(hands)):
			continue
		var data: ItemData = items.catalog[item_id]
		var node := data.scene.instantiate() as Node3D
		node.name = "HeldR" if hand == 0 else "HeldL"
		var offset := data.hold_offset
		if hand == 1:
			offset.x = -offset.x
		node.position = offset
		node.scale = Vector3.ONE * data.hold_scale
		var held := node as HeldItem
		if held != null:
			held.data = data
			held.holder = cat
			held.hand = hand
		cat.cat_model.add_child(node)


static func _update_backpack(items: ItemManager, cat: CatPlayer, used: int, size: int) -> void:
	var pack := cat.cat_model.get_node_or_null("BackPack") as Node3D
	if pack == null:
		pack = LevelKit.instantiate_model(ItemManager.BACKPACK_MODEL)
		if pack == null:
			return
		pack.name = "BackPack"
		pack.position = ItemManager.BACKPACK_SPOT
		cat.cat_model.add_child(pack)
	pack.visible = items.show_backpack
	var fill := clampf(float(used) / maxf(size, 1), 0.0, 1.0)
	var light := items.pack_light_empty.lerp(items.pack_light_half, fill * 2.0) if fill < 0.5 else items.pack_light_half.lerp(items.pack_light_full, (fill - 0.5) * 2.0)
	LevelKit.make_parts_glow(pack, {"Strip": light}, 1.5 + fill * 2.0)


## World-space position of the cat's PackAnchor marker (where the inventory callout line starts).
static func backpack_anchor(cat: CatPlayer) -> Vector3:
	var anchor := cat.cat_model.get_node_or_null("BackPack/PackAnchor") as Node3D
	if anchor == null:
		var pack := cat.cat_model.get_node_or_null("BackPack")
		anchor = pack.find_child("PackAnchor", true, false) as Node3D if pack != null else null
	if anchor != null:
		return anchor.global_position
	return cat.cat_model.to_global(ItemManager.BACKPACK_SPOT + Vector3(0, 0.15, 0.15))


## Updates the bottom-left weapon box and crosshair for every local player seat.
static func update_hud(items: ItemManager) -> void:
	if Game.instance == null:
		return
	for cat in Game.instance.playing_cats():
		_update_hud_for(items, cat)


static func _update_hud_for(items: ItemManager, cat: CatPlayer) -> void:
	var paws: Array = []
	var quick: Array = []
	var wants_crosshair := false
	if cat.is_controlled or cat.is_gunner():
		var keys := ["shoot", "use_left"]
		for hand in 2:
			var held := items.held_item(cat, hand)
			if held == null or held.data == null:
				continue
			var weapon := held as Weapon
			paws.append({
				"id": held.data.id,
				"name": weapon.hud_name if weapon != null else held.data.display_name,
				"heat": weapon.heat if weapon != null else 0.0,
				"overheated": weapon != null and weapon.is_overheated,
				"heats": weapon != null and weapon.heat_per_shot > 0.0,
				"charge": (held as MeleeWeapon).slam_charge if held is MeleeWeapon and (held as MeleeWeapon).can_slam else -1.0,
				"key": Hud.key_for(keys[hand], cat.slot),
			})
			wants_crosshair = wants_crosshair or held.wants_crosshair()
		var slots := items.quick_slots(cat.player_id)
		for slot in 2:
			var stack: Array = slots[slot]
			quick.append({
				"id": stack[0] if not stack.is_empty() else "",
				"count": stack.size(),
				"key": Hud.key_for("quick_%d" % (slot + 1), cat.slot),
			})
	var display := Hud.element("Held", cat.slot) as HudWeaponDisplay
	if display != null:
		display.show_loadout(paws, quick)
	if UndergroundHub.is_safe(cat.global_position):
		wants_crosshair = false
	Hud.show_element("Crosshair", wants_crosshair, cat.slot)


## Owner's computer: reads trigger / quick-use / ADS / melee inputs for every local cat.
static func use_held_items(items: ItemManager, delta: float) -> void:
	if Game.instance == null:
		return
	for cat in Game.instance.local_cats():
		if not cat.reads_input() or not (cat.is_controlled or cat.is_gunner()) or cat.knocked_out or cat.is_downed():
			cat.aim.wants_aim = false
			continue
		var safe_zone := UndergroundHub.is_safe(cat.global_position)
		var allowed := _can_use_items(cat)
		for slot in 2:
			if allowed and Seats.is_just_pressed(cat.slot, "quick_%d" % (slot + 1)) and not items.quick_slots(cat.player_id)[slot].is_empty():
				items.request_quick_use.rpc_id(1, cat.player_id, slot)
		var right := items.held_item(cat, 0)
		var can_aim := right is Weapon and not right is MeleeWeapon and items.held_item(cat, 1) == null and not safe_zone
		cat.aim.wants_aim = can_aim and allowed and Seats.is_pressed(cat.slot, "use_left")
		var left := items.held_item(cat, 1)
		var left_is_bat := left is MeleeWeapon and (left as MeleeWeapon).throwable
		var right_is_bat := right is MeleeWeapon and (right as MeleeWeapon).throwable
		if allowed and not safe_zone and cat.melee != null and cat.is_controlled and (left_is_bat or (right_is_bat and left == null)):
			if Seats.is_just_pressed(cat.slot, "use_left"):
				cat.melee.throw_next()
		for hand in 2:
			var held := items.held_item(cat, hand)
			if held == null or (safe_zone and held is Weapon):
				continue
			var action := "shoot" if hand == 0 else "use_left"
			var pressed := Seats.is_pressed(cat.slot, action)
			var just := Seats.is_just_pressed(cat.slot, action)
			if hand == 1 and left_is_bat:
				pressed = false
				just = false
			if hand == 1 and right == null:
				pressed = pressed or Seats.is_pressed(cat.slot, "shoot")
				just = just or Seats.is_just_pressed(cat.slot, "shoot")
			held.use_tick(allowed and pressed, allowed and just, delta)
			if hand == 0 and held.data != null and held.data.hands == 2:
				held.alt_use_tick(allowed and Seats.is_pressed(cat.slot, "use_left"), allowed and Seats.is_just_pressed(cat.slot, "use_left"), delta)
	for cat in Game.instance.local_cats():
		if cat.reads_input() and cat.is_controlled and not cat.knocked_out and not cat.is_downed() and cat.melee != null:
			cat.melee.melee_tick(_can_use_items(cat) and not UndergroundHub.is_safe(cat.global_position),
				Seats.is_pressed(cat.slot, "melee"), Seats.is_just_pressed(cat.slot, "melee"), delta)


static func _can_use_items(cat: CatPlayer) -> bool:
	if cat._menu_open():
		return false
	var inventory := InventoryScreen.for_seat(cat.slot)
	if inventory != null and inventory.visible:
		return false
	if cat.slot == 0 and not Controls.using_pad:
		return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	return true


## The backpack as SLOTS, in order: [{"id", "count", "index"}], where "index" is the place in
## the item list of the stack's top item.
static func pack_stacks_of(items: ItemManager, pack: Array, stack_size: int) -> Array:
	var stacks: Array = []
	var open := {}
	for i in pack.size():
		var item_id: String = pack[i]
		if open.has(item_id):
			var stack: Dictionary = stacks[open[item_id]]
			stack.count += 1
			stack.index = i
			if stack.count >= stack_size:
				open.erase(item_id)
			continue
		stacks.append({"id": item_id, "count": 1, "index": i})
		if items.is_stackable(item_id) and stack_size > 1:
			open[item_id] = stacks.size() - 1
	return stacks


## Would one more of this item fit in this backpack item list?
static func pack_has_room_in(items: ItemManager, player_id: int, pack: Array, item_id: String) -> bool:
	var size := items.pack_stack_size_for(player_id)
	var stacks := pack_stacks_of(items, pack, size)
	if stacks.size() < items.pack_size_for(player_id):
		return true
	if items.is_stackable(item_id):
		for stack in stacks:
			if stack.id == item_id and stack.count < size:
				return true
	return false


## A spot on the ground a step in front of the cat (where dropped things land).
static func ground_in_front_of(items: ItemManager, cat: CatPlayer) -> Vector3:
	var spot := cat.global_position - cat.cat_model.global_basis.z * 0.8
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP, spot + Vector3.DOWN * 20.0)
	query.exclude = [cat.get_rid()]
	var hit := items.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else spot


## The floor straight below a spot (ignoring cats), or the spot itself if there's no floor.
static func ground_below(items: ItemManager, at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 20.0)
	query.collision_mask = 1
	var skip: Array[RID] = []
	for cat in items.players.get_children():
		skip.append((cat as CollisionObject3D).get_rid())
	query.exclude = skip
	var hit := items.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else at
