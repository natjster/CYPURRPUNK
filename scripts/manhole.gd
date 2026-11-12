class_name Manhole
extends Node3D
## CYPURRPUNK — a sewer manhole in the street: the rebellion's way in and out of the city.
## Built by fish_heist.gd for every district (you don't place these by hand):
##   - the ENTRY manhole (your gang's corner; co-op: the centre crossroads), where your boss sends
##     you up. It's one-way: it always looks closed. Every time a cat comes up, the lid BLASTS off,
##     flips through the air and SLAMS shut behind it (play_slam: clank, dust, a little screen shake).
##   - the EXIT manhole somewhere else in the city: lid slid aside, a glow coming up out of the
##     hole (open from the start: fish_heist.gd exit_open_from_start). Walking onto it takes you
##     (and your loot) back down to the sewers. Find out where it is with a payphone.
##
## The lid and the hole are two little pictures you can repaint:
##   textures/manhole_closed.png and textures/manhole_open.png (any size, square, round art
##   in the middle). Double-click them in the FileSystem dock to see them.
##
## The manhole is a short raised disc (a drain collar), not a flat sticker on the road: two
## flat surfaces a few centimetres apart flicker against each other (see city_generator.gd).

const CLOSED_TEXTURE: String = "res://textures/manhole_closed.png"
const OPEN_TEXTURE: String = "res://textures/manhole_open.png"
## Radius of the manhole (metres).
const RADIUS: float = 0.8
## How far it sticks up out of the road (metres).
const HEIGHT: float = 0.1
## Colour of the glow that comes up out of an open manhole.
const GLOW_COLOR: Color = Color(0.3, 1, 0.5)

## THE SLAM (play_slam), in seconds: the lid flies up for this long...
const SLAM_RISE: float = 0.3
## ...how high it flies (metres)...
const SLAM_HEIGHT: float = 1.5
## ...hangs at the top for this long...
const SLAM_HANG: float = 0.25
## ...then drops back down this fast and SLAMS.
const SLAM_DROP: float = 0.18

## The glow colour for THIS manhole (set before it's added; fish_heist.gd gives each gang's exit
## its gang colour, so you can tell yours from the rival's).
var glow_color: Color = GLOW_COLOR
## True = lid off, glowing, and you can climb down.
var is_open: bool = false

var _closed_disc: MeshInstance3D
var _open_disc: MeshInstance3D
var _lid_aside: MeshInstance3D  # the lid, slid off to one side, while it's open
var _glow: OmniLight3D
var _flying_lid: MeshInstance3D  # the lid while it flies off and slams back (play_slam)
var _dust: CPUParticles3D
var _slam_tween: Tween


func _ready() -> void:
	var disc := _make_disc_mesh(RADIUS, HEIGHT)
	_closed_disc = _add_disc(disc, _material(CLOSED_TEXTURE, 0.0), Vector3.ZERO)
	_open_disc = _add_disc(disc, _material(OPEN_TEXTURE, 1.5), Vector3.ZERO)
	# The lid lying next to the hole (a thinner disc, so it looks like it was shoved aside).
	_lid_aside = _add_disc(_make_disc_mesh(RADIUS, HEIGHT * 0.6), _material(CLOSED_TEXTURE, 0.0), Vector3(RADIUS * 1.9, 0, 0.3))
	_lid_aside.rotation.y = 0.7

	_glow = OmniLight3D.new()
	_glow.light_color = glow_color
	_glow.light_energy = 2.5
	_glow.light_volumetric_fog_energy = 3.0  # a green haze rising out of the hole
	_glow.omni_range = 6.0
	_glow.position = Vector3(0, 0.6, 0)
	add_child(_glow)
	# The flying lid for play_slam (hidden until then): a copy of the closed lid.
	_flying_lid = _add_disc(disc, _material(CLOSED_TEXTURE, 0.0), Vector3.ZERO)
	_flying_lid.visible = false
	set_open(is_open)


## Open (lid aside, glowing) or closed (lid on).
func set_open(open: bool) -> void:
	is_open = open
	if _closed_disc == null:
		return  # not built yet: _ready() calls this again
	_closed_disc.visible = not open
	_open_disc.visible = open
	_lid_aside.visible = open
	_glow.visible = open


