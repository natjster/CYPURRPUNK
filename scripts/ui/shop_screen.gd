class_name ShopScreen
extends Control
## THE BLACK MARKITTEN — the shop screen. Press E on Comrade Whiskers (Hub) or Clawd (GangHub) and it
## opens straight away (scripts/npcs/shopkeeper.gd), in the shared ocean-blue style
## (scripts/ui/hud_style.gd, colours in ui/hud_style.tres).
## Lives at scenes/ui/hud.tscn > HUD > Frame > Shop; builds its own buttons in code.
##
##   LEFT HALF:  your BACKPACK VIEW (scripts/ui/inventory_ui.gd in "shop mode"): the camera glides
##               behind your cat, your paws / quick-use / backpack boxes show SELL prices, and
##               clicking one SELLS it (right-click still drops it).
##   RIGHT HALF: this panel:
##     ┌ THE BLACK MARKITTEN                         $240 ┐
##     │ "Take your pick, comrade."                         │
##     │ [ SELL ALL LOOT (+$150) ]                          │
##     │ [ MELEE ] [ CONSUMABLES ] [ FIREARMS ]             │  <- tabs: click, or LB / RB
##     │ [pic] PAW-PISTOL  one shot per click...  BUY $60 │  <- click a row = buy it
##     │ [###] HAIRBALL BLASTER  LOCKED: CRATE 1 AT THE     │  <- locked = black silhouette;
##     │       WORKBENCH                          LOCKED  │     unlock crates at the TINKER WORKBENCH
##     │ what the highlighted thing is / "Bought ..."       │
##     └────────────────────────────────────────────────────┘
##
## PRICES (ItemManager.sell_price_for, the host checks everything):
##   buying = the item card's Price. Selling: street loot 100% of its Cash Value (+GOURMET FENCE),
##   gear half its Price, SCRAP not at all (it's for THE MAINFRAME and the workbench).
## CONTROLLER: the d-pad / stick moves one highlight over BOTH halves (tabs, rows, SELL ALL, your
##   backpack), A = click, X = drop (backpack), LB / RB = tabs, B / Y / Esc / Tab = leave.
## SPLIT SCREEN: every player has their own (ShopScreen.for_seat(seat)).

## The three tabs: title and the item ids on it (only items the shopkeeper has in his Stock show).
@export var melee_items: PackedStringArray = ["neon_bat", "frozen_tuna"]
@export var consumable_items: PackedStringArray = ["catnip", "catdip"]
@export var firearm_items: PackedStringArray = ["pistol", "hairball_blaster", "red_dot", "tommy_gun", "yarn_zooka", "cucumber_launcher"]

@export_group("Layout")
## Where the panel starts (fraction of the screen width): the backpack gets the left part.
@export_range(0.3, 0.7) var panel_start: float = 0.52
@export var row_max_height: float = 78.0
@export var gap: float = 8.0

@export_group("Words")
@export var title_font_size: int = 22
@export var name_font_size: int = 16
@export var detail_font_size: int = 12
@export var button_font_size: int = 15
## Shown on a locked row (%d = the crate number).
@export var locked_text: String = "LOCKED — PURCHASE CRATE %d AT WORKBENCH"
## The hint when a locked row is clicked.
@export var locked_hint: String = "Unlock Weapon Crate %d at the Tinker Workbench!"
## The bottom box before anything is highlighted.
@export var default_info: String = "Click a row to BUY. Click something in your backpack to SELL it. LB / RB: tabs. Esc / Tab: leave."
## How long a "Bought ..." / "Sold ..." message stays before the line goes back to item info.
@export var note_seconds: float = 3.0

@export_group("Locked silhouettes")
@export var silhouette_color: Color = Color(0, 0, 0, 0.92)
@export var silhouette_rim: Color = Color(0.1, 0.25, 0.5, 0.85)

const TAB_TITLES := ["MELEE", "CONSUMABLES", "FIREARMS"]
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)

