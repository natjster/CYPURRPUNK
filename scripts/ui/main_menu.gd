class_name MainMenu
extends Control
## MEOW-CITY 1999 — the START MENU shown over the city before a game.
## Attach to the "Lobby" Control under PS1Overlay in main.tscn. Expected node tree:
##   Lobby (Control)                 <- this script
##   ├── Shade (ColorRect)           <- darkens the city a little so the text reads
##   ├── Title / Subtitle / Tagline (Label)
##   ├── MainScreen (VBoxContainer)  <- PlayButton, SettingsButton, QuitButton
##   ├── ModeScreen (VBoxContainer)  <- PlayingAs (Label), SoloButton, MultiplayerButton, BackButton
##   ├── PlayScreen (PanelContainer) > VBox      <- the MULTIPLAYER screen
##   │   ├── Columns > HostColumn (HostLabel, SeedInput, HostButton)
##   │   │           > JoinColumn (JoinLabel, AddressInput, JoinButton)
##   │   └── BackButton
##   ├── Status (Label)
##   └── Version (Label)
##
## The way through:
##   PLAY / SETTINGS / QUIT
##     PLAY -> CHOOSE YOUR CAT (scripts/ui/cat_creator.gd, its own node; game.gd opens it)
##       NEXT -> SOLO / MULTIPLAYER (ModeScreen)
##         SOLO        -> a game just for you, in a random city
##         MULTIPLAYER -> HOST (with a city #) or JOIN (a friend's address) (PlayScreen)
## BACK (or Esc) always goes one step back.
##
## This script only runs the menu. When the player picks something it sends a signal,
## and game.gd does the actual work.

## PLAY was clicked, or BACK on the SOLO / MULTIPLAYER screen (game.gd opens CHOOSE YOUR CAT).
signal play_pressed
## SOLO was clicked. city_seed = a random city.
signal solo_pressed(city_seed: int)
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
@onready var mode_screen: Control = $ModeScreen
@onready var play_screen: Control = $PlayScreen
@onready var seed_input: LineEdit = $PlayScreen/VBox/Columns/HostColumn/SeedInput
@onready var address_input: LineEdit = $PlayScreen/VBox/Columns/JoinColumn/AddressInput
@onready var status_label: Label = $Status

## Where the menu camera starts, so it can sway around it.
var _camera_yaw: float
## The couch lobby line at the bottom of the SOLO / MULTIPLAYER and HOST / JOIN screens
## (scripts/seats.gd): who's sitting down, and with which cat.
var _couch_label: Label
## Buttons for the games found on your network (MULTIPLAYER screen, under JOIN).
var _game_list: VBoxContainer


func _ready() -> void:
	$MainScreen/PlayButton.pressed.connect(_on_play_pressed)
	$MainScreen/SettingsButton.pressed.connect(_on_settings_pressed)
	$MainScreen/QuitButton.pressed.connect(get_tree().quit)
	$ModeScreen/SoloButton.pressed.connect(func(): solo_pressed.emit(randi_range(1, 99999)))
	$ModeScreen/MultiplayerButton.pressed.connect(show_play_screen)
	$ModeScreen/BackButton.pressed.connect(_on_play_pressed)
	$PlayScreen/VBox/Columns/HostColumn/HostButton.pressed.connect(_on_host_pressed)
	$PlayScreen/VBox/Columns/JoinColumn/JoinButton.pressed.connect(func(): join_pressed.emit(address_input.text.strip_edges()))
	$PlayScreen/VBox/BackButton.pressed.connect(show_mode_screen)
	# Controller / arrow keys: left / right hops straight between HOST and JOIN (Godot's own
	# guess sent "right" from HOST down to BACK).
	var host_button: Button = $PlayScreen/VBox/Columns/HostColumn/HostButton
	var join_button: Button = $PlayScreen/VBox/Columns/JoinColumn/JoinButton
	host_button.focus_neighbor_right = host_button.get_path_to(join_button)
	join_button.focus_neighbor_left = join_button.get_path_to(host_button)
	$Version.text = "v%s  LAN" % ProjectSettings.get_setting("application/config/version", "0")
	if menu_camera != null:
		_camera_yaw = menu_camera.rotation.y
	# Games found on your network (net.gd): one button each, under the JOIN button.
	_game_list = VBoxContainer.new()
	_game_list.name = "GameList"
	_game_list.add_theme_constant_override("separation", 2)
	$PlayScreen/VBox/Columns/JoinColumn.add_child(_game_list)
	Net.games_changed.connect(_refresh_game_list)
	_refresh_game_list()
	_couch_label = Label.new()
	_couch_label.name = "CouchLobby"
	_couch_label.position = Vector2(30, 214)
	_couch_label.size = Vector2(260, 24)
	_couch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_couch_label.add_theme_color_override("font_color", Color(0.4, 1, 1))
	_couch_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_couch_label)
	show_main_screen()


