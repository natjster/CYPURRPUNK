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
## Split screen: every player on this computer plays one of the cats, and each has its own
## file the same way (they're kept apart by player ID, scripts/player_id.gd).
##
## How it works (multiplayer: the host is the referee, as always):
##   1. When you start or join a game (or a couch player joins in), game.gd calls
##      restore(player_id, ...): we read that cat's file and send its cash + stash to the
##      host (_request_restore).
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

## Every player on THIS computer that has a save: player ID -> {"path": the file,
## "restored": true once the host applied it (changes may be saved from then on),
## "saved_key": what we last saved, so we only write when something changed}.
var _local := {}


func _enter_tree() -> void:
	instance = self


## Called by game.gd for each player on this computer once they're in a game: load the save
## of the cat they play (cat_id from Settings.cats) and send it to the host.
## player_name is only used by test runs, to name their test save.
func restore(player_id: int, cat_id: String, player_name: String) -> void:
	var path := _profile_path(player_id, cat_id, player_name)
	_local[player_id] = {"path": path, "restored": false, "saved_key": ""}
	var config := ConfigFile.new()
	var cash := 0
	var stash: Array = []
	if config.load(path) == OK:
		cash = int(config.get_value("progress", "cash", 0))
		var saved: Variant = config.get_value("progress", "stash", [])
		if saved is Array:
			stash = saved
		print("[Profile] Loaded %s: $%d, stash %s" % [path, cash, stash])
	else:
		print("[Profile] No save yet at %s: starting fresh" % path)
	_request_restore.rpc_id(1, player_id, cash, stash)


## A player on this computer left the game (split screen: one couch player drops out).
## Their file is already up to date (we save on every change); stop watching it.
func forget(player_id: int) -> void:
	_local.erase(player_id)


## Delete a cat's save file (the CHOOSE YOUR CAT screen calls this when you delete a cat).
static func forget_cat(cat_id: String) -> void:
	if not cat_id.is_empty():
		DirAccess.remove_absolute(PROFILES_FOLDER + cat_id.validate_filename() + ".cfg")


## The save file for a cat.
func _profile_path(player_id: int, cat_id: String, player_name: String) -> String:
	var user_args := OS.get_cmdline_user_args()
	var is_test_run := false
	for arg in user_args:
		is_test_run = is_test_run or arg.begins_with("--capture")
	var file := cat_id.validate_filename()
	if is_test_run:
		# Tests name their save after --name, or keep the host's and the joiner's apart.
		file = player_name.validate_filename().to_lower()
		if file.is_empty():
			file = "host" if multiplayer.is_server() else "join"
			if PlayerId.slot_of(player_id) > 0:
				file += "_%d" % (PlayerId.slot_of(player_id) + 1)  # split-screen test players
	elif file.is_empty():
		file = "cat"
	var folder := TEST_PROFILES_FOLDER if is_test_run else PROFILES_FOLDER
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder + file + ".cfg"
	if is_test_run and "--fresh_profile" in user_args:
		DirAccess.remove_absolute(path)
	return path


# --- The host checks and applies a player's save ---

@rpc("any_peer", "call_local", "reliable")
func _request_restore(player_id: int, cash: int, stash: Array) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id):
		return
	if PlayerId.slot_of(player_id) > 0 and Game.instance.cat_for(player_id) == null:
		return  # a couch player the host didn't let in (the game was full)
	var items := ItemManager.instance
	var clean: Array = []
	for item_id in stash:
		# Only real gear (no loot, no unknown items), and no more than fits in the stash.
		if item_id is String and items.catalog.has(item_id) \
				and (items.catalog[item_id] as ItemData).kind != ItemData.Kind.LOOT and clean.size() < items.stash_size:
			clean.append(item_id)
	FishHeist.instance._set_cash.rpc(player_id, clampi(cash, 0, MAX_CASH))
	items.set_stash(player_id, clean)
	print("[Profile] Player %d came back with $%d and stash %s" % [player_id, clampi(cash, 0, MAX_CASH), clean])
	_restore_done.rpc_id(PlayerId.peer_of(player_id), player_id)


## Host -> the player's computer: their save is in the game. Start saving changes from now on.
@rpc("authority", "call_local", "reliable")
func _restore_done(player_id: int) -> void:
	if not _local.has(player_id):
		return
	_local[player_id].restored = true
	_local[player_id].saved_key = _current_key(player_id)  # nothing new to save yet


# --- Saving (our own computer only) ---

func _process(_delta: float) -> void:
	for player_id in _local:
		var save: Dictionary = _local[player_id]
		if not save.restored:
			continue
		var key := _current_key(player_id)
		if key != save.saved_key:
			save.saved_key = key
			_save(player_id, save.path)


## A player's cash and stash as text, to spot changes cheaply.
func _current_key(player_id: int) -> String:
	return str([_cash_of(player_id), ItemManager.instance.get_stash(player_id)])


func _cash_of(player_id: int) -> int:
	return FishHeist.instance.cash.get(player_id, 0)


func _save(player_id: int, path: String) -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "cash", _cash_of(player_id))
	config.set_value("progress", "stash", ItemManager.instance.get_stash(player_id))
	config.save(path)
