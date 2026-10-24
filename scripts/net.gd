extends Node
## MEOW-CITY 1999 — the network connection: hosting, joining and leaving a game.
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

## We joined someone's game successfully.
signal joined
## Joining didn't work (wrong address, nobody hosting...).
signal join_failed
## The host closed the game (or the connection dropped) — we're on our own again.
signal host_left

## The network "door" number the game uses. Friends' firewalls must allow it (UDP).
const PORT: int = 7777
## Most players in one game, host included.
const MAX_PLAYERS: int = 8


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
