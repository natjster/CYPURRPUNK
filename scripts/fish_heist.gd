class_name FishHeist
extends Node3D
## FISH HEIST — the extraction loop: up the manhole, grab loot, find the exit, back down.
## Attach to the "Heist" node in main.tscn.
##
## THE STORY: OVERCLEAN, the AI, runs the city with its VAC-COP Roombas. The cat rebellion hides
## in the sewers. Each raid is on one DISTRICT (a city built from a seed). Don Catleone sends his
## cats up ONCE; the hatch shuts behind them and his crew digs for a new way back down. When
## everyone's home (or the heat maxes out) he seals that hole for good, and the rebellion moves
## on to a new district (in the code: a new city seed is generated).
##
## How a district plays:
##   - Cats start in the underground hub (hub.gd). Don Catleone sends them up the ENTRY manhole
##     in the centre crossroads. It's one-way: the only way back down is the EXIT manhole.
##   - ONE TRIP PER DISTRICT: once a cat has been up top (went_up), Don won't send it up again
##     until the next district, whether it extracted or got knocked out.
##   - Loot lies around the city, worth different amounts (each item card's cash_value):
##       SARDINE $20 (everywhere), FISH $50 (outside Meow-Mart and on some sidewalks), and the
##       GOLDEN KOI $400: only one in the city, far from Meow-Mart, glowing gold. It's HEAVY
##       (slows you) and NOISY (Roombas spot you from further). Taken loot grows back after a while.
##       WHAT lies WHERE is the loot table, res://loot/city.tres (placed by the Items node).
##   - The HEAT is the district's clock: it creeps up while anyone is up top (faster with trouble).
##   - At 3/4 heat (exit_opens_at_heat) Don's crew breaks through: the EXIT manhole opens,
##     somewhere random, and every PAYPHONE in the district rings. Payphones
##     (scripts/npcs/payphone.gd) are scattered too: call Don on one and he tells you where the
##     exit is; the HUD arrow switches on for the crew.
##   - Walk (or drive) onto the open exit: your loot pays its cash_value into YOUR cash
##     (the Wallet, scripts/wallet.gd), quests done at that moment pay their bonus, and you climb
##     down to the hub. That was your trip: wait there for the next district.
##   - (The HUD heat bar shows how close you are.) At 100 the hatch is SEALED and the DEEP CLEAN starts: a swarm of
##     VAC-COPs plus the MEGA VAC-COP. Anyone left up top is as good as dead (after
##     deep_clean_seconds they're knocked out no matter what, losing what they carry).
##     Then a NEW DISTRICT is built (new seed, heat back to 0) and Don can send you up again.
##
## Multiplayer: the HOST is the referee. It checks every frame who is standing on the open exit,
## empties their loot bag and tells everyone with an RPC. The extracted player's own computer
## then moves their cat down to the hub (owners always move their own cat).
## Manholes and payphones are placed from the city seed with their OWN random generator,
## so every computer places them identically and buildings never move. Whether the exit has been
## found (exit_revealed) and whether the hatch is sealed are decided by the host (_set_state).

@export_group("Manholes (the way in and out)")
## The EXIT manhole opens (lid off, climb down) once the heat reaches this (out of 100).
@export var exit_opens_at_heat: float = 75.0
## How close (metres) to the middle of the open exit manhole you must get to climb down.
@export var exit_radius: float = 1.6
## The exit is at least this far (metres) from the centre, where you come up.
@export var exit_min_distance: float = 60.0

@export_group("Payphones")
## How many payphones each district has (call Don on one to find the exit).
@export var payphones: int = 3
## Payphones are at least this far (metres) from each other...
@export var payphone_spacing: float = 45.0
## ...and from the centre, where you come up.
@export var payphone_min_distance: float = 25.0

@export_group("The DEEP CLEAN (max heat)")
## Once the hatch is sealed, the swarm hunts whoever is still up top for this many seconds.
## Then anyone still standing is knocked out anyway (loot lost), and a new district is built.
@export var deep_clean_seconds: float = 30.0
## After the DEEP CLEAN, wait this long (seconds) before building the next district, so
## knocked-out cats are back in the sewers first.
@export var new_district_delay: float = 6.0

## The one heist node (FishHeist.instance).
static var instance: FishHeist

## Mixed into the city seed so heist placement has its own random numbers.
const HEIST_SEED_SALT: int = 7331
const PAYPHONE_SCENE: PackedScene = preload("res://scenes/props/payphone.tscn")
## Where the entry manhole is: the middle of the centre crossroads, where Don sends you up.
const ENTRY_POSITION: Vector3 = Vector3(0, 0, 0)

@onready var city: CityGenerator = $"../City"
@onready var players: Node3D = $"../Players"
@onready var car: GetawayCar = $"../GetawayCar"

