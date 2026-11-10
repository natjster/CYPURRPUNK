class_name HudCompassArrow
extends Control
## CYPURRPUNK — the big GREEN 3D ARROW at the top-middle of the screen ("Crazy Taxi" style).
## Lives at scenes/ui/hud.tscn > HUD > Frame > Top > Compass (every player's HUD has one).
##
## It shows up as soon as YOUR GANG'S EXIT IS OPEN while you're up in the city:
##   1. "PAYPHONE  45m"  -> it points at the NEAREST RINGING PAYPHONE (call your boss on it)
##   2. "EXIT  80m"      -> once someone in your gang has made that call, it points at your EXIT
## Hidden in the sewers, during a Sewer Breach alarm, before your exit opens, and the moment the
## hatch is SEALED at 100 heat. scripts/fish_heist.gd decides all that and calls point_at() /
## hide_arrow() every frame.
##
## HOW IT'S DRAWN: no 3D scene, no extra viewport. The arrow is a little list of 3D corner points
## (a fat arrowhead + a tail block, both with bevelled edges) that this script turns, tilts and
## flattens onto the screen itself every frame, then paints face by face with draw_polygon (far
## faces first). Each face gets its own shade of green from a fake light, so the top, the bevels
## and the sides read as solid 3D. Corners snap to a coarse grid for the wobbly PS1 look.
## Cheap enough for all four split-screen HUDs at once.
##
## It turns to face the target as seen from YOUR CAMERA (on foot or driving), so "straight up"
## on the arrow = straight ahead on screen. Above seal_warning_at_heat (fish_heist.gd, 90 heat)
## it bobs and pulses faster: the hatch is about to seal!
##
## Move / resize it in hud.tscn like any Control (select Compass, drag it). While the TUTORIAL box
## is showing it slides down underneath it by itself. Everything else is in the Inspector.

@export_group("Colours")
## The arrow's green (the lit top face; sides are darker shades of it).
@export var arrow_color: Color = Color(0.15, 1.0, 0.25)
## Thin outline round every face (chunky PS1 edges).
@export var edge_color: Color = Color(0.02, 0.22, 0.05)
## The words under the arrow ("PAYPHONE  45m").
@export var label_color: Color = Color(0.45, 1.0, 0.5)

@export_group("Shape")
## How big the arrow is (HUD units: the screen is 720 tall).
@export var arrow_size: float = 44.0
## How far down the camera looks at the arrow (degrees). More = you see more of its top.
@export var tilt_degrees: float = 38.0
## How thick the arrow is, and how wide its bevelled edge (in arrow lengths).
@export var thickness: float = 0.22
@export var bevel: float = 0.09
## Corners snap to a grid this many HUD units wide (3 = one game pixel). 0 = smooth.
@export var snap: float = 3.0
## Text size of the words under the arrow.
@export var label_font_size: int = 22

@export_group("Feel")
## How quickly the arrow turns to a new direction (higher = snappier).
@export var turn_speed: float = 9.0
## Gentle bob: how far (HUD units) and how often (per second).
@export var bob_height: float = 4.0
@export var bob_speed: float = 1.6
## Gentle size pulse (0.06 = 6% bigger at the top of a pulse).
@export var pulse_amount: float = 0.05
## At 90+ heat (about to seal) everything above goes this many times faster, and the pulse
## this many times bigger.
@export var urgent_speed: float = 3.0
@export var urgent_pulse: float = 2.2

## Which way the arrow points right now (radians; 0 = straight ahead, + = to the right).
var _yaw: float = 0.0
var _target_yaw: float = 0.0
var _text: String = ""
var _urgent: bool = false
var _clock: float = 0.0
## Where the Compass sits in hud.tscn (offset_top), so it can slide back after the tutorial.
var _base_top: float = 0.0
## The arrow as convex pieces: each = {"outline": PackedVector2Array (x, z), "skip_wall": index}.
var _pieces: Array = []


