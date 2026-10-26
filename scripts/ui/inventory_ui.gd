class_name InventoryScreen
extends Control
## INVENTORY SCREEN — press Tab or I to open/close (Esc closes too).
## Part of the HUD (scenes/ui/hud.tscn > HUD > Frame > Inventory), so it's drawn sharp at your
## monitor's real resolution, on top of the low-res game. It builds its own boxes and buttons
## when the game starts, so the scene only needs the empty node. Sizes are in HUD units (the
## screen is 720 tall); tweak them with the exports below (select Inventory in hud.tscn).
##
##   PAWS      what you're holding. Click = put it in the backpack.
##   BACKPACK  held items you're carrying but not using. Click = take it into your paws.
##   LOOT BAG  fish etc. Delivered at the drop-off.
##   Right-click any item = drop it on the ground in front of you.
##
## AT THE STASH (standing at the lockers in the sewers, or pressing E there) the loot bag is
## swapped for your STASH, and clicks move things between you and the stash instead:
##   click a paw / backpack item = put it in the stash; click a stash item = into the backpack.
##
## The screen only ASKS the item system (ItemManager) to move things; the host decides,
## and the screen redraws itself from the result. So it's always in sync in multiplayer.
## While it's open the mouse and keys go to it instead of the game (scripts/ui/game_screen.gd).
##
## What it builds:
##   Inventory (this)
##   ├── Dim (ColorRect)                   <- darkens the game behind it
##   └── Centre (CenterContainer) > Panel (PanelContainer) > VBox
##       ├── Title, Paws (left + right paw slots)
##       ├── PackTitle + PackGrid           (3 slots per row)
##       ├── BagTitle + BagGrid  / StashTitle + StashGrid   (only one of the two is shown)
##       └── Info (hints, item descriptions, "Backpack is full.")

## The one inventory screen (the cat opens it when E is pressed at the stash).
static var instance: InventoryScreen

## Size of one item slot (HUD units).
@export var slot_size: Vector2 = Vector2(220, 44)
## Text size inside the slots.
@export var slot_font_size: int = 18
## Text size of the section titles (BACKPACK, LOOT BAG...).
@export var title_font_size: int = 20
## How many slots per row.
@export var columns: int = 3

var _paw_buttons: Array[Button] = []    # [left paw, right paw] as shown on screen
var _pack_buttons: Array[Button] = []
var _bag_buttons: Array[Button] = []
var _stash_buttons: Array[Button] = []
var _pack_title: Label
var _bag_title: Label
var _bag_grid: GridContainer
var _stash_title: Label
var _stash_grid: GridContainer
var _info: Label
var _last_key := ""
var _at_stash := false


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # clicks on the dim background don't reach the game
	_build.call_deferred()  # after the game (and its ItemManager, which knows the slot counts) is ready


func _build() -> void:
	var items := ItemManager.instance
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "VBox"
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	box.add_child(_label("INVENTORY", 34, Color(1, 0.4, 0.8)))

	# The two paws side by side, each with a little title above.
	var paws := HBoxContainer.new()
	paws.name = "Paws"
	paws.alignment = BoxContainer.ALIGNMENT_CENTER
	paws.add_theme_constant_override("separation", 24)
	box.add_child(paws)
	for paw in [["LEFT PAW", 1], ["RIGHT PAW", 0]]:  # left paw = hands[1], right paw = hands[0]
		var column := VBoxContainer.new()
		column.add_child(_label(paw[0], title_font_size - 2, Color(0.7, 0.7, 0.8)))
		var button := _slot("hand", paw[1])
		column.add_child(button)
		_paw_buttons.append(button)
		paws.add_child(column)

	_pack_title = _label("BACKPACK", title_font_size, Color(0.6, 0.85, 1))
	box.add_child(_pack_title)
	box.add_child(_grid(_pack_buttons, "pack", items.pack_size))

	# The loot bag and the stash share the same spot: only one is shown at a time.
	_bag_title = _label("LOOT BAG", title_font_size, Color(0.45, 1, 0.55))
	box.add_child(_bag_title)
	_bag_grid = _grid(_bag_buttons, "bag", items.bag_size)
	box.add_child(_bag_grid)
	_stash_title = _label("STASH", title_font_size, Color(0.4, 0.9, 1))
	box.add_child(_stash_title)
	_stash_grid = _grid(_stash_buttons, "stash", items.stash_size)
	box.add_child(_stash_grid)

	_info = _label("", title_font_size - 2, Color(1, 1, 1, 0.85))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# As wide as the slot rows, and room for two lines, so the box doesn't jump in size.
	_info.custom_minimum_size = Vector2(columns * slot_size.x + (columns - 1) * 8, (title_font_size + 4) * 2)
	box.add_child(_info)


func _input(event: InputEvent) -> void:
	var cat := ItemManager.instance.local_cat()
	if event.is_action_pressed("inventory") and cat != null and not Hud.menu_open() and not NpcDialog.is_open:
		_set_open(not visible)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


## Open the screen (the cat calls this when E is pressed at the stash lockers).
func open() -> void:
	if not visible:
		_set_open(true)


