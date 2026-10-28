class_name Game
extends Node3D
## CYPURRPUNK — main scene script: starts games, spawns cats, keeps late joiners in sync.
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
##   - A cat is named after its PLAYER ID (scripts/player_id.gd). One computer can have up to
##     4 players (split screen): the first one joins with the computer, more join in with
##     add_local_player() and can drop out again with remove_local_player().
##   - The city is generated from a seed number (see city_generator.gd). The host
##     sends just that number to each player, and everyone builds the same city.
##   - Cats start in THE SEWERS, the underground hub 200 m below the city (hub.gd).
##     Don Catleone sends them up a manhole; the EXIT manhole brings them back (fish_heist.gd).
##
## Testing shortcuts: launch the game with "--solo", "--host" or "--join" to skip the menu
## (plus "--name=Whiskers" / "--seed=42" for the cat's name and the city number).

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
## Why we were sent back to the start menu (e.g. "That game is full."), shown there once.
static var leave_reason: String = ""
## Split screen: the EXTRA players on this computer (slot 1, 2, 3 -> {"name", "look", "cat_id"}).
## Slot 0, the first player, is always the cat picked in CHOOSE YOUR CAT (Settings.current_cat()).
var extra_local_players := {}

@onready var players: Node3D = $Players
@onready var car: GetawayCar = $GetawayCar
@onready var city: CityGenerator = $City
@onready var main_menu: MainMenu = $PS1Overlay/Lobby
@onready var pause_menu: PauseMenu = $PS1Overlay/PauseMenu
@onready var settings_menu: SettingsMenu = $PS1Overlay/SettingsMenu
@onready var cat_creator: CatCreator = $PS1Overlay/CatCreator
@onready var hub: UndergroundHub = $Hub
@onready var crt_material: ShaderMaterial = $PS1Overlay/ColorDepthDither.material

## The CRT slider values at full strength (read from the shader), scaled by Settings.crt_strength.
var _crt_full: Dictionary = {}


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	# The start menu's way through (main_menu.gd): PLAY -> SOLO (pick your cat) or MULTIPLAYER ->
	# LOCAL / ONLINE CO-OP -> the landing page where everyone joins and picks a cat.
	main_menu.cat_pressed.connect(cat_creator.open.bind(false))
	cat_creator.next_pressed.connect(main_menu.cat_done)
	main_menu.solo_pressed.connect(solo_game)
	main_menu.host_pressed.connect(host_game)
	main_menu.join_pressed.connect(join_game)
	main_menu.settings_pressed.connect(settings_menu.open)
	pause_menu.settings_pressed.connect(settings_menu.open)
	main_menu.lobby_cat_pressed.connect(func(seat: int): cat_creator.open(false, seat))  # couch player's cat
	pause_menu.cat_pressed.connect(func(): cat_creator.open(true, pause_menu.opened_by))  # restyle your cat mid-game
	pause_menu.leave_pressed.connect(_back_to_menu.bind(true))
	settings_menu.closed.connect(_on_settings_closed)
	cat_creator.closed.connect(_on_cat_creator_closed)  # back to whichever menu opened it

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

	Seats.reset()  # one player, no controllers claimed yet (scripts/seats.gd)
	if leave_reason != "":
		main_menu.show_status.call_deferred(leave_reason)
		leave_reason = ""
	Hud.set_in_game(false)  # the HUD (scenes/ui/hud.tscn) waits for a game to start
	city.generate(PREVIEW_SEED)
	park_car()
	_handle_test_shortcuts()


func _handle_test_shortcuts() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--name="):  # e.g. --name=Whiskers (names the current cat; tests never save it)
			Settings.update_current_cat({"name": arg.trim_prefix("--name=")})
		if arg.begins_with("--seed="):  # e.g. --seed=42
			main_menu.seed_input.text = arg.trim_prefix("--seed=")
	if "--solo" in args:
		Seats.coop = false
		solo_game(main_menu.chosen_seed())
	elif "--host" in args:
		Seats.coop = true  # (online co-op)
		host_game(main_menu.chosen_seed())
	elif "--join" in args:
		Seats.coop = true
		join_game(main_menu.address_input.text.strip_edges())


