class_name ItemManager
extends Node3D
## THE ITEM SYSTEM. One of these lives in main.tscn as the "Items" node.
## It handles every item in the game the same way, so new items need no new plumbing:
##   - loads every item card (ItemData .tres) from res://items/
##   - places the LOOT TABLE (res://loot/city.tres: fish, sardines, the koi) in each city,
##     lying on the street, and makes it grow back (gear is BOUGHT in the sewers, see request_buy)
##   - buying from the shop down in the sewers (request_buy, prices on the item cards)
##   - pickups (E), drops (G), using up (catnip)
##   - each cat's PAWS (right + left; a 2-paw item takes both) and ONE BACKPACK (6 slots, more with
##     the BIGGER BACKPACK upgrade) that holds EVERYTHING else: fish and other loot, spare gear, scrap.
##     Full backpack = no more loot. Loot comes home in it (nothing is sold at the exit): sell it at
##     the Black Markitten (request_sell), bury it in the litterbox, or keep it for a quest.
##   - two QUICK USE slots per cat (keys 1 / 2, d-pad left / right): catnip and catdip go
##     there when picked up or bought (ItemData.quick_use), stacked, and are used with one press
##   - each player's STASH: safe lockers in the sewers, saved between games (player_profile.gd)
##   - shows held items in paws and the BACKPACK on every cat's back (models/cat_backpack.glb), on
##     every computer; its light strip shows how full it is
##   - Left Mouse uses the right-paw item, Right Mouse the left-paw item
##
## MULTIPLAYER: the HOST is the referee. Clients ask (request_pickup / request_drop_item /
## request_consume / ...); the host checks and then tells everyone the result. Everyone keeps
## a copy of "world" (items on the street) and "inventories" (paws + backpack per player).
## Players are PLAYER IDs (scripts/player_id.gd): every request_* says which player it's for
## (one computer can have several in split screen), and the host checks that player really
## belongs to the computer that asked (PlayerId.sender_owns).
##
## World item IDs: items placed when the city is built get IDs 0, 1, 2... in the same order
## on every computer. Items dropped later get IDs from 100000 up, chosen by the host.

## The one Items node (so items and cats can find it easily).
static var instance: ItemManager

const ITEMS_FOLDER: String = "res://items/"
const FIRST_DROPPED_ID: int = 100000
## Mixed into the city seed so item placement has its own random numbers.
const LOOT_SEED_SALT: int = 4242
## The backpack model every cat wears (tools/make_backpack_spec.py), and where it sits on the cat
## (CatModel space: between the shoulders, -Z is the nose). Its "PackAnchor" marker is where the
## inventory screen's callout line starts (scripts/ui/inventory_ui.gd).
const BACKPACK_MODEL := "res://models/cat_backpack.glb"
const BACKPACK_SPOT := Vector3(0, 0.37, 0.12)
## A cat can't grab an item more than this many metres above or below it (see _reach_distance).
const MAX_REACH_HEIGHT: float = 3.0

@export_group("Rules")
## BACKPACK slots: ONE backpack holds everything you aren't holding in your paws (fish, the koi,
## scrap, spare guns...). Every item takes one slot, except CONSUMABLES (catnip, catdip), which
## stack like in a QUICK USE slot (see pack_stacks_of). Upgrades add more (pack_size_for).
@export var pack_size: int = 6
## How many of the same item stack in one QUICK USE slot (3 = up to 3 catnip on key 1).
@export var quick_stack_size: int = 3
## Slots in each player's STASH (THE LITTERBOX) down in the sewers. Anything can go in it (gear,
## fish, scrap). What's in it never drops when you're knocked out, and is saved between games.
@export var stash_size: int = 9
## How close (metres) a cat must be to grab an item with E.
@export var interact_radius: float = 2.5
## How close (metres) you must be to see the floating label over a street item.
@export var item_tag_distance: float = 18.0

## The light strip on a cat's backpack: empty / some room / full.
@export var pack_light_empty: Color = Color(0.25, 0.95, 1.0)
@export var pack_light_half: Color = Color(1.0, 0.8, 0.25)
@export var pack_light_full: Color = Color(1.0, 0.25, 0.3)

@export_group("Placed in every city")
## What lies around every district: a list of "N of this item, here, grows back after S
## seconds" lines (scripts/items/loot_table.gd). Double-click it to edit the lines.
@export var loot_table: LootTable = preload("res://loot/city.tres")
## More players = loot grows back faster, so there's enough to go round: every player beyond
## the first makes it this much faster (0.15 = 15%; 8 players = about twice as fast).
@export var regrow_faster_per_player: float = 0.15

@onready var city: CityGenerator = $"../City"
@onready var players: Node3D = $"../Players"

## Item id -> ItemData, for every card in res://items/.
var catalog := {}
## World item ID -> {"item": item id, "pos": Vector3}. Items lying on the street.
var world := {}
## Player ID -> {"hands": [right, left], "pack": [item ids], "stash": [item ids],
##                "quick": [[ids in slot 1], [ids in slot 2]]}.
## "" = empty paw. A 2-paw item is stored in BOTH paws. "pack" is THE BACKPACK: loot AND spare gear.
## "stash" is the litterbox in the sewers (see request_to_stash / player_profile.gd).
## "quick" = the two QUICK USE slots: each a stack of the SAME item, e.g. ["catnip", "catnip"].
var inventories := {}

var _world_nodes := {}   # world item ID -> Node3D on the street
var _spawns: Array = []  # host: [{"item", "pos", "respawn", "back_at"}], index = world item ID
var _next_id: int = FIRST_DROPPED_ID
var _mart_spots_used := {}  # Meow-Mart loot spots already taken while building this city's loot
var _clock: float = 0.0
## Item id -> a spare copy of its scene's script, NOT in the world: quick-use items call its
## quick_use(cat) (so catnip's speed/duration still come from its own Inspector numbers).
var _quick_effects := {}


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	for effect in _quick_effects.values():
		effect.free()  # the spare quick-use scripts were never in the world
	_quick_effects.clear()


func _ready() -> void:
	add_to_group(Interactable.GROUP)  # E grabs the nearest press-E item (scripts/interactable.gd)
	_load_catalog()
	add_to_group(GameSystems.GROUP)  # late joiners / quitting players / new districts (game_systems.gd)
	city.generated.connect(_on_city_generated)


func _load_catalog() -> void:
	for file in DirAccess.get_files_at(ITEMS_FOLDER):
		file = file.trim_suffix(".remap")  # exported games rename resources
		if file.ends_with(".tres"):
			var data := load(ITEMS_FOLDER + file) as ItemData
			if data != null and not data.id.is_empty():
				catalog[data.id] = data
	print("[Items] Loaded %d item cards: %s" % [catalog.size(), ", ".join(catalog.keys())])


# --- Placing items when a city is built (same result on every computer) ---

func _on_city_generated(city_seed: int) -> void:
	# The old street goes, but things DROPPED in the sewers stay on the floor: they're the same
	# sewers in every district. (Dropped ids keep counting up, so these can't be given away twice.)
	for id in world.keys():
		if id < FIRST_DROPPED_ID or not UndergroundHub.is_in_hub(world[id].pos):
			_remove_world_local(id)
	_spawns.clear()
	_mart_spots_used.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(city_seed * 31 + LOOT_SEED_SALT)
	if loot_table != null:
		for line in loot_table.spawns:
			if line != null:
				_place_loot_line(line, rng)
	# MEOW-MART CLEARANCE (scripts/district_twist.gd): a prize right in front of the door.
	var twist := DistrictTwist.instance
	if DistrictTwist.is_clearance() and twist.clearance_prize_item != "" and catalog.has(twist.clearance_prize_item):
		add_spawn_point(twist.clearance_prize_item, city.meow_mart_position + city.meow_mart_outward * 3.0, 0.0)
	# Anything else that places things per city (the heist's manholes and payphones) goes now,
	# in a fixed order.
	get_tree().call_group("item_placers", "place_items", self, city_seed)


