class_name SettingsMenu
extends Control
## CYPURRPUNK — the SETTINGS screen (opened from the start menu and the pause menu).
## Attach to the root of scenes/ui/settings_menu.tscn. Expected node tree:
##   SettingsMenu (Control)      <- this script
##   ├── Dim (ColorRect)         <- darkens the game behind the menu
##   └── Panel (PanelContainer)
##       └── VBox (VBoxContainer)
##           ├── Title (Label)
##           ├── Tabs (HBoxContainer)    <- tab buttons are made by this script
##           ├── Scroll (ScrollContainer) <- scrolls when a tab has many rows (KEYS)
##           │   └── Rows (VBoxContainer) <- setting rows are made by this script
##           ├── Hint (Label)            <- explains the setting under the mouse
##           └── Buttons (HBoxContainer)
##               ├── ResetButton
##               └── BackButton
##
## Each row is "NAME   <  VALUE  >". The rows come from the TABS list below, and the values
## live in the Settings autoload (scripts/settings.gd), which saves them to disk.
## The KEYS tab is different: one row per control, "NAME  [KEY 1] [KEY 2] [PAD]". Click a box,
## then press the new key (or controller button, in the PAD box). Those rows come from
## Controls.ACTIONS (scripts/controls.gd).
##
## With a controller: the d-pad / stick move the highlight (left / right between a row's < and >),
## A presses (A on < or > changes the value), B goes back, LB / RB switch tabs.

## Fired when the player presses BACK (or Esc), so whoever opened us can show itself again.
signal closed

## Every tab and its rows. A tab whose rows are the word "keys" is the key-binding tab.
## Each row is a Dictionary:
##   setting  = variable name in scripts/settings.gd
##   label    = text on the left
##   hint     = one-line explanation shown at the bottom
##   choices  = [[value, "TEXT"], ...] for on/off style settings, OR
##   min/max/step + format for number settings. format: "percent", "times" (4x) or "number".
const TABS: Array = [
	["DISPLAY", [
		{"setting": "fullscreen", "label": "SCREEN", "choices": [[false, "WINDOW"], [true, "FULLSCREEN"]],
			"hint": "FULLSCREEN fills your monitor at its max resolution."},
		# "choices": "resolutions" = the list comes from Settings.resolution_choices() (it depends on your monitor).
		{"setting": "resolution", "label": "RESOLUTION", "choices": "resolutions",
			"hint": "Window size. The biggest one is your monitor's max."},
		{"setting": "pixel_perfect", "label": "SCALING", "choices": [[true, "SHARP"], [false, "FILL"]],
			"hint": "SHARP = even pixels (may leave a border). FILL = as big as fits."},
		{"setting": "widescreen", "label": "ASPECT", "choices": [[true, "WIDE"], [false, "4:3"]],
			"hint": "WIDE fills widescreen + ultrawide monitors. Still 240 pixels tall."},
		{"setting": "vsync", "label": "VSYNC", "choices": [[true, "ON"], [false, "OFF"]],
			"hint": "ON stops screen tearing. OFF can feel a tiny bit snappier."},
		{"setting": "split_side_by_side", "label": "2-PLAYER SPLIT", "choices": [[true, "SIDE BY SIDE"], [false, "TOP + BOTTOM"]],
			"hint": "How the screen is cut when 2 players share this PC (couch co-op)."},
		{"setting": "field_of_view", "label": "FIELD OF VIEW", "min": 50.0, "max": 100.0, "step": 5.0, "format": "number",
			"hint": "How wide the camera sees. Higher = more city, smaller cat."},
	]],
	["SOUND", [
		{"setting": "master_volume", "label": "MASTER", "min": 0.0, "max": 1.0, "step": 0.1, "format": "percent",
			"hint": "Volume of everything."},
		{"setting": "music_volume", "label": "MUSIC", "min": 0.0, "max": 1.0, "step": 0.1, "format": "percent",
			"hint": "Volume of the music."},
		{"setting": "sfx_volume", "label": "SOUND FX", "min": 0.0, "max": 1.0, "step": 0.1, "format": "percent",
			"hint": "Volume of meows, engines, zaps and rain."},
	]],
	["CONTROLS", [
		{"setting": "mouse_speed", "label": "MOUSE SPEED", "min": 0.2, "max": 3.0, "step": 0.1, "format": "percent",
			"hint": "How fast the camera turns when you move the mouse."},
		{"setting": "invert_y", "label": "INVERT MOUSE Y", "choices": [[false, "OFF"], [true, "ON"]],
			"hint": "ON = push the mouse up to look down (flight-sim style)."},
		{"setting": "stick_speed", "label": "STICK SPEED", "min": 0.2, "max": 3.0, "step": 0.1, "format": "percent",
			"hint": "How fast the camera turns with the controller's right stick."},
		{"setting": "invert_stick_y", "label": "INVERT STICK Y", "choices": [[false, "OFF"], [true, "ON"]],
			"hint": "ON = push the right stick up to look down."},
		{"setting": "rumble", "label": "RUMBLE", "choices": [[true, "ON"], [false, "OFF"]],
			"hint": "Controller shakes when you get hit, shoot or extract."},
	]],
	["KEYS", "keys"],
	["EFFECTS", [
		{"setting": "crt_strength", "label": "CRT TV LOOK", "min": 0.0, "max": 1.0, "step": 0.25, "format": "percent",
			"hint": "Curved glass, scanlines and static of an old TV."},
		{"setting": "ps1_wobble", "label": "PS1 WOBBLE", "choices": [[true, "ON"], [false, "OFF"]],
			"hint": "Shaky polygons and warpy textures. Turn OFF if it bothers your eyes."},
		{"setting": "volumetric_fog", "label": "VOLUMETRIC FOG", "choices": [[true, "ON"], [false, "OFF"]],
			"hint": "Glowing fog around lights. Turn OFF for more speed on slow PCs."},
	]],
]

