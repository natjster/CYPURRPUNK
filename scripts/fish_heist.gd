class_name FishHeist
extends Node3D
## FISH HEIST — the extraction loop: go up, grab fish, reach the beam, get paid, back down.
## Attach to the "Heist" node in main.tscn.
##
## How it plays:
##   - Cats start in the underground hub (hub.gd). Don Catleone sends them up to the city.
##   - Glowing fish lie outside Meow-Mart and on sidewalks around the city.
##   - Walk into a fish to pick it up automatically. Fish are LOOT items (items/fish.tres),
##     so the item system handles picking up, the loot bag and showing them on your cat.
##   - Reach the EXTRACTION point (the tall green light beam), on foot or by car.
##     Every piece of loot pays its card's cash_value into YOUR cash (cash is per player),
##     and you're sent back down to the hub — with or without loot.
##     Quests done at that moment (quest_manager.gd, e.g. Lil' Mittens' 3 fish) pay their
##     bonus on top.
##     If you were driving, the getaway car goes back to its parking spot for the next trip.
##   - Taken fish grow back at their spot after respawn_seconds. No timer: play forever.
##
## Multiplayer: the HOST is the referee. It checks every frame who is standing in the
## beam, empties their loot bag and tells everyone with an RPC. The extracted player's own
## computer then moves their cat down to the hub (owners always move their own cat).
## Fish spots and the drop-off are picked from the city seed with their OWN random
## generator, so every computer places them identically and buildings never move.

@export_group("Fish")
## Which item card is placed as the heist's loot.
@export var loot_item: String = "fish"
## Fish waiting outside Meow-Mart.
@export var meow_mart_fish: int = 5
## Extra fish scattered on sidewalks around the city.
@export var street_fish: int = 8
## Seconds before a taken fish appears again at its spot.
@export var respawn_seconds: float = 20.0

@export_group("Drop-off")
## How close (metres) to the beam you must get to hand in your loot.
@export var dropoff_radius: float = 4.0
## The drop-off is picked at a crossroads at least this far from Meow-Mart.
@export var min_dropoff_distance: float = 70.0
@export var beam_color: Color = Color(0.2, 1, 0.45)

## The one heist node, so the shop can reach everyone's cash (FishHeist.instance).
static var instance: FishHeist

## Mixed into the city seed so heist placement has its own random numbers.
const HEIST_SEED_SALT: int = 7331

@onready var city: CityGenerator = $"../City"
@onready var players: Node3D = $"../Players"
@onready var car: GetawayCar = $"../GetawayCar"
@onready var cash_label: Label = $"../PS1Overlay/HUD/Cash"
@onready var carry_label: Label = $"../PS1Overlay/HUD/Carrying"
@onready var dropoff_label: Label = $"../PS1Overlay/HUD/DropOff"
@onready var scoreboard_label: Label = $"../PS1Overlay/HUD/Scoreboard"
@onready var popup_label: Label = $"../PS1Overlay/HUD/Popup"

## Where the drop-off is in the current city.
var dropoff_position: Vector3
## Network ID -> cash. Everyone keeps a copy; only the host changes it (via RPC).
var cash := {}

var _built: Array[Node] = []  # the drop-off pieces, so a new city can clear them
var _popup_time: float = 0.0
var _clock: float = 0.0
## Host: network ID -> time until we ignore that cat at the beam (it's on its way down).
var _extract_wait := {}


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	add_to_group("item_placers")  # the item system calls place_items() for every new city
	popup_label.hide()


# --- Setting up the heist for a city (called by the item system, on every computer) ---

