@tool
class_name HudCrosshair
extends Control
## CYPURRPUNK — the aiming crosshair on the HUD: four short lines with a gap in the middle
## and a dot, drawn sharp at full resolution. Sits in the exact middle of the game picture
## (that's where guns aim). Tweak the look in the Inspector (scenes/ui/hud.tscn > HUD >
## Frame > Middle > Crosshair); the editor shows your changes straight away.

## Colour of the lines and dot.
@export var color: Color = Color(0.4, 1, 1, 0.9):
	set(value):
		color = value
		queue_redraw()
## Length of each of the four lines (HUD units; the screen is 720 tall).
@export var line_length: float = 9.0:
	set(value):
		line_length = value
		queue_redraw()
## Empty space between the middle and where each line starts.
@export var gap: float = 5.0:
	set(value):
		gap = value
		queue_redraw()
## How thick the lines are.
@export var thickness: float = 2.5:
	set(value):
		thickness = value
		queue_redraw()
## Size of the dot in the middle (0 = no dot).
@export var dot_size: float = 2.5:
	set(value):
		dot_size = value
		queue_redraw()
## Dark edge around everything, so it shows up on bright neon too (0 = none).
@export var outline: float = 1.5:
	set(value):
		outline = value
		queue_redraw()
@export var outline_color: Color = Color(0.02, 0.01, 0.06, 0.8):
	set(value):
		outline_color = value
		queue_redraw()


## AIM DOWN SIGHTS (scripts/cat/cat_aim.gd): the gap shrinks to this share while fully aimed...
@export_range(0.0, 1.0) var ads_gap_scale: float = 0.45
## ...and each degree of spread BLOOM (firing fast) opens the gap by this much (HUD units).
@export var bloom_gap_per_degree: float = 3.0
## While aiming, four little corner brackets frame the crosshair (0 = none). Their size:
@export var ads_bracket_size: float = 16.0

var _aim: float = 0.0
var _bloom: float = 0.0


## Called every frame by the cat's Aim node: how far aimed in (0..1) and the spread bloom (degrees).
func set_aim(aim_amount: float, bloom_degrees: float) -> void:
	if absf(aim_amount - _aim) < 0.002 and absf(bloom_degrees - _bloom) < 0.02:
		return
	_aim = aim_amount
	_bloom = bloom_degrees
	queue_redraw()


func _current_gap() -> float:
	return gap * lerpf(1.0, ads_gap_scale, _aim) + _bloom * bloom_gap_per_degree


func _draw() -> void:
	var centre := size / 2.0
	if _aim > 0.05 and ads_bracket_size > 0.0:
		_draw_brackets(centre)
	# Dark edge first (a slightly bigger copy), then the coloured lines on top.
	if outline > 0.0 and Settings.modern_ui:  # (PS1 UI look: too thin to outline at 240 rows)
		_draw_cross(centre, outline_color, outline)
	_draw_cross(centre, color, 0.0)


func _draw_cross(centre: Vector2, tint: Color, grow: float) -> void:
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var g := _current_gap()
		var from: Vector2 = centre + direction * (g - grow)
		var to: Vector2 = centre + direction * (g + line_length + grow)
		draw_line(from, to, tint, thickness + grow * 2.0, true)
	if dot_size > 0.0:
		draw_circle(centre, dot_size / 2.0 + grow, tint, true, -1.0, true)


## The ADS brackets: four corners that slide in from further out as you aim, fading in.
func _draw_brackets(centre: Vector2) -> void:
	var reach := lerpf(ads_bracket_size * 3.0, ads_bracket_size * 1.6, _aim)
	var tint := Color(color, color.a * _aim * 0.8)
	var arm := ads_bracket_size * 0.5
	for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var tip: Vector2 = centre + corner * reach
		draw_line(tip, tip - Vector2(corner.x * arm, 0), tint, thickness * 0.8, true)
		draw_line(tip, tip - Vector2(0, corner.y * arm), tint, thickness * 0.8, true)