## Where the exit manhole is in the current district.
var exit_position: Vector3
## True once someone called Don on a payphone: the HUD arrow points at the exit (whole crew).
var exit_revealed: bool = false
## True from max heat until the new district is built: the hatch is shut, nobody gets out.
var sealed: bool = false
## Player ID -> true for everyone who has been up top in THIS district (their one trip is used:
## Don won't send them up again until the next one). Set by the host (_mark_went_up), copied to
## everyone; emptied for every new district (place_items).
var went_up := {}

var _built: Array[Node] = []  # manholes and payphones, so a new district can clear them
var _entry: Manhole
var _exit: Manhole
var _payphones: Array[Payphone] = []
var _clock: float = 0.0
## Host: player ID -> time until we ignore that cat at the exit (it's on its way down).
var _extract_wait := {}
## Host: when the DEEP CLEAN's time is up (knock out whoever is left), and when to build the
## next district. -1 = not yet.
var _deep_clean_ends_at: float = -1.0
var _new_district_at: float = -1.0


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	add_to_group("item_placers")  # the item system calls place_items() for every new city
	add_to_group(GameSystems.GROUP)  # late joiners / quitting players / new districts (game_systems.gd)


# --- Setting up a district (called by the item system for every new city, on every computer) ---

func place_items(items: ItemManager, city_seed: int) -> void:
	for node in _built:
		remove_child(node)  # out of the tree NOW, so the new district's "Payphone0" keeps its name
		node.queue_free()
	_built.clear()
	_payphones.clear()
	exit_revealed = false
	sealed = false
	went_up.clear()  # a new district: everyone gets a trip up again
	_deep_clean_ends_at = -1.0
	_new_district_at = -1.0

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(city_seed * 31 + HEIST_SEED_SALT)

	# The manholes: the way up (centre) and the way back (a random street far from the centre).
	_entry = _add_manhole(ENTRY_POSITION)
	exit_position = _random_street_spot(rng)
	for attempt in 40:
		if Motion.flat_distance(exit_position, ENTRY_POSITION) >= exit_min_distance:
			break
		exit_position = _random_street_spot(rng)
	_exit = _add_manhole(exit_position)

	# The payphones: on sidewalks, spread out, facing the street.
	var phone_spots: Array[Vector3] = []
	for spacing in [payphone_spacing, payphone_spacing * 0.5, 0.0]:  # relax the rules if the city is small
		for attempt in 60:
			if phone_spots.size() >= payphones:
				break
			var spot := items.random_sidewalk_spot(rng)
			var ok: bool = Motion.flat_distance(spot, ENTRY_POSITION) >= payphone_min_distance or spacing == 0.0
			for other in phone_spots:
				ok = ok and spot.distance_to(other) >= spacing
			if ok:
				phone_spots.append(spot)
	for i in phone_spots.size():
		var phone := PAYPHONE_SCENE.instantiate() as Payphone
		phone.name = "Payphone%d" % i  # (tests talk to it by name: --talk=Payphone0)
		phone.position = phone_spots[i]
		# Face the street: away from the middle of the block this sidewalk belongs to.
		var outward := _street_side_of(phone_spots[i])
		phone.rotation.y = atan2(outward.x, outward.z)
		_add_built(phone)
		_payphones.append(phone)
	print("[Heist] District #%d: exit manhole at %s, %d payphones" % [city_seed, exit_position, _payphones.size()])


func _add_manhole(at: Vector3) -> Manhole:
	var manhole := Manhole.new()
	manhole.position = at
	_add_built(manhole)
	return manhole


func _add_built(node: Node3D) -> void:
	add_child(node)
	_built.append(node)


## A random spot in the middle of a street, halfway along a block (not at a crossroads, where
## the street lamps and the cars' turns are).
func _random_street_spot(rng: RandomNumberGenerator) -> Vector3:
	var pitch := city.block_size + city.street_width
	var blocks := city.blocks_per_side
	var street := (rng.randi_range(0, blocks - 2) + 1 - blocks / 2.0) * pitch  # one of the streets
	var along := (rng.randi_range(0, blocks - 1) + 0.5 - blocks / 2.0) * pitch  # halfway along a block
	return Vector3(street, 0, along) if rng.randf() < 0.5 else Vector3(along, 0, street)


## Which way the street is from a sidewalk spot (away from the middle of its block).
func _street_side_of(spot: Vector3) -> Vector3:
	var pitch := city.block_size + city.street_width
	var blocks := city.blocks_per_side
	var block_x := (floorf(spot.x / pitch + blocks / 2.0) + 0.5 - blocks / 2.0) * pitch
	var block_z := (floorf(spot.z / pitch + blocks / 2.0) + 0.5 - blocks / 2.0) * pitch
	var away := Vector3(spot.x - block_x, 0, spot.z - block_z)
	if absf(away.x) > absf(away.z):
		return Vector3(signf(away.x), 0, 0)
	return Vector3(0, 0, signf(away.z))


