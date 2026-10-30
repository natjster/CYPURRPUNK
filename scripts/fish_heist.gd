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
## TWO GANGS (scripts/teams.gd): each gang has its OWN entry manhole (opposite corners of the city,
## entry_position: Catleone Family south-west, Burrow Gang north-east, so nobody pops up in the
## rival's lap), its OWN exit (exit_for, glowing in its gang colour; you can only climb down your
## own), and its OWN payphone call (a call shows the exit arrow to the caller's gang only, and the
## boss on the line is your own: Don or Pawnie). The getaway car waits in the middle, for whoever
## gets there first.
##
## How a district plays:
##   - Cats start in their gang's hub (hub.gd). The boss sends them up their gang's ENTRY manhole.
##     It's one-way: the only way back down is their gang's EXIT manhole.
##   - ONE TRIP PER DISTRICT: once a cat has been up top (went_up), Don won't send it up again
##     until the next district, whether it extracted or got knocked out.
##   - Loot lies around the city, worth different amounts (each item card's cash_value):
##       SARDINE $20 (everywhere), FISH $50 (outside Meow-Mart and on some sidewalks), and the
##       GOLDEN KOI $400: only one in the city, far from Meow-Mart, glowing gold. It's HEAVY
##       (slows you) and NOISY (Roombas spot you from further). Taken loot grows back after a while.
##       WHAT lies WHERE is the loot table, res://loot/city.tres (placed by the Items node).
##       SCRAP isn't on the street: only a destroyed MEGA VAC-COP drops it. It's worth $0 here
##       (it stays in your bag at the exit) - it's fuel for THE MAINFRAME (scripts/mainframe.gd).
##   - The HEAT is the district's clock: it creeps up while anyone is up top (faster with trouble).
##   - At the heat its own MAINFRAME says (scripts/mainframe.gd exit_heat: 60 / 75 / 82 / 90 / 95)
##     a gang's crew breaks through: its EXIT manhole opens, somewhere random, and every PAYPHONE
##     in the district rings. Once open it stays open for the district. Payphones
##     (scripts/npcs/payphone.gd) are scattered too: call your boss on one and they tell you where
##     your exit is; the HUD arrow switches on for your gang. The phones ring until every gang
##     in the game has called.
##   - Walk (or drive) onto the open exit: your loot pays its cash_value into YOUR cash
##     (the Wallet, scripts/wallet.gd), quests done at that moment pay their bonus, and you climb
##     down to the hub. That was your trip: wait there for the next district.
##   - (The HUD heat bar shows how close you are.) At 100 the hatch is SEALED and the DEEP CLEAN starts: a swarm of
##     VAC-COPs plus the MEGA VAC-COP. Anyone left up top is as good as dead (after
##     deep_clean_seconds they're knocked out no matter what, losing what they carry).
##     Then a NEW DISTRICT is built (new seed, heat back to where THE MAINFRAME says) and Don can send you up again.
##
## Multiplayer: the HOST is the referee. It checks every frame who is standing on the open exit,
## empties their loot bag and tells everyone with an RPC. The extracted player's own computer
## then moves their cat down to the hub (owners always move their own cat).
## Manholes and payphones are placed from the city seed with their OWN random generator,
## so every computer places them identically and buildings never move. Which gangs have found
## their exit (revealed) and whether the hatch is sealed are decided by the host (_set_state).

@export_group("Manholes (the way in and out)")
## How close (metres) to the middle of the open exit manhole you must get to climb down.
@export var exit_radius: float = 1.6
## Every exit is at least this far (metres) from every gang's entry manhole...
@export var exit_min_distance: float = 60.0
## ...and the gangs' exits are at least this far from each other.
@export var exit_spacing: float = 45.0

@export_group("Payphones")
## How many payphones each district has (call Don on one to find the exit).
@export var payphones: int = 3
## Payphones are at least this far (metres) from each other...
@export var payphone_spacing: float = 45.0
## ...and from every entry manhole, where cats come up.
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
## The usual colour of the HUD's top line (scenes/ui/hud.tscn, DropOff).
const DROP_OFF_COLOR := Color(0.45, 1, 0.55, 1)

@onready var city: CityGenerator = $"../City"
@onready var players: Node3D = $"../Players"

