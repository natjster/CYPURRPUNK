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
var _tank: HitRelay
var _tank_glass: MeshInstance3D
var _tank_water: MeshInstance3D
var _tank_shape: CollisionShape3D
var _koi: Node3D
var _tank_light: OmniLight3D
var _puddle: MeshInstance3D
var _shards: Array[Node3D] = []
var _crate: StaticBody3D
var _monitor_label: Label3D
var _alarm_speaker: Node3D
var _alarm_loop: AudioStreamPlayer3D
var _street_alarm: Node3D
var _street_alarm_light: OmniLight3D
var _street_alarm_loop: AudioStreamPlayer3D

# Materials
var _floor_mat: ShaderMaterial
var _wall_mat: ShaderMaterial
var _metal_mat: ShaderMaterial
var _shelf_mat: ShaderMaterial
var _neon_mat: ShaderMaterial
var _tube_mat: ShaderMaterial
var _can_mat: ShaderMaterial
var _ice_mat: ShaderMaterial
var _glass_mat: StandardMaterial3D
var _water_mat: StandardMaterial3D
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
	_make_materials()
	_build()
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
	if not enabled:
		return
	_animate_doors(delta)
	_animate_security_door(delta)
	_animate_lights(delta)
	_animate_koi()
	_animate_plate()
	if _crate != null:
		_crate.position = _crate.position.lerp(crate_pos + Vector3(0, CRATE_SIZE * 0.5, 0), 1.0 - exp(-14.0 * delta))
	if alarm_left > 0.0:
		alarm_left = maxf(alarm_left - delta, 0.0)
		if alarm_left <= 0.0:
			_alarm_sounds(false)
	_update_street_alarm()


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
	var home: Transform3D = stack.get_meta("home")
	var id: int = stack.get_meta("id")
	var landing := home.origin + direction * 0.8
	landing.y = 0.06
	var cans := stack.get_children()
	for i in cans.size():
		var can := cans[i] as Node3D
		var spread := Vector3(cos(id * 2.1 + i * 2.3), 0, sin(id * 1.7 + i * 2.3)) * (0.18 + 0.12 * i)
		var lying := Transform3D(Basis.from_euler(Vector3(PI / 2, id * 0.9 + i * 1.4, 0)), spread - Vector3(0, can.get_meta("home").origin.y, 0))
		if instant:
			can.transform = lying
		else:
			create_tween().tween_property(can, "transform", lying, 0.35 + 0.05 * i)
	var target := Transform3D(Basis.IDENTITY, landing)
	if instant:
		stack.transform = target
	else:
		var tween := create_tween()
		# Up a little, then down: a short arc off the shelf.
		tween.tween_property(stack, "position", (home.origin + landing) * 0.5 + Vector3(0, 0.35, 0), 0.15)
		tween.tween_property(stack, "position", landing, 0.25).set_ease(Tween.EASE_IN)


