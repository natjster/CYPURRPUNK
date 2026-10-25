extends Control
## INVENTORY SCREEN — press Tab or I to open/close (Esc closes too).
## Attach to the "Inventory" Control under PS1Overlay in main.tscn. It builds its own
## buttons when the game starts, so the scene only needs the empty node.
##
##   PAWS      what you're holding. Click = put it in the backpack.
##   BACKPACK  held items you're carrying but not using. Click = take it into your paws.
##   LOOT BAG  fish etc. Delivered at the drop-off.
##   Right-click any item = drop it on the ground in front of you.
##
## The screen only ASKS the item system (ItemManager) to move things; the host decides,
## and the screen redraws itself from the result. So it's always in sync in multiplayer.

const SLOT_SIZE := Vector2(70, 16)

var _paw_buttons: Array[Button] = []    # [left paw, right paw] as shown on screen
var _pack_buttons: Array[Button] = []
var _bag_buttons: Array[Button] = []
var _pack_title: Label
var _bag_title: Label
var _info: Label
var _last_key := ""


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # clicks on the dim background don't reach the game

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(36, 24)
	panel.size = Vector2(248, 186)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_label("INVENTORY", Vector2(36, 27), 248, 12, Color(1, 0.4, 0.8))

	_label("LEFT PAW", Vector2(80, 46), SLOT_SIZE.x, 8, Color(0.7, 0.7, 0.8))
	_label("RIGHT PAW", Vector2(170, 46), SLOT_SIZE.x, 8, Color(0.7, 0.7, 0.8))
	_paw_buttons.append(_slot(Vector2(80, 56), "hand", 1))   # left paw = hands[1]
	_paw_buttons.append(_slot(Vector2(170, 56), "hand", 0))  # right paw = hands[0]

	_pack_title = _label("BACKPACK", Vector2(36, 78), 248, 8, Color(0.6, 0.85, 1))
	for i in ItemManager.instance.pack_size:
		var column := i % 3
		var row := i / 3
		_pack_buttons.append(_slot(Vector2(47 + column * (SLOT_SIZE.x + 6), 88 + row * (SLOT_SIZE.y + 3)), "pack", i))

	var pack_rows := ceili(ItemManager.instance.pack_size / 3.0)
	var bag_top := 88 + pack_rows * (SLOT_SIZE.y + 3) + 6
	_bag_title = _label("LOOT BAG", Vector2(36, bag_top), 248, 8, Color(0.45, 1, 0.55))
	for i in ItemManager.instance.bag_size:
		_bag_buttons.append(_slot(Vector2(47 + (i % 3) * (SLOT_SIZE.x + 6), bag_top + 10 + (i / 3) * (SLOT_SIZE.y + 3)), "bag", i))

	_info = _label("", Vector2(40, 186), 240, 8, Color(1, 1, 1, 0.85))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size.y = 22


func _input(event: InputEvent) -> void:
	var cat := ItemManager.instance.local_cat()
	if event.is_action_pressed("inventory") and cat != null and not PauseMenu.is_open and not NpcDialog.is_open:
		_set_open(not visible)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	visible = open
	_last_key = ""
	var cat := ItemManager.instance.local_cat()
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_info.text = "Click: equip / put away   Right-click: drop   %s: close" % Controls.key_text("inventory")
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
	var inventory := items.get_inventory(cat.name.to_int())
	var key := str(inventory)
	if key == _last_key:
		return
	_last_key = key  # only redraw when something changed

	var hands: Array = inventory.hands
	_fill(_paw_buttons[0], hands[1])
	_fill(_paw_buttons[1], hands[0])
	if hands[0] != "" and (items.catalog[hands[0]] as ItemData).hands == 2:
		_paw_buttons[1].text = "BOTH PAWS"  # a 2-paw item fills both slots
	for i in _pack_buttons.size():
		_fill(_pack_buttons[i], inventory.pack[i] if i < inventory.pack.size() else "")
	for i in _bag_buttons.size():
		_fill(_bag_buttons[i], inventory.bag[i] if i < inventory.bag.size() else "")
	_pack_title.text = "BACKPACK  %d/%d" % [inventory.pack.size(), items.pack_size]
	_bag_title.text = "LOOT BAG  %d/%d  (deliver at the drop-off)" % [items.bag_used(cat.name.to_int()), items.bag_size]


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


func _slot(at: Vector2, where: String, index: int) -> Button:
	var button := Button.new()
	button.position = at
	button.size = SLOT_SIZE
	button.focus_mode = Control.FOCUS_NONE  # so Tab closes the screen instead of moving focus
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 8)
	# Dark slot box with a neon edge (brighter when the mouse is over it).
	button.add_theme_stylebox_override("normal", _slot_style(Color(0.55, 0.35, 0.85, 0.8)))
	button.add_theme_stylebox_override("hover", _slot_style(Color(1, 0.4, 0.8)))
	button.add_theme_stylebox_override("pressed", _slot_style(Color(1, 1, 1)))
	button.set_meta("item", "")
	button.gui_input.connect(_on_slot_input.bind(button, where, index))
	button.mouse_entered.connect(_on_slot_hover.bind(button))
	add_child(button)
	return button


func _slot_style(edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.13, 0.95)
	style.border_color = edge
	style.set_border_width_all(1)
	return style


func _label(text: String, at: Vector2, width: float, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(width, font_size + 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## Left-click = equip / put away; right-click = drop.
func _on_slot_input(event: InputEvent, button: Button, where: String, index: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or button.get_meta("item") == "":
		return
	var items := ItemManager.instance
	var cat := items.local_cat()
	if cat == null or not cat.is_controlled:
		_info.text = "Can't do that from inside the car."
		return
	if click.button_index == MOUSE_BUTTON_RIGHT:
		items.request_drop_item.rpc_id(1, where, index, items.ground_in_front_of(cat))
	elif click.button_index == MOUSE_BUTTON_LEFT:
		if where == "pack":
			items.request_equip.rpc_id(1, index)
		elif where == "hand":
			if items.get_inventory(cat.name.to_int()).pack.size() >= items.pack_size:
				_info.text = "Backpack is full."
			else:
				items.request_stash.rpc_id(1, index)
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
