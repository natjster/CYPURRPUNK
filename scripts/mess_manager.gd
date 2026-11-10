class_name MessManager
extends Node
## CYPURRPUNK — MESS-MAKING ("Chaos versus Clean", ROADMAP.md §3). Cats are the mess a clean-freak
## AI can't tidy up: knock over bins, cones and boxes, scratch OVERCLEAN's posters. Each mess adds a
## little HEAT, counts on the RAID REPORT (MESS column, AGENT OF CHAOS award), and DISTRACTS the
## VAC-COPs: a patrolling bot that spots a mess drives over and tidies it up (roomba.gd TIDY_GO /
## TIDYING), half-blind while it does. So one cat trashes a corner while another sneaks the koi past.
##
## Node: "Mess" under Main in scenes/main.tscn (in the GameSystems group, like Heat or Wallet).
## Select it to tune the numbers below in the Inspector.
##
## HOW A MESS IS MADE (all of these end in knock() on the computer that noticed it):
##   - a cat runs into a prop (cat_player.gd calls cat_bump every frame on the cat's owner's computer):
##     cones, boxes and posters fall over at a walk; a heavy bin needs ZOOMIES (Bin Knock Speed);
##   - a car drives into one (getaway_car.gd calls car_bump on the driver's computer);
##   - a bolt, blast or bat hits one (MessProp.receive_hit, the Hit framework);
##   - a cat presses E next to one: "KNOCK OVER", "TIP OVER", "SHOVE", "SCRATCH" (MessProp.interact).
## knock() asks the HOST (request_knock), which checks it, adds the heat, emits
## Events.mess_made(player_id, 1) and tells every computer (_set_knocked) to tip it over.
##
## The props themselves are built by the city (city_generator.gd _add_mess_prop) in a fixed order,
## numbered 0, 1, 2... in CityGenerator.mess_props: the same numbers on every computer, so only the
## number goes over the network. A late joiner gets the list of knocked numbers (send_state_to).
## A new district builds a new city, so every mess is gone (the list starts empty again).

static var instance: MessManager

@export var enabled: bool = true

@export_group("Making a mess")
## Heat each mess adds (heat goes 0 to 100; a whole raid adds ~100 over 10 minutes).
@export var heat_per_mess: float = 0.4
## How fast (metres per second) a cat must run into a BIN to knock it over. Cats walk at 4.5 and
## do ZOOMIES at 9 (cat_player.gd), so 6 = only zoomies tip a bin.
@export var bin_knock_speed: float = 6.0
## The same for cones, boxes and posters (light things): a walk is enough.
@export var light_knock_speed: float = 1.5
## How close (metres, edge to edge) counts as running into a prop.
@export var bump_reach: float = 0.55
## A car knocks props over faster than this (metres per second), within Car Reach of its middle.
@export var car_knock_speed: float = 3.0
@export var car_reach: float = 2.0
## E reaches this far (metres past the prop's edge).
@export var interact_reach: float = 1.2
## The [E] prompts for each kind of prop.
@export var bin_prompt: String = "TIP OVER"
@export var cone_prompt: String = "KNOCK OVER"
@export var box_prompt: String = "SHOVE"
@export var poster_prompt: String = "SCRATCH"

@export_group("OVERCLEAN remarks")
## OVERCLEAN says something passive-aggressive when this many messes are made within Remark Window
## seconds (anywhere in the city), at most once every Remark Cooldown seconds.
@export var remark_after_messes: int = 4
@export var remark_window: float = 20.0
@export var remark_cooldown: float = 75.0
## sounds/sfx/<name>.wav (made by tools/sound_specs/mess.json) and the subtitle for each.
@export var remark_sounds: Array[String] = ["overclean_mess_1", "overclean_mess_2", "overclean_mess_3"]
@export var remark_lines: Array[String] = [
	"A mess has been detected. Please remain where you are.",
	"Shedding is a crime. Knocking things over is also a crime.",
	"Unscheduled mess detected. Sanitation units will tidy up after you. As always.",
]

## The plain PS1 material the litter bits use (each bit gets its own colour via instance_tint).
var debris_material: Material

## Every computer: how many messes have been made / tidied this district (for tests and the log).
var messes_made: int = 0
var messes_tidied: int = 0

var _clock: float = 0.0
var _recent: Array[float] = []      # every computer: when recent messes happened (for the remarks)
var _last_remark_at: float = -1000.0
var _asked: Dictionary = {}          # this computer: {prop id: time we last asked}, so we ask once
var _pending: Dictionary = {}        # client: knocked props the host told us about before our city existed


