class_name MeowMartInterior
extends Node3D
## CYPURRPUNK — INSIDE MEOW-MART: the first real heist interior (ROADMAP.md section 4 #8).
##
## A neon-lit PS1 supermarket that is REALLY THERE in the city: it takes the south half of a block
## (the city picks the block, scripts/city_generator.gd _build_meow_mart, and calls place_in_city),
## and you just walk in through the sliding glass doors. No teleport, no loading: you can see the
## street through the glass, and your couch buddy can drive past while you shop.
## The store is built once, from code, and MOVED to its block every district (Main/MeowMart, see
## scenes/interiors/meow_mart_interior.tscn; until a city is built it waits at y = -50, out of sight).
## The outside (cladding, rooftop sign, cameras, AC units...) is scripts/interiors/meow_mart_exterior.gd.
##
## WHAT'S IN THE STORE (all built from code in _build(), never random, the same on every computer):
##
##     north  +--------------------------------------------------+
##            |  BACK ROOM:  [monitor]   [GOLDEN KOI TANK]   [crates] |
##            |----------------------------------[EMPLOYEES ONLY]-----|  <- security door
##            | [scale]   [AISLE 1]      [AISLE 2]        [FRESH  |
##            |  plate                                    CATCH]  |
##            |   [basket]  [checkouts]                           |
##            +-----------------[ sliding doors ]------------------+  south (back out to the street)
##
##   - AISLES: two stepped shelf units (cats can hop up the steps). Stacks of cans sit on the ledges:
##     walk into one (or press [E] SWAT) and it clatters to the floor = a MESS. Run at an aisle's END
##     with zoomies (or press [E] TOPPLE while running) and the whole row goes down like dominoes:
##     a big mess (Topple Mess), cans everywhere.
##   - THE SCALE: a pressure plate by the west wall. Weight on it (a cat, or the heavy BASKET pushed or
##     dragged onto it) opens the EMPLOYEES ONLY door across the store. Off it, the door shuts after
##     Plate Close Delay seconds. (Inside the back room a push bar lets you back out.)
##   - THE GOLDEN KOI TANK in the back room: hit it (bolt, bat, blast, [E] SCRATCH) enough times, or
##     pounce into it at zoomies speed, and it SHATTERS: the koi ($400) flops out onto the floor, and the
##     STORE ALARM goes off: red strobes, klaxon, OVERCLEAN on the speakers, +Alarm Heat, and every
##     VAC-COP in range drives to Meow-Mart's front door to wait for you (the inside stays bot-free).
##   - Loot: FRESH CATCH on the seafood counter, GOURMET TUNA and CATNIP TREATS on the shelves (placed by
##     the Items node from the loot table: loot/city.tres lines with Where = Meow Mart Shelf / Counter).
##
## NETWORK: the HOST decides everything (request_* RPCs, checked with PlayerId.sender_owns) and tells
## every computer (_swat, _topple, _shatter...). The doors and the walk-through are worked out by each
## computer itself (everyone sees every cat). A late joiner gets the whole state (send_state_to), and
## a new district puts the store back as new (start_district -> _reset).
##
## Tuning: select Main > MeowMart in scenes/main.tscn; every number below is in the Inspector.
## Testing: --test_meow_mart, --inside_meow_mart, --shatter_tank, --mart_log (SETUP_GUIDE section 27).

static var instance: MeowMartInterior

## Off = Meow-Mart is a solid pink box nobody can go in, and the golden koi goes back to a sidewalk.
@export var enabled: bool = true

@export_group("Doors")
## The sliding doors open when a cat is this close (metres).
@export var door_open_distance: float = 3.2
## How fast they slide (1 = one full open per second).
@export var door_slide_speed: float = 3.0

@export_group("Look")
## The fog and ambient light while YOUR camera is in the store (scripts/hub.gd mood_at).
@export var fog_color: Color = Color(0.12, 0.16, 0.14)
@export var fog_albedo: Color = Color(0.55, 0.65, 0.6)
@export var ambient_color: Color = Color(0.55, 0.65, 0.6)
@export var ambient_energy: float = 0.3
## The background loop inside (res://sounds/ambience/). "" = silence.
@export var ambience: String = "meow_mart_hum"
## The fluorescent tubes.
@export var light_color: Color = Color(0.85, 1.0, 0.95)
@export var light_energy: float = 2.2
@export var light_range: float = 8.0
## Chance per second that a tube flickers for a moment (PS1 horror-film charm).
@export_range(0.0, 1.0) var flicker_chance: float = 0.15

@export_group("Outside")
## The corrugated metal skin on the outside walls (multiplies its plum texture).
@export var cladding_tint: Color = Color(1.0, 0.8, 1.0)
## The big MEOW-MART letters, the neon frame and the cat head's glow.
@export var sign_color: Color = Color(1, 0.22, 0.72)
## The second neon colour (the strap line, the awning edge, the corner lights).
@export var trim_color: Color = Color(0.25, 0.95, 1.0)
## How big the giant neon cat head on the roof is (1 = 4.5 m wide).
@export_range(0.5, 2.0) var cat_sign_scale: float = 1.25
## How far the security cameras swing each way (radians; 0.6 = about 35 degrees).
@export_range(0.0, 1.5) var camera_sweep: float = 0.6

