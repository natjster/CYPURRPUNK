class_name ItemManager
extends Node3D
## THE ITEM SYSTEM. One of these lives in main.tscn as the "Items" node.
## It handles every item in the game the same way, so new items need no new plumbing:
##   - loads every item card (ItemData .tres) from res://items/
##   - places the LOOT TABLE (res://loot/city.tres: fish, sardines, the koi) in each city,
##     lying on the street, and makes it grow back (gear is BOUGHT in the sewers, see request_buy)
##   - buying from the shop down in the sewers (request_buy, prices on the item cards)
##   - pickups (walk-into for auto_pickup items, E for the rest), drops (G), using up (catnip)
##   - each cat's PAWS (right + left; a 2-paw item takes both), BACKPACK and LOOT BAG
##   - two QUICK USE slots per cat (keys 1 / 2, d-pad left / right): catnip and catdip go
##     there when picked up or bought (ItemData.quick_use), stacked, and are used with one press
##   - each player's STASH: safe lockers in the sewers, saved between games (player_profile.gd)
##   - shows held items in paws and loot stacked on the cat, on every computer
##   - Left Mouse uses the right-paw item, Right Mouse the left-paw item
##
## MULTIPLAYER: the HOST is the referee. Clients ask (request_pickup / request_drop_item /
## request_consume / ...); the host checks and then tells everyone the result. Everyone keeps
## a copy of "world" (items on the street) and "inventories" (paws + bag per player).
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
## Where loot sits on a cat: first in its mouth, then stacked on its head.
const LOOT_SPOTS: Array[Vector3] = [Vector3(0, 0.66, -0.38), Vector3(0, 1.12, 0), Vector3(0, 1.23, 0), Vector3(0, 1.34, 0)]
## A cat can't grab an item more than this many metres above or below it (see _reach_distance).
const MAX_REACH_HEIGHT: float = 3.0

@export_group("Rules")
## How much loot one cat can carry.
@export var bag_size: int = 3
## Backpack slots for held items you aren't using right now (open the inventory: Tab or I).
@export var pack_size: int = 6
## How many of the same item stack in one QUICK USE slot (3 = up to 3 catnip on key 1).
@export var quick_stack_size: int = 3
## Slots in each player's STASH, the safe lockers down in the sewers (gear, and SCRAP - no
## money loot). What's in the stash never drops when you're knocked out, and is saved between games.
@export var stash_size: int = 9
## How close (metres) a cat must be to grab an auto-pickup item by walking into it.
@export var pickup_radius: float = 1.4
## How close (metres) a cat must be to grab an item with E.
@export var interact_radius: float = 2.5

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
## Player ID -> {"hands": [right, left], "bag": [loot ids], "pack": [held item ids],
##                "stash": [held item ids], "quick": [[ids in slot 1], [ids in slot 2]]}.
## "" = empty paw. A 2-paw item is stored in BOTH paws. "pack" is the backpack.
## "stash" is the safe locker in the sewers (see request_to_stash / player_profile.gd).
## "quick" = the two QUICK USE slots: each a stack of the SAME item, e.g. ["catnip", "catnip"].
var inventories := {}

var _world_nodes := {}   # world item ID -> Node3D on the street
var _spawns: Array = []  # host: [{"item", "pos", "respawn", "back_at"}], index = world item ID
var _next_id: int = FIRST_DROPPED_ID
var _clock: float = 0.0
## Host: world item ID -> player ID of the cat that dropped it. That cat can't auto-grab it
## again until it steps away (otherwise dropping a fish would instantly pick it back up).
var _dropped_by := {}
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
	Controls.changed.connect(_refresh_pickup_prompts)


func _load_catalog() -> void:
	for file in DirAccess.get_files_at(ITEMS_FOLDER):
		file = file.trim_suffix(".remap")  # exported games rename resources
		if file.ends_with(".tres"):
			var data := load(ITEMS_FOLDER + file) as ItemData
			if data != null and not data.id.is_empty():
				catalog[data.id] = data
	print("[Items] Loaded %d item cards: %s" % [catalog.size(), ", ".join(catalog.keys())])


