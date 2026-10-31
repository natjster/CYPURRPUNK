class_name OnScreenKeyboard
extends Control
## CYPURRPUNK — a little ON-SCREEN KEYBOARD so you can type with a controller
## (your cat's name in MY CAT, the city # and the address on the ONLINE screen).
##
## You never put this on a node by hand. A menu hooks one onto a text box (LineEdit) with
##   OnScreenKeyboard.hook(my_line_edit, self)              # letters + numbers
##   OnScreenKeyboard.hook(seed_box, self, OnScreenKeyboard.DIGITS)
## That HIDES the text box and puts a button in its place (the "field": it shows the text, or the
## box's grey placeholder). The text box stays as the place the text is kept, so the menu still
## reads my_line_edit.text as before. (Why? Godot 4.7 never lets the d-pad / stick highlight a
## text box, so a controller could never get to it - or past it.)
##   - the d-pad / stick highlight the field like any button
##   - A (or Enter, or a click) on it opens this keyboard over the menu
##   - in the keyboard: d-pad / stick = pick a key, A = type it, B = delete a letter,
##     START = done (or the DONE key). A real keyboard types straight in too
##     (Backspace = delete, Enter / Esc = done).
##
##   +--------------------------------+
##   |  WHISKERS_                     |   <- what you've typed so far
##   |  A B C D E F G H I J           |
##   |  K L M N O P Q R S T           |
##   |  U V W X Y Z - ' . !           |
##   |  1 2 3 4 5 6 7 8 9 0           |
##   |  [SPACE] [DEL] [PASTE] [DONE]  |
##   |  B = DELETE   START = DONE     |
##   +--------------------------------+
##
## PASTE (or Ctrl+V) adds what's on the clipboard, keeping only characters this keyboard can type.
##
## The layouts are the LETTERS / DIGITS / ADDRESS lists below: change a row's characters there.

## The keyboard closed (DONE, START, or B with nothing left to delete).
signal closed

## Every key row (one character per key). The SPACE / DEL / DONE row is added after them.
const LETTERS: Array[String] = ["ABCDEFGHIJ", "KLMNOPQRST", "UVWXYZ-'.!", "1234567890"]
## Numbers only (the city #).
const DIGITS: Array[String] = ["12345", "67890"]
## A room code or network address (MEOW-499A-21B0, 192.168.1.20 or 192.168.1.20:7777).
const ADDRESS: Array[String] = ["1234567890", "ABCDEF", "MOW-.:"]

## The look (same as the other menus).
const MENU_THEME: Theme = preload("res://ui/menu_theme.tres")
const KEY_SIZE := Vector2(16, 14)
const TEXT_COLOR := Color(1, 0.8, 0.45)
const HINT_COLOR := Color(0.6, 0.55, 0.7)

## The (hidden) text box that keeps the text.
var target: LineEdit
## The button shown where the text box was. Menus point their focus neighbours at this.
var field: Button
## Whether the keyboard has a SPACE key (not for numbers / addresses).
var with_space: bool = true

var _rows: Array = []  # Array of Array[Button], top to bottom (for moving the highlight)
var _text_label: Label
var _hint: Label
## Every character a key on this keyboard types (a real keyboard can only type these too).
var _allowed: String = ""


## Hook a keyboard onto a text box. parent = the menu it appears over (full screen).
static func hook(line_edit: LineEdit, parent: Control, layout: Array[String] = LETTERS) -> OnScreenKeyboard:
	var keyboard := OnScreenKeyboard.new()
	keyboard.name = "Keyboard_" + line_edit.name
	keyboard.target = line_edit
	keyboard.with_space = layout == LETTERS
	parent.add_child(keyboard)
	keyboard._build(layout)
	keyboard._make_field()
	return keyboard


## Swap the text box for a button in the same spot (same size, same place in its row / column).
func _make_field() -> void:
	field = Button.new()
	field.name = target.name + "Field"
	field.custom_minimum_size = target.custom_minimum_size
	field.size_flags_horizontal = target.size_flags_horizontal
	field.size_flags_vertical = target.size_flags_vertical
	field.clip_text = true
	if target.has_theme_font_size_override("font_size"):
		field.add_theme_font_size_override("font_size", target.get_theme_font_size("font_size"))
	field.pressed.connect(open)
	var holder := target.get_parent()
	holder.add_child(field)
	holder.move_child(field, target.get_index())
	if not holder is Container:
		field.position = target.position
		field.size = target.size
	target.hide()
	_update_field()


## Keep the field showing the text (menus change target.text themselves, e.g. switching cats).
func _process(_delta: float) -> void:
	_update_field()


func _update_field() -> void:
	if field == null:
		return
	var empty := target.text.is_empty()
	var shown := target.placeholder_text if empty else target.text
	if field.text != shown:
		field.text = shown
		field.modulate = Color(1, 1, 1, 0.55) if empty else Color.WHITE


## Open the keyboard (e.g. a menu wants a name typed right now).
func open() -> void:
	move_to_front()  # drawn over everything else in the menu (and hears the buttons first)
	show()
	_refresh()
	_focus(0, 0)