# --- Starting and leaving a game ---

## SOLO: a game just for you. No network at all: this computer stays "offline" (Net), where it
## is its own host (player 1), so everything works exactly like hosting, but nobody can join.
func solo_game(city_seed: int) -> void:
	_remember_name()
	_begin_game(city_seed)


## MULTIPLAYER > HOST: start a game others can join.
func host_game(city_seed: int) -> void:
	_remember_name()
	if Net.host() != OK:
		main_menu.show_status("Can't host - is another game already hosting?")
		return
	_begin_game(city_seed)


## Host (or solo): build the city and start.
func _begin_game(city_seed: int) -> void:
	city.generate(city_seed)
	park_car()
	_start_playing()
	_spawn_cat(PlayerId.make(1, 0))  # the host's own (first) player
	$Heat.reset()  # the city starts calm (scripts/heat_meter.gd)
	$Roombas.start_patrol()  # the VAC-COPs come out (the spawner copies them to everyone)


func join_game(address: String) -> void:
	_remember_name()
	if Net.join(address) != OK:
		main_menu.show_status("Can't start connecting.")
		return
	main_menu.show_status("Connecting to %s..." % (address if address != "" else "this computer"))


## Our cat's name (from CHOOSE YOUR CAT), which our cat shows to everyone.
func _remember_name() -> void:
	local_player_name = str(Settings.current_cat().get("name", ""))


func _on_joined() -> void:
	print("[Network] Joined game as player %d" % multiplayer.get_unique_id())
	_start_playing()


func _start_playing() -> void:
	main_menu.hide()
	Hud.set_in_game(true)
	pause_menu.enabled = true
	# Bring back our first player's saved cash + stash (player_profile.gd).
	$Profile.restore(PlayerId.first_local(), str(Settings.current_cat().get("id", "")), local_player_name)
	# Couch players from the start menu's lobby come along (scripts/seats.gd).
	Seats.game_started()
	Seats.start_lobby_players()


## Back to a fresh start menu: we chose LEAVE GAME, or the host closed the game.
func _back_to_menu(we_left: bool) -> void:
	if we_left:
		Net.leave()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


## CHOOSE YOUR CAT / MY CAT closed (BACK / DONE): back to whichever menu opened it.
func _on_cat_creator_closed() -> void:
	if cat_creator.back_to_player_pause:
		PlayerPause.for_seat(cat_creator.seat).open()  # opened from a player's own small pause menu
	elif pause_menu.enabled:
		pause_menu.open()
	else:
		main_menu.cat_closed()


## The settings menu closed: go back to whichever menu opened it.
func _on_settings_closed() -> void:
	if pause_menu.enabled:
		pause_menu.open()
	else:
		main_menu.show_main_screen()


## Host: the hatch was sealed (fish_heist.gd), so the rebellion moves to a NEW DISTRICT: a new
## city seed for everyone, the car back at its spot, the heat back to calm, a fresh patrol.
## (Everyone should be down in the sewers by now: the DEEP CLEAN knocked out anyone up top.)
func new_district() -> void:
	var new_seed := randi_range(1, 99999)
	print("[Game] New district: city #%d" % new_seed)
	_receive_city_seed.rpc(new_seed)  # everyone else builds it...
	city.generate(new_seed)  # ...and so do we
	park_car()
	$Heat.reset()
	$Roombas.start_patrol()
	_district_news.rpc()


## Host -> everyone: Don's news about the new district.
@rpc("authority", "call_local", "reliable")
func _district_news() -> void:
	Hud.show_message("DON CATLEONE: We're movin' to a new part of town. Hatch is ready when you are.", 5.0)