## The player changed their keys: rewrite the "E  PURR-TOMMY" labels above street items.
func _refresh_pickup_prompts() -> void:
	for prompt in get_tree().get_nodes_in_group("pickup_prompts"):
		prompt.text = "%s  %s" % [Controls.key_text("interact"), prompt.get_meta("item_name")]


# --- Placing items when a city is built (same result on every computer) ---

func _on_city_generated(city_seed: int) -> void:
	for id in _world_nodes:
		_world_nodes[id].queue_free()
	_world_nodes.clear()
	world.clear()
	_spawns.clear()
	_dropped_by.clear()
	_next_id = FIRST_DROPPED_ID

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(city_seed * 31 + LOOT_SEED_SALT)
	if loot_table != null:
		for line in loot_table.spawns:
			if line != null:
				_place_loot_line(line, rng)
	# Anything else that places things per city (the heist's manholes and payphones) goes now,
	# in a fixed order.
	get_tree().call_group("item_placers", "place_items", self, city_seed)


## One line of the loot table: "count" of an item, where the line says (loot_spawn.gd).
func _place_loot_line(line: LootSpawn, rng: RandomNumberGenerator) -> void:
	if not catalog.has(line.item_id):
		push_warning("[Items] Loot table: no item card called '%s' in res://items/" % line.item_id)
		return
	var door := city.meow_mart_position
	for i in line.count:
		var spot := Vector3.ZERO
		match line.where:
			LootSpawn.Where.OUTSIDE_MEOW_MART:
				# A row along the sidewalk outside the door, 1.3 m apart, centred on it.
				spot = door + Vector3((i - (line.count - 1) / 2.0) * 1.3, 0, -0.5)
			LootSpawn.Where.FIXED_SPOT:
				spot = line.spot + Vector3(i * 0.8, 0, 0)
			_:  # SIDEWALK
				spot = random_sidewalk_spot(rng)
				for attempt in 20:  # far enough from Meow-Mart? (a few tries, then take what we got)
					if spot.distance_to(door) >= line.min_distance_from_meow_mart:
						break
					spot = random_sidewalk_spot(rng)
		add_spawn_point(line.item_id, spot, line.respawn_seconds)


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
	if not data.auto_pickup:
		var prompt := Label3D.new()
		prompt.text = "%s  %s" % [Controls.key_text("interact"), data.display_name]
		prompt.set_meta("item_name", data.display_name)
		prompt.add_to_group("pickup_prompts")  # re-labelled when the player rebinds GRAB
		prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		prompt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		prompt.modulate = Color(1, 1, 1, 0.9)
		prompt.outline_size = 6
		prompt.font_size = 32
		prompt.pixel_size = 0.007
		prompt.position.y = 1.25
		spot.add_child(prompt)
	_world_nodes[id] = spot


func _remove_world_local(id: int) -> void:
	world.erase(id)
	_dropped_by.erase(id)  # gone from the street: nobody needs to "step away" from it any more
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


## Host only: grow items back, and hand auto-pickup items to cats walking into them.
func _host_tick() -> void:
	for i in _spawns.size():
		var spawn: Dictionary = _spawns[i]
		if spawn.back_at >= 0.0 and _clock >= spawn.back_at:
			spawn.back_at = -1.0
			_add_world.rpc(i, spawn.item, spawn.pos)
	for node in players.get_children():
		var cat := node as CatPlayer
		var player_id := cat.player_id
		if Game.instance.car_of(player_id) != null:
			continue  # no grabbing things from inside the car
		if CatHealth.instance.is_down(player_id):
			continue  # knocked out: it's lying on the loot it just spilled, don't suck it back up
		for id in world.keys():
			var data: ItemData = catalog[world[id].item]
			var distance := _reach_distance(cat.global_position, world[id].pos)
			if _dropped_by.get(id, 0) == player_id:
				if distance > pickup_radius + 0.5:
					_dropped_by.erase(id)  # walked away: it can be grabbed again
				continue
			if data.auto_pickup and distance < pickup_radius and _can_take(player_id, data):
				_give(player_id, id)
				break  # one item per cat per frame


