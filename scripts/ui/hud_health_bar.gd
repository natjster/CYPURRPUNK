class_name HudHealthBar
extends Control
## CYPURRPUNK — YOUR health bar, top-left of the HUD (Cyberpunk-style).
## Lives at scenes/ui/hud.tscn > HUD > Frame > Top > Health. Drawn in code (_draw), so it is
## sharp at any resolution. scripts/cat_health.gd feeds it every frame with set_health().
##
## What you see:
##   [ 87 ]  ██████████░░░   <- the number box, then a thin plain bar
##   - RED fill = your health right now.
##   - When you get hurt, the bit you lost turns WHITE-YELLOW and drains away after a moment
##     (the "chip"), so you can see how big the hit was.
##   - When you heal, the new bit flashes CYAN as it fills in.
##   - Below low_health (30%) the bar pulses and the number turns bright.
##   - 0 HP: "DOWNED" across the bar while a friend can still revive you, then "KNOCKED OUT".
##
## Move / resize it in hud.tscn like any Control (select Health, drag it, or change Layout >
## Transform). Colours and timings are below (Inspector, with Health selected).

@export_group("Colours")
@export var fill_color: Color = Color(1.0, 0.27, 0.32)
## The bit you just lost (drains away after chip_delay).
@export var chip_color: Color = Color(1.0, 0.93, 0.55)
## The bit you just healed.
@export var heal_color: Color = Color(0.35, 1.0, 1.0)
@export var back_color: Color = Color(0.12, 0.02, 0.06, 0.8)
@export var frame_color: Color = Color(1.0, 0.35, 0.45, 0.9)

@export_group("Shape")
## How thick the bar is (HUD units; the screen is 720 tall).
@export var bar_thickness: float = 9.0
## Width of the number box on the left.
@export var number_box_width: float = 64.0
@export var number_font_size: int = 26

@export_group("Feel")
## Seconds the white-yellow "chip" waits before it drains.
@export var chip_delay: float = 0.45
## How fast the chip drains / a heal fills (fraction of the whole bar per second).
@export var drain_speed: float = 0.9
## Below this fraction of health the bar pulses.
@export var low_health: float = 0.3

## True while this player is DOWNED (waiting for a revive): the bar says "DOWNED" instead of
## "KNOCKED OUT". Set every frame by cat_health.gd.
var downed: bool = false
var _hp: float = 100.0
var _max: float = 100.0
## What's drawn: the red fill (catches up with _hp when healing) and the chip (trails when hurt).
var _shown: float = 1.0
var _chip: float = 1.0
var _chip_wait: float = 0.0
var _hurt_flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called every frame by cat_health.gd with this player's health.
func set_health(hp: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		return
	if hp < _hp:  # got hurt: hold the chip where it was for a moment
		_chip_wait = chip_delay
		_hurt_flash = 0.25
	_hp = hp
	_max = max_hp
	# Hurt: the red drops the same frame the number does (the chip stays behind to drain).
	_shown = minf(_shown, clampf(_hp / _max, 0.0, 1.0))
	queue_redraw()


func _process(delta: float) -> void:
	var target := clampf(_hp / _max, 0.0, 1.0)
	# Hurt: the red jumps down straight away, the chip waits, then drains down to it.
	if target < _shown:
		_shown = target
	# Healed: the red fills up smoothly (the cyan bit shows what's coming).
	elif target > _shown:
		_shown = minf(_shown + drain_speed * delta, target)
	_chip_wait = maxf(_chip_wait - delta, 0.0)
	if _chip < _shown:
		_chip = _shown
	elif _chip_wait <= 0.0:
		_chip = maxf(_chip - drain_speed * delta, _shown)
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var h := size.y
	var bar_left := number_box_width + 8.0
	var bar_w := size.x - bar_left
	var bar_top := (h - bar_thickness) * 0.5
	var fraction := clampf(_hp / _max, 0.0, 1.0)
	var low := fraction <= low_health and _hp > 0.0
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 10.0) if low else 1.0

	# --- The number box: [ 87 ] ---
	var box := Rect2(0, 0, number_box_width, h)
	draw_rect(box, back_color)
	draw_rect(box, Color.WHITE if _hurt_flash > 0.0 else frame_color, false, 2.0)
	var number := str(ceili(_hp))
	var number_color := Color.WHITE if _hurt_flash > 0.0 else (fill_color.lerp(Color.WHITE, 0.5 * pulse) if low else fill_color)
	var text_size := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_font_size)
	var text_pos := Vector2((number_box_width - text_size.x) * 0.5, (h + text_size.y) * 0.5 - font.get_descent(number_font_size))
	draw_string_outline(font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_font_size, 6, Color(0.04, 0.01, 0.08))
	draw_string(font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_font_size, number_color)

	# --- The bar: a plain rectangle. Dark back, red fill, then the chip (just lost) and heal bits ---
	draw_rect(Rect2(bar_left, bar_top, bar_w, bar_thickness), back_color)
	draw_rect(Rect2(bar_left, bar_top, bar_w * _shown, bar_thickness), fill_color * Color(1, 1, 1, lerpf(0.55, 1.0, pulse)))
	if _chip > _shown:
		draw_rect(Rect2(bar_left + bar_w * _shown, bar_top, bar_w * (_chip - _shown), bar_thickness), chip_color)
	if fraction > _shown:
		draw_rect(Rect2(bar_left + bar_w * _shown, bar_top, bar_w * (fraction - _shown), bar_thickness), heal_color)
	draw_rect(Rect2(bar_left, bar_top, bar_w, bar_thickness), Color.WHITE if _hurt_flash > 0.0 else frame_color, false, 1.0)

	if _hp <= 0.0:
		var ko := "DOWNED" if downed else "KNOCKED OUT"
		var ko_size := 18
		var ko_w := font.get_string_size(ko, HORIZONTAL_ALIGNMENT_LEFT, -1, ko_size).x
		var ko_pos := Vector2(bar_left + (bar_w - ko_w) * 0.5, bar_top - 4.0)
		draw_string_outline(font, ko_pos, ko, HORIZONTAL_ALIGNMENT_LEFT, -1, ko_size, 6, Color(0.04, 0.01, 0.08))
		draw_string(font, ko_pos, ko, HORIZONTAL_ALIGNMENT_LEFT, -1, ko_size, Color.WHITE)