## An aisle going down like dominoes, one section after another from the end that was hit.
func _show_toppled(aisle: int, side: int, from_end: int, instant: bool) -> void:
	var segments: Array = _segments[aisle]
	var order := range(segments.size())
	if from_end > 0:
		order.reverse()  # (sections are numbered from the -z end)
	var half_base: float = TIERS[0][0] * 0.5
	for n in order.size():
		var seg: Dictionary = segments[order[n]]
		var pivot := seg.pivot as Node3D
		# Turn around the bottom edge on the side it falls to (not its middle: it'd sink into the floor).
		pivot.position = seg.home + Vector3(side * half_base, 0, 0)
		(seg.inner as Node3D).position = Vector3(-side * half_base, 0, 0)
		var lying := Vector3(0, 0, -side * deg_to_rad(80.0))
		if instant:
			pivot.rotation = lying
		else:
			pivot.rotation = Vector3.ZERO
			var tween := create_tween()
			tween.tween_interval(domino_delay * n)
			tween.tween_property(pivot, "rotation", lying, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	for shape: CollisionShape3D in _aisle_shapes[aisle]:
		shape.disabled = true
	var rubble := _aisle_rubble[aisle]
	rubble.position = Vector3(AISLE_X[aisle] + side * (half_base + 0.8), 0.3, AISLE_Z)
	rubble.disabled = false
	# Every can stack on it comes down too (no extra mess: the topple already counted).
	for stack in _stacks:
		var id: int = stack.get_meta("id")
		if stack.get_meta("aisle") == aisle and not swatted.has(id):
			swatted[id] = true
			_show_swatted(stack, Vector3(side, 0, 0), instant)
	# And dozens of cans roll out across the floor.
	var rng := RandomNumberGenerator.new()
	rng.seed = aisle * 977 + side * 13
	for i in topple_cans:
		var can := MeshInstance3D.new()
		can.mesh = _can_mesh
		can.material_override = _can_mat
		can.set_instance_shader_parameter("instance_tint", PRODUCT_COLORS[i % PRODUCT_COLORS.size()])
		add_child(can)
		_spilled.append(can)
		var start := Vector3(AISLE_X[aisle], rng.randf_range(0.4, 1.5), AISLE_Z + rng.randf_range(-AISLE_LENGTH * 0.5, AISLE_LENGTH * 0.5))
		var land := Vector3(AISLE_X[aisle] + side * rng.randf_range(0.6, 3.2), 0.06, start.z + rng.randf_range(-1.2, 1.2))
		land.z = clampf(land.z, BACK_WALL_Z + 0.4, FRONT_Z - 1.0)
		var lying := Basis.from_euler(Vector3(PI / 2, rng.randf() * TAU, 0))
		if instant:
			can.transform = Transform3D(lying, land)
		else:
			can.position = start
			var tween := create_tween()
			tween.tween_interval(domino_delay * rng.randf_range(0.0, AISLE_SEGMENTS))
			tween.tween_property(can, "transform", Transform3D(lying, land), rng.randf_range(0.35, 0.6)).set_ease(Tween.EASE_IN)


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
		_burst(Color(0.8, 0.95, 1, 1), 60, 0.04, 5.0)    # glass
		_burst(Color(0.2, 0.55, 1, 0.8), 80, 0.06, 3.5)  # water


## A one-off spray of little bits out of the tank (glass or water).
func _burst(color: Color, amount: int, size: float, speed: float) -> void:
	var particles := CPUParticles3D.new()
	particles.position = TANK_SPOT + Vector3(0, TANK_STAND + TANK_SIZE.y * 0.5, 0)
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = 1.2
	particles.direction = Vector3(0, 0.6, 1)
	particles.spread = 75.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -12, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.mesh = mesh
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(2.0).timeout.connect(particles.queue_free)


# --- Animations (every computer, every frame) ---

## The sliding front doors open for any cat near them, inside or out (every computer, by itself).
func _animate_doors(delta: float) -> void:
	if not _placed:
		return
	var door := to_global(Vector3(0, 0, FRONT_Z))
	var want := 0.0
	for node in Game.instance.players.get_children():
		var cat := node as Node3D
		if cat.visible and Motion.flat_distance(cat.global_position, door) < door_open_distance and absf(cat.global_position.y - door.y) < 2.0:
			want = 1.0
	if want > 0.0 and _doors_open == 0.0:
		Sound.play_at("door_slide", door + Vector3(0, 1.5, 0), -4.0)
	_doors_open = move_toward(_doors_open, want, door_slide_speed * delta)
	for leaf in _door_leaves:
		leaf.position.x = lerpf(leaf.get_meta("home_x"), leaf.get_meta("open_x"), _smooth(_doors_open))


func _animate_security_door(delta: float) -> void:
	_security_amount = move_toward(_security_amount, 1.0 if security_open else 0.0, delta * 1.6)
	_security_door.position.y = _smooth(_security_amount) * (SECURITY_DOOR_HEIGHT - 0.35)


func _animate_plate() -> void:
	_plate_top.position.y = 0.035 if plate_pressed else 0.07
	var colour := Color(0.2, 1, 0.35) if plate_pressed else Color(1, 0.2, 0.2)
	_plate_top.set_instance_shader_parameter("instance_tint", colour)
	_plate_light.light_color = colour


func _animate_koi() -> void:
	if shattered or _koi == null:
		return
	var t := _clock * 0.9
	_koi.position = Vector3(cos(t) * 0.45, TANK_STAND + 0.55 + sin(t * 2.3) * 0.08, sin(t) * 0.3)
	_koi.rotation.y = -t + PI  # (nose along the circle)


func _animate_lights(delta: float) -> void:
	var alarm := alarm_left > 0.0
	var strobe := 0.5 + 0.5 * sin(_clock * TAU * 1.6)
	for i in _lights.size():
		var light := _lights[i]
		if alarm:
			light.light_color = Color(1, 0.08, 0.06)
			light.light_energy = light_energy * lerpf(0.25, 1.6, strobe)
			continue
		light.light_color = light_color
		# Every now and then a tube flickers (looks only, so it uses its own random numbers).
		if _fx_rng.randf() < flicker_chance * delta / maxf(_lights.size(), 1) * 4.0:
			_flicker_left[i] = _fx_rng.randf_range(0.15, 0.5)
		var flicker := float(_flicker_left.get(i, 0.0))
		if flicker > 0.0:
			_flicker_left[i] = flicker - delta
			light.light_energy = light_energy * (0.15 if _fx_rng.randf() < 0.5 else 1.0)
		else:
			light.light_energy = light_energy
	var tube_colour := Color(1, 0.1, 0.08) * lerpf(0.3, 1.0, strobe) if alarm else light_color
	for tube in _tubes:
		tube.set_instance_shader_parameter("instance_tint", Color(tube_colour, 1))
	if _monitor_label != null:
		_monitor_label.text = ("!! ALARM !!\nALL UNITS" if fmod(_clock, 1.0) < 0.6 else "") if alarm \
			else ("CAM 01  AISLE 2\nCAM 02  KOI DISPLAY\nSTATUS: CALM" if not shattered else "CAM 02\nNO SIGNAL")
		_monitor_label.modulate = Color(Color(1, 0.15, 0.1) * 2.5, 1) if alarm or shattered else Color(Color(0.3, 1, 0.6) * 2.0, 1)


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


## In an alarm a red light flashes over Meow-Mart's doors in the city, and the klaxon wails out there too.
func _update_street_alarm() -> void:
	var door := street_door()
	var on := alarm_left > 0.0 and door != Vector3.INF
	_street_alarm.visible = on
	if not on:
		return
	_street_alarm.global_position = door + street_outward() * 0.6 + Vector3(0, 3.4, 0)
	_street_alarm_light.light_energy = 4.0 * (0.5 + 0.5 * sin(_clock * TAU * 1.6))
	if _street_alarm_loop == null or not is_instance_valid(_street_alarm_loop):
		_street_alarm_loop = Sound.attach_loop("store_alarm", _street_alarm, alarm_volume_db - 2.0)


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# --- Building the store (once, in _ready; no randomness) ---

func _make_materials() -> void:
	_floor_mat = LevelKit.psx_material({"albedo_texture": preload("res://textures/mart_tiles.png"), "world_uv": true, "world_uv_scale": 0.5, "specular": 0.6, "roughness": 0.25})
	_wall_mat = LevelKit.psx_material({"albedo_color": Color(0.82, 0.86, 0.8), "specular": 0.2})
	_metal_mat = LevelKit.psx_material({"albedo_color": Color(0.35, 0.38, 0.42), "specular": 0.6, "roughness": 0.35})
	_shelf_mat = LevelKit.psx_material({"albedo_color": Color(0.9, 0.92, 0.95), "specular": 0.4, "roughness": 0.4})
	_neon_mat = LevelKit.psx_material({"emission_color": Color.WHITE, "emission_energy": 5.0})
	_tube_mat = LevelKit.psx_material({"albedo_color": Color.WHITE, "emission_color": Color.WHITE, "emission_energy": 3.0})
	_can_mat = LevelKit.psx_material({"albedo_color": Color.WHITE, "specular": 0.7, "roughness": 0.25})
	_ice_mat = LevelKit.psx_material({"albedo_color": Color(0.85, 0.95, 1.0), "emission_color": Color(0.5, 0.8, 1.0), "emission_energy": 0.6, "specular": 0.9, "roughness": 0.1})
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_mat.albedo_color = Color(0.55, 0.85, 1.0, 0.22)
	_glass_mat.metallic_specular = 0.9
	_glass_mat.roughness = 0.05
	_glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_water_mat = StandardMaterial3D.new()
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.albedo_color = Color(0.15, 0.5, 1.0, 0.4)
	_water_mat.emission_enabled = true
	_water_mat.emission = Color(0.05, 0.25, 0.6)
	_water_mat.roughness = 0.1
	_water_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_can_mesh = CylinderMesh.new()
	_can_mesh.top_radius = 0.065
	_can_mesh.bottom_radius = 0.065
	_can_mesh.height = 0.13
	_can_mesh.radial_segments = 6
	_can_mesh.rings = 0


func _build() -> void:
	var shell := StaticBody3D.new()
	shell.name = "Shell"
	add_child(shell)
	var half := ROOM * 0.5
	# Floor (seen) + floor (walked on), ceiling, outer walls.
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = LevelKit.subdivided_plane(Vector2(ROOM.x, ROOM.z))
	floor_mesh.material_override = _floor_mat
	add_child(floor_mesh)
	LevelKit.add_collision(shell, Vector3(0, -0.5, 0), Vector3(ROOM.x + WALL * 2.0, 1, ROOM.z + WALL * 2.0))
	_solid_box(shell, Vector3(0, ROOM.y + WALL * 0.5, 0), Vector3(ROOM.x + WALL * 2, WALL, ROOM.z + WALL * 2), _wall_mat)
	_solid_box(shell, Vector3(-half.x - WALL * 0.5, half.y, 0), Vector3(WALL, ROOM.y, ROOM.z), _wall_mat)
	_solid_box(shell, Vector3(half.x + WALL * 0.5, half.y, 0), Vector3(WALL, ROOM.y, ROOM.z), _wall_mat)
	_solid_box(shell, Vector3(0, half.y, -half.z - WALL * 0.5), Vector3(ROOM.x, ROOM.y, WALL), _wall_mat)
	_build_front(shell)
	_build_back_wall(shell)
	_build_lights()
	_build_checkouts(shell)
	for aisle in AISLE_X.size():
		_build_aisle(aisle)
	_build_counter(shell)
	_build_plate()
	_build_crate()
	_build_back_room(shell)
	_build_tank()
	_alarm_speaker = Node3D.new()
	_alarm_speaker.name = "AlarmSpeaker"
	_alarm_speaker.position = Vector3(0, 3.5, 0)
	add_child(_alarm_speaker)
	_street_alarm = Node3D.new()
	_street_alarm.name = "StreetAlarm"
	_street_alarm.top_level = true
	_street_alarm.visible = false
	add_child(_street_alarm)
	_street_alarm_light = LevelKit.add_light(_street_alarm, Vector3.ZERO, Color(1, 0.05, 0.05), 4.0, 12.0)
	var beacon := LevelKit.add_box(_street_alarm, Vector3.ZERO, Vector3(0.5, 0.3, 0.3), _neon_mat, false)
	beacon.set_instance_shader_parameter("instance_tint", Color(1, 0.1, 0.1))


## A box cats bump into (its collision goes on "body", the store's shell: hits come to us).
func _solid_box(body: StaticBody3D, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := LevelKit.add_box(self, center, size, material, false)
	LevelKit.add_collision(body, center, size)
	return mesh


## The front wall: glass, the sliding doors, and the night outside them.
## The front wall: the glass front with the sliding doors in the middle. The doorway is a real
## gap in the wall (the glass leaves only slide for show: you walk straight in and out).
func _build_front(shell: StaticBody3D) -> void:
	var half_x := ROOM.x * 0.5
	var z := FRONT_Z + WALL * 0.5
	for side in [-1.0, 1.0]:
		var width := half_x - GLASS_HALF
		_solid_box(shell, Vector3(side * (GLASS_HALF + width * 0.5), ROOM.y * 0.5, z), Vector3(width, ROOM.y, WALL), _wall_mat)
		# Fixed glass beside the doors (solid: you only get in and out through the doors).
		LevelKit.add_box(self, Vector3(side * (ENTRY_HALF_WIDTH + (GLASS_HALF - ENTRY_HALF_WIDTH) * 0.5), GLASS_HEIGHT * 0.5, z),
			Vector3(GLASS_HALF - ENTRY_HALF_WIDTH, GLASS_HEIGHT, 0.06), _glass_mat, false)
		LevelKit.add_collision(shell, Vector3(side * (ENTRY_HALF_WIDTH + (GLASS_HALF - ENTRY_HALF_WIDTH) * 0.5), GLASS_HEIGHT * 0.5, z), Vector3(GLASS_HALF - ENTRY_HALF_WIDTH, GLASS_HEIGHT, WALL))
	_solid_box(shell, Vector3(0, GLASS_HEIGHT + (ROOM.y - GLASS_HEIGHT) * 0.5, z), Vector3(GLASS_HALF * 2.0, ROOM.y - GLASS_HEIGHT, WALL), _wall_mat)
	# The two sliding leaves, just inside the glass line (no collision).
	for side in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.position = Vector3(side * ENTRY_HALF_WIDTH * 0.5, 0, z - 0.12)
		leaf.set_meta("home_x", leaf.position.x)
		leaf.set_meta("open_x", leaf.position.x + side * ENTRY_HALF_WIDTH * 0.95)
		add_child(leaf)
		LevelKit.add_box(leaf, Vector3(0, (GLASS_HEIGHT - 0.2) * 0.5, 0), Vector3(ENTRY_HALF_WIDTH - 0.04, GLASS_HEIGHT - 0.2, 0.05), _glass_mat, false)
		for face in [-1.0, 1.0]:  # a pink push bar on both faces
			var bar := LevelKit.add_box(leaf, Vector3(-side * ENTRY_HALF_WIDTH * 0.35, 1.0, face * 0.045), Vector3(0.06, 0.5, 0.04), _neon_mat, false)
			bar.set_instance_shader_parameter("instance_tint", Color(1, 0.1, 0.65))
		_door_leaves.append(leaf)
	# A rubber welcome mat (a box ON the floor, not a sticker 1 cm above it).
	var mat := LevelKit.add_box(self, Vector3(0, 0.025, FRONT_Z - 0.9), Vector3(2.2, 0.05, 1.0), _metal_mat, false)
	mat.set_instance_shader_parameter("instance_tint", Color(1.0, 0.45, 0.8))


## The wall between the shop floor and the back room, with the EMPLOYEES ONLY roller door.
func _build_back_wall(shell: StaticBody3D) -> void:
	var half_x := ROOM.x * 0.5
	var door_left := SECURITY_DOOR_X - SECURITY_DOOR_WIDTH * 0.5
	var door_right := SECURITY_DOOR_X + SECURITY_DOOR_WIDTH * 0.5
	_solid_box(shell, Vector3((-half_x + door_left) * 0.5, ROOM.y * 0.5, BACK_WALL_Z), Vector3(door_left + half_x, ROOM.y, WALL), _wall_mat)
	_solid_box(shell, Vector3((door_right + half_x) * 0.5, ROOM.y * 0.5, BACK_WALL_Z), Vector3(half_x - door_right, ROOM.y, WALL), _wall_mat)
	_solid_box(shell, Vector3(SECURITY_DOOR_X, SECURITY_DOOR_HEIGHT + (ROOM.y - SECURITY_DOOR_HEIGHT) * 0.5, BACK_WALL_Z),
		Vector3(SECURITY_DOOR_WIDTH, ROOM.y - SECURITY_DOOR_HEIGHT, WALL), _wall_mat)
	# The roller door: a StaticBody (its own, so it can slide up) on the shop side of the wall.
	_security_door = StaticBody3D.new()
	_security_door.name = "SecurityDoor"
	add_child(_security_door)
	var door_z := BACK_WALL_Z + WALL * 0.5 + 0.1
	var slab := LevelKit.add_box(_security_door, Vector3(SECURITY_DOOR_X, SECURITY_DOOR_HEIGHT * 0.5, door_z), Vector3(SECURITY_DOOR_WIDTH + 0.1, SECURITY_DOOR_HEIGHT, 0.12), _metal_mat, false)
	slab.set_instance_shader_parameter("instance_tint", Color(0.8, 0.8, 0.85))
	for i in 5:  # ribs, so it reads as a roller shutter
		LevelKit.add_box(_security_door, Vector3(SECURITY_DOOR_X, 0.3 + i * 0.5, door_z + 0.07), Vector3(SECURITY_DOOR_WIDTH + 0.1, 0.05, 0.03), _metal_mat, false)
	var stripe := LevelKit.add_box(_security_door, Vector3(SECURITY_DOOR_X, 0.12, door_z + 0.07), Vector3(SECURITY_DOOR_WIDTH + 0.1, 0.18, 0.03), _neon_mat, false)
	stripe.set_instance_shader_parameter("instance_tint", Color(1, 0.75, 0.1))
	_security_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SECURITY_DOOR_WIDTH, SECURITY_DOOR_HEIGHT, WALL + 0.3)
	_security_shape.shape = box
	_security_shape.position = Vector3(SECURITY_DOOR_X, SECURITY_DOOR_HEIGHT * 0.5, BACK_WALL_Z)
	_security_door.add_child(_security_shape)
	# The push bar on the back room side (E: OPEN DOOR), with a green light.
	var bar := LevelKit.add_box(self, EXIT_BUTTON_SPOT - Vector3(0, 0, 0.05), Vector3(0.6, 0.15, 0.1), _neon_mat, false)
	bar.set_instance_shader_parameter("instance_tint", Color(0.2, 1, 0.4))


func _build_lights() -> void:
	var spots: Array[Vector3] = [Vector3(-7, 0, -0.6), Vector3(-0.75, 0, -0.6), Vector3(5.5, 0, -0.6),
		Vector3(-7, 0, 3.6), Vector3(-0.75, 0, 3.6), Vector3(5.5, 0, 3.6), Vector3(-5, 0, -3.8), Vector3(5, 0, -3.8)]
	for spot in spots:
		var tube := LevelKit.add_box(self, Vector3(spot.x, ROOM.y - 0.12, spot.z), Vector3(2.4, 0.08, 0.25), _tube_mat, false)
		tube.set_instance_shader_parameter("instance_tint", light_color)
		_tubes.append(tube)
		_lights.append(LevelKit.add_light(self, Vector3(spot.x, ROOM.y - 0.5, spot.z), light_color, light_energy, light_range))
	LevelKit.add_light(self, Vector3(-4.0, 3.4, BACK_WALL_Z + 1.0), Color(1, 0.15, 0.6), 1.5, 6.0)
	LevelKit.add_light(self, Vector3(COUNTER_X - 1.2, 2.6, (COUNTER_Z.x + COUNTER_Z.y) * 0.5), Color(0.3, 0.8, 1), 1.4, 6.0)


func _build_checkouts(shell: StaticBody3D) -> void:
	for lane in CHECKOUT_X.size():
		var x: float = CHECKOUT_X[lane]
		var counter := _solid_box(shell, Vector3(x, 0.42, CHECKOUT_Z), Vector3(0.8, 0.84, CHECKOUT_LENGTH), _metal_mat)
		counter.set_instance_shader_parameter("instance_tint", Color(0.5, 0.45, 0.6))
		LevelKit.add_box(self, Vector3(x, 0.88, CHECKOUT_Z + 0.25), Vector3(0.55, 0.08, CHECKOUT_LENGTH - 0.7), _metal_mat, false)  # conveyor belt
		var register := LevelKit.add_box(self, Vector3(x, 1.06, CHECKOUT_Z - 0.9), Vector3(0.45, 0.4, 0.4), _metal_mat, false)
		register.set_instance_shader_parameter("instance_tint", Color(0.25, 0.25, 0.3))
		var screen := LevelKit.add_box(self, Vector3(x, 1.38, CHECKOUT_Z - 0.95), Vector3(0.35, 0.22, 0.05), _neon_mat, false)
		screen.set_instance_shader_parameter("instance_tint", Color(0.2, 1, 0.5))
		var scanner := LevelKit.add_box(self, Vector3(x, 0.9, CHECKOUT_Z - 0.55), Vector3(0.3, 0.04, 0.2), _neon_mat, false)
		scanner.set_instance_shader_parameter("instance_tint", Color(1, 0.1, 0.1))


## One aisle: four sections (each falls on its own, dominoes), stepped like stairs.
func _build_aisle(aisle: int) -> void:
	var x: float = AISLE_X[aisle]
	var body := StaticBody3D.new()
	body.name = "Aisle%d" % (aisle + 1)
	add_child(body)
	var bottom := 0.0
	for tier in TIERS:
		var width: float = tier[0]
		var top: float = tier[1]
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, top - bottom, AISLE_LENGTH)
		shape.shape = box
		shape.position = Vector3(x, (top + bottom) * 0.5, AISLE_Z)
		body.add_child(shape)
		_aisle_shapes[aisle].append(shape)
		bottom = top
	var rubble := CollisionShape3D.new()
	var rubble_box := BoxShape3D.new()
	rubble_box.size = Vector3(1.6, 0.6, AISLE_LENGTH)
	rubble.shape = rubble_box
	rubble.disabled = true
	body.add_child(rubble)
	_aisle_rubble.append(rubble)

	var seg_length := AISLE_LENGTH / AISLE_SEGMENTS
	for seg in AISLE_SEGMENTS:
		var seg_z := AISLE_Z - AISLE_LENGTH * 0.5 + seg_length * (seg + 0.5)
		var pivot := Node3D.new()
		pivot.position = Vector3(x, 0, seg_z)
		add_child(pivot)
		var inner := Node3D.new()
		pivot.add_child(inner)
		_segments[aisle].append({"pivot": pivot, "inner": inner, "home": pivot.position})
		bottom = 0.0
		for tier in TIERS:
			var shelf := LevelKit.add_box(inner, Vector3(0, (float(tier[1]) + bottom) * 0.5, 0), Vector3(tier[0], float(tier[1]) - bottom, seg_length - 0.02), _shelf_mat, false)
			shelf.set_instance_shader_parameter("instance_tint", Color(0.95, 0.95, 1.0) if (seg + aisle) % 2 == 0 else Color(0.85, 0.9, 1.0))
			bottom = tier[1]
		# Each side of each section has one tier with a can stack, one with a loot spot and one with
		# boxes of stock (which tier gets what turns round from section to section).
		for side in [-1, 1]:
			var stack_tier := (seg + (1 if side > 0 else 0) + aisle) % 3
			var loot_tier := (stack_tier + 1) % 3
			var stock_tier := (stack_tier + 2) % 3
			var z_shift := 0.25 if side > 0 else -0.25
			_add_stack(aisle, _ledge_spot(x, side, stack_tier, seg_z + z_shift))
			_loot_shelf.append(_ledge_spot(x, side, loot_tier, seg_z - z_shift) + Vector3(0, 0.15, 0))
			for n in 3:
				var at := _ledge_spot(0.0, side, stock_tier, (n - 1) * 0.28)
				var product := LevelKit.add_box(inner, at + Vector3(0, 0.14, 0), Vector3(0.12, 0.28, 0.2), _can_mat, false)
				product.set_instance_shader_parameter("instance_tint", PRODUCT_COLORS[(seg * 3 + n + aisle * 2 + side) % PRODUCT_COLORS.size()])


