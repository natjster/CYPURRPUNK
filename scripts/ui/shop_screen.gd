class_name ShopScreen
extends Control
## THE BLACK MARKITTEN — the shop screen. Talk to Comrade Whiskers (Hub) or Clawd (GangHub) with E and
## pick SHOW ME THE GOODS (scripts/npcs/shopkeeper.gd). One big centred window in the shared ocean-blue
## style (scripts/ui/hud_style.gd, colours in ui/hud_style.tres), laid out like THE MAINFRAME
## (mainframe_screen.gd) and the TINKER WORKBENCH (workbench_screen.gd): the sewer dims behind it.
## Lives at scenes/ui/hud.tscn > HUD > Frame > Shop; builds its own buttons in code.
##
##   ┌ THE BLACK MARKITTEN                                              $240 ┐
##   │ COMRADE WHISKERS: "Take your pick, comrade."                          │
##   │            [ MELEE ] [ CONSUMABLES ] [ FIREARMS ]                     │  <- tabs: click, or LB / RB
##   │      [pic] [pic] [###] [pic] [pic] [pic]                              │  <- item tiles (### = locked)
##   │ ┌big pic┐  PAW-PISTOL               ┌ PAW-PISTOL ────────────────┐   │
##   │ │       │  FIREARM   $60            │ one shot per click...      │   │  <- click a tile to pick it,
##   │ └───────┘  SELLS BACK FOR $30       │ [ BUY — $60 ]              │   │     then BUY
##   │ ┌ SELL TO THE FENCE: [fish x3] [koi] [pistol] ...   [SELL ALL LOOT] ┐ │  <- click one = sell ONE
##   │ what the highlighted thing is / "Bought ..."                          │
##   └───────────────────────────────────────────────────────────────────────┘
##
## PRICES (ItemManager.sell_price_for, the host checks everything):
##   buying = the item card's Price. Selling: street loot 100% of its Cash Value (+GOURMET FENCE),
##   gear half its Price, SCRAP / ELECTRONICS not at all (they're for the workbench / THE MAINFRAME).
## LOCKED guns (black silhouettes): unlock their WEAPON CRATE at the TINKER WORKBENCH first.
## CONTROLLER: the d-pad / stick moves the highlight, A = click, LB / RB = tabs, B / Y / Esc / Tab = leave.
## SPLIT SCREEN: every player has their own (ShopScreen.for_seat(seat)).

## The three tabs: title and the item ids on it (only items the shopkeeper has in his Stock show).
@export var melee_items: PackedStringArray = ["neon_bat", "frozen_tuna"]
@export var consumable_items: PackedStringArray = ["catnip", "catdip"]
@export var firearm_items: PackedStringArray = ["pistol", "hairball_blaster", "red_dot", "tommy_gun", "yarn_zooka", "cucumber_launcher"]

@export_group("Layout")
## The window's widest size (HUD units; the window is 960 wide).
@export var panel_max_width: float = 980.0
## The item tiles under the tabs (width; they get 20 more for the name underneath).
@export var tile_max_size: float = 104.0
## Height of the BUY button.
@export var button_height: float = 50.0
## The SELL TO THE FENCE strip's height, and the most of your things it shows at once.
@export var sell_strip_height: float = 92.0
@export var max_sell_tiles: int = 10
@export var gap: float = 8.0

@export_group("Words")
@export var title_font_size: int = 22
@export var name_font_size: int = 20
@export var detail_font_size: int = 13
@export var button_font_size: int = 16
## Shown on a locked item (%d = the crate number).
@export var locked_text: String = "LOCKED — PURCHASE CRATE %d AT WORKBENCH"
## The hint when a locked item's BUY is clicked.
@export var locked_hint: String = "Unlock Weapon Crate %d at the Tinker Workbench!"
## The bottom box before anything is highlighted.
@export var default_info: String = "Pick something on top, then BUY. Click your own things at the bottom to SELL one. LB / RB: tabs. Esc / Tab: leave."
## How long a "Bought ..." / "Sold ..." message stays before the line goes back to item info.
@export var note_seconds: float = 3.0

