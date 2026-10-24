class_name RoombaPatrol
extends Node3D
## THE VAC-COP PATROL: puts police Roombas (scenes/roomba.tscn) on the city's sidewalks and
## sends a new one some time after one is destroyed.
## Attach to the "Roombas" node in main.tscn. Its sibling "RoombaSpawner" (a
## MultiplayerSpawner pointing at Roombas) copies every Roomba to every player's game,
## including players who join later.
##
## Only the HOST creates Roombas (game.gd calls start_patrol() when hosting). Where they appear
## is random each game — they're not part of the city seed, so they never change the city.

const ROOMBA_SCENE: PackedScene = preload("res://scenes/roomba.tscn")

## How many Roombas patrol the city at once.
@export var roomba_count: int = 8
## Seconds before a destroyed Roomba is replaced.
@export var respawn_seconds: float = 25.0
## New Roombas never appear closer than this to a cat, or to the centre crossroads where
## cats arrive from the hub.
@export var min_spawn_distance: float = 25.0

var _respawn_at: Array[float] = []  # host: when each replacement is due
var _clock: float = 0.0
var _next_number: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Host: clear any old Roombas and put a fresh patrol out (called when a game is hosted).
func start_patrol() -> void:
	for old in get_children():
		old.queue_free()
	_respawn_at.clear()
	for i in roomba_count:
		_spawn_one()


## Host: a Roomba blew up. Show the explosion everywhere and queue its replacement.
func roomba_destroyed(at: Vector3) -> void:
	_show_explosion.rpc(at)
	_respawn_at.append(_clock + respawn_seconds)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_clock += delta
	for i in range(_respawn_at.size() - 1, -1, -1):
		if _clock >= _respawn_at[i]:
			_respawn_at.remove_at(i)
			_spawn_one()


func _spawn_one() -> void:
	var roomba := ROOMBA_SCENE.instantiate() as Roomba
	roomba.name = "Roomba%d" % _next_number  # unique names keep everyone's copies matched up
	_next_number += 1
	roomba.position = _spawn_spot()
	add_child(roomba, true)


## A random sidewalk spot away from the centre and from every cat.
func _spawn_spot() -> Vector3:
	var spot := Vector3.ZERO
	for attempt in 20:
		spot = ItemManager.instance.random_sidewalk_spot(_rng) + Vector3(0, 0.1, 0)
		var clear := Vector2(spot.x, spot.z).length() > min_spawn_distance
		for cat in Game.instance.players.get_children():
			clear = clear and spot.distance_to((cat as Node3D).global_position) > min_spawn_distance
		if clear:
			break
	return spot


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
