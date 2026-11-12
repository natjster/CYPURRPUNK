@tool
class_name HudStyleBox
extends StyleBox
## CYPURRPUNK — a box in the HUD's OCEAN-BLUE look (translucent fill, thin bright edge and the brighter
## CORNER BRACKETS), usable anywhere Godot wants a StyleBox: menu buttons, panels, text boxes.
##
## The menus' theme (res://ui/menu_theme.tres) uses these for its buttons and panels, so the start menu,
## MY CAT, SETTINGS and PAUSE look like the in-game HUD (weapon box, shop, inventory).
##
## To retune: double-click ui/menu_theme.tres in the FileSystem dock, open Button (or Panel) > Styles,
## click a style and change the colours below in the Inspector, then Ctrl+S.
## (The menus are laid out on a 320 x 240 screen, so 1 here = 3 of the HUD's units.)

## Inside of the box. Alpha 0 = no fill (just the edge).
@export var fill_color: Color = Color(0.03, 0.14, 0.24, 0.72):
	set(value):
		fill_color = value
		emit_changed()
## The thin edge round the box. Alpha 0 = no edge.
@export var border_color: Color = Color(0.22, 0.72, 0.98, 0.88):
	set(value):
		border_color = value
		emit_changed()
## Edge thickness in menu pixels.
@export var border_width: float = 1.0:
	set(value):
		border_width = value
		emit_changed()
## Length of the bright corner brackets (0 = none).
@export var corner_length: float = 4.0:
	set(value):
		corner_length = value
		emit_changed()
## Colour of the corner brackets. Alpha 0 = the edge colour made brighter (like the HUD).
@export var corner_color: Color = Color(0, 0, 0, 0):
	set(value):
		corner_color = value
		emit_changed()
## A soft glow round the outside of the box (alpha 0 = none). Nice on the highlighted button.
@export var glow_color: Color = Color(0, 0, 0, 0):
	set(value):
		glow_color = value
		emit_changed()


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	# Soft glow: two faint rings outside the box.
	if glow_color.a > 0.0:
		for i in 2:
			var ring := glow_color
			ring.a *= 0.5 / (i + 1)
			var r := rect.grow(1.0 + i)
			_outline(to_canvas_item, r, ring, 1.0)
	if fill_color.a > 0.0:
		rs.canvas_item_add_rect(to_canvas_item, rect, fill_color)
	if border_color.a > 0.0 and border_width > 0.0:
		_outline(to_canvas_item, rect, border_color, border_width)
	if corner_length > 0.0:
		var bright := corner_color if corner_color.a > 0.0 else border_color.lightened(0.35)
		if corner_color.a <= 0.0:
			bright.a = maxf(border_color.a, 0.9) if border_color.a > 0.0 else 0.0
		if bright.a > 0.0:
			var c := minf(corner_length, minf(rect.size.x, rect.size.y) / 3.0)
			var w := maxf(border_width, 1.0)
			var p := rect.position
			var q := rect.end
			# Each corner = a short bar along the top/bottom + one down/up the side.
			for corner in [[p, Vector2(1, 1)], [Vector2(q.x, p.y), Vector2(-1, 1)], [Vector2(p.x, q.y), Vector2(1, -1)], [q, Vector2(-1, -1)]]:
				var at: Vector2 = corner[0]
				var d: Vector2 = corner[1]
				rs.canvas_item_add_rect(to_canvas_item, Rect2(at, Vector2(c * d.x, w * d.y)).abs(), bright)
				rs.canvas_item_add_rect(to_canvas_item, Rect2(at, Vector2(w * d.x, c * d.y)).abs(), bright)


## A hollow rectangle drawn as four filled strips (crisp at the menus' small pixel size).
func _outline(item: RID, r: Rect2, color: Color, w: float) -> void:
	var rs := RenderingServer
	rs.canvas_item_add_rect(item, Rect2(r.position, Vector2(r.size.x, w)), color)
	rs.canvas_item_add_rect(item, Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)), color)
	rs.canvas_item_add_rect(item, Rect2(Vector2(r.position.x, r.position.y + w), Vector2(w, r.size.y - w * 2)), color)
	rs.canvas_item_add_rect(item, Rect2(Vector2(r.end.x - w, r.position.y + w), Vector2(w, r.size.y - w * 2)), color)