@export_group("Colours")
@export var title_color: Color = Color(1, 0.55, 0.85)
@export var silhouette_color: Color = Color(0, 0, 0, 0.92)
@export var silhouette_rim: Color = Color(0.1, 0.25, 0.5, 0.85)

const TAB_TITLES := ["MELEE", "CONSUMABLES", "FIREARMS"]
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)
const AMBER := Color(1.0, 0.75, 0.3)

## Which player's screen this is (its HUD's seat), whose cat is shopping, and with whom.
var seat: int = 0
var owner_cat: CatPlayer = null
var keeper: Shopkeeper = null
var tab: int = 0
## The item picked on top (shown big in the middle; BUY buys it).
var selected := ""

var _focus := SeatFocus.new()
var _tab_buttons: Array[Button] = []
var _rows: Array[Button] = []        # the item tiles on top (reused; hidden when the tab has fewer)
var _sell_tiles: Array[Button] = []  # your own things in the SELL strip (reused)
var _buy: Button
var _sell_all: Button
var _built := false
var _line := ""          # what the shopkeeper said when it opened
var _info := ""          # the bottom line: the highlighted thing
var _note := ""          # ...or a message ("Bought ...") for a few seconds
var _note_good := true
var _note_left := 0.0
var _last_key := ""
var _panel := Rect2()
var _picture := Rect2()   # the big picture of the picked item
var _card := Rect2()      # its detail card (BUY sits inside it)
var _sell_rect := Rect2() # the SELL TO THE FENCE strip
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
	mouse_filter = Control.MOUSE_FILTER_STOP  # clicks on the window don't reach the game
	_build.call_deferred()


func _build() -> void:
	for i in TAB_TITLES.size():
		var tab_button := HudStyle.make_button(self, TAB_TITLES[i], button_font_size)
		tab_button.pressed.connect(_set_tab.bind(i))
		tab_button.mouse_entered.connect(_on_highlight.bind(tab_button))
		_tab_buttons.append(tab_button)
	for i in 6:
		var row := HudStyle.make_button(self, "", button_font_size)
		row.set_meta("row", i)
		var face := ItemTile.new()
		face.screen = self
		HudStyle.attach_face(row, face)
		row.pressed.connect(_pick_row.bind(row))
		row.mouse_entered.connect(_on_highlight.bind(row))
		_rows.append(row)
	_buy = HudStyle.make_button(self, "BUY", button_font_size + 2)
	_buy.pressed.connect(_press_buy)
	_buy.mouse_entered.connect(_on_highlight.bind(_buy))
	for i in max_sell_tiles:
		var tile := HudStyle.make_button(self, "", button_font_size)
		var face := SellTile.new()
		face.screen = self
		HudStyle.attach_face(tile, face)
		tile.pressed.connect(_press_sell.bind(tile))
		tile.mouse_entered.connect(_on_highlight.bind(tile))
		_sell_tiles.append(tile)
	_sell_all = HudStyle.make_button(self, "SELL ALL LOOT", button_font_size - 2)
	_sell_all.pressed.connect(_sell_all_loot)
	_sell_all.mouse_entered.connect(_on_highlight.bind(_sell_all))
	_focus.press_on_accept = false
	_focus.highlighted.connect(_on_highlight)
	_built = true


# --- Opening / closing ---

## Open the shop for this cat at this shopkeeper (shopkeeper.gd, the SHOW ME THE GOODS button).
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
	if seat == 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # (the mouse is player 1's)
	if shopkeeper != null and shopkeeper.voice != "":
		Sound.play(shopkeeper.voice)
	_set_tab(tab)


func close() -> void:
	if not visible:
		return
	visible = false
	_focus.clear()
	owner_cat = null
	HudStyle.restore_game_mouse(seat)


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
	elif event.is_action_pressed("ui_accept"):
		if _focus.current != null:
			_focus.current.pressed.emit()
		get_viewport().set_input_as_handled()


## Every button the d-pad highlight moves over.
func _refocus(first: Button = null) -> void:
	var list: Array = _tab_buttons + _rows.filter(func(r): return r.visible) + [_buy] \
		+ _sell_tiles.filter(func(t): return t.visible) + [_sell_all]
	_focus.set_buttons(list, first if first != null and first.visible else _tab_buttons[tab])