## The owner's computer: press the use buttons for whatever is in our cats' paws
## (every player on this computer, each with their own buttons: scripts/seats.gd).
func _use_held_items(delta: float) -> void:
	if Game.instance == null:
		return
	for cat in Game.instance.local_cats():
		if not cat.reads_input() or not cat.is_controlled or cat.knocked_out or cat.is_downed():
			continue  # (downed cats can't shoot or sniff catnip: they can only crawl and meow)
		var safe_zone := UndergroundHub.is_in_hub(cat.global_position)
		var allowed := _can_use_items(cat)
		# QUICK USE keys (1 / 2, d-pad left / right): the host takes one out and we use it.
		for slot in 2:
			if allowed and Seats.is_just_pressed(cat.slot, "quick_%d" % (slot + 1)) and not quick_slots(cat.player_id)[slot].is_empty():
				request_quick_use.rpc_id(1, cat.player_id, slot)
		for hand in 2:
			var held := held_item(cat, hand)
			if held == null or (safe_zone and held is Weapon):
				continue  # the hub is a safe zone: guns don't fire down there (catnip still works)
			var action := "shoot" if hand == 0 else "use_left"
			held.use_tick(allowed and Seats.is_pressed(cat.slot, action), allowed and Seats.is_just_pressed(cat.slot, action), delta)


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

func _can_take(player_id: int, data: ItemData) -> bool:
	if data.kind == ItemData.Kind.LOOT:
		return bag_used(player_id) + data.bag_space <= bag_size
	return true  # held items always fit: whatever is in the way gets dropped


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


## Host: put an item into a player's paws (or backpack, or loot bag) and tell everyone.
## If every paw and backpack slot is full, whatever is in the way is dropped at the cat's
## feet (or at "fallback_spot" if the cat can't be found).
func _put_in_inventory(player_id: int, item_id: String, fallback_spot: Vector3) -> void:
	var data: ItemData = catalog[item_id]
	var inventory := get_inventory(player_id).duplicate(true)
	var cat := _cat(player_id)
	var drop_at: Vector3 = cat.global_position if cat != null else fallback_spot

	if data.kind == ItemData.Kind.LOOT:
		inventory.bag.append(item_id)
	elif data.quick_use and _add_to_quick(inventory, item_id):
		pass                                                # catnip etc.: into a QUICK USE slot
	else:
		var hands: Array = inventory.hands
		var pack: Array = inventory.pack
		if data.hands == 2 and _held_ids(hands).is_empty():
			hands = [item_id, item_id]                      # free paws: hold it
		elif data.hands == 1 and not _is_two_handed(hands) and "" in hands:
			hands[hands.find("")] = item_id                 # a free paw: hold it
		elif pack.size() < pack_size:
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
func _add_to_quick(inventory: Dictionary, item_id: String) -> bool:
	var quick := quick_slots_of(inventory)
	for slot in quick:
		if not slot.is_empty() and slot[0] == item_id and slot.size() < quick_stack_size:
			slot.append(item_id)
			inventory.quick = quick
			return true
	for slot in quick:
		if slot.is_empty():
			slot.append(item_id)
			inventory.quick = quick
			return true
	return false


## Host: put an item on the street with a brand-new world ID.
## dropper = the cat that dropped it (it won't auto-grab it back until it steps away).
func _spawn_dropped(item_id: String, at: Vector3, dropper: int = 0) -> void:
	# Keep the height: a drop in the sewers stays in the sewers (it used to pop up in the city).
	_add_world.rpc(_next_id, item_id, at)
	# Remember who dropped it AFTER it's on the street: putting it there clears old notes about
	# that ID (_remove_world_local), which used to wipe this one, so a dropped fish got
	# grabbed straight back.
	if dropper != 0:
		_dropped_by[_next_id] = dropper
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
	if not _can_take(player_id, data):
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
	Hud.show_message(("SOLD! " if ok else "") + text, 3.0, PlayerId.slot_of(player_id))  # the buyer's screen


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
	if inventory.pack.size() >= pack_size:
		return
	var item_id := _pop_quick(inventory, slot)
	if item_id == "":
		return
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
	if data.quick_use and _add_to_quick(inventory, item_id):
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
		hands[hands.find("")] = item_id
	else:
		put_away.append(hands[0])  # both paws full: the right-paw item goes in the backpack
		hands[0] = item_id
	for old in put_away:
		if pack.size() < pack_size:
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
	if item_id == "" or inventory.pack.size() >= pack_size:
		return
	if _is_two_handed(hands):
		hands = ["", ""]
	else:
		hands[clampi(hand, 0, 1)] = ""
	inventory.hands = hands
	inventory.pack.append(item_id)
	_set_inventory.rpc(player_id, inventory)


