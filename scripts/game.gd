class_name Game
extends Node3D
## MEOW-CITY 1999 — main scene script: starts games, spawns cats, keeps late joiners in sync.
## Attach to the root "Main" node of main.tscn.
##
## Who does what:
##   - Net (autoload, scripts/net.gd)        connects: host / join / leave
##   - Lobby (scripts/ui/main_menu.gd)       the start menu; tells us when HOST / JOIN is clicked
##   - PauseMenu (scripts/ui/pause_menu.gd)  Esc menu during a game
##   - this script                           everything in between, below
##
## How the multiplayer works:
##   - One player clicks HOST. Their game becomes the server (network ID 1).
##   - Others type the host's IP address and click JOIN.
##   - The host creates a cat for every player under the "Players" node.
##     The MultiplayerSpawner node copies those cats to everyone's game.
##   - Each cat is moved by its owner and synced to the others (see cat_player.gd).
##   - The city is generated from a seed number (see city_generator.gd). The host
##     sends just that number to each player, and everyone builds the same city.
##   - Cats start in THE SEWERS, the underground hub 200 m below the city (hub.gd).
##     Don Catleone sends them up; the EXTRACTION beam brings them back (fish_heist.gd).
##
## Testing shortcuts: launch the game with "--host" or "--join" to skip the menu
## (plus "--name=Whiskers" / "--seed=42" to fill in those boxes).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
## The crossroads at the centre of every generated city (where dropped items of a player
## who quits end up if their cat is already gone). Cats themselves start in the hub.
const SPAWN_POINT: Vector3 = Vector3(0, 0, 4)
## The city shown behind the start menu before a game starts.
const PREVIEW_SEED: int = 1999
## The CRT shader's sliders that the "CRT TV LOOK" setting turns down.
const CRT_PARAMS: Array[String] = ["curvature", "chromatic_aberration", "scanline_strength", "vignette_strength", "noise_strength"]

## The one Main node, so other scripts can reach it (e.g. Game.instance.cat_for(id)).
static var instance: Game
## The name typed in the lobby. Your own cat reads this when it appears
## and shares it with everyone (see player_name in cat_player.gd).
static var local_player_name: String = ""

@onready var players: Node3D = $Players
@onready var car: GetawayCar = $GetawayCar
@onready var city: CityGenerator = $City
@onready var main_menu: MainMenu = $PS1Overlay/Lobby
@onready var pause_menu: PauseMenu = $PS1Overlay/PauseMenu
@onready var settings_menu: SettingsMenu = $PS1Overlay/SettingsMenu
@onready var cat_creator: CatCreator = $PS1Overlay/CatCreator
@onready var hud: Control = $PS1Overlay/HUD
@onready var message_label: Label = $PS1Overlay/HUD/Message
@onready var hub: UndergroundHub = $Hub
@onready var crt_material: ShaderMaterial = $PS1Overlay/ColorDepthDither.material

## The CRT slider values at full strength (read from the shader), scaled by Settings.crt_strength.
var _crt_full: Dictionary = {}
var _message_time: float = 0.0


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	main_menu.host_pressed.connect(host_game)
	main_menu.join_pressed.connect(join_game)
	main_menu.settings_pressed.connect(settings_menu.open)
	pause_menu.settings_pressed.connect(settings_menu.open)
	pause_menu.leave_pressed.connect(_back_to_menu.bind(true))
	settings_menu.closed.connect(_on_settings_closed)
	main_menu.cat_pressed.connect(cat_creator.open)
	pause_menu.cat_pressed.connect(cat_creator.open)
	cat_creator.closed.connect(_on_settings_closed)  # back to whichever menu opened it, too

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	Net.joined.connect(_on_joined)
	Net.join_failed.connect(main_menu.show_status.bind("Couldn't connect. Check the address and that the host is running."))
	Net.host_left.connect(_back_to_menu.bind(false))

	# Settings that belong to this scene (CRT look, fog) — re-applied whenever they change.
	for param in CRT_PARAMS:
		_crt_full[param] = RenderingServer.shader_get_parameter_default(crt_material.shader.get_rid(), param)
	Settings.changed.connect(_apply_scene_settings)
	_apply_scene_settings()

	hud.hide()
	city.generate(PREVIEW_SEED)
	park_car()
	_handle_test_shortcuts()


func _handle_test_shortcuts() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--name="):  # e.g. --name=Whiskers
			main_menu.name_input.text = arg.trim_prefix("--name=")
		if arg.begins_with("--seed="):  # e.g. --seed=42
			main_menu.seed_input.text = arg.trim_prefix("--seed=")
	if "--host" in args:
		host_game(main_menu.chosen_seed())
	elif "--join" in args:
		join_game(main_menu.address_input.text.strip_edges())


# --- Starting and leaving a game ---

