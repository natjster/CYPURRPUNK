@tool
class_name MenuLogo
extends Control
## CYPURRPUNK — the big logo on the start menu, drawn in code so it stays crisp in both UI looks.
##
##   ┌                         ┐      corner brackets like the HUD's boxes
##          /\  /\                    cat ears perched on "PURR"
##     CY  PURR  PUNK                 ice-white letters, "PURR" in neon pink,
##   └────────────═══─────────┘      pink + cyan "glitch" shadows behind them, a thin bar underneath
##
## Where it is: Main scene > PS1Overlay > Lobby > Logo. Click it and tune it in the Inspector
## (it redraws live in the editor). Every few seconds it "glitches" (the shadows jump) for a moment.

@export_group("Words")
## The three parts of the name: the middle one is coloured and gets the cat ears.
@export var before: String = "CY"
@export var middle: String = "PURR"
@export var after: String = "PUNK"
## Letter size (menu pixels; the menu screen is 240 tall).
@export var font_size: int = 40
## Where the letters sit (their baseline), from the top of this box.
@export var baseline: float = 44.0

## Cat ears: width and height (x the letter size), and how far down into the letters they sit.
@export var ear_width: float = 0.55
@export var ear_height: float = 0.38
@export var ear_sink: float = 4.0

@export_group("Colours")
## The outer words (CY, PUNK): icy white-blue like the HUD's text.
@export var main_color: Color = Color(0.86, 0.97, 1.0)
## The middle word (PURR) + the ears.
@export var accent_color: Color = Color(1.0, 0.45, 0.82)
## The dark outline round every letter.
@export var outline_color: Color = Color(0.01, 0.04, 0.08)
@export var outline_size: int = 4
## The two "glitch" shadows behind the letters (offset left / right).
@export var shadow_a: Color = Color(0.22, 0.72, 0.98, 0.75)
@export var shadow_b: Color = Color(1.0, 0.3, 0.75, 0.6)
## How far the shadows sit from the letters normally (menu pixels).
@export var shadow_offset: float = 1.5
## The corner brackets and the bar under the words (the HUD's ocean blue).
@export var frame_color: Color = Color(0.22, 0.72, 0.98, 0.9)

@export_group("Glitch")
## Seconds between glitches (0 = never).
@export var glitch_every: float = 3.5
## How long one glitch lasts (seconds).
@export var glitch_length: float = 0.18
## How far the shadows jump during a glitch.
@export var glitch_offset: float = 4.0

var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _jitter: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()


func _process(delta: float) -> void:
	_time += delta
	var glitching := glitch_every > 0.0 and fmod(_time, glitch_every) < glitch_length
	var jitter := Vector2(_rng.randf_range(-1, 1) * glitch_offset, _rng.randf_range(-0.5, 0.5)) if glitching else Vector2.ZERO
	if jitter != _jitter or glitching:
		_jitter = jitter
		queue_redraw()


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	if font == null:
		return
	var full := before + middle + after
	var full_width := font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x0 := (size.x - full_width) / 2.0
	var mid_x := x0 + font.get_string_size(before, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var mid_w := font.get_string_size(middle, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var after_x := mid_x + mid_w
	var cap := font_size * 0.72  # roughly how tall the capital letters are
	var top := baseline - cap

	# Cat ears on the middle word (drawn first so the letters overlap their bottoms).
	var ear_w := font_size * ear_width
	var ear_h := font_size * ear_height
	var letter_w := mid_w / maxf(middle.length(), 1)  # (the font is monospace: every letter is as wide)
	for side in [0, 1]:
		# Over the first and last letter of the middle word, leaning outwards a little.
		var cx := mid_x + letter_w * (0.5 if side == 0 else middle.length() - 0.5)
		var lean := -ear_w * 0.22 if side == 0 else ear_w * 0.22
		var base_y := top + ear_sink
		var outer := PackedVector2Array([Vector2(cx - ear_w / 2.0, base_y), Vector2(cx + lean, base_y - ear_h), Vector2(cx + ear_w / 2.0, base_y)])
		draw_colored_polygon(_grow(outer, 2.0), outline_color)
		draw_colored_polygon(outer, accent_color)
		var inner := PackedVector2Array([Vector2(cx - ear_w * 0.22, base_y), Vector2(cx + lean * 0.7, base_y - ear_h * 0.6), Vector2(cx + ear_w * 0.22, base_y)])
		draw_colored_polygon(inner, accent_color.darkened(0.45))

	# Glitch shadows: the whole word twice, offset sideways in blue and pink.
	var off := Vector2(shadow_offset, 0) + _jitter
	for pass_data in [[-off, shadow_a], [off + Vector2(0, 1), shadow_b]]:
		draw_string(font, Vector2(x0, baseline) + pass_data[0], full, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, pass_data[1])

	# The letters: dark outline, then fill (outer words ice white, middle word pink).
	var parts := [[before, x0, main_color], [middle, mid_x, accent_color], [after, after_x, main_color]]
	for part in parts:
		draw_string_outline(font, Vector2(part[1], baseline), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_color)
	for part in parts:
		draw_string(font, Vector2(part[1], baseline), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, part[2])

	# Thin scan lines across the letters (every 3rd row a little darker), like an old monitor.
	var y := top
	while y < baseline + 2:
		draw_rect(Rect2(x0 - 2, y, full_width + 4, 1), Color(0.0, 0.03, 0.08, 0.28))
		y += 3.0

	# The bar underneath: ocean blue, with a pink piece under the middle word.
	var bar_y := baseline + 5.0
	draw_rect(Rect2(x0, bar_y, full_width, 1), frame_color)
	draw_rect(Rect2(mid_x, bar_y - 0.5, mid_w, 2), accent_color)

	# HUD-style corner brackets round the whole logo.
	var box := Rect2(x0 - 8, top - ear_h - 2, full_width + 16, bar_y + 6 - (top - ear_h - 2))
	var c := 7.0
	var bright := frame_color.lightened(0.35)
	for corner in [[box.position, Vector2(1, 1)], [Vector2(box.end.x, box.position.y), Vector2(-1, 1)], [Vector2(box.position.x, box.end.y), Vector2(1, -1)], [box.end, Vector2(-1, -1)]]:
		var at: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_rect(Rect2(at, Vector2(c * d.x, d.y)).abs(), bright)
		draw_rect(Rect2(at, Vector2(d.x, c * d.y)).abs(), bright)


## A triangle made a bit bigger all round (for the ears' dark outline).
func _grow(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var centre := (points[0] + points[1] + points[2]) / 3.0
	var out := PackedVector2Array()
	for p in points:
		out.append(p + (p - centre).normalized() * amount)
	return out
