extends HeldItem
## CATNIP — a one-paw item you use up: click to sniff it for a burst of super zoomies.
## A good template for any "use it once" item (health, shield, a bomb...).

## Speed multiplier while it lasts (1.6 = 60% faster).
@export var speed_multiplier: float = 1.6
## How long it lasts (seconds).
@export var duration: float = 8.0


func use_tick(_trigger_down: bool, trigger_pressed: bool, _delta: float) -> void:
	if trigger_pressed:
		holder.start_boost(speed_multiplier, duration)
		consume()


func hud_text() -> String:
	return "CATNIP (click to sniff)"
