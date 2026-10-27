class_name CatCreator
extends Control
## CYPURRPUNK — the CHOOSE YOUR CAT screen (the character creator).
## Attach to the "CatCreator" Control under PS1Overlay in main.tscn; it builds everything
## itself, so the scene only needs the empty node.
##
## Two ways in:
##   - START MENU > PLAY (open(false)): pick one of your cats or make a new one, name it,
##     dress it, then NEXT (on to SOLO / MULTIPLAYER, main_menu.gd). BACK = the start menu.
##   - PAUSE MENU > MY CAT (open(true, seat)), during a game: restyle / rename the cat you're
##     playing. No switching cats mid-game. DONE = back to the pause menu.
##     Couch players 2-4 get it too (from their own pause menu, scripts/ui/player_pause.gd, or
##     A on their row of the landing page): it then edits THEIR saved cat, and only their
##     controller drives the screen (scripts/ui/game_screen.gd _menu_driver).
##
## Controller: up / down picks a row, LEFT / RIGHT changes it (or A on its < >), DONE / NEXT at
## the bottom. B = back.
##
##   CHOOSE YOUR CAT
##   <  [ WHISKERS     ]  >  2/3  [NEW] [DELETE]   <- your cats (Settings.cats); type the name
##   FUR       <  [colour]  >        +-----------+
##   MARKINGS  <  [colour]  >        |  your cat |   <- live 3D preview, slowly turning
##   EYES ...  NOSE ...              |           |
##   HAT       <  FEDORA    >        +-----------+
##   FACE ...  NECK ...
##   [ BACK ]     [ RANDOM ]     [ NEXT ]
##
## The look rows come from the framework (scripts/cat/cat_look.gd): one colour row per
## CatLook.COLOR_KEYS (colours from res://cat_parts/palette.tres) and one accessory row per
## CatLook.SLOTS (every CatPart card in res://cat_parts/). New hats or colours show up here
## by themselves.
##
## Every change is saved straight away (Settings.cats, in settings.cfg). Each cat also has its
## own cash and stash (player_profile.gd); DELETE throws those away too (it asks twice).
## In a game, your cat changes too and everyone sees it (cat_player.gd listens to Settings.changed).

## BACK / DONE (or Esc) was pressed, so whoever opened us can show itself again.
signal closed
## NEXT was pressed on the start-menu version (main_menu.gd shows SOLO / MULTIPLAYER).
signal next_pressed

const CAT_MODEL: PackedScene = preload("res://scenes/cat_model.tscn")
## Menu names for the colour keys and slots.
const LABELS: Dictionary = {
	"fur": "FUR", "markings": "MARKINGS", "eyes": "EYES", "nose": "NOSE",
	"hat": "HAT", "face": "FACE", "neck": "NECK",
}
const HEADER_COLOR := Color(1, 0.35, 0.8)
const VALUE_COLOR := Color(0.4, 1, 1)
const NOTE_COLOR := Color(0.6, 0.55, 0.7)
const WARN_COLOR := Color(1, 0.8, 0.45)
## How fast the preview cat turns (radians per second).
const SPIN_SPEED: float = 0.8
## Longest cat name (it floats over your cat).
const MAX_NAME_LENGTH: int = 12
## Names handed out when someone on a controller presses NEXT without typing one (max 12 letters).
const PAD_NAMES: Array[String] = [
	"WHISKERS", "MITTENS", "SOCKS", "PICKLES", "NOODLE", "BISCUIT", "SARDINE", "TUNA",
	"CHAIRMEOW","PURRSIA", "SMUDGE", "GIZMO", "NACHO", "PEPPER", "ZIGGY", "MOCHI",
]

