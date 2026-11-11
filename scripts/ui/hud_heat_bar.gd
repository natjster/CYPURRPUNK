class_name HudHeatBar
extends Control
## CYPURRPUNK — the HEAT bar, top-right of the HUD. A mirror image of your health bar
## (scripts/ui/hud_health_bar.gd): same shape, but the number box sits on the RIGHT and the bar
## grows from the right-hand edge towards the middle.
## Lives at scenes/ui/hud.tscn > HUD > Frame > Top > Heat. Drawn in code (_draw), so it is sharp
## at any resolution. scripts/heat_meter.gd feeds it every frame with set_heat().
##
## What you see (kept clean on purpose: just one bar with the number in it):
##   [░░░░░░████████ 42]   <- heat 0..100; the fill grows from the RIGHT edge, the number sits inside
##   - The fill FLASHES back and forth between RED and BLUE like police lights.
##   - The hotter it gets, the faster it flashes (flash_speed + flash_speed_per_level).
##   - When the heat goes up a LEVEL (every 25), the frame flashes white for a moment.
##   - Optional (off by default, Inspector > Shape): tick marks at 25 / 50 / 75 (Show Level Ticks)
##     and a white notch where YOUR gang's exit opens (Show Exit Mark; scripts/mainframe.gd exit_heat).
##
## DOWN IN THE SEWERS the same bar shows YOUR GANG'S MAINFRAME instead (scripts/mainframe.gd; heat_meter.gd
## calls set_mainframe() while you're in the hub): its charge 0..100% in the terminal colour of
## its tier (cyan OVERCLOCK, green ONLINE, yellow POWER LOW, orange WARNING, flashing red
## CRITICAL), with "MAINFRAME" written inside the bar's left end, and a white flash when it's fed.
##
## Move / resize it in hud.tscn like any Control (select Heat, drag it, or change Layout >
## Transform). Colours and timings are below (Inspector, with Heat selected).

@export_group("Colours")
## The two police-light colours the bar flips between.
@export var red_color: Color = Color(1.0, 0.2, 0.25)
@export var blue_color: Color = Color(0.25, 0.45, 1.0)
@export var back_color: Color = Color(0.03, 0.03, 0.12, 0.8)

@export_group("Shape")
## How thick the bar is (HUD units; the screen is 720 tall). The number is written inside it.
@export var bar_thickness: float = 26.0
## Size of the number inside the bar (it shrinks itself if the bar is too thin).
@export var number_font_size: int = 22
## Gap between the number and the bar's right end.
@export var number_padding: float = 8.0
## Draw small tick marks on the bar at every heat level (25, 50, 75).
@export var show_level_ticks: bool = false
## Draw a white notch where YOUR gang's exit opens.
@export var show_exit_mark: bool = false

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
## Size of the "MAINFRAME" word inside the bar's left end.
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
	var colour := current_color()
	var frame_colour := Color.WHITE if _level_flash > 0.0 else colour * Color(1, 1, 1, 0.9)
	var bar_h := minf(bar_thickness, size.y)
	var bar := Rect2(0, (size.y - bar_h) * 0.5, size.x, bar_h)
	var fraction := clampf(_heat / _max, 0.0, 1.0)
	var outline := Color(0.01, 0.04, 0.08)

	# --- The bar: dark back, flashing fill growing from the RIGHT edge ---
	draw_rect(bar, back_color)
	draw_rect(Rect2(bar.end.x - bar.size.x * fraction, bar.position.y, bar.size.x * fraction, bar_h), colour * Color(1, 1, 1, 0.85))
	if show_level_ticks:
		for step: float in [0.25, 0.5, 0.75]:
			var x := bar.size.x * (1.0 - step)
			draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(1, 1, 1, 0.35), Hud.line(1.0))
	if show_exit_mark and not _mainframe_mode and _exit_heat >= 0.0:
		var exit_x := bar.size.x * (1.0 - clampf(_exit_heat / _max, 0.0, 1.0))
		draw_line(Vector2(exit_x, bar.position.y), Vector2(exit_x, bar.end.y), Color.WHITE, Hud.line(2.0))
	draw_rect(bar.grow(-Hud.line(1.0) * 0.5), frame_colour, false, Hud.line(2.0))

	# --- The number, inside the bar at its right end: 42 (Mainframe mode: 75%) ---
	var number := str(floori(_heat)) + ("%" if _mainframe_mode else "")
	var font_size := mini(number_font_size, int(bar_h * 0.85))
	var text_size := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := bar.position.y + (bar_h + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var text_pos := Vector2(bar.end.x - number_padding - text_size.x, baseline)
	draw_string_outline(font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Hud.outline(5), outline)
	draw_string(font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	# Mainframe mode: "MAINFRAME" inside the bar's left end.
	if _mainframe_mode:
		var tag := "MAINFRAME"
		var tag_font := mini(Hud.text_size(mainframe_tag_size), int(bar_h * 0.8))
		var tag_base := bar.position.y + (bar_h + font.get_ascent(tag_font) - font.get_descent(tag_font)) * 0.5
		var tag_pos := Vector2(number_padding, tag_base)
		if tag_pos.x + font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_font).x < text_pos.x - 6.0:
			draw_string_outline(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_font, Hud.outline(4), outline)
			draw_string(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_font, colour.lerp(Color.WHITE, 0.5))
