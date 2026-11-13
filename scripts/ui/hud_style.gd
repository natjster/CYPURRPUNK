class_name HudStyle
extends Resource
## CYPURRPUNK — the shared OCEAN-BLUE UI STYLE: one set of colours every new HUD / menu panel uses
## (the weapon box bottom-left, the buff badges top-left; later the inventory, shop and workbench).
##
## The settings live in ONE file: res://ui/hud_style.tres. To retune the look, double-click it in
## the FileSystem dock (ui > hud_style.tres) and change the colours in the Inspector, then press
## Ctrl+S. Every piece that uses it picks the change up next time the game starts.
##
## How scripts use it (all static, call on the class):
##   var style := HudStyle.current()                the settings
##   HudStyle.draw_panel(self, rect)               a translucent ocean-blue box with a bright edge
##   HudStyle.item_icon("pistol")                  the white side-profile picture of an item
##   HudStyle.status_icon("catnip")                a buff / debuff badge picture
##   HudStyle.npc_portrait("don_catleone")         a coloured NPC portrait
##   HudStyle.draw_icon(self, texture, box, color) an icon fitted into a box (only its visible part)
##
## The icons are made by the icon tool (tools/cypurr_icons.py, SETUP_GUIDE section 20): white
## pictures, so any colour can be painted on them with `color` / `modulate`.

const PATH := "res://ui/hud_style.tres"

## How a gun's colour travels from cool_color to hot_color as it heats up (heat_blend below):
##   VIOLET_SWEEP  ocean blue -> violet -> hot pink -> red (round the colour wheel: always vivid)
##   THERMAL       ocean blue -> cyan -> yellow -> orange -> red (like a thermal camera)
##   STRAIGHT      a plain mix of the two colours (goes a bit grey in the middle)
enum HeatBlend { VIOLET_SWEEP, THERMAL, STRAIGHT }

@export_group("Panels")
## Inside of every box: translucent deep ocean blue.
@export var panel_color: Color = Color(0.03, 0.14, 0.24, 0.72)
## Edge / frame of every box: bright ocean cyan-blue.
@export var border_color: Color = Color(0.22, 0.72, 0.98, 0.88)
## An empty slot's edge (a quick-use slot with nothing in it).
@export var faint_border_color: Color = Color(0.22, 0.72, 0.98, 0.3)
## Edge thickness (HUD units; the screen is 720 tall). The PS1 look thickens thin lines itself.
@export var border_width: float = 2.0
## Length of the brighter corner brackets on each box (0 = none).
@export var corner_length: float = 10.0
## Small words on panels (key names, counts, weapon names).
@export var text_color: Color = Color(0.78, 0.94, 1.0, 0.95)

@export_group("Weapons")
## A cool gun's picture: translucent ocean blue.
@export var cool_color: Color = Color(0.28, 0.78, 1.0, 0.82)
## A fully heated gun: glowing red.
@export var hot_color: Color = Color(1.0, 0.18, 0.14, 0.95)
## Which colours a gun passes through on the way from cool to hot (see HeatBlend at the top).
@export var heat_blend: HeatBlend = HeatBlend.VIOLET_SWEEP
## How long a gun stays blue as it warms up: 1 = evenly, higher = stays blue longer, then rushes to red.
@export_range(0.5, 3.0, 0.1) var heat_curve: float = 1.3
## OVERHEATED: the picture flashes between hot_color and this, this many times a second.
@export var overheat_flash_color: Color = Color(1.0, 0.85, 0.75, 1.0)
@export var overheat_flashes_per_second: float = 4.0

@export_group("Buffs and debuffs")
## A good effect's badge (catnip, catdip).
@export var buff_color: Color = Color(0.35, 0.9, 1.0, 0.95)
## A bad effect's badge (sticky paws): amber.
@export var debuff_color: Color = Color(1.0, 0.72, 0.2, 0.95)
## The draining timer fill inside a badge (drawn in the badge's colour at this opacity).
@export_range(0.0, 1.0) var timer_fill_opacity: float = 0.35
## Under this many seconds left the badge pulses.
@export var ending_soon_seconds: float = 1.0

static var _current: HudStyle = null
static var _textures: Dictionary = {}   # path -> Texture2D (or null if missing)
static var _used_rects: Dictionary = {}  # path -> Rect2 of the picture's visible pixels


## The style settings (loaded once from res://ui/hud_style.tres; built-in defaults if it's missing).
static func current() -> HudStyle:
	if _current == null:
		_current = load(PATH) as HudStyle if ResourceLoader.exists(PATH) else null
		if _current == null:
			_current = HudStyle.new()
	return _current