## Which player's screen this is (its HUD's seat), whose cat is shopping, and with whom.
var seat: int = 0
var owner_cat: CatPlayer = null
var keeper: Shopkeeper = null
var tab: int = 0

var _focus := SeatFocus.new()
var _tab_buttons: Array[Button] = []
var _rows: Array[Button] = []
var _sell_all: Button
var _built := false
var _line := ""          # what the shopkeeper said when it opened
var _info := ""          # the bottom line: the highlighted thing
var _note := ""          # ...or a message ("Bought ...") for a few seconds
var _note_good := true
var _note_left := 0.0
var _last_key := ""
var _panel := Rect2()
var _info_rect := Rect2()


func _enter_tree() -> void:
	seat = (owner as Hud).seat if owner is Hud else 0


## This player's shop screen (seat 0 = player 1), or null.
static func for_seat(seat_number: int) -> ShopScreen:
	var hud := Hud.of(seat_number)
	return hud.get_node_or_null("Frame/Shop") as ShopScreen if hud != null else null


## Is this player shopping right now? (Hud.wants_input / the cat's _menu_open ask this.)
static func is_open_for(seat_number: int) -> bool:
	var screen := for_seat(seat_number)
	return screen != null and screen.visible


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # (the backpack boxes underneath get their clicks)
	_build.call_deferred()


func _build() -> void:
	_sell_all = _button("SELL ALL LOOT")
	_sell_all.pressed.connect(_sell_all_loot)
	for i in TAB_TITLES.size():
		var tab_button := _button(TAB_TITLES[i])
		tab_button.pressed.connect(_set_tab.bind(i))
		_tab_buttons.append(tab_button)
	for i in 6:
		var row := _button("")
		row.set_meta("row", i)
		var face := RowFace.new()
		face.name = "Face"
		face.screen = self
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(face)
		row.pressed.connect(_press_row.bind(row))
		row.mouse_entered.connect(_on_highlight.bind(row))
		_rows.append(row)
	_focus.press_on_accept = false
	_focus.highlighted.connect(_on_highlight)
	_built = true


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE  # (the d-pad moves a highlight: _focus, seat_focus.gd)
	button.add_theme_font_size_override("font_size", button_font_size)
	button.add_theme_color_override("font_color", HudStyle.current().text_color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _box(false))
	button.add_theme_stylebox_override("hover", _box(true))
	button.add_theme_stylebox_override("pressed", _box(true))
	add_child(button)
	return button


func _box(lit: bool) -> StyleBoxFlat:
	var style := HudStyle.current()
	var box := StyleBoxFlat.new()
	box.bg_color = style.panel_color.lightened(0.12) if lit else style.panel_color
	box.border_color = style.border_color.lightened(0.45) if lit else style.faint_border_color.lerp(style.border_color, 0.45)
	box.set_border_width_all(int(Hud.line(3.0 if lit else 1.5)))
	box.set_content_margin_all(4)
	return box


# --- Opening / closing ---

## Open the shop for this cat at this shopkeeper (shopkeeper.gd interact). The backpack opens on
## the left in shop mode.
func open(cat: CatPlayer, shopkeeper: Shopkeeper) -> void:
	if not _built or cat == null:
		return
	owner_cat = cat
	keeper = shopkeeper
	var cash := Wallet.instance.cash_of(cat.player_id)
	var lines: PackedStringArray = shopkeeper.shop_lines if shopkeeper != null else PackedStringArray()
	_line = lines[randi() % lines.size()] if not lines.is_empty() else "Take your pick."
	if _line.contains("%d"):
		_line = _line % cash
	_note = ""
	_info = default_info
	_last_key = ""
	visible = true
	var inventory := InventoryScreen.for_seat(seat)
	if inventory != null:
		inventory.open_for_shop(cat)
	if shopkeeper != null and shopkeeper.voice != "":
		Sound.play(shopkeeper.voice)
	_set_tab(tab)