## Host → one player: "build city number X". Every computer builds the identical city.
@rpc("authority", "call_remote", "reliable")
func _receive_city_seed(city_seed: int) -> void:
	city.generate(city_seed)


## Hosting: what the network hears about our game (Net.advert, the MULTIPLAYER screen's list).
func _process(_delta: float) -> void:
	if multiplayer.is_server():
		Net.advert = {"name": local_player_name.to_upper(), "city": city.city_seed,
			"players": player_count(), "max": Net.MAX_PLAYERS}




## How many players are in the game right now, on every computer (up to Net.MAX_PLAYERS = 8).
## The balance scales with it: more VAC-COPs, faster heat, faster-growing loot, an extra beam.
func player_count() -> int:
	return players.get_child_count()


## Every player on this computer who has a screen right now (couch co-op): their cats.
func playing_cats() -> Array[CatPlayer]:
	var list: Array[CatPlayer] = []
	for cat in local_cats():
		if cat.reads_input():
			list.append(cat)
	return list


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

## A player's cat (cats are named after their PLAYER ID, scripts/player_id.gd), or null.
func cat_for(player_id: int) -> CatPlayer:
	if player_id == 0:
		return null
	return players.get_node_or_null(str(player_id)) as CatPlayer


## The cat of this computer's FIRST player, or null (e.g. still in the start menu).
func my_cat() -> CatPlayer:
	return cat_for(PlayerId.first_local())


## Every cat played on this computer (split screen: more than one), first player first.
func local_cats() -> Array[CatPlayer]:
	var list: Array[CatPlayer] = []
	for slot in PlayerId.MAX_LOCAL:
		var cat := cat_for(PlayerId.make(multiplayer.get_unique_id(), slot))
		if cat != null:
			list.append(cat)
	return list


## Name, look and saved-cat id of the player sitting at this slot on THIS computer.
## (Our cats read it when they appear: cat_player.gd.)
func local_player_info(slot: int) -> Dictionary:
	if slot == 0:
		var cat := Settings.current_cat()
		return {"name": local_player_name, "look": cat.get("look", {}), "cat_id": str(cat.get("id", ""))}
	return extra_local_players.get(slot, {"name": "PLAYER %d" % (slot + 1), "look": {}, "cat_id": ""})


## Split screen: one more player on this computer joins the game in "slot" (1, 2 or 3), playing
## the cat described by info ({"name", "look", "cat_id"} - cat_id picks their saved cash + stash).
## The host makes the cat; then we send that cat's save, like the first player's.
func add_local_player(slot: int, info: Dictionary) -> void:
	if slot < 1 or slot >= PlayerId.MAX_LOCAL or extra_local_players.has(slot):
		return
	extra_local_players[slot] = info
	_request_add_player.rpc_id(1, slot)
	$Profile.restore(PlayerId.make(multiplayer.get_unique_id(), slot), str(info.get("cat_id", "")), str(info.get("name", "")))


## Split screen: the player in "slot" (1, 2 or 3) on this computer drops out. Like quitting:
## what they carry drops where they stand; their stash is safe in their save.
func remove_local_player(slot: int) -> void:
	if not extra_local_players.has(slot):
		return
	var player_id := PlayerId.make(multiplayer.get_unique_id(), slot)
	extra_local_players.erase(slot)
	$Profile.forget(player_id)
	_request_remove_player.rpc_id(1, player_id)


## Host: a computer wants one more player (split screen). Fine if the game isn't full.
@rpc("any_peer", "call_local", "reliable")
func _request_add_player(slot: int) -> void:
	if not multiplayer.is_server() or slot < 1 or slot >= PlayerId.MAX_LOCAL:
		return
	var player_id := PlayerId.make(multiplayer.get_remote_sender_id(), slot)
	if cat_for(player_id) != null:
		return  # already playing
	if players.get_child_count() >= Net.MAX_PLAYERS:
		print("[Network] Game is full (%d players): no room for player %d" % [Net.MAX_PLAYERS, player_id])
		_add_player_refused.rpc_id(PlayerId.peer_of(player_id), slot)
		return
	print("[Network] Player %d joined in (split screen, slot %d)" % [player_id, slot])
	_spawn_cat(player_id)