func close() -> void:
	if not visible:
		return
	hide()
	if field != null and field.is_visible_in_tree():
		field.grab_focus()  # back on the field
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouse:
		return  # clicking the keys works as normal
	if event is InputEventKey and event.pressed and _typed_key(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if target.text.is_empty():
			close()
		else:
			_backspace()
	elif event.is_action_pressed("ui_accept"):
		return  # Godot presses the highlighted key
	else:
		var pushed := _direction(event)
		if pushed != Vector2i.ZERO:
			_move(pushed)
		if pushed != Vector2i.ZERO or event is InputEventJoypadMotion or event is InputEventKey:
			# Keep everything inside the keyboard (no highlight escaping to the menu behind,
			# no typing into the box with a real keyboard while this is up).
			get_viewport().set_input_as_handled()


## A real keyboard: letters / numbers type, Backspace deletes, Ctrl+V pastes, Enter = done. True
## if used. (Arrow keys, Esc etc. are left for the menu controls.)
func _typed_key(event: InputEventKey) -> bool:
	if event.is_command_or_control_pressed() and event.keycode == KEY_V:
		_paste()
		return true
	if event.keycode == KEY_BACKSPACE:
		_backspace()
		return true
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		close()
		return true
	var character := char(event.unicode) if event.unicode > 0 else ""
	if character == "" or not character.to_upper() in _allowed:
		return false
	_type(character)
	return true


## Which way this press moves the highlight. (A held stick already only arrives ONCE per push:
## scripts/ui/game_screen.gd drops the "still held" messages while a menu is up.)
func _direction(event: InputEvent) -> Vector2i:
	var directions := {"ui_up": Vector2i.UP, "ui_down": Vector2i.DOWN, "ui_left": Vector2i.LEFT, "ui_right": Vector2i.RIGHT}
	for action in directions:
		if event.is_action_pressed(action, true):
			return directions[action]
	return Vector2i.ZERO


## Move the highlight one key (wrapping around the edges).
func _move(step: Vector2i) -> void:
	var at := _focused_key()
	var row := posmod(at.y + step.y, _rows.size())
	var column := at.x
	if step.x != 0:
		column = posmod(at.x + step.x, (_rows[row] as Array).size())
	elif row != at.y:
		# Up / down onto a row with a different number of keys: the key in about the same place.
		var from_size := (_rows[at.y] as Array).size()
		var to_size := (_rows[row] as Array).size()
		column = clampi(roundi((at.x + 0.5) * to_size / float(from_size) - 0.5), 0, to_size - 1)
	_focus(column, row)


## Which key has the highlight: Vector2i(column, row).
func _focused_key() -> Vector2i:
	var focused := get_viewport().gui_get_focus_owner()
	for row in _rows.size():
		var column: int = (_rows[row] as Array).find(focused)
		if column != -1:
			return Vector2i(column, row)
	return Vector2i.ZERO


func _focus(column: int, row: int) -> void:
	(_rows[row][column] as Button).grab_focus()


func _type(character: String) -> void:
	if target.max_length > 0 and target.text.length() >= target.max_length:
		return
	_set_text(target.text + character)


func _backspace() -> void:
	_set_text(target.text.left(-1))


## Add the clipboard's text, skipping anything this keyboard can't type.
func _paste() -> void:
	var text := target.text
	for character in DisplayServer.clipboard_get().strip_edges():
		if character.to_upper() in _allowed:
			text += character
	if target.max_length > 0:
		text = text.left(target.max_length)
	_set_text(text)


## Change the text box (and tell its menu, as if it was typed).
func _set_text(text: String) -> void:
	target.text = text
	target.caret_column = text.length()
	target.text_changed.emit(text)
	_refresh()


func _refresh() -> void:
	_text_label.text = target.text + "_"
	_hint.text = "%s = DELETE   %s = DONE" % [Controls.display_name("Pad B"), Controls.display_name("Pad Start")]


# --- Building it (game pixels: the menus are laid out for a 320x240 screen) ---

func _build(layout: Array[String]) -> void:
	hide()
	theme = MENU_THEME  # the menus' neon boxes, small pixel-menu text
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # no clicking the menu behind
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	_text_label = Label.new()
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.add_theme_color_override("font_color", TEXT_COLOR)
	box.add_child(_text_label)

	_allowed = "".join(PackedStringArray(layout)) +(" " if with_space else "")
	for characters in layout:
		var row := _row(box)
		var keys: Array[Button] = []
		for character in characters:
			keys.append(_key(row, character, _type.bind(character)))
		_rows.append(keys)
	var row := _row(box)
	var bottom: Array[Button] = []
	if with_space:
		bottom.append(_key(row, "SPACE", _type.bind(" "), 50))
	bottom.append(_key(row, "DEL", _backspace, 34))
	bottom.append(_key(row, "PASTE", _paste, 42))
	bottom.append(_key(row, "DONE", close, 42))
	_rows.append(bottom)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", HINT_COLOR)
	box.add_child(_hint)


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	return row


func _key(row: HBoxContainer, text: String, action: Callable, width: float = KEY_SIZE.x) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, KEY_SIZE.y)
	button.add_theme_font_size_override("font_size", 8)
	button.pressed.connect(action)
	row.add_child(button)
	return button