func _set_tab(index: int) -> void:
	tab = clampi(index, 0, TAB_TITLES.size() - 1)
	var items := _tab_items(tab)
	selected = items[0] if not items.is_empty() else ""
	_last_key = ""
	_fill_rows()
	_layout()
	if visible:
		_refocus(_tab_buttons[tab])


## The item ids on this tab that the shopkeeper stocks.
func _tab_items(index: int) -> PackedStringArray:
	var list: PackedStringArray = [melee_items, consumable_items, firearm_items][index]
	list = PackedStringArray(Array(list).filter(func(item_id): return ItemManager.instance.catalog.has(item_id)))
	if keeper == null:
		return list
	return PackedStringArray(Array(list).filter(func(item_id): return item_id in keeper.stock))


## Is this item still locked for us (its WEAPON CRATE isn't bought)?
func is_locked(item_id: String) -> bool:
	return owner_cat != null and item_id != "" and not Upgrades.shop_allows(owner_cat.player_id, item_id)


func _fill_rows() -> void:
	var items := _tab_items(tab)
	for i in _rows.size():
		var row := _rows[i]
		var face := row.get_node("Face") as ItemTile
		row.visible = i < items.size()
		face.item_id = items[i] if i < items.size() else ""
		row.add_theme_stylebox_override("normal", HudStyle.button_box(face.item_id != "" and face.item_id == selected))
		face.queue_redraw()
	for i in _tab_buttons.size():
		_tab_buttons[i].add_theme_color_override("font_color", Color.WHITE if i == tab else Color(HudStyle.current().text_color, 0.6))
		_tab_buttons[i].add_theme_stylebox_override("normal", HudStyle.button_box(i == tab))
	# The BUY button follows the picked item.
	var data: ItemData = ItemManager.instance.catalog.get(selected)
	_buy.visible = data != null
	if data != null:
		var can_pay := owner_cat != null and Wallet.instance.cash_of(owner_cat.player_id) >= data.price
		if is_locked(selected):
			_buy.text = "LOCKED — CRATE %d" % Upgrades.crate_for(selected)
			_buy.add_theme_color_override("font_color", AMBER)
		else:
			_buy.text = "BUY — $%d" % data.price
			_buy.add_theme_color_override("font_color", Color.WHITE if can_pay else Color(BAD, 0.85))
	_fill_sell_tiles()


## The SELL strip: hands, quick-use, then each kind of thing in the backpack (stacked: "x3").
func _fill_sell_tiles() -> void:
	var things := _sellables()
	for i in _sell_tiles.size():
		var tile := _sell_tiles[i]
		var face := tile.get_node("Face") as SellTile
		tile.visible = i < things.size()
		if tile.visible:
			var thing: Dictionary = things[i]
			tile.set_meta("where", thing.where)
			tile.set_meta("index", thing.index)
			face.item_id = thing.item_id
			face.count = thing.count
		else:
			face.item_id = ""
		face.queue_redraw()
	var loot := ItemManager.instance.pack_sell_value(owner_cat.player_id) if owner_cat != null else 0
	_sell_all.text = "SELL ALL LOOT (+$%d)" % loot if loot > 0 else "SELL ALL LOOT"
	_sell_all.add_theme_color_override("font_color", GOOD if loot > 0 else Color(HudStyle.current().text_color, 0.45))