## The colour of a gun at this heat (0 = cool_color, 1 = hot_color), the heat_blend way.
func heat_color(heat: float) -> Color:
	var t := pow(clampf(heat, 0.0, 1.0), heat_curve)
	if heat_blend == HeatBlend.STRAIGHT:
		return cool_color.lerp(hot_color, t)
	var from_hue := cool_color.h
	var to_hue := hot_color.h
	if heat_blend == HeatBlend.VIOLET_SWEEP and to_hue < from_hue:
		to_hue += 1.0  # "up" the wheel: blue -> violet -> pink -> red
	elif heat_blend == HeatBlend.THERMAL and to_hue > from_hue:
		to_hue -= 1.0  # "down" the wheel: blue -> cyan -> yellow -> orange -> red
	return Color.from_hsv(fposmod(lerpf(from_hue, to_hue, t), 1.0), lerpf(cool_color.s, hot_color.s, t),
		lerpf(cool_color.v, hot_color.v, t), lerpf(cool_color.a, hot_color.a, t))


## A translucent ocean-blue box with a bright edge and corner brackets. faint = an empty slot.
## alpha = fade the whole box (1 = normal, 0 = gone), e.g. while the words in it fade out.
static func draw_panel(canvas: CanvasItem, rect: Rect2, faint: bool = false, edge: Color = Color(0, 0, 0, 0), alpha: float = 1.0) -> void:
	var style := current()
	var fill := style.panel_color
	if faint:
		fill.a *= 0.5
	fill.a *= alpha
	canvas.draw_rect(rect, fill)
	var border := edge if edge.a > 0.0 else (style.faint_border_color if faint else style.border_color)
	border.a *= alpha
	var width := Hud.line(style.border_width)
	canvas.draw_rect(rect.grow(-width / 2.0), border, false, width)
	if not faint:
		draw_corners(canvas, rect, border, alpha)


## Just the brighter corner brackets of a panel (the talk box's PanelContainer draws its own box
## from ui/hud_theme.tres, then adds these on top so it matches the rest of the HUD).
static func draw_corners(canvas: CanvasItem, rect: Rect2, edge: Color = Color(0, 0, 0, 0), alpha: float = 1.0) -> void:
	var style := current()
	if style.corner_length <= 0.0:
		return
	var bright := (edge if edge.a > 0.0 else style.border_color).lightened(0.35)
	bright.a = alpha
	var c := minf(style.corner_length, minf(rect.size.x, rect.size.y) / 3.0)
	var w := Hud.line(style.border_width * 1.5)
	var p := rect.position
	var q := rect.end
	for corner in [[p, Vector2(1, 1)], [Vector2(q.x, p.y), Vector2(-1, 1)], [Vector2(p.x, q.y), Vector2(1, -1)], [q, Vector2(-1, -1)]]:
		var at: Vector2 = corner[0] + corner[1] * w / 2.0
		canvas.draw_line(at, at + Vector2(c * corner[1].x, 0), bright, w)
		canvas.draw_line(at, at + Vector2(0, c * corner[1].y), bright, w)


## Item side-profile icon (ui/icons/items/<id>.png), or null if there isn't one yet.
static func item_icon(item_id: String) -> Texture2D:
	return _texture("res://ui/icons/items/%s.png" % item_id)


## Buff / debuff badge picture (ui/icons/status/<id>.png), or null.
static func status_icon(status_id: String) -> Texture2D:
	return _texture("res://ui/icons/status/%s.png" % status_id)


## NPC portrait (ui/icons/npcs/<id>.png), or null.
static func npc_portrait(npc_id: String) -> Texture2D:
	return _texture("res://ui/icons/npcs/%s.png" % npc_id)


static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[path]


## The part of an icon that isn't see-through (the item pictures sit in a square with empty space
## round them; a gun is long and thin). Worked out once per picture.
static func used_rect(texture: Texture2D) -> Rect2:
	var path := texture.resource_path
	if not _used_rects.has(path):
		var image := texture.get_image()
		var rect := Rect2(Vector2.ZERO, texture.get_size())
		if image != null:
			if image.is_compressed():
				image.decompress()
			var used := image.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				rect = Rect2(used)
		_used_rects[path] = rect
	return _used_rects[path]


## Draw an icon's visible part as big as fits inside box (keeping its shape), painted in color.
## Returns where it ended up.
static func draw_icon(canvas: CanvasItem, texture: Texture2D, box: Rect2, color: Color) -> Rect2:
	if texture == null:
		return Rect2()
	var src := used_rect(texture)
	var fit := minf(box.size.x / src.size.x, box.size.y / src.size.y)
	var size := src.size * fit
	var dest := Rect2(box.get_center() - size / 2.0, size)
	canvas.draw_texture_rect_region(texture, dest, src, color)
	return dest
