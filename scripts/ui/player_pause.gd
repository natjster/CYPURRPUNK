class_name PlayerPause
extends Control
## CYPURRPUNK — ONE PLAYER'S PAUSE MENU, for split screen (couch co-op).
## Part of every player's HUD (scenes/ui/hud.tscn > HUD > Frame > PlayerPause); it builds its
## own box and buttons, so the scene only needs the empty node.
##
## While 2-4 players share this computer, START (or Esc for player 1) opens THIS small menu on
## that player's own screen only: their cat stops, everyone else keeps playing. Alone, the normal
## full-screen pause menu opens instead (scripts/ui/pause_menu.gd).
##
##   Everyone:    RESUME, then their OWN STICK SPEED / INVERT STICK Y / RUMBLE (A on a row's
##                < or > changes it; a couch player's are saved with their cat, player 1's are the
##                same as SETTINGS > CONTROLS)
##   Everyone:    MY CAT (restyle / rename THEIR cat: the full-screen cat screen, driven only by
##                their controller; DONE comes back here)
##   Player 1:    SETTINGS / LEAVE GAME / QUIT TO DESKTOP
##                (SETTINGS opens the big pause menu: those screens are shared)
##   Players 2-4: DROP OUT (just them: scripts/seats.gd)
##
## It also opens by itself when that player's controller is unplugged (open(reason)), and closes
## by itself when it's back.
##
## Controller: d-pad + A, B or START = back to the game.

## Text size of the title and buttons (HUD units; the HUD shrinks on small screens anyway).
@export var font_size: int = 26

## Which player's pause menu this is (its HUD's seat).
var seat: int = 0
## True while it's open: that player's cat ignores their buttons.
var is_open: bool = false

var _title: Label
var _buttons: VBoxContainer
## True while it's open because the controller was unplugged (it closes itself when it's back).
var _for_unplug: bool = false
## This player's highlighted button (scripts/ui/seat_focus.gd), moved by their own d-pad.
var _focus := SeatFocus.new()
## Every button the highlight can move to (the setting rows' < and > too).
var _focus_buttons: Array[Button] = []


func _enter_tree() -> void:
	seat = (owner as Hud).seat if owner is Hud else 0


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", font_size + 8)
	_title.add_theme_color_override("font_color", Color(1, 0.4, 0.8))
	box.add_child(_title)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	box.add_child(_buttons)


## This player's pause menu (seat 0 = player 1), or null.
static func for_seat(seat_number: int) -> PlayerPause:
	var hud := Hud.of(seat_number)
	return hud.get_node_or_null("Frame/PlayerPause") as PlayerPause if hud != null else null


## Is this player's own pause menu open?
static func is_open_for(seat_number: int) -> bool:
	var menu := for_seat(seat_number)
	return menu != null and menu.is_open


## More than one player on this computer right now? (Then everyone gets their own pause menu.)
static func split_active() -> bool:
	return Game.instance != null and is_instance_valid(Game.instance) and Game.instance.playing_cats().size() > 1


## START / Esc: open or close (only this player's buttons: player 1's HUD hears every button first).
func _input(event: InputEvent) -> void:
	if Seats.seat_of_event(event) != seat:
		return
	if is_open and _focus.handle(event):  # up / down + A
		get_viewport().set_input_as_handled()
		return
	if is_open and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()
	elif not is_open and event.is_action_pressed("pause") and split_active() and not Hud.menu_open() \
			and not Hud.wants_input(seat):
		get_viewport().set_input_as_handled()
		open()


## reason = a title to show instead of "PAUSED" (e.g. the controller was unplugged).
func open(reason: String = "") -> void:
	var game := Game.instance
	_for_unplug = reason != ""
	_title.text = reason if reason != "" else "PLAYER %d - PAUSED" % (seat + 1)
	_title.add_theme_color_override("font_color", Seats.color(seat))  # their player colour
	for old in _buttons.get_children():
		_buttons.remove_child(old)
		old.queue_free()
	_focus_buttons.clear()
	_add_button("RESUME", close)
	# Their own controller settings (A on the row's < or > changes it).
	_add_setting("STICK SPEED", func(): return "%d%%" % roundi(Seats.stick_speed(seat) * 100.0),
		func(direction: int): Seats.set_player_setting(seat, "stick_speed",
			snappedf(clampf(Seats.stick_speed(seat) + 0.1 * direction, 0.2, 3.0), 0.1)))
	_add_setting("INVERT STICK Y", func(): return "ON" if Seats.invert_stick_y(seat) else "OFF",
		func(_direction: int): Seats.set_player_setting(seat, "invert_stick_y", not Seats.invert_stick_y(seat)))
	_add_setting("RUMBLE", func(): return "ON" if Seats.rumble_on(seat) else "OFF",
		func(_direction: int): Seats.set_player_setting(seat, "rumble", not Seats.rumble_on(seat)))
	_add_button("MY CAT", func():
		close()
		game.cat_creator.open(true, seat)
		game.cat_creator.back_to_player_pause = true)  # DONE comes back to this menu (game.gd)
	if seat == 0:
		_add_button("SETTINGS", func():
			close()
			game.pause_menu.opened_by = 0
			game.pause_menu.open())  # the big pause menu: SETTINGS is in there
		_add_button("LEAVE GAME", func():
			close()
			game.pause_menu.leave_pressed.emit())  # this whole computer leaves (game.gd)
		_add_button("QUIT TO DESKTOP", get_tree().quit)
	else:
		_add_button("DROP OUT", func():
			close()
			Seats.leave(seat))  # just this player
	is_open = true
	show()
	if seat == 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # (the mouse is player 1's)
	_focus.set_buttons(_focus_buttons)  # RESUME highlighted


## The controller is back: close the pause that opened when it was unplugged (not a normal one).
func close_unplug_pause() -> void:
	if is_open and _for_unplug:
		close()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_for_unplug = false
	hide()
	_focus.clear()
	if seat == 0:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A setting row: "STICK SPEED  [<] 100% [>]". value_text() gives the value's text; adjust(-1 / +1)
## changes it. The d-pad moves the highlight onto < or >, and A (or a click) presses it.
func _add_setting(label: String, value_text: Callable, adjust: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(320, 40)
	row.add_theme_constant_override("separation", 6)
	_buttons.add_child(row)
	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", font_size - 4)
	row.add_child(name_label)
	var value := Label.new()
	var refresh := func(): value.text = value_text.call()
	for direction in [-1, 1]:
		var button := Button.new()
		button.text = "<" if direction < 0 else ">"
		button.custom_minimum_size = Vector2(40, 40)
		button.add_theme_font_size_override("font_size", font_size - 4)
		button.pressed.connect(func():
			adjust.call(direction)
			refresh.call())
		row.add_child(button)
		_focus_buttons.append(button)
		if direction < 0:
			value.custom_minimum_size = Vector2(80, 0)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value.add_theme_font_size_override("font_size", font_size - 4)
			value.add_theme_color_override("font_color", Color(0.4, 1, 1))
			row.add_child(value)
	refresh.call()


func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 40)
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(action)
	_buttons.add_child(button)
	_focus_buttons.append(button)
