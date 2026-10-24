class_name SettingsMenu
extends Control
## MEOW-CITY 1999 — the SETTINGS screen (opened from the start menu and the pause menu).
## Attach to the root of scenes/ui/settings_menu.tscn. Expected node tree:
##   SettingsMenu (Control)      <- this script
##   ├── Dim (ColorRect)         <- darkens the game behind the menu
##   └── Panel (PanelContainer)
##       └── VBox (VBoxContainer)
##           ├── Title (Label)
##           ├── Tabs (HBoxContainer)    <- tab buttons are made by this script
##           ├── Rows (VBoxContainer)    <- setting rows are made by this script
##           ├── Hint (Label)            <- explains the setting under the mouse
##           └── Buttons (HBoxContainer)
##               ├── ResetButton
##               └── BackButton
##
## Each row is "NAME   <  VALUE  >". The rows come from the TABS list below, and the values
## live in the Settings autoload (scripts/settings.gd), which saves them to disk.

## Fired when the player presses BACK (or Esc), so whoever opened us can show itself again.
signal closed

## Every tab and its rows. Each row is a Dictionary:
##   setting  = variable name in scripts/settings.gd
##   label    = text on the left
##   hint     = one-line explanation shown at the bottom
##   choices  = [[value, "TEXT"], ...] for on/off style settings, OR
##   min/max/step + format for number settings. format: "percent", "times" (4x) or "number".
const TABS: Array = [
	["DISPLAY", [
		{"setting": "fullscreen", "label": "SCREEN", "choices": [[false, "WINDOW"], [true, "FULLSCREEN"]],
			"hint": "Play in a window or fill the whole screen."},
		{"setting": "window_scale", "label": "WINDOW SIZE", "min": 1, "max": 0, "step": 1, "format": "times",
			"hint": "How big the window is (the game is 320x240, made bigger)."},
		{"setting": "vsync", "label": "VSYNC", "choices": [[true, "ON"], [false, "OFF"]],
			"hint": "ON stops screen tearing. OFF can feel a tiny bit snappier."},
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
	]],
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
@onready var rows_box: VBoxContainer = $Panel/VBox/Rows
@onready var hint_label: Label = $Panel/VBox/Hint

var _tab_buttons: Array[Button] = []
var _current_tab: int = 0
## Value label for each setting on screen, so they can be refreshed: {setting: Label}.
var _value_labels: Dictionary = {}


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
	hide()


## Show the menu (on the tab used last time).
func open() -> void:
	show()
	_show_tab(_current_tab)
	_tab_buttons[_current_tab].grab_focus()


func close() -> void:
	hide()
	closed.emit()


## Esc = BACK. (This menu sits after the start and pause menus in the scene, so it sees
## Esc first and they don't also react to it.)
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _show_tab(index: int) -> void:
	_current_tab = index
	_tab_buttons[index].button_pressed = true
	for child in rows_box.get_children():
		child.queue_free()
	_value_labels.clear()
	for row in TABS[index][1]:
		rows_box.add_child(_make_row(row))
	hint_label.text = ""
	_refresh_values()


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
	return line


## "<" (direction -1) or ">" (direction +1) was pressed on a row.
func _step(row: Dictionary, direction: int) -> void:
	var current: Variant = Settings.get(row.setting)
	if row.has("choices"):
		# Cycle through the choices, wrapping around.
		var index := 0
		for i in row.choices.size():
			if row.choices[i][0] == current:
				index = i
		index = posmod(index + direction, row.choices.size())
		Settings.set_value(row.setting, row.choices[index][0])
	else:
		var top: Variant = _row_max(row)
		var next: Variant = clamp(current + row.step * direction, row.min, top)
		if typeof(current) == TYPE_FLOAT:
			next = snappedf(next, row.step)  # avoid 0.30000001-style drift
		Settings.set_value(row.setting, next)


## Number rows can have a max that depends on the PC (window size depends on the monitor).
func _row_max(row: Dictionary) -> Variant:
	if row.setting == "window_scale":
		return Settings.max_window_scale()
	return row.max


## Rewrite every value label from the current settings.
func _refresh_values() -> void:
	for tab in TABS:
		for row in tab[1]:
			if _value_labels.has(row.setting):
				_value_labels[row.setting].text = _value_text(row, Settings.get(row.setting))


func _value_text(row: Dictionary, value: Variant) -> String:
	if row.has("choices"):
		for choice in row.choices:
			if choice[0] == value:
				return choice[1]
		return str(value)
	match row.format:
		"percent":
			return "OFF" if value <= 0.001 else "%d%%" % roundi(value * 100.0)
		"times":
			return "%dx" % value
	return str(roundi(value))


func _on_reset_pressed() -> void:
	Settings.reset_to_defaults()
	hint_label.text = "Everything is back to normal."
