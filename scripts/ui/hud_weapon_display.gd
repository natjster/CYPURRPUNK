class_name HudWeaponDisplay
extends Control
## CYPURRPUNK — WHAT'S IN YOUR PAWS, bottom-left of the HUD (replaces the old "R: PISTOL" text line).
## Lives at scenes/ui/hud.tscn > HUD > Frame > Middle > Held. Drawn in code (_draw) in the shared
## ocean-blue style (scripts/ui/hud_style.gd, colours in ui/hud_style.tres).
##
## What you see:
##   ┌──────────────────────┐ ┌───┐
##   │                      │ │[1]│  <- QUICK USE 1 (catnip x2)
##   │   [side view of gun] │ └───┘
##   │                      │ ┌───┐
##  (The gun's NAME and its fire KEY used to show in the box; both are off now: show_weapon_name /
##   show_fire_key in the Inspector turn them back on.)
##   └──────────────────────┘ │[2]│  <- QUICK USE 2 (an EMPTY slot isn't drawn: less clutter)
##                            └───┘
##  - The gun picture is translucent OCEAN BLUE when cool. As it heats up (weapon.heat 0 -> 1) it
##    slides through orange to RED. Overheated = it flashes and "OVERHEAT" shows above the box.
##  - Two one-paw guns (dual wield): two pictures, overlapping. The RIGHT paw's (fires with LMB / RT)
##    sits in front, the LEFT paw's (RMB / LT) peeks out behind it, up and to the left. Each one heats
##    up on its own.
##  - Nothing in your paws: the gun box goes away (the quick-use slots slide over).
##
## scripts/items/item_manager.gd feeds it every frame (show_loadout). Move / resize it in hud.tscn
## like any Control (it keeps to the bottom-left corner on every screen shape: anchors).

@export_group("Shape")
## The gun box (HUD units; the screen is 720 tall).
@export var weapon_box_size: Vector2 = Vector2(210, 92)
## Each quick-use square.
@export var quick_slot_size: float = 44.0
## Space between the boxes.
@export var gap: float = 8.0
## Empty space inside the gun box round the picture.
@export var padding: float = 10.0
## Dual wield: how far the back (left paw) picture is pushed up-left of the front one.
@export var dual_offset: Vector2 = Vector2(34, 20)
## Dual wield: how see-through the back picture is (1 = solid).
@export_range(0.0, 1.0) var back_opacity: float = 0.7

@export_group("Words")
## Show the gun's NAME (e.g. "PAW-PISTOL") in the top-left of the gun box. Off = just the picture.
@export var show_weapon_name: bool = false
## Show which button fires the gun (e.g. "LMB" / "RT") in the gun box corners. Off = hidden.
## (The quick-use squares still show their keys.)
@export var show_fire_key: bool = false
@export var name_font_size: int = 14
@export var key_font_size: int = 13
@export var overheat_font_size: int = 18
@export var count_font_size: int = 15

@export_group("Feel")
## How fast the colour follows the gun's heat (higher = snappier).
@export var heat_follow_speed: float = 10.0

@export_group("Slam Meter")
## THE SLAM METER (the FROZEN TUNA): a bar along the bottom of the gun box that fills while you HOLD
## the button. How tall it is (HUD units), its colour while filling, and when it's full (it flashes).
@export var charge_bar_height: float = 7.0
@export var charge_color: Color = Color(0.3, 0.75, 1.0, 0.9)
@export var charge_ready_color: Color = Color(1.0, 0.85, 0.2, 1.0)
## The words over the box while you HOLD to charge the slam.
@export var slam_ready_text: String = "CHARGING..."

## [right paw, left paw] (or just [paw] for a two-paw gun): {"id", "name", "heat", "overheated",
## "heats" (false = never overheats), "key"}. Set by show_loadout.
var _paws: Array = []
## The two quick-use slots: {"id" ("" = empty), "count", "key"}.
var _quick: Array = []
## Heat as drawn per paw (follows the real heat smoothly).
var _shown_heat: Array = [0.0, 0.0]
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called every frame by item_manager.gd. paws / quick: see _paws / _quick above. Empty paws and
## empty quick slots = the whole display hides.
func show_loadout(paws: Array, quick: Array) -> void:
	_paws = paws
	_quick = quick
	var anything := not paws.is_empty()
	for slot in quick:
		anything = anything or slot.id != ""
	visible = anything


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for i in mini(_paws.size(), 2):
		var target: float = _paws[i].heat if _paws[i].heats else 0.0
		_shown_heat[i] = lerpf(_shown_heat[i], target, 1.0 - exp(-heat_follow_speed * delta))
	# Pixel pictures: crisp (nearest) at real resolution; in the chunky PS1 look the HUD is shrunk
	# to game pixels, where a smooth filter keeps thin barrels from vanishing.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if Settings.modern_ui else CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


func _draw() -> void:
	var style := HudStyle.current()
	var bottom := size.y
	var x := 0.0
	if not _paws.is_empty():
		var box := Rect2(Vector2(0, bottom - weapon_box_size.y), weapon_box_size)
		_draw_weapon_box(style, box)
		x = box.end.x + gap
	# The two QUICK USE squares, stacked, right of the gun box.
	for slot in mini(_quick.size(), 2):
		if str(_quick[slot].get("id", "")) == "":
			continue  # empty: nothing to show
		var y := bottom - weapon_box_size.y + slot * (weapon_box_size.y - quick_slot_size)
		if weapon_box_size.y < quick_slot_size * 2.0:
			y = bottom - (2 - slot) * quick_slot_size - (1 - slot) * gap
		_draw_quick_slot(style, Rect2(Vector2(x, y), Vector2(quick_slot_size, quick_slot_size)), _quick[slot])