## One line of the loot table: "count" of an item, where the line says (loot_spawn.gd).
func _place_loot_line(line: LootSpawn, rng: RandomNumberGenerator) -> void:
	if not catalog.has(line.item_id):
		push_warning("[Items] Loot table: no item card called '%s' in res://items/" % line.item_id)
		return
	var door := city.meow_mart_position
	var count := line.count
	# THE MEOW-MART HEIST (scripts/interiors/meow_mart_interior.gd): the golden koi lives in the
	# tank in Meow-Mart's back room now, so the old "somewhere on a sidewalk" koi isn't placed.
	if line.where == LootSpawn.Where.SIDEWALK and MeowMartInterior.koi_in_tank(line.item_id):
		return
	if line.where == LootSpawn.Where.OUTSIDE_MEOW_MART and line.item_id == "fish" and DistrictTwist.is_clearance():
		count *= DistrictTwist.instance.clearance_fish_multiplier  # CLEARANCE SALE: more fish (district_twist.gd)
	for i in count:
		var spot := Vector3.ZERO
		match line.where:
			LootSpawn.Where.OUTSIDE_MEOW_MART:
				# A row along the sidewalk outside the door, 1.3 m apart, centred on it. (More than a
				# row's worth, in a CLEARANCE: the extra rows line up further out in the street.)
				var row := i / line.count
				var in_row := i % line.count
				spot = door + Vector3((in_row - (line.count - 1) / 2.0) * 1.3, 0, -0.5) + city.meow_mart_outward * 1.3 * row
			LootSpawn.Where.FIXED_SPOT:
				spot = line.spot + Vector3(i * 0.8, 0, 0)
			LootSpawn.Where.MEOW_MART_SHELF, LootSpawn.Where.MEOW_MART_COUNTER:
				# Inside Meow-Mart: a free spot from the store's own list (the store is the same in
				# every district, the loot's random numbers pick which spots get something).
				var free := _free_mart_spots(line.where)
				if free.is_empty():
					push_warning("[Items] Meow-Mart has no free spot left for '%s'" % line.item_id)
					return
				spot = free[rng.randi_range(0, free.size() - 1)]
				_mart_spots_used[spot] = true
			_:  # SIDEWALK
				spot = random_sidewalk_spot(rng)
				for attempt in 20:  # far enough from Meow-Mart? (a few tries, then take what we got)
					if spot.distance_to(door) >= line.min_distance_from_meow_mart:
						break
					spot = random_sidewalk_spot(rng)
		add_spawn_point(line.item_id, spot, line.respawn_seconds)


## The Meow-Mart loot spots (shelves or seafood counter) nothing has been put on yet this city.
func _free_mart_spots(where: LootSpawn.Where) -> Array[Vector3]:
	var free: Array[Vector3] = []
	if MeowMartInterior.instance == null:
		return free
	var counter := where == LootSpawn.Where.MEOW_MART_COUNTER
	for spot in MeowMartInterior.instance.loot_spots(counter):
		if not _mart_spots_used.has(spot):
			free.append(spot)
	return free


## Put an item on the street. respawn_seconds > 0 = it grows back that long after it's taken.
## Call this only while a city is being built (from place_items), so IDs match everywhere.
func add_spawn_point(item_id: String, at: Vector3, respawn_seconds: float) -> void:
	var id := _spawns.size()
	_spawns.append({"item": item_id, "pos": at, "respawn": respawn_seconds, "back_at": -1.0})
	_add_world_local(id, item_id, at)


## A random spot on a sidewalk, along the street edge of a random block.
func random_sidewalk_spot(rng: RandomNumberGenerator) -> Vector3:
	var pitch := city.block_size + city.street_width
	var blocks := city.blocks_per_side
	var block_center := Vector3(
		(rng.randi_range(0, blocks - 1) + 0.5 - blocks / 2.0) * pitch, 0,
		(rng.randi_range(0, blocks - 1) + 0.5 - blocks / 2.0) * pitch)
	var outward: Vector3 = [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK][rng.randi_range(0, 3)]
	var along := Vector3(outward.z, 0, outward.x)
	return block_center + outward * (city.block_size * 0.5 - 0.5) + along * rng.randf_range(-9.0, 9.0)


# --- Items lying on the street ---

func _add_world_local(id: int, item_id: String, at: Vector3) -> void:
	var data: ItemData = catalog.get(item_id)
	if data == null:
		push_warning("[Items] No item card with id '%s' in %s" % [item_id, ITEMS_FOLDER])
		return
	_remove_world_local(id)
	world[id] = {"item": item_id, "pos": at}
	var spot := Node3D.new()
	spot.position = at
	add_child(spot)
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
	spot.add_child(_make_item_tag(data))
	_world_nodes[id] = spot


## The floating label over a street item. It's only a MARKER: the HUD draws the real, sharp text
## (scripts/ui/hud_name_tags.gd reads the Text, Modulate and metadata set here).
func _make_item_tag(data: ItemData) -> Label3D:
	var tag := Label3D.new()
	tag.add_to_group(HudNameTags.GROUP)
	tag.text = data.display_name
	tag.transparency = 1.0  # see-through from its first frame, before the HUD has noticed it
	tag.position.y = 1.25
	tag.set_meta("max_distance", item_tag_distance)
	if data.kind == ItemData.Kind.LOOT:
		# Loot: its glow colour (gold koi, cyan scrap) or warm white.
		tag.modulate = data.glow_color.lightened(0.25) if data.glow_color.a > 0.0 else Color(0.95, 0.95, 1.0)
	else:
		# Gear: plain white. The button is on the HUD prompt ("[E] PICKUP", interact_prompt).
		tag.modulate = Color(1, 1, 1, 0.9)
	return tag


func _remove_world_local(id: int) -> void:
	world.erase(id)
	if _world_nodes.has(id):
		_world_nodes[id].queue_free()
		_world_nodes.erase(id)


@rpc("authority", "call_local", "reliable")
func _add_world(id: int, item_id: String, at: Vector3) -> void:
	_add_world_local(id, item_id, at)


@rpc("authority", "call_local", "reliable")
func _remove_world(id: int) -> void:
	_remove_world_local(id)


@rpc("authority", "call_local", "reliable")
func _set_inventory(player_id: int, inventory: Dictionary) -> void:
	inventories[player_id] = inventory


# --- Every frame ---

func _process(delta: float) -> void:
	_clock += delta
	# Items on the street spin and bob so they look like loot.
	for id in _world_nodes:
		var model: Node3D = _world_nodes[id].get_node("Model")
		model.rotation.y += delta * 1.5
		model.position.y = 0.45 + sin(_clock * 3.0 + id) * 0.08
	for node in players.get_children():
		_sync_cat_visuals(node as CatPlayer)
	_update_hud()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_host_tick()
	_use_held_items(delta)


## Host only: grow items back.
func _host_tick() -> void:
	for i in _spawns.size():
		var spawn: Dictionary = _spawns[i]
		if spawn.back_at >= 0.0 and _clock >= spawn.back_at:
			spawn.back_at = -1.0
			_add_world.rpc(i, spawn.item, spawn.pos)