@export_group("Mess")
## A can stack falls when a cat runs into it faster than this (metres per second; walking is 4.5).
@export var swat_bump_speed: float = 1.5
## [E] SWAT reaches this far (metres).
@export var swat_reach: float = 1.2
## Heat for each can stack knocked down.
@export var swat_heat: float = 0.4
## Ram an aisle's end this fast to topple it (zoomies are 9 m/s).
@export var topple_ram_speed: float = 6.0
## [E] TOPPLE only works while running at least this fast.
@export var topple_e_speed: float = 2.5
## How much MESS a toppled aisle counts as (the RAID REPORT's MESS column), and its heat.
@export var topple_mess: int = 10
@export var topple_heat: float = 3.0
## Seconds between one shelf section falling and the next (the domino effect).
@export var domino_delay: float = 0.14
## How many cans spill across the floor when an aisle goes down.
@export var topple_cans: int = 26

@export_group("Back room puzzle")
## Seconds the EMPLOYEES ONLY door stays open after the last weight leaves the scale.
@export var plate_close_delay: float = 1.5
## The push bar inside the back room keeps the door open this long (seconds).
@export var exit_button_seconds: float = 4.0
## How fast cats can shove the heavy basket by walking into it (metres per second).
@export var crate_push_speed: float = 2.2
## Dragging ([E] DRAG): the basket trails this far behind the cat (metres).
@export var crate_drag_distance: float = 1.15

@export_group("Golden Koi Tank")
## The prize inside (an item card id from res://items/).
@export var tank_item: String = "golden_koi"
## Hits (bolts, bat swings, scratches) it takes to break the glass. A zoomies pounce breaks it at once.
@export var tank_hits_to_break: int = 3
## Pounce: run into the tank at least this fast (metres per second).
@export var pounce_speed: float = 6.0
## The MESS a smashed tank counts as.
@export var tank_mess: int = 5

@export_group("Store alarm")
## Heat added the moment the tank breaks (25 = one whole heat level). It lands at once, not trickled.
@export var alarm_heat: float = 25.0
## How long the klaxon and red strobes go on (seconds).
@export var alarm_seconds: float = 60.0
## Extra VAC-COPs sent to the street outside the door when the alarm goes.
@export var ambush_bots: int = 4
## VAC-COPs within this many metres of the door are called to it...
@export var ambush_call_range: float = 90.0
## ...every this many seconds...
@export var ambush_call_every: float = 6.0
## ...for this long.
@export var ambush_seconds: float = 45.0
## OVERCLEAN's line (res://sounds/sfx/<sound>.wav) and its words.
@export var alarm_sound: String = "overclean_mart_alarm"
@export var alarm_line: String = "AQUATIC DISPLAY BREACH DETECTED. ALL UNITS DISPATCHED TO MEOW-MART."
## Loudness of the store klaxon (dB; negative is quieter).
@export var alarm_volume_db: float = -12.0

# --- The layout (metres, from the store's own middle; the floor is at 0) ---
## (Store coordinates: x = east, z = south = out of the front door, 0 = the middle of the floor.
## It must fit on half a city block: 24 x 12 m, minus 1 m of pavement front and sides.)
const ROOM := Vector3(21, 4.5, 10.8)     ## inside size (the walls are outside this)
const WALL := 0.3
const FLOOR_LIFT := 0.06                 ## the floor stands this far above the street (no flicker with the pavement)
const FRONT_Z := 5.4                     ## the front wall with the sliding doors (south)
const BACK_WALL_Z := -2.2                ## the wall between the shop floor and the back room
const ENTRY_HALF_WIDTH := 1.5            ## half the width of the front doorway
const GLASS_HALF := 3.5                  ## half the width of the whole glass front
const GLASS_HEIGHT := 3.0
const PLATE_SPOT := Vector3(-9.3, 0, 0.4)
const PLATE_HALF := 0.75
const SECURITY_DOOR_X := 7.0
const SECURITY_DOOR_WIDTH := 2.2
const SECURITY_DOOR_HEIGHT := 2.6
const EXIT_BUTTON_SPOT := Vector3(8.7, 1.1, -2.45)  ## the push bar, on the back room side of the wall
const TANK_SPOT := Vector3(0, 0, -4.0)
const TANK_SIZE := Vector3(1.6, 1.2, 1.2)
const TANK_STAND := 0.6
const CRATE_HOME := Vector3(-6.6, 0, 0.6)
const CRATE_SIZE := 0.8
const AISLE_X: Array[float] = [-3.0, 1.5]
const AISLE_Z := 0.9                     ## the middle of the aisles (front to back)
const AISLE_LENGTH := 4.0
const AISLE_SEGMENTS := 4
## The three steps of an aisle unit: [width, top height]. Cats hop up them like stairs.
const TIERS: Array = [[1.4, 0.35], [0.9, 0.95], [0.45, 1.6]]
const CHECKOUT_X: Array[float] = [-8.2, -5.4]
const CHECKOUT_Z := 3.9
const CHECKOUT_LENGTH := 2.0
const COUNTER_X := 9.7                   ## the FRESH CATCH counter, along the east wall
const COUNTER_Z := Vector2(-1.6, 3.4)    ## from / to
const PRODUCT_COLORS: Array[Color] = [Color(1, 0.3, 0.55), Color(0.3, 0.8, 1), Color(1, 0.8, 0.25),
	Color(0.4, 1, 0.5), Color(0.75, 0.45, 1), Color(1, 0.5, 0.2)]

## Every computer: the state of the store (the host's copy is the real one).
var swatted := {}              # can stack id -> true
var toppled: Array[int] = [0, 0]  # per aisle: 0 = standing, +1 / -1 = fell towards +x / -x
var tank_hits: int = 0
var shattered: bool = false
var alarm_left: float = 0.0    # seconds of klaxon left (0 = quiet)
var plate_pressed: bool = false
var security_open: bool = false
var crate_pos: Vector3 = CRATE_HOME   # the basket, store coordinates
var crate_dragger: int = 0            # who's dragging it (player id, 0 = nobody)

