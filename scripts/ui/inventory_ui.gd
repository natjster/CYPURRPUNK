class_name InventoryScreen
extends Control
## INVENTORY SCREEN — press Tab or I to open/close (Esc closes too).
## Part of the HUD (scenes/ui/hud.tscn > HUD > Frame > Inventory), so it's drawn sharp at your
## monitor's real resolution, on top of the low-res game. It builds its own boxes and buttons
## when the game starts, so the scene only needs the empty node. Sizes are in HUD units (the
## screen is 720 tall); tweak them with the exports below (select Inventory in hud.tscn).
##
##   PAWS      what you're holding. Click = put it in the backpack.
##   QUICK USE two slots for catnip / catdip (keys 1 / 2, d-pad left / right in the game).
##             Click = put one back in the backpack. Clicking catnip in the backpack moves it here.
##   BACKPACK  held items you're carrying but not using. Click = take it into your paws.
##   LOOT BAG  fish etc. Paid out at the exit manhole.
##   Right-click any item = drop it on the ground in front of you.
##   CONTROLLER: Y opens it, the d-pad / left stick picks a slot, A = click, X = drop, B / Y = close.
## SPLIT SCREEN: every player has their own inventory screen in their own HUD (Hud.seat), showing
## their own cat's things. InventoryScreen.for_seat(seat) finds it.
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
##       ├── Quick (QUICK USE 1 + 2 slots)
##       ├── PackTitle + PackGrid           (3 slots per row)
##       ├── BagTitle + BagGrid  / StashTitle + StashGrid   (only one of the two is shown)
##       └── Info (hints, item descriptions, "Backpack is full.")

## Player 1's inventory screen.
static var instance: InventoryScreen

## Which player's screen this is (its HUD's seat).
var seat: int = 0
## Whose things are showing: this seat's cat (set when it opens).
var owner_cat: CatPlayer = null
## This player's highlighted slot (scripts/ui/seat_focus.gd): their d-pad / arrows move it,
## A / Enter = click it, X = drop it (handled here, so A doesn't "press" the slot itself).
var _focus := SeatFocus.new()

## Size of one item slot (HUD units).
@export var slot_size: Vector2 = Vector2(220, 44)
## Text size inside the slots.
@export var slot_font_size: int = 18
## Text size of the section titles (BACKPACK, LOOT BAG...).
@export var title_font_size: int = 20
## How many slots per row.
@export var columns: int = 3

var _paw_buttons: Array[Button] = []    # [left paw, right paw] as shown on screen
var _quick_buttons: Array[Button] = []  # [quick use 1, quick use 2]
var _quick_titles: Array[Label] = []
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
	seat = (owner as Hud).seat if owner is Hud else 0
	if seat == 0:
		instance = self


## This player's inventory screen (seat 0 = player 1), or null.
static func for_seat(seat_number: int) -> InventoryScreen:
	var hud := Hud.of(seat_number)
	return hud.get_node_or_null("Frame/Inventory") as InventoryScreen if hud != null else null


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

	# The two QUICK USE slots, the same way (titles show their keys: filled in by _process).
	var quick := HBoxContainer.new()
	quick.name = "Quick"
	quick.alignment = BoxContainer.ALIGNMENT_CENTER
	quick.add_theme_constant_override("separation", 24)
	box.add_child(quick)
	for slot in 2:
		var column := VBoxContainer.new()
		var title := _label("QUICK USE %d" % (slot + 1), title_font_size - 2, Color(1, 0.85, 0.4))
		column.add_child(title)
		_quick_titles.append(title)
		var button := _slot("quick", slot)
		column.add_child(button)
		_quick_buttons.append(button)
		quick.add_child(column)

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
	_focus.press_on_accept = false
	_focus.highlighted.connect(_on_slot_hover)  # show what the highlighted item is
	Controls.changed.connect(func():  # switched keyboard <-> controller: redo the "Click: ..." line
		if visible:
			_show_stash_section(_at_stash))


func _input(event: InputEvent) -> void:
	if Seats.seat_of_event(event) != seat:
		return  # another player's button (player 1's HUD hears every button first)
	if event.is_action_pressed("inventory") and not Hud.menu_open() and not NpcDialog.is_open_for(seat):
		var cat := Game.instance.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat))
		if visible:
			_set_open(false)
		elif cat != null and cat.reads_input():
			_set_open(true, cat)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()
	elif visible and _focus.handle(event):  # d-pad / arrows: move the highlight
		get_viewport().set_input_as_handled()
	elif visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_drop")):
		# Controller / keyboard: A (Enter) = click the highlighted slot, X = drop it.
		var slot := _focus.current
		if slot != null and slot.has_meta("where"):
			_use_slot(slot, slot.get_meta("where"), slot.get_meta("index"), event.is_action_pressed("ui_drop"))
			get_viewport().set_input_as_handled()


## Open the screen for this cat (the cat calls this when E is pressed at the stash lockers).
func open(cat: CatPlayer) -> void:
	if not visible:
		_set_open(true, cat)