## Someone just came up through this manhole: the lid blasts off, flips over in the air and SLAMS
## back down behind them (clank + dust + a shake for cats nearby). Only a look: nothing else
## changes. Called on every computer by fish_heist.gd for each cat that comes up.
func play_slam() -> void:
	if _flying_lid == null:
		return
	if _slam_tween != null and _slam_tween.is_valid():
		_slam_tween.kill()  # someone else came up mid-slam: start over
	# The hole shows (green glow bursting out), the lid is the flying one now.
	_closed_disc.visible = false
	_open_disc.visible = true
	_lid_aside.visible = false
	_glow.visible = true
	_glow.light_energy = 7.0
	_flying_lid.visible = true
	_flying_lid.position = Vector3.ZERO
	_flying_lid.rotation = Vector3.ZERO
	Sound.play_at("hydrant_burst", global_position, -10.0)  # the whoosh of sewer air
	var flip_axis := randf_range(0.0, TAU)  # (each slam flips a different way)
	var t := create_tween()
	_slam_tween = t
	# UP: fast, slowing at the top, while the lid tumbles over twice and spins.
	t.tween_property(_flying_lid, "position", Vector3(cos(flip_axis) * 0.4, SLAM_HEIGHT, sin(flip_axis) * 0.4), SLAM_RISE) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_flying_lid, "rotation", Vector3(TAU * 0.9, PI * 0.5, 0.0), SLAM_RISE)
	t.parallel().tween_property(_glow, "light_energy", 4.0, SLAM_RISE)
	# A moment in the air (still tumbling)...
	t.tween_property(_flying_lid, "position:y", SLAM_HEIGHT + 0.1, SLAM_HANG).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_flying_lid, "rotation", Vector3(TAU * 1.5, PI * 0.85, 0.0), SLAM_HANG)
	t.parallel().tween_property(_glow, "light_energy", 2.5, SLAM_HANG)
	# ...then DOWN, speeding up, landing flat, right into the hole.
	t.tween_property(_flying_lid, "position", Vector3.ZERO, SLAM_DROP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_flying_lid, "rotation", Vector3(TAU * 2.0, PI, 0.0), SLAM_DROP)
	t.tween_callback(_on_slam)
	# A little bounce and rattle as it settles.
	t.tween_property(_flying_lid, "position:y", 0.08, 0.07).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_flying_lid, "rotation:z", 0.12, 0.07)
	t.tween_property(_flying_lid, "position:y", 0.0, 0.08).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_flying_lid, "rotation:z", -0.06, 0.08)
	t.tween_property(_flying_lid, "rotation:z", 0.0, 0.1)
	t.tween_callback(_end_slam)


## BANG: the lid is back on.
func _on_slam() -> void:
	_open_disc.visible = false
	_glow.visible = false
	Sound.play_at("bin_clatter", global_position)  # metal on metal
	Sound.play_at("bonk", global_position, -4.0)
	Feedback.shake_near(global_position, 0.35, 10.0)
	_puff_dust()


## Back to how it normally looks.
func _end_slam() -> void:
	_flying_lid.visible = false
	_flying_lid.rotation = Vector3.ZERO
	_glow.light_energy = 2.5
	set_open(is_open)


## A ring of grey dust puffs out from under the lid.
func _puff_dust() -> void:
	if _dust == null:
		_dust = CPUParticles3D.new()
		_dust.one_shot = true
		_dust.emitting = false
		_dust.amount = 18
		_dust.lifetime = 0.7
		_dust.explosiveness = 1.0
		_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_dust.emission_ring_axis = Vector3.UP
		_dust.emission_ring_radius = RADIUS
		_dust.emission_ring_inner_radius = RADIUS * 0.8
		_dust.emission_ring_height = 0.05
		_dust.direction = Vector3(0, 0.3, 0)
		_dust.spread = 180.0
		_dust.flatness = 0.8
		_dust.initial_velocity_min = 1.5
		_dust.initial_velocity_max = 3.0
		_dust.gravity = Vector3(0, 0.6, 0)  # dust drifts up a little
		_dust.damping_min = 3.0
		_dust.damping_max = 5.0
		_dust.scale_amount_min = 0.6
		_dust.scale_amount_max = 1.2
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0))
		_dust.scale_amount_curve = curve
		var puff := BoxMesh.new()
		puff.size = Vector3(0.18, 0.18, 0.18)
		_dust.mesh = puff
		_dust.material_override = LevelKit.psx_material({"albedo_color": Color(0.55, 0.55, 0.5)})
		_dust.position = Vector3(0, 0.1, 0)
		add_child(_dust)
	_dust.restart()


func _add_disc(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node


## The game's PS1 look (psx_lit shader) with the picture on top. "glow" makes the picture
## light up by itself (the open hole's green sewer light).
func _material(texture_path: String, glow: float) -> ShaderMaterial:
	return LevelKit.psx_material({"albedo_texture": load(texture_path), "texture_glow": glow, "specular": 0.3})


## A flat-topped disc: a 16-sided top showing the whole picture (the picture's middle at the
## disc's middle), plus a thin side wall down to the road (which shows the rim colour).
func _make_disc_mesh(radius: float, height: float) -> ArrayMesh:
	const SIDES := 16
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		var p0 := Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := Vector3(cos(a1), 0, sin(a1)) * radius
		var top := Vector3(0, height, 0)
		# Top: a slice of pie from the centre (clockwise seen from above = faces up in Godot).
		tool.set_uv(Vector2(0.5, 0.5))
		tool.add_vertex(top)
		tool.set_uv(Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5))
		tool.add_vertex(p0 + top)
		tool.set_uv(Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5))
		tool.add_vertex(p1 + top)
		# Side wall: a thin strip from the road up to the top, using the picture's edge (the rim).
		var rim := Vector2(0.5 + cos(a0) * 0.49, 0.5 + sin(a0) * 0.49)
		for corner in [p0, p1, p1 + top, p0, p1 + top, p0 + top]:
			tool.set_uv(rim)
			tool.add_vertex(corner)
	tool.generate_normals()
	return tool.commit()