# Host only
var _close_at: float = INF
var _open_until: float = -1.0
var _ambush_left: float = 0.0
var _ambush_call_left: float = 0.0
var _push_sent_at := 0.0
var _crate_sent_at := 0.0

# This computer
var _clock: float = 0.0
var _asked := {}               # "kind:id" -> time we last asked the host (so we ask once)
var _doors_open: float = 0.0  # the sliding front doors: 0 shut .. 1 open
var _security_amount: float = 0.0
var _fx_rng := RandomNumberGenerator.new()  # only for looks (flicker, spilled cans): never game rules

# The pieces (made in _build)
var _stacks: Array[Node3D] = []         # can stacks; metas "aisle", "home" (Transform3D)
var _loot_shelf: Array[Vector3] = []    # store coordinates
var _loot_counter: Array[Vector3] = []
var _segments: Array = [[], []]         # per aisle: [{pivot: Node3D, inner: Node3D}]
var _aisle_shapes: Array = [[], []]     # per aisle: standing CollisionShape3Ds
var _aisle_rubble: Array[CollisionShape3D] = []
var _spilled: Array[Node3D] = []        # cans on the floor (freed on reset)
var _lights: Array[OmniLight3D] = []
var _tubes: Array[MeshInstance3D] = []
var _flicker_left := {}                 # light index -> seconds of flicker left
var _door_leaves: Array[Node3D] = []
var _placed := false                    # moved onto a city block yet?
var _security_door: StaticBody3D
var _security_shape: CollisionShape3D
var _plate_top: MeshInstance3D
var _plate_light: OmniLight3D
var _tank_glass: MeshInstance3D
var _tank_water: MeshInstance3D
var _tank_shape: CollisionShape3D
var _koi: Node3D
var _puddle: MeshInstance3D
var _shards: Array[Node3D] = []
var _crate: StaticBody3D
var _monitor_label: Label3D
var _alarm_speaker: Node3D
var _alarm_loop: AudioStreamPlayer3D
var _street_alarm: Node3D
var _street_alarm_light: OmniLight3D
var _street_alarm_loop: AudioStreamPlayer3D
var _can_mat: ShaderMaterial
var _can_mesh: CylinderMesh


func _enter_tree() -> void:
	instance = self
	add_to_group(GameSystems.GROUP)
	add_to_group(Interactable.GROUP)  # [E] SWAT / TOPPLE / DRAG / SCRATCH... (interact_* below)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	_fx_rng.seed = 1999
	MeowMartBuilder.build(self)
	MeowMartExterior.build(self)  # the outside: cladding, rooftop sign, cameras... (meow_mart_exterior.gd)
	_show_all(true)
	visible = false  # (until a city puts it on a block: place_in_city)


## The city (CityGenerator._build_meow_mart) puts the store on its block. "where" = the middle of
## the floor, at floor height. Every computer builds the same city, so the store lands in the same spot.
func place_in_city(where: Vector3) -> void:
	global_position = where
	visible = true
	_placed = true


## The whole store from outside, walls included (metres): the city keeps this much room for it.
static func outer_size() -> Vector3:
	return Vector3(ROOM.x + WALL * 2.0, ROOM.y + WALL, ROOM.z + WALL * 2.0)


# --- Questions other scripts ask ---

## Is this spot inside Meow-Mart (anywhere in the store, back room included)?
static func contains(where: Vector3) -> bool:
	if instance == null:
		return false
	if not instance._placed:
		return false
	var local := where - instance.global_position
	# (Inside the walls only: the pavement outside and the roof are the city.)
	return absf(local.x) < ROOM.x * 0.5 and absf(local.z) < ROOM.z * 0.5 and local.y > -1.0 and local.y < ROOM.y


## The Items node asks: is this sidewalk loot line's item really in the koi tank instead?
static func koi_in_tank(item_id: String) -> bool:
	return instance != null and instance.enabled and item_id == instance.tank_item


## The loot spots in the store (world positions): the shelves, or (counter = true) the seafood counter.
func loot_spots(counter: bool) -> Array[Vector3]:
	var list: Array[Vector3] = []
	for spot in (_loot_counter if counter else _loot_shelf):
		list.append(to_global(spot))
	return list


## The store's doorway (world position, the outside of the front wall, street level), or INF if the
## store isn't on a block.
func street_door() -> Vector3:
	if not _placed or not enabled:
		return Vector3.INF
	var door := to_global(Vector3(0, 0, FRONT_Z + WALL))
	door.y -= FLOOR_LIFT
	return door


## Which way is "out into the street" from the doorway (the store always faces south, +z).
func street_outward() -> Vector3:
	return Vector3.BACK


## Where a cat stands when it comes OUT of the store (and the VAC-COPs gather in an alarm).
func street_spot(distance: float = 1.8) -> Vector3:
	return street_door() + street_outward() * distance


## A short line about the store for the test log (DevCapture "mart" lines).
func debug_line() -> String:
	return "inside=%s swatted=%d toppled=%s plate=%s door=%s crate=%s dragger=%d tank_hits=%d shattered=%s alarm=%.0f" % [
		_cats_inside().map(func(c): return c.name), swatted.size(), toppled, plate_pressed, security_open,
		crate_pos.snapped(Vector3.ONE * 0.1), crate_dragger, tank_hits, shattered, alarm_left]


# --- Every frame ---

func _process(delta: float) -> void:
	_clock += delta
	if enabled:
		MeowMartBuilder.animate_store(self, delta)


