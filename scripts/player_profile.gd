class_name PlayerProfile
extends Node
## MEOW-CITY 1999 — SAVED PROGRESS: your cash and your stash, kept between games.
## Attach to the "Profile" node in main.tscn. Reach it with PlayerProfile.instance.
##
## What's saved: your CASH and what's in your STASH (the lockers in the sewers). That's all:
## what you carry (paws, backpack, loot bag) is NOT saved, so put gear in the stash before you
## quit — a player who quits drops what they carry on the spot, like before.
##
## Where: on YOUR computer, one file per cat you've made (Settings.cats, CHOOSE YOUR CAT screen):
##   user://profiles/<cat id>.cfg   (Windows: %APPDATA%\MeowCity1999\profiles\)
## so each of your cats has its own cash and stash, whoever's game you join. Two copies of
## the game on one PC should play different cats, or they'd share (and overwrite) one save.
##
## How it works (multiplayer: the host is the referee, as always):
##   1. When you start or join a game, game.gd calls restore(): we read our file and send
##      our cash + stash to the host (_request_restore).
##   2. The host checks it (real items only, sensible cash), sets it for everyone, and says
##      "done" (_restore_done).
##   3. From then on, whenever OUR cash or stash changes, we save the file again (_process).
##      (Not before step 2, or a fresh $0 could overwrite your save while it loads.)
## The host trusts what players send, same as the rest of the game: fine between friends.
##
## Test runs (DevCapture, "--capture=...") use user://test_profiles/ instead, so tests never
## touch your real saves. --fresh_profile starts that test save from scratch.

const PROFILES_FOLDER: String = "user://profiles/"
const TEST_PROFILES_FOLDER: String = "user://test_profiles/"
## The host refuses saved cash above this (a broken or hand-edited file).
const MAX_CASH: int = 10_000_000

## The one profile node (PlayerProfile.instance).
static var instance: PlayerProfile

var _path: String = ""
var _restored: bool = false  # the host has applied our save: changes may be saved now
var _saved_key: String = ""  # what we last saved, so we only write when something changed


func _enter_tree() -> void:
	instance = self


## Called by game.gd once we're in a game (hosting or joined): load our save, send it to the host.
func restore() -> void:
	_path = _profile_path()
	var config := ConfigFile.new()
	var cash := 0
	var stash: Array = []
	if config.load(_path) == OK:
		cash = int(config.get_value("progress", "cash", 0))
		var saved: Variant = config.get_value("progress", "stash", [])
		if saved is Array:
			stash = saved
		print("[Profile] Loaded %s: $%d, stash %s" % [_path, cash, stash])
	else:
		print("[Profile] No save yet at %s: starting fresh" % _path)
	_request_restore.rpc_id(1, cash, stash)


## Delete a cat's save file (the CHOOSE YOUR CAT screen calls this when you delete a cat).
static func forget_cat(cat_id: String) -> void:
	if not cat_id.is_empty():
		DirAccess.remove_absolute(PROFILES_FOLDER + cat_id.validate_filename() + ".cfg")


## The save file for the cat we're playing as.
func _profile_path() -> String:
	var user_args := OS.get_cmdline_user_args()
	var is_test_run := false
	for arg in user_args:
		is_test_run = is_test_run or arg.begins_with("--capture")
	var player := str(Settings.current_cat().get("id", "")).validate_filename()
	if is_test_run:
		# Tests name their save after --name, or keep the host's and the joiner's apart.
		player = Game.local_player_name.validate_filename().to_lower()
		if player.is_empty():
			player = "host" if multiplayer.is_server() else "join"
	elif player.is_empty():
		player = "cat"
	var folder := TEST_PROFILES_FOLDER if is_test_run else PROFILES_FOLDER
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder + player + ".cfg"
	if is_test_run and "--fresh_profile" in user_args:
		DirAccess.remove_absolute(path)
	return path


# --- The host checks and applies a player's save ---

@rpc("any_peer", "call_local", "reliable")
func _request_restore(cash: int, stash: Array) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var items := ItemManager.instance
	var clean: Array = []
	for item_id in stash:
		# Only real gear (no loot, no unknown items), and no more than fits in the stash.
		if item_id is String and items.catalog.has(item_id) \
				and (items.catalog[item_id] as ItemData).kind != ItemData.Kind.LOOT and clean.size() < items.stash_size:
			clean.append(item_id)
	FishHeist.instance._set_cash.rpc(peer_id, clampi(cash, 0, MAX_CASH))
	items.set_stash(peer_id, clean)
	print("[Profile] Player %d came back with $%d and stash %s" % [peer_id, clampi(cash, 0, MAX_CASH), clean])
	_restore_done.rpc_id(peer_id)


## Host -> the player: your save is in the game. Start saving changes from now on.
@rpc("authority", "call_local", "reliable")
func _restore_done() -> void:
	_restored = true
	_saved_key = _current_key()  # nothing new to save yet


# --- Saving (our own computer only) ---

func _process(_delta: float) -> void:
	if not _restored:
		return
	var key := _current_key()
	if key != _saved_key:
		_saved_key = key
		_save()


## Our cash and stash as text, to spot changes cheaply.
func _current_key() -> String:
	return str([_my_cash(), ItemManager.instance.get_stash(multiplayer.get_unique_id())])


func _my_cash() -> int:
	return FishHeist.instance.cash.get(multiplayer.get_unique_id(), 0)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "cash", _my_cash())
	config.set_value("progress", "stash", ItemManager.instance.get_stash(multiplayer.get_unique_id()))
	config.save(_path)