func place_items(items: ItemManager, city_seed: int) -> void:
	for node in _built:
		node.queue_free()
	_built.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(city_seed * 31 + HEIST_SEED_SALT)

	# A row of fish on the sidewalk outside Meow-Mart's door.
	var door := city.meow_mart_position
	for i in meow_mart_fish:
		items.add_spawn_point(loot_item, door + Vector3((i - (meow_mart_fish - 1) / 2.0) * 1.3, 0, -0.5), respawn_seconds)
	# Fish dropped on random sidewalks around the city.
	for i in street_fish:
		items.add_spawn_point(loot_item, items.random_sidewalk_spot(rng), respawn_seconds)

	# The drop-off: a random crossroads far from Meow-Mart.
	var pitch := city.block_size + city.street_width
	var blocks := city.blocks_per_side
	var choices: Array[Vector3] = []
	var farthest := Vector3.ZERO
	for ix in blocks - 1:
		for iz in blocks - 1:
			var crossroads := Vector3((ix + 1 - blocks / 2.0) * pitch, 0, (iz + 1 - blocks / 2.0) * pitch)
			if crossroads.distance_to(door) >= min_dropoff_distance:
				choices.append(crossroads)
			if crossroads.distance_to(door) > farthest.distance_to(door):
				farthest = crossroads
	dropoff_position = choices[rng.randi_range(0, choices.size() - 1)] if not choices.is_empty() else farthest
	_build_dropoff(dropoff_position)


## Tall glowing beam you can see over the rooftops, a ring of glowing posts, a light and a sign.
func _build_dropoff(at: Vector3) -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.disable_fog = true  # shines through the fog so you can find it from far away
	glow.albedo_color = Color(beam_color, 0.35)

	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 1.2
	beam_mesh.bottom_radius = 1.6
	beam_mesh.height = 60.0
	beam_mesh.radial_segments = 8
	beam_mesh.rings = 6
	var beam := MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.material_override = glow
	beam.position = at + Vector3(0, 30, 0)
	_add_built(beam)

	var post_material := StandardMaterial3D.new()
	post_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	post_material.albedo_color = beam_color * 2.5  # brighter than white = it glows
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.25, 0.6, 0.25)
	for i in 8:
		var angle := TAU * i / 8.0
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = post_material
		post.position = at + Vector3(cos(angle), 0, sin(angle)) * dropoff_radius + Vector3(0, 0.3, 0)
		_add_built(post)

	var light := OmniLight3D.new()
	light.light_color = beam_color
	light.light_energy = 3.0
	light.light_volumetric_fog_energy = 2.0
	light.omni_range = 10.0
	light.position = at + Vector3(0, 2.5, 0)
	_add_built(light)

	var sign_label := Label3D.new()
	sign_label.text = "EXTRACTION\n$ FISH $"
	sign_label.font_size = 48
	sign_label.pixel_size = 0.02
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sign_label.modulate = Color(beam_color * 2.5, 1)
	sign_label.position = at + Vector3(0, 4.5, 0)
	_add_built(sign_label)


func _add_built(node: Node3D) -> void:
	add_child(node)
	_built.append(node)


# --- Every frame ---

func _process(delta: float) -> void:
	_update_hud(delta)


## Host only: the referee. Who reached the extraction beam?
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_clock += delta
	var items := ItemManager.instance
	for node in players.get_children():
		var peer_id := node.name.to_int()
		var driving := car.driver_id == peer_id
		var where: Vector3 = car.global_position if driving else (node as Node3D).global_position
		if UndergroundHub.is_in_hub(where) or _clock < _extract_wait.get(peer_id, 0.0):
			continue
		if Vector2(where.x - dropoff_position.x, where.z - dropoff_position.z).length() >= dropoff_radius:
			continue
		# Extract! Ignore this cat for a moment while its new position arrives from its owner.
		_extract_wait[peer_id] = _clock + 3.0
		# Quests first, while the loot is still in the bag (e.g. Mittens wants 3 fish IN it).
		var quest_bonus: int = QuestManager.instance.complete_on_extract(peer_id)[0]
		var loot := items.take_bag(peer_id) if items.bag_used(peer_id) > 0 else []
		var earned := 0
		for item_id in loot:
			earned += (items.catalog[item_id] as ItemData).cash_value
		if driving:
			car.set_driver.rpc(0)  # out of the car first (the host owns the car again)...
			Game.instance.park_car()  # ...and it waits at its parking spot for the next trip up
		_extracted.rpc(peer_id, earned, loot.size(), quest_bonus)


# --- What the host tells everyone (runs on every computer) ---

