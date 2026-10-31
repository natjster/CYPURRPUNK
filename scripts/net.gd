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
##
## PLAYING OVER THE INTERNET (no router setup): when a game is hosted, a background thread asks the
## home router to open PORT by itself (UPnP), and to say our public internet address. That address
## becomes a ROOM CODE (ip_to_code, e.g. 73.154.33.176 = MEOW-499A-21B0), which is all a friend needs:
## join() takes a code or a normal address. The door is closed again when the game ends.
##   upnp_status (signal upnp_updated when it changes):
##     ""             not hosting
##     "opening"      still asking the router (takes a few seconds)
##     "ready"        open! room_code + external_ip work from anywhere
##     "unavailable"  the router said no (UPnP off, or the internet provider shares one address
##                    between many homes = CGNAT). room_code is then this PC's own network / VPN
##                    address (local_ip): it only works for people on that network or VPN.
## Test runs (--capture) never touch a real router. --fake_upnp=73.154.33.176 pretends the router
## answered that address, --fake_upnp=off pretends it said no.

## We joined someone's game successfully.
signal joined
## Joining didn't work (wrong address, nobody hosting...).
signal join_failed
## The host closed the game (or the connection dropped) — we're on our own again.
signal host_left
## The list of games found on the network changed (found_games).
signal games_changed
## The router step moved on (upnp_status, room_code...).
signal upnp_updated

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
## Every room code starts with this (typing it is optional).
const CODE_PREFIX: String = "MEOW-"
## The name our opened door gets in the router's settings page.
const UPNP_NAME: String = "CYPURRPUNK"

## What a host tells the network about its game (game.gd keeps it up to date):
## {"name": host's cat, "city": city number, "players": how many, "max": MAX_PLAYERS}.
var advert: Dictionary = {}
## Games heard on the network: host address -> the advert, plus "seen" (when, in seconds).
var found_games: Dictionary = {}
## Where the router step is: "", "opening", "ready" or "unavailable" (see the top of this file).
var upnp_status: String = ""
## Our public internet address ("ready" only).
var external_ip: String = ""
## This PC's own network / VPN address (the fallback, "unavailable" only).
var local_ip: String = ""
## The code friends type to join ("" = none yet).
var room_code: String = ""

## The background thread that talks to the router.
var _router_thread: Thread = null
## Goes up each time the router step starts or stops, so a late answer from an old game is ignored.
var _router_run: int = 0
var _advert_socket: PacketPeerUDP = null
var _advert_timer: float = 0.0
var _listen_socket: PacketPeerUDP = null


func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): joined.emit())
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## The game is closing: give the router its door back.
func _exit_tree() -> void:
	_close_router()


## Start a game others can join. Returns OK, or an error if the port is already in use.
func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	print("[Network] Hosting on port %d" % PORT)
	_start_advertising()
	_open_router()
	return OK


## Start connecting to a host. The "joined" or "join_failed" signal says how it went.
## address = a room code or a normal address. Empty means "this computer" (two copies of the game
## on one PC).
func join(address: String) -> Error:
	if address.is_empty():
		address = "127.0.0.1"
	var decoded := code_to_ip(address)
	if not decoded.is_empty():
		address = decoded
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
	_close_router()


# --- Room codes ---

## Turn an IPv4 address into a room code: each of its 4 numbers becomes 2 hex characters.
## 73.154.33.176 -> MEOW-499A-21B0. Anything else (IPv6, not an address) gives "".
func ip_to_code(ip: String) -> String:
	if not _is_ipv4(ip):
		return ""
	var hex := ""
	for part in ip.split("."):
		hex += "%02X" % int(part)
	return "%s%s-%s" % [CODE_PREFIX, hex.left(4), hex.right(4)]


## Turn what someone typed or pasted into an address to connect to, or "" if it isn't one.
## Takes MEOW-499A-21B0, 499A-21B0, 499A21B0, any upper / lower case, spaces, and normal IPv4
## addresses (a ":7777" on the end is ignored: the game always uses PORT).
func code_to_ip(text: String) -> String:
	var typed := text.strip_edges()
	var address := typed.get_slice(":", 0)
	if _is_ipv4(address):
		return address
	var hex := typed.to_upper().replace(" ", "").replace("-", "").trim_prefix("MEOW")
	if hex.length() != 8:
		return ""
	for character in hex:
		if not character in "0123456789ABCDEF":
			return ""
	var numbers := PackedStringArray()
	for start in [0, 2, 4, 6]:
		numbers.append(str(hex.substr(start, 2).hex_to_int()))
	return ".".join(numbers)


