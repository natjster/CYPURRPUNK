class_name PayphoneModel
extends Node3D
## CYPURRPUNK — the LOOK of a payphone (scenes/props/payphone.tscn, the "Model" child).
## Built in code out of little PS1-style boxes when the phone appears, so there's no model file:
##
##        [ PHONE ]  <- glowing sign on the roof
##      ____________
##     |  ~~neon~~  |  <- the hood, with a cyan neon strip under it lighting the phone
##     | |[screen]| |
##     | |H [###] | |  <- H = the handset in its cradle, ### = keypad (3 x 4 buttons)
##     | |H [###] | |     a curly cord hangs from the handset to the phone
##     | |  =coin=| |
##     |_|________|_|  <- side wings + a little shelf; posts down to a base plate
##
## The FRONT is +Z (the side cats walk up to; fish_heist.gd turns it to face the street).
## While the phone RINGS (payphone.gd set_ringing) the handset rattles in its cradle and the
## little screen flashes "RING".
##
## Tuning: select Payphone > Model in scenes/props/payphone.tscn and look in the Inspector.

## Main body colour (the booth's painted metal).
@export var metal_color: Color = Color(0.16, 0.28, 0.42)
## The phone unit's face plate (brushed steel).
@export var steel_color: Color = Color(0.55, 0.58, 0.62)
## Handset, cord, keypad frame and other dark bits.
@export var dark_color: Color = Color(0.06, 0.06, 0.08)
## The glowing sign on the roof.
@export var sign_color: Color = Color(1, 0.75, 0.15)
## The neon strip under the hood (it lights the phone).
@export var neon_color: Color = Color(0.2, 0.9, 1.0)
## The little screen on the phone.
@export var screen_color: Color = Color(0.3, 1, 0.6)
## How hard the handset rattles while ringing (radians of wobble).
@export var rattle_amount: float = 0.12
## How fast the handset rattles (wobbles a second).
@export var rattle_speed: float = 22.0

var _handset: Node3D
var _handset_rest: Vector3
var _screen_text: Label3D
var _screen_mat: ShaderMaterial
var _ringing: bool = false