## Show a message under the menu ("Connecting...", errors).
func show_status(text: String) -> void:
	status_label.text = text


## PLAY / SETTINGS / QUIT.
func show_main_screen() -> void:
	_show_only(main_screen)
	$MainScreen/PlayButton.grab_focus()


## SOLO / MULTIPLAYER (after CHOOSE YOUR CAT).
func show_mode_screen() -> void:
	_show_only(mode_screen)
	$ModeScreen/PlayingAs.text = "PLAYING AS %s" % str(Settings.current_cat().get("name", "")).to_upper()
	$ModeScreen/SoloButton.grab_focus()


## MULTIPLAYER: host or join.
func show_play_screen() -> void:
	_show_only(play_screen)
	$PlayScreen/VBox/Columns/HostColumn/HostButton.grab_focus()


## Hide every screen (another menu, e.g. CHOOSE YOUR CAT, is on top). The title stays.
func hide_screens() -> void:
	_show_only(null)


func _show_only(screen: Control) -> void:
	show()
	for each in [main_screen, mode_screen, play_screen]:
		each.visible = each == screen
	status_label.text = ""
	# Only the MULTIPLAYER screen listens for games on the network.
	if screen == play_screen:
		Net.start_listening()
	else:
		Net.stop_listening()


## The games found on your network, as buttons: "WHISKERS  #4242  3/8". Click = join it.
func _refresh_game_list() -> void:
	if _game_list == null:
		return
	for old in _game_list.get_children():
		_game_list.remove_child(old)
		old.queue_free()
	var title := Label.new()
	title.text = "ON YOUR NETWORK:" if not Net.found_games.is_empty() else "looking for games..."
	title.modulate = Color(1, 1, 1, 0.6)
	_game_list.add_child(title)
	var shown := 0
	for address in Net.found_games:
		if shown >= 3:
			break  # (room for 3; type the address for any other)
		var info: Dictionary = Net.found_games[address]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 14)
		var full: bool = int(info.get("players", 0)) >= int(info.get("max", Net.MAX_PLAYERS))
		button.text = "%s  #%d  %d/%d%s" % [str(info.get("name", "?")).left(9), int(info.get("city", 0)),
			int(info.get("players", 0)), int(info.get("max", Net.MAX_PLAYERS)), "  FULL" if full else ""]
		button.disabled = full
		button.pressed.connect(func():
			address_input.text = address
			join_pressed.emit(address))
		_game_list.add_child(button)
		shown += 1


## Esc = one step back.
## Couch lobby players' controllers (seats 2-4) only pick their cat (left / right) or leave (B):
## they never move player 1's menu.
func _input(event: InputEvent) -> void:
	var seat := Seats.seat_of_event(event)
	if visible and seat > 0:
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_left"):
			Seats.cycle_lobby_cat(seat, -1)
		elif event.is_action_pressed("ui_right"):
			Seats.cycle_lobby_cat(seat, 1)
		elif event.is_action_pressed("ui_cancel"):
			Seats.leave_lobby(seat)
		return
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if play_screen.visible:
		show_mode_screen()
	elif mode_screen.visible:
		_on_play_pressed()
	else:
		return
	get_viewport().set_input_as_handled()


## The number typed in the city # box, or a random one if it's empty.
func chosen_seed() -> int:
	var typed := seed_input.text.strip_edges()
	return typed.to_int() if typed.is_valid_int() else randi_range(1, 99999)


func _on_play_pressed() -> void:
	hide_screens()  # CHOOSE YOUR CAT takes their place
	play_pressed.emit()


func _on_host_pressed() -> void:
	host_pressed.emit(chosen_seed())


func _on_settings_pressed() -> void:
	hide_screens()  # the settings menu takes their place; it calls show_main_screen() after
	settings_pressed.emit()


## Slowly pan the camera over the city and flicker the neon title.
func _process(_delta: float) -> void:
	if not visible:
		return
	_couch_label.visible = mode_screen.visible or play_screen.visible
	if _couch_label.visible:
		_couch_label.text = Seats.lobby_text()
	var t := Time.get_ticks_msec() / 1000.0
	if menu_camera != null:
		menu_camera.rotation.y = _camera_yaw + deg_to_rad(camera_sway_degrees) * sin(TAU * t / camera_sway_seconds)
	# Neon flicker: mostly steady, with the odd quick dip like a dodgy sign.
	var dip := title_flicker if fmod(t, 4.3) < 0.08 or fmod(t, 7.1) < 0.05 else 0.0
	title_label.modulate.a = 1.0 - dip - title_flicker * 0.2 * (0.5 + 0.5 * sin(t * 3.0))