func close() -> void:
	if not visible:
		return
	visible = false
	_focus.clear()
	var inventory := InventoryScreen.for_seat(seat)
	if inventory != null and inventory.visible:
		inventory._set_open(false)
	owner_cat = null


func _input(event: InputEvent) -> void:
	if not visible or Seats.seat_of_event(event) != seat:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_tab_left") or event.is_action_pressed("ui_tab_right"):
		_set_tab(posmod(tab + (1 if event.is_action_pressed("ui_tab_right") else -1), TAB_TITLES.size()))
		get_viewport().set_input_as_handled()
	elif _focus.handle(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_drop"):
		var current := _focus.current
		if current != null:
			var inventory := InventoryScreen.for_seat(seat)
			if current.has_meta("where") and inventory != null:
				inventory._use_slot(current, current.get_meta("where"), current.get_meta("index"), event.is_action_pressed("ui_drop"))
			elif event.is_action_pressed("ui_accept"):
				current.pressed.emit()
			get_viewport().set_input_as_handled()


## Every button the d-pad highlight moves over: ours AND the backpack's (paws, quick, slots).
func _refocus(first: Button = null) -> void:
	var inventory := InventoryScreen.for_seat(seat)
	var list: Array = _tab_buttons + [_sell_all] + _rows.filter(func(r): return r.visible)
	if inventory != null:
		list += inventory._paw_buttons + inventory._quick_buttons + inventory._pack_buttons
	_focus.set_buttons(list, first if first != null else _tab_buttons[tab])


func _set_tab(index: int) -> void:
	tab = clampi(index, 0, TAB_TITLES.size() - 1)
	_last_key = ""
	_fill_rows()
	_layout()
	if visible:
		_refocus(_tab_buttons[tab])


## The item ids on this tab that the shopkeeper stocks.
func _tab_items(index: int) -> PackedStringArray:
	var list: PackedStringArray = [melee_items, consumable_items, firearm_items][index]
	if keeper == null:
		return list
	return PackedStringArray(Array(list).filter(func(item_id): return item_id in keeper.stock))


func _fill_rows() -> void:
	var items := _tab_items(tab)
	for i in _rows.size():
		var row := _rows[i]
		var face := row.get_node("Face") as RowFace
		row.visible = i < items.size() and ItemManager.instance.catalog.has(items[i])
		face.item_id = items[i] if i < items.size() else ""
		face.locked = owner_cat != null and face.item_id != "" and not Upgrades.shop_allows(owner_cat.player_id, face.item_id)
		face.queue_redraw()
	for i in _tab_buttons.size():
		_tab_buttons[i].add_theme_color_override("font_color", Color.WHITE if i == tab else Color(HudStyle.current().text_color, 0.6))
		_tab_buttons[i].add_theme_stylebox_override("normal", _box(i == tab))


# --- Every frame ---

func _process(delta: float) -> void:
	if not visible:
		return
	var cat := owner_cat
	if cat == null or not is_instance_valid(cat) or not cat.is_inside_tree() or not UndergroundHub.is_in_hub(cat.global_position) \
			or (keeper != null and cat.global_position.distance_to(keeper.global_position) > 6.0) or Hud.menu_open():
		close()
		return
	var inventory := InventoryScreen.for_seat(seat)
	if inventory != null and not inventory.visible:
		inventory.open_for_shop(cat)  # (it closed somehow: keep the two together)
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0:
			_note = ""
	var items := ItemManager.instance
	var loot := items.pack_sell_value(cat.player_id)
	_sell_all.text = "SELL ALL LOOT (+$%d)" % loot if loot > 0 else "SELL ALL LOOT"
	_sell_all.add_theme_color_override("font_color", GOOD if loot > 0 else Color(HudStyle.current().text_color, 0.45))
	# Unlocks / prices can change while it's open (a crate bought by a friend, the backpack grows).
	var key := str(Upgrades.instance.player_upgrades.get(cat.player_id, {})) + str(items.pack_size_for(cat.player_id))
	if key != _last_key:
		_last_key = key
		_fill_rows()
		_refocus(_focus.current)
	modulate.a = clampf(cat.inventory_view_amount() * 1.6, 0.0, 1.0)
	_layout()
	queue_redraw()


func _layout() -> void:
	var slide := (1.0 - (owner_cat.inventory_view_amount() if owner_cat != null and is_instance_valid(owner_cat) else 1.0)) * 40.0
	var x := size.x * panel_start + slide
	var w := size.x - x - 24.0 + slide
	_panel = Rect2(x, 60.0, w, size.y - 84.0)
	var y := _panel.position.y + 64.0
	_place(_sell_all, Rect2(x + 10, y, w - 20, 34))
	y += 34 + gap
	var tab_w := (w - 20 - gap * (TAB_TITLES.size() - 1)) / TAB_TITLES.size()
	for i in _tab_buttons.size():
		_place(_tab_buttons[i], Rect2(x + 10 + i * (tab_w + gap), y, tab_w, 32))
	y += 32 + gap
	var info_h := 70.0
	var room := _panel.end.y - y - info_h - gap * 2
	var row_h := clampf((room - (5) * 6.0) / 6.0, 40.0, row_max_height)
	for i in _rows.size():
		_place(_rows[i], Rect2(x + 10, y + i * (row_h + 6), w - 20, row_h))
	_info_rect = Rect2(x + 10, _panel.end.y - info_h - 10, w - 20, info_h)


func _place(button: Control, rect: Rect2) -> void:
	button.position = rect.position
	button.size = rect.size


func _draw() -> void:
	if not visible or _panel.size.x <= 0:
		return
	var style := HudStyle.current()
	var font := get_theme_font("font", "Label")
	HudStyle.draw_panel(self, _panel)
	_text(font, _panel.position + Vector2(12, 28), "THE BLACK MARKITTEN", title_font_size, Color(1, 0.55, 0.85))
	if owner_cat != null and is_instance_valid(owner_cat):
		var cash := "$%d" % Wallet.instance.cash_of(owner_cat.player_id)
		var cw := font.get_string_size(cash, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size).x
		_text(font, Vector2(_panel.end.x - cw - 12, _panel.position.y + 28), cash, title_font_size, GOOD)
	var who := (keeper.npc_name + ": ") if keeper != null else ""
	_text(font, _panel.position + Vector2(12, 50), "%s\"%s\"" % [who, _line], detail_font_size + 1, Color(style.text_color, 0.75), _panel.size.x - 24)
	# The bottom box: a message, or what the highlighted thing is.
	HudStyle.draw_panel(self, _info_rect, true)
	var shown := _note if _note != "" else _info
	var color := (GOOD if _note_good else BAD) if _note != "" else style.text_color
	draw_multiline_string(font, _info_rect.position + Vector2(10, 22), shown, HORIZONTAL_ALIGNMENT_LEFT, _info_rect.size.x - 20,
		detail_font_size + 2, 3, color)


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color, max_width: float = -1.0) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, Hud.outline(4), Color(0, 0.03, 0.06, color.a * 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, color)


