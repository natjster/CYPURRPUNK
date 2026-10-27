class_name MainMenu
extends Control
## MEOW-CITY 1999 — the START MENU shown over the city before a game.
## Attach to the "Lobby" Control under PS1Overlay in main.tscn. Expected node tree:
##   Lobby (Control)                 <- this script
##   ├── Shade (ColorRect)           <- darkens the city a little so the text reads
##   ├── Title / Subtitle / Tagline (Label)
##   ├── MainScreen (VBoxContainer)  <- PlayButton, SettingsButton, QuitButton
##   ├── ModeScreen (VBoxContainer)  <- PlayingAs (Label, unused), SoloButton, MultiplayerButton, BackButton
##   ├── CoopScreen (VBoxContainer)  <- made by this script: LOCAL CO-OP / ONLINE CO-OP / BACK
##   ├── LandingScreen (VBoxContainer) <- made by this script: who's playing (see below)
##   ├── PlayScreen (PanelContainer) > VBox      <- the ONLINE screen
##   │   ├── Columns > HostColumn (HostLabel, SeedInput, HostButton)
##   │   │           > JoinColumn (JoinLabel, AddressInput, JoinButton, GameList)
##   │   └── BackButton
##   ├── Status (Label)
##   └── Version (Label)
##
## The way through:
##   PLAY / SETTINGS / QUIT
##     PLAY -> SOLO / MULTIPLAYER (ModeScreen)
##       SOLO        -> CHOOSE YOUR CAT (scripts/ui/cat_creator.gd) -> NEXT = a game just for you
##       MULTIPLAYER -> LOCAL CO-OP / ONLINE CO-OP (CoopScreen)
##         either one -> the LANDING PAGE (LandingScreen): everyone on this computer gathers
##           P1  < WHISKERS >          <- player 1: left / right = pick cat, A = make / edit cats
##           P2  < MITTENS >           <- joined with START on their controller (left / right = cat, B = leave)
##           P3  PRESS START TO JOIN
##           [START GAME] / [NEXT]  [BACK]
##           LOCAL:  START GAME = everyone into the sewers on this computer (no network)
##           ONLINE: NEXT -> HOST (with a city #) or JOIN (a game on your network) (PlayScreen)
## BACK (or Esc) always goes one step back. Leaving the landing page stands everyone up again.
##
## This script only runs the menu. When the player picks something it sends a signal,
## and game.gd does the actual work.

## Open CHOOSE YOUR CAT (game.gd does): for SOLO, or player 1 editing their cat on the landing page.
## Its NEXT comes back to cat_done(), its BACK to cat_closed().
signal cat_pressed
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
## LOCAL CO-OP / ONLINE CO-OP / BACK.
var coop_screen: VBoxContainer
## The landing page: who's playing on this computer, and with which cat.
var landing_screen: VBoxContainer
var _landing_title: Label
var _p1_button: Button          # "P1  < WHISKERS >": left / right = cat, A = make / edit cats
var _seat_labels: Array[Label] = []  # P2..P4
var _landing_hint: Label
var _start_button: Button       # START GAME (local) / NEXT (online)
## Is the landing page for ONLINE CO-OP (NEXT -> host / join) or LOCAL (START GAME)?
var _online: bool = false
## Where CHOOSE YOUR CAT was opened from: "solo" or "landing" (where its NEXT / BACK go).
var _cat_from: String = ""


func _ready() -> void:
	$MainScreen/PlayButton.pressed.connect(_on_play_pressed)
	$MainScreen/SettingsButton.pressed.connect(_on_settings_pressed)
	$MainScreen/QuitButton.pressed.connect(get_tree().quit)
	$ModeScreen/SoloButton.pressed.connect(_on_solo_pressed)
	$ModeScreen/MultiplayerButton.pressed.connect(show_coop_screen)
	$ModeScreen/BackButton.pressed.connect(show_main_screen)
	$ModeScreen/PlayingAs.hide()  # (you pick your cat after SOLO, or on the landing page)
	_build_coop_screen()
	_build_landing_screen()
	$PlayScreen/VBox/Columns/HostColumn/HostButton.pressed.connect(_on_host_pressed)
	$PlayScreen/VBox/Columns/JoinColumn/JoinButton.pressed.connect(func(): join_pressed.emit(address_input.text.strip_edges()))
	$PlayScreen/VBox/BackButton.pressed.connect(show_landing.bind(true))
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