## The middle of a ledge (where goods sit) on this side of an aisle at "x", on step "tier".
func _ledge_spot(x: float, side: int, tier: int, z: float) -> Vector3:
	var outer: float = TIERS[tier][0] * 0.5
	var inner: float = TIERS[tier + 1][0] * 0.5 if tier + 1 < TIERS.size() else 0.0
	return Vector3(x + side * (outer + inner) * 0.5, TIERS[tier][1], z)


## A swattable stack of three cans (two at the bottom, one on top).
func _add_stack(aisle: int, at: Vector3) -> void:
	var stack := Node3D.new()
	stack.position = at
	add_child(stack)
	var id := _stacks.size()
	for i in 3:
		var can := MeshInstance3D.new()
		can.mesh = _can_mesh
		can.material_override = _can_mat
		can.set_instance_shader_parameter("instance_tint", PRODUCT_COLORS[(id + i) % PRODUCT_COLORS.size()])
		can.position = Vector3(-0.07 + 0.14 * i, 0.065, 0) if i < 2 else Vector3(0, 0.195, 0)
		can.set_meta("home", can.transform)
		stack.add_child(can)
	stack.set_meta("id", id)
	stack.set_meta("aisle", aisle)
	stack.set_meta("home", stack.transform)
	_stacks.append(stack)