## Host -> a computer: no room for your player in "slot" (the game has 8 players).
@rpc("authority", "call_local", "reliable")
func _add_player_refused(slot: int) -> void:
	extra_local_players.erase(slot)
	$Profile.forget(PlayerId.make(multiplayer.get_unique_id(), slot))
	Seats.refused(slot)


## Host -> a computer that just connected: sorry, all 8 places are taken.
@rpc("authority", "call_remote", "reliable")
func _game_full() -> void:
	leave_reason = "That game is full (%d players)." % Net.MAX_PLAYERS


## Host: a computer says one of its players dropped out.
@rpc("any_peer", "call_local", "reliable")
func _request_remove_player(player_id: int) -> void:
	if multiplayer.is_server() and PlayerId.sender_owns(player_id) and PlayerId.slot_of(player_id) > 0:
		_remove_player(player_id)


## Host only: create a cat for a player ID. The spawner copies it to everyone.
func _spawn_cat(player_id: int) -> void:
	var cat := PLAYER_SCENE.instantiate()
	cat.name = str(player_id)  # the name IS the owner — see cat_player.gd _enter_tree()
	cat.position = hub.spawn_position(players.get_child_count())  # everyone starts in the sewers
	players.add_child(cat, true)


func _on_peer_connected(peer_id: int) -> void:
	print("[Network] Computer %d connected" % peer_id)
	if multiplayer.is_server() and players.get_child_count() >= Net.MAX_PLAYERS:
		# All 8 places are taken (e.g. two computers with 4 players each): say why, then hang up.
		print("[Network] Game is full: sending computer %d away" % peer_id)
		_game_full.rpc_id(peer_id)
		await get_tree().create_timer(0.5).timeout
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	if multiplayer.is_server():
		_receive_city_seed.rpc_id(peer_id, city.city_seed)  # build the same city first
		$Items.send_state_to(peer_id)  # then which items are taken, who holds/carries what
		$Heist.send_state_to(peer_id)  # then everyone's cash
		$Quests.send_state_to(peer_id)  # and everyone's quests
		$Health.send_state_to(peer_id)  # and everyone's HP
		$Heat.send_state_to(peer_id)  # and how angry the city is
		_spawn_cat(PlayerId.make(peer_id, 0))  # their first player (more can join in later)
		# Late joiner: tell them who's already driving, so that driver's cat is hidden
		# and their copy of the car follows the right player.
		if car.driver_id != 0:
			car.set_driver.rpc_id(peer_id, car.driver_id)


## A computer left: every player on it leaves.
func _on_peer_disconnected(peer_id: int) -> void:
	print("[Network] Computer %d left" % peer_id)
	if not multiplayer.is_server():
		return
	for slot in PlayerId.MAX_LOCAL:
		_remove_player(PlayerId.make(peer_id, slot))


## Host only: a player is gone (their computer left, or a split-screen player dropped out).
func _remove_player(player_id: int) -> void:
	var cat := cat_for(player_id)
	if cat == null and not $Heist.cash.has(player_id):
		return  # never played (e.g. an empty split-screen slot)
	print("[Network] Player %d left" % player_id)
	if car.driver_id == player_id:
		car.set_driver.rpc(0)  # empty the car before their cat disappears
	$Heist.player_left(player_id)
	$Quests.player_left(player_id)
	$Health.player_left(player_id)
	# Everything they carried drops where they stood, so nothing is lost.
	$Items.player_left(player_id, cat.global_position if cat != null else SPAWN_POINT)
	if cat != null:
		cat.queue_free()  # the spawner removes it on everyone's screen too
