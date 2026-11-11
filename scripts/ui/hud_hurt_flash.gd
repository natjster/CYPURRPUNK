class_name HudHurtFlash
extends Control
## CYPURRPUNK — the red edges of your screen: they FLASH when you get hurt (bigger hit = stronger)
## and slowly PULSE while your health is low, so you know to back off and heal.
## Lives at scenes/ui/hud.tscn > HUD > Frame > HurtFlash (first child, so it sits under the HUD).
## Fired by Feedback.hurt (scripts/feedback.gd); the low-health pulse watches CatHealth by itself.

@export var color: Color = Color(0.95, 0.05, 0.12)
## How far in the red reaches from each edge (fraction of the screen's height).
@export var edge_size: float = 0.28
## Strongest flash (0..1 see-through), reached by a hit of "full_flash_damage" or more.
@export var max_flash: float = 0.8
@export var full_flash_damage: int = 35
## Seconds the hurt flash takes to fade.
@export var fade_seconds: float = 0.45
## Below this much health (fraction of max), the edges pulse.
@export var low_health: float = 0.3
## How strong the low-health pulse gets, and how fast it beats (per second).
@export var low_pulse: float = 0.4
@export var pulse_speed: float = 1.6
## Bands drawn per edge (more = smoother fade, a few = chunky PS1 steps).
@export var bands: int = 6

var _flash: float = 0.0
var _pulse_time: float = 0.0
var _low: float = 0.0
## Something was drawn last frame (so one more redraw clears it).
var _was_drawn: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Got hurt for "amount": flash.
func flash(amount: int) -> void:
	_flash = maxf(_flash, max_flash * clampf(float(amount) / full_flash_damage, 0.35, 1.0))


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * max_flash / maxf(fade_seconds, 0.01), 0.0)
	_low = 0.0
	var health := _health_fraction()
	if health > 0.0 and health < low_health:
		_pulse_time += delta
		var beat := 0.5 + 0.5 * sin(_pulse_time * TAU * pulse_speed)
		# Lower health = stronger pulse.
		_low = low_pulse * (0.35 + 0.65 * beat) * (1.0 - health / low_health * 0.6)
	else:
		_pulse_time = 0.0
	if _flash > 0.0 or _low > 0.0 or _was_drawn:
		queue_redraw()


## 0..1 health of this HUD's player (0 when there is nobody, or they are downed / knocked out:
## the DOWNED screen says enough then).
func _health_fraction() -> float:
	var hud := owner as Hud
	if hud == null or Game.instance == null or CatHealth.instance == null or not hud.in_game:
		return 0.0
	var player_id := PlayerId.make(multiplayer.get_unique_id(), hud.seat)
	if Game.instance.cat_for(player_id) == null or CatHealth.instance.is_down(player_id):
		return 0.0
	return float(CatHealth.instance.get_health(player_id)) / maxf(CatHealth.instance.max_health_for(player_id), 1.0)


func _draw() -> void:
	var strength := maxf(_flash, _low)
	_was_drawn = strength > 0.0
	if strength <= 0.0:
		return
	var depth := size.y * edge_size
	for i in bands:
		var inset := depth * float(i) / bands
		var thick := depth / bands
		var tint := color
		tint.a = strength * pow(1.0 - float(i) / bands, 1.5)
		draw_rect(Rect2(0, inset, size.x, thick), tint)  # top
		draw_rect(Rect2(0, size.y - inset - thick, size.x, thick), tint)  # bottom
		draw_rect(Rect2(inset, 0, thick, size.y), tint)  # left
		draw_rect(Rect2(size.x - inset - thick, 0, thick, size.y), tint)  # right
