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
##   - Kept as plain as the health bar on purpose. Optional extras (Inspector > Shape, OFF by default):
##     Show Level Ticks (25 / 50 / 75 marks) and Show Exit Mark (a white tick tagged EXIT where YOUR
##     gang's exit opens: scripts/mainframe.gd exit_heat).
##
## DOWN IN THE SEWERS the same bar shows YOUR GANG'S MAINFRAME instead (scripts/mainframe.gd; heat_meter.gd
## calls set_mainframe() while you're in the hub): its charge 0..100% in the terminal colour of
## its tier (cyan OVERCLOCK, green ONLINE, yellow POWER LOW, orange WARNING, flashing red
## CRITICAL) and a white flash when it's fed. (Show Mainframe Tag = a small "MAINFRAME" word over it.)
##
## THE LAST CALL (heat 100, scripts/fish_heist.gd hatch_closing_seconds): the bar turns into the
## HATCH CLOSING countdown, up top AND in the sewers (fish_heist.gd calls set_hatch every frame):
##   HATCH CLOSING                        <- tag over the bar ("... - YOU'RE SAFE" in the sewers)
##   ░░░░░░░░░▚▚▚▚▚▚▚▚▚▚▚▚▚  [ 7 ]          <- hazard stripes that DRAIN towards the number box,
##                                           the seconds left thump on every tick
##   - The last danger_seconds: red, and the whole thing flashes.
##   - When it hits 0: the box says SAFE (green) or TOO LATE (red) for sealed_seconds
##     (set_hatch_sealed), then it's the plain heat bar again.
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
@export var show_level_ticks: bool = false
## Draw the EXIT tick where your gang's exit opens.
@export var show_exit_mark: bool = false
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

@export_group("Hatch closing (heat 100)")
## The hazard stripes and the tag while there's still time.
@export var hatch_color: Color = Color(1.0, 0.78, 0.12)
## The last danger_seconds, and the TOO LATE card.
@export var danger_color: Color = Color(1.0, 0.16, 0.14)
## The tag in the sewers, and the SAFE card.
@export var safe_color: Color = Color(0.45, 1.0, 0.55)
## Below this many seconds the countdown goes red and flashes.
@export var danger_seconds: float = 3.0
## How long the SAFE / TOO LATE card stays once the hatch seals (seconds).
@export var sealed_seconds: float = 3.0
## Size of the "HATCH CLOSING" tag over the bar.
@export var hatch_tag_size: int = 16
## How much bigger the seconds get on each tick (0.35 = 35%).
@export var thump_scale: float = 0.35

@export_group("Mainframe mode (in the sewers)")
## Write a small "MAINFRAME" over the bar in the sewers.
@export var show_mainframe_tag: bool = false
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
## THE LAST CALL: seconds left (-1 = not counting), what it started from, and whether this player
## is already safe in the sewers.
var _hatch_left: float = -1.0
var _hatch_total: float = 10.0
var _hatch_safe: bool = false
## Seconds since the hatch sealed (-1 = no SAFE / TOO LATE card showing) and which card.
var _sealed_for: float = -1.0
var _made_it: bool = false


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


## fish_heist.gd, every frame of THE LAST CALL: seconds left, seconds it started from, and whether
## this player is already safe in the sewers.
func set_hatch(seconds_left: float, seconds_total: float, safe: bool) -> void:
	_hatch_left = maxf(seconds_left, 0.0)
	_hatch_total = maxf(seconds_total, 0.01)
	_hatch_safe = safe
	_sealed_for = -1.0


## fish_heist.gd, the moment the hatch seals: the SAFE (made_it) or TOO LATE card.
func set_hatch_sealed(made_it: bool) -> void:
	if _hatch_left >= 0.0:
		_sealed_for = 0.0
		_made_it = made_it
		_hatch_left = -1.0


## Back to the plain heat bar (a new district).
func clear_hatch() -> void:
	_hatch_left = -1.0
	_sealed_for = -1.0


