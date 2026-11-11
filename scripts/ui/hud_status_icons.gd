class_name HudStatusIcons
extends Control
## CYPURRPUNK — BUFF / DEBUFF BADGES, top-left, right of your health bar.
## Lives at scenes/ui/hud.tscn > HUD > Frame > Top > StatusIcons. Drawn in code in the shared
## ocean-blue style (scripts/ui/hud_style.gd, colours in ui/hud_style.tres).
##
##   [87] █████████░░░   [paw] [leaf] [tin]
##                        ^ one small badge per effect that's on right now:
##   STICKY PAWS (debuff, amber)  you stepped in LINT-TRAPPER glue: slow paws
##   CATNIP      (buff, blue)     speed boost
##   CATDIP      (buff, blue)     double jump
##  Each badge has a timer: a lighter fill that drains downwards as the effect runs out, and the
##  badge pulses in its last second.
##
## scripts/ui/hud.gd feeds it every frame from this player's cat (set_effects). To add a new
## effect: give CatPlayer a "<name>_fraction()" getter, make a picture with the icon tool
## (tools/cypurr_icons.py STATUS), and add a line in hud.gd _update_status.

@export_group("Shape")
## Each badge's size (HUD units; the screen is 720 tall).
@export var badge_size: float = 40.0
@export var gap: float = 6.0
## Empty space inside a badge round its picture.
@export var padding: float = 6.0

@export_group("Feel")
## How fast an ending badge pulses (times a second).
@export var pulse_per_second: float = 5.0

## What's shown: [{"id", "fraction" (1 = full .. 0 = over), "seconds_left", "debuff"}].
var _effects: Array = []
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called every frame by hud.gd with the effects on this player's cat right now.
func set_effects(effects: Array) -> void:
	_effects = effects
	visible = not effects.is_empty()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if Settings.modern_ui else CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


func _draw() -> void:
	var style := HudStyle.current()
	var x := 0.0
	for effect in _effects:
		var rect := Rect2(Vector2(x, 0), Vector2(badge_size, badge_size))
		_draw_badge(style, rect, effect)
		x += badge_size + gap


func _draw_badge(style: HudStyle, rect: Rect2, effect: Dictionary) -> void:
	var tint := style.debuff_color if effect.debuff else style.buff_color
	var ending: bool = effect.seconds_left < style.ending_soon_seconds
	var pulse := 0.5 + 0.5 * sin(_time * TAU * pulse_per_second) if ending else 0.0
	# Box, then the draining timer fill (from the bottom), then the picture, then the edge.
	draw_rect(rect, style.panel_color)
	var fill := tint
	fill.a = style.timer_fill_opacity * (1.0 + pulse * 0.6)
	var height := rect.size.y * clampf(effect.fraction, 0.0, 1.0)
	draw_rect(Rect2(rect.position.x, rect.end.y - height, rect.size.x, height), fill)
	var picture := tint.lerp(Color.WHITE, pulse * 0.5)
	if effect.get("dim", false):
		picture.a *= 0.3  # not ready yet (a recharging BOOST charge: hud.gd _update_status)
	HudStyle.draw_icon(self, HudStyle.status_icon(effect.id), rect.grow(-padding), picture)
	var edge := tint
	edge.a = lerpf(0.85, 1.0, pulse)
	var width := Hud.line(style.border_width)
	draw_rect(rect.grow(-width / 2.0), edge, false, width)