func _physics_process(delta: float) -> void:
	if not enabled or not _placed or Game.instance == null:
		return
	if multiplayer.is_server():
		_host_tick(delta)


func _cats_inside() -> Array[CatPlayer]:
	var list: Array[CatPlayer] = []
	if Game.instance == null:
		return list
	for node in Game.instance.players.get_children():
		var cat := node as CatPlayer
		if cat != null and contains(cat.global_position):
			list.append(cat)
	return list


# --- The cat's owner, every physics frame (cat_player.gd, next to the mess check) ---

## Did this cat just run into a can stack, an aisle end, the tank or the basket? "push" = its speed
## before move_and_slide (whatever it hit has already stopped it by now).
func cat_bump(cat: CatPlayer, push: Vector3) -> void:
	if not enabled or not cat.visible or cat.is_downed() or not contains(cat.global_position):
		return
	var flat := Motion.flat(push)
	var speed := flat.length()
	if speed < swat_bump_speed:
		return
	var heading := flat / speed
	var local := to_local(cat.global_position)
	# Can stacks on the ledges (you have to be at about their height: hop up for the high ones).
	for stack in _stacks:
		var id: int = stack.get_meta("id")
		if swatted.has(id):
			continue
		var home: Vector3 = stack.get_meta("home").origin
		var to_stack := Motion.flat(home - local)
		if to_stack.length() < 0.6 and home.y - local.y > -0.4 and home.y - local.y < 0.75:
			_ask("swat", id, func(): request_swat.rpc_id(1, cat.player_id, id, heading))
	# Aisle ends at zoomies speed: TIMBER!
	if speed >= topple_ram_speed:
		for aisle in AISLE_X.size():
			var end := _nearest_end(aisle, local)
			if toppled[aisle] == 0 and end.distance > -1.0 and end.distance < 0.95 and heading.dot(end.inward) > 0.3:
				_ask("topple", aisle, func(): request_topple.rpc_id(1, cat.player_id, aisle, _fall_side(aisle, local), end.end))
	# The tank: a zoomies POUNCE goes straight through the glass.
	if not shattered and speed >= pounce_speed and _distance_to_tank(local) < 0.45:
		_ask("tank", 0, func(): request_tank_hit.rpc_id(1, cat.player_id, tank_hits_to_break))
	# The basket: walking into it shoves it along.
	if Motion.flat_distance(local, crate_pos) < CRATE_SIZE * 0.5 + 0.55 and heading.dot(Motion.flat(crate_pos - local).normalized()) > 0.5:
		if _clock - _push_sent_at > 0.1:
			_push_sent_at = _clock
			request_push.rpc_id(1, cat.player_id, heading)


## Ask the host for something once a second at most (props get bumped every frame).
func _ask(kind: String, id: int, send: Callable) -> void:
	var key := "%s:%d" % [kind, id]
	if _clock - float(_asked.get(key, -10.0)) < 1.0:
		return
	_asked[key] = _clock
	send.call()


## The nearer end of an aisle to a spot: {end: +1 / -1, distance (-1 = not near), inward (direction)}.
func _nearest_end(aisle: int, local: Vector3) -> Dictionary:
	var end := 1 if local.z > AISLE_Z else -1
	var end_spot := Vector3(AISLE_X[aisle], 0, AISLE_Z + end * AISLE_LENGTH * 0.5)
	var off := Motion.flat(local - end_spot)
	# Standing off the end of the aisle (not along its side) and within its width.
	if off.z * end < -0.1 or absf(off.x) > 0.8:
		return {"end": end, "distance": -1.0, "inward": Vector3.ZERO}
	return {"end": end, "distance": off.length(), "inward": Vector3(0, 0, -end)}


## Which way an aisle falls when this cat knocks it: away from the side the cat is on.
func _fall_side(aisle: int, local: Vector3) -> int:
	return 1 if local.x <= AISLE_X[aisle] else -1


func _distance_to_tank(local: Vector3) -> float:
	var half := Vector3(TANK_SIZE.x * 0.5 + 0.1, 0, TANK_SIZE.z * 0.5 + 0.1)
	var off := local - TANK_SPOT
	var dx := maxf(absf(off.x) - half.x, 0.0)
	var dz := maxf(absf(off.z) - half.z, 0.0)
	return Vector2(dx, dz).length()


# --- The E key (scripts/interactable.gd): one answer for the whole store ---

