class_name SeatFocus
extends RefCounted
## MEOW-CITY 1999 — ONE PLAYER'S HIGHLIGHTED BUTTON in a HUD window (talk box, inventory, pause).
##
## Why not Godot's own "focus"? Godot allows only ONE focused button in the whole game window,
## even across the split-screen HUDs: when player 2 highlighted a button, player 1's highlight
## vanished. So every HUD window keeps its own highlight with one of these, moved by that
## player's own d-pad / arrow keys:
##
##   var focus := SeatFocus.new()
##   focus.set_buttons(my_buttons)          # when the window opens (first one is highlighted)
##   func _input(event):                     # (after checking it's this player's button)
##       if focus.handle(event):             # d-pad / arrows move the highlight, A / Enter presses it
##           get_viewport().set_input_as_handled()
##
## The highlighted button looks like the mouse is over it (its theme's "hover" box). The mouse
## still works as normal for player 1. Buttons get focus_mode = NONE so Godot's focus stays out of it.
## A SETTING ROW is a button with an "adjust" meta (a Callable taking -1 / +1): left / right on it
## changes the value instead of moving the highlight (e.g. STICK SPEED < 100% > in the pause menu).

## The highlight moved to this button (e.g. to show what an inventory item is).
signal highlighted(button: Button)

## true = A / Enter emits the button's "pressed" signal. false = the window handles A itself
## (the inventory does: A and X do different things to the highlighted slot).
var press_on_accept: bool = true
## The highlighted button, or null.
var current: Button = null

var _buttons: Array[Button] = []


## The buttons the highlight can move between. Highlights the first one (or "first").
func set_buttons(buttons: Array, first: Button = null) -> void:
	_unhighlight()
	_buttons.clear()
	for button in buttons:
		_buttons.append(button)
		button.focus_mode = Control.FOCUS_NONE
	var start: Button = first if first != null else (_buttons[0] if not _buttons.is_empty() else null)
	if start != null:
		highlight(start)


## No highlight (the window closed).
func clear() -> void:
	_unhighlight()
	_buttons.clear()


## Move the highlight to this button.
func highlight(button: Button) -> void:
	_unhighlight()
	current = button
	if button == null or not is_instance_valid(button):
		current = null
		return
	button.set_meta("seat_focus_normal", button.get_theme_stylebox("normal"))
	button.set_meta("seat_focus_had_override", button.has_theme_stylebox_override("normal"))
	button.add_theme_stylebox_override("normal", button.get_theme_stylebox("hover"))
	highlighted.emit(button)


## A d-pad / arrow press moves the highlight, A / Enter presses the button. True if it was used.
func handle(event: InputEvent) -> bool:
	if current == null or not is_instance_valid(current):
		return false
	if event.is_action_pressed("ui_accept"):
		if press_on_accept and not current.disabled:
			current.pressed.emit()
			return true
		return false
	if current.has_meta("adjust") and (event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true)):
		(current.get_meta("adjust") as Callable).call(-1 if event.is_action_pressed("ui_left", true) else 1)
		return true
	var directions := {"ui_up": Vector2.UP, "ui_down": Vector2.DOWN, "ui_left": Vector2.LEFT, "ui_right": Vector2.RIGHT}
	for action in directions:
		if event.is_action_pressed(action, true):
			var next := _neighbour(directions[action])
			if next != null:
				highlight(next)
			return true
	return false


## The closest visible button in that direction (by where the buttons are on screen).
func _neighbour(direction: Vector2) -> Button:
	var from := current.get_global_rect().get_center()
	var best: Button = null
	var best_score := INF
	for button in _buttons:
		if button == current or not is_instance_valid(button) or not button.is_visible_in_tree():
			continue
		var offset := button.get_global_rect().get_center() - from
		var along := offset.dot(direction)
		if along <= 1.0:
			continue  # not in that direction
		var sideways := absf(offset.dot(Vector2(direction.y, direction.x)))
		var score := along + sideways * 2.0  # straight ahead beats diagonal
		if score < best_score:
			best_score = score
			best = button
	return best


func _unhighlight() -> void:
	if current != null and is_instance_valid(current) and current.has_meta("seat_focus_normal"):
		if current.get_meta("seat_focus_had_override"):
			current.add_theme_stylebox_override("normal", current.get_meta("seat_focus_normal"))
		else:
			current.remove_theme_stylebox_override("normal")
		current.remove_meta("seat_focus_normal")
	current = null
