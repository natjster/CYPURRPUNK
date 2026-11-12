class_name HudCarPointer
extends Control
## CYPURRPUNK — the little WHERE'S MY CAR pointer, bottom-left of the HUD, just above the gun box.
## Lives at scenes/ui/hud.tscn > HUD > Frame > Middle > CarPointer. Drawn in code (_draw).
## hud.gd (_update_car_pointer) feeds it every frame with point_at() / hide_pointer().
##
## What you see (small and quiet on purpose):
##      ➤ CAR 42m
##   - The arrow turns to point at YOUR gang's getaway car, the way your camera faces
##     (straight up = dead ahead, pointing down = behind you).
##   - Hidden while you're IN a car, down in the sewers, or while the car is a wreck.
##   - Very close (under hide_within metres) it fades away: you can see the car anyway.
##
## Sitting: hud.gd keeps it just ABOVE the gun box (Held) when that's showing, and slides it
## down into the corner when it isn't. Colours / sizes below (Inspector, with CarPointer selected).

@export_group("Look")
## The arrow + words colour (soft ocean blue, like the rest of the HUD).
@export var color: Color = Color(0.55, 0.9, 1.0, 0.85)
## The word in front of the distance. Empty = just the distance.
@export var label: String = "CAR"
## How big the arrow is (HUD units; the screen is 720 tall).
@export var arrow_size: float = 13.0
## Size of the words.
@export var font_size: int = 15
## Show the distance in metres after the word.
@export var show_distance: bool = true

@export_group("Feel")
## Closer than this (metres) = the pointer fades out (the car's right there).
@export var hide_within: float = 6.0
## How fast the arrow swings to its new direction (higher = snappier).
@export var turn_speed: float = 14.0
## How fast it fades in / out.
@export var fade_speed: float = 6.0

## Screen angle of the car (radians, 0 = straight up / ahead, clockwise).
var _angle: float = 0.0
var _shown_angle: float = 0.0
var _metres: int = 0
var _wanted: bool = false
var _alpha: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


## hud.gd, every frame: angle (0 = ahead, clockwise) and how far the car is (metres).
func point_at(angle: float, metres: float) -> void:
	_angle = angle
	_metres = roundi(metres)
	_wanted = metres > hide_within


## hud.gd: no car to point at right now (in a car, in the sewers, wrecked...).
func hide_pointer() -> void:
	_wanted = false


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0 if _wanted else 0.0, fade_speed * delta)
	modulate.a = _alpha
	visible = _alpha > 0.0
	if not visible:
		_shown_angle = _angle  # (snap, so it doesn't swing in from the old direction)
		return
	# Turn the short way round.
	_shown_angle += wrapf(_angle - _shown_angle, -PI, PI) * (1.0 - exp(-turn_speed * delta))
	queue_redraw()


func _draw() -> void:
	var s := arrow_size
	var centre := Vector2(s, size.y / 2.0)
	# A slim arrowhead with a notch at the back (an outline first so it reads on bright streets).
	var points := PackedVector2Array([Vector2(0, -s), Vector2(s * 0.7, s * 0.75), Vector2(0, s * 0.35), Vector2(-s * 0.7, s * 0.75)])
	var turned := PackedVector2Array()
	for p in points:
		turned.append(centre + p.rotated(_shown_angle))
	var outline := turned.duplicate()
	outline.append(turned[0])
	draw_polyline(outline, Color(0, 0, 0, 0.8), Hud.line(3.0), true)
	draw_colored_polygon(turned, color)
	# "CAR 42m"
	var text := label
	if show_distance:
		text = ("%s %dm" % [label, _metres]).strip_edges()
	if text == "":
		return
	var font := get_theme_default_font()
	var text_size := Hud.text_size(font_size)
	var at := Vector2(s * 2.0 + 6.0, size.y / 2.0 + text_size * 0.35)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Hud.outline(4), Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, color)