## What an invite button says right now (the pause menus).
func invite_text() -> String:
	if upnp_status == "opening":
		return "OPENING ROUTER PORT..."
	if room_code.is_empty():
		return "NO INVITE CODE"
	return "COPY %s: %s" % ["CODE" if upnp_status == "ready" else "LAN CODE", room_code]


## Is there an invite row to show (we're hosting a network game)?
func is_hosting() -> bool:
	return upnp_status != ""


func _is_ipv4(ip: String) -> bool:
	return ip.is_valid_ip_address() and ip.count(".") == 3


## Can people on the internet reach this address? (Home-network and CGNAT addresses: no.)
func is_public_ip(ip: String) -> bool:
	if not _is_ipv4(ip):
		return false
	var parts := ip.split(".")
	var first := int(parts[0])
	var second := int(parts[1])
	return not (first in [0, 10, 127] or first >= 224
		or (first == 100 and second >= 64 and second < 128)  # CGNAT
		or (first == 169 and second == 254)
		or (first == 172 and second >= 16 and second < 32)
		or (first == 192 and second == 168))


## The address on this PC most likely to reach a friend when the router said no. VPNs first
## (Tailscale, Hamachi: that's the way to cross the internet then), then the home network.
## Last: 172.16+ and anything ending in .1. On a PC those are usually virtual networks (WSL, Docker,
## Hyper-V, VirtualBox), not a real one: a real PC is rarely the .1, that's the router's number.
func best_local_ip(addresses: PackedStringArray) -> String:
	var best := ""
	var best_score := 0
	for address in addresses:
		if not _is_ipv4(address) or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		var parts := address.split(".")
		var first := int(parts[0])
		var second := int(parts[1])
		var score := 4  # a public or VPN address
		if first == 192 and second == 168:
			score = 1 if parts[3] == "1" else 3
		elif first == 10:
			score = 1 if parts[3] == "1" else 2
		elif first == 172 and second >= 16 and second < 32:
			score = 1
		if score > best_score:
			best = address
			best_score = score
	return best


# --- Opening the router's door (UPnP) ---

## Hosting started: ask the router on a background thread (asking takes seconds: the game
## would freeze if this waited on the main thread).
func _open_router() -> void:
	var fake_answer := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture") and fake_answer.is_empty():
			fake_answer = "none"
		elif arg.begins_with("--fake_upnp="):
			fake_answer = arg.trim_prefix("--fake_upnp=")
			break
	if fake_answer == "none":
		return  # a test run leaves the real router alone
	_close_router()
	upnp_status = "opening"
	upnp_updated.emit()
	_router_thread = Thread.new()
	_router_thread.start(_ask_router_thread.bind(_router_run, fake_answer))


## ON THE BACKGROUND THREAD. Only call_deferred may touch the rest of the game from here.
## Returns the UPNP object if the door stays open (_close_router needs it to close the door).
func _ask_router_thread(run: int, fake_answer: String) -> UPNP:
	var upnp: UPNP = null
	var address := fake_answer
	if fake_answer.is_empty():
		upnp = UPNP.new()
		upnp.discover(2000, 2, "InternetGatewayDevice")
		# (get_gateway logs an error when the router never answered: check first.)
		var gateway := upnp.get_gateway() if upnp.get_device_count() > 0 else null
		if gateway == null or not gateway.is_valid_gateway() \
				or upnp.add_port_mapping(PORT, PORT, UPNP_NAME, "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
			_router_answered.call_deferred(run, "")
			return null
		address = upnp.query_external_address()
	if not is_public_ip(address):
		# A door on a router that isn't on the internet itself (CGNAT): no use to anyone.
		if upnp != null:
			upnp.delete_port_mapping(PORT, "UDP")
			upnp = null
		address = ""
	_router_answered.call_deferred(run, address)
	return upnp


## Back on the main thread with the router's answer ("" = it said no).
func _router_answered(run: int, address: String) -> void:
	if run != _router_run:
		return  # that game has already ended
	external_ip = address
	if address.is_empty():
		upnp_status = "unavailable"
		local_ip = best_local_ip(IP.get_local_addresses())
		room_code = ip_to_code(local_ip)
	else:
		upnp_status = "ready"
		room_code = ip_to_code(address)
	print("[Network] Router: %s, room code %s" % [upnp_status, room_code])
	upnp_updated.emit()


## Hosting ended: wait for the thread and close the router's door again.
func _close_router() -> void:
	_router_run += 1
	if _router_thread != null:
		var opened: UPNP = _router_thread.wait_to_finish()
		_router_thread = null
		if opened != null:
			opened.delete_port_mapping(PORT, "UDP")
	upnp_status = ""
	external_ip = ""
	local_ip = ""
	room_code = ""


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