func _ready() -> void:
	_base_top = offset_top
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# The arrow lies flat, pointing "ahead" (-Z). Seen from above: a fat arrowhead and a tail
	# block, 1 unit long in all. Each outline goes round anticlockwise seen from above.
	_pieces = [
		{"outline": PackedVector2Array([Vector2(0, -1.0), Vector2(-0.62, -0.18), Vector2(0.62, -0.18)]), "skip_wall": -1},
		# The tail's front edge (index 3 -> 0) is tucked against the arrowhead: never drawn.
		{"outline": PackedVector2Array([Vector2(-0.25, -0.18), Vector2(-0.25, 0.78), Vector2(0.25, 0.78), Vector2(0.25, -0.18)]), "skip_wall": 3},
	]


## Show the arrow pointing at "yaw" (radians from straight ahead on screen, + = right) with
## "text" under it. urgent = the hatch is about to seal (bob + pulse faster).
func point_at(yaw: float, text: String, urgent: bool) -> void:
	if not visible:
		_yaw = yaw  # appear already pointing the right way (no spin-in)
		visible = true
	_target_yaw = yaw
	_text = text
	_urgent = urgent


func hide_arrow() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	var speed := urgent_speed if _urgent else 1.0
	_clock += delta * speed
	_yaw = lerp_angle(_yaw, _target_yaw, 1.0 - exp(-turn_speed * delta))
	# The tutorial's box sits in the same top-middle spot: slide down below it while it shows.
	var box := get_parent().get_node_or_null("TutorialBox") as Control
	var top := _base_top
	if box != null and box.visible:
		top = maxf(_base_top, box.position.y + box.size.y + 6.0)
	if not is_equal_approx(offset_top, top):
		var height := offset_bottom - offset_top
		offset_top = top
		offset_bottom = top + height
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + sin(_clock * TAU * bob_speed) * pulse_amount * (urgent_pulse if _urgent else 1.0)
	var scale_px := arrow_size * pulse
	var centre := Vector2(size.x * 0.5, arrow_size * 1.15 + sin(_clock * TAU * bob_speed * 0.5) * bob_height)
	var tilt := deg_to_rad(tilt_degrees)
	# A fake light from the upper left, a bit towards us (view space: x right, y up, z towards us).
	var light := Vector3(-0.45, 0.8, 0.4).normalized()
	var faces: Array = []  # [{"points", "depth", "shade"}]
	for piece in _pieces:
		var middle := Vector3.ZERO
		for p: Vector2 in piece["outline"]:
			middle += Vector3(p.x, 0.0, p.y)
		middle /= (piece["outline"] as PackedVector2Array).size()
		for face: Array in _faces_of(piece):
			# Which way the face looks: away from the middle of its (bulging) piece.
			var normal: Vector3 = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
			var face_middle := Vector3.ZERO
			for p: Vector3 in face:
				face_middle += p
			face_middle /= face.size()
			if normal.dot(face_middle - middle) < 0.0:
				normal = -normal
			normal = _to_view(normal, tilt)
			# Facing away from us? Skip it (the faces at the front hide that side anyway).
			if normal.z <= 0.001:
				continue
			var view: Array[Vector3] = []
			for p: Vector3 in face:
				view.append(_to_view(p, tilt))
			var depth := 0.0
			var points := PackedVector2Array()
			for v in view:
				depth += v.z
				var perspective := 4.0 / (4.0 - v.z)  # a touch of perspective: near corners a bit bigger
				var screen := centre + Vector2(v.x, -v.y) * scale_px * perspective
				if snap > 0.0:
					screen = (screen / snap).round() * snap
				points.append(screen)
			var lit := clampf(normal.dot(light), 0.0, 1.0)
			faces.append({"points": points, "depth": depth / view.size(), "shade": 0.3 + 0.8 * lit})
	# Painter's order: farthest first.
	faces.sort_custom(func(a, b): return a["depth"] < b["depth"])
	var flash := 0.0
	if _urgent:
		flash = 0.35 * maxf(0.0, sin(_clock * TAU * bob_speed))
	for face in faces:
		var colour: Color = (arrow_color * float(face["shade"])).lerp(Color.WHITE, flash)
		colour.a = 1.0
		# (draw_primitive takes a 3- or 4-cornered face as it is: no cutting into triangles that a
		# squashed, pixel-snapped face could make fail.)
		draw_primitive(face["points"], PackedColorArray([colour]), PackedVector2Array())
		var outline: PackedVector2Array = face["points"].duplicate()
		outline.append(outline[0])
		draw_polyline(outline, edge_color, Hud.line(1.5))
	# The words underneath: "PAYPHONE  45m" / "EXIT  80m".
	if _text != "":
		var font := get_theme_font("font", "Label")
		var text_size := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size)
		var at := Vector2((size.x - text_size.x) * 0.5, arrow_size * 2.35 + text_size.y * 0.5)
		draw_string_outline(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, Hud.outline(6), Color(0.01, 0.06, 0.02))
		draw_string(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, label_color.lerp(Color.WHITE, flash))