## What we carry, one entry per thing the SELL strip shows: {where, index, item_id, count}.
## where/index are what ItemManager.request_sell wants ("hand" 0/1, "quick" 0/1, "pack" list index).
func _sellables() -> Array:
	var list: Array = []
	if owner_cat == null:
		return list
	var items := ItemManager.instance
	var inventory := items.get_inventory(owner_cat.player_id)
	var hands: Array = inventory.hands
	for i in 2:
		if hands[i] != "" and not (i == 1 and hands[0] == hands[1] and items._is_two_handed(hands)):
			list.append({"where": "hand", "index": i, "item_id": hands[i], "count": 1})
	var quick := items.quick_slots_of(inventory)
	for i in 2:
		if not quick[i].is_empty():
			list.append({"where": "quick", "index": i, "item_id": quick[i][0], "count": quick[i].size()})
	# The backpack, one tile per kind of thing (the tile sells the LAST one in the list).
	var by_id := {}
	for i in inventory.pack.size():
		var item_id: String = inventory.pack[i]
		if not by_id.has(item_id):
			by_id[item_id] = {"where": "pack", "index": i, "item_id": item_id, "count": 0}
			list.append(by_id[item_id])
		by_id[item_id].index = i
		by_id[item_id].count += 1
	return list.slice(0, max_sell_tiles)


# --- Every frame ---

func _process(delta: float) -> void:
	if not visible:
		return
	var cat := owner_cat
	if cat == null or not is_instance_valid(cat) or not cat.is_inside_tree() or not UndergroundHub.is_in_hub(cat.global_position) \
			or (keeper != null and cat.global_position.distance_to(keeper.global_position) > 6.0) or Hud.menu_open():
		close()
		return
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0:
			_note = ""
	# Unlocks / cash / what we carry can change while it's open (a sale, a crate bought by a friend).
	var items := ItemManager.instance
	var key := "%s|%s|%d|%s" % [Upgrades.instance.player_upgrades.get(cat.player_id, {}), items.get_inventory(cat.player_id),
		Wallet.instance.cash_of(cat.player_id), selected]
	if key != _last_key:
		_last_key = key
		_fill_rows()
		_refocus(_focus.current)
	_layout()
	queue_redraw()


func _layout() -> void:
	var w := minf(size.x - 48.0, panel_max_width)
	_panel = Rect2((size.x - w) / 2.0, 56.0, w, size.y - 80.0)
	var x := _panel.position.x + 12.0
	var inner_w := w - 24.0
	# Tabs, centred under the title + the shopkeeper's line.
	var tab_w := minf(180.0, (inner_w - gap * 2) / 3.0)
	var tabs_x := _panel.position.x + (w - (tab_w * 3 + gap * 2)) / 2.0
	var y := _panel.position.y + 64.0
	for i in _tab_buttons.size():
		HudStyle.place(_tab_buttons[i], Rect2(tabs_x + i * (tab_w + gap), y, tab_w, 32))
	y += 32 + gap
	# The item tiles, centred like the workbench's portraits.
	var shown := _rows.filter(func(r): return r.visible)
	var tile := minf(tile_max_size, (inner_w - gap * 5) / 6.0)
	var tiles_w := tile * shown.size() + gap * maxf(shown.size() - 1, 0)
	var tile_x := _panel.position.x + (w - tiles_w) / 2.0
	for i in shown.size():
		HudStyle.place(shown[i], Rect2(tile_x + i * (tile + gap), y, tile, tile * 0.72 + 20.0))
	y += tile * 0.72 + 20.0 + gap * 2
	# Bottom up: the info box, the SELL strip, then the picked item fills the middle.
	var compact := size.y < 640.0
	var info_h := 46.0 if compact else 56.0
	var sell_h_box := minf(sell_strip_height, 78.0) if compact else sell_strip_height
	_info_rect = Rect2(x, _panel.end.y - info_h - 10.0, inner_w, info_h)
	_sell_rect = Rect2(x, _info_rect.position.y - gap - sell_h_box, inner_w, sell_h_box)
	var middle_h := _sell_rect.position.y - gap - y
	var picture_w := minf(inner_w * 0.24, middle_h * 1.3)
	_picture = Rect2(x, y, picture_w, middle_h)
	var card_x := x + inner_w * 0.5
	_card = Rect2(card_x, y, _panel.end.x - 12.0 - card_x, middle_h)
	var buy_h := minf(button_height, 34.0) if middle_h < 140.0 else button_height
	HudStyle.place(_buy, Rect2(_card.position.x + 12, _card.end.y - buy_h - 10, _card.size.x - 24, buy_h))
	# The SELL strip: your things, then SELL ALL LOOT on the right.
	var all_w := 236.0
	HudStyle.place(_sell_all, Rect2(_sell_rect.end.x - all_w - 10, _sell_rect.position.y + 30, all_w, _sell_rect.size.y - 40))
	var sell_x := _sell_rect.position.x + 10
	var sell_room := _sell_rect.size.x - all_w - 30
	var sell_h := _sell_rect.size.y - 40
	var sell_w := minf(sell_h * 1.3, (sell_room - gap * (max_sell_tiles - 1)) / max_sell_tiles)
	for i in _sell_tiles.size():
		HudStyle.place(_sell_tiles[i], Rect2(sell_x + i * (sell_w + gap), _sell_rect.position.y + 30, sell_w, sell_h))


