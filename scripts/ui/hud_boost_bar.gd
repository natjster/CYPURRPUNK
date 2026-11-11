class_name HudBoostBar
extends Control
## CYPURRPUNK — the AFTERBURNER BOOST bar, bottom-left of the HUD (only while YOU are driving).
## Lives at scenes/ui/hud.tscn > HUD > Frame > Middle > Boost. Drawn in code (_draw), so it is
## sharp at any resolution. hud.gd (_update_boost) feeds it every frame with set_boost().
##
## What you see:
##   [flame]  BOOST  [Shift]
##            [██████|██████|███░░░]   <- ONE bar that is always the same width; it is SPLIT into
##                                        one piece per charge (1 to start, 2 / 3 with the
##                                        AFTERBURNER upgrade: scripts/car/car_boost.gd).
##   - A full piece = a charge ready (bright orange).
##   - The next empty piece fills up slowly while that charge recharges.
##   - Pieces still waiting their turn are dark.
##   - While the boost is firing the whole bar flickers white-hot.
##
## Sitting: hud.gd keeps it just ABOVE the guns box (Held) when that's showing, and slides it
## down into the corner when it isn't. Move it left / right or resize it in hud.tscn (select
## Boost, change Layout > Transform). Colours and shape are below (Inspector, with Boost selected).

@export_group("Colours")
## A ready charge.
@export var ready_color: Color = Color(1.0, 0.5, 0.08)
## The charge that's filling back up.
@export var charging_color: Color = Color(0.75, 0.32, 0.06)
## The bar's empty background.
@export var empty_color: Color = Color(0.05, 0.03, 0.08, 0.85)
## The flicker while the boost is firing.
@export var firing_color: Color = Color(1.0, 0.92, 0.55)

@export_group("Shape")
## How thick the bar is (HUD units; the screen is 720 tall).
@export var bar_thickness: float = 14.0
## The gap between two pieces of the bar.
@export var split_gap: float = 6.0
## Size of the flame picture on the left.
@export var icon_size: float = 34.0
## Size of the "BOOST" word and the key hint.
@export var label_size: int = 15

var seat: int = 0
var _max: int = 0
var _charges: int = 0
var _recharge: float = 0.0
var _firing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## hud.gd, every frame: max charges (0 = hide), charges ready, how far the next one has
## recharged (0..1) and whether the boost is firing right now.
func set_boost(max_charges: int, charges: int, recharge: float, firing: bool) -> void:
	visible = max_charges > 0
	_max = max_charges
	_charges = clampi(charges, 0, max_charges)
	_recharge = clampf(recharge, 0.0, 1.0)
	_firing = firing
	queue_redraw()


func _draw() -> void:
	if _max <= 0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	HudStyle.draw_panel(self, rect)
	var pad := 8.0
	# The flame on the left (the same picture as the old badge: ui/icons/status/boost.png).
	var icon_box := Rect2(pad, (size.y - icon_size) / 2.0, icon_size, icon_size)
	var icon_tint := firing_color if _firing else (ready_color if _charges > 0 else ready_color.darkened(0.55))
	HudStyle.draw_icon(self, HudStyle.status_icon("boost"), icon_box, icon_tint)
	var left := icon_box.end.x + pad
	var width := size.x - left - pad
	# "BOOST" and the key to press, above the bar.
	var font := get_theme_default_font()
	var text_size := Hud.text_size(label_size)
	var text_y := pad + text_size * 0.85
	draw_string_outline(font, Vector2(left, text_y), "BOOST", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Hud.outline(4), Color.BLACK)
	draw_string(font, Vector2(left, text_y), "BOOST", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, ready_color.lightened(0.3))
	var key := "[%s]" % Hud.key_for("boost", seat)
	draw_string_outline(font, Vector2(left, text_y), key, HORIZONTAL_ALIGNMENT_RIGHT, width, text_size, Hud.outline(4), Color.BLACK)
	draw_string(font, Vector2(left, text_y), key, HORIZONTAL_ALIGNMENT_RIGHT, width, text_size, Color(0.85, 0.9, 1.0))
	# The bar: always the same width, split into one piece per charge.
	var bar_top := size.y - pad - bar_thickness
	var gap := Hud.line(split_gap)
	var piece := (width - gap * (_max - 1)) / float(_max)
	var flicker := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 40.0)
	for i in _max:
		var box := Rect2(left + i * (piece + gap), bar_top, piece, bar_thickness)
		draw_rect(box, empty_color)
		if i < _charges:
			draw_rect(box, ready_color.lerp(firing_color, flicker) if _firing else ready_color)
		elif i == _charges:
			draw_rect(Rect2(box.position, Vector2(piece * _recharge, bar_thickness)), charging_color)
		draw_rect(box.grow(-Hud.line(1.0) / 2.0), Color(0, 0, 0, 0.8), false, Hud.line(1.0))
