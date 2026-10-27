class_name HudDamageNumbers
extends Control
## CYPURRPUNK — damage numbers that pop off things you shoot (Cyberpunk-style), drawn by the HUD
## so they're sharp. Lives at scenes/ui/hud.tscn > HUD > Frame > Damage.
##
## Each number sticks to the spot in the world you hit, pops in, floats up and fades out.
##   - normal hit: white, e.g. "38"
##   - CRITICAL hit: bigger, yellow-orange, with a "!" e.g. "84!"
## Only the player who fired sees their numbers (on their own HUD in split screen).
##
## Other scripts: Hud.damage_number(hit_position, amount, is_crit, cat.slot)
## (weapon.gd does this the moment a bolt hits a VAC-COP.)

## Seconds a number stays on screen.
@export var lifetime: float = 0.9
## How far it floats up while fading (HUD units).
@export var rise: float = 50.0
## Random sideways drift, so several quick hits don't stack on top of each other.
@export var spread: float = 22.0
@export var font_size: int = 22
@export var crit_font_size: int = 34
@export var color: Color = Color(1, 1, 1)
@export var crit_color: Color = Color(1, 0.82, 0.2)

## [{where (Vector3), text, crit, age, drift (Vector2)}]
var _numbers: Array = []
## What to draw this frame: [{pos, text, crit, age}].
var _draw_list: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Show "amount" popping off the world position "where".
func spawn(where: Vector3, amount: int, crit: bool) -> void:
	_numbers.append({
		"where": where, "text": str(amount) + ("!" if crit else ""), "crit": crit, "age": 0.0,
		"drift": Vector2(randf_range(-spread, spread), randf_range(-spread * 0.3, spread * 0.3))})
	if _numbers.size() > 40:  # a long tommy-gun burst: forget the oldest
		_numbers.pop_front()


func _process(delta: float) -> void:
	var seat: int = (owner as Hud).seat if owner is Hud else 0
	var screen := GameScreen.instance
	var camera: Camera3D = screen.camera_for_seat(seat) if screen != null else null
	var game_size: Vector2 = screen.screen_size_for_seat(seat) if screen != null else Vector2.ONE
	_draw_list.clear()
	for n in _numbers:
		n.age += delta
	_numbers = _numbers.filter(func(n): return n.age < lifetime)
	if camera != null:
		for n in _numbers:
			if camera.is_position_behind(n.where):
				continue
			var t: float = n.age / lifetime
			var pos: Vector2 = camera.unproject_position(n.where) * (size / game_size) + n.drift * t - Vector2(0, rise * t)
			_draw_list.append({"pos": pos, "text": n.text, "crit": n.crit, "t": t})
	queue_redraw()


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	for n in _draw_list:
		var t: float = n.t
		# Pop: starts 1.6x big and snaps down in the first 15%; fades in the last 40%.
		var pop := 1.0 + 0.6 * clampf(1.0 - t / 0.15, 0.0, 1.0)
		var font_px := roundi((crit_font_size if n.crit else font_size) * pop)
		var alpha := clampf((1.0 - t) / 0.4, 0.0, 1.0)
		var text_w := font.get_string_size(n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
		var pos: Vector2 = (n.pos - Vector2(text_w * 0.5, 0)).round()
		draw_string_outline(font, pos, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, 7, Color(0.04, 0.01, 0.08, alpha))
		draw_string(font, pos, n.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, Color(crit_color if n.crit else color, alpha))