## Where each gang's exit manhole is in the current district (by team number: exit_for(team)).
var exit_positions: Array[Vector3] = []
## Per gang: true once someone in that gang called their boss on a payphone (the HUD arrow then
## points that gang at its exit). By team number: is_revealed(team).
var revealed: Array[bool] = []
## Per gang: true once that gang's exit has opened in this district. It stays open, even if a
## rival's hack pushes that gang's exit heat back up.
var exit_opened: Array[bool] = []
## True from max heat until the new district is built: the hatch is shut, nobody gets out.
var sealed: bool = false
## Player ID -> true for everyone who has been up top in THIS district (their one trip is used:
## Don won't send them up again until the next one). Set by the host (_mark_went_up), copied to
## everyone; emptied for every new district (place_items).
var went_up := {}

var _built: Array[Node] = []  # manholes and payphones, so a new district can clear them
var _exits: Array[Manhole] = []  # by team number
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
	_exits.clear()
	exit_positions.clear()
	revealed.clear()
	exit_opened.clear()
	sealed = false
	went_up.clear()  # a new district: everyone gets a trip up again
	_deep_clean_ends_at = -1.0
	_new_district_at = -1.0

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(city_seed * 31 + HEIST_SEED_SALT)

	# The manholes. Every gang's way UP (its own corner of the city; SOLO: one, in the centre)...
	var entries: Array[Vector3] = []
	for team in Teams.count():
		entries.append(entry_position(team))
		if team == 0 or entries[team] != entries[0]:  # (solo: don't stack two lids on one spot)
			_add_manhole(entries[team], Teams.color_of(team))
	# ...and its way back DOWN: a random street far from every entry and from the other exits.
	# (SOLO: just one exit, the Catleone Family's. exit_for() hands it to anyone who asks.)
	var solo := Game.instance != null and Game.instance.is_solo()
	for team in (1 if solo else Teams.count()):
		var spot := _random_street_spot(rng)
		for attempt in 60:
			var ok := true
			for entry in entries:
				ok = ok and Motion.flat_distance(spot, entry) >= exit_min_distance
			for other in exit_positions:
				ok = ok and Motion.flat_distance(spot, other) >= exit_spacing
			if ok:
				break
			spot = _random_street_spot(rng)
		exit_positions.append(spot)
		revealed.append(false)
		exit_opened.append(false)
		_exits.append(_add_manhole(spot, Teams.color_of(team)))

	# The payphones: on sidewalks, spread out, facing the street.
	var phone_spots: Array[Vector3] = []
	for spacing in [payphone_spacing, payphone_spacing * 0.5, 0.0]:  # relax the rules if the city is small
		for attempt in 60:
			if phone_spots.size() >= payphones:
				break
			var spot := items.random_sidewalk_spot(rng)
			var ok: bool = true
			for entry in entries:
				ok = ok and (Motion.flat_distance(spot, entry) >= payphone_min_distance or spacing == 0.0)
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
	print("[Heist] District #%d: entries %s, exits %s, %d payphones" % [city_seed, entries, exit_positions, _payphones.size()])


func _add_manhole(at: Vector3, glow: Color) -> Manhole:
	var manhole := Manhole.new()
	manhole.position = at
	manhole.glow_color = glow
	_add_built(manhole)
	return manhole


## Where a gang's ENTRY manhole is: the middle of the city's outermost crossroads, a different
## corner for each gang (0 = south-west, 1 = north-east; a third gang would get the middle).
## Worked out from the city's size, so it's always on a street.
func entry_position(team: int) -> Vector3:
	if Game.instance != null and Game.instance.is_solo():
		return Vector3.ZERO  # SOLO: the classic single manhole in the centre crossroads (game.gd)
	return corner_position(team)


## A gang's own corner crossroads (where its manhole is in co-op; its car parks near it).
func corner_position(team: int) -> Vector3:
	var reach := (city.blocks_per_side / 2.0 - 1.0) * (city.block_size + city.street_width)
	match team:
		Teams.CATLEONE:
			return Vector3(-reach, 0, reach)
		Teams.BURROW:
			return Vector3(reach, 0, -reach)
	return Vector3.ZERO


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
## No players at all (the start menu) = false: otherwise the heat raced up behind the menu,
## playing the heat alarm over and over (heat_meter.gd).
func everyone_has_been_up() -> bool:
	if Game.instance.player_ids().is_empty():
		return false
	for player_id in Game.instance.player_ids():
		if not went_up.has(player_id):
			return false
	return true