# --- Buying / selling ---

func _press_row(row: Button) -> void:
	var face := row.get_node("Face") as RowFace
	if face.item_id == "" or owner_cat == null:
		return
	if face.locked:
		Sound.play("error")
		note(locked_hint % Upgrades.crate_for(face.item_id), false)
		return
	ItemManager.instance.request_buy.rpc_id(1, owner_cat.player_id, face.item_id)


func _sell_all_loot() -> void:
	if owner_cat == null:
		return
	if ItemManager.instance.pack_sell_value(owner_cat.player_id) <= 0:
		Sound.play("error")
		note("No street loot to sell. (Scrap feeds THE MAINFRAME.)", false)
		return
	ItemManager.instance.request_sell_all_loot.rpc_id(1, owner_cat.player_id)


## A message in the bottom box for a few seconds (green = good news, red = no).
func note(text: String, good: bool) -> void:
	_note = text
	_note_good = good
	_note_left = note_seconds
	queue_redraw()


## The highlighted / hovered button: what it is and what it costs.
func _on_highlight(button: Button) -> void:
	if button == null or not button.has_meta("row"):
		if button == _sell_all and owner_cat != null:
			_info = "Sell every piece of street loot in your backpack at full price (scrap and gear stay)."
		return
	var face := button.get_node("Face") as RowFace
	var data: ItemData = ItemManager.instance.catalog.get(face.item_id)
	if data == null:
		return
	if face.locked:
		_info = "%s: %s" % [data.display_name, locked_hint % Upgrades.crate_for(face.item_id)]
	else:
		_info = "%s ($%d): %s  Sells back for $%d." % [data.display_name, data.price, data.description,
			ItemManager.instance.sell_price_for(owner_cat.player_id, face.item_id) if owner_cat != null else data.price / 2]