func _draw() -> void:
	if not visible or _panel.size.x <= 0 or owner_cat == null or not is_instance_valid(owner_cat):
		return
	var style := HudStyle.current()
	var font := get_theme_font("font", "Label")
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0.02, 0.05, 0.45))  # dim the sewer behind
	HudStyle.draw_panel(self, _panel)
	HudStyle.draw_text(self, font, _panel.position + Vector2(14, 30), "THE BLACK MARKITTEN", title_font_size, title_color)
	HudStyle.draw_text_right(self, font, Vector2(_panel.end.x - 14, _panel.position.y + 30), "$%d" % Wallet.instance.cash_of(owner_cat.player_id), title_font_size, GOOD)
	var who := (keeper.npc_name + ": ") if keeper != null else ""
	HudStyle.draw_text(self, font, _panel.position + Vector2(14, 52), "%s\"%s\"" % [who, _line], detail_font_size, Color(style.text_color, 0.75), _panel.size.x - 28)

	# The picked item: big picture (left), its name / kind / prices (middle), its card + BUY (right).
	var data: ItemData = ItemManager.instance.catalog.get(selected)
	if data != null:
		var locked := is_locked(selected)
		HudStyle.draw_panel(self, _picture, true)
		draw_item_picture(self, selected, _picture.grow(-14), locked, 2.0)
		var tx := _picture.end.x + 14
		var tw := _card.position.x - tx - 12
		var ty := _picture.position.y + 24
		var step := minf(46.0, maxf(30.0, (_picture.size.y - 44.0) * 0.5))
		HudStyle.draw_text(self, font, Vector2(tx, ty), data.display_name, name_font_size, Color(style.text_color, 0.55) if locked else Color.WHITE, tw)
		HudStyle.draw_text(self, font, Vector2(tx, ty + 20), TAB_TITLES[tab], detail_font_size, AMBER, tw)
		var price_y := ty + 20 + step * 0.65
		HudStyle.draw_text(self, font, Vector2(tx, price_y), "PRICE", detail_font_size, Color(style.text_color, 0.6), tw)
		HudStyle.draw_text(self, font, Vector2(tx, price_y + 17), "$%d" % data.price, detail_font_size + 3, GOOD, tw)
		var sell_y := price_y + step
		HudStyle.draw_text(self, font, Vector2(tx, sell_y), "SELLS BACK FOR", detail_font_size, Color(style.text_color, 0.6), tw)
		HudStyle.draw_text(self, font, Vector2(tx, sell_y + 17), "$%d" % ItemManager.instance.sell_price_for(owner_cat.player_id, selected), detail_font_size + 3,
			Color(style.text_color, 0.85), tw)
		HudStyle.draw_panel(self, _card)
		var cw := _card.size.x - 28
		HudStyle.draw_text(self, font, _card.position + Vector2(14, 28), data.display_name, name_font_size, AMBER, cw)
		if locked:
			HudStyle.draw_text(self, font, _card.position + Vector2(14, 50), locked_text % Upgrades.crate_for(selected), detail_font_size + 1, AMBER, cw)
		var desc_y := 74.0 if locked else 52.0
		var avail_h := _buy.position.y - (_card.position.y + desc_y) - 4.0
		var lines := int(floor(avail_h / float(detail_font_size + 5)))
		if lines >= 1:
			draw_multiline_string(font, _card.position + Vector2(14, desc_y), data.description, HORIZONTAL_ALIGNMENT_LEFT, cw,
				detail_font_size + 1, lines, Color(style.text_color, 0.8))

	# The SELL strip.
	HudStyle.draw_panel(self, _sell_rect, true)
	HudStyle.draw_text(self, font, _sell_rect.position + Vector2(12, 21), "SELL TO THE FENCE", detail_font_size + 1, AMBER)
	HudStyle.draw_text(self, font, _sell_rect.position + Vector2(172, 21), "click one of your things to sell ONE", detail_font_size - 1, Color(style.text_color, 0.45))
	if _sell_tiles.filter(func(t): return t.visible).is_empty():
		HudStyle.draw_text(self, font, _sell_rect.position + Vector2(12, _sell_rect.size.y * 0.5 + 18), "Nothing on you to sell. Go loot!", detail_font_size, Color(style.text_color, 0.5))

	# The bottom box: a message, or what the highlighted thing is.
	HudStyle.draw_panel(self, _info_rect, true)
	var shown := _note if _note != "" else _info
	var color := (GOOD if _note_good else BAD) if _note != "" else style.text_color
	draw_multiline_string(font, _info_rect.position + Vector2(10, 22), shown, HORIZONTAL_ALIGNMENT_LEFT, _info_rect.size.x - 20,
		detail_font_size + 1, 3, color)


