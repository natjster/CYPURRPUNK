class_name FishHeist
extends Node3D
## FISH HEIST — the extraction loop: go up, grab loot, reach a beam, get paid, back down.
## Attach to the "Heist" node in main.tscn.
##
## How it plays:
##   - Cats start in the underground hub (hub.gd). Don Catleone sends them up to the city.
##   - Loot lies around the city, worth different amounts (each item card's cash_value):
##       SARDINE $20 (everywhere), FISH $50 (outside Meow-Mart and on some sidewalks), and the
##       GOLDEN KOI $400: only one in the city, far from Meow-Mart, glowing gold. It's HEAVY
##       (slows you), NOISY (Roombas spot you from further) and grabbing it raises the HEAT
##       (scripts/heat_meter.gd) and tells everyone who took it. Greed has a price!
##   - Walk into loot to pick it up automatically. Loot is handled by the item system
##     (items/*.tres), so it goes in your loot bag and shows on your cat.
##   - Reach an OPEN EXTRACTION BEAM (tall green light), on foot or by car. There are several
##     beam spots around the city; only a couple are open at a time. Each stays open for a
##     while, BLINKS when it's about to close, then shuts and another one opens somewhere else.
##     The HUD arrow always points at the nearest open beam.
##     Every piece of loot pays its card's cash_value into YOUR cash (cash is per player),
##     and you're sent back down to the hub — with or without loot.
##     Quests done at that moment (quest_manager.gd, e.g. Lil' Mittens' 3 fish) pay their
##     bonus on top. Extracting also cools the HEAT a little.
##     If you were driving, the getaway car goes back to its parking spot for the next trip.
##   - Taken loot grows back at its spot after a while.
##
## Multiplayer: the HOST is the referee. It checks every frame who is standing in an open
## beam, empties their loot bag and tells everyone with an RPC. The extracted player's own
## computer then moves their cat down to the hub (owners always move their own cat).
## Loot spots and beam spots are picked from the city seed with their OWN random
## generator, so every computer places them identically and buildings never move.
## WHICH beams are open is decided by the host alone and sent to everyone (_set_beams).

@export_group("Loot")
## Which item card is placed outside Meow-Mart (and counted by quests like Mittens').
@export var loot_item: String = "fish"
## Fish waiting outside Meow-Mart.
@export var meow_mart_fish: int = 5
## Extra fish scattered on sidewalks around the city.
@export var street_fish: int = 5
## Cheap sardines scattered on sidewalks around the city.
@export var street_sardines: int = 8
## How many golden koi are hidden in the city (the big $400 prize).
@export var golden_koi: int = 1
## Seconds before taken fish and sardines appear again at their spot.
@export var respawn_seconds: float = 20.0
## Seconds before a taken golden koi appears again.
@export var koi_respawn_seconds: float = 120.0
## Golden koi are placed at least this far (metres) from Meow-Mart, so you have to travel.
@export var koi_min_distance: float = 60.0

@export_group("Extraction beams")
## How close (metres) to a beam you must get to hand in your loot.
@export var dropoff_radius: float = 4.0
## How many beam spots the city has (at crossroads, spread out).
@export var beam_spots: int = 4
## How many beams are open at the same time.
@export var open_at_once: int = 2
## Each beam stays open for a random time between these (seconds).
@export var beam_open_min_seconds: float = 40.0
@export var beam_open_max_seconds: float = 70.0
## For this many seconds before it closes, a beam blinks (and its sign counts down).
@export var beam_warning_seconds: float = 10.0
## Beam spots are at least this far from Meow-Mart (where most fish are).
@export var min_dropoff_distance: float = 40.0
## ...and at least this far from each other.
@export var beam_spacing: float = 50.0
@export var beam_color: Color = Color(0.2, 1, 0.45)

## The one heist node, so the shop can reach everyone's cash (FishHeist.instance).
static var instance: FishHeist

## Mixed into the city seed so heist placement has its own random numbers.
const HEIST_SEED_SALT: int = 7331

@onready var city: CityGenerator = $"../City"
@onready var players: Node3D = $"../Players"
@onready var car: GetawayCar = $"../GetawayCar"

