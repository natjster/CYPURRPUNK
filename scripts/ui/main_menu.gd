class_name MainMenu
extends Control
## MEOW-CITY 1999 — the START MENU shown over the city before a game.
## Attach to the "Lobby" Control under PS1Overlay in main.tscn. Expected node tree:
##   Lobby (Control)                 <- this script
##   ├── Shade (ColorRect)           <- darkens the city a little so the text reads
##   ├── Title / Subtitle / Tagline (Label)
##   ├── MainScreen (VBoxContainer)  <- PlayButton, SettingsButton, QuitButton
##   ├── PlayScreen (PanelContainer) > VBox
##   │   ├── NameRow > NameLabel, NameInput
##   │   ├── Columns > HostColumn (HostLabel, SeedInput, HostButton)
##   │   │           > JoinColumn (JoinLabel, AddressInput, JoinButton)
##   │   └── BackButton
##   ├── Status (Label)
##   └── Version (Label)
##
## This script only runs the menu. When the player clicks HOST or JOIN it sends a signal,
## and game.gd does the actual hosting / joining.

## HOST was clicked. city_seed = the number typed, or a random one.
signal host_pressed(city_seed: int)
## JOIN was clicked, with the address typed in.
signal join_pressed(address: String)
## SETTINGS was clicked (game.gd opens the settings menu).
signal settings_pressed

@export_group("Start Menu")
## The camera that looks at the city behind the menu (it slowly pans while the menu is open).
@export var menu_camera: Camera3D
## How far (degrees) the menu camera slowly pans left and right over the city.
@export var camera_sway_degrees: float = 18.0
## How long one slow pan left-and-back takes, in seconds.
@export var camera_sway_seconds: float = 40.0
## How much the big MEOW-CITY title flickers like a neon sign (0 = steady).
@export var title_flicker: float = 0.25

@onready var title_label: Label = $Title
@onready var main_screen: Control = $MainScreen
@onready var play_screen: Control = $PlayScreen
@onready var name_input: LineEdit = $PlayScreen/VBox/NameRow/NameInput
@onready var seed_input: LineEdit = $PlayScreen/VBox/Columns/HostColumn/SeedInput
@onready var address_input: LineEdit = $PlayScreen/VBox/Columns/JoinColumn/AddressInput
@onready var status_label: Label = $Status

## Where the menu camera starts, so it can sway around it.
var _camera_yaw: float


func _ready() -> void:
	$MainScreen/PlayButton.pressed.connect(show_play_screen)
	$MainScreen/SettingsButton.pressed.connect(_on_settings_pressed)
	$MainScreen/QuitButton.pressed.connect(get_tree().quit)
	$PlayScreen/VBox/Columns/HostColumn/HostButton.pressed.connect(_on_host_pressed)
	$PlayScreen/VBox/Columns/JoinColumn/JoinButton.pressed.connect(func(): join_pressed.emit(address_input.text.strip_edges()))
	$PlayScreen/VBox/BackButton.pressed.connect(show_main_screen)
	$Version.text = "v%s  LAN" % ProjectSettings.get_setting("application/config/version", "0")
	name_input.text = Settings.player_name
	if menu_camera != null:
		_camera_yaw = menu_camera.rotation.y
	show_main_screen()


## The name typed in the CAT NAME box.
func typed_name() -> String:
	return name_input.text.strip_edges()


## Show a message under the menu ("Connecting...", errors).
func show_status(text: String) -> void:
	status_label.text = text


## PLAY / SETTINGS / QUIT.
func show_main_screen() -> void:
	show()
	play_screen.hide()
	main_screen.show()
	status_label.text = ""
	$MainScreen/PlayButton.grab_focus()


## Name, host or join.
func show_play_screen() -> void:
	show()
	main_screen.hide()
	play_screen.show()
	$PlayScreen/VBox/Columns/HostColumn/HostButton.grab_focus()


## Esc on the play screen = back.
func _input(event: InputEvent) -> void:
	if visible and play_screen.visible and event.is_action_pressed("ui_cancel"):
		show_main_screen()
		get_viewport().set_input_as_handled()


## The number typed in the city # box, or a random one if it's empty.
func chosen_seed() -> int:
	var typed := seed_input.text.strip_edges()
	return typed.to_int() if typed.is_valid_int() else randi_range(1, 99999)


func _on_host_pressed() -> void:
	host_pressed.emit(chosen_seed())


func _on_settings_pressed() -> void:
	main_screen.hide()  # the settings menu takes its place; it calls show_main_screen() after
	settings_pressed.emit()


## Slowly pan the camera over the city and flicker the neon title.
func _process(_delta: float) -> void:
	if not visible:
		return
	var t := Time.get_ticks_msec() / 1000.0
	if menu_camera != null:
		menu_camera.rotation.y = _camera_yaw + deg_to_rad(camera_sway_degrees) * sin(TAU * t / camera_sway_seconds)
	# Neon flicker: mostly steady, with the odd quick dip like a dodgy sign.
	var dip := title_flicker if fmod(t, 4.3) < 0.08 or fmod(t, 7.1) < 0.05 else 0.0
	title_label.modulate.a = 1.0 - dip - title_flicker * 0.2 * (0.5 + 0.5 * sin(t * 3.0))