## Which player on this computer it's open for (0 = player 1, 1-3 = couch players 2-4).
var seat: int = 0
## Couch player's MY CAT: reopen their own small pause menu when it closes (game.gd).
var back_to_player_pause: bool = false
## The look being edited (a CatLook dictionary).
var _look: Dictionary = {}
## key -> the value Label (accessory rows) or ColorRect swatch (colour rows).
var _value_nodes: Dictionary = {}
var _preview_cat: Node3D
var _in_game: bool = false
var _title: Label
var _name_edit: LineEdit
var _count_label: Label
var _switch_buttons: Array[Button] = []  # <, >, NEW, DELETE: hidden during a game
var _delete_button: Button
var _delete_armed_until: float = 0.0  # DELETE asks "SURE?" first; this is when that runs out
var _back_button: Button
var _next_button: Button
var _note: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	hide()
	_rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)  # dark enough that the menu behind doesn't show through
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(14, 14)
	panel.size = Vector2(292, 216)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_title = _label("CHOOSE YOUR CAT", Vector2(14, 16), 292, 16, HEADER_COLOR)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_build_cat_row(38)

	# One row per colour, then one per accessory slot.
	var y := 60.0
	for key in CatLook.COLOR_KEYS:
		_add_row(key, y, true)
		y += 19
	for slot in CatLook.SLOTS:
		_add_row(slot, y, false)
		y += 19

	_build_preview(Vector2(178, 60), Vector2(118, 130))

	_back_button = _button("BACK", Vector2(24, 198), Vector2(70, 16))
	_back_button.pressed.connect(close)
	var random := _button("RANDOM", Vector2(125, 198), Vector2(70, 16))
	random.pressed.connect(_randomize)
	_next_button = _button("NEXT", Vector2(226, 198), Vector2(70, 16))
	_next_button.pressed.connect(_on_next_pressed)
	_note = _label("", Vector2(14, 216), 292, 8, NOTE_COLOR)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Show the screen. in_game = opened from the pause menu (restyle only, no switching cats).
## for_seat = which player's cat (0 = player 1; 1-3 = a couch player: restyle only, like in_game).
func open(in_game: bool = false, for_seat: int = 0) -> void:
	seat = for_seat
	in_game = in_game or seat > 0  # (a couch player's cat: no switching cats here either)
	_in_game = in_game
	if seat > 0 and Seats.saved_cat(seat).is_empty():
		seat = 0  # (shouldn't happen: every couch player plays a saved cat)
	if Settings.current_cat().is_empty():
		Settings.new_cat()  # first time playing: start a cat for them to name
	_title.text = ("MY CAT - PLAYER %d" % (seat + 1) if seat > 0 else "MY CAT") if in_game else "CHOOSE YOUR CAT"
	if in_game:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for button in _switch_buttons:
		button.visible = not in_game
	_count_label.visible = not in_game
	_back_button.visible = not in_game
	_next_button.text = "DONE" if in_game else "NEXT"
	_disarm_delete()
	_load_current_cat()
	show()
	_next_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()
	seat = 0
	back_to_player_pause = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	# (Stick / d-pad / arrow keys only move the highlight between buttons, like any menu. A row
	# changes when you PRESS its < or > button: A on a controller, Enter / click on keyboard.)


func _process(delta: float) -> void:
	if not visible:
		return
	if _preview_cat != null:
		_preview_cat.rotation.y += SPIN_SPEED * delta
	if _delete_armed_until > 0.0 and Time.get_ticks_msec() / 1000.0 > _delete_armed_until:
		_disarm_delete()


# --- Your cats: switching, naming, new, delete ---

## The saved cat this screen is editing: player 1's current cat, or a couch player's own.
func _editing_cat() -> Dictionary:
	return Seats.saved_cat(seat) if seat > 0 else Settings.current_cat()


## Save changes ({"name": ..} / {"look": ..}) onto the cat being edited. Settings.changed then
## tells that player's cat in the game to wear them (cat_player.gd).
func _update_cat(changes: Dictionary) -> void:
	if seat == 0:
		Settings.update_current_cat(changes)
		return
	_editing_cat().merge(changes, true)  # (changes the cat inside Settings.cats)
	Settings.apply()
	Settings.save_settings()