## The thing in the store this cat would use with E: {kind, id, distance, prompt}, or {} for nothing.
func _best_action(cat: CatPlayer) -> Dictionary:
	if not enabled or not cat.visible or not contains(cat.global_position):
		return {}
	var local := to_local(cat.global_position)
	var best := {}
	# (A lambda can't swap "best" for a new dictionary, so it fills in the same one.)
	var offer := func(kind: String, id: int, distance: float, prompt: String) -> void:
		if distance >= 0.0 and (best.is_empty() or distance < best.distance):
			best.clear()
			best.merge({"kind": kind, "id": id, "distance": distance, "prompt": prompt})
	# The basket (always first in line while you're dragging it: E lets go).
	var crate_distance := Motion.flat_distance(local, crate_pos)
	if crate_dragger == cat.player_id:
		return {"kind": "crate", "id": 0, "distance": 0.0, "prompt": "LET GO OF BASKET"}
	if crate_distance < CRATE_SIZE * 0.5 + 1.0 and crate_dragger == 0:
		offer.call("crate", 0, crate_distance, "DRAG BASKET")
	for stack in _stacks:
		var id: int = stack.get_meta("id")
		if swatted.has(id):
			continue
		var home: Vector3 = stack.get_meta("home").origin
		var dy := home.y - local.y
		var d := Motion.flat_distance(home, local)
		if d < swat_reach and dy > -0.6 and dy < 1.3:
			offer.call("swat", id, d + 0.2, "SWAT")
	for aisle in AISLE_X.size():
		if toppled[aisle] != 0:
			continue
		var end := _nearest_end(aisle, local)
		if end.distance >= 0.0 and end.distance < 1.3:
			var running := Motion.flat(cat.velocity).length() >= topple_e_speed
			offer.call("topple", aisle, end.distance, "TOPPLE" if running else "TOPPLE (RUN AT IT!)")
	if not shattered:
		var d := _distance_to_tank(local)
		if d < 1.0:
			offer.call("tank", 0, d, "SCRATCH THE GLASS")
	if not security_open and Motion.flat_distance(local, EXIT_BUTTON_SPOT) < 1.3 and local.z < BACK_WALL_Z:
		offer.call("exit_button", 0, Motion.flat_distance(local, EXIT_BUTTON_SPOT), "OPEN DOOR")
	for lane in CHECKOUT_X.size():
		var register := Vector3(CHECKOUT_X[lane], 0, CHECKOUT_Z - 1.0)
		var d := Motion.flat_distance(local, register)
		if d < 1.1:
			offer.call("scan", lane, d + 0.3, "SCAN")
	return best


func interact_distance(cat: CatPlayer) -> float:
	var best := _best_action(cat)
	return -1.0 if best.is_empty() else best.distance


func interact_prompt(cat: CatPlayer) -> String:
	return _best_action(cat).get("prompt", "")


## Above street props (mess -5), below loot (items 30): a fish on a shelf is still [E] PICKUP.
func interact_priority() -> int:
	return 5


func interact(cat: CatPlayer) -> void:
	var best := _best_action(cat)
	if best.is_empty():
		return
	var local := to_local(cat.global_position)
	match best.kind:
		"crate":
			request_drag.rpc_id(1, cat.player_id)
		"swat":
			var home: Vector3 = _stacks[best.id].get_meta("home").origin
			request_swat.rpc_id(1, cat.player_id, best.id, Motion.flat(home - local).normalized())
		"topple":
			if Motion.flat(cat.velocity).length() >= topple_e_speed:
				var end := _nearest_end(best.id, local)
				request_topple.rpc_id(1, cat.player_id, best.id, _fall_side(best.id, local), end.end)
			else:
				Hud.popup("GET A RUN-UP FIRST!", 1.5, cat.slot)
		"tank":
			Sound.play_everywhere("fish_slap", to_global(TANK_SPOT + Vector3(0, 1.2, 0)), -6.0)
			request_tank_hit.rpc_id(1, cat.player_id, 1)
		"exit_button":
			request_exit_button.rpc_id(1, cat.player_id)
		"scan":
			Sound.play_everywhere("scanner_beep", to_global(Vector3(CHECKOUT_X[best.id], 1.0, CHECKOUT_Z - 1.0)), -4.0)


# --- Shooting / hitting things in the store (the Hit framework, scripts/hit.gd) ---

## Runs on the shooter's computer: something in the store got hit (every wall and shelf in here hands
## its hits to this node). Near the tank = a crack; near a can stack = it's knocked flying.
func receive_hit(hit: Hit) -> bool:
	if not enabled or hit.shooter == null:
		return false
	# (A bat swing or a blast says "the middle of the target" = our middle: no use. A swing hits just
	# in front of the cat; a blast in here can't tell which can it hit, so it leaves the cans alone.)
	var where := hit.position
	if hit.weapon is MeleeWeapon:
		where = hit.shooter.global_position + Motion.flat(hit.direction).normalized() * 0.9 + Vector3(0, 0.6, 0)
	elif hit.weapon != null and hit.weapon.blast_radius > 0.0:
		return false
	var local := to_local(where)
	for stack in _stacks:
		var id: int = stack.get_meta("id")
		if not swatted.has(id) and (stack.get_meta("home").origin as Vector3).distance_to(local) < 0.5:
			_ask("swat", id, func(): request_swat.rpc_id(1, hit.shooter.player_id, id, Motion.flat(hit.direction).normalized()))
	return false  # (no damage numbers on groceries)


## The tank's own hit box was hit (HitRelay, every kind of weapon): a crack.
func _on_tank_hit(hit: Hit) -> bool:
	if enabled and not shattered and hit.shooter != null:
		_ask("tank", 1, func(): request_tank_hit.rpc_id(1, hit.shooter.player_id, 1))
	return false


# --- Host: checking requests ---

## A cat of this player, inside the store and able to act, or null.
func _acting_cat(player_id: int) -> CatPlayer:
	if not multiplayer.is_server() or not enabled or not PlayerId.sender_owns(player_id):
		return null
	var cat := Game.instance.cat_for(player_id)
	if cat == null or not cat.visible or CatHealth.instance.is_down(player_id) or not contains(cat.global_position):
		return null
	return cat


@rpc("any_peer", "call_local", "reliable")
func request_swat(player_id: int, id: int, direction: Vector3) -> void:
	var cat := _acting_cat(player_id)
	if cat == null or id < 0 or id >= _stacks.size() or swatted.has(id):
		return
	_swat.rpc(id, Motion.flat(direction).normalized())
	_count_mess(player_id, 1, swat_heat)


