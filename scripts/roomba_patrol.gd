class_name RoombaPatrol
extends Node3D
## THE VAC-COP PATROL: puts police Roombas (scenes/roomba.tscn) on the city's sidewalks and
## sends a new one some time after one is destroyed.
## Attach to the "Roombas" node in main.tscn. Its sibling "RoombaSpawner" (a
## MultiplayerSpawner pointing at Roombas) copies every Roomba to every player's game,
## including players who join later.
##
## How many are out follows the HEAT (scripts/heat_meter.gd): every heat level adds a few, and
## The MEGA VAC-COP (scenes/roomba_boss.tscn) is called in every boss_every_kills VAC-COPs the
## crew destroys (up to bosses_per_district times), and always comes out for the DEEP CLEAN.
## At max heat fish_heist.gd also seals the hatch and starts the DEEP CLEAN: it sets
## deep_clean_extra, and a swarm that many strong pours in close to the cats still up top,
## hunting them from much further away (roomba.gd _can_chase).
##
## Only the HOST creates Roombas (game.gd calls start_patrol() when hosting). Where they appear
## is random each game — they're not part of the city seed, so they never change the city.

const ROOMBA_SCENE: PackedScene = preload("res://scenes/roomba.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/roomba_boss.tscn")

## How many Roombas patrol the city at once when the city is calm (HEAT level 1).
## Hotter levels add more (HeatMeter.extra_roombas_per_level, on the Heat node).
@export var roomba_count: int = 20
## More players = more VAC-COPs: this many extra for every player beyond the second
## (8 players with 2.0 = 12 extra). Decimals are fine (0.5 = one extra per two players).
@export var extra_roombas_per_player: float = 2.0
## Seconds before a destroyed Roomba is replaced.
@export var respawn_seconds: float = 15.0
## New Roombas never appear closer than this to a cat, or to the centre crossroads where
## cats arrive from the hub.
@export var min_spawn_distance: float = 25.0
## When the heat goes UP a level, one reinforcement Roomba arrives every this many seconds
## until there are enough. (When it cools down, spare Roombas far from cats go home just as slowly.)
@export var reinforce_seconds: float = 2.0

@export_group("MEGA VAC-COP (boss)")
## The boss appears at least this far from every cat (it drives in from across town).
@export var boss_spawn_distance: float = 45.0
## Every this many regular VAC-COPs the crew destroys, the MEGA VAC-COP is called in...
@export var boss_every_kills: int = 3
## ...but no more than this many times per district. (The DEEP CLEAN's boss doesn't count.)
@export var bosses_per_district: int = 4

@export_group("DEEP CLEAN swarm")
## During the DEEP CLEAN, swarm Roombas appear between these distances (metres) from a cat up top.
@export var swarm_min_distance: float = 15.0
@export var swarm_max_distance: float = 40.0
## During the DEEP CLEAN every Roomba spots cats this many times further away than normal.
@export var swarm_sight_multiplier: float = 6.0
## Extra swarm Roombas spawned per physics frame while the DEEP CLEAN fills up.
@export var swarm_spawns_per_frame: int = 2

## The one patrol (RoombaPatrol.instance).
static var instance: RoombaPatrol

## Host: how many EXTRA Roombas the DEEP CLEAN wants out right now (0 = no deep clean).
## Set by fish_heist.gd.
var deep_clean_extra: int = 0

var _respawn_at: Array[float] = []  # host: when each replacement is due
var _clock: float = 0.0
var _next_number: int = 0
var _next_change_at: float = 0.0  # host: when the next reinforcement may arrive / leave
var _boss: Roomba = null
## Host: regular Roombas destroyed since the last boss call, and bosses called this district.
var _kills_toward_boss: int = 0
var _bosses_called: int = 0
## True once this computer hosts a game (start_patrol). Before that - in the start menu the
## game counts as its own "host" - no Roombas may be sent out: they'd clash with the real
## host's when we join someone.
var _patrolling: bool = false
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	_rng.randomize()


## Host: clear any old Roombas and put a fresh patrol out (called when a game is hosted).
func start_patrol() -> void:
	for old in get_children():
		old.queue_free()
	_patrolling = true
	_respawn_at.clear()
	_boss = null
	deep_clean_extra = 0
	_kills_toward_boss = 0
	_bosses_called = 0
	for i in roomba_count:
		_spawn_one()


## Host: a Roomba blew up. Show the explosion everywhere and queue its replacement
## (the boss has no replacement). Every boss_every_kills regulars destroyed calls the boss in.
func roomba_destroyed(roomba: Roomba) -> void:
	_show_explosion.rpc(roomba.global_position)
	if roomba == _boss:
		_boss = null
		_announce.rpc("THE MEGA VAC-COP IS DOWN!")
	else:
		_respawn_at.append(_clock + respawn_seconds)
		_kills_toward_boss += 1


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not _patrolling:
		return
	_clock += delta
	for i in range(_respawn_at.size() - 1, -1, -1):
		if _clock >= _respawn_at[i]:
			_respawn_at.remove_at(i)
			_spawn_one()
	_follow_the_heat()