## Fill the screen from the cat we're playing as.
func _load_current_cat() -> void:
	var cat := _editing_cat()
	_look = CatLook.default_look().merged(CatLook.clean(cat.get("look", {})), true)
	_name_edit.text = cat.get("name", "")
	var index := Settings.cats.find(cat)
	_count_label.text = "%d/%d" % [index + 1, Settings.cats.size()]
	_set_note("Your cats are saved automatically", NOTE_COLOR)
	_refresh()


## "<" / ">" next to the name: play as your previous / next cat.
func _switch_cat(direction: int) -> void:
	if Settings.cats.size() < 2:
		return
	var index := Settings.cats.find(Settings.current_cat())
	Settings.select_cat(Settings.cats[posmod(index + direction, Settings.cats.size())].id)
	_disarm_delete()
	_load_current_cat()


func _new_cat() -> void:
	Settings.new_cat()
	_disarm_delete()
	_load_current_cat()
	_name_edit.grab_focus()
	_set_note("A new cat! Give it a name.", WARN_COLOR)


## DELETE: the first click asks "SURE?", the second (within 3 seconds) deletes the cat AND its
## saved cash + stash. There's always at least one cat: deleting the last one starts a new one.
func _on_delete_pressed() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now > _delete_armed_until:
		_delete_armed_until = now + 3.0
		_delete_button.text = "SURE?"
		_set_note("Click again to delete this cat, its cash and its stash.", WARN_COLOR)
		return
	var cat_id: String = Settings.current_cat_id
	PlayerProfile.forget_cat(cat_id)
	Settings.delete_cat(cat_id)
	if Settings.cats.is_empty():
		Settings.new_cat()
	_disarm_delete()
	_load_current_cat()


func _disarm_delete() -> void:
	_delete_armed_until = 0.0
	if _delete_button != null:
		_delete_button.text = "DELETE"


## Typing in the name box: save it as you type.
func _on_name_changed(new_text: String) -> void:
	_update_cat({"name": new_text.strip_edges()})


## NEXT needs a name. (DONE in a game just closes.)
func _on_next_pressed() -> void:
	if _in_game:
		close()
		return
	if str(Settings.current_cat().get("name", "")).is_empty():
		if Controls.using_pad:
			# A controller can't type: pick a name for them (they can retype it on a keyboard later).
			_name_edit.text = PAD_NAMES[_rng.randi_range(0, PAD_NAMES.size() - 1)]
			_on_name_changed(_name_edit.text)
		else:
			_set_note("Name your cat first!", WARN_COLOR)
			_name_edit.grab_focus()
			return
	hide()
	next_pressed.emit()


func _set_note(text: String, color: Color) -> void:
	_note.text = text
	_note.add_theme_color_override("font_color", color)


# --- Changing the look ---

## "<" (-1) or ">" (+1) on a row: the previous / next colour or accessory.
func _step(key: String, direction: int) -> void:
	var options: Array = _options_for(key)
	if options.is_empty():
		return
	var index := options.find(_look.get(key, options[0]))
	_look[key] = options[posmod(index + direction, options.size())]
	_changed()


func _randomize() -> void:
	_look = CatLook.random_look(_rng)
	_changed()


## Save, and redraw the rows and the preview.
func _changed() -> void:
	_update_cat({"look": _look.duplicate()})
	_refresh()


func _refresh() -> void:
	for key in _value_nodes:
		var node: Control = _value_nodes[key]
		if node is ColorRect:
			node.color = _look.get(key, Color.WHITE)
		else:
			var part: CatPart = CatLook.parts().get(_look.get(key, ""))
			(node as Label).text = part.display_name if part != null else "NONE"
	CatLook.apply(_preview_cat, _look)


## The choices for a row: the palette's colours, or the slot's accessory ids ("" = none).
func _options_for(key: String) -> Array:
	if key in CatLook.COLOR_KEYS:
		return Array(CatLook.palette().colors_for(key))
	return Array(CatLook.part_ids_for(key))


