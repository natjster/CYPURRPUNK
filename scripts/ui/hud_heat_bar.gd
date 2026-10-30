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
##   - Thin tick marks on the bar show the level steps (25 / 50 / 75).
##   - A taller white tick tagged EXIT shows the heat where YOUR gang's exit opens (60 / 75 / 82 /
##     90 / 95, from your gang's Mainframe: scripts/mainframe.gd exit_heat).
##
## DOWN IN THE SEWERS the same bar shows YOUR GANG'S MAINFRAME instead (scripts/mainframe.gd; heat_meter.gd
## calls set_mainframe() while you're in the hub): its charge 0..100% in the terminal colour of
## its tier (cyan OVERCLOCK, green ONLINE, yellow POWER LOW, orange WARNING, flashing red
## CRITICAL), the same 25 / 50 / 75 ticks, a "MAINFRAME" tag, and a white flash when it's fed.
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
## Size of the little "EXIT" tag over your gang's exit tick.
@export var exit_tag_size: int = 12

@export_group("Feel")
## Red/blue flips per second at heat level 1.
@export var flash_speed: float = 1.5
## Extra flips per second for every heat level above 1 (level 4 = 1.5 + 3 x 1.0 = 4.5 a second).
@export var flash_speed_per_level: float = 1.0
## 0 = hard police-light switch between red and blue, 1 = smooth fade between them.
@export_range(0.0, 1.0) var smoothness: float = 0.25
## Seconds the frame flashes white when the heat goes up a level.
@export var level_up_flash: float = 0.6

@export_group("Mainframe mode (in the sewers)")
## Size of the little "MAINFRAME" tag above the bar.
@export var mainframe_tag_size: int = 14
## Flashes per second of the bar when the Mainframe is CRITICAL (0%).
@export var critical_flash_speed: float = 2.0

var _heat: float = 0.0
var _max: float = 100.0
var _level: int = 1
## The heat at which your gang's exit opens (the EXIT tick). -1 = no tick.
var _exit_heat: float = -1.0
var _level_flash: float = 0.0
## Where we are in the red/blue cycle (0..1 = one red + one blue).
var _phase: float = 0.0
## True while showing THE MAINFRAME (set_mainframe) instead of the heat (set_heat).
var _mainframe_mode: bool = false
var _mainframe_color: Color = Color(0.2, 1.0, 0.45)
var _mainframe_critical: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called every frame by heat_meter.gd with the shared heat (0..max), the heat level (1..5) and
## the heat at which this player's gang's exit opens.
func set_heat(heat: float, max_heat: float, level: int, exit_heat: float = -1.0) -> void:
	if max_heat <= 0.0:
		return
	if level > _level and not _mainframe_mode:
		_level_flash = level_up_flash
	_mainframe_mode = false
	_heat = heat
	_max = max_heat
	_level = level
	_exit_heat = exit_heat


## Called every frame by heat_meter.gd while the player is in the sewers: THE MAINFRAME's charge
## (0..max), its tier colour, and whether it's CRITICAL (the bar flashes).
func set_mainframe(charge: float, max_charge: float, color: Color, critical: bool) -> void:
	if max_charge <= 0.0:
		return
	if _mainframe_mode and charge > _heat:
		_level_flash = level_up_flash  # scrap fed in: flash white
	_mainframe_mode = true
	_heat = charge
	_max = max_charge
	_mainframe_color = color
	_mainframe_critical = critical


func _process(delta: float) -> void:
	# Two flips (red -> blue -> red) make one full cycle, so the cycle speed is half the flip speed.
	var flips_per_second := flash_speed + flash_speed_per_level * maxi(_level - 1, 0)
	_phase = fmod(_phase + delta * flips_per_second * 0.5, 1.0)
	_level_flash = maxf(_level_flash - delta, 0.0)
	queue_redraw()


## The colour right now: red for the first half of the cycle, blue for the second half.
## smoothness rounds off the switch (a sine wave squashed towards a square wave).
## (Mainframe mode: the tier's terminal colour, blinking dark when CRITICAL.)
func current_color() -> Color:
	if _mainframe_mode:
		if _mainframe_critical and fmod(Time.get_ticks_msec() / 1000.0 * critical_flash_speed, 1.0) > 0.5:
			return _mainframe_color.darkened(0.6)
		return _mainframe_color
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

	# --- The number box (right side): [ 42 ] (Mainframe mode: [ 75% ]) ---
	var box := Rect2(box_left, 0, number_box_width, h)
	draw_rect(box, back_color)
	draw_rect(box, frame_colour, false, Hud.line(2.0))
	var number := str(floori(_heat))
	var font_size := number_font_size
	if _mainframe_mode:
		number += "%"
		# Shrink the text until "100%" fits in the box.
		while font_size > 10 and font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > number_box_width - 10.0:
			font_size -= 2
	var number_colour := Color.WHITE if _level_flash > 0.0 else colour.lerp(Color.WHITE, 0.25)
	var text_size := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos := Vector2(box_left + (number_box_width - text_size.x) * 0.5, (h + text_size.y) * 0.5 - font.get_descent(font_size))
	draw_string_outline(font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Hud.outline(6), Color(0.04, 0.01, 0.08))
	draw_string(font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, number_colour)

	# Mainframe mode: a small "MAINFRAME" tag just above the bar's right end.
	if _mainframe_mode:
		var tag := "MAINFRAME"
		var tag_size := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, mainframe_tag_size)
		var tag_pos := Vector2(bar_w - tag_size.x, bar_top - 4.0)
		draw_string_outline(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, mainframe_tag_size, 4, Color(0.04, 0.01, 0.08))
		draw_string(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, mainframe_tag_size, colour.lerp(Color.WHITE, 0.3))

	# --- The bar: dark back, flashing fill growing from the RIGHT edge (next to the number) ---
	draw_rect(Rect2(0, bar_top, bar_w, bar_thickness), back_color)
	draw_rect(Rect2(bar_w * (1.0 - fraction), bar_top, bar_w * fraction, bar_thickness), colour)
	if show_level_ticks:
		for step: float in [0.25, 0.5, 0.75]:
			var x := bar_w * (1.0 - step)
			draw_line(Vector2(x, bar_top - 2.0), Vector2(x, bar_top + bar_thickness + 2.0), Color(1, 1, 1, 0.5), Hud.line(1.0))
	draw_rect(Rect2(0, bar_top, bar_w, bar_thickness), frame_colour, false, Hud.line(1.0))

	# --- Up top: where YOUR gang's exit opens (a taller white tick, tagged EXIT) ---
	if not _mainframe_mode and _exit_heat >= 0.0:
		var exit_x := bar_w * (1.0 - clampf(_exit_heat / _max, 0.0, 1.0))
		draw_line(Vector2(exit_x, bar_top - 5.0), Vector2(exit_x, bar_top + bar_thickness + 5.0), Color.WHITE, Hud.line(2.0))
		var exit_tag_width := font.get_string_size("EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, exit_tag_size).x
		var exit_tag_pos := Vector2(exit_x - exit_tag_width * 0.5, bar_top - 7.0)
		draw_string_outline(font, exit_tag_pos, "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, exit_tag_size, 4, Color(0.04, 0.01, 0.08))
		draw_string(font, exit_tag_pos, "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, exit_tag_size, Color.WHITE)
