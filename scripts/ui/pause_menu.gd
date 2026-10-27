class_name PauseMenu
extends Control
## CYPURRPUNK — the PAUSE MENU (press Esc, or START on a controller, during a game).
## Attach to the "PauseMenu" Control under PS1Overlay in main.tscn. Expected node tree:
##   PauseMenu (Control)   <- this script
##   ├── Dim (ColorRect)
##   └── Panel (PanelContainer) > VBox
##       ├── Title (Label)
##       └── ResumeButton, CatButton, SettingsButton, LeaveButton, QuitButton
##
## The game does NOT stop while it's open (it's online), but your cat and car ignore the
## keyboard: they check PauseMenu.is_open.

## SETTINGS was clicked (game.gd opens the settings menu).
signal settings_pressed
## LEAVE GAME was clicked.
signal leave_pressed
## MY CAT was clicked (game.gd opens the character creator).
signal cat_pressed

## True while this menu (or the settings menu opened from it) is up. The cat, the car and
## the inventory screen ignore the keyboard while it's true.
static var is_open: bool = false

## Esc only opens the pause menu once a game has started (game.gd turns this on).
var enabled: bool = false
## Which player on this computer opened it (their seat, scripts/seats.gd). For a couch player
## (seat 1-3), LEAVE GAME drops only them out; for player 1 it leaves the whole game.
var opened_by: int = 0


func _ready() -> void:
	$Panel/VBox/ResumeButton.pressed.connect(close)
	$Panel/VBox/SettingsButton.pressed.connect(_on_settings_pressed)
	$Panel/VBox/CatButton.pressed.connect(func():
		hide()  # is_open stays true: the MY CAT screen is on top, so still no walking
		cat_pressed.emit())
	$Panel/VBox/LeaveButton.pressed.connect(_on_leave_pressed)
	$Panel/VBox/QuitButton.pressed.connect(get_tree().quit)
	is_open = false  # (it's static, so reset it when the scene reloads)
	hide()


## Esc / START during a game: open, or close if already open. B (back) also closes it.
## (Runs before the cat and car see the key. The settings menu catches Esc first when it's open.)
func _input(event: InputEvent) -> void:
	var seat := Seats.seat_of_event(event)
	if not enabled or seat == -1:
		return  # (-1 = a controller nobody has: its START joins a new player, scripts/seats.gd)
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()
	elif not is_open and event.is_action_pressed("pause"):
		# (is_open is also true while SETTINGS or MY CAT is up on top of us: START does nothing then.)
		get_viewport().set_input_as_handled()
		opened_by = seat
		open()


func open() -> void:
	is_open = true
	# A couch player's pause menu drops only them out of the game.
	$Panel/VBox/LeaveButton.text = "LEAVE GAME" if opened_by == 0 else "DROP OUT (PLAYER %d)" % (opened_by + 1)
	# MY CAT restyles the cat of whoever opened the menu (game.gd passes opened_by on).
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Panel/VBox/ResumeButton.grab_focus()


## Back to the game: grab the mouse again.
func close() -> void:
	is_open = false
	opened_by = 0
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_leave_pressed() -> void:
	if opened_by > 0:
		Seats.leave(opened_by)  # just that couch player
		opened_by = 0
		close()
	else:
		leave_pressed.emit()


func _on_settings_pressed() -> void:
	hide()  # is_open stays true: the settings menu is on top, so still no driving
	settings_pressed.emit()