func _ready() -> void:
	var metal := _mat(metal_color, 0.4)
	var steel := _mat(steel_color, 0.8)
	var dark := _mat(dark_color, 0.2)
	var button := _mat(Color(0.8, 0.8, 0.75), 0.3)
	var chrome := _mat(Color(0.75, 0.78, 0.8), 1.0)

	# --- The booth: base plate, two posts, a back panel, side wings and the hood ---
	_box(Vector3(0, 0.03, 0), Vector3(0.78, 0.06, 0.6), dark)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.36 * side, 1.08, -0.18), Vector3(0.07, 2.1, 0.07), metal)  # posts
		_box(Vector3(0.36 * side, 1.65, 0.0), Vector3(0.04, 0.95, 0.42), metal)  # side wings
		_box(Vector3(0.36 * side, 1.18, 0.0), Vector3(0.05, 0.05, 0.44), chrome)  # wing trim
	_box(Vector3(0, 1.6, -0.19), Vector3(0.68, 1.05, 0.04), metal)  # back panel
	_box(Vector3(0, 2.15, 0.02), Vector3(0.82, 0.08, 0.58), metal)  # the hood (roof)
	_box(Vector3(0, 2.1, 0.3), Vector3(0.82, 0.05, 0.03), chrome)  # hood's front lip
	# The neon strip under the hood, and the light it throws on the phone.
	_box(Vector3(0, 2.09, 0.2), Vector3(0.6, 0.025, 0.03), _glow(neon_color, 3.0))
	var neon_light := OmniLight3D.new()
	neon_light.light_color = neon_color
	neon_light.light_energy = 0.8
	neon_light.omni_range = 1.8
	neon_light.position = Vector3(0, 1.9, 0.35)
	neon_light.distance_fade_enabled = true
	neon_light.distance_fade_begin = 40.0
	neon_light.distance_fade_length = 10.0
	add_child(neon_light)

	# --- The glowing sign on the roof (letters on both sides) ---
	_box(Vector3(0, 2.32, 0.02), Vector3(0.64, 0.2, 0.07), _glow(sign_color, 2.5))
	_box(Vector3(0, 2.32, 0.02), Vector3(0.68, 0.24, 0.05), dark)  # its dark frame
	for facing in [0.0, PI]:
		var letters := Label3D.new()
		letters.text = "PHONE"
		letters.font_size = 40
		letters.pixel_size = 0.0042
		letters.outline_size = 0
		letters.modulate = Color(0.12, 0.05, 0.0)
		letters.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		letters.rotation.y = facing
		letters.position = Vector3(0, 2.32, 0.02) + Vector3(0, 0, 0.04).rotated(Vector3.UP, facing)
		add_child(letters)

	# --- The phone unit on the back panel ---
	var unit_z := -0.08
	_box(Vector3(0, 1.48, unit_z), Vector3(0.42, 0.66, 0.18), steel)  # the housing
	_box(Vector3(0, 1.83, unit_z + 0.01), Vector3(0.44, 0.05, 0.2), chrome)  # top cap
	# The little screen (it flashes RING while ringing).
	_screen_mat = _glow(screen_color, 1.5)
	_box(Vector3(0.04, 1.72, unit_z + 0.095), Vector3(0.24, 0.08, 0.02), _screen_mat)
	_screen_text = Label3D.new()
	_screen_text.text = "$0.25"
	_screen_text.font_size = 24
	_screen_text.pixel_size = 0.004
	_screen_text.outline_size = 0
	_screen_text.modulate = Color(0.02, 0.15, 0.05)
	_screen_text.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_screen_text.position = Vector3(0.04, 1.72, unit_z + 0.107)
	add_child(_screen_text)
	# The keypad: a dark frame with 3 x 4 buttons.
	var pad_x := 0.06
	_box(Vector3(pad_x, 1.5, unit_z + 0.095), Vector3(0.17, 0.23, 0.015), dark)
	for row in 4:
		for column in 3:
			_box(Vector3(pad_x - 0.05 + column * 0.05, 1.59 - row * 0.055, unit_z + 0.107),
				Vector3(0.035, 0.035, 0.015), button)
	# The coin slot and the coin-return cup.
	_box(Vector3(0.14, 1.66, unit_z + 0.095), Vector3(0.05, 0.012, 0.01), dark)
	_box(Vector3(0.06, 1.25, unit_z + 0.1), Vector3(0.1, 0.06, 0.04), dark)
	_box(Vector3(0.06, 1.27, unit_z + 0.11), Vector3(0.08, 0.02, 0.02), chrome)
	# The cradle on the left side, and the handset sitting in it.
	_box(Vector3(-0.16, 1.48, unit_z + 0.1), Vector3(0.07, 0.36, 0.04), dark)
	_handset = Node3D.new()
	_handset.position = Vector3(-0.16, 1.48, unit_z + 0.14)
	_handset_rest = _handset.position
	add_child(_handset)
	_box(Vector3(0, 0, 0), Vector3(0.05, 0.28, 0.05), dark, _handset)  # handle
	_box(Vector3(0, 0.16, 0.02), Vector3(0.08, 0.07, 0.07), dark, _handset)  # earpiece
	_box(Vector3(0, -0.16, 0.02), Vector3(0.08, 0.07, 0.07), dark, _handset)  # mouthpiece
	# The curly cord: little wiggling boxes sagging from the handset down to the phone's bottom.
	var cord_from := Vector3(-0.16, 1.3, unit_z + 0.15)
	var cord_to := Vector3(-0.1, 1.16, unit_z + 0.06)
	const LINKS := 12
	for i in LINKS:
		var t := float(i) / (LINKS - 1)
		var at := cord_from.lerp(cord_to, t)
		at.y -= sin(t * PI) * 0.12  # it sags
		at.x += sin(t * TAU * 3.0) * 0.012  # the curls
		at.z += cos(t * TAU * 3.0) * 0.012
		_box(at, Vector3(0.022, 0.022, 0.022), dark)
	# A little shelf under the phone (for your phone book, or your paws).
	_box(Vector3(0, 1.1, -0.04), Vector3(0.6, 0.03, 0.26), metal)
	_box(Vector3(0, 1.08, 0.09), Vector3(0.6, 0.05, 0.02), chrome)

	# --- A bit of street life: a pink sticker on the wing and a scratched "MEOW" tag ---
	_box(Vector3(0.385, 1.75, 0.08), Vector3(0.005, 0.1, 0.1), _glow(Color(1, 0.3, 0.7), 1.2))
	var tag := Label3D.new()
	tag.text = "MEOW"
	tag.font_size = 28
	tag.pixel_size = 0.005
	tag.outline_size = 0
	tag.modulate = Color(1, 0.3, 0.7)
	tag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tag.rotation.y = PI / 2.0
	tag.position = Vector3(0.39, 1.45, 0.0)
	add_child(tag)


## payphone.gd calls this when the phone starts / stops ringing.
func set_ringing(ringing: bool) -> void:
	_ringing = ringing
	if not ringing and _handset != null:
		_handset.position = _handset_rest
		_handset.rotation = Vector3.ZERO
		if _screen_text != null:
			_screen_text.text = "$0.25"


func _process(_delta: float) -> void:
	if not _ringing or _handset == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	# Rings come in bursts (like the sound): rattle for 0.6 s, rest for 0.4 s.
	var in_burst := fmod(t, 1.0) < 0.6
	var wobble := sin(t * rattle_speed) * rattle_amount if in_burst else 0.0
	_handset.rotation.z = wobble
	_handset.position = _handset_rest + Vector3(0, absf(wobble) * 0.15, 0)
	_screen_text.text = "RING!" if in_burst else ""


# --- Little helpers ---

func _box(center: Vector3, size: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = center
	parent.add_child(node)
	return node


func _mat(color: Color, specular: float) -> ShaderMaterial:
	return LevelKit.psx_material({"albedo_color": color, "specular": specular})


func _glow(color: Color, energy: float) -> ShaderMaterial:
	return LevelKit.psx_material({"albedo_color": color, "emission_color": color, "emission_energy": energy})