# --- Questions anyone can ask ---

## Has this player already had their one trip up in this district?
func has_been_up(player_id: int) -> bool:
	return went_up.has(player_id)


## Has EVERY player in the game used their trip up? (Nobody left who could go up.)
func everyone_has_been_up() -> bool:
	for player_id in Game.instance.player_ids():
		if not went_up.has(player_id):
			return false
	return true


## Can you climb down the exit right now? (Heat high enough, hatch not sealed yet.)
func exit_is_open() -> bool:
	return not sealed and HeatMeter.instance != null and HeatMeter.instance.heat >= exit_opens_at_heat


## "north-east" etc.: which side of town the exit is on, seen from the centre (north = -Z, the way
## you face when you come up the entry manhole).
func exit_direction_name() -> String:
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var angle := atan2(exit_position.x, -exit_position.z)  # 0 = north, turning towards east
	return names[posmod(roundi(angle / (TAU / 8.0)), 8)]


# --- Every frame (every computer): how things look and sound ---

func _process(_delta: float) -> void:
	if _exit == null:
		return
	var open := exit_is_open()
	_exit.set_open(open)
	# The phones ring once the exit is open, until somebody picks up.
	for phone in _payphones:
		phone.set_ringing(open and not exit_revealed)
	_update_hud()


# --- The referee (host only) ---

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _exit == null:
		return
	_clock += delta

	# One trip per district: note everyone who has made it up top.
	for player_id in Game.instance.player_ids():
		if not went_up.has(player_id) and Game.instance.is_up_top(player_id):
			_mark_went_up.rpc(player_id)

	# Max heat: seal the hatch and start the DEEP CLEAN.
	if not sealed and HeatMeter.instance.heat >= HeatMeter.MAX_HEAT:
		_deep_clean_ends_at = _clock + deep_clean_seconds
		_set_state.rpc(true, exit_revealed)  # (announces Events.district_sealed: the swarm comes)
		print("[Heist] Hatch SEALED: the DEEP CLEAN begins")
	if sealed:
		_run_deep_clean()
		return
	if not exit_is_open():
		return

	var items := ItemManager.instance
	for player_id in Game.instance.player_ids():
		var their_car := Game.instance.car_of(player_id)  # null = on foot
		var where := Game.instance.player_position(player_id)
		if not Game.instance.is_up_top(player_id) or _clock < _extract_wait.get(player_id, 0.0):
			continue
		if CatHealth.instance.is_down(player_id):
			continue  # knocked out: no flopping into the hole to save your stuff
		if Motion.flat_distance(where, exit_position) >= exit_radius + (1.5 if their_car != null else 0.0):
			continue
		# Extract! Ignore this cat for a moment while its new position arrives from its owner.
		_extract_wait[player_id] = _clock + 3.0
		# Quests first, while the loot is still in the bag (e.g. Mittens wants 3 fish IN it).
		var quest_bonus: int = QuestManager.instance.complete_on_extract(player_id)[0]
		var loot := items.take_bag(player_id) if items.bag_used(player_id) > 0 else []
		var earned := 0
		for item_id in loot:
			earned += (items.catalog[item_id] as ItemData).cash_value
		if their_car != null:
			their_car.remove_occupant(player_id)  # out of the car first...
			# ...and once the last cat is out it waits at its parking spot for the next trip up.
			# (Everyone in the car is at the beam, so the passengers extract this same frame.)
			if their_car.driver_id == 0 and their_car.passenger_ids.is_empty():
				their_car.park()
		Wallet.instance.earn(player_id, earned + quest_bonus, "extracted %d loot" % loot.size())
		_extracted.rpc(player_id, earned, quest_bonus)


## Host, while sealed: when time's up, whoever is still up top goes down (loot and all), then a
## new district is built.
func _run_deep_clean() -> void:
	# Nobody up top (everyone extracted / knocked out)? No point waiting: end it now.
	if _deep_clean_ends_at >= 0.0 and Game.instance.players_up_top() == 0:
		_deep_clean_ends_at = _clock
	if _deep_clean_ends_at >= 0.0 and _clock >= _deep_clean_ends_at:
		_deep_clean_ends_at = -1.0
		car.empty_car()  # nobody escapes in the car either (driver or passengers)
		for player_id in Game.instance.player_ids():
			if Game.instance.is_up_top(player_id):
				CatHealth.instance.damage(player_id, 99999, "THE DEEP CLEAN", true)  # (true: no downed stage)
		_new_district_at = _clock + new_district_delay
	if _new_district_at >= 0.0 and _clock >= _new_district_at:
		_new_district_at = -1.0
		Game.instance.new_district()  # a new city seed for everyone; place_items() resets us