## The owner's computer: press the use buttons for whatever is in our cats' paws
## (every player on this computer, each with their own buttons: scripts/seats.gd).
func _use_held_items(delta: float) -> void:
	if Game.instance == null:
		return
	for cat in Game.instance.local_cats():
		# (Walking, or a GUNNER in a car's passenger seat: scripts/cat/cat_ride.gd. Drivers keep their
		# paws on the wheel.)
		if not cat.reads_input() or not (cat.is_controlled or cat.is_gunner()) or cat.knocked_out or cat.is_downed():
			cat.aim.wants_aim = false  # (no aiming down sights either)
			continue  # (downed cats can't shoot or sniff catnip: they can only crawl and meow)
		var safe_zone := UndergroundHub.is_safe(cat.global_position)  # (a SEWER BREACH: fight!)
		var allowed := _can_use_items(cat)
		# QUICK USE keys (1 / 2, d-pad left / right): the host takes one out and we use it.
		for slot in 2:
			if allowed and Seats.is_just_pressed(cat.slot, "quick_%d" % (slot + 1)) and not quick_slots(cat.player_id)[slot].is_empty():
				request_quick_use.rpc_id(1, cat.player_id, slot)
		# AIM DOWN SIGHTS (scripts/cat/cat_aim.gd): a gun in the right paw (or a two-paw gun) and
		# NOTHING in the left paw = the left-paw button (right mouse / LT) aims instead.
		var right := held_item(cat, 0)
		var can_aim := right is Weapon and not right is MeleeWeapon and held_item(cat, 1) == null and not safe_zone
		cat.aim.wants_aim = can_aim and allowed and Seats.is_pressed(cat.slot, "use_left")
		for hand in 2:
			var held := held_item(cat, hand)
			if held == null or (safe_zone and held is Weapon):
				continue  # the hub is a safe zone: guns don't fire down there (catnip still works)
			var action := "shoot" if hand == 0 else "use_left"
			var pressed := Seats.is_pressed(cat.slot, action)
			var just := Seats.is_just_pressed(cat.slot, action)
			if hand == 1 and right == null:
				# Nothing in the right paw (e.g. just the OFFHAND bat): Left Mouse / RT uses the left paw too.
				pressed = pressed or Seats.is_pressed(cat.slot, "shoot")
				just = just or Seats.is_just_pressed(cat.slot, "shoot")
			held.use_tick(allowed and pressed, allowed and just, delta)
	# The MELEE button (F / RB): throw the offhand bat, or SCRATCH with bare claws (scripts/cat/cat_melee.gd).
	for cat in Game.instance.local_cats():
		if cat.reads_input() and cat.is_controlled and not cat.knocked_out and not cat.is_downed() and cat.melee != null:
			cat.melee.melee_tick(_can_use_items(cat) and not UndergroundHub.is_safe(cat.global_position),
				Seats.is_pressed(cat.slot, "melee"), Seats.is_just_pressed(cat.slot, "melee"), delta)


## May this cat's player use their paws right now? Not while a menu or talk box is open, or
## their own inventory. Player 1 on the mouse: only while the game has the mouse (not while
## clicking a menu).
func _can_use_items(cat: CatPlayer) -> bool:
	if cat._menu_open():
		return false
	var inventory := InventoryScreen.for_seat(cat.slot)
	if inventory != null and inventory.visible:
		return false
	if cat.slot == 0 and not Controls.using_pad:
		return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	return true


# --- Host decisions ---

## Can this player take one more of this item? Loot needs a free BACKPACK slot (full = you can't
## pick it up: make room first). Held items always fit: paws, then the backpack, else whatever is
## in the paws gets dropped to make room.
func _can_take(player_id: int, data: ItemData) -> bool:
	if data.kind == ItemData.Kind.LOOT:
		return pack_free(player_id) > 0
	return true


## Host: give the item lying at world ID to a player.
func _give(player_id: int, world_id: int) -> void:
	Sound.play_everywhere("pickup", world[world_id].pos, -4.0)
	# Big prizes (the golden koi) make the city angrier and tell everyone who took it.
	var data: ItemData = catalog[world[world_id].item]
	if data.heat_on_pickup > 0.0 and not UndergroundHub.is_in_hub(world[world_id].pos):
		HeatMeter.instance.add_heat(data.heat_on_pickup)
	if data.pickup_announcement != "":
		var cat := _cat(player_id)
		var who: String = cat.player_name if cat != null and cat.player_name != "" else "SOMEONE"
		_announce.rpc(data.pickup_announcement % who)
	Events.item_picked_up.emit(player_id, world[world_id].item)  # host only (scripts/events.gd)
	_put_in_inventory(player_id, world[world_id].item, world[world_id].pos)
	_remove_world.rpc(world_id)
	if world_id < _spawns.size() and _spawns[world_id].respawn > 0.0:
		var crowd := 1.0 + regrow_faster_per_player * maxi(Game.instance.player_count() - 1, 0)
		_spawns[world_id].back_at = _clock + _spawns[world_id].respawn / crowd


## Host: put an item into a player's paws, quick-use slot or backpack and tell everyone.
## If every paw and backpack slot is full, whatever is in the way is dropped at the cat's
## feet (or at "fallback_spot" if the cat can't be found).
func _put_in_inventory(player_id: int, item_id: String, fallback_spot: Vector3) -> void:
	var data: ItemData = catalog[item_id]
	var inventory := get_inventory(player_id).duplicate(true)
	var cat := _cat(player_id)
	var drop_at: Vector3 = cat.global_position if cat != null else fallback_spot

	if data.kind == ItemData.Kind.LOOT:
		inventory.pack.append(item_id)                      # loot: into the backpack
	elif data.quick_use and _add_to_quick(inventory, item_id, quick_stack_size_for(player_id)):
		pass                                                # catnip etc.: into a QUICK USE slot
	elif data.quick_use and pack_has_room_in(player_id, inventory.pack, item_id):
		inventory.pack.append(item_id)                      # quick slots full: stack it in the backpack
	else:
		var hands: Array = inventory.hands
		var pack: Array = inventory.pack
		if data.hands == 2 and _held_ids(hands).is_empty():
			hands = [item_id, item_id]                      # free paws: hold it
		elif data.hands == 1 and not _is_two_handed(hands) and "" in hands:
			hands[_free_paw_for(data, hands)] = item_id     # a free paw: hold it (the bat: LEFT first)
		elif pack_has_room_in(player_id, pack, item_id):
			pack.append(item_id)                            # paws busy: into the backpack
		elif data.hands == 2:
			for old in _held_ids(hands):                    # everything full: swap
				_spawn_dropped(old, drop_at)
			hands = [item_id, item_id]
		else:
			if _is_two_handed(hands):
				_spawn_dropped(hands[0], drop_at)
				hands = ["", ""]
			if hands[0] != "":
				_spawn_dropped(hands[0], drop_at)
			hands[0] = item_id
		inventory.hands = hands
		inventory.pack = pack
	_set_inventory.rpc(player_id, inventory)


## Put one quick-use item into a QUICK USE slot of this inventory (changes it): on top of a
## stack of the same item with room, else into an empty slot. False = both slots are taken.
func _add_to_quick(inventory: Dictionary, item_id: String, stack_size: int = -1) -> bool:
	if stack_size < 0:
		stack_size = quick_stack_size
	var quick := quick_slots_of(inventory)
	for slot in quick:
		if not slot.is_empty() and slot[0] == item_id and slot.size() < stack_size:
			slot.append(item_id)
			inventory.quick = quick
			return true
	for slot in quick:
		if slot.is_empty():
			slot.append(item_id)
			inventory.quick = quick
			return true
	return false


## Which free paw a 1-paw item goes in (hands has at least one ""): the RIGHT one, except an
## OFFHAND item (the bat), which takes the LEFT paw when it's free.
func _free_paw_for(data: ItemData, hands: Array) -> int:
	if data.offhand and hands[1] == "":
		return 1
	return hands.find("")


## THROW (the MELEE button with a Throwable weapon in the LEFT paw, scripts/cat/cat_melee.gd): the
## item leaves the paw now, and lands on the street at "land" after "delay" seconds (when the
## spinning bat gets there). Host only.
@rpc("any_peer", "call_local", "reliable")
func request_throw(player_id: int, hand: int, land: Vector3, delay: float) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var cat := _cat(player_id)
	if cat == null or Game.instance.car_of(player_id) != null:
		return
	var inventory := get_inventory(player_id).duplicate(true)
	hand = clampi(hand, 0, 1)
	var item_id: String = inventory.hands[hand]
	if item_id == "" or _is_two_handed(inventory.hands):
		return
	if Motion.flat_distance(land, cat.global_position) > 40.0:
		land = cat.global_position  # no throwing things across the map
	inventory.hands[hand] = ""
	_set_inventory.rpc(player_id, inventory)
	get_tree().create_timer(clampf(delay, 0.0, 3.0)).timeout.connect(_spawn_dropped.bind(item_id, land))