@rpc("any_peer", "call_local", "reliable")
func request_topple(player_id: int, aisle: int, side: int, end: int) -> void:
	var cat := _acting_cat(player_id)
	if cat == null or aisle < 0 or aisle >= AISLE_X.size() or toppled[aisle] != 0:
		return
	_topple.rpc(aisle, 1 if side >= 0 else -1, 1 if end >= 0 else -1)
	_count_mess(player_id, topple_mess, topple_heat)
	print("[MeowMart] player %d TOPPLED aisle %d" % [player_id, aisle + 1])


@rpc("any_peer", "call_local", "reliable")
func request_tank_hit(player_id: int, amount: int) -> void:
	var cat := _acting_cat(player_id)
	if cat == null or shattered:
		return
	tank_hits = mini(tank_hits + maxi(amount, 1), tank_hits_to_break)
	if tank_hits >= tank_hits_to_break:
		_shatter_tank(player_id)
	else:
		_set_tank_hits.rpc(tank_hits)


## Host: the tank goes. The koi falls out, the alarm goes off.
func _shatter_tank(player_id: int) -> void:
	_shatter.rpc(player_id)
	_count_mess(player_id, tank_mess, 0.0)
	if ItemManager.instance != null and ItemManager.instance.catalog.has(tank_item):
		ItemManager.instance.drop_on_street(tank_item, to_global(TANK_SPOT + Vector3(0, 0.05, 1.1)))
	trip_alarm()
	print("[MeowMart] player %d SHATTERED the koi tank" % player_id)


## Host: THE STORE ALARM. Heat jumps, the bots outside are called to the front door.
func trip_alarm() -> void:
	if not multiplayer.is_server():
		return
	_set_alarm.rpc(alarm_seconds)
	if HeatMeter.instance != null:
		HeatMeter.instance.add_heat(alarm_heat, true)
	_ambush_left = ambush_seconds
	_ambush_call_left = 0.0
	if RoombaPatrol.instance != null and street_door() != Vector3.INF:
		RoombaPatrol.instance.ambush(street_spot(3.0), ambush_bots, ambush_call_range)


@rpc("any_peer", "call_local", "reliable")
func request_drag(player_id: int) -> void:
	var cat := _acting_cat(player_id)
	if cat == null:
		return
	if crate_dragger == player_id:
		crate_dragger = 0
	elif crate_dragger == 0 and Motion.flat_distance(to_local(cat.global_position), crate_pos) < CRATE_SIZE * 0.5 + 1.5:
		crate_dragger = player_id
	_set_crate.rpc(crate_pos, crate_dragger)


@rpc("any_peer", "call_local", "reliable")
func request_push(player_id: int, direction: Vector3) -> void:
	var cat := _acting_cat(player_id)
	if cat == null or crate_dragger != 0 or Motion.flat_distance(to_local(cat.global_position), crate_pos) > CRATE_SIZE * 0.5 + 1.0:
		return
	_move_crate(Motion.flat(direction).normalized() * crate_push_speed * 0.12)


@rpc("any_peer", "call_local", "reliable")
func request_exit_button(player_id: int) -> void:
	var cat := _acting_cat(player_id)
	if cat == null or to_local(cat.global_position).z > BACK_WALL_Z:
		return
	_open_until = _clock + exit_button_seconds


## Host: count a mess like the street props do (heat, RAID REPORT MESS, BIN DAY's chaos bonus).
func _count_mess(player_id: int, amount: int, heat: float) -> void:
	if MessManager.instance != null:
		MessManager.instance.count_mess(player_id, amount, heat)


# --- Host: every physics frame ---

func _host_tick(delta: float) -> void:
	# THE SCALE: anyone (or the basket) on it?
	var pressed := Motion.flat_distance(crate_pos, PLATE_SPOT) < PLATE_HALF + 0.1
	if not pressed:
		for cat in _cats_inside():
			var local := to_local(cat.global_position)
			if cat.visible and not CatHealth.instance.is_down(cat.player_id) \
					and absf(local.x - PLATE_SPOT.x) < PLATE_HALF + 0.15 and absf(local.z - PLATE_SPOT.z) < PLATE_HALF + 0.15 and local.y < 0.8:
				pressed = true
				break
	var want_open := pressed or _clock < _open_until
	if want_open:
		_close_at = INF
	elif security_open and _close_at == INF:
		_close_at = _clock + plate_close_delay
	var open := want_open or (security_open and _clock < _close_at)
	if pressed != plate_pressed or open != security_open:
		_set_doors.rpc(pressed, open)

	# THE BASKET, being dragged: it trails behind its cat.
	if crate_dragger != 0:
		var cat := Game.instance.cat_for(crate_dragger)
		if cat == null or not contains(cat.global_position) or CatHealth.instance.is_down(crate_dragger) or not cat.visible:
			crate_dragger = 0
			_set_crate.rpc(crate_pos, 0)
		else:
			var cat_local := to_local(cat.global_position)
			var away := Motion.flat(crate_pos - cat_local)
			if away.length() > crate_drag_distance + 2.0:
				crate_dragger = 0  # (snagged on something: let go)
				_set_crate.rpc(crate_pos, 0)
			elif away.length() > crate_drag_distance:
				_move_crate(-away.normalized() * (away.length() - crate_drag_distance))

	# THE AMBUSH: keep calling the VAC-COPs to the front door for a while.
	if _ambush_left > 0.0:
		_ambush_left -= delta
		_ambush_call_left -= delta
		if _ambush_call_left <= 0.0 and RoombaPatrol.instance != null and street_door() != Vector3.INF:
			_ambush_call_left = ambush_call_every
			var coming := RoombaPatrol.instance.hear_noise(street_spot(3.0), ambush_call_range)
			print("[MeowMart] alarm: %d VAC-COPs heading for the front door" % coming)