## Draws one shop row: the side-view picture (ocean blue, or a black silhouette when locked), the
## name, a short description, and BUY $XX (or LOCKED).
class RowFace extends Control:
	var screen: ShopScreen
	var item_id := ""
	var locked := false

	func _draw() -> void:
		if item_id == "":
			return
		var data: ItemData = ItemManager.instance.catalog.get(item_id)
		if data == null:
			return
		var style := HudStyle.current()
		var font := get_theme_font("font", "Label")
		var icon_box := Rect2(8, 6, minf(size.y * 1.7, size.x * 0.28), size.y - 12)
		var texture := HudStyle.item_icon(item_id)
		if locked:
			# Its exact shape, as a solid black silhouette with a thin dark-blue rim.
			for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				HudStyle.draw_icon(self, texture, Rect2(icon_box.position + offset * Hud.line(1.0), icon_box.size), screen.silhouette_rim)
			HudStyle.draw_icon(self, texture, icon_box, screen.silhouette_color)
		else:
			HudStyle.draw_icon(self, texture, icon_box, style.cool_color.lightened(0.2))
		var text_x := icon_box.end.x + 12
		var pill_w := 84.0 if locked else 112.0
		var text_w := size.x - text_x - pill_w - 16
		var name_color := Color(style.text_color, 0.55) if locked else Color.WHITE
		_text(font, Vector2(text_x, 6 + screen.name_font_size), data.display_name, screen.name_font_size, name_color, text_w)
		if locked:
			draw_multiline_string(font, Vector2(text_x, 10 + screen.name_font_size + screen.detail_font_size), screen.locked_text % Upgrades.crate_for(item_id),
				HORIZONTAL_ALIGNMENT_LEFT, text_w, screen.detail_font_size, 2, Color(1, 0.72, 0.25))
		elif size.y > 44:
			draw_multiline_string(font, Vector2(text_x, 10 + screen.name_font_size + screen.detail_font_size), data.description,
				HORIZONTAL_ALIGNMENT_LEFT, text_w, screen.detail_font_size, 2, Color(style.text_color, 0.7))
		# The BUY pill on the right.
		var pill := Rect2(size.x - pill_w - 8, size.y / 2.0 - 15, pill_w, 30)
		var can_pay := screen.owner_cat != null and Wallet.instance.cash_of(screen.owner_cat.player_id) >= data.price
		draw_rect(pill, Color(0.05, 0.1, 0.16, 0.85) if locked else (Color(0.1, 0.45, 0.25, 0.85) if can_pay else Color(0.35, 0.1, 0.1, 0.8)))
		draw_rect(pill, Color(style.border_color, 0.6), false, Hud.line(1.0))
		var label := "LOCKED" if locked else "BUY  $%d" % data.price
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, screen.button_font_size).x
		_text(font, Vector2(pill.get_center().x - lw / 2.0, pill.get_center().y + screen.button_font_size * 0.35), label, screen.button_font_size,
			Color(1, 0.72, 0.25) if locked else Color.WHITE)

	func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color, max_width: float = -1.0) -> void:
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, Hud.outline(4), Color(0, 0.03, 0.06, color.a * 0.9))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, color)