## Host: put an item on the street with a brand-new world ID.
## dropper = the cat that dropped it (it won't auto-grab it back until it steps away).
func _spawn_dropped(item_id: String, at: Vector3) -> void:
	# Keep the height: a drop in the sewers stays in the sewers (it used to pop up in the city).
	_add_world.rpc(_next_id, item_id, at)
	_next_id += 1


## A player pressed E next to an item. Runs on the host only, which decides.
@rpc("any_peer", "call_local", "reliable")
func request_pickup(player_id: int, world_id: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id) or not world.has(world_id):
		return
	var cat := _cat(player_id)
	if cat == null or Game.instance.car_of(player_id) != null or CatHealth.instance.is_down(player_id):
		return
	if _reach_distance(cat.global_position, world[world_id].pos) <= interact_radius + 0.5 and _can_take(player_id, catalog[world[world_id].item]):
		_give(player_id, world_id)


## A player clicked "BUY" at a shop (scripts/npcs/shopkeeper.gd). Runs on the host only,
## which checks the price on the item card (never trusts the buyer), takes the cash
## (Wallet.spend) and puts the item in their paws/backpack, like picking it up.
## The buyer gets a "_buy_result" message back either way.
@rpc("any_peer", "call_local", "reliable")
func request_buy(player_id: int, item_id: String) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var data: ItemData = catalog.get(item_id)
	var cat := _cat(player_id)
	if data == null or data.price <= 0 or cat == null:
		return
	if not UndergroundHub.is_in_hub(cat.global_position):
		return  # the shop is down in the sewers: no buying from up top
	if not Upgrades.shop_allows(player_id, item_id):
		# WEAPON CRATES (scripts/upgrades.gd): this gun isn't unlocked for this cat yet.
		_buy_result.rpc_id(PlayerId.peer_of(player_id), player_id, false, "%s comes in crate %d. Unlock it first." % [data.display_name, Upgrades.crate_for(item_id)])
	elif not _can_take(player_id, data):
		_buy_result.rpc_id(PlayerId.peer_of(player_id), player_id, false, "No room for that, comrade.")
	elif not Wallet.instance.spend(player_id, data.price):
		_buy_result.rpc_id(PlayerId.peer_of(player_id), player_id, false, "%s costs $%d. Come back with more fish money." % [data.display_name, data.price])
	else:
		_put_in_inventory(player_id, item_id, cat.global_position)
		Events.item_picked_up.emit(player_id, item_id)  # host only (scripts/events.gd)
		print("[Items] Player %d bought %s for $%d" % [player_id, item_id, data.price])
		_buy_result.rpc_id(PlayerId.peer_of(player_id), player_id, true, "Bought %s for $%d." % [data.display_name, data.price])


## Host -> the buyer: how the purchase went (shown in the middle of the screen).
@rpc("authority", "call_local", "reliable")
func _buy_result(player_id: int, ok: bool, text: String) -> void:
	print("[Items] Shop says: %s" % text)
	Sound.play("buy" if ok else "error")
	var shop := ShopScreen.for_seat(PlayerId.slot_of(player_id))
	if shop != null and shop.visible:
		shop.note(text, ok)  # the shop screen's own message line
	else:
		Hud.show_message(text, 3.0, PlayerId.slot_of(player_id))  # the buyer's screen


# --- SELLING to THE BLACK MARKITTEN (scripts/ui/shop_screen.gd) ---

## What the shop pays THIS player for one of this item (the shop screen, the backpack badges and the
## host all use this, so they always agree):
##   street LOOT (fish, koi, treats...)  = 100% of its card's Cash Value, x the GOURMET FENCE upgrade
##   HELD gear (guns, catnip...)         = half its shop Price (at least $1)
##   SCRAP, ELECTRONICS (and anything else with no value) = 0: the shop won't take them (scrap pays for
##   upgrades at the workbench, electronics feed THE MAINFRAME)
func sell_price_for(player_id: int, item_id: String) -> int:
	var data: ItemData = catalog.get(item_id)
	if data == null or item_id == Mainframe.SCRAP_ID or item_id == Mainframe.FUEL_ID:
		return 0
	if data.kind == ItemData.Kind.LOOT:
		return roundi(data.cash_value * Upgrades.gourmet_multiplier(player_id)) if data.cash_value > 0 else 0
	return maxi(1, data.price / 2) if data.price > 0 else 0


## (Old name, same thing.)
func sell_price(player_id: int, item_id: String) -> int:
	return sell_price_for(player_id, item_id)


## What all the street LOOT in a player's backpack sells for right now (SELL ALL LOOT; gear and
## scrap don't count).
func pack_sell_value(player_id: int) -> int:
	var total := 0
	for item_id in loot_in_pack(player_id):
		total += sell_price_for(player_id, item_id)
	return total


