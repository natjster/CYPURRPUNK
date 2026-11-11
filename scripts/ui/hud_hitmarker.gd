@tool
class_name HudHitmarker
extends Control
## CYPURRPUNK — the HITMARKER: four short diagonal lines that flash round the middle of your screen
## when your shot or swing lands. White = hit, yellow = critical hit, RED and bigger = you smashed
## it (kill confirm). Shows even without a gun (bat swings too).
## Lives at scenes/ui/hud.tscn > HUD > Frame > Middle > Hitmarker. Fired by Feedback (scripts/feedback.gd).

const HIT := 0
const CRIT := 1
const KILL := 2
const BOSS_KILL := 3

## Seconds a normal hitmarker stays (kills stay a bit longer, see kill_seconds).
@export var hit_seconds: float = 0.14
@export var kill_seconds: float = 0.35
## Empty space in the middle before each line starts (HUD units).
@export var gap: float = 9.0
## Length of each line.
@export var line_length: float = 9.0
## A kill makes the lines this much longer and further out.
@export var kill_grow: float = 1.6
@export var thickness: float = 2.5
@export var hit_color: Color = Color(1, 1, 1, 0.95)
@export var crit_color: Color = Color(1, 0.82, 0.2, 1)
@export var kill_color: Color = Color(1, 0.18, 0.25, 1)
@export var outline_color: Color = Color(0.02, 0.01, 0.06, 0.8)

var _kind: int = HIT
var _left: float = 0.0
var _total: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Flash it. A weaker kind never cuts short a stronger one still showing (a kill beats a hit).
func flash(kind: int) -> void:
	if _left > 0.0 and kind < _kind:
		return
	_kind = kind
	_total = kill_seconds if kind >= KILL else hit_seconds
	_left = _total
	queue_redraw()


func _process(delta: float) -> void:
	if _left > 0.0:
		_left = maxf(_left - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	if _left <= 0.0:
		return
	var fade := _left / _total
	var tint: Color = [hit_color, crit_color, kill_color, kill_color][_kind]
	tint.a *= clampf(fade * 1.5, 0.0, 1.0)
	var grow := kill_grow if _kind >= KILL else 1.0
	if _kind == BOSS_KILL:
		grow *= 1.4
	# Pop: starts a little further out and snaps in.
	var pop := 1.0 + 0.35 * fade * fade
	var inner := gap * grow * pop
	var outer := inner + line_length * grow
	var width := Hud.line(thickness * (1.3 if _kind >= KILL else 1.0))
	var centre := size / 2.0
	for direction in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var d: Vector2 = direction.normalized()
		if Settings.modern_ui:
			var edge := outline_color
			edge.a *= tint.a
			draw_line(centre + d * (inner - 1.5), centre + d * (outer + 1.5), edge, width + 3.0, true)
		draw_line(centre + d * inner, centre + d * outer, tint, width, true)