## Host: more Roombas when the city is hot, and the MEGA VAC-COP when it's called in.
func _follow_the_heat() -> void:
	var heat := HeatMeter.instance
	# The boss (one at a time; it stays until it's destroyed or the district ends):
	#   - called in after every boss_every_kills VAC-COPs destroyed, up to bosses_per_district,
	#   - and always out for the DEEP CLEAN (max heat).
	if _boss == null:
		var called := _kills_toward_boss >= boss_every_kills and _bosses_called < bosses_per_district
		if called or deep_clean_extra > 0 or heat.level() == HeatMeter.MAX_LEVEL:
			if called:
				_kills_toward_boss -= boss_every_kills
				_bosses_called += 1
			_boss = BOSS_SCENE.instantiate() as Roomba
			_boss.name = "RoombaBoss%d" % _next_number
			_next_number += 1
			_boss.position = _spawn_spot(boss_spawn_distance)
			add_child(_boss, true)
			_announce.rpc("MEGA VAC-COP DEPLOYED (%d/%d this district)" % [_bosses_called, bosses_per_district])
			_boss_siren.rpc()  # everyone hears it coming

	# Regular Roombas: how many are out (or on their way back after being smashed)?
	# (During the DEEP CLEAN there's no waiting: the swarm pours in, one every frame.)
	if _clock < _next_change_at and deep_clean_extra == 0:
		return
	var regulars: Array[Roomba] = []
	for child in get_children():
		var roomba := child as Roomba
		if roomba != null and not roomba.is_boss and not roomba.is_queued_for_deletion():
			regulars.append(roomba)
	var wanted := roomba_count + heat.extra_roombas() + deep_clean_extra \
		+ floori(extra_roombas_per_player * maxi(Game.instance.player_count() - 2, 0))
	if regulars.size() + _respawn_at.size() < wanted:
		for i in (swarm_spawns_per_frame if deep_clean_extra > 0 else 1):
			_spawn_one(deep_clean_extra > 0)
		_next_change_at = _clock + reinforce_seconds
	elif regulars.size() + _respawn_at.size() > wanted:
		# Too many for this heat: send one home, but only one nobody is looking at.
		for roomba in regulars:
			if roomba.state == Roomba.State.PATROL and _far_from_cats(roomba.global_position, 30.0):
				roomba.queue_free()
				break
		_next_change_at = _clock + reinforce_seconds


## "swarm" = DEEP CLEAN: appear close to a cat that's still up top.
func _spawn_one(swarm: bool = false) -> void:
	var roomba := ROOMBA_SCENE.instantiate() as Roomba
	roomba.name = "Roomba%d" % _next_number  # unique names keep everyone's copies matched up
	_next_number += 1
	roomba.position = _swarm_spot() if swarm else _spawn_spot()
	add_child(roomba, true)


## DEEP CLEAN: a sidewalk spot near (but not on top of) a random cat up in the city.
func _swarm_spot() -> Vector3:
	var targets: Array[Vector3] = []
	for cat in Game.instance.players.get_children():
		var where := (cat as Node3D).global_position
		if not UndergroundHub.is_in_hub(where):
			targets.append(where)
	if targets.is_empty():
		return _spawn_spot()
	var target := targets[_rng.randi_range(0, targets.size() - 1)]
	var spot := Vector3.ZERO
	for attempt in 40:
		spot = ItemManager.instance.random_sidewalk_spot(_rng) + Vector3(0, 0.1, 0)
		var d := spot.distance_to(target)
		if d > swarm_min_distance and d < swarm_max_distance:
			break
	return spot


## A random sidewalk spot away from the centre and at least "distance" from every cat.
func _spawn_spot(distance: float = min_spawn_distance) -> Vector3:
	var spot := Vector3.ZERO
	for attempt in 30:
		spot = ItemManager.instance.random_sidewalk_spot(_rng) + Vector3(0, 0.1, 0)
		if Vector2(spot.x, spot.z).length() > min_spawn_distance and _far_from_cats(spot, distance):
			break
	return spot


func _far_from_cats(spot: Vector3, distance: float) -> bool:
	for cat in Game.instance.players.get_children():
		if spot.distance_to((cat as Node3D).global_position) < distance:
			return false
	return true


## Host -> everyone: news about the MEGA VAC-COP. Console only now (the HUD was simplified, so
## nothing pops up on screen).
@rpc("authority", "call_local", "reliable")
func _announce(text: String) -> void:
	print("[Roombas] " + text)


## Host -> everyone: the MEGA VAC-COP's siren (everywhere at once: it's on its way).
@rpc("authority", "call_local", "reliable")
func _boss_siren() -> void:
	Sound.play("boss_siren")  # sounds/sfx/boss_siren.wav


## Everyone: a flash of orange light and bits of Roomba flying everywhere.
@rpc("authority", "call_local", "reliable")
func _show_explosion(at: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1, 0.55, 0.15)
	flash.light_energy = 8.0
	flash.light_volumetric_fog_energy = 4.0
	flash.omni_range = 7.0
	flash.position = at + Vector3(0, 0.8, 0)
	get_parent().add_child(flash)
	var fade := flash.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, 0.6)
	fade.tween_callback(flash.queue_free)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.85, 0.9)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.06, 0.15)
	for i in 7:
		var bit := MeshInstance3D.new()
		bit.mesh = mesh
		bit.material_override = material
		bit.position = at + Vector3(0, 0.3, 0)
		get_parent().add_child(bit)
		var out := Vector3(cos(i * 0.9), 0, sin(i * 0.9)) * randf_range(1.0, 2.5)
		var fly := bit.create_tween().set_parallel()
		fly.tween_property(bit, "position", at + out + Vector3(0, 1.2, 0), 0.3).set_ease(Tween.EASE_OUT)
		fly.tween_property(bit, "rotation", Vector3(randf() * 8, randf() * 8, 0), 0.7)
		fly.chain().tween_property(bit, "position:y", at.y + 0.03, 0.4).set_ease(Tween.EASE_IN)
		fly.chain().tween_callback(bit.queue_free).set_delay(2.0)
