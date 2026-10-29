extends HeldItem
## CATDIP — a one-paw tin you use up: click to take a dip and get a DOUBLE JUMP for a while
## (press Space again in mid-air). Same pattern as catnip.gd.

## Extra jumps you get in mid-air (1 = double jump, 2 = triple jump...).
@export var extra_jumps: int = 1
## How long it lasts (seconds).
@export var duration: float = 20.0


func use_tick(_trigger_down: bool, trigger_pressed: bool, _delta: float) -> void:
	if trigger_pressed:
		quick_use(holder)
		consume()


## Dipped from a QUICK USE slot (key 1 / 2), or from the paw above.
func quick_use(cat: CatPlayer) -> void:
	cat.start_double_jump(extra_jumps, duration)


func hud_text() -> String:
	return "CATDIP (click for double jump)"