## The top row: <  [name box]  >  1/3  [NEW] [DELETE]
func _build_cat_row(y: float) -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(24, y)
	row.size = Vector2(272, 17)
	row.add_theme_constant_override("separation", 3)
	add_child(row)
	var left := _row_button("<", 14, row)
	left.pressed.connect(_switch_cat.bind(-1))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(112, 0)
	_name_edit.placeholder_text = "NAME YOUR CAT"
	_name_edit.max_length = MAX_NAME_LENGTH
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.add_theme_font_size_override("font_size", 8)
	_name_edit.text_changed.connect(_on_name_changed)
	row.add_child(_name_edit)
	var right := _row_button(">", 14, row)
	right.pressed.connect(_switch_cat.bind(1))
	_count_label = _row_label("1/1", 26, NOTE_COLOR)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_count_label)
	var new_button := _row_button("NEW", 38, row)
	new_button.pressed.connect(_new_cat)
	_delete_button = _row_button("DELETE", 50, row)
	_delete_button.pressed.connect(_on_delete_pressed)
	_switch_buttons.assign([left, right, new_button, _delete_button])


func _row_button(text: String, width: float, row: HBoxContainer) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 15)
	button.add_theme_font_size_override("font_size", 8)
	row.add_child(button)
	return button


# --- Building the screen ---

## NAME   <  value  >   (an HBoxContainer, so everything lines up vertically)
func _add_row(key: String, y: float, is_color: bool) -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(24, y)
	row.size = Vector2(152, 16)
	row.add_theme_constant_override("separation", 3)
	add_child(row)
	var name_label := _row_label(LABELS.get(key, key.to_upper()), 60, Color(0.85, 0.85, 0.95))
	row.add_child(name_label)
	var left := _button("<", Vector2.ZERO, Vector2(14, 15))
	remove_child(left)
	row.add_child(left)
	left.pressed.connect(_step.bind(key, -1))  # pressed (A / Enter / click) = previous option
	if is_color:
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(52, 9)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(swatch)
		_value_nodes[key] = swatch
	else:
		var value := _row_label("", 52, VALUE_COLOR)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.clip_text = true
		row.add_child(value)
		_value_nodes[key] = value
	var right := _button(">", Vector2.ZERO, Vector2(14, 15))
	remove_child(right)
	row.add_child(right)
	right.pressed.connect(_step.bind(key, 1))  # pressed = next option
	# Left / right on a row hops between its own < and > (and stops at the ends), so the
	# highlight never jumps off to a far-away button. Up / down still go to the rows above / below.
	left.focus_neighbor_left = left.get_path_to(left)
	left.focus_neighbor_right = left.get_path_to(right)
	right.focus_neighbor_left = right.get_path_to(left)
	right.focus_neighbor_right = right.get_path_to(right)


## A label for inside a row: fixed width, vertically centred.
func _row_label(text: String, width: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A little 3D stage with its own world: a cat model, a camera and some lights.
func _build_preview(at: Vector2, preview_size: Vector2) -> void:
	var frame := ColorRect.new()
	frame.color = Color(0.1, 0.06, 0.16)
	frame.position = at - Vector2.ONE
	frame.size = preview_size + Vector2.ONE * 2
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var container := SubViewportContainer.new()
	container.position = at
	container.size = preview_size
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true  # its own little world, separate from the city
	viewport.transparent_bg = true
	container.add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.5, 0.7)
	environment.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.2
	viewport.add_child(sun)
	var rim := OmniLight3D.new()  # pink neon from behind, like the city
	rim.position = Vector3(-0.8, 1.2, -1.0)
	rim.light_color = Color(1, 0.35, 0.8)
	rim.light_energy = 2.0
	rim.omni_range = 3.0
	viewport.add_child(rim)

	var camera := Camera3D.new()
	camera.fov = 35
	camera.position = Vector3(0, 0.75, 2.6)
	camera.rotation_degrees = Vector3(-5, 0, 0)
	viewport.add_child(camera)

	_preview_cat = CAT_MODEL.instantiate()
	_preview_cat.rotation.y = PI * 0.8  # start facing roughly towards us
	viewport.add_child(_preview_cat)


func _label(text: String, at: Vector2, width: float, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(width, font_size + 4)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(text: String, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 8)
	add_child(button)
	return button