## A player sells ONE thing to the shop: where = "pack" (backpack slot), "hand" (0 right / 1 left)
## or "quick" (one off that stack). Host only: checks the seller is down in the sewers and the shop
## buys it (sell_price_for > 0), takes it away and pays them (Wallet.earn).
@rpc("any_peer", "call_local", "reliable")
func request_sell(player_id: int, where: String, index: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var cat := _cat(player_id)
	if cat == null or not UndergroundHub.is_in_hub(cat.global_position):
		return  # the fence is down in the sewers
	var inventory := get_inventory(player_id).duplicate(true)
	var item_id := ""
	match where:
		"pack":
			if index >= 0 and index < inventory.pack.size():
				item_id = inventory.pack[index]
		"hand":
			item_id = inventory.hands[clampi(index, 0, 1)]
		"quick":
			var stack: Array = quick_slots_of(inventory)[clampi(index, 0, 1)]
			item_id = stack[0] if not stack.is_empty() else ""
	var price := sell_price_for(player_id, item_id)
	if item_id == "" or price <= 0:
		_buy_result.rpc_id(PlayerId.peer_of(player_id), player_id, false, "I don't buy that, comrade.")
		return
	match where:
		"pack":
			inventory.pack.remove_at(index)
		"hand":
			if _is_two_handed(inventory.hands):
				inventory.hands = ["", ""]
			else:
				inventory.hands[clampi(index, 0, 1)] = ""
		"quick":
			_pop_quick(inventory, index)
	_set_inventory.rpc(player_id, inventory)
	_paid_for(player_id, [item_id], price)


## SELL ALL LOOT: every piece of street loot in the backpack (fish, koi, treats...; scrap and gear
## stay). Host only, same checks as request_sell.
@rpc("any_peer", "call_local", "reliable")
func request_sell_all_loot(player_id: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var cat := _cat(player_id)
	if cat == null or not UndergroundHub.is_in_hub(cat.global_position):
		return
	var inventory := get_inventory(player_id).duplicate(true)
	var kept: Array = []
	var sold: Array = []
	var earned := 0
	for item_id in inventory.pack:
		var data: ItemData = catalog.get(item_id)
		var price := sell_price_for(player_id, item_id)
		if data != null and data.kind == ItemData.Kind.LOOT and price > 0:
			sold.append(item_id)
			earned += price
		else:
			kept.append(item_id)
	if sold.is_empty():
		_buy_result.rpc_id(PlayerId.peer_of(player_id), player_id, false, "No loot to sell, comrade.")
		return
	inventory.pack = kept
	_set_inventory.rpc(player_id, inventory)
	_paid_for(player_id, sold, earned)


## Host: pay a seller and tell them (and the RAID REPORT / anything else listening: Events.loot_sold).
func _paid_for(player_id: int, sold: Array, earned: int) -> void:
	Wallet.instance.earn(player_id, earned, "sold %s" % ", ".join(sold))
	Events.loot_sold.emit(player_id, sold, earned)  # (host only: scripts/events.gd)
	print("[Items] Player %d sold %s for $%d" % [player_id, sold, earned])
	var what: String = (catalog[sold[0]] as ItemData).display_name if sold.size() == 1 else "%d items" % sold.size()
	_sell_result.rpc_id(PlayerId.peer_of(player_id), player_id, "Sold %s for $%d." % [what, earned])


## Host -> the seller: the sale went through (cash sound; the shop screen shows the words, or the
## middle of their screen if it's closed).
@rpc("authority", "call_local", "reliable")
func _sell_result(player_id: int, text: String) -> void:
	Sound.play("buy")
	var shop := ShopScreen.for_seat(PlayerId.slot_of(player_id))
	if shop != null and shop.visible:
		shop.note("SOLD! " + text, true)
	else:
		Hud.show_message("SOLD! " + text, 3.0, PlayerId.slot_of(player_id))


## The holder used up the item in this paw (catnip). Host only.
@rpc("any_peer", "call_local", "reliable")
func request_consume(player_id: int, hand: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var inventory := get_inventory(player_id).duplicate(true)
	if _is_two_handed(inventory.hands):
		inventory.hands = ["", ""]
	else:
		inventory.hands[clampi(hand, 0, 1)] = ""
	_set_inventory.rpc(player_id, inventory)


## A player pressed a QUICK USE key (slot 0 = key 1, slot 1 = key 2). Host only: takes one out
## of that slot and tells the owner's computer to use it (_quick_used).
@rpc("any_peer", "call_local", "reliable")
func request_quick_use(player_id: int, slot: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id) or CatHealth.instance.is_down(player_id):
		return
	var inventory := get_inventory(player_id).duplicate(true)
	var item_id := _pop_quick(inventory, slot)
	if item_id == "":
		return
	_set_inventory.rpc(player_id, inventory)
	_quick_used.rpc_id(PlayerId.peer_of(player_id), player_id, item_id)


## Host -> the owner's computer: one quick-use item was taken out of a slot, so use it now.
@rpc("authority", "call_local", "reliable")
func _quick_used(player_id: int, item_id: String) -> void:
	var cat := _cat(player_id)
	var data: ItemData = catalog.get(item_id)
	if cat == null or data == null or not cat.is_multiplayer_authority():
		return
	if not _quick_effects.has(item_id):
		_quick_effects[item_id] = data.scene.instantiate()  # (kept out of the world, just for its script)
	var effect := _quick_effects[item_id] as HeldItem
	if effect != null:
		effect.quick_use(cat)
	print("[Items] Player %d quick-used %s" % [player_id, item_id])
	Sound.play_everywhere("quick_use", cat.global_position, -4.0)  # sounds/sfx/quick_use.wav (if there is one)


## Inventory screen: click a QUICK USE slot = put one of it back in the backpack. Host only.
@rpc("any_peer", "call_local", "reliable")
func request_quick_to_pack(player_id: int, slot: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var inventory := get_inventory(player_id).duplicate(true)
	var item_id := _pop_quick(inventory, slot)
	if item_id == "" or not pack_has_room_in(player_id, inventory.pack, item_id):
		return  # (nothing there, or no free slot / stack with room in the backpack)
	inventory.pack.append(item_id)
	_set_inventory.rpc(player_id, inventory)


## Inventory screen: take a backpack item into the paws. Whatever was in the way goes into
## the backpack (or drops if the backpack is full). Host only.
@rpc("any_peer", "call_local", "reliable")
func request_equip(player_id: int, pack_index: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var cat := _cat(player_id)
	var inventory := get_inventory(player_id).duplicate(true)
	var pack: Array = inventory.pack
	if cat == null or pack_index < 0 or pack_index >= pack.size():
		return
	var item_id: String = pack.pop_at(pack_index)
	var data: ItemData = catalog[item_id]
	if data.quick_use and _add_to_quick(inventory, item_id, quick_stack_size_for(player_id)):
		inventory.pack = pack
		_set_inventory.rpc(player_id, inventory)  # catnip etc. go to a QUICK USE slot, not the paws
		return
	var hands: Array = inventory.hands
	var put_away: Array = []
	if data.hands == 2 or _is_two_handed(hands):
		put_away = _held_ids(hands)
		hands = ["", ""]
	if data.hands == 2:
		hands = [item_id, item_id]
	elif "" in hands:
		hands[_free_paw_for(data, hands)] = item_id
	elif data.offhand:
		put_away.append(hands[1])  # both paws full: an OFFHAND item swaps out the left-paw one
		hands[1] = item_id
	else:
		put_away.append(hands[0])  # both paws full: the right-paw item goes in the backpack
		hands[0] = item_id
	for old in put_away:
		if pack_has_room_in(player_id, pack, old):
			pack.insert(mini(pack_index, pack.size()), old)
		else:
			_spawn_dropped(old, cat.global_position)
	inventory.hands = hands
	inventory.pack = pack
	_set_inventory.rpc(player_id, inventory)


## Inventory screen: put the item in this paw (0 = right, 1 = left) into the backpack. Host only.
@rpc("any_peer", "call_local", "reliable")
func request_put_away(player_id: int, hand: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var inventory := get_inventory(player_id).duplicate(true)
	var hands: Array = inventory.hands
	var item_id: String = hands[clampi(hand, 0, 1)]
	if item_id == "" or not pack_has_room_in(player_id, inventory.pack, item_id):
		return
	if _is_two_handed(hands):
		hands = ["", ""]
	else:
		hands[clampi(hand, 0, 1)] = ""
	inventory.hands = hands
	inventory.pack.append(item_id)
	_set_inventory.rpc(player_id, inventory)


## Drop one item on the ground in front of the cat (G key, or right-click in the inventory).
## where = "hand" (index 0 right / 1 left), "pack" (index = backpack slot) or "quick". Host only.
@rpc("any_peer", "call_local", "reliable")
func request_drop_item(player_id: int, where: String, index: int, ground: Vector3) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var cat := _cat(player_id)
	if cat == null or Game.instance.car_of(player_id) != null:
		return
	if ground.distance_to(cat.global_position) > 3.0:
		ground = cat.global_position  # no dropping things across the map
	var inventory := get_inventory(player_id).duplicate(true)
	var item_id := ""
	if where == "hand":
		item_id = inventory.hands[clampi(index, 0, 1)]
		if _is_two_handed(inventory.hands):
			inventory.hands = ["", ""]
		else:
			inventory.hands[clampi(index, 0, 1)] = ""
	elif where == "pack" and index >= 0 and index < inventory.pack.size():
		item_id = inventory.pack.pop_at(index)
	elif where == "quick":
		item_id = _pop_quick(inventory, index)  # one off the top of that stack
	if item_id == "":
		return
	_spawn_dropped(item_id, ground)
	_set_inventory.rpc(player_id, inventory)


## Host: take every piece of LOOT (fish, koi, scrap...) out of a player's backpack and return it.
## Their gear stays. (A rival ROBBING a downed cat: steal_loot.)
func take_all_loot(player_id: int) -> Array:
	var inventory := get_inventory(player_id).duplicate(true)
	var loot: Array = []
	var kept: Array = []
	for item_id in inventory.pack:
		if (catalog[item_id] as ItemData).kind == ItemData.Kind.LOOT:
			loot.append(item_id)
		else:
			kept.append(item_id)
	if loot.is_empty():
		return []
	inventory.pack = kept
	_set_inventory.rpc(player_id, inventory)
	return loot


## The LOOT (not gear) in a player's backpack, in the order it was picked up.
func loot_in_pack(player_id: int) -> Array:
	return get_inventory(player_id).pack.filter(func(item_id): return catalog.has(item_id) and (catalog[item_id] as ItemData).kind == ItemData.Kind.LOOT)


## What the loot in a player's backpack is worth (the cards' Cash Value, no upgrades): the
## heist reports this when they extract (the loot itself stays in the backpack).
func loot_value(player_id: int) -> int:
	var total := 0
	for item_id in loot_in_pack(player_id):
		total += (catalog[item_id] as ItemData).cash_value
	return total


## --- Per-player sizes (SEWER UPGRADES, scripts/upgrades.gd) ---
## The numbers in the Inspector above (Pack Size, Stash Size...) are the BASE sizes; a cat's
## upgrades add to them. Always ask these instead of reading pack_size etc. directly.

## (Old name from when loot had its own bag: it's all the backpack now.)
func bag_size_for(player_id: int) -> int:
	return pack_size_for(player_id)


## How many backpack slots are free right now.
func pack_free(player_id: int) -> int:
	return pack_size_for(player_id) - pack_slots_used(player_id, get_inventory(player_id).pack)


## Backpack slots: 6, +2 per BIGGER BACKPACK tier (6 -> 8 -> 10 -> 12).
func pack_size_for(player_id: int) -> int:
	var per_tier: int = Upgrades.instance.pack_slots_per_tier if Upgrades.instance != null else 2
	return pack_size + per_tier * Upgrades.level(player_id, "bigger_pack")


## Litterbox (stash) slots: 9, +6 per DELUXE LITTERBOX tier (the Tinker Workbench).
func stash_size_for(player_id: int) -> int:
	var per_tier: int = Upgrades.instance.stash_slots_per_tier if Upgrades.instance != null else 6
	return stash_size + per_tier * Upgrades.level(player_id, "deluxe_litterbox")


## How many snacks stack in one QUICK USE slot: 3, +1 per STUFFED CHEEKS tier.
func quick_stack_size_for(player_id: int) -> int:
	return quick_stack_size + Upgrades.level(player_id, "stuffed_cheeks")


## --- CONSUMABLES STACK IN THE BACKPACK TOO ---
## Catnip, catdip (any item card with "Quick Use" ticked) stack in the backpack the same way they
## do in a QUICK USE slot: up to quick_stack_size_for(player) of the same one share ONE backpack
## slot. Everything else still takes a slot each.
## The backpack is still stored as a plain list of item ids (one entry per item, so counting,
## selling, robbing and saving all work as before); these helpers work out how those items fill
## the slots. ALWAYS check room with pack_has_room / pack_slots_used, never pack.size().

## Does this item stack in the backpack? (= a consumable: ItemData.quick_use)
func is_stackable(item_id: String) -> bool:
	return catalog.has(item_id) and (catalog[item_id] as ItemData).quick_use


## How many of one consumable share a backpack slot (the same as a QUICK USE slot).
func pack_stack_size_for(player_id: int) -> int:
	return maxi(1, quick_stack_size_for(player_id))


## The backpack as SLOTS, in order: [{"id", "count", "index"}], where "index" is the place in
## the item list of the stack's top item (what the inventory screen sends when you click it).
## A consumable joins the first stack of the same item that has room, else starts a new slot.
func pack_stacks_of(pack: Array, stack_size: int) -> Array:
	var stacks: Array = []
	var open := {}  # item id -> the stacks entry of that item that still has room
	for i in pack.size():
		var item_id: String = pack[i]
		if open.has(item_id):
			var stack: Dictionary = stacks[open[item_id]]
			stack.count += 1
			stack.index = i
			if stack.count >= stack_size:
				open.erase(item_id)  # full: the next one starts a new slot
			continue
		stacks.append({"id": item_id, "count": 1, "index": i})
		if is_stackable(item_id) and stack_size > 1:
			open[item_id] = stacks.size() - 1
	return stacks


## A player's backpack as slots (see pack_stacks_of).
func pack_stacks(player_id: int) -> Array:
	return pack_stacks_of(get_inventory(player_id).pack, pack_stack_size_for(player_id))


## How many backpack SLOTS this item list fills for this player (stacks count once).
func pack_slots_used(player_id: int, pack: Array) -> int:
	return pack_stacks_of(pack, pack_stack_size_for(player_id)).size()


## Would one more of this item fit in this backpack item list? (A free slot, or for a consumable
## a stack of the same one with room.)
func pack_has_room_in(player_id: int, pack: Array, item_id: String) -> bool:
	var size := pack_stack_size_for(player_id)
	var stacks := pack_stacks_of(pack, size)
	if stacks.size() < pack_size_for(player_id):
		return true
	if is_stackable(item_id):
		for stack in stacks:
			if stack.id == item_id and stack.count < size:
				return true
	return false


## Would one more of this item fit in this player's backpack right now?
func pack_has_room(player_id: int, item_id: String) -> bool:
	return pack_has_room_in(player_id, get_inventory(player_id).pack, item_id)


## --- SCRAP as money for upgrades ---

## All the SCRAP a player owns right now: in their backpack AND in their litterbox (stash).
func scrap_count_of(player_id: int) -> int:
	var inventory := get_inventory(player_id)
	return inventory.pack.count(Mainframe.SCRAP_ID) + (inventory.get("stash", []) as Array).count(Mainframe.SCRAP_ID)


## Host: take "count" SCRAP from a player, from the backpack first, then the litterbox.
## False (and nothing taken) if they don't have that much in total.
func spend_scrap(player_id: int, count: int) -> bool:
	if not multiplayer.is_server() or scrap_count_of(player_id) < count:
		return false
	if count <= 0:
		return true
	var inventory := get_inventory(player_id).duplicate(true)
	var bag: Array = inventory.pack
	var stash: Array = inventory.get("stash", [])
	var left := count
	while left > 0 and bag.has(Mainframe.SCRAP_ID):
		bag.remove_at(bag.rfind(Mainframe.SCRAP_ID))
		left -= 1
	while left > 0 and stash.has(Mainframe.SCRAP_ID):
		stash.remove_at(stash.rfind(Mainframe.SCRAP_ID))
		left -= 1
	inventory.pack = bag
	inventory.stash = stash
	_set_inventory.rpc(player_id, inventory)
	return true


## How many of this item are in a player's backpack (e.g. electronics for THE MAINFRAME, fish for a quest).
func count_in_bag(player_id: int, item_id: String) -> int:
	return get_inventory(player_id).pack.count(item_id)


## Host: take ONE of this item out of a player's backpack. False = they had none.
## (THE MAINFRAME calls this when electronics are fed in: scripts/mainframe.gd.)
func take_from_bag(player_id: int, item_id: String) -> bool:
	var inventory := get_inventory(player_id).duplicate(true)
	var bag: Array = inventory.pack
	var index := bag.rfind(item_id)
	if index < 0:
		return false
	bag.remove_at(index)
	_set_inventory.rpc(player_id, inventory)
	return true


## Host: a rival ROBS a downed cat (cat_health.gd): the LOOT in the victim's backpack goes into
## the robber's, as far as it fits; the rest drops on the street next to the victim. (Their gear
## stays.) Returns how many pieces the robber got.
func steal_bag(victim_id: int, robber_id: int) -> int:
	var victim := _cat(victim_id)
	var at: Vector3 = victim.global_position if victim != null else Vector3.ZERO
	var taken := 0
	var loot := take_all_loot(victim_id)
	for i in loot.size():
		var data: ItemData = catalog[loot[i]]
		if _can_take(robber_id, data):
			_put_in_inventory(robber_id, loot[i], at)
			taken += 1
		else:
			_spawn_dropped(loot[i], _ground_below(at) + Vector3(cos(i * 1.3), 0, sin(i * 1.3)) * 0.8)
	if taken > 0:
		Events.item_picked_up.emit(robber_id, loot[0])  # (host only: scripts/events.gd)
	return taken


## Host: take ONE piece of loot (the last one picked up) out of a player's backpack (never gear).
## Returns its item id, or "" if there was no loot. (A Roomba bonk calls this.)
func take_one_loot(player_id: int) -> String:
	var inventory := get_inventory(player_id).duplicate(true)
	var bag: Array = inventory.pack
	var index := -1
	for i in range(bag.size() - 1, -1, -1):
		if (catalog[bag[i]] as ItemData).kind == ItemData.Kind.LOOT:
			index = i
			break
	if index < 0:
		return ""
	var item_id: String = bag.pop_at(index)
	_set_inventory.rpc(player_id, inventory)
	Events.loot_vacuumed.emit(player_id, item_id)  # (scripts/events.gd: the RAID REPORT's BUTTERPAWS)
	return item_id


## Host: put an item on the street for anyone to grab (e.g. what a smashed Roomba spits out).
func drop_on_street(item_id: String, at: Vector3) -> void:
	_spawn_dropped(item_id, at)


## Host: empty a player's paws, quick-use slots and backpack onto the ground around "at"
## (a knocked-out cat, see cat_health.gd, or a player who quit). The STASH is safe: it stays.
func drop_everything(player_id: int, at: Vector3) -> void:
	var inventory := get_inventory(player_id).duplicate(true)
	var dropped := _held_ids(inventory.hands) + Array(inventory.pack)
	for stack in quick_slots_of(inventory):
		dropped += Array(stack)
	var ground := _ground_below(at)  # a bonked cat may still be flying through the air
	for i in dropped.size():
		_spawn_dropped(dropped[i], ground + Vector3(cos(i * 1.3), 0, sin(i * 1.3)) * 0.8)
	if not dropped.is_empty():
		inventory.hands = ["", ""]
		inventory.pack = []
		inventory.quick = [[], []]
		_set_inventory.rpc(player_id, inventory)


# --- The stash: safe lockers in the sewers (host decides, like everything else) ---

## Inventory screen at the litterbox: put the item in this paw ("hand", 0 right / 1 left),
## backpack slot ("pack") or quick slot ("quick") into the stash. Anything can go in (fish too).
## Only while standing at the litterbox. Host only.
@rpc("any_peer", "call_local", "reliable")
func request_to_stash(player_id: int, where: String, index: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var cat := _cat(player_id)
	var inventory := get_inventory(player_id).duplicate(true)
	var stash: Array = inventory.get("stash", [])
	if cat == null or not UndergroundHub.of(cat).near_stash(cat) or stash.size() >= stash_size_for(player_id):
		return
	var item_id := ""
	if where == "hand":
		item_id = inventory.hands[clampi(index, 0, 1)]
		if _is_two_handed(inventory.hands):
			inventory.hands = ["", ""]
		else:
			inventory.hands[clampi(index, 0, 1)] = ""
	elif where == "pack" and index >= 0 and index < inventory.pack.size():
		item_id = inventory.pack.pop_at(index)
	elif where == "quick":
		item_id = _pop_quick(inventory, index)
	if item_id == "":
		return
	stash.append(item_id)
	inventory.stash = stash
	_set_inventory.rpc(player_id, inventory)


## Inventory screen at the litterbox: take stash slot "index" out, into the backpack. Host only.
@rpc("any_peer", "call_local", "reliable")
func request_from_stash(player_id: int, index: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var cat := _cat(player_id)
	var inventory := get_inventory(player_id).duplicate(true)
	var stash: Array = inventory.get("stash", [])
	if cat == null or not UndergroundHub.of(cat).near_stash(cat) or index < 0 or index >= stash.size():
		return
	if not pack_has_room_in(player_id, inventory.pack, stash[index]):
		return  # backpack full (the screen tells the player)
	inventory.pack.append(stash.pop_at(index))
	inventory.stash = stash
	_set_inventory.rpc(player_id, inventory)


## May this item go in the stash? Anything with an item card can (gear, fish, the koi, scrap).
## (player_profile.gd checks saves with this.)
func is_stashable(item_id: String) -> bool:
	return catalog.has(item_id)


## Host: replace a player's whole stash (their saved one, when they start a game —
## see player_profile.gd). The caller has already checked the item ids.
func set_stash(player_id: int, stash: Array) -> void:
	var inventory := get_inventory(player_id).duplicate(true)
	inventory.stash = stash
	_set_inventory.rpc(player_id, inventory)


## Host: a player quit. Everything they carried drops where they stood.
func player_left(player_id: int, last_position: Vector3) -> void:
	drop_everything(player_id, last_position)
	_forget_player.rpc(player_id)


@rpc("authority", "call_local", "reliable")
func _forget_player(player_id: int) -> void:
	inventories.erase(player_id)


## Host -> a computer that just joined (network ID "peer"): every item on the street and in
## everyone's paws/backpacks. (Sent right after the city seed, so the city's items already exist; Items
## sits above the other systems in main.tscn so it goes first.)
func send_state_to(peer: int) -> void:
	_receive_state.rpc_id(peer, world, inventories)


@rpc("authority", "call_remote", "reliable")
func _receive_state(world_now: Dictionary, inventories_now: Dictionary) -> void:
	for id in world.keys():
		if not world_now.has(id):
			_remove_world_local(id)
	for id in world_now:
		if not world.has(id):
			_add_world_local(id, world_now[id].item, world_now[id].pos)
	inventories = inventories_now


# --- Things cats call ---

# The E key (scripts/interactable.gd): the street items are all one "interactable" - this node.

func interact_distance(cat: CatPlayer) -> float:
	var best_id := _nearest_item(cat)
	return _reach_distance(cat.global_position, world[best_id].pos) if best_id >= 0 else -1.0


func interact_prompt(_cat: CatPlayer) -> String:
	return "PICKUP"


## E pressed: ask the host for the nearest item in reach.
func interact(cat: CatPlayer) -> void:
	var best_id := _nearest_item(cat)
	if best_id >= 0:
		request_pickup.rpc_id(1, cat.player_id, best_id)


## A street item right by you comes before anything else (E near an item and the car = item).
func interact_priority() -> int:
	return 30


## The world ID of the nearest item this cat could take right now, or -1. Not from inside a car,
## and loot doesn't count with a full backpack: otherwise E would do nothing there (and a fish on the
## road would steal the E meant for getting in or out of the car).
func _nearest_item(cat: CatPlayer) -> int:
	if Game.instance.car_of(cat.player_id) != null:
		return -1
	var best_id := -1
	var best_distance := interact_radius
	for id in world:
		var data: ItemData = catalog[world[id].item]
		var distance := _reach_distance(cat.global_position, world[id].pos)
		if distance < best_distance and _can_take(cat.player_id, data):
			best_id = id
			best_distance = distance
	return best_id


## G pressed: drop what's in the paws (right paw first, or the 2-paw item) a step in front
## of the cat, on the ground.
func drop_from(cat: CatPlayer) -> void:
	var hands: Array = get_inventory(cat.player_id).hands
	if _held_ids(hands).is_empty():
		return
	request_drop_item.rpc_id(1, cat.player_id, "hand", 0 if hands[0] != "" else 1, ground_in_front_of(cat))


# --- Showing items on cats (every computer) ---

func _sync_cat_visuals(cat: CatPlayer) -> void:
	var inventory := get_inventory(cat.player_id)
	var hands_key := str(inventory.hands)
	if cat.get_meta("hands_key", "") != hands_key:
		cat.set_meta("hands_key", hands_key)
		_rebuild_paws(cat, inventory.hands)
	var used := pack_slots_used(cat.player_id, inventory.pack)  # (a stack of catnip = one slot)
	var pack_key := "%d/%d" % [used, pack_size_for(cat.player_id)]
	if cat.get_meta("pack_key", "") != pack_key or cat.cat_model.get_node_or_null("BackPack") == null:
		cat.set_meta("pack_key", pack_key)
		_update_backpack(cat, used, pack_size_for(cat.player_id))
	# Over-the-shoulder camera if anything held asks for it.
	var shoulder := false
	for item_id in _held_ids(inventory.hands):
		shoulder = shoulder or catalog[item_id].shoulder_camera
	cat.shoulder_view = shoulder


func _rebuild_paws(cat: CatPlayer, hands: Array) -> void:
	for slot in ["HeldR", "HeldL"]:
		_free_now(cat.cat_model.get_node_or_null(slot))
	for hand in 2:
		var item_id: String = hands[hand]
		if item_id == "" or (hand == 1 and _is_two_handed(hands)):
			continue
		var data: ItemData = catalog[item_id]
		var node := data.scene.instantiate() as Node3D
		# Same name on every computer, so RPCs sent from the item reach all copies.
		node.name = "HeldR" if hand == 0 else "HeldL"
		var offset := data.hold_offset
		if hand == 1:
			offset.x = -offset.x  # mirror for the left paw
		node.position = offset
		node.scale = Vector3.ONE * data.hold_scale
		var held := node as HeldItem
		if held != null:
			held.data = data
			held.holder = cat
			held.hand = hand
		cat.cat_model.add_child(node)


## The BACKPACK on a cat's back (made once, kept): its light strip goes cyan (empty) -> amber ->
## red (full), so anyone can see who's carrying a haul.
func _update_backpack(cat: CatPlayer, used: int, size: int) -> void:
	var pack := cat.cat_model.get_node_or_null("BackPack") as Node3D
	if pack == null:
		pack = LevelKit.instantiate_model(BACKPACK_MODEL)
		if pack == null:
			return
		pack.name = "BackPack"
		pack.position = BACKPACK_SPOT
		cat.cat_model.add_child(pack)
	var fill := clampf(float(used) / maxf(size, 1), 0.0, 1.0)
	var light := pack_light_empty.lerp(pack_light_half, fill * 2.0) if fill < 0.5 else pack_light_half.lerp(pack_light_full, (fill - 0.5) * 2.0)
	LevelKit.make_parts_glow(pack, {"Strip": light}, 1.5 + fill * 2.0)


## Where the inventory callout line starts: the PackAnchor marker on a cat's backpack (world
## space), or a spot on its back if the model isn't there.
func backpack_anchor(cat: CatPlayer) -> Vector3:
	var anchor := cat.cat_model.get_node_or_null("BackPack/PackAnchor") as Node3D
	if anchor == null:
		var pack := cat.cat_model.get_node_or_null("BackPack")
		anchor = pack.find_child("PackAnchor", true, false) as Node3D if pack != null else null
	if anchor != null:
		return anchor.global_position
	return cat.cat_model.to_global(BACKPACK_SPOT + Vector3(0, 0.15, 0.15))


func _free_now(node: Node) -> void:
	if node != null:
		node.get_parent().remove_child(node)  # frees the name right away for the new one
		node.queue_free()


## The bottom-left gun box (HUD "Held", scripts/ui/hud_weapon_display.gd) and crosshair, for
## whatever each of OUR players holds (on their own HUD: split screen).
func _update_hud() -> void:
	if Game.instance == null:
		return
	for cat in Game.instance.playing_cats():
		_update_hud_for(cat)


func _update_hud_for(cat: CatPlayer) -> void:
	var paws: Array = []   # [right paw, left paw]: what each holds (see HudWeaponDisplay.show_loadout)
	var quick: Array = []  # the two QUICK USE slots
	var wants_crosshair := false
	if cat.is_controlled or cat.is_gunner():
		var keys := ["shoot", "use_left"]  # right paw fires with LMB / RT, left with RMB / LT (SETTINGS > KEYS)
		for hand in 2:
			var held := held_item(cat, hand)
			if held == null or held.data == null:
				continue
			var weapon := held as Weapon
			paws.append({
				"id": held.data.id,
				"name": weapon.hud_name if weapon != null else held.data.display_name,
				"heat": weapon.heat if weapon != null else 0.0,
				"overheated": weapon != null and weapon.is_overheated,
				"heats": weapon != null and weapon.heat_per_shot > 0.0,
				# THE SLAM METER (the frozen tuna): 0..1, or -1 = this weapon has none.
				"charge": (held as MeleeWeapon).slam_charge if held is MeleeWeapon and (held as MeleeWeapon).can_slam else -1.0,
				"key": Hud.key_for(keys[hand], cat.slot),
			})
			wants_crosshair = wants_crosshair or held.wants_crosshair()
		var slots := quick_slots(cat.player_id)
		for slot in 2:  # QUICK USE slots (keys 1 / 2, d-pad left / right)
			var stack: Array = slots[slot]
			quick.append({
				"id": stack[0] if not stack.is_empty() else "",
				"count": stack.size(),
				"key": Hud.key_for("quick_%d" % (slot + 1), cat.slot),
			})
	var display := Hud.element("Held", cat.slot) as HudWeaponDisplay
	if display != null:
		display.show_loadout(paws, quick)
	# (No crosshair in the sewer's SAFE ZONE: guns don't fire there, so it's just clutter.)
	if UndergroundHub.is_safe(cat.global_position):
		wants_crosshair = false
	Hud.show_element("Crosshair", wants_crosshair, cat.slot)


# --- Helpers anyone can use ---

func get_inventory(player_id: int) -> Dictionary:
	return inventories.get(player_id, {"hands": ["", ""], "pack": [], "stash": [], "quick": [[], []]})


## A player's two QUICK USE slots: [[ids in slot 1], [ids in slot 2]] (each a stack of one item).
func quick_slots(player_id: int) -> Array:
	return quick_slots_of(get_inventory(player_id))


## The QUICK USE slots of an inventory dictionary (always two, even in an old one without them).
func quick_slots_of(inventory: Dictionary) -> Array:
	var quick: Array = inventory.get("quick", [])
	while quick.size() < 2:
		quick.append([])
	return quick


## Take the top item off QUICK USE stack "slot" of this inventory (changes it). "" = empty.
func _pop_quick(inventory: Dictionary, slot: int) -> String:
	var quick := quick_slots_of(inventory)
	var stack: Array = quick[clampi(slot, 0, 1)]
	if stack.is_empty():
		return ""
	var item_id: String = stack.pop_back()
	inventory.quick = quick
	return item_id


## What's in a player's stash (the safe lockers in the sewers).
func get_stash(player_id: int) -> Array:
	return get_inventory(player_id).get("stash", [])


## A spot on the ground a step in front of the cat (where dropped things land).
func ground_in_front_of(cat: CatPlayer) -> Vector3:
	var spot := cat.global_position - cat.cat_model.global_basis.z * 0.8
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP, spot + Vector3.DOWN * 20.0)
	query.exclude = [cat.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else spot


## The floor straight below a spot (ignoring cats), or the spot itself if there's no floor.
func _ground_below(at: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 20.0)
	query.collision_mask = 1  # the city and the hub only (Roombas are on layer 2)
	var skip: Array[RID] = []
	for cat in players.get_children():
		skip.append((cat as CollisionObject3D).get_rid())
	query.exclude = skip
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else at


## Speed multiplier from HEAVY loot in a player's backpack (ItemData.carry_speed): 1.0 = not slowed.
## cat_player.gd multiplies its walking and zoomies speed by this.
func carry_speed(player_id: int) -> float:
	var slowest := 1.0
	for item_id in get_inventory(player_id).pack:
		slowest = minf(slowest, (catalog[item_id] as ItemData).carry_speed)
	return slowest


## How NOISY a player's loot is (ItemData.noise): 1.0 = normal. Roombas multiply how far
## they can spot that cat by this (roomba.gd).
func loot_noise(player_id: int) -> float:
	var loudest := 1.0
	for item_id in get_inventory(player_id).pack:
		loudest = maxf(loudest, (catalog[item_id] as ItemData).noise)
	return loudest


## Host -> everyone: someone grabbed a big prize. Only a sound now (the HUD was simplified, so
## no "MITTENS GRABBED THE GOLDEN KOI!" text); "text" is kept for the console.
@rpc("authority", "call_local", "reliable")
func _announce(text: String) -> void:
	print("[Items] " + text)
	Sound.play("koi_grab")  # sounds/sfx/koi_grab.wav


## How many pieces of LOOT are in a player's backpack (0 = nothing for a rival to rob).
func bag_used(player_id: int) -> int:
	return loot_in_pack(player_id).size()


## The item script in a cat's paw (0 = right, 1 = left), or null.
func held_item(cat: CatPlayer, hand: int) -> HeldItem:
	return cat.cat_model.get_node_or_null("HeldR" if hand == 0 else "HeldL") as HeldItem


func _held_ids(hands: Array) -> Array:
	if _is_two_handed(hands):
		return [hands[0]]
	return hands.filter(func(item_id): return item_id != "")


func _is_two_handed(hands: Array) -> bool:
	return hands[0] != "" and catalog.has(hands[0]) and (catalog[hands[0]] as ItemData).hands == 2


func _cat(player_id: int) -> CatPlayer:
	return players.get_node_or_null(str(player_id)) as CatPlayer


## How far apart a cat and an item are, for grabbing: measured along the ground, but
## "out of reach" (INF) if one is far above the other. Without the height check, a cat in the
## sewers (200 m down) could grab fish lying in the city right above its head.
func _reach_distance(a: Vector3, b: Vector3) -> float:
	if absf(a.y - b.y) > MAX_REACH_HEIGHT:
		return INF
	return Motion.flat_distance(a, b)