## Can this gang climb down its exit right now? (Heat high enough for ITS Mainframe, or it already
## opened this district, and the hatch isn't sealed yet.)
func exit_is_open(team: int) -> bool:
	if sealed or HeatMeter.instance == null or Mainframe.instance == null:
		return false
	if team >= 0 and team < exit_opened.size() and exit_opened[team]:
		return true
	return HeatMeter.instance.heat >= Mainframe.instance.exit_heat(team)


## Is the exit open for every gang in the game? (Then a sewer full of cats can hurry the heat on
## without taking a gang's chance at its later exit away: heat_meter.gd.)
func every_exit_is_open() -> bool:
	for team in Mainframe.instance.active_gangs():
		if not exit_is_open(team):
			return false
	return true


## Where this gang's exit manhole is.
func exit_for(team: int) -> Vector3:
	return exit_positions[clampi(team, 0, exit_positions.size() - 1)] if not exit_positions.is_empty() else Vector3.ZERO


## Has this gang called their boss yet (so its exit arrow is on)?
func is_revealed(team: int) -> bool:
	return team >= 0 and team < revealed.size() and revealed[team]


## "north-east" etc.: which side of town this gang's exit is on, seen from the centre (north = -Z).
func exit_direction_name(team: int) -> String:
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var at := exit_for(team)
	var angle := atan2(at.x, -at.z)  # 0 = north, turning towards east
	return names[posmod(roundi(angle / (TAU / 8.0)), 8)]


## The gangs that have at least one player UP TOP right now (the only ones who still need a call:
## a gang that's all home, or all knocked out, can't use its exit any more).
func _gangs_up_top() -> Array[int]:
	var gangs: Array[int] = []
	for player_id in Game.instance.player_ids():
		var team := Teams.team_of(player_id)
		if not team in gangs and Game.instance.is_up_top(player_id):
			gangs.append(team)
	return gangs


# --- Every frame (every computer): how things look and sound ---

func _process(_delta: float) -> void:
	if _exits.is_empty():
		return
	for team in _exits.size():
		var open := exit_is_open(team)
		exit_opened[team] = exit_opened[team] or open
		_exits[team].set_open(open)
	# The phones ring while a gang up top has an open exit and hasn't called its boss yet.
	var someone_waiting := false
	for team in _gangs_up_top():
		someone_waiting = someone_waiting or (exit_is_open(team) and not is_revealed(team))
	for phone in _payphones:
		phone.set_ringing(someone_waiting)
	_update_hud()


# --- The referee (host only) ---

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _exits.is_empty():
		return
	# A SEWER BREACH (scripts/mainframe.gd): no sealing and no new district until it's over. It
	# starts the next district itself, which resets everything here (place_items).
	if Mainframe.instance.breach_busy:
		return
	_clock += delta

	# One trip per district: note everyone who has made it up top.
	for player_id in Game.instance.player_ids():
		if not went_up.has(player_id) and Game.instance.is_up_top(player_id):
			_mark_went_up.rpc(player_id)

	# Max heat: seal the hatch and start the DEEP CLEAN.
	if not sealed and HeatMeter.instance.heat >= HeatMeter.MAX_HEAT:
		_deep_clean_ends_at = _clock + deep_clean_seconds
		_set_state.rpc(true, revealed, exit_opened)  # (announces Events.district_sealed: the swarm comes)
		print("[Heist] Hatch SEALED: the DEEP CLEAN begins")
	if sealed:
		_run_deep_clean()
		return

	var items := ItemManager.instance
	for player_id in Game.instance.player_ids():
		var their_car := Game.instance.car_of(player_id)  # null = on foot
		var where := Game.instance.player_position(player_id)
		if not Game.instance.is_up_top(player_id) or _clock < _extract_wait.get(player_id, 0.0):
			continue
		if not exit_is_open(Teams.team_of(player_id)):
			continue  # this gang's crew hasn't broken through yet
		if CatHealth.instance.is_down(player_id):
			continue  # knocked out: no flopping into the hole to save your stuff
		# Only YOUR gang's exit takes you down (the rival's is just a hole in the road to you).
		if Motion.flat_distance(where, exit_for(Teams.team_of(player_id))) >= exit_radius + (1.5 if their_car != null else 0.0):
			continue
		# Extract! Ignore this cat for a moment while its new position arrives from its owner.
		_extract_wait[player_id] = _clock + 3.0
		# Quests first, while the loot is still in the bag (e.g. Mittens wants 3 fish IN it).
		var quest_bonus: int = QuestManager.instance.complete_on_extract(player_id)[0]
		# Only MONEY loot is cashed in; SCRAP ($0) stays in the bag for THE MAINFRAME / the stash.
		var loot := items.take_cash_loot(player_id) if items.bag_used(player_id) > 0 else []
		var earned := 0
		for item_id in loot:
			earned += (items.catalog[item_id] as ItemData).cash_value
		if their_car != null:
			their_car.remove_occupant(player_id)  # out of the car first...
			# ...and once the last cat is out it waits at its parking spot for the next trip up.
			# (Passengers of the same gang extract this same frame; a rival riding along stays in.)
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
		for each_car in Game.instance.cars():
			each_car.empty_car()  # nobody escapes in a car either (drivers or passengers)
		for player_id in Game.instance.player_ids():
			if Game.instance.is_up_top(player_id):
				CatHealth.instance.damage(player_id, 99999, "THE DEEP CLEAN", true)  # (true: no downed stage)
		_new_district_at = _clock + new_district_delay
	# (A Mainframe on its last legs: the siren or the breach goes first. It may yet be fed.)
	if _new_district_at >= 0.0 and _clock >= _new_district_at and not Mainframe.instance.breach_coming():
		_new_district_at = -1.0
		Game.instance.new_district()  # a new city seed for everyone; place_items() resets us


