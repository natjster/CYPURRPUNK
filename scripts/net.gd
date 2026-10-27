extends Node
## CYPURRPUNK — the network connection: hosting, joining and leaving a game.
## Loaded automatically on startup (it's an Autoload named "Net").
##
## Everything that knows HOW players connect lives here, so switching from LAN (ENet) to
## Steam later only changes this file. The rest of the game just uses Godot's normal
## "multiplayer" features (RPCs, MultiplayerSpawner, MultiplayerSynchronizer), which work
## the same whatever the connection is.
##
## Who reacts to what:
##   - game.gd listens to multiplayer.peer_connected / peer_disconnected (spawning cats),
##     and to the signals below (start playing, back to the menu).
##
## FINDING GAMES ON YOUR NETWORK (no typing IP addresses): while hosting, this computer shouts
## "a CYPURRPUNK game is here!" to the whole local network once a second (a small UDP broadcast
## on DISCOVERY_PORT, with what's in `advert`: host name, city number, players). The MULTIPLAYER
## screen listens (start_listening) and lists every game it hears (`found_games`, signal
## games_changed). Firewalls must allow UDP 7777 AND 7778.

## We joined someone's game successfully.
signal joined
## Joining didn't work (wrong address, nobody hosting...).
signal join_failed
## The host closed the game (or the connection dropped) — we're on our own again.
signal host_left
## The list of games found on the network changed (found_games).
signal games_changed

## The network "door" number the game uses. Friends' firewalls must allow it (UDP).
const PORT: int = 7777
## Most players in one game, host included.
const MAX_PLAYERS: int = 8
## The "door" for finding games on the network (UDP broadcast). Friends' firewalls must allow it.
const DISCOVERY_PORT: int = 7778
## How often a host announces its game (seconds).
const ADVERT_SECONDS: float = 1.0
## A game not heard from for this long disappears from the list (seconds).
const FORGET_SECONDS: float = 3.5
## Every announcement starts with this, so we never mistake another program's broadcast for a game.
const ADVERT_TAG: String = "MEOWCITY1999"

## What a host tells the network about its game (game.gd keeps it up to date):
## {"name": host's cat, "city": city number, "players": how many, "max": MAX_PLAYERS}.
var advert: Dictionary = {}
## Games heard on the network: host address -> the advert, plus "seen" (when, in seconds).
var found_games: Dictionary = {}

var _advert_socket: PacketPeerUDP = null
var _advert_timer: float = 0.0
var _listen_socket: PacketPeerUDP = null


func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): joined.emit())
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Start a game others can join. Returns OK, or an error if the port is already in use.
func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	print("[Network] Hosting on port %d" % PORT)
	_start_advertising()
	return OK


## Start connecting to a host. The "joined" or "join_failed" signal says how it went.
## An empty address means "this computer" (two copies of the game on one PC).
func join(address: String) -> Error:
	if address.is_empty():
		address = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	return OK


## Disconnect and go back to playing alone. If we were the host, everyone else is sent
## back to their menu too.
func leave() -> void:
	multiplayer.multiplayer_peer.close()
	_go_offline()


func _on_connection_failed() -> void:
	_go_offline()
	join_failed.emit()


func _on_server_disconnected() -> void:
	_go_offline()
	host_left.emit()


## "Offline" = playing alone, not "no network at all": this computer is its own host (ID 1).
func _go_offline() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_stop_advertising()


# --- Finding games on the local network ---

## The MULTIPLAYER screen is open: listen for games being announced.
func start_listening() -> void:
	if _listen_socket != null:
		return
	_listen_socket = PacketPeerUDP.new()
	if _listen_socket.bind(DISCOVERY_PORT) != OK:
		# (Another copy of the game on this PC is already listening: only one can.)
		print("[Network] Can't listen for games on port %d (in use)" % DISCOVERY_PORT)
		_listen_socket = null


## The MULTIPLAYER screen closed: stop listening and forget the list.
func stop_listening() -> void:
	if _listen_socket != null:
		_listen_socket.close()
		_listen_socket = null
	if not found_games.is_empty():
		found_games.clear()
		games_changed.emit()


func _start_advertising() -> void:
	_advert_socket = PacketPeerUDP.new()
	_advert_socket.set_broadcast_enabled(true)
	_advert_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_advert_timer = 0.0


func _stop_advertising() -> void:
	if _advert_socket != null:
		_advert_socket.close()
		_advert_socket = null


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Hosting: announce the game every ADVERT_SECONDS.
	if _advert_socket != null:
		_advert_timer -= delta
		if _advert_timer <= 0.0:
			_advert_timer = ADVERT_SECONDS
			_advert_socket.put_packet((ADVERT_TAG + JSON.stringify(advert)).to_utf8_buffer())
	# Listening: collect announcements, drop games that went quiet.
	if _listen_socket == null:
		return
	var changed := false
	while _listen_socket.get_available_packet_count() > 0:
		var text := _listen_socket.get_packet().get_string_from_utf8()
		var address := _listen_socket.get_packet_ip()
		if not text.begins_with(ADVERT_TAG):
			continue
		var info: Variant = JSON.parse_string(text.trim_prefix(ADVERT_TAG))
		if not info is Dictionary:
			continue
		changed = changed or not found_games.has(address) or found_games[address].get("players") != info.get("players")
		info["seen"] = now
		found_games[address] = info
	for address in found_games.keys():
		if now - float(found_games[address].seen) > FORGET_SECONDS:
			found_games.erase(address)
			changed = true
	if changed:
		games_changed.emit()