func host_game(city_seed: int) -> void:
	_remember_name()
	if Net.host() != OK:
		main_menu.show_status("Can't host - is another game already hosting?")
		return
	city.generate(city_seed)
	park_car()
	_start_playing()
	_spawn_cat(1)  # the host's own cat
	$Roombas.start_patrol()  # the VAC-COPs come out (the spawner copies them to everyone)


func join_game(address: String) -> void:
	_remember_name()
	if Net.join(address) != OK:
		main_menu.show_status("Can't start connecting.")
		return
	main_menu.show_status("Connecting to %s..." % (address if address != "" else "this computer"))


## Store the typed name for our cat, and save it to disk for next time.
func _remember_name() -> void:
	local_player_name = main_menu.typed_name()
	Settings.set_value("player_name", local_player_name)


func _on_joined() -> void:
	print("[Network] Joined game as player %d" % multiplayer.get_unique_id())
	_start_playing()


func _start_playing() -> void:
	main_menu.hide()
	hud.show()
	pause_menu.enabled = true
	_show_city_number()
	$Profile.restore()  # bring back our saved cash + stash (player_profile.gd)


## Back to a fresh start menu: we chose LEAVE GAME, or the host closed the game.
func _back_to_menu(we_left: bool) -> void:
	if we_left:
		Net.leave()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


## The settings menu (or the MY CAT screen) closed: go back to whichever menu opened it.
func _on_settings_closed() -> void:
	if pause_menu.enabled:
		pause_menu.open()
	else:
		main_menu.show_main_screen()


## Host → one player: "build city number X". Every computer builds the identical city.
@rpc("authority", "call_remote", "reliable")
func _receive_city_seed(city_seed: int) -> void:
	city.generate(city_seed)
	_show_city_number()


func _show_city_number() -> void:
	# Shown in the pause menu, so the bottom of the screen stays clear (keys: SETTINGS > KEYS).
	pause_menu.get_node("Panel/VBox/Note").text = "CITY #%d\nthe city keeps going - it's online!" % city.city_seed


## A line of text in the middle of the screen for a few seconds (e.g. what Don says).
func show_message(text: String, seconds: float = 4.0) -> void:
	message_label.text = text
	message_label.show()
	_message_time = seconds


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		message_label.visible = _message_time > 0.0


## Host (and start menu): put the car back at its parking spot, stopped.
## Also used when the driver extracts, so the car is waiting for the next trip up.
func park_car() -> void:
	car.global_transform = Transform3D(Basis(), CityGenerator.CAR_SPAWN)
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.sync_position = car.global_position
	car.sync_rotation = car.global_rotation


## The settings that live in this scene: CRT strength and volumetric fog.
func _apply_scene_settings() -> void:
	for param in CRT_PARAMS:
		crt_material.set_shader_parameter(param, _crt_full[param] * Settings.crt_strength)
	$WorldEnvironment.environment.volumetric_fog_enabled = Settings.volumetric_fog


# --- Players ---

## A player's cat (cats are named after their network ID), or null.
func cat_for(peer_id: int) -> CatPlayer:
	if peer_id == 0:
		return null
	return players.get_node_or_null(str(peer_id)) as CatPlayer


## The cat this computer controls, or null (e.g. still in the start menu).
func my_cat() -> CatPlayer:
	return cat_for(multiplayer.get_unique_id())


## Host only: create a cat for a network ID. The spawner copies it to everyone.
func _spawn_cat(peer_id: int) -> void:
	var cat := PLAYER_SCENE.instantiate()
	cat.name = str(peer_id)  # the name IS the owner — see cat_player.gd _enter_tree()
	cat.position = hub.spawn_position(players.get_child_count())  # everyone starts in the sewers
	players.add_child(cat, true)


func _on_peer_connected(peer_id: int) -> void:
	print("[Network] Player %d connected" % peer_id)
	if multiplayer.is_server():
		_receive_city_seed.rpc_id(peer_id, city.city_seed)  # build the same city first
		$Items.send_state_to(peer_id)  # then which items are taken, who holds/carries what
		$Heist.send_state_to(peer_id)  # then everyone's cash
		$Quests.send_state_to(peer_id)  # and everyone's quests
		$Health.send_state_to(peer_id)  # and everyone's HP
		_spawn_cat(peer_id)
		# Late joiner: tell them who's already driving, so that driver's cat is hidden
		# and their copy of the car follows the right player.
		if car.driver_id != 0:
			car.set_driver.rpc_id(peer_id, car.driver_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("[Network] Player %d left" % peer_id)
	if not multiplayer.is_server():
		return
	if car.driver_id == peer_id:
		car.set_driver.rpc(0)  # empty the car before their cat disappears
	$Heist.player_left(peer_id)
	$Quests.player_left(peer_id)
	$Health.player_left(peer_id)
	var cat := cat_for(peer_id)
	# Everything they carried drops where they stood, so nothing is lost.
	$Items.player_left(peer_id, cat.global_position if cat != null else SPAWN_POINT)
	if cat != null:
		cat.queue_free()  # the spawner removes it on everyone's screen too