## Where every beam spot is in the current city.
var beam_positions: Array[Vector3] = []
## For each beam spot: seconds until it closes, or -1 if it's closed. (The host's copy is the
## real one; everyone else counts their copy down between the host's updates.)
var beam_time_left: Array[float] = []
## Network ID -> cash. Everyone keeps a copy; only the host changes it (via RPC).
var cash := {}

var _built: Array[Node] = []  # the beam pieces, so a new city can clear them
var _beams: Array[Dictionary] = []  # per beam spot: {"shine", "posts", "sign"} (see _build_beam)
var _clock: float = 0.0
## Host: network ID -> time until we ignore that cat at the beam (it's on its way down).
var _extract_wait := {}
var _beam_rng := RandomNumberGenerator.new()  # host: which beam opens next (NOT the city seed)


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	add_to_group("item_placers")  # the item system calls place_items() for every new city
	_beam_rng.randomize()


# --- Setting up the heist for a city (called by the item system, on every computer) ---

func place_items(items: ItemManager, city_seed: int) -> void:
	for node in _built:
		node.queue_free()
	_built.clear()
	_beams.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(city_seed * 31 + HEIST_SEED_SALT)

	# A row of fish on the sidewalk outside Meow-Mart's door.
	var door := city.meow_mart_position
	for i in meow_mart_fish:
		items.add_spawn_point(loot_item, door + Vector3((i - (meow_mart_fish - 1) / 2.0) * 1.3, 0, -0.5), respawn_seconds)
	# Fish and sardines dropped on random sidewalks around the city.
	for i in street_fish:
		items.add_spawn_point(loot_item, items.random_sidewalk_spot(rng), respawn_seconds)
	for i in street_sardines:
		items.add_spawn_point("sardine", items.random_sidewalk_spot(rng), respawn_seconds)
	# The golden koi: somewhere far from Meow-Mart.
	for i in golden_koi:
		var spot := items.random_sidewalk_spot(rng)
		for attempt in 20:
			if spot.distance_to(door) >= koi_min_distance:
				break
			spot = items.random_sidewalk_spot(rng)
		items.add_spawn_point("golden_koi", spot, koi_respawn_seconds)

	# The beam spots: crossroads far from Meow-Mart and spread apart, in a seeded random order.
	var pitch := city.block_size + city.street_width
	var blocks := city.blocks_per_side
	var crossroads: Array[Vector3] = []
	for ix in blocks - 1:
		for iz in blocks - 1:
			var spot := Vector3((ix + 1 - blocks / 2.0) * pitch, 0, (iz + 1 - blocks / 2.0) * pitch)
			if spot.length() > 1.0:  # not the centre crossroads, where cats arrive from the hub
				crossroads.append(spot)
	# Shuffle with OUR random generator (Array.shuffle() would differ between computers).
	for i in range(crossroads.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := crossroads[i]
		crossroads[i] = crossroads[j]
		crossroads[j] = swap
	beam_positions.clear()
	for spacing in [beam_spacing, beam_spacing * 0.6, 0.0]:  # relax the rules if the city is too small
		for spot in crossroads:
			if beam_positions.size() >= beam_spots:
				break
			var ok: bool = spot.distance_to(door) >= min_dropoff_distance or spacing == 0.0
			for other in beam_positions:
				ok = ok and spot.distance_to(other) >= maxf(spacing, 1.0)
			if ok:
				beam_positions.append(spot)
	beam_time_left.clear()
	for spot in beam_positions:
		_build_beam(spot)
		beam_time_left.append(-1.0)

	# The host opens the first beams (staggered, so they don't all close at once).
	if multiplayer.is_server():
		for n in mini(open_at_once, beam_positions.size()):
			_open_random_beam(-1, (n + 1.0) / open_at_once)
		_set_beams.rpc(beam_time_left)


## Tall glowing beam you can see over the rooftops, a ring of glowing posts, a light and a sign.
## The beam, light and sign ("shine") only show while the beam is open; the posts always show
## (dim when closed), so you learn where the beam spots are.
func _build_beam(at: Vector3) -> void:
	var shine := Node3D.new()
	shine.position = at
	_add_built(shine)

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
	beam.position = Vector3(0, 30, 0)
	shine.add_child(beam)

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
	light.position = Vector3(0, 2.5, 0)
	shine.add_child(light)

	var sign_label := Label3D.new()
	sign_label.text = "EXTRACTION\n$ OPEN $"
	sign_label.font_size = 48
	sign_label.pixel_size = 0.02
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sign_label.modulate = Color(beam_color * 2.5, 1)
	sign_label.position = Vector3(0, 4.5, 0)
	shine.add_child(sign_label)

	_beams.append({"shine": shine, "posts": post_material, "sign": sign_label})


func _add_built(node: Node3D) -> void:
	add_child(node)
	_built.append(node)


## Is beam number "index" open right now?
func is_beam_open(index: int) -> bool:
	return index < beam_time_left.size() and beam_time_left[index] > 0.0


## The nearest OPEN beam to a spot: its index, or -1 if none is open.
func nearest_open_beam(where: Vector3) -> int:
	var best := -1
	for i in beam_positions.size():
		if not is_beam_open(i):
			continue
		if best == -1 or _flat_distance(where, beam_positions[i]) < _flat_distance(where, beam_positions[best]):
			best = i
	return best


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Host: open a random CLOSED beam (not "skip"). "fraction" shortens its first opening
## (used at the start so the first beams don't all close together).
func _open_random_beam(skip: int, fraction: float = 1.0) -> void:
	var closed: Array[int] = []
	for i in beam_positions.size():
		if not is_beam_open(i) and i != skip:
			closed.append(i)
	if closed.is_empty():
		if skip < 0:
			return
		closed.append(skip)  # only one beam spot in the whole city: reopen it
	var pick := closed[_beam_rng.randi_range(0, closed.size() - 1)]
	var seconds := _beam_rng.randf_range(beam_open_min_seconds, beam_open_max_seconds) * fraction
	beam_time_left[pick] = maxf(seconds, beam_warning_seconds + 5.0)
	print("[Heist] Extraction beam %d opened for %ds (closed: %d)" % [pick, int(beam_time_left[pick]), skip])


# --- Every frame ---

func _process(delta: float) -> void:
	# Everyone but the host counts their copy of the beam timers down between host updates.
	if not multiplayer.is_server():
		for i in beam_time_left.size():
			if beam_time_left[i] > 0.0:
				beam_time_left[i] = maxf(beam_time_left[i] - delta, 0.01)  # the host decides when it shuts
	_update_beam_looks()
	_update_hud()


## Open beams shine; closing beams blink and count down; closed beams are just dim posts.
func _update_beam_looks() -> void:
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25
	for i in _beams.size():
		var beam: Dictionary = _beams[i]
		var open := is_beam_open(i)
		var closing := open and beam_time_left[i] < beam_warning_seconds
		(beam.shine as Node3D).visible = open and not (closing and blink)
		(beam.sign as Label3D).text = ("EXTRACTION\nCLOSING %d" % ceili(beam_time_left[i])) if closing else "EXTRACTION\n$ OPEN $"
		(beam.posts as StandardMaterial3D).albedo_color = beam_color * 2.5 if open else Color(0.15, 0.2, 0.17)


## Host only: the referee. Beam timers, and who reached an open beam?
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_clock += delta

	# Beams close when their time runs out, and another one opens somewhere else.
	var changed := false
	for i in beam_time_left.size():
		if beam_time_left[i] > 0.0:
			beam_time_left[i] -= delta
			if beam_time_left[i] <= 0.0:
				beam_time_left[i] = -1.0
				_open_random_beam(i)
				changed = true
	if changed:
		_set_beams.rpc(beam_time_left)

	var items := ItemManager.instance
	for node in players.get_children():
		var peer_id := node.name.to_int()
		var driving := car.driver_id == peer_id
		var where: Vector3 = car.global_position if driving else (node as Node3D).global_position
		if UndergroundHub.is_in_hub(where) or _clock < _extract_wait.get(peer_id, 0.0):
			continue
		if CatHealth.instance.is_down(peer_id):
			continue  # knocked out: no flopping into the beam to save your stuff
		var beam := nearest_open_beam(where)
		if beam == -1 or _flat_distance(where, beam_positions[beam]) >= dropoff_radius:
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
		HeatMeter.instance.add_heat(-HeatMeter.instance.cool_per_extraction)  # the cops lose your trail
		_extracted.rpc(peer_id, earned, loot.size(), quest_bonus)


## Host -> everyone: how long each beam stays open (-1 = closed).
@rpc("authority", "call_local", "reliable")
func _set_beams(times: Array) -> void:
	for i in mini(times.size(), beam_time_left.size()):
		beam_time_left[i] = times[i]


# --- What the host tells everyone (runs on every computer) ---

## earned = what the loot was worth; quest_bonus = extra cash from quests finished just now.
@rpc("authority", "call_local", "reliable")
func _extracted(peer_id: int, earned: int, count: int, quest_bonus: int = 0) -> void:
	cash[peer_id] = cash.get(peer_id, 0) + earned + quest_bonus
	print("[Heist] Player %d extracted with %d loot for $%d + quest bonus $%d (total $%d)" % [peer_id, count, earned, quest_bonus, cash[peer_id]])
	if peer_id == multiplayer.get_unique_id():
		var popup_text := ("EXTRACTED +$%d" % earned) if earned > 0 else "EXTRACTED"
		if quest_bonus > 0:
			popup_text += "\nQUEST DONE +$%d" % quest_bonus
		Hud.popup(popup_text, 2.5)  # the big text that fades out (scripts/ui/hud.gd)
		Sound.play("extract")
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


## Host -> a player who just joined: everyone's cash, and which extraction beams are open.
func send_state_to(peer_id: int) -> void:
	_receive_state.rpc_id(peer_id, cash)
	_set_beams.rpc_id(peer_id, beam_time_left)


@rpc("authority", "call_remote", "reliable")
func _receive_state(cash_now: Dictionary) -> void:
	cash = cash_now


## Host: a player quit. Their cash goes with them.
func player_left(peer_id: int) -> void:
	_forget_player.rpc(peer_id)


@rpc("authority", "call_local", "reliable")
func _forget_player(peer_id: int) -> void:
	cash.erase(peer_id)


# --- HUD (your cash, your loot, where to go, everyone's cash: scenes/ui/hud.tscn) ---

func _update_hud() -> void:
	var me := multiplayer.get_unique_id()
	var my_cat := players.get_node_or_null(str(me)) as CatPlayer
	if my_cat == null:
		return
	var items := ItemManager.instance
	Hud.set_text("Cash", "$%d" % cash.get(me, 0))
	# Under the cash: your quest's progress (e.g. "QUEST: MITTENS' FISH 2/3") if you have one,
	# otherwise how full your loot bag is.
	var quest_line := QuestManager.instance.hud_text(me)
	if quest_line != "":
		Hud.set_text("Carrying", "QUEST: " + quest_line)
	else:
		var used := items.bag_used(me)
		var worth := 0
		for item_id in items.get_inventory(me).bag:
			worth += (items.catalog[item_id] as ItemData).cash_value
		var notes := ""
		if used >= items.bag_size:
			notes += "  FULL!"
		if items.carry_speed(me) < 1.0:
			notes += "  HEAVY!"
		Hud.set_text("Carrying", "LOOT %d/%d ($%d)%s" % [used, items.bag_size, worth, notes])

	# Distance and rough direction to the extraction beam, relative to where the camera looks.
	# Down in the hub there's no beam to point at.
	var where := car.global_position if car.driver_id == me else my_cat.global_position
	if UndergroundHub.is_in_hub(where):
		Hud.set_text("DropOff", "THE SEWERS - SAFE ZONE")
	else:
		Hud.set_text("DropOff", _direction_text(where))

	# Everyone's cash, richest first.
	var rows: Array = []
	for node in players.get_children():
		var cat := node as CatPlayer
		rows.append([cash.get(cat.name.to_int(), 0), cat.get_node("NameTag").text if cat.name.to_int() != me else "YOU"])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var lines := PackedStringArray()
	for row in rows:
		lines.append("%s $%d" % [row[1], row[0]])
	Hud.set_text("Scoreboard", "\n".join(lines))


## "EXTRACT > 120m": distance and rough direction to the nearest OPEN beam from where the
## camera looks. Adds "CLOSING 7s" when that beam is about to shut.
func _direction_text(where: Vector3) -> String:
	var beam := nearest_open_beam(where)
	if beam == -1:
		return "NO EXTRACTION OPEN"
	var to_dropoff := beam_positions[beam] - where
	var closing := ""
	if beam_time_left[beam] < beam_warning_seconds:
		closing = "  CLOSING %ds!" % ceili(beam_time_left[beam])
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
	return "EXTRACT %s %dm%s" % [arrow, int(Vector2(to_dropoff.x, to_dropoff.z).length()), closing]