const HEADER_COLOR := Color(1, 0.35, 0.8)
const VALUE_COLOR := Color(0.4, 1, 1)

@onready var tabs_box: HBoxContainer = $Panel/VBox/Tabs
@onready var scroll: ScrollContainer = $Panel/VBox/Scroll
@onready var rows_box: VBoxContainer = $Panel/VBox/Scroll/Rows
@onready var hint_label: Label = $Panel/VBox/Hint

const KEYS_HINT := "Pick a box, then press the new key. PAD = controller."
const LISTEN_HINT := "Press a key or mouse button...  ESC = cancel, DELETE = clear."
const LISTEN_PAD_HINT := "Press a controller button...  START / ESC = cancel, DELETE = clear."
## Width of each key box on the KEYS tab (game pixels).
const KEY_BOX_WIDTH: float = 44.0

var _tab_buttons: Array[Button] = []
var _current_tab: int = 0
## Value label for each setting on screen, so they can be refreshed: {setting: Label}.
var _value_labels: Dictionary = {}
## The key boxes of each control on the KEYS tab: {action: [KEY 1, KEY 2, PAD]}.
var _key_buttons: Dictionary = {}
## While waiting for the player to press a new key: [action, slot]. Empty otherwise.
var _listening: Array = []


func _ready() -> void:
	$Panel/VBox/Buttons/BackButton.pressed.connect(close)
	$Panel/VBox/Buttons/ResetButton.pressed.connect(_on_reset_pressed)
	var group := ButtonGroup.new()  # only one tab can be "pressed" at a time
	for i in TABS.size():
		var tab := Button.new()
		tab.text = TABS[i][0]
		tab.toggle_mode = true
		tab.button_group = group
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_show_tab.bind(i))
		tabs_box.add_child(tab)
		_tab_buttons.append(tab)
	Settings.changed.connect(_refresh_values)
	Controls.changed.connect(_refresh_keys)
	scroll.follow_focus = true  # a controller moving down a long tab (KEYS) scrolls with it
	hide()


## Show the menu (on the tab used last time).
func open() -> void:
	show()
	_show_tab(_current_tab)
	_tab_buttons[_current_tab].grab_focus()


func close() -> void:
	_listening = []
	hide()
	closed.emit()


