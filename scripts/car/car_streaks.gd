class_name CarStreaks
extends Node3D
## CYPURRPUNK — SPEED STREAKS: neon rips of light that tear off the car when it TAKES OFF.
## Same look as the cat's claw marks (scripts/cat/cat_melee.gd): a glowing ribbon, sharp at both
## ends and thick in the middle, that rips out fast and then fades. Here they shoot backwards off
## the car's sides and tail, and stay where they were drawn, so a car speeding away leaves a trail
## of them behind it.
##
## Attach to the "Streaks" node under GetawayCar in scenes/getaway_car.tscn. Knobs: open that scene,
## click Streaks in the Scene panel, and look at the Inspector.
##
## Who uses it (nothing to set up, they call it in code):
##   AFTERBURNER   (scripts/car/car_boost.gd)  a big orange burst + a steady stream while it burns.
##   DRIFT TURBO   (scripts/car/car_juice.gd)  a blue / orange burst on the speed kick.
##   LAUNCH        (scripts/car/car_juice.gd)  white streaks off the back wheels when you floor it
##                                             from standstill.
## Purely a look: runs on every computer, no network messages of its own.

## How long one streak is (metres), before the random size and the speed stretch.
@export var streak_length: float = 2.2
## Streaks get this many times longer at the car's top speed (1 = no stretch).
@export var speed_stretch: float = 1.8
## How thick a streak is in the middle (metres).
@export var streak_width: float = 0.11
## How long a streak takes to rip out (seconds), and to fade away after.
@export var rip_seconds: float = 0.07
@export var fade_seconds: float = 0.3
## Most streaks on screen at once per car (keeps it cheap with 8 players).
@export var max_streaks: int = 60

@onready var car: GetawayCar = get_parent()

var _marks: Array[Dictionary] = []
var _stream_carry: float = 0.0  # part-streaks left over from stream() between frames
var _mesh: ImmediateMesh
var _mesh_node: MeshInstance3D
var _last_pos: Vector3
var _velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	_last_pos = car.global_position
	# One mesh redrawn every frame (same trick as the claw marks).
	var trail := LevelKit.add_trail_mesh(self, "StreakMesh")
	_mesh = trail["mesh"]
	_mesh_node = trail["node"]


## A one-off burst of "count" streaks. where: "sides" (all round the car) or "wheels" (low, off the
## back wheels). length_scale makes them longer / shorter.
func burst(colour: Color, count: int, where: String = "sides", length_scale: float = 1.0) -> void:
	for i in count:
		_spawn(colour, where, length_scale, -0.02 * randf())  # tiny random delays = less "all at once"


## Call every frame while something is going on (the afterburner): about "per_second" streaks a second.
func stream(colour: Color, per_second: float, delta: float, where: String = "sides") -> void:
	_stream_carry += per_second * delta
	while _stream_carry >= 1.0:
		_stream_carry -= 1.0
		_spawn(colour, where, 1.0, 0.0)


func streak_count() -> int:
	return _marks.size()


func _spawn(colour: Color, where: String, length_scale: float, delay: float) -> void:
	if _marks.size() >= max_streaks:
		_marks.pop_front()  # the oldest one goes
	var box := _box()
	var right := car.global_basis.x
	var back := car.global_basis.z  # the car's tail points +Z
	var side := -1.0 if randf() < 0.5 else 1.0
	var spot: Vector3
	if where == "wheels":
		spot = right * side * box.x * randf_range(0.3, 0.55) + Vector3.UP * randf_range(0.05, 0.35) \
			+ back * box.z * randf_range(0.3, 0.55)
	else:
		# Just outside the body: down both sides and off the top corners, front half to tail.
		spot = right * side * box.x * randf_range(0.5, 0.75) + Vector3.UP * randf_range(0.1, box.y * 1.1) \
			+ back * box.z * randf_range(-0.2, 0.55)
	# They shoot backwards along the way the car is going (or straight out the tail when it's slow).
	var flat := Vector3(_velocity.x, 0.0, _velocity.z)
	var dir := -flat.normalized() if flat.length() > 2.0 else back
	# Fan out sideways (wheel streaks more), so they still read from the chase camera right behind.
	var fan := randf_range(0.15, 0.45) if where == "wheels" else randf_range(0.0, 0.15)
	dir = (dir + right * side * fan + Vector3.UP * randf_range(0.0, 0.08)).normalized()
	var top := maxf(car.max_speed, 0.1)
	var stretch := lerpf(1.0, speed_stretch, clampf(flat.length() / top, 0.0, 1.0))
	_marks.append({"start": car.global_position + spot, "dir": dir,
		"length": streak_length * stretch * length_scale * randf_range(0.6, 1.2),
		"age": delay, "colour": colour})


func _box() -> Vector3:
	var shape := car.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		return (shape.shape as BoxShape3D).size
	return Vector3(1.8, 1.2, 4.0)


## Every frame: age the streaks and redraw them all.
func _process(delta: float) -> void:
	if delta > 0.0:
		var moved := car.global_position - _last_pos
		if moved.length() < 8.0:  # (a teleport: keep the old speed)
			_velocity = _velocity.lerp(moved / delta, 0.5)
	_last_pos = car.global_position
	var life_total := rip_seconds + fade_seconds
	for i in range(_marks.size() - 1, -1, -1):
		_marks[i].age += delta
		if _marks[i].age > life_total:
			_marks.remove_at(i)
	_mesh.clear_surfaces()
	_mesh_node.global_transform = Transform3D.IDENTITY
	if _marks.is_empty():
		return
	var view_cam := get_viewport().get_camera_3d()
	for mark in _marks:
		var age: float = mark.age
		var rip := clampf(age / maxf(rip_seconds, 0.001), 0.0, 1.0)
		if rip <= 0.0:
			continue
		rip = 1.0 - pow(1.0 - rip, 3.0)  # fast start, eases in at the end: a SLASH
		var fade_age := maxf(age - rip_seconds, 0.0)
		var life := clampf(1.0 - fade_age / maxf(fade_seconds, 0.001), 0.0, 1.0)
		var start: Vector3 = mark.start
		var dir: Vector3 = mark.dir
		var length: float = mark.length * rip
		# Face the camera: the ribbon's width goes sideways to the view.
		var to_cam := (view_cam.global_position - start).normalized() if view_cam != null else Vector3.UP
		var across := dir.cross(to_cam)
		if across.length() < 0.01:
			across = dir.cross(Vector3.UP)
		across = across.normalized()
		var base: Color = mark.colour
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var segments := 6
		for s in segments + 1:
			var t := float(s) / segments
			var point := start + dir * length * t
			# Thick in the middle, sharp at both ends, thinner as it fades.
			var width := streak_width * sin(PI * t) * (0.4 + 0.6 * life)
			# The end by the car is white-hot, the far end is the streak's colour.
			var colour := base.lerp(Color.WHITE, (1.0 - t) * 0.6 * life)
			colour.a = life * 0.95
			_mesh.surface_set_color(colour)
			_mesh.surface_add_vertex(point - across * width)
			_mesh.surface_set_color(colour)
			_mesh.surface_add_vertex(point + across * width)
		_mesh.surface_end()