## A payphone call (any computer -> host): switch the exit arrow on for the CALLER'S gang.
@rpc("any_peer", "call_local", "reliable")
func request_reveal_exit(player_id: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var team := Teams.team_of(player_id)
	if exit_is_open(team) and not is_revealed(team) and team < revealed.size():
		print("[Heist] Player %d called their boss: the %s's exit is revealed" % [player_id, Teams.name_of(team)])
		var now := revealed.duplicate()
		now[team] = true
		_set_state.rpc(sealed, now, exit_opened)


## Host -> everyone: is the hatch sealed, which gangs know where their exit is, and whose exits
## have already opened?
@rpc("authority", "call_local", "reliable")
func _set_state(is_sealed: bool, gangs_revealed: Array, gangs_opened: Array) -> void:
	var newly_sealed := is_sealed and not sealed
	sealed = is_sealed
	for team in mini(gangs_revealed.size(), revealed.size()):
		revealed[team] = gangs_revealed[team]
	for team in mini(gangs_opened.size(), exit_opened.size()):
		exit_opened[team] = gangs_opened[team]
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
		UndergroundHub.of(cat).return_cat(cat)  # down the drain we go


## Host -> everyone: this player has used their one trip up in this district.
@rpc("authority", "call_local", "reliable")
func _mark_went_up(player_id: int) -> void:
	went_up[player_id] = true


## Host -> a computer that just joined (network ID "peer"): which gangs found their exit, the
## hatch sealed, and who has already been up.
func send_state_to(peer: int) -> void:
	_set_state.rpc_id(peer, sealed, revealed, exit_opened)
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
	# A SEWER BREACH takes over the line at the top: the clock, in yellow (it sits between the red and green bars).
	var mainframe := Mainframe.instance
	var alarm := mainframe.breach_busy or not mainframe.warning_teams.is_empty()
	Hud.set_color("DropOff", Mainframe.TIER_COLORS[Mainframe.Tier.POWER_LOW] if alarm else DROP_OFF_COLOR, seat)
	if alarm:
		Hud.show_element("DropOff", true, seat)
		Hud.set_text("DropOff", mainframe.breach_text(my_cat), seat)
		return
	# The arrow to OUR gang's exit only shows once our boss has told us where it is (a payphone call).
	if in_sewers:
		Hud.show_element("DropOff", true, seat)
		Hud.set_text("DropOff", "THE SEWERS - WAIT FOR THE NEXT DISTRICT" if has_been_up(me) else "THE SEWERS - SAFE ZONE", seat)
	else:
		var show_arrow := is_revealed(my_cat.team) and exit_is_open(my_cat.team)
		Hud.show_element("DropOff", show_arrow, seat)
		if show_arrow:
			Hud.set_text("DropOff", _direction_text(where, exit_for(my_cat.team), GameScreen.instance.camera_for_seat(seat)), seat)


## "EXIT > 120m": distance and rough direction to an exit manhole from where the camera looks.
func _direction_text(where: Vector3, exit_at: Vector3, camera: Camera3D) -> String:
	var to_exit := exit_at - where
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