## Host: props knocked over this trip, player id -> count (player_messes_this_trip).
var _trip_messes := {}


func _enter_tree() -> void:
	instance = self
	add_to_group(GameSystems.GROUP)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	debris_material = LevelKit.psx_material({"albedo_color": Color.WHITE, "world_uv": false})
	_hook_city.call_deferred()  # (after Main is ready, so Game.instance.city exists)


func _hook_city() -> void:
	if Game.instance != null and Game.instance.city != null:
		Game.instance.city.generated.connect(_on_city_generated)


func _process(delta: float) -> void:
	_clock += delta


## Every prop in the city (index = prop id). Empty before the city exists.
func props() -> Array[MessProp]:
	if Game.instance == null or Game.instance.city == null:
		return []
	return Game.instance.city.mess_props


func prop(id: int) -> MessProp:
	var all := props()
	return all[id] if id >= 0 and id < all.size() and is_instance_valid(all[id]) else null


## The [E] line for a kind of prop (MessProp.interact_prompt).
func prompt_for(kind: MessProp.Kind) -> String:
	match kind:
		MessProp.Kind.BIN: return bin_prompt
		MessProp.Kind.CONE: return cone_prompt
		MessProp.Kind.BOX: return box_prompt
		_: return poster_prompt


# --- Noticing a mess (on whichever computer saw it happen) ---

## The cat's OWNER, every physics frame (cat_player.gd): did we just run into something?
## "push" = the cat's speed before move_and_slide (a bin stops the cat, so afterwards it's ~0).
func cat_bump(cat: CatPlayer, push: Vector3) -> void:
	if not enabled or not cat.visible or cat.is_downed():
		return
	var flat := Vector3(push.x, 0, push.z)
	var speed := flat.length()
	if speed < light_knock_speed:
		return
	var here := cat.global_position
	for p in props():
		if p.knocked or p.kind == MessProp.Kind.POSTER:  # (posters: E or a hit, you can't run into a wall)
			continue
		var to_prop := Motion.flat(p.global_position - here)
		var gap := to_prop.length()
		if gap > p.radius() + bump_reach or absf(p.global_position.y - here.y) > 1.5:
			continue
		var needed := bin_knock_speed if p.kind == MessProp.Kind.BIN else light_knock_speed
		if speed >= needed and (gap < 0.05 or flat.normalized().dot(to_prop / gap) > 0.3):  # running AT it
			knock(cat.player_id, p.id, flat / speed)


## The driver's computer, every physics frame (getaway_car.gd): did the car plough through something?
func car_bump(car: GetawayCar) -> void:
	if not enabled or car.driver_id == 0:
		return
	var flat := Vector3(car.linear_velocity.x, 0, car.linear_velocity.z)
	var speed := flat.length()
	if speed < car_knock_speed:
		return
	var here := car.global_position
	for p in props():
		if p.knocked or p.kind == MessProp.Kind.POSTER:
			continue
		if Motion.flat_distance(p.global_position, here) < car_reach + p.radius():
			knock(car.driver_id, p.id, flat / speed)


## Ask the host to knock prop "id" over, pushed along "direction", credited to "player_id".
## Safe to call often: each prop is only asked about once a second from this computer.
func knock(player_id: int, id: int, direction: Vector3) -> void:
	var p := prop(id)
	if not enabled or p == null or p.knocked:
		return
	if _clock - float(_asked.get(id, -10.0)) < 1.0:
		return
	_asked[id] = _clock
	var flat := Motion.flat(direction)
	var fall_yaw := atan2(-flat.x, -flat.z) if flat.length() > 0.01 else 0.0
	request_knock.rpc_id(1, player_id, id, fall_yaw)


## Host: a player knocked a prop over. Check it, then tell everyone.
@rpc("any_peer", "call_local", "reliable")
func request_knock(player_id: int, id: int, fall_yaw: float) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	var p := prop(id)
	if p == null or p.knocked:
		return
	var cat := Game.instance.cat_for(player_id)
	if cat == null or UndergroundHub.is_in_hub(cat.global_position):
		return
	_set_knocked.rpc(id, true, fall_yaw)
	_trip_messes[player_id] = int(_trip_messes.get(player_id, 0)) + 1  # (BIN DAY's chaos bonus)
	if HeatMeter.instance != null:
		HeatMeter.instance.add_heat(heat_per_mess)
	Events.mess_made.emit(player_id, 1)  # (the RAID REPORT counts it: MESS, AGENT OF CHAOS)
	print("[Mess] player %d knocked over prop #%d (%s)" % [player_id, id, MessProp.Kind.keys()[p.kind]])


