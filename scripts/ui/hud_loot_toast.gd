class_name HudLootToast
extends Control
## CYPURRPUNK — LOOT TOASTS: "+ GOLDFISH  $40" slides in on the right of your screen whenever
## something goes into your backpack (picked up, bought, or robbed off a rival). Up to a few at
## once, newest at the bottom; each one holds, then fades away.
## Lives at scenes/ui/hud.tscn > HUD > Frame > LootToast. Fed by Feedback (scripts/feedback.gd).

## Seconds each toast stays (including the fade at the end).
@export var lifetime: float = 2.6
@export var fade_seconds: float = 0.5
## Seconds to slide in from the right edge.
@export var slide_seconds: float = 0.18
@export var max_toasts: int = 4
@export var row_height: float = 34.0
@export var row_width: float = 230.0
@export var font_size: int = 18
@export var text_color: Color = Color(0.85, 1, 1)
## Colour of the "$40" bit for loot worth cash.
@export var cash_color: Color = Color(1, 0.82, 0.2)

## [{icon (Texture2D), name, cash, age}]
var _toasts: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add(item_id: String, display_name: String, cash: int) -> void:
	# The same thing twice in a row (a stack of catnip)? Count it up instead of a new row.
	if not _toasts.is_empty() and _toasts[-1].id == item_id and _toasts[-1].age < lifetime - fade_seconds:
		_toasts[-1].count += 1
		_toasts[-1].age = minf(_toasts[-1].age, slide_seconds)
		_toasts[-1].bump = 1.0
		return
	_toasts.append({"id": item_id, "icon": HudStyle.item_icon(item_id), "name": display_name.to_upper(),
		"cash": cash, "age": 0.0, "count": 1, "bump": 0.0})
	while _toasts.size() > max_toasts:
		_toasts.pop_front()


func _process(delta: float) -> void:
	if _toasts.is_empty():
		return
	for toast in _toasts:
		toast.age += delta
		toast.bump = maxf(toast.bump - delta * 5.0, 0.0)
	_toasts = _toasts.filter(func(t): return t.age < lifetime)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var text_size := Hud.text_size(font_size)
	for i in _toasts.size():
		var toast: Dictionary = _toasts[i]
		var age: float = toast.age
		var slide := clampf(age / slide_seconds, 0.0, 1.0)
		slide = 1.0 - pow(1.0 - slide, 3.0)  # eases in
		var alpha := clampf((lifetime - age) / fade_seconds, 0.0, 1.0)
		# Bottom row = newest. Rows stack upward from the bottom of this box.
		var y := size.y - (_toasts.size() - i) * (row_height + 6.0)
		var x := size.x - row_width * slide + 30.0 * (1.0 - slide)
		var rect := Rect2(x, y, row_width, row_height)
		modulate_rect(rect, alpha, toast)
		var icon_box := Rect2(x + 6, y + 3, row_height - 6, row_height - 6)
		var icon_tint := Color(1, 1, 1, alpha)
		HudStyle.draw_icon(self, toast.icon, icon_box, icon_tint)
		var label: String = "+ " + toast.name + ("  x%d" % toast.count if toast.count > 1 else "")
		var base := y + row_height / 2.0 + text_size * 0.35
		var tint := text_color
		tint.a = alpha
		var text_x := x + row_height + 4.0
		var room := row_width - row_height - 10.0
		var cash_text := ""
		if toast.cash > 0:
			cash_text = "$%d" % (toast.cash * toast.count)
			room -= font.get_string_size(cash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x + 8.0
		draw_string_outline(font, Vector2(text_x, base), label, HORIZONTAL_ALIGNMENT_LEFT, room, text_size,
			Hud.outline(4), Color(0, 0, 0, alpha * 0.8))
		draw_string(font, Vector2(text_x, base), label, HORIZONTAL_ALIGNMENT_LEFT, room, text_size, tint)
		if cash_text != "":
			var gold := cash_color
			gold.a = alpha
			var cash_x := x + row_width - 6.0 - font.get_string_size(cash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
			draw_string(font, Vector2(cash_x, base), cash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, gold)


## The panel behind one toast (flashes brighter for a moment when it counts up).
func modulate_rect(rect: Rect2, alpha: float, toast: Dictionary) -> void:
	var style := HudStyle.current()
	var fill := style.panel_color
	fill.a *= alpha
	draw_rect(rect, fill)
	var edge := style.border_color.lerp(Color.WHITE, toast.bump)
	edge.a *= alpha
	var width := Hud.line(style.border_width)
	draw_rect(rect.grow(-width / 2.0), edge, false, width)