## The FRESH CATCH counter: a long chiller along the east wall, crushed ice on top.
func _build_counter(shell: StaticBody3D) -> void:
	var length := COUNTER_Z.y - COUNTER_Z.x
	var mid := (COUNTER_Z.x + COUNTER_Z.y) * 0.5
	var body := _solid_box(shell, Vector3(COUNTER_X, 0.5, mid), Vector3(1.2, 1.0, length), _metal_mat)
	body.set_instance_shader_parameter("instance_tint", Color(0.55, 0.7, 0.8))
	LevelKit.add_box(self, Vector3(COUNTER_X + 0.05, 1.05, mid), Vector3(1.0, 0.1, length - 0.1), _ice_mat, false)
	# A sloped glass sneeze guard on the shop side.
	var guard := LevelKit.add_box(self, Vector3(COUNTER_X - 0.62, 1.35, mid), Vector3(0.05, 0.5, length - 0.2), _glass_mat, false)
	guard.rotation.z = deg_to_rad(-15.0)
	# Some fish just for show, lying on the ice...
	var show_fish := preload("res://scenes/items/sardine.tscn")
	for i in 6:
		var fish := show_fish.instantiate() as Node3D
		fish.position = Vector3(COUNTER_X + 0.25, 1.13, COUNTER_Z.x + 0.4 + i * (length - 0.8) / 5.0)
		fish.rotation = Vector3(0, PI / 2 + (0.3 if i % 2 == 0 else -0.3), PI / 2)
		add_child(fish)
	# ...and the spots where real FRESH CATCH (loot) can lie.
	for i in 5:
		_loot_counter.append(Vector3(COUNTER_X - 0.2, 1.25, COUNTER_Z.x + 0.6 + i * (length - 1.2) / 4.0))


