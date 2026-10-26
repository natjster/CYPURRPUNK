class_name RoombaPatrol
extends Node3D
## THE VAC-COP PATROL: puts police Roombas (scenes/roomba.tscn) on the city's sidewalks and
## sends a new one some time after one is destroyed.
## Attach to the "Roombas" node in main.tscn. Its sibling "RoombaSpawner" (a
## MultiplayerSpawner pointing at Roombas) copies every Roomba to every player's game,
## including players who join later.
##
## How many are out follows the HEAT (scripts/heat_meter.gd): every heat level adds a few, and
## at max heat the MEGA VAC-COP (scenes/roomba_boss.tscn) comes out until the heat cools down.
##
## Only the HOST creates Roombas (game.gd calls start_patrol() when hosting). Where they appear
## is random each game — they're not part of the city seed, so they never change the city.

const ROOMBA_SCENE: PackedScene = preload("res://scenes/roomba.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/roomba_boss.tscn")

## How many Roombas patrol the city at once when the city is calm (HEAT level 1).
## Hotter levels add more (HeatMeter.extra_roombas_per_level, on the Heat node).
@export var roomba_count: int = 8
## Seconds before a destroyed Roomba is replaced.
@export var respawn_seconds: float = 25.0
## New Roombas never appear closer than this to a cat, or to the centre crossroads where
## cats arrive from the hub.
@export var min_spawn_distance: float = 25.0
## When the heat goes UP a level, one reinforcement Roomba arrives every this many seconds
## until there are enough. (When it cools down, spare Roombas far from cats go home just as slowly.)
@export var reinforce_seconds: float = 4.0

@export_group("MEGA VAC-COP (boss)")
## The boss appears at least this far from every cat (it drives in from across town).
@export var boss_spawn_distance: float = 45.0
## The boss goes home once the heat cools below this (out of 100).
@export var boss_leaves_below_heat: float = 60.0

var _respawn_at: Array[float] = []  # host: when each replacement is due
var _clock: float = 0.0
var _next_number: int = 0
var _next_change_at: float = 0.0  # host: when the next reinforcement may arrive / leave
var _boss: Roomba = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Host: clear any old Roombas and put a fresh patrol out (called when a game is hosted).
func start_patrol() -> void:
	for old in get_children():
		old.queue_free()
	_respawn_at.clear()
	_boss = null
	for i in roomba_count:
		_spawn_one()


## Host: a Roomba blew up. Show the explosion everywhere and queue its replacement
## (the boss has no replacement: the heat decides if another one comes).
func roomba_destroyed(roomba: Roomba) -> void:
	_show_explosion.rpc(roomba.global_position)
	if roomba == _boss:
		_boss = null
		_announce.rpc("THE MEGA VAC-COP IS DOWN!")
	else:
		_respawn_at.append(_clock + respawn_seconds)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_clock += delta
	for i in range(_respawn_at.size() - 1, -1, -1):
		if _clock >= _respawn_at[i]:
			_respawn_at.remove_at(i)
			_spawn_one()
	_follow_the_heat()


## Host: more Roombas when the city is hot, fewer when it cools, and the boss at max heat.
func _follow_the_heat() -> void:
	var heat := HeatMeter.instance
	# The boss: out at max heat, home again once it cools.
	if _boss == null and heat.level() == HeatMeter.MAX_LEVEL:
		_boss = BOSS_SCENE.instantiate() as Roomba
		_boss.name = "RoombaBoss%d" % _next_number
		_next_number += 1
		_boss.position = _spawn_spot(boss_spawn_distance)
		add_child(_boss, true)
		print("[Roombas] MEGA VAC-COP deployed at %s" % _boss.position)
	elif _boss != null and is_instance_valid(_boss) and heat.heat < boss_leaves_below_heat:
		_boss.queue_free()  # it drives off (the spawner removes it everywhere)
		_boss = null
		_announce.rpc("THE MEGA VAC-COP WENT HOME.")

	# Regular Roombas: how many are out (or on their way back after being smashed)?
	if _clock < _next_change_at:
		return
	var regulars: Array[Roomba] = []
	for child in get_children():
		var roomba := child as Roomba
		if roomba != null and not roomba.is_boss and not roomba.is_queued_for_deletion():
			regulars.append(roomba)
	var wanted := roomba_count + heat.extra_roombas()
	if regulars.size() + _respawn_at.size() < wanted:
		_spawn_one()
		_next_change_at = _clock + reinforce_seconds
	elif regulars.size() + _respawn_at.size() > wanted:
		# Too many for this heat: send one home, but only one nobody is looking at.
		for roomba in regulars:
			if roomba.state == Roomba.State.PATROL and _far_from_cats(roomba.global_position, 30.0):
				roomba.queue_free()
				break
		_next_change_at = _clock + reinforce_seconds


func _spawn_one() -> void:
	var roomba := ROOMBA_SCENE.instantiate() as Roomba
	roomba.name = "Roomba%d" % _next_number  # unique names keep everyone's copies matched up
	_next_number += 1
	roomba.position = _spawn_spot()
	add_child(roomba, true)


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


## Host -> everyone: a line of text in the middle of the screen.
@rpc("authority", "call_local", "reliable")
func _announce(text: String) -> void:
	Hud.show_message(text, 3.0)


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
