class_name HudHeatBar
extends Control
## CYPURRPUNK — the HEAT bar, top-right of the HUD. A mirror image of your health bar
## (scripts/ui/hud_health_bar.gd): same shape, but the number box sits on the RIGHT and the bar
## grows from the right-hand edge towards the middle.
## Lives at scenes/ui/hud.tscn > HUD > Frame > Top > Heat. Drawn in code (_draw), so it is sharp
## at any resolution. scripts/heat_meter.gd feeds it every frame with set_heat().
##
## What you see:
##   ░░░░██████████  [ 42 ]   <- the bar, then the number box (heat 0..100)
##   - The fill FLASHES back and forth between RED and BLUE like police lights.
##   - The hotter it gets, the faster it flashes (flash_speed + flash_speed_per_level).
##   - When the heat goes up a LEVEL (every 25), the frame flashes white for a moment.
##   - Thin tick marks on the bar show the level steps (25 / 50 / 75); 75 = the exit opens.
##
## Move / resize it in hud.tscn like any Control (select Heat, drag it, or change Layout >
## Transform). Colours and timings are below (Inspector, with Heat selected).

@export_group("Colours")
## The two police-light colours the bar flips between.
@export var red_color: Color = Color(1.0, 0.2, 0.25)
@export var blue_color: Color = Color(0.25, 0.45, 1.0)
@export var back_color: Color = Color(0.03, 0.03, 0.12, 0.8)

@export_group("Shape")
## How thick the bar is (HUD units; the screen is 720 tall).
@export var bar_thickness: float = 9.0
## Width of the number box on the right.
@export var number_box_width: float = 64.0
@export var number_font_size: int = 26
## Draw small tick marks on the bar at every heat level (25, 50, 75).
@export var show_level_ticks: bool = true

@export_group("Feel")
## Red/blue flips per second at heat level 1.
@export var flash_speed: float = 1.5
## Extra flips per second for every heat level above 1 (level 4 = 1.5 + 3 x 1.0 = 4.5 a second).
@export var flash_speed_per_level: float = 1.0
## 0 = hard police-light switch between red and blue, 1 = smooth fade between them.
@export_range(0.0, 1.0) var smoothness: float = 0.25
## Seconds the frame flashes white when the heat goes up a level.
@export var level_up_flash: float = 0.6

var _heat: float = 0.0
var _max: float = 100.0
var _level: int = 1
var _level_flash: float = 0.0
## Where we are in the red/blue cycle (0..1 = one red + one blue).
var _phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called every frame by heat_meter.gd with the shared heat (0..max) and the heat level (1..5).
func set_heat(heat: float, max_heat: float, level: int) -> void:
	if max_heat <= 0.0:
		return
	if level > _level:
		_level_flash = level_up_flash
	_heat = heat
	_max = max_heat
	_level = level


func _process(delta: float) -> void:
	# Two flips (red -> blue -> red) make one full cycle, so the cycle speed is half the flip speed.
	var flips_per_second := flash_speed + flash_speed_per_level * maxi(_level - 1, 0)
	_phase = fmod(_phase + delta * flips_per_second * 0.5, 1.0)
	_level_flash = maxf(_level_flash - delta, 0.0)
	queue_redraw()


## The colour right now: red for the first half of the cycle, blue for the second half.
## smoothness rounds off the switch (a sine wave squashed towards a square wave).
func current_color() -> Color:
	var wave := sin(_phase * TAU)  # +1 = red, -1 = blue
	var sharp := 1.0 if wave >= 0.0 else -1.0
	var mixed := lerpf(sharp, wave, smoothness)
	return blue_color.lerp(red_color, mixed * 0.5 + 0.5)


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var h := size.y
	var colour := current_color()
	var frame_colour := Color.WHITE if _level_flash > 0.0 else colour * Color(1, 1, 1, 0.9)
	var box_left := size.x - number_box_width
	var bar_w := box_left - 8.0
	var bar_top := (h - bar_thickness) * 0.5
	var fraction := clampf(_heat / _max, 0.0, 1.0)

	# --- The number box (right side): [ 42 ] ---
	var box := Rect2(box_left, 0, number_box_width, h)
	draw_rect(box, back_color)
	draw_rect(box, frame_colour, false, 2.0)
	var number := str(floori(_heat))
	var number_colour := Color.WHITE if _level_flash > 0.0 else colour.lerp(Color.WHITE, 0.25)
	var text_size := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_font_size)
	var text_pos := Vector2(box_left + (number_box_width - text_size.x) * 0.5, (h + text_size.y) * 0.5 - font.get_descent(number_font_size))
	draw_string_outline(font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_font_size, 6, Color(0.04, 0.01, 0.08))
	draw_string(font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_font_size, number_colour)

	# --- The bar: dark back, flashing fill growing from the RIGHT edge (next to the number) ---
	draw_rect(Rect2(0, bar_top, bar_w, bar_thickness), back_color)
	draw_rect(Rect2(bar_w * (1.0 - fraction), bar_top, bar_w * fraction, bar_thickness), colour)
	if show_level_ticks:
		for step: float in [0.25, 0.5, 0.75]:
			var x := bar_w * (1.0 - step)
			draw_line(Vector2(x, bar_top - 2.0), Vector2(x, bar_top + bar_thickness + 2.0), Color(1, 1, 1, 0.5), 1.0)
	draw_rect(Rect2(0, bar_top, bar_w, bar_thickness), frame_colour, false, 1.0)