func _build_plate() -> void:
	var frame := LevelKit.add_box(self, Vector3(PLATE_SPOT.x, 0.02, PLATE_SPOT.z), Vector3(PLATE_HALF * 2.0 + 0.2, 0.04, PLATE_HALF * 2.0 + 0.2), _metal_mat, false)
	frame.set_instance_shader_parameter("instance_tint", Color(0.3, 0.3, 0.32))
	_plate_top = LevelKit.add_box(self, Vector3(PLATE_SPOT.x, 0.07, PLATE_SPOT.z), Vector3(PLATE_HALF * 2.0, 0.06, PLATE_HALF * 2.0), _neon_mat, false)
	_plate_light = LevelKit.add_light(self, PLATE_SPOT + Vector3(0, 0.8, 0), Color(1, 0.2, 0.2), 1.2, 3.5)


## The heavy shopping basket: shove it by walking into it, or [E] DRAG it behind you.
func _build_crate() -> void:
	_crate = StaticBody3D.new()
	_crate.name = "Basket"
	_crate.position = crate_pos + Vector3(0, CRATE_SIZE * 0.5, 0)
	add_child(_crate)
	LevelKit.add_collision(_crate, Vector3.ZERO, Vector3.ONE * CRATE_SIZE)
	var model := LevelKit.instantiate_model("res://models/cardboard_box.glb", _crate, Vector3(0, -CRATE_SIZE * 0.5, 0), 0.3)
	if model != null:
		model.scale = Vector3.ONE * 1.15
	else:
		LevelKit.add_box(_crate, Vector3.ZERO, Vector3.ONE * CRATE_SIZE, _metal_mat, false)
	var tag := LevelKit.add_sign(_crate, "HEAVY", Vector3(0, CRATE_SIZE * 0.5 + 0.25, 0), Color(1, 0.8, 0.2), 20, 0.0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED


## The back room: a security desk with a monitor, racks of spare crates (the tank is its own piece).
func _build_back_room(shell: StaticBody3D) -> void:
	var desk := _solid_box(shell, Vector3(-8.5, 0.4, -4.6), Vector3(2.2, 0.8, 1.0), _metal_mat)
	desk.set_instance_shader_parameter("instance_tint", Color(0.3, 0.3, 0.35))
	var monitor := LevelKit.add_box(self, Vector3(-8.5, 1.15, -4.85), Vector3(0.9, 0.65, 0.4), _metal_mat, false)
	monitor.set_instance_shader_parameter("instance_tint", Color(0.15, 0.15, 0.18))
	var screen := LevelKit.add_box(self, Vector3(-8.5, 1.15, -4.64), Vector3(0.75, 0.5, 0.02), _neon_mat, false)
	screen.set_instance_shader_parameter("instance_tint", Color(0.05, 0.3, 0.15))
	_monitor_label = LevelKit.add_sign(self, "", Vector3(-8.5, 1.15, -4.6), Color(0.3, 1, 0.6), 12, 0.0)
	_monitor_label.pixel_size = 0.006
	LevelKit.add_light(self, Vector3(-8.5, 1.4, -4.0), Color(0.3, 1, 0.6), 0.8, 3.0)
	# Racks of spare stock on the east side.
	for level in 3:
		_solid_box(shell, Vector3(9.3, 0.05 + level * 0.8, -3.8), Vector3(1.6, 0.06, 2.6), _metal_mat)
		for n in 3:
			var crate := LevelKit.add_box(self, Vector3(9.3, 0.08 + level * 0.8 + 0.25, -4.7 + n * 0.9), Vector3(0.9, 0.5, 0.7), _shelf_mat, false)
			crate.set_instance_shader_parameter("instance_tint", Color(0.7, 0.5, 0.3))
	for post in [Vector3(8.55, 0, -5.05), Vector3(10.05, 0, -5.05), Vector3(8.55, 0, -2.55), Vector3(10.05, 0, -2.55)]:
		_solid_box(shell, post + Vector3(0, 1.1, 0), Vector3(0.08, 2.2, 0.08), _metal_mat)


## THE GOLDEN KOI TANK: glass, water, the koi swimming round, a gold light over it.
func _build_tank() -> void:
	# (A HitRelay: bolts, bat swings and blasts that hit the tank come to _on_tank_hit.)
	_tank = HitRelay.new()
	_tank.name = "KoiTank"
	_tank.position = TANK_SPOT
	_tank.on_hit = _on_tank_hit
	add_child(_tank)
	var stand := LevelKit.add_box(_tank, Vector3(0, TANK_STAND * 0.5, 0), Vector3(TANK_SIZE.x + 0.2, TANK_STAND, TANK_SIZE.z + 0.2), _metal_mat, false)
	stand.set_instance_shader_parameter("instance_tint", Color(0.2, 0.18, 0.15))
	var plaque := LevelKit.add_sign(_tank, "GOLDEN KOI\nNOT FOR SALE", Vector3(0, TANK_STAND * 0.5, TANK_SIZE.z * 0.5 + 0.12), Color(1, 0.8, 0.2), 14, 0.0)
	plaque.pixel_size = 0.01
	_tank_water = LevelKit.add_box(_tank, Vector3(0, TANK_STAND + 0.48, 0), Vector3(TANK_SIZE.x - 0.08, 0.95, TANK_SIZE.z - 0.08), _water_mat, false)
	var glass_material := _glass_mat.duplicate() as StandardMaterial3D  # (its own: it cracks)
	_tank_glass = LevelKit.add_box(_tank, Vector3(0, TANK_STAND + TANK_SIZE.y * 0.5, 0), TANK_SIZE, glass_material, false)
	_tank_glass.material_override = glass_material
	_koi = preload("res://scenes/items/golden_koi.tscn").instantiate() as Node3D
	_koi.scale = Vector3.ONE * 1.3
	_tank.add_child(_koi)
	_tank_light = LevelKit.add_light(_tank, Vector3(0, 2.8, 0.4), Color(1, 0.75, 0.25), 2.5, 6.0)
	# The hit box (a StaticBody on the tank, so bolts and bats hit it and come to receive_hit).
	var body := StaticBody3D.new()
	body.name = "TankBody"
	_tank.add_child(body)
	_tank_shape = CollisionShape3D.new()
	_tank_shape.shape = BoxShape3D.new()
	body.add_child(_tank_shape)
	# After it breaks: a puddle (a flat box ON the floor) and broken glass.
	var water_floor := StandardMaterial3D.new()
	water_floor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_floor.albedo_color = Color(0.2, 0.5, 1.0, 0.45)
	water_floor.roughness = 0.05
	water_floor.metallic_specular = 1.0
	var puddle_mesh := CylinderMesh.new()
	puddle_mesh.top_radius = 1.5
	puddle_mesh.bottom_radius = 1.5
	puddle_mesh.height = 0.04
	puddle_mesh.radial_segments = 10
	puddle_mesh.rings = 0
	_puddle = MeshInstance3D.new()
	_puddle.mesh = puddle_mesh
	_puddle.material_override = water_floor
	_puddle.position = TANK_SPOT + Vector3(0, 0.02, 0.6)
	_puddle.visible = false
	add_child(_puddle)
	for i in 14:
		var shard := LevelKit.add_box(self, TANK_SPOT + Vector3(cos(i * 2.4) * (0.9 + 0.1 * (i % 4)), 0.02, sin(i * 2.4) * (0.6 + 0.1 * (i % 3)) + 0.3),
			Vector3(0.12, 0.04, 0.07), _ice_mat, false)
		shard.rotation.y = i * 0.7
		shard.visible = false
		_shards.append(shard)


# --- Tests (DevCapture) ---

## Host, tests only (--shatter_tank): break the tank as if this player had.
func test_shatter(player_id: int) -> void:
	if multiplayer.is_server() and not shattered:
		_shatter_tank(player_id)