## Host: slide the basket by "step" (store coordinates), stopping at walls and shelves.
func _move_crate(step: Vector3) -> void:
	if step.length() < 0.001:
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(CRATE_SIZE - 0.05, CRATE_SIZE - 0.1, CRATE_SIZE - 0.05)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, to_global(crate_pos + Vector3(0, CRATE_SIZE * 0.5 + 0.05, 0)))
	query.motion = step
	query.collision_mask = 1
	var skip: Array[RID] = [_crate.get_rid()]
	for node in Game.instance.players.get_children():
		skip.append((node as CollisionObject3D).get_rid())
	query.exclude = skip
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	var safe: float = fractions[0] if fractions.size() > 0 else 1.0
	if safe <= 0.0:
		return
	crate_pos += step * safe
	crate_pos.y = 0.0
	if _clock - _crate_sent_at > 0.05:
		_crate_sent_at = _clock
		_set_crate_quick.rpc(crate_pos, crate_dragger)


# --- Every computer: what the host decided ---

@rpc("authority", "call_local", "reliable")
func _swat(id: int, direction: Vector3) -> void:
	if swatted.has(id) or id < 0 or id >= _stacks.size():
		return
	swatted[id] = true
	_show_swatted(_stacks[id], direction, false)
	Sound.play_at("can_clatter", _stacks[id].global_position, -2.0)


@rpc("authority", "call_local", "reliable")
func _topple(aisle: int, side: int, from_end: int) -> void:
	if toppled[aisle] != 0:
		return
	toppled[aisle] = side
	_show_toppled(aisle, side, from_end, false)
	Sound.play_at("shelf_collapse", to_global(Vector3(AISLE_X[aisle], 1.0, AISLE_Z)), 2.0)
	for player_cat in Game.instance.local_cats():
		if contains(player_cat.global_position):
			Seats.rumble(player_cat.player_id, 0.6, 0.6, 0.4)


@rpc("authority", "call_local", "reliable")
func _set_tank_hits(hits: int) -> void:
	tank_hits = hits
	_show_tank_cracks()
	Sound.play_at("bonk", to_global(TANK_SPOT + Vector3(0, 1.2, 0)), -4.0)


@rpc("authority", "call_local", "reliable")
func _shatter(player_id: int) -> void:
	if shattered:
		return
	tank_hits = tank_hits_to_break
	shattered = true
	_show_shattered(false)
	Sound.play_at("tank_shatter", to_global(TANK_SPOT + Vector3(0, 1.2, 0)), 3.0)
	var cat := Game.instance.cat_for(player_id)
	var who := cat.display_name() if cat != null else "SOMEONE"
	Hud.feed("%s SMASHED THE KOI TANK!" % who, Color(1, 0.8, 0.2))
	Events.store_alarm_tripped.emit(player_id)


@rpc("authority", "call_local", "reliable")
func _set_alarm(seconds: float) -> void:
	alarm_left = seconds
	_alarm_sounds(seconds > 0.0)
	if seconds > 0.0 and OvercleanAnnouncer.instance != null:
		OvercleanAnnouncer.instance.say(alarm_sound, alarm_line, true, 0.6, "meow-mart alarm")
	if seconds > 0.0:
		Hud.show_message("STORE ALARM! VAC-COPS ARE COMING TO THE FRONT DOOR!", 4.0)


@rpc("authority", "call_local", "reliable")
func _set_doors(pressed: bool, open: bool) -> void:
	if pressed != plate_pressed:
		Sound.play_at("plate_click", to_global(PLATE_SPOT + Vector3(0, 0.3, 0)), -2.0)
	if open != security_open:
		Sound.play_at("security_door", to_global(Vector3(SECURITY_DOOR_X, 1.5, BACK_WALL_Z)), 0.0)
	plate_pressed = pressed
	security_open = open
	_security_shape.disabled = open


@rpc("authority", "call_local", "reliable")
func _set_crate(pos: Vector3, dragger: int) -> void:
	crate_pos = pos
	crate_dragger = dragger


## (The same, often, while the basket moves: a lost one doesn't matter, the next one comes soon.)
@rpc("authority", "call_local", "unreliable_ordered")
func _set_crate_quick(pos: Vector3, dragger: int) -> void:
	crate_pos = pos
	crate_dragger = dragger


## Host -> a late joiner: the store as it is right now (nothing animates, no sounds).
@rpc("authority", "call_remote", "reliable")
func _receive_state(state: Dictionary) -> void:
	_reset_local()
	for id in state.swatted:
		swatted[int(id)] = true
	toppled = []
	for side in state.toppled:
		toppled.append(int(side))
	tank_hits = state.tank_hits
	shattered = state.shattered
	plate_pressed = state.plate
	security_open = state.door
	_security_amount = 1.0 if security_open else 0.0
	_security_shape.disabled = security_open
	crate_pos = state.crate
	crate_dragger = state.dragger
	alarm_left = state.alarm
	_show_all(true)
	_alarm_sounds(alarm_left > 0.0)


## Host -> everyone: a new district, a brand new store.
@rpc("authority", "call_local", "reliable")
func _reset() -> void:
	_reset_local()
	_show_all(true)


func _reset_local() -> void:
	swatted.clear()
	toppled = [0, 0]
	tank_hits = 0
	shattered = false
	alarm_left = 0.0
	plate_pressed = false
	security_open = false
	_security_amount = 0.0
	if _security_shape != null:
		_security_shape.disabled = false
	crate_pos = CRATE_HOME
	crate_dragger = 0
	_asked.clear()
	_alarm_sounds(false)
	for node in _spilled:
		if is_instance_valid(node):
			node.queue_free()
	_spilled.clear()