## A payphone call (any computer -> host): switch the exit arrow on for the whole crew.
@rpc("any_peer", "call_local", "reliable")
func request_reveal_exit(player_id: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	if exit_is_open() and not exit_revealed:
		print("[Heist] Player %d called Don: the exit is revealed" % player_id)
		_set_state.rpc(sealed, true)


## Host -> everyone: is the hatch sealed, and does the crew know where the exit is?
@rpc("authority", "call_local", "reliable")
func _set_state(is_sealed: bool, revealed: bool) -> void:
	var newly_sealed := is_sealed and not sealed
	sealed = is_sealed
	exit_revealed = revealed
	if newly_sealed:
		Sound.play("boss_siren")
		Hud.show_message("THE HATCH IS SEALED.\nOVERCLEAN IS DEEP CLEANING THIS DISTRICT.", 6.0)
		Events.district_sealed.emit()  # (scripts/events.gd: the Roomba patrol sends the swarm)


# --- What the host tells everyone (runs on every computer) ---

## earned = what the loot was worth; quest_bonus = extra cash from quests finished just now.
@rpc("authority", "call_local", "reliable")
func _extracted(player_id: int, earned: int, quest_bonus: int = 0) -> void:
	Events.player_extracted.emit(player_id, earned, quest_bonus)  # (scripts/events.gd)
	if not PlayerId.is_local(player_id):
		return  # someone else's cat: their computer moves it
	var popup_text := ("EXTRACTED +$%d" % earned) if earned > 0 else "EXTRACTED"
	if quest_bonus > 0:
		popup_text += "\nQUEST DONE +$%d" % quest_bonus
	Hud.popup(popup_text, 2.5, PlayerId.slot_of(player_id))  # big fading text on THEIR screen (scripts/ui/hud.gd)
	Sound.play("extract")
	Seats.rumble(player_id, 0.5, 0.2, 0.3)  # a happy buzz on their controller
	var cat := Game.instance.cat_for(player_id)
	if cat != null:
		UndergroundHub.instance.return_cat(cat)  # down the drain we go


## Host -> everyone: this player has used their one trip up in this district.
@rpc("authority", "call_local", "reliable")
func _mark_went_up(player_id: int) -> void:
	went_up[player_id] = true


## Host -> a computer that just joined (network ID "peer"): whether the exit is found / the
## hatch sealed, and who has already been up.
func send_state_to(peer: int) -> void:
	_set_state.rpc_id(peer, sealed, exit_revealed)
	for player_id in went_up:
		_mark_went_up.rpc_id(peer, player_id)


# --- HUD (the arrow to the exit: scenes/ui/hud.tscn. Everyone's cash is the Wallet's.) ---

## Every player on this computer gets their own lines on their own HUD (split screen).
func _update_hud() -> void:
	if Game.instance == null:
		return
	for cat in Game.instance.playing_cats():
		_update_hud_for(cat)


func _update_hud_for(my_cat: CatPlayer) -> void:
	var me := my_cat.player_id
	var seat := my_cat.slot
	var where := Game.instance.player_position(me)
	var in_sewers := not Game.instance.is_up_top(me)
	# The arrow to the exit only shows once Don has told the crew where it is (a payphone call).
	if in_sewers:
		Hud.show_element("DropOff", true, seat)
		Hud.set_text("DropOff", "THE SEWERS - WAIT FOR THE NEXT DISTRICT" if has_been_up(me) else "THE SEWERS - SAFE ZONE", seat)
	else:
		var show_arrow := exit_revealed and exit_is_open()
		Hud.show_element("DropOff", show_arrow, seat)
		if show_arrow:
			Hud.set_text("DropOff", _direction_text(where, GameScreen.instance.camera_for_seat(seat)), seat)


## "EXIT > 120m": distance and rough direction to the exit manhole from where the camera looks.
func _direction_text(where: Vector3, camera: Camera3D) -> String:
	var to_exit := exit_position - where
	var arrow := "^"
	if camera != null:
		var look := -camera.global_transform.basis.z
		var angle := rad_to_deg(Vector2(look.x, look.z).angle_to(Vector2(to_exit.x, to_exit.z)))
		if absf(angle) > 135.0:
			arrow = "v"
		elif angle > 30.0:
			arrow = ">"
		elif angle < -30.0:
			arrow = "<"
	return "EXIT %s %dm" % [arrow, int(Vector2(to_exit.x, to_exit.z).length())]
