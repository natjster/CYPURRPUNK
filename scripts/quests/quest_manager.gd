class_name QuestManager
extends Node
## CYPURRPUNK — THE QUEST SYSTEM. Attach to the "Quests" node in main.tscn.
## Reach it from anywhere with QuestManager.instance.
##
## Quest cards are QuestData .tres files in res://quests/, loaded automatically.
## NPCs hand quests out: a talk-box choice with the Action "quest:<id>" (see npc.gd), and
## their pages can change depending on the quest's state (NpcPage "Only If Quest").
##
## Multiplayer: the HOST is the referee, same as items and cash.
##   - Taking a quest asks the host (request_start). The host tells everyone (_set_quests).
##   - Progress isn't sent at all: it's counted from your loot bag, which every computer
##     already knows about (ItemManager.inventories).
##   - At the extraction beam, fish_heist.gd asks the host's QuestManager for the bonus
##     (complete_on_extract) BEFORE the loot bag is emptied.
##   - Late joiners get everyone's quests (send_state_to); quitters are forgotten.
##
## Quest states, per player (what NpcPage's "Only If State" checks):
##   "not_started"  doesn't have it right now (never taken, or finished and repeatable)
##   "active"       has it right now
##   "done"         finished it at least once and doesn't have it right now

## The one quest manager (QuestManager.instance).
static var instance: QuestManager

const QUESTS_FOLDER := "res://quests/"

## Quest id -> QuestData, for every card in res://quests/.
var catalog := {}
## Player ID -> Array of active quest ids. Everyone keeps a copy; only the host changes it.
var active := {}
## Player ID -> {quest id: times completed}. Same deal.
var completed := {}


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	for file in DirAccess.get_files_at(QUESTS_FOLDER):
		file = file.trim_suffix(".remap")  # exported games rename resources
		if file.ends_with(".tres"):
			var data := load(QUESTS_FOLDER + file) as QuestData
			if data != null and not data.id.is_empty():
				catalog[data.id] = data
	print("[Quests] Loaded %d quest cards: %s" % [catalog.size(), ", ".join(catalog.keys())])


# --- Questions anyone can ask (every computer has the answers) ---

## "not_started", "active" or "done" (see the top of this file).
func state_of(player_id: int, quest_id: String) -> String:
	if quest_id in active.get(player_id, []):
		return "active"
	if completed.get(player_id, {}).get(quest_id, 0) > 0:
		return "done"
	return "not_started"


## Used by NPC pages: is the quest in this state? Also understands "ready" =
## active AND the objective is done (go extract!).
func is_in_state(player_id: int, quest_id: String, wanted: String) -> bool:
	if not catalog.has(quest_id):
		push_warning("No quest card with id '%s' in %s" % [quest_id, QUESTS_FOLDER])
		return false
	var state := state_of(player_id, quest_id)
	if wanted == "ready":
		return state == "active" and progress(player_id, quest_id) >= (catalog[quest_id] as QuestData).count
	return state == wanted


## How many of the quest's items this player is carrying right now.
func progress(player_id: int, quest_id: String) -> int:
	var data: QuestData = catalog[quest_id]
	return ItemManager.instance.get_inventory(player_id).bag.count(data.item)


## The top-left HUD line for our first active quest, or "" if we have none.
## e.g. "MITTENS' FISH 2/3"  or  "MITTENS' FISH 3/3 - EXTRACT!"
func hud_text(player_id: int) -> String:
	for quest_id in active.get(player_id, []):
		var data: QuestData = catalog[quest_id]
		var have := mini(progress(player_id, quest_id), data.count)
		return "%s %d/%d%s" % [data.title, have, data.count, " - EXTRACT!" if have >= data.count else ""]
	return ""


# --- Taking a quest ---

## Call on your own computer (the NPC does this): ask the host to give this player the quest.
func start_quest(player_id: int, quest_id: String) -> void:
	if not catalog.has(quest_id):
		push_warning("No quest card with id '%s' in %s" % [quest_id, QUESTS_FOLDER])
		return
	_request_start.rpc_id(1, player_id, quest_id)


@rpc("any_peer", "call_local", "reliable")
func _request_start(player_id: int, quest_id: String) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id) or not catalog.has(quest_id):
		return
	var data: QuestData = catalog[quest_id]
	var state := state_of(player_id, quest_id)
	if state == "active" or (state == "done" and not data.repeatable):
		return  # already on it / one-time quest already done
	var list: Array = active.get(player_id, []).duplicate()
	list.append(quest_id)
	_set_quests.rpc(player_id, list, completed.get(player_id, {}))
	print("[Quests] Player %d started '%s'" % [player_id, quest_id])


## Host -> everyone: this player's quests now.
@rpc("authority", "call_local", "reliable")
func _set_quests(player_id: int, active_now: Array, completed_now: Dictionary) -> void:
	active[player_id] = active_now
	completed[player_id] = completed_now


# --- Finishing quests (host, at the extraction beam) ---

## Host only, called by fish_heist.gd as a cat extracts, BEFORE its bag is emptied.
## Completes every active quest whose objective is met and returns
## [total bonus cash, Array of finished quest titles].
func complete_on_extract(player_id: int) -> Array:
	var bonus := 0
	var titles: Array = []
	var still_active: Array = []
	var done: Dictionary = completed.get(player_id, {}).duplicate()
	for quest_id in active.get(player_id, []):
		var data: QuestData = catalog[quest_id]
		if progress(player_id, quest_id) >= data.count:
			bonus += data.reward_cash
			titles.append(data.title)
			done[quest_id] = done.get(quest_id, 0) + 1
			print("[Quests] Player %d completed '%s' (+$%d)" % [player_id, quest_id, data.reward_cash])
		else:
			still_active.append(quest_id)  # not done yet: keep it for the next trip up
	if not titles.is_empty():
		_set_quests.rpc(player_id, still_active, done)
	return [bonus, titles]


# --- Joining and leaving ---

## Host -> a computer that just joined (network ID "peer"): everyone's quests.
func send_state_to(peer: int) -> void:
	_receive_state.rpc_id(peer, active, completed)


@rpc("authority", "call_remote", "reliable")
func _receive_state(active_now: Dictionary, completed_now: Dictionary) -> void:
	active = active_now
	completed = completed_now


## Host: a player quit. Their quests go with them.
func player_left(player_id: int) -> void:
	_forget_player.rpc(player_id)


@rpc("authority", "call_local", "reliable")
func _forget_player(player_id: int) -> void:
	active.erase(player_id)
	completed.erase(player_id)