## Esc = BACK. (This menu sits after the start and pause menus in the scene, so it sees
## Esc first and they don't also react to it.)
## While a key box is waiting for a new key, the next key / click goes there instead.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _listening.is_empty():
		_listen_for_key(event)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_tab_left") or event.is_action_pressed("ui_tab_right"):
		# LB / RB: previous / next tab.
		get_viewport().set_input_as_handled()
		var direction := -1 if event.is_action_pressed("ui_tab_left") else 1
		_show_tab(posmod(_current_tab + direction, TABS.size()))
		_tab_buttons[_current_tab].grab_focus()
	# (Left / right only move the highlight between a row's < and >: press A on one to change it.)


func _show_tab(index: int) -> void:
	_current_tab = index
	_listening = []
	_tab_buttons[index].button_pressed = true
	for child in rows_box.get_children():
		child.queue_free()
	_value_labels.clear()
	_key_buttons.clear()
	scroll.scroll_vertical = 0
	if TABS[index][1] is String:  # the KEYS tab
		rows_box.add_child(_make_key_header())
		for entry in Controls.ACTIONS:
			rows_box.add_child(_make_key_row(entry))
		$Panel/VBox/Buttons/ResetButton.text = "RESET KEYS"
	else:
		for row in TABS[index][1]:
			rows_box.add_child(_make_row(row))
		$Panel/VBox/Buttons/ResetButton.text = "RESET"
	hint_label.text = ""
	_refresh_values()
	_refresh_keys()


## One "NAME   <  VALUE  >" line.
func _make_row(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 2)
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.mouse_entered.connect(func(): hint_label.text = row.hint)

	var name_label := Label.new()
	name_label.text = row.label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)

	var less := Button.new()
	less.text = "<"
	less.custom_minimum_size.x = 14
	less.pressed.connect(_step.bind(row, -1))
	less.focus_entered.connect(func(): hint_label.text = row.hint)
	line.add_child(less)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 64
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", VALUE_COLOR)
	line.add_child(value_label)
	_value_labels[row.setting] = value_label

	var more := Button.new()
	more.text = ">"
	more.custom_minimum_size.x = 14
	more.pressed.connect(_step.bind(row, 1))
	more.focus_entered.connect(func(): hint_label.text = row.hint)
	line.add_child(more)
	# Left / right hop between this row's own < and > and stop there (no jumping to the scrollbar).
	less.focus_neighbor_left = less.get_path_to(less)
	less.focus_neighbor_right = less.get_path_to(more)
	more.focus_neighbor_left = more.get_path_to(less)
	more.focus_neighbor_right = more.get_path_to(more)
	return line


## "<" (direction -1) or ">" (direction +1) was pressed on a row.
func _step(row: Dictionary, direction: int) -> void:
	var current: Variant = Settings.get(row.setting)
	if row.setting == "resolution" and Settings.fullscreen:
		# Fullscreen always runs at the monitor's own resolution.
		hint_label.text = "Fullscreen uses your monitor's max. Set SCREEN to WINDOW to pick."
		return
	if row.has("choices"):
		# Cycle through the choices, wrapping around.
		var choices := _row_choices(row)
		var index := 0
		for i in choices.size():
			if choices[i][0] == current:
				index = i
		index = posmod(index + direction, choices.size())
		Settings.set_value(row.setting, choices[index][0])
	else:
		var top: Variant = _row_max(row)
		var next: Variant = clamp(current + row.step * direction, row.min, top)
		if typeof(current) == TYPE_FLOAT:
			next = snappedf(next, row.step)  # avoid 0.30000001-style drift
		Settings.set_value(row.setting, next)


## Number rows could have a max that depends on the PC; add special cases here.
func _row_max(row: Dictionary) -> Variant:
	return row.max


## A row's [[value, "TEXT"], ...] list. Rows whose "choices" is a word get it from the PC
## ("resolutions" = the window sizes that fit your monitor).
func _row_choices(row: Dictionary) -> Array:
	if row.choices is String and row.choices == "resolutions":
		var list: Array = []
		for size in Settings.resolution_choices():
			list.append([size, _size_text(size)])
		return list
	return row.choices


func _size_text(size: Vector2i) -> String:
	return "%dx%d" % [size.x, size.y]


## Rewrite every value label from the current settings.
func _refresh_values() -> void:
	for tab in TABS:
		if tab[1] is String:
			continue  # the KEYS tab has no setting rows
		for row in tab[1]:
			if _value_labels.has(row.setting):
				_value_labels[row.setting].text = _value_text(row, Settings.get(row.setting))