func _set_open(open_it: bool) -> void:
	if _info == null:
		return  # not built yet (the very first frame)
	visible = open_it
	_last_key = ""
	var cat := ItemManager.instance.local_cat()
	if open_it:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_info.text = ""  # filled in by _process (it depends on whether we're at the stash)
	elif cat != null and cat.is_controlled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if not visible:
		return
	var items := ItemManager.instance
	var cat := items.local_cat()
	if cat == null:
		_set_open(false)
		return
	var at_stash := UndergroundHub.instance.near_stash(cat)
	var inventory := items.get_inventory(cat.name.to_int())
	var key := str(inventory) + str(at_stash)
	if key == _last_key:
		return
	_last_key = key  # only redraw when something changed
	if at_stash != _at_stash or _info.text == "":
		_at_stash = at_stash
		_show_stash_section(at_stash)

	var hands: Array = inventory.hands
	_fill(_paw_buttons[0], hands[1])
	_fill(_paw_buttons[1], hands[0])
	if hands[0] != "" and (items.catalog[hands[0]] as ItemData).hands == 2:
		_paw_buttons[1].text = "BOTH PAWS"  # a 2-paw item fills both slots
	for i in _pack_buttons.size():
		_fill(_pack_buttons[i], inventory.pack[i] if i < inventory.pack.size() else "")
	for i in _bag_buttons.size():
		_fill(_bag_buttons[i], inventory.bag[i] if i < inventory.bag.size() else "")
	var stash := items.get_stash(cat.name.to_int())
	for i in _stash_buttons.size():
		_fill(_stash_buttons[i], stash[i] if i < stash.size() else "")
	_pack_title.text = "BACKPACK  %d/%d" % [inventory.pack.size(), items.pack_size]
	_bag_title.text = "LOOT BAG  %d/%d  (deliver at the drop-off)" % [items.bag_used(cat.name.to_int()), items.bag_size]
	_stash_title.text = "STASH  %d/%d  (safe, kept between games)" % [stash.size(), items.stash_size]


## At the lockers: show the stash instead of the loot bag (the box resizes itself to fit).
func _show_stash_section(at_stash: bool) -> void:
	_bag_title.visible = not at_stash
	_bag_grid.visible = not at_stash
	_stash_title.visible = at_stash
	_stash_grid.visible = at_stash
	if at_stash:
		_info.text = "Click: move between you and the stash   Right-click: drop   %s: close" % Controls.key_text("inventory")
	else:
		_info.text = "Click: equip / put away   Right-click: drop   %s: close" % Controls.key_text("inventory")


## Show an item in a slot (or "-" when empty), coloured like the item's glow.
func _fill(button: Button, item_id: String) -> void:
	button.set_meta("item", item_id)
	if item_id == "":
		button.text = "-"
		button.remove_theme_color_override("font_color")
		return
	var data: ItemData = ItemManager.instance.catalog[item_id]
	button.text = data.display_name
	if data.glow_color.a > 0.0:
		button.add_theme_color_override("font_color", data.glow_color.lightened(0.3))


## A grid of "count" slots, "columns" per row (the buttons are also added to "list").
func _grid(list: Array[Button], where: String, count: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	for i in count:
		var button := _slot(where, i)
		grid.add_child(button)
		list.append(button)
	return grid


func _slot(where: String, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = slot_size
	button.focus_mode = Control.FOCUS_NONE  # so Tab closes the screen instead of moving focus
	button.clip_text = true
	button.add_theme_font_size_override("font_size", slot_font_size)
	# Dark slot box with a neon edge (brighter when the mouse is over it).
	button.add_theme_stylebox_override("normal", _slot_style(Color(0.55, 0.35, 0.85, 0.8)))
	button.add_theme_stylebox_override("hover", _slot_style(Color(1, 0.4, 0.8)))
	button.add_theme_stylebox_override("pressed", _slot_style(Color(1, 1, 1)))
	button.set_meta("item", "")
	button.gui_input.connect(_on_slot_input.bind(button, where, index))
	button.mouse_entered.connect(_on_slot_hover.bind(button))
	return button


func _slot_style(edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.13, 0.95)
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_content_margin_all(6)
	return style


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)  # the box is dark already
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Left-click = equip / put away (or, at the stash, move to/from the stash); right-click = drop.
func _on_slot_input(event: InputEvent, button: Button, where: String, index: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or button.get_meta("item") == "":
		return
	var items := ItemManager.instance
	var cat := items.local_cat()
	if cat == null or not cat.is_controlled:
		_info.text = "Can't do that from inside the car."
		return
	var inventory := items.get_inventory(cat.name.to_int())
	if click.button_index == MOUSE_BUTTON_RIGHT and where != "stash":
		items.request_drop_item.rpc_id(1, where, index, items.ground_in_front_of(cat))
	elif click.button_index == MOUSE_BUTTON_LEFT and _at_stash:
		if where == "stash":
			if inventory.pack.size() >= items.pack_size:
				_info.text = "Backpack is full."
			else:
				items.request_from_stash.rpc_id(1, index)
		elif items.get_stash(cat.name.to_int()).size() >= items.stash_size:
			_info.text = "Stash is full."
		else:
			items.request_to_stash.rpc_id(1, where, index)
	elif click.button_index == MOUSE_BUTTON_LEFT:
		if where == "pack":
			items.request_equip.rpc_id(1, index)
		elif where == "hand":
			if inventory.pack.size() >= items.pack_size:
				_info.text = "Backpack is full."
			else:
				items.request_put_away.rpc_id(1, index)
		else:
			_info.text = "Loot pays out at the drop-off (the green beam)."
	accept_event()


## Hovering a slot shows what the item is.
func _on_slot_hover(button: Button) -> void:
	var item_id: String = button.get_meta("item")
	if item_id == "":
		return
	var data: ItemData = ItemManager.instance.catalog[item_id]
	_info.text = "%s: %s" % [data.display_name, data.description if data.description != "" else "-"]