# --- Tidying up (the VAC-COPs, roomba.gd) ---

## Host: the nearest knocked-over prop within "reach" of "from" that no other bot is already
## going to, or null. The bot asking gets it (it's "claimed" until it's tidied or the bot gives up).
func claim_nearest(from: Vector3, reach: float, bot: Node) -> MessProp:
	var best: MessProp = null
	var best_distance := reach
	for p in props():
		if not p.knocked or _is_claimed(p, bot):
			continue
		var distance := Motion.flat_distance(p.tidy_spot(), from)
		if distance < best_distance and absf(p.global_position.y - from.y) < 3.0:
			best = p
			best_distance = distance
	if best != null:
		best.claimed_by = bot
	return best


## Someone else (still alive, still on its way or tidying THIS prop) has it.
func _is_claimed(p: MessProp, asker: Node) -> bool:
	var bot := p.claimed_by
	if bot == null or bot == asker or not is_instance_valid(bot) or bot.is_queued_for_deletion():
		return false
	return bot.has_method("tidying_prop") and bot.tidying_prop() == p


## Host: a VAC-COP finished tidying prop "id": it stands back up on every computer.
func tidy(id: int) -> void:
	if not multiplayer.is_server():
		return
	var p := prop(id)
	if p == null or not p.knocked:
		return
	_set_knocked.rpc(id, false, 0.0)
	print("[Mess] prop #%d tidied up" % id)


# --- Every computer ---

## Host -> everyone: prop "id" is now knocked over (or tidied back up).
@rpc("authority", "call_local", "reliable")
func _set_knocked(id: int, knocked: bool, fall_yaw: float) -> void:
	var p := prop(id)
	if p == null:
		if knocked:
			_pending[id] = fall_yaw
		return
	if knocked == p.knocked:
		return
	if knocked:
		p.show_knocked(fall_yaw, false)
		messes_made += 1
		_maybe_remark()
	else:
		p.show_standing(false)
		messes_tidied += 1


## Host -> a late joiner: every prop that's lying knocked over right now (no sounds, no remarks).
@rpc("authority", "call_remote", "reliable")
func _set_all_knocked(ids: PackedInt32Array, yaws: PackedFloat32Array) -> void:
	for i in ids.size():
		var p := prop(ids[i])
		if p == null:
			_pending[ids[i]] = yaws[i]
		elif not p.knocked:
			p.show_knocked(yaws[i], true)


## A new city was built (a new district, or a joiner's first city): every prop is new and standing.
func _on_city_generated(_seed: int) -> void:
	_asked.clear()
	_recent.clear()
	messes_made = 0
	messes_tidied = 0
	# (The props are made during generate(), so they exist now: catch up on what the host sent early.)
	for id in _pending:
		var p := prop(id)
		if p != null and not p.knocked:
			p.show_knocked(_pending[id], true)
	_pending.clear()


## OVERCLEAN notices when the city gets trashed (every computer on its own: the knocks reach
## everyone, so every computer hears the same remark; only players up top hear it).
func _maybe_remark() -> void:
	_recent.append(_clock)
	while not _recent.is_empty() and _clock - _recent[0] > remark_window:
		_recent.pop_front()
	if _recent.size() < remark_after_messes or _clock - _last_remark_at < remark_cooldown:
		return
	if OvercleanAnnouncer.instance == null or remark_sounds.is_empty():
		return
	_last_remark_at = _clock
	_recent.clear()
	var pick := randi() % remark_sounds.size()
	OvercleanAnnouncer.instance.say(remark_sounds[pick], remark_lines[pick] if pick < remark_lines.size() else "", false, 0.8, "lots of mess")


# --- Game systems (scripts/game_systems.gd) ---

## Host: a late joiner gets every knocked-over prop.
func send_state_to(peer: int) -> void:
	var ids := PackedInt32Array()
	var yaws := PackedFloat32Array()
	for p in props():
		if p.knocked:
			ids.append(p.id)
			yaws.append(p.fall_yaw)
	if not ids.is_empty():
		_set_all_knocked.rpc_id(peer, ids, yaws)


## Host: how many props this player has knocked over on this trip up top (BIN DAY pays for
## them when they extract: fish_heist.gd, scripts/district_twist.gd).
func player_messes_this_trip(player_id: int) -> int:
	return int(_trip_messes.get(player_id, 0))


## Host: their trip is over (extracted): start counting from 0 again.
func clear_trip_messes(player_id: int) -> void:
	_trip_messes.erase(player_id)


## Host: a new district (the city was rebuilt just before this, so the props are fresh).
func start_district() -> void:
	_trip_messes.clear()
	_asked.clear()