## SOLO / MULTIPLAYER.
func show_mode_screen() -> void:
	_show_only(mode_screen)
	$ModeScreen/SoloButton.grab_focus()


## LOCAL CO-OP / ONLINE CO-OP.
func show_coop_screen() -> void:
	Seats.clear_lobby()  # (back from the landing page: everyone stands up)
	_show_only(coop_screen)
	(coop_screen.get_child(0) as Button).grab_focus()


## The landing page: friends press START on their controllers to join, everyone picks a cat.
func show_landing(online: bool) -> void:
	_online = online
	Seats.coop = true  # co-op: other controllers can join (scripts/seats.gd)
	_show_only(landing_screen)
	_landing_title.text = "ONLINE CO-OP: WHO'S ON THIS COMPUTER?" if online else "LOCAL CO-OP: WHO'S PLAYING?"
	_start_button.text = "NEXT" if online else "START GAME"
	_refresh_landing()
	_start_button.grab_focus()


## ONLINE CO-OP (after the landing page): host or join.
func show_play_screen() -> void:
	_show_only(play_screen)
	$PlayScreen/VBox/Columns/HostColumn/HostButton.grab_focus()


## Hide every screen (another menu, e.g. CHOOSE YOUR CAT, is on top). The title stays.
func hide_screens() -> void:
	_show_only(null)


func _show_only(screen: Control) -> void:
	show()
	for each in [main_screen, mode_screen, coop_screen, landing_screen, play_screen]:
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
	if not visible:
		return
	# Player 1's row on the landing page: left / right picks their cat.
	if landing_screen.visible and _p1_button.has_focus() \
			and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		get_viewport().set_input_as_handled()
		Seats.cycle_p1_cat(-1 if event.is_action_pressed("ui_left") else 1)
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if play_screen.visible:
		show_landing(true)
	elif landing_screen.visible:
		show_coop_screen()
	elif coop_screen.visible:
		show_mode_screen()
	elif mode_screen.visible:
		show_main_screen()
	else:
		return
	get_viewport().set_input_as_handled()


# --- LOCAL CO-OP / ONLINE CO-OP and the landing page (built here, in the menu's look) ---

func _build_coop_screen() -> void:
	coop_screen = _screen_box("CoopScreen", Vector2(90, 90), Vector2(230, 180))
	_menu_button(coop_screen, "LOCAL CO-OP", show_landing.bind(false), 16)
	_menu_button(coop_screen, "ONLINE CO-OP", show_landing.bind(true), 16)
	_menu_button(coop_screen, "BACK", show_mode_screen, 14).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var note := Label.new()
	note.text = "LOCAL = everyone on this computer\nONLINE = with friends on your network"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate = Color(1, 1, 1, 0.6)
	coop_screen.add_child(note)


func _build_landing_screen() -> void:
	landing_screen = _screen_box("LandingScreen", Vector2(40, 82), Vector2(280, 236))
	landing_screen.add_theme_constant_override("separation", 3)
	_landing_title = Label.new()
	_landing_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_landing_title.add_theme_color_override("font_color", Color(1, 0.35, 0.8))
	landing_screen.add_child(_landing_title)
	_p1_button = _menu_button(landing_screen, "P1", _on_p1_cat_pressed, 14)
	_p1_button.add_theme_color_override("font_color", Seats.color(0))
	for seat in range(1, PlayerId.MAX_LOCAL):
		var row := Label.new()
		row.custom_minimum_size = Vector2(0, 13)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_color_override("font_color", Seats.color(seat))
		landing_screen.add_child(row)
		_seat_labels.append(row)
	_landing_hint = Label.new()
	_landing_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_landing_hint.modulate = Color(1, 1, 1, 0.6)
	landing_screen.add_child(_landing_hint)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	landing_screen.add_child(buttons)
	_start_button = _menu_button(buttons, "START GAME", _on_landing_start, 16)
	_start_button.custom_minimum_size.x = 100
	_menu_button(buttons, "BACK", show_coop_screen, 16).custom_minimum_size.x = 60
	Seats.changed.connect(_refresh_landing)
	Settings.changed.connect(_refresh_landing)