func _process(delta: float) -> void:
	if _sealed_for >= 0.0:
		_sealed_for += delta
		if _sealed_for >= sealed_seconds:
			_sealed_for = -1.0
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
	if _hatch_left >= 0.0 or _sealed_for >= 0.0:
		_draw_hatch()
		return
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

	# Mainframe mode: a small "MAINFRAME" tag just above the bar's right end (optional).
	if _mainframe_mode and show_mainframe_tag:
		var tag := "MAINFRAME"
		var tag_font := Hud.text_size(mainframe_tag_size)  # (PS1 look: bigger, so it's readable)
		var tag_size := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_font)
		var tag_pos := Vector2(bar_w - tag_size.x, bar_top - 4.0)
		draw_string_outline(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_font, Hud.outline(4), Color(0.04, 0.01, 0.08))
		draw_string(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_font, colour.lerp(Color.WHITE, 0.3))

	# --- The bar: dark back, flashing fill growing from the RIGHT edge (next to the number) ---
	draw_rect(Rect2(0, bar_top, bar_w, bar_thickness), back_color)
	draw_rect(Rect2(bar_w * (1.0 - fraction), bar_top, bar_w * fraction, bar_thickness), colour)
	if show_level_ticks:
		for step: float in [0.25, 0.5, 0.75]:
			var x := bar_w * (1.0 - step)
			draw_line(Vector2(x, bar_top - 2.0), Vector2(x, bar_top + bar_thickness + 2.0), Color(1, 1, 1, 0.5), Hud.line(1.0))
	draw_rect(Rect2(0, bar_top, bar_w, bar_thickness), frame_colour, false, Hud.line(1.0))

	# --- Up top: where YOUR gang's exit opens (a taller white tick, tagged EXIT) ---
	if show_exit_mark and not _mainframe_mode and _exit_heat >= 0.0:
		var exit_x := bar_w * (1.0 - clampf(_exit_heat / _max, 0.0, 1.0))
		draw_line(Vector2(exit_x, bar_top - 5.0), Vector2(exit_x, bar_top + bar_thickness + 5.0), Color.WHITE, Hud.line(2.0))
		var exit_font := Hud.text_size(exit_tag_size)  # (PS1 look: bigger, so it's readable)
		var exit_tag_width := font.get_string_size("PHONE", HORIZONTAL_ALIGNMENT_LEFT, -1, exit_font).x
		var exit_tag_pos := Vector2(exit_x - exit_tag_width * 0.5, bar_top - 7.0)
		draw_string_outline(font, exit_tag_pos, "PHONE", HORIZONTAL_ALIGNMENT_LEFT, -1, exit_font, Hud.outline(4), Color(0.04, 0.01, 0.08))
		draw_string(font, exit_tag_pos, "PHONE", HORIZONTAL_ALIGNMENT_LEFT, -1, exit_font, Color.WHITE)


# --- THE LAST CALL look (heat 100: the hatch is closing) ---