## Drop one item on the ground in front of the cat (G key, or right-click in the inventory).
## where = "hand" (index 0 right / 1 left), "pack" or "bag" (index = slot). Host only.
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
	elif where in ["pack", "bag"] and index >= 0 and index < inventory[where].size():
		item_id = inventory[where].pop_at(index)
	elif where == "quick":
		item_id = _pop_quick(inventory, index)  # one off the top of that stack
	if item_id == "":
		return
	_spawn_dropped(item_id, ground, player_id)
	_set_inventory.rpc(player_id, inventory)


## Host: empty a player's loot bag (the heist calls this at the drop-off). Returns what was in it.
func take_bag(player_id: int) -> Array:
	var inventory := get_inventory(player_id).duplicate(true)
	var bag: Array = inventory.bag
	if bag.is_empty():
		return []
	inventory.bag = []
	_set_inventory.rpc(player_id, inventory)
	return bag


## Host: take only the MONEY loot (cash_value > 0) out of a player's loot bag and return it
## (the heist cashes it in at the exit manhole). Loot worth $0 - SCRAP - stays in the bag, to
## be fed to THE MAINFRAME (scripts/mainframe.gd) or put in the stash.
func take_cash_loot(player_id: int) -> Array:
	var inventory := get_inventory(player_id).duplicate(true)
	var cash: Array = []
	var kept: Array = []
	for item_id in inventory.bag:
		if (catalog[item_id] as ItemData).cash_value > 0:
			cash.append(item_id)
		else:
			kept.append(item_id)
	if cash.is_empty():
		return []
	inventory.bag = kept
	_set_inventory.rpc(player_id, inventory)
	return cash


## How many of this item are in a player's loot bag (e.g. scrap for THE MAINFRAME).
func count_in_bag(player_id: int, item_id: String) -> int:
	return get_inventory(player_id).bag.count(item_id)


## Host: take ONE of this item out of a player's loot bag. False = they had none.
## (THE MAINFRAME calls this when scrap is fed in: scripts/mainframe.gd.)
func take_from_bag(player_id: int, item_id: String) -> bool:
	var inventory := get_inventory(player_id).duplicate(true)
	var bag: Array = inventory.bag
	var index := bag.rfind(item_id)
	if index < 0:
		return false
	bag.remove_at(index)
	_set_inventory.rpc(player_id, inventory)
	return true


## Host: a rival ROBS a downed cat (cat_health.gd): the victim's loot bag goes into the robber's,
## as far as it fits; the rest drops on the street next to the victim. Returns how many pieces
## the robber got.
func steal_bag(victim_id: int, robber_id: int) -> int:
	var victim := _cat(victim_id)
	var at: Vector3 = victim.global_position if victim != null else Vector3.ZERO
	var taken := 0
	var loot := take_bag(victim_id)
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


## Host: take ONE piece of loot (the last one picked up) out of a player's bag.
## Returns its item id, or "" if the bag was empty. (A Roomba bonk calls this.)
func take_one_loot(player_id: int) -> String:
	var inventory := get_inventory(player_id).duplicate(true)
	var bag: Array = inventory.bag
	if bag.is_empty():
		return ""
	var item_id: String = bag.pop_back()
	_set_inventory.rpc(player_id, inventory)
	return item_id


## Host: put an item on the street for anyone to grab (e.g. what a smashed Roomba spits out).
func drop_on_street(item_id: String, at: Vector3) -> void:
	_spawn_dropped(item_id, at)


