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


func _draw() -> void:
	var centre := size / 2.0
	# Dark edge first (a slightly bigger copy), then the coloured lines on top.
	if outline > 0.0:
		_draw_cross(centre, outline_color, outline)
	_draw_cross(centre, color, 0.0)


func _draw_cross(centre: Vector2, tint: Color, grow: float) -> void:
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var from: Vector2 = centre + direction * (gap - grow)
		var to: Vector2 = centre + direction * (gap + line_length + grow)
		draw_line(from, to, tint, thickness + grow * 2.0, true)
	if dot_size > 0.0:
		draw_circle(centre, dot_size / 2.0 + grow, tint, true, -1.0, true)