## earned = what the loot was worth; quest_bonus = extra cash from quests finished just now.
@rpc("authority", "call_local", "reliable")
func _extracted(peer_id: int, earned: int, count: int, quest_bonus: int = 0) -> void:
	cash[peer_id] = cash.get(peer_id, 0) + earned + quest_bonus
	print("[Heist] Player %d extracted with %d loot for $%d + quest bonus $%d (total $%d)" % [peer_id, count, earned, quest_bonus, cash[peer_id]])
	if peer_id == multiplayer.get_unique_id():
		popup_label.text = ("EXTRACTED +$%d" % earned) if earned > 0 else "EXTRACTED"
		if quest_bonus > 0:
			popup_label.text += "\nQUEST DONE +$%d" % quest_bonus
		_popup_time = 2.5
		UndergroundHub.instance.return_cat(Game.instance.my_cat())  # down the drain we go


## Host only: take "amount" from a player's cash (the sewer shop calls this).
## Returns false (and takes nothing) if they can't afford it.
func spend(peer_id: int, amount: int) -> bool:
	if cash.get(peer_id, 0) < amount:
		return false
	_set_cash.rpc(peer_id, cash.get(peer_id, 0) - amount)
	return true


## Host -> everyone: this player's cash is now "amount".
@rpc("authority", "call_local", "reliable")
func _set_cash(peer_id: int, amount: int) -> void:
	cash[peer_id] = amount


## Host -> a player who just joined: everyone's cash.
func send_state_to(peer_id: int) -> void:
	_receive_state.rpc_id(peer_id, cash)


@rpc("authority", "call_remote", "reliable")
func _receive_state(cash_now: Dictionary) -> void:
	cash = cash_now


## Host: a player quit. Their cash goes with them.
func player_left(peer_id: int) -> void:
	_forget_player.rpc(peer_id)


@rpc("authority", "call_local", "reliable")
func _forget_player(peer_id: int) -> void:
	cash.erase(peer_id)


# --- HUD (your cash, your loot, where to go, everyone's cash) ---

func _update_hud(delta: float) -> void:
	var me := multiplayer.get_unique_id()
	var my_cat := players.get_node_or_null(str(me)) as CatPlayer
	if my_cat == null:
		return
	var items := ItemManager.instance
	cash_label.text = "$%d" % cash.get(me, 0)
	# Under the cash: your quest's progress (e.g. "QUEST: MITTENS' FISH 2/3") if you have one,
	# otherwise how full your loot bag is.
	var quest_line := QuestManager.instance.hud_text(me)
	if quest_line != "":
		carry_label.text = "QUEST: " + quest_line
	else:
		var used := items.bag_used(me)
		carry_label.text = "LOOT %d/%d%s" % [used, items.bag_size, "  FULL!" if used >= items.bag_size else ""]

	# Distance and rough direction to the extraction beam, relative to where the camera looks.
	# Down in the hub there's no beam to point at.
	var where := car.global_position if car.driver_id == me else my_cat.global_position
	if UndergroundHub.is_in_hub(where):
		dropoff_label.text = "THE SEWERS - SAFE ZONE"
	else:
		dropoff_label.text = _direction_text(where)

	# Everyone's cash, richest first.
	var rows: Array = []
	for node in players.get_children():
		var cat := node as CatPlayer
		rows.append([cash.get(cat.name.to_int(), 0), cat.get_node("NameTag").text if cat.name.to_int() != me else "YOU"])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var lines := PackedStringArray()
	for row in rows:
		lines.append("%s $%d" % [row[1], row[0]])
	scoreboard_label.text = "\n".join(lines)

	if _popup_time > 0.0:
		_popup_time -= delta
		popup_label.visible = _popup_time > 0.0
		popup_label.modulate.a = clampf(_popup_time, 0.0, 1.0)


## "EXTRACT > 120m": distance and rough direction to the beam from where the camera looks.
func _direction_text(where: Vector3) -> String:
	var to_dropoff := dropoff_position - where
	var arrow := "^"
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var look := -camera.global_transform.basis.z
		var angle := rad_to_deg(Vector2(look.x, look.z).angle_to(Vector2(to_dropoff.x, to_dropoff.z)))
		if absf(angle) > 135.0:
			arrow = "v"
		elif angle > 30.0:
			arrow = ">"
		elif angle < -30.0:
			arrow = "<"
	return "EXTRACT %s %dm" % [arrow, int(Vector2(to_dropoff.x, to_dropoff.z).length())]