func _draw_hatch() -> void:
	var font := get_theme_font("font", "Label")
	var now := Time.get_ticks_msec() / 1000.0
	var h := size.y
	var box_left := size.x - number_box_width
	var bar_w := box_left - 8.0
	var bar_top := (h - bar_thickness) * 0.5
	var dark := Color(0.04, 0.01, 0.08)
	var sealed := _sealed_for >= 0.0
	var danger := not sealed and _hatch_left <= danger_seconds
	var flash := 0.5 + 0.5 * sin(now * TAU * 3.0) if danger else 0.0
	var accent := danger_color if danger else hatch_color
	if sealed:
		accent = safe_color if _made_it else danger_color
	var frame_colour := accent.lerp(Color.WHITE, flash * 0.6)

	# --- The number box: the seconds left (thumping on every tick), or SAFE / TOO LATE ---
	var box := Rect2(box_left, 0, number_box_width, h)
	draw_rect(box, back_color)
	if danger:
		draw_rect(box, Color(danger_color, 0.35 * flash))
	draw_rect(box, frame_colour, false, Hud.line(2.0))
	var number := str(ceili(_hatch_left)) if not sealed else ("SAFE" if _made_it else "SHUT")
	var font_size := number_font_size
	while font_size > 10 and font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > number_box_width - 10.0:
		font_size -= 2
	var into_second := _hatch_left - floorf(_hatch_left)  # just after a tick ~1 -> just before the next ~0
	var thump := 1.0 + thump_scale * pow(into_second, 4.0) if not sealed and _hatch_left > 0.05 else 1.0
	if sealed:
		thump = 1.0 + 0.5 * clampf(1.0 - _sealed_for / 0.15, 0.0, 1.0)  # (slammed in)
	var text_size := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var centre := box.get_center()
	draw_set_transform(centre, 0.0, Vector2.ONE * thump)
	var text_pos := Vector2(-text_size.x * 0.5, text_size.y * 0.5 - font.get_descent(font_size))
	draw_string_outline(font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Hud.outline(6), dark)
	draw_string(font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE.lerp(accent, 0.35 if danger or sealed else 0.0))
	draw_set_transform(Vector2.ZERO)

	# --- The bar: hazard stripes that drain towards the number box as the seconds run out ---
	var fraction := 0.0 if sealed else clampf(_hatch_left / _hatch_total, 0.0, 1.0)
	var bar := Rect2(0, bar_top, bar_w, bar_thickness)
	draw_rect(bar, back_color)
	var fill := Rect2(bar_w * (1.0 - fraction), bar_top, bar_w * fraction, bar_thickness)
	if fill.size.x > 0.5:
		draw_rect(fill, Color(accent, 0.55))
		_draw_stripes(fill, accent.lerp(Color.WHITE, flash * 0.4), now)
	# One notch per second.
	for i in range(1, int(ceilf(_hatch_total))):
		var x := bar_w * (1.0 - float(i) / _hatch_total)
		draw_line(Vector2(x, bar_top), Vector2(x, bar_top + bar_thickness), Color(0, 0, 0, 0.7), Hud.line(1.0))
	draw_rect(bar, frame_colour, false, Hud.line(1.0))

	# --- The tag over the bar ---
	var tag := ("HATCH SEALED - SAFE" if _made_it else "HATCH SEALED - TOO LATE") if sealed else ("HATCH CLOSING - YOU'RE SAFE" if _hatch_safe else "HATCH CLOSING - GET OUT!")
	var tag_font := Hud.text_size(hatch_tag_size)
	var tag_size := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_font)
	var tag_pos := Vector2(bar_w - tag_size.x, bar_top - 4.0)
	var tag_colour := safe_color if _hatch_safe and not sealed else accent
	draw_string_outline(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_font, Hud.outline(5), dark)
	draw_string(font, tag_pos, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_font, tag_colour.lerp(Color.WHITE, flash * 0.5))


## Diagonal black stripes over a filled box, scrolling sideways (a hazard tape look).
func _draw_stripes(box: Rect2, colour: Color, now: float) -> void:
	draw_rect(box, colour)
	var step := 10.0
	var shift := fmod(now * 24.0, step * 2.0)
	var x := box.position.x - box.size.y - step * 2.0 + shift
	while x < box.end.x:
		var a := Vector2(x, box.end.y)
		var points := PackedVector2Array([a, a + Vector2(step, 0), a + Vector2(step + box.size.y, -box.size.y), a + Vector2(box.size.y, -box.size.y)])
		for i in points.size():
			points[i].x = clampf(points[i].x, box.position.x, box.end.x)  # (keep inside the box)
		if points[1].x - points[0].x > 0.1 or points[2].x - points[3].x > 0.1:
			draw_colored_polygon(points, Color(0.04, 0.01, 0.08, 0.85))
		x += step * 2.0