func _draw_weapon_box(style: HudStyle, box: Rect2) -> void:
	var any_overheated := false
	var hottest := 0.0
	for i in mini(_paws.size(), 2):
		any_overheated = any_overheated or _paws[i].overheated
		hottest = maxf(hottest, _shown_heat[i])
	# The box edge warms up with the hottest gun too.
	var edge := style.border_color.lerp(style.heat_color(1.0), clampf(hottest - 0.35, 0.0, 1.0)) if hottest > 0.35 else Color(0, 0, 0, 0)
	HudStyle.draw_panel(self, box, false, edge)
	var inner := box.grow(-padding)
	var font := get_theme_font("font", "Label")
	if _paws.size() == 1:
		if show_weapon_name:
			inner.position.y += name_font_size * 0.6  # room for the name
			inner.size.y -= name_font_size * 0.6
		_draw_gun(style, _paws[0], 0, inner, 1.0)
		if show_weapon_name:
			_text(font, box.position + Vector2(padding * 0.8, padding * 0.6 + name_font_size), _paws[0].name, name_font_size, style.text_color)
		if show_fire_key:
			_text_right(font, box.end - Vector2(padding * 0.6, padding * 0.5), _paws[0].key, key_font_size, style.text_color)
	else:
		# DUAL WIELD: left paw behind (up-left), right paw in front (down-right).
		var pic := Rect2(inner.position, inner.size - dual_offset)
		_draw_gun(style, _paws[1], 1, Rect2(pic.position, pic.size), back_opacity)
		_draw_gun(style, _paws[0], 0, Rect2(pic.position + dual_offset, pic.size), 1.0)
		if show_fire_key:
			_text(font, box.position + Vector2(padding * 0.6, padding * 0.4 + key_font_size), _paws[1].key, key_font_size, style.text_color)
			_text_right(font, box.end - Vector2(padding * 0.6, padding * 0.5), _paws[0].key, key_font_size, style.text_color)
	if any_overheated:
		var flash := 0.5 + 0.5 * sin(_time * TAU * style.overheat_flashes_per_second)
		var color := style.hot_color.lerp(style.overheat_flash_color, flash)
		_text(font, Vector2(box.position.x + 2.0, box.position.y - 6.0), "OVERHEAT", overheat_font_size, color)
	_draw_slam_meter(font, box)


## THE SLAM METER (only for a weapon that has one: paw "charge" >= 0): a thin bar inside the bottom
## edge of the box. It fills while you HOLD the button; CHARGING... shows above the box, and it flashes
## gold as it nears full (then the tuna slams).
func _draw_slam_meter(font: Font, box: Rect2) -> void:
	for i in mini(_paws.size(), 2):
		var charge: float = _paws[i].get("charge", -1.0)
		if charge < 0.0:
			continue
		var bar := Rect2(box.position + Vector2(padding * 0.5, box.size.y - charge_bar_height - padding * 0.4),
			Vector2((box.size.x - padding) * 0.72, charge_bar_height))  # (leaves room for the key on the right)
		draw_rect(bar, Color(0, 0.03, 0.06, 0.75))
		var ready := charge >= 0.8
		var flash := 0.5 + 0.5 * sin(_time * TAU * 3.0)
		var color := charge_ready_color.lerp(Color.WHITE, flash * 0.5) if ready else charge_color
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(charge, 0.0, 1.0), bar.size.y)), color)
		if charge > 0.0:
			_text(font, Vector2(box.position.x + 2.0, box.position.y - 6.0), slam_ready_text, overheat_font_size, color)
		return  # (one meter is plenty: only the tuna has one, and it takes both paws)


## One gun's picture, coloured by its heat. hand = 0 right / 1 left (which heat to read).
func _draw_gun(style: HudStyle, paw: Dictionary, hand: int, rect: Rect2, opacity: float) -> void:
	var color := style.heat_color(_shown_heat[hand])
	if paw.overheated:
		var flash := 0.5 + 0.5 * sin(_time * TAU * style.overheat_flashes_per_second)
		color = style.hot_color.lerp(style.overheat_flash_color, flash * 0.6)
	color.a *= opacity
	var texture := HudStyle.item_icon(paw.id)
	if texture != null:
		HudStyle.draw_icon(self, texture, rect, color)
	else:  # no picture made yet: just its name
		_text(get_theme_font("font", "Label"), rect.position + Vector2(0, rect.size.y / 2.0), paw.name, name_font_size, color)


func _draw_quick_slot(style: HudStyle, rect: Rect2, slot: Dictionary) -> void:
	var empty: bool = slot.id == ""
	HudStyle.draw_panel(self, rect, empty)
	var font := get_theme_font("font", "Label")
	var faint := style.text_color
	faint.a *= 0.45
	if not empty:
		var texture := HudStyle.item_icon(slot.id)
		if texture != null:
			HudStyle.draw_icon(self, texture, rect.grow(-7.0), style.cool_color)
		if slot.count > 1:
			_text_right(font, rect.end - Vector2(3, 3), "x%d" % slot.count, count_font_size, style.text_color)
	_text(font, rect.position + Vector2(3, key_font_size + 1), slot.key, key_font_size, faint if empty else style.text_color)


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	if text == "":
		return
	var outline := Color(0.0, 0.03, 0.06, color.a * 0.9)
	font_size = Hud.text_size(font_size)  # (PS1 look: small text stays readable)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Hud.outline(4), outline)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Text whose bottom-right corner (baseline) is at "at".
func _text_right(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Hud.text_size(font_size)).x
	_text(font, at - Vector2(width, 0), text, font_size, color)