## Rewrite the landing page's rows from who's sitting down (scripts/seats.gd).
func _refresh_landing() -> void:
	if landing_screen == null or not landing_screen.visible:
		return
	var my_name := str(Settings.current_cat().get("name", ""))
	_p1_button.text = "P1   < %s >" % (my_name.to_upper() if my_name != "" else "MAKE YOUR CAT")
	for i in _seat_labels.size():
		var seat := i + 1
		var cat := Seats.lobby_cat_name(seat)
		_seat_labels[i].text = "P%d   < %s >" % [seat + 1, cat] if cat != "" \
			else "P%d   PRESS %s TO JOIN" % [seat + 1, Controls.display_name("Pad Start")]
		_seat_labels[i].modulate.a = 1.0 if cat != "" else 0.55
	_landing_hint.text = "LEFT / RIGHT = PICK CAT   %s = EDIT   %s = LEAVE" % [
		Controls.display_name("Pad A"), Controls.display_name("Pad B")]


## A on player 1's row: make or restyle cats (CHOOSE YOUR CAT), then back here.
func _on_p1_cat_pressed() -> void:
	_cat_from = "landing"
	hide_screens()
	cat_pressed.emit()


## START GAME (local) / NEXT (online). Player 1 needs a named cat first.
func _on_landing_start() -> void:
	if str(Settings.current_cat().get("name", "")).is_empty():
		_on_p1_cat_pressed()
		return
	if _online:
		show_play_screen()
	else:
		solo_pressed.emit(randi_range(1, 99999))  # everyone on this computer: game.gd brings the couch players


## SOLO: just you. Pick (or make) your cat first.
func _on_solo_pressed() -> void:
	Seats.clear_lobby()
	Seats.coop = false  # SOLO: every controller is player 1's, nobody joins
	_cat_from = "solo"
	hide_screens()
	cat_pressed.emit()


## CHOOSE YOUR CAT: NEXT was pressed (game.gd forwards it).
func cat_done() -> void:
	if _cat_from == "solo":
		solo_pressed.emit(randi_range(1, 99999))
	else:
		show_landing(_online)


## CHOOSE YOUR CAT: BACK was pressed.
func cat_closed() -> void:
	if _cat_from == "solo":
		show_mode_screen()
	else:
		show_landing(_online)


## A column of menu buttons placed like the other screens (game pixels).
func _screen_box(node_name: String, top_left: Vector2, bottom_right: Vector2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = node_name
	box.position = top_left
	box.size = bottom_right - top_left
	box.add_theme_constant_override("separation", 5)
	box.hide()
	add_child(box)
	move_child(box, play_screen.get_index())
	return box


func _menu_button(parent: Control, text: String, action: Callable, height: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, height)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## The number typed in the city # box, or a random one if it's empty.
func chosen_seed() -> int:
	var typed := seed_input.text.strip_edges()
	return typed.to_int() if typed.is_valid_int() else randi_range(1, 99999)


func _on_play_pressed() -> void:
	show_mode_screen()  # SOLO / MULTIPLAYER


func _on_host_pressed() -> void:
	host_pressed.emit(chosen_seed())


func _on_settings_pressed() -> void:
	hide_screens()  # the settings menu takes their place; it calls show_main_screen() after
	settings_pressed.emit()


## Slowly pan the camera over the city and flicker the neon title.
func _process(_delta: float) -> void:
	if not visible:
		return
	_couch_label.visible = play_screen.visible  # (who's on the couch, while hosting / joining)
	if _couch_label.visible:
		_couch_label.text = Seats.lobby_text()
	var t := Time.get_ticks_msec() / 1000.0
	if menu_camera != null:
		menu_camera.rotation.y = _camera_yaw + deg_to_rad(camera_sway_degrees) * sin(TAU * t / camera_sway_seconds)
	# Neon flicker: mostly steady, with the odd quick dip like a dodgy sign.
	var dip := title_flicker if fmod(t, 4.3) < 0.08 or fmod(t, 7.1) < 0.05 else 0.0
	title_label.modulate.a = 1.0 - dip - title_flicker * 0.2 * (0.5 + 0.5 * sin(t * 3.0))