## Host: empty a player's paws, backpack and loot bag onto the ground around "at"
## (a knocked-out cat, see cat_health.gd, or a player who quit). The STASH is safe: it stays.
func drop_everything(player_id: int, at: Vector3) -> void:
	var inventory := get_inventory(player_id).duplicate(true)
	var dropped := _held_ids(inventory.hands) + Array(inventory.bag) + Array(inventory.pack)
	for stack in quick_slots_of(inventory):
		dropped += Array(stack)
	var ground := _ground_below(at)  # a bonked cat may still be flying through the air
	for i in dropped.size():
		_spawn_dropped(dropped[i], ground + Vector3(cos(i * 1.3), 0, sin(i * 1.3)) * 0.8)
	if not dropped.is_empty():
		inventory.hands = ["", ""]
		inventory.bag = []
		inventory.pack = []
		inventory.quick = [[], []]
		_set_inventory.rpc(player_id, inventory)


# --- The stash: safe lockers in the sewers (host decides, like everything else) ---

## Inventory screen at the stash: put the item in this paw ("hand", 0 right / 1 left),
## backpack slot ("pack"), quick slot ("quick") or loot bag slot ("bag": SCRAP only, see
## is_stashable) into the stash. Only while standing at the lockers. Host only.
@rpc("any_peer", "call_local", "reliable")
func request_to_stash(player_id: int, where: String, index: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var cat := _cat(player_id)
	var inventory := get_inventory(player_id).duplicate(true)
	var stash: Array = inventory.get("stash", [])
	if cat == null or not UndergroundHub.of(cat).near_stash(cat) or stash.size() >= stash_size:
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
	elif where == "bag" and index >= 0 and index < inventory.bag.size() and is_stashable(inventory.bag[index]):
		item_id = inventory.bag.pop_at(index)  # (money loot can't be stashed: only scrap)
	if item_id == "":
		return
	stash.append(item_id)
	inventory.stash = stash
	_set_inventory.rpc(player_id, inventory)


## Inventory screen at the stash: take stash slot "index" out, into the backpack (or, for
## SCRAP, back into the loot bag). Host only.
@rpc("any_peer", "call_local", "reliable")
func request_from_stash(player_id: int, index: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var cat := _cat(player_id)
	var inventory := get_inventory(player_id).duplicate(true)
	var stash: Array = inventory.get("stash", [])
	if cat == null or not UndergroundHub.of(cat).near_stash(cat) or index < 0 or index >= stash.size():
		return
	var data: ItemData = catalog.get(stash[index])
	if data != null and data.kind == ItemData.Kind.LOOT:
		if not _can_take(player_id, data):
			return  # loot bag full (the screen tells the player)
		inventory.bag.append(stash.pop_at(index))
	elif inventory.pack.size() >= pack_size:
		return  # backpack full (the screen tells the player)
	else:
		inventory.pack.append(stash.pop_at(index))
	inventory.stash = stash
	_set_inventory.rpc(player_id, inventory)


## May this item go in the stash? Gear (held items) yes; loot only if it's worth $0 at the
## exit (SCRAP) - fish and koi have to be cashed in. (player_profile.gd checks saves with this.)
func is_stashable(item_id: String) -> bool:
	var data: ItemData = catalog.get(item_id)
	return data != null and (data.kind != ItemData.Kind.LOOT or data.cash_value <= 0)


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
## everyone's paws/bags. (Sent right after the city seed, so the city's items already exist; Items
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
# (No HUD line: each press-E item already floats its own "E PURR-TOMMY" label.)

func interact_distance(cat: CatPlayer) -> float:
	var best_id := _nearest_press_e_item(cat)
	return _reach_distance(cat.global_position, world[best_id].pos) if best_id >= 0 else -1.0


func interact_prompt(_cat: CatPlayer) -> String:
	return ""


## E pressed: ask the host for the nearest press-E item in reach.
func interact(cat: CatPlayer) -> void:
	var best_id := _nearest_press_e_item(cat)
	if best_id >= 0:
		request_pickup.rpc_id(1, cat.player_id, best_id)


## A street item right by you comes before anything else (E near an item and the car = item).
func interact_priority() -> int:
	return 30


## The world ID of the nearest press-E (not walk-into) item within reach, or -1.
func _nearest_press_e_item(cat: CatPlayer) -> int:
	var best_id := -1
	var best_distance := interact_radius
	for id in world:
		var data: ItemData = catalog[world[id].item]
		var distance := _reach_distance(cat.global_position, world[id].pos)
		if not data.auto_pickup and distance < best_distance:
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
	var bag_key := str(inventory.bag)
	if cat.get_meta("bag_key", "") != bag_key:
		cat.set_meta("bag_key", bag_key)
		_rebuild_loot_stack(cat, inventory.bag)
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


func _rebuild_loot_stack(cat: CatPlayer, bag: Array) -> void:
	_free_now(cat.cat_model.get_node_or_null("LootStack"))
	var stack := Node3D.new()
	stack.name = "LootStack"
	cat.cat_model.add_child(stack)
	for i in bag.size():
		var model := (catalog[bag[i]] as ItemData).scene.instantiate() as Node3D
		model.position = LOOT_SPOTS[mini(i, LOOT_SPOTS.size() - 1)] + Vector3(0, 0.11 * maxi(0, i - LOOT_SPOTS.size() + 1), 0)
		model.rotation.y = PI / 2.0  # sideways, like a cat holding a fish
		stack.add_child(model)


func _free_now(node: Node) -> void:
	if node != null:
		node.get_parent().remove_child(node)  # frees the name right away for the new one
		node.queue_free()


## The bottom-of-screen text (HUD "Held") and crosshair, for whatever each of OUR players holds
## (on their own HUD: split screen).
func _update_hud() -> void:
	if Game.instance == null:
		return
	for cat in Game.instance.playing_cats():
		_update_hud_for(cat)


func _update_hud_for(cat: CatPlayer) -> void:
	var lines := PackedStringArray()
	var wants_crosshair := false
	if cat.is_controlled:
		var labels := ["R:", "L:"]  # right paw, left paw (keys: SETTINGS > KEYS)
		for hand in 2:
			var held := held_item(cat, hand)
			if held != null:
				var text := held.hud_text()
				lines.append(("%s %s" % [labels[hand], text]) if text != "" else labels[hand])
				wants_crosshair = wants_crosshair or held.wants_crosshair()
		var quick := quick_slots(cat.player_id)
		for slot in 2:  # QUICK USE slots, e.g. "1: CATNIP x2"
			if not quick[slot].is_empty():
				var data: ItemData = catalog[quick[slot][0]]
				lines.append("%s: %s x%d" % [Controls.key_text("quick_%d" % (slot + 1)), data.display_name, quick[slot].size()])
	Hud.show_element("Held", not lines.is_empty(), cat.slot)
	Hud.set_text("Held", "  |  ".join(lines), cat.slot)
	Hud.show_element("Crosshair", wants_crosshair, cat.slot)


# --- Helpers anyone can use ---

func get_inventory(player_id: int) -> Dictionary:
	return inventories.get(player_id, {"hands": ["", ""], "bag": [], "pack": [], "stash": [], "quick": [[], []]})


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


## Speed multiplier from HEAVY loot in a player's bag (ItemData.carry_speed): 1.0 = not slowed.
## cat_player.gd multiplies its walking and zoomies speed by this.
func carry_speed(player_id: int) -> float:
	var slowest := 1.0
	for item_id in get_inventory(player_id).bag:
		slowest = minf(slowest, (catalog[item_id] as ItemData).carry_speed)
	return slowest


## How NOISY a player's loot is (ItemData.noise): 1.0 = normal. Roombas multiply how far
## they can spot that cat by this (roomba.gd).
func loot_noise(player_id: int) -> float:
	var loudest := 1.0
	for item_id in get_inventory(player_id).bag:
		loudest = maxf(loudest, (catalog[item_id] as ItemData).noise)
	return loudest


## Host -> everyone: someone grabbed a big prize. Only a sound now (the HUD was simplified, so
## no "MITTENS GRABBED THE GOLDEN KOI!" text); "text" is kept for the console.
@rpc("authority", "call_local", "reliable")
func _announce(text: String) -> void:
	print("[Items] " + text)
	Sound.play("koi_grab")  # sounds/sfx/koi_grab.wav


## How much loot-bag room a player is using.
func bag_used(player_id: int) -> int:
	var used := 0
	for item_id in get_inventory(player_id).bag:
		used += (catalog[item_id] as ItemData).bag_space
	return used


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