## Turn a point (or direction) of the arrow to point at the target (_yaw), then tilt it towards
## the camera. View space: x = right, y = up the screen, z = towards us.
func _to_view(p: Vector3, tilt: float) -> Vector3:
	var turned := Vector3(p.x * cos(_yaw) - p.z * sin(_yaw), p.y, p.x * sin(_yaw) + p.z * cos(_yaw))
	return Vector3(turned.x, turned.y * cos(tilt) - turned.z * sin(tilt), turned.z * cos(tilt) + turned.y * sin(tilt))


## The 3D faces (lists of corners, anticlockwise seen from outside) of one bevelled arrow piece:
## a top face (shrunk in by the bevel), sloping bevel faces round it, straight walls, a bottom.
func _faces_of(piece: Dictionary) -> Array:
	var outline: PackedVector2Array = piece["outline"]
	var inner := _shrink(outline, bevel)
	var n := outline.size()
	var bottom_y := -thickness * 0.5
	var mid_y := thickness * 0.5 - bevel * 0.6
	var top_y := thickness * 0.5
	var at := func(p: Vector2, y: float) -> Vector3: return Vector3(p.x, y, p.y)
	var faces: Array = []
	# (Corner order doesn't matter: _draw works out which way each face looks by itself.)
	var top: Array[Vector3] = []
	var under: Array[Vector3] = []
	for i in n:
		top.append(at.call(inner[n - 1 - i], top_y))
		under.append(at.call(outline[i], bottom_y))
	faces.append(top)
	faces.append(under)
	for i in n:
		if i == piece["skip_wall"]:
			continue
		var j := (i + 1) % n
		faces.append([at.call(outline[i], bottom_y), at.call(outline[i], mid_y), at.call(outline[j], mid_y), at.call(outline[j], bottom_y)])
		faces.append([at.call(outline[i], mid_y), at.call(inner[i], top_y), at.call(inner[j], top_y), at.call(outline[j], mid_y)])
	return faces


## A convex outline moved inwards by "amount" on every side (for the bevelled top face).
func _shrink(outline: PackedVector2Array, amount: float) -> PackedVector2Array:
	var n := outline.size()
	var centre := Vector2.ZERO
	for p in outline:
		centre += p
	centre /= n
	var result := PackedVector2Array()
	for i in n:
		var prev := outline[(i - 1 + n) % n]
		var here := outline[i]
		var next := outline[(i + 1) % n]
		# Push both edges at this corner inwards, and take where they cross.
		var a1 := _inward(prev, here, centre, amount)
		var a2 := _inward(here, next, centre, amount)
		var crossing: Variant = Geometry2D.line_intersects_line(prev + a1, here - prev, here + a2, next - here)
		result.append(crossing if crossing != null else here.lerp(centre, 0.2))
	return result


## How far to push the edge a->b sideways so it moves "amount" towards the centre.
func _inward(a: Vector2, b: Vector2, centre: Vector2, amount: float) -> Vector2:
	var side := (b - a).orthogonal().normalized()
	if side.dot(centre - a) < 0.0:
		side = -side
	return side * amount