## An item's side-view picture fitted in a box: ocean blue, or a black silhouette with a thin rim
## when it's locked. (The tiles use it too.)
func draw_item_picture(canvas: CanvasItem, item_id: String, box: Rect2, locked: bool, rim: float = 1.0) -> void:
	var texture := HudStyle.item_icon(item_id)
	if locked:
		for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			HudStyle.draw_icon(canvas, texture, Rect2(box.position + offset * Hud.line(rim), box.size), silhouette_rim)
		HudStyle.draw_icon(canvas, texture, box, silhouette_color)
	else:
		HudStyle.draw_icon(canvas, texture, box, HudStyle.current().cool_color.lightened(0.2))


# --- Buying / selling ---

## A tile on top was clicked: show that item big in the middle (BUY buys it).
func _pick_row(row: Button) -> void:
	var item_id: String = (row.get_node("Face") as ItemTile).item_id
	if item_id == "":
		return
	selected = item_id
	_fill_rows()


func _press_buy() -> void:
	if selected == "" or owner_cat == null:
		return
	if is_locked(selected):
		Sound.play("error")
		note(locked_hint % Upgrades.crate_for(selected), false)
		return
	ItemManager.instance.request_buy.rpc_id(1, owner_cat.player_id, selected)


## (Old name, kept for the dev tests: pick this row's item and buy it.)
func _press_row(row: Button) -> void:
	_pick_row(row)
	_press_buy()


## A tile in the SELL strip: sell ONE of that (the host checks and pays: request_sell).
func _press_sell(tile: Button) -> void:
	if owner_cat == null or not tile.visible:
		return
	var item_id: String = (tile.get_node("Face") as SellTile).item_id
	if ItemManager.instance.sell_price_for(owner_cat.player_id, item_id) <= 0:
		Sound.play("error")
		var data: ItemData = ItemManager.instance.catalog.get(item_id)
		note("The shop won't buy %s. SCRAP pays for upgrades at the workbench; ELECTRONICS feed THE MAINFRAME." % (data.display_name if data != null else item_id), false)
		return
	ItemManager.instance.request_sell.rpc_id(1, owner_cat.player_id, tile.get_meta("where"), tile.get_meta("index"))


## Sell what's in a hand / quick slot / the Nth backpack tile (dev tests: --shop_sell=pack:0).
func sell_from(where: String, index: int) -> void:
	var nth := 0
	for tile in _sell_tiles:
		if tile.visible and tile.get_meta("where") == where:
			if (where == "pack" and nth == index) or (where != "pack" and tile.get_meta("index") == index):
				_press_sell(tile)
				return
			nth += 1