func _value_text(row: Dictionary, value: Variant) -> String:
	if row.setting == "resolution":
		return _size_text(Settings.monitor_resolution() if Settings.fullscreen else value)
	if row.has("choices"):
		for choice in _row_choices(row):
			if choice[0] == value:
				return choice[1]
		return str(value)
	match row.format:
		"percent":
			return "OFF" if value <= 0.001 else "%d%%" % roundi(value * 100.0)
		"times":
			return "%dx" % value
	return str(roundi(value))


## RESET puts back the keys on the KEYS tab, and every other setting on the other tabs.
func _on_reset_pressed() -> void:
	_listening = []
	if TABS[_current_tab][1] is String:
		Controls.reset_to_defaults()
		hint_label.text = "All keys are back to normal."
	else:
		Settings.reset_to_defaults()
		hint_label.text = "Everything is back to normal."


# --- The KEYS tab ---

## The "KEY 1  KEY 2  PAD" titles above the key boxes.
func _make_key_header() -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 2)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)
	for title in ["KEY 1", "KEY 2", "PAD"]:
		var label := Label.new()
		label.text = title
		label.custom_minimum_size.x = KEY_BOX_WIDTH
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", HEADER_COLOR)
		line.add_child(label)
	return line


## One "NAME   [KEY 1] [KEY 2] [PAD]" line for a control from Controls.ACTIONS.
func _make_key_row(entry: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 2)
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	line.mouse_entered.connect(_show_keys_hint)

	var name_label := Label.new()
	name_label.text = entry.label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)

	var boxes: Array[Button] = []
	for slot in Controls.SLOTS + 1:  # 2 keyboard boxes + the controller box
		var box := Button.new()
		box.custom_minimum_size.x = KEY_BOX_WIDTH
		box.clip_text = true
		box.add_theme_color_override("font_color", VALUE_COLOR)
		box.pressed.connect(_start_listening.bind(entry.action, slot))
		box.focus_entered.connect(_show_keys_hint)
		line.add_child(box)
		boxes.append(box)
	_key_buttons[entry.action] = boxes
	return line


func _show_keys_hint() -> void:
	if _listening.is_empty():
		hint_label.text = KEYS_HINT


## A key box was clicked: the next key / mouse button (or controller button, for the PAD box)
## pressed goes into it.
func _start_listening(action: String, slot: int) -> void:
	_listening = [action, slot]
	_refresh_keys()
	hint_label.text = LISTEN_PAD_HINT if Controls.is_pad_slot(slot) else LISTEN_HINT


## Called by _input while a key box is waiting. Esc / START cancels, Delete / Backspace empties
## the box, anything else (that can be bound) becomes the new key. Keyboard boxes only take
## keys and mouse buttons; the PAD box only takes controller buttons, sticks and triggers.
func _listen_for_key(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return  # moving the mouse is fine
	get_viewport().set_input_as_handled()  # don't let the press also click a button
	var action: String = _listening[0]
	var slot: int = _listening[1]
	if event.is_action_pressed("pause"):
		_listening = []
		_refresh_keys()
		hint_label.text = KEYS_HINT
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_DELETE, KEY_BACKSPACE]:
			_listening = []
			Controls.set_binding(action, slot, "")
			hint_label.text = "%s key %d cleared." % [Controls.label_of(action), slot + 1]
			return
	var key_name := Controls.name_from_event(event)
	if key_name == "" or key_name.begins_with("Pad ") != Controls.is_pad_slot(slot):
		return  # a key release, or the wrong kind of key for this box, etc. - keep waiting
	_listening = []
	var taken_from := Controls.set_binding(action, slot, key_name)
	if taken_from != "":
		hint_label.text = "%s was taken from %s - give it a new key!" % [Controls.display_name(key_name), taken_from]
	else:
		hint_label.text = "%s = %s" % [Controls.label_of(action), Controls.display_name(key_name)]


## Rewrite every key box from the current keys.
func _refresh_keys() -> void:
	for action in _key_buttons:
		for slot in Controls.SLOTS + 1:
			var box: Button = _key_buttons[action][slot]
			if _listening == [action, slot]:
				box.text = "..."
			else:
				box.text = Controls.display_name(Controls.binding(action, slot))