func _set_open(open_it: bool, cat: CatPlayer = null) -> void:
	if _info == null:
		return  # not built yet (the very first frame)
	if open_it:
		owner_cat = cat if cat != null else Game.instance.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat))
		if owner_cat == null:
			return
	visible = open_it
	_last_key = ""
	if open_it:
		if seat == 0:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # (the mouse is player 1's)
		_info.text = ""  # filled in by _process (it depends on whether we're at the stash)
		# A highlighted slot for the d-pad / arrows to move around from (left paw first).
		_focus.set_buttons(_paw_buttons + _quick_buttons + _pack_buttons + _bag_buttons + _stash_buttons, _paw_buttons[0])
	else:
		_focus.clear()
		var first := Game.instance.my_cat() if Game.instance != null else null
		if seat == 0 and first != null and first.is_controlled:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if not visible:
		return
	var items := ItemManager.instance
	var cat := owner_cat
	if cat == null or not is_instance_valid(cat):
		_set_open(false)
		return
	var at_stash := UndergroundHub.of(cat).near_stash(cat)
	var inventory := items.get_inventory(cat.player_id)
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
	var quick := items.quick_slots(cat.player_id)
	for i in 2:
		_fill(_quick_buttons[i], quick[i][0] if not quick[i].is_empty() else "")
		if quick[i].size() > 1:
			_quick_buttons[i].text += "  x%d" % quick[i].size()
		_quick_titles[i].text = "QUICK USE %d  [%s]" % [i + 1, Controls.key_text("quick_%d" % (i + 1))]
	for i in _pack_buttons.size():
		_fill(_pack_buttons[i], inventory.pack[i] if i < inventory.pack.size() else "")
	for i in _bag_buttons.size():
		_fill(_bag_buttons[i], inventory.bag[i] if i < inventory.bag.size() else "")
	var stash := items.get_stash(cat.player_id)
	for i in _stash_buttons.size():
		_fill(_stash_buttons[i], stash[i] if i < stash.size() else "")
	_pack_title.text = "BACKPACK  %d/%d" % [inventory.pack.size(), items.pack_size]
	_bag_title.text = "LOOT BAG  %d/%d  (paid out at the exit manhole)" % [items.bag_used(cat.player_id), items.bag_size]
	_stash_title.text = "STASH  %d/%d  (safe, kept between games)" % [stash.size(), items.stash_size]


## At the lockers: show the stash instead of the loot bag (the box resizes itself to fit).
func _show_stash_section(at_stash: bool) -> void:
	_bag_title.visible = not at_stash
	_bag_grid.visible = not at_stash
	_stash_title.visible = at_stash
	_stash_grid.visible = at_stash
	var on_pad := owner_cat != null and Seats.uses_pad(owner_cat.slot)
	var click := "%s:" % Controls.display_name("Pad A") if on_pad else "Click:"
	var drop := "%s:" % Controls.display_name("Pad X") if on_pad else "Right-click:"
	if at_stash:
		_info.text = "%s move between you and the stash   %s drop   %s: close" % [click, drop, Controls.key_text("inventory")]
	else:
		_info.text = "%s equip / put away   %s drop   %s: close" % [click, drop, Controls.key_text("inventory")]


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
	# (The d-pad / arrows move a highlight between slots: _focus, scripts/ui/seat_focus.gd.)
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("where", where)
	button.set_meta("index", index)
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
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_LEFT or click.button_index == MOUSE_BUTTON_RIGHT:
		_use_slot(button, where, index, click.button_index == MOUSE_BUTTON_RIGHT)
		accept_event()


## What clicking a slot does (drop = right-click / X on a controller).
func _use_slot(button: Button, where: String, index: int, drop: bool) -> void:
	if button.get_meta("item") == "":
		return
	var items := ItemManager.instance
	var cat := owner_cat
	if cat == null or not is_instance_valid(cat) or not cat.is_controlled:
		_info.text = "Can't do that from inside the car."
		return
	var inventory := items.get_inventory(cat.player_id)
	if drop and where != "stash":
		items.request_drop_item.rpc_id(1, cat.player_id, where, index, items.ground_in_front_of(cat))
	elif drop:
		pass  # (stash items can't be dropped)
	elif _at_stash:
		if where == "stash":
			if inventory.pack.size() >= items.pack_size:
				_info.text = "Backpack is full."
			else:
				items.request_from_stash.rpc_id(1, cat.player_id, index)
		elif items.get_stash(cat.player_id).size() >= items.stash_size:
			_info.text = "Stash is full."
		else:
			items.request_to_stash.rpc_id(1, cat.player_id, where, index)
	else:
		if where == "pack":
			items.request_equip.rpc_id(1, cat.player_id, index)  # (catnip etc. go to a QUICK USE slot)
		elif where == "quick":
			if inventory.pack.size() >= items.pack_size:
				_info.text = "Backpack is full."
			else:
				items.request_quick_to_pack.rpc_id(1, cat.player_id, index)
		elif where == "hand":
			if inventory.pack.size() >= items.pack_size:
				_info.text = "Backpack is full."
			else:
				items.request_put_away.rpc_id(1, cat.player_id, index)
		else:
			_info.text = "Loot pays out when you climb down the exit manhole."


## Hovering a slot shows what the item is.
func _on_slot_hover(button: Button) -> void:
	var item_id: String = button.get_meta("item")
	if item_id == "":
		return
	var data: ItemData = ItemManager.instance.catalog[item_id]
	_info.text = "%s: %s" % [data.display_name, data.description if data.description != "" else "-"]
