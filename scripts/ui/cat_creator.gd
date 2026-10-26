class_name CatCreator
extends Control
## MEOW-CITY 1999 — the MY CAT screen (the character creator). Opened from the start menu
## and the pause menu. Attach to the "CatCreator" Control under PS1Overlay in main.tscn; it
## builds everything itself, so the scene only needs the empty node.
##
##   MY CAT
##   FUR       <  [colour]  >        +-----------+
##   MARKINGS  <  [colour]  >        |  your cat |   <- live 3D preview, slowly turning
##   EYES ...  NOSE ...              |           |
##   HAT       <  FEDORA    >        +-----------+
##   FACE ...  NECK ...
##   [ RANDOM ]  [ DONE ]
##
## The rows come from the framework (scripts/cat/cat_look.gd): one colour row per
## CatLook.COLOR_KEYS (colours from res://cat_parts/palette.tres) and one accessory row per
## CatLook.SLOTS (every CatPart card in res://cat_parts/). New hats or colours show up here
## by themselves.
##
## Every click is saved straight away (Settings.cat_look, in settings.cfg). In a game, your
## cat changes too and everyone sees it (cat_player.gd listens to Settings.changed).

## DONE (or Esc) was pressed, so whoever opened us can show itself again.
signal closed

const CAT_MODEL: PackedScene = preload("res://scenes/cat_model.tscn")
## Menu names for the colour keys and slots.
const LABELS: Dictionary = {
	"fur": "FUR", "markings": "MARKINGS", "eyes": "EYES", "nose": "NOSE",
	"hat": "HAT", "face": "FACE", "neck": "NECK",
}
const HEADER_COLOR := Color(1, 0.35, 0.8)
const VALUE_COLOR := Color(0.4, 1, 1)
## How fast the preview cat turns (radians per second).
const SPIN_SPEED: float = 0.8

## The look being edited (a CatLook dictionary).
var _look: Dictionary = {}
## key -> the value Label (accessory rows) or ColorRect swatch (colour rows).
var _value_nodes: Dictionary = {}
var _preview_cat: Node3D
var _done_button: Button
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
	panel.size = Vector2(292, 212)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var title := _label("MY CAT", Vector2(14, 18), 292, 16, HEADER_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# One row per colour, then one per accessory slot.
	var y := 44.0
	for key in CatLook.COLOR_KEYS:
		_add_row(key, y, true)
		y += 19
	for slot in CatLook.SLOTS:
		_add_row(slot, y, false)
		y += 19

	_build_preview(Vector2(178, 40), Vector2(118, 150))

	var random := _button("RANDOM", Vector2(40, 196), Vector2(80, 16))
	random.pressed.connect(_randomize)
	_done_button = _button("DONE", Vector2(200, 196), Vector2(80, 16))
	_done_button.pressed.connect(close)
	var note := _label("Saved automatically", Vector2(14, 214), 292, 8, Color(0.6, 0.55, 0.7))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Show the screen with the saved look.
func open() -> void:
	_look = CatLook.default_look().merged(CatLook.clean(Settings.cat_look), true)
	_refresh()
	show()
	_done_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	if visible and _preview_cat != null:
		_preview_cat.rotation.y += SPIN_SPEED * delta


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
	Settings.set_value("cat_look", _look.duplicate())
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
	left.pressed.connect(_step.bind(key, -1))
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
	right.pressed.connect(_step.bind(key, 1))


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
