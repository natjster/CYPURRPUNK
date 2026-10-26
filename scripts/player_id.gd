class_name PlayerId
## MEOW-CITY 1999 — PLAYER IDs: one number per player (per cat), even with several players
## on one computer (split screen).
##
## Two different numbers, don't mix them up:
##   NETWORK ID ("peer")  = which COMPUTER. Godot hands these out: the host is always 1,
##                          joiners get big random numbers like 771171244.
##   PLAYER ID            = which PLAYER / CAT. Made from the computer's network ID plus the
##                          player's SLOT on that computer (0 = first player, 1 = second...).
##
## The first player on a computer (slot 0) has a player ID EQUAL to the computer's network ID,
## so with one player per computer everything is the same numbers as before (the host's cat is
## still "1"). Extra couch players get the slot added on top (slot * 4294967296), which keeps
## them apart and lets anyone work out which computer they're on:
##   PlayerId.make(771171244, 1) = 5066138540  ->  peer_of() = 771171244, slot_of() = 1
##
## Every per-player list in the game (cash, HP, inventories, quests, who's driving, the cat
## nodes under Players/) uses PLAYER IDs. Network IDs are only for "who sent this RPC" and
## "send this RPC to which computer" (rpc_id(PlayerId.peer_of(player_id), ...)).
##
## All functions are static: call them on the class, e.g. PlayerId.is_local(id).

## Most players on one computer (split screen). Two computers x 4 = the full 8.
const MAX_LOCAL: int = 4
## Slot numbers live above the 32 bits a network ID uses.
const SLOT_FACTOR: int = 4294967296  # 2^32


## The player ID of player number "slot" (0..3) on the computer with this network ID.
static func make(peer: int, slot: int) -> int:
	return peer + slot * SLOT_FACTOR


## Which computer this player is on (its network ID).
static func peer_of(player_id: int) -> int:
	return player_id % SLOT_FACTOR


## Which player on that computer: 0 = the first one, 1 = the second...
static func slot_of(player_id: int) -> int:
	return player_id / SLOT_FACTOR


## Is this player on THIS computer?
static func is_local(player_id: int) -> bool:
	return player_id != 0 and peer_of(player_id) == _multiplayer().get_unique_id()


## The first (slot 0) player on this computer.
static func first_local() -> int:
	return make(_multiplayer().get_unique_id(), 0)


## Host, inside an "any_peer" RPC: did the computer that sent it really own this player?
## (Stops one computer from moving another computer's items or cash.)
static func sender_owns(player_id: int) -> bool:
	return player_id != 0 and peer_of(player_id) == _multiplayer().get_remote_sender_id()


static func _multiplayer() -> MultiplayerAPI:
	return (Engine.get_main_loop() as SceneTree).get_multiplayer()