# --- Game systems (scripts/game_systems.gd) ---

## Host: a new game / new district: the store is restocked, the tank refilled, the alarm reset.
func start_district() -> void:
	_close_at = INF
	_open_until = -1.0
	_ambush_left = 0.0
	_reset.rpc()


## Host: a late joiner gets the store as it is.
func send_state_to(peer: int) -> void:
	_receive_state.rpc_id(peer, {"swatted": swatted.keys(), "toppled": toppled, "tank_hits": tank_hits, "shattered": shattered,
		"plate": plate_pressed, "door": security_open, "crate": crate_pos, "dragger": crate_dragger, "alarm": alarm_left})


## Host: someone quit while dragging the basket: let go of it.
func player_left(player_id: int, _last_position: Vector3) -> void:
	if crate_dragger == player_id:
		crate_dragger = 0
		_set_crate.rpc(crate_pos, 0)


# --- Showing the state ---

## Put every piece into the state the variables say (instant = no animation).
func _show_all(instant: bool) -> void:
	for stack in _stacks:
		var id: int = stack.get_meta("id")
		if swatted.has(id):
			_show_swatted(stack, Vector3.FORWARD, instant)
		else:
			stack.transform = stack.get_meta("home")
			stack.visible = true
			for i in stack.get_child_count():
				(stack.get_child(i) as Node3D).transform = stack.get_child(i).get_meta("home")
	for aisle in AISLE_X.size():
		if toppled[aisle] != 0:
			_show_toppled(aisle, toppled[aisle], 1, instant)
		else:
			for seg: Dictionary in _segments[aisle]:
				(seg.pivot as Node3D).rotation = Vector3.ZERO
				(seg.pivot as Node3D).position = seg.home
				(seg.inner as Node3D).position = Vector3.ZERO
			for shape: CollisionShape3D in _aisle_shapes[aisle]:
				shape.disabled = false
			_aisle_rubble[aisle].disabled = true
	if shattered:
		_show_shattered(instant)
	else:
		_tank_glass.visible = true
		_tank_water.visible = true
		_koi.visible = true
		_puddle.visible = false
		for shard in _shards:
			shard.visible = false
		_tank_shape.shape.size = Vector3(TANK_SIZE.x + 0.2, TANK_STAND + TANK_SIZE.y, TANK_SIZE.z + 0.2)
		_tank_shape.position.y = (TANK_STAND + TANK_SIZE.y) * 0.5
		_show_tank_cracks()
	if _crate != null:
		_crate.position = crate_pos + Vector3(0, CRATE_SIZE * 0.5, 0)


## A can stack knocked off its ledge: the cans tumble to the floor and lie there.
func _show_swatted(stack: Node3D, direction: Vector3, instant: bool) -> void:
	MeowMartBuilder.show_swatted(self, stack, direction, instant)


## An aisle going down like dominoes, one section after another from the end that was hit.
func _show_toppled(aisle: int, side: int, from_end: int, instant: bool) -> void:
	MeowMartBuilder.show_toppled(self, aisle, side, from_end, instant)


func _show_tank_cracks() -> void:
	# More cracks = whiter, cloudier glass.
	var cracked := float(tank_hits) / maxf(tank_hits_to_break, 1)
	var glass := _tank_glass.material_override as StandardMaterial3D
	glass.albedo_color = Color(0.55, 0.85, 1.0, 0.22).lerp(Color(0.95, 1, 1, 0.6), cracked)


func _show_shattered(instant: bool) -> void:
	_tank_glass.visible = false
	_tank_water.visible = false
	_koi.visible = false  # (the real koi, the one you can pick up, is now on the floor: an item)
	# Only the stand is left to bump into.
	_tank_shape.shape.size = Vector3(TANK_SIZE.x + 0.2, TANK_STAND, TANK_SIZE.z + 0.2)
	_tank_shape.position.y = TANK_STAND * 0.5
	for shard in _shards:
		shard.visible = true
	_puddle.visible = true
	if instant:
		_puddle.scale = Vector3.ONE
	else:
		_puddle.scale = Vector3(0.1, 1, 0.1)
		create_tween().tween_property(_puddle, "scale", Vector3.ONE, 1.4).set_ease(Tween.EASE_OUT)
		MeowMartBuilder.burst_tank(self, Color(0.8, 0.95, 1, 1), 60, 0.04, 5.0)    # glass
		MeowMartBuilder.burst_tank(self, Color(0.2, 0.55, 1, 0.8), 80, 0.06, 3.5)  # water


# --- Animations (every computer, every frame) ---

## The klaxon (inside and out on the street) on or off.
func _alarm_sounds(on: bool) -> void:
	if on:
		if _alarm_loop == null or not is_instance_valid(_alarm_loop):
			_alarm_loop = Sound.attach_loop("store_alarm", _alarm_speaker, alarm_volume_db)
	else:
		if _alarm_loop != null and is_instance_valid(_alarm_loop):
			_alarm_loop.queue_free()
		_alarm_loop = null
		if _street_alarm_loop != null and is_instance_valid(_street_alarm_loop):
			_street_alarm_loop.queue_free()
		_street_alarm_loop = null


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# --- Tests (DevCapture) ---

## Host, tests only (--shatter_tank): break the tank as if this player had.
func test_shatter(player_id: int) -> void:
	if multiplayer.is_server() and not shattered:
		_shatter_tank(player_id)