func _sell_all_loot() -> void:
	if owner_cat == null:
		return
	if ItemManager.instance.pack_sell_value(owner_cat.player_id) <= 0:
		Sound.play("error")
		note("No street loot to sell. (Scrap = upgrades, electronics = THE MAINFRAME.)", false)
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
	if button == null or owner_cat == null:
		return
	var items := ItemManager.instance
	if button == _sell_all:
		_info = "Sell every piece of street loot in your backpack at full price (scrap and gear stay)."
	elif button == _buy:
		var data: ItemData = items.catalog.get(selected)
		if data != null:
			_info = (locked_hint % Upgrades.crate_for(selected)) if is_locked(selected) else "Buy %s for $%d. It goes in your paws or backpack." % [data.display_name, data.price]
	elif button in _tab_buttons:
		_info = "%s: LB / RB flips between the tabs." % button.text
	elif button.has_meta("row"):
		var item_id: String = (button.get_node("Face") as ItemTile).item_id
		var data: ItemData = items.catalog.get(item_id)
		if data != null:
			_info = "%s: %s" % [data.display_name, locked_hint % Upgrades.crate_for(item_id)] if is_locked(item_id) \
				else "%s ($%d): %s  Click to look closer." % [data.display_name, data.price, data.description]
	elif button in _sell_tiles:
		var item_id: String = (button.get_node("Face") as SellTile).item_id
		var data: ItemData = items.catalog.get(item_id)
		var price := items.sell_price_for(owner_cat.player_id, item_id)
		if data != null:
			_info = ("Sell one %s for $%d." % [data.display_name, price]) if price > 0 \
				else "The shop won't buy %s.%s" % [data.display_name, "  Spend it at the TINKER WORKBENCH." if item_id == Mainframe.SCRAP_ID \
				else ("  Feed it to THE MAINFRAME." if item_id == Mainframe.FUEL_ID else "")]


## One item tile on top: its picture (or a black silhouette when locked), name and price.
class ItemTile extends Control:
	var screen: ShopScreen
	var item_id := ""

	func _draw() -> void:
		var data: ItemData = ItemManager.instance.catalog.get(item_id)
		if data == null:
			return
		var font := get_theme_font("font", "Label")
		var locked := screen.is_locked(item_id)
		screen.draw_item_picture(self, item_id, Rect2(8, 6, size.x - 16, size.y - 32), locked)
		var label := "LOCKED" if locked else "$%d" % data.price
		var color := ShopScreen.AMBER if locked else (Color.WHITE if item_id == screen.selected else Color(1, 1, 1, 0.8))
		_centred(font, data.display_name, size.y - 15, 10, Color(color, 0.85))
		_centred(font, label, size.y - 3, 11, ShopScreen.AMBER if locked else ShopScreen.GOOD)

	func _centred(font: Font, text: String, y: float, font_size: int, color: Color) -> void:
		var w := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, size.x - 4)
		var at := Vector2(maxf(2, (size.x - w) / 2.0), y)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 4, font_size, Hud.outline(3), Color(0, 0.03, 0.06))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 4, font_size, color)


## One of your things in the SELL strip: its picture, "x3" when stacked, and SELL $X (or NO SALE).
class SellTile extends Control:
	var screen: ShopScreen
	var item_id := ""
	var count := 1

	func _draw() -> void:
		if item_id == "" or screen.owner_cat == null:
			return
		var font := get_theme_font("font", "Label")
		var price := ItemManager.instance.sell_price_for(screen.owner_cat.player_id, item_id)
		HudStyle.draw_icon(self, HudStyle.item_icon(item_id), Rect2(5, 4, size.x - 10, size.y - 20),
			HudStyle.current().cool_color.lightened(0.2) if price > 0 else Color(0.5, 0.55, 0.6, 0.6))
		if count > 1:
			HudStyle.draw_text(self, font, Vector2(size.x - 22, 15), "x%d" % count, 11, Color.WHITE, size.x - 4, 3.0)
		var label := "SELL $%d" % price if price > 0 else "NO SALE"
		var w := minf(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, size.x - 4)
		HudStyle.draw_text(self, font, Vector2(maxf(2, (size.x - w) / 2.0), size.y - 4), label, 10, ShopScreen.GOOD if price > 0 else Color(0.6, 0.65, 0.7), size.x - 4, 3.0)
