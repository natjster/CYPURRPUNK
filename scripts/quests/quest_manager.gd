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
##   - CARRY_ITEM progress isn't sent at all: it's counted from your loot bag, which every
##     computer already knows about (ItemManager.inventories).
##   - Kills / disrespect are counted by the host from Events (tallies) and sent with _set_quests.
##     Getting knocked out wipes your tallies.
##   - At the exit manhole, fish_heist.gd asks the host's QuestManager for the bonus
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
## Player ID -> {quest id: VAC-COPs smashed / disrespect done so far}. Same deal.
var tallies := {}


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	add_to_group(GameSystems.GROUP)  # late joiners / quitting players / new districts (game_systems.gd)
	for file in DirAccess.get_files_at(QUESTS_FOLDER):
		file = file.trim_suffix(".remap")  # exported games rename resources
		if file.ends_with(".tres"):
			var data := load(QUESTS_FOLDER + file) as QuestData
			if data != null and not data.id.is_empty():
				catalog[data.id] = data
	print("[Quests] Loaded %d quest cards: %s" % [catalog.size(), ", ".join(catalog.keys())])
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	Events.player_robbed.connect(_on_player_robbed)
	Events.player_slapped.connect(_on_player_slapped)
	Events.player_knocked_out.connect(_on_player_knocked_out)


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


## How far along this player is. Compare it with the card's Count.
func progress(player_id: int, quest_id: String) -> int:
	var data: QuestData = catalog[quest_id]
	match data.kind:
		QuestData.Kind.CARRY_ITEM:
			return ItemManager.instance.get_inventory(player_id).bag.count(data.item)
		QuestData.Kind.EXTRACT_AT_HEAT:
			return 1 if HeatMeter.instance.heat >= data.heat_needed else 0
		_:
			return tallies.get(player_id, {}).get(quest_id, 0)


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
	var tally: Dictionary = tallies.get(player_id, {}).duplicate()
	tally.erase(quest_id)  # a fresh start
	_set_quests.rpc(player_id, list, completed.get(player_id, {}), tally)
	print("[Quests] Player %d started '%s'" % [player_id, quest_id])


## Host -> everyone: this player's quests now.
@rpc("authority", "call_local", "reliable")
func _set_quests(player_id: int, active_now: Array, completed_now: Dictionary, tally_now: Dictionary) -> void:
	active[player_id] = active_now
	completed[player_id] = completed_now
	tallies[player_id] = tally_now


# --- Counting kills and disrespect (host, from Events: scripts/events.gd) ---

## Host: +1 on every active quest of this kind this player has.
func _add_tally(player_id: int, kind: QuestData.Kind) -> void:
	var tally: Dictionary = tallies.get(player_id, {}).duplicate()
	var changed := false
	for quest_id in active.get(player_id, []):
		if (catalog[quest_id] as QuestData).kind == kind:
			tally[quest_id] = tally.get(quest_id, 0) + 1
			changed = true
			print("[Quests] Player %d: '%s' now %d" % [player_id, quest_id, tally[quest_id]])
	if changed:
		_set_quests.rpc(player_id, active[player_id], completed.get(player_id, {}), tally)


func _on_enemy_destroyed(enemy: Enemy) -> void:
	if enemy.killed_by == 0:
		return  # nobody in particular
	_add_tally(enemy.killed_by, QuestData.Kind.DESTROY_ROOMBAS)
	if enemy.is_boss:
		_add_tally(enemy.killed_by, QuestData.Kind.DISRESPECT)


func _on_player_robbed(_player_id: int, by: int) -> void:
	if multiplayer.is_server():  # (this event fires on every computer)
		_add_tally(by, QuestData.Kind.DISRESPECT)


func _on_player_slapped(_player_id: int, by: int) -> void:
	_add_tally(by, QuestData.Kind.DISRESPECT)


## Knocked out: everything you hadn't extracted yet is gone, and that includes kill counts.
func _on_player_knocked_out(player_id: int, _cause: String) -> void:
	if multiplayer.is_server() and not tallies.get(player_id, {}).is_empty():
		print("[Quests] Player %d was knocked out: kill counts reset" % player_id)
		_set_quests.rpc(player_id, active.get(player_id, []), completed.get(player_id, {}), {})


# --- Finishing quests (host, at the exit manhole) ---

## Host only, called by fish_heist.gd as a cat extracts, BEFORE its bag is emptied.
## Completes every active quest whose objective is met and returns
## [total bonus cash, Array of finished quest titles].
func complete_on_extract(player_id: int) -> Array:
	var bonus := 0
	var titles: Array = []
	var still_active: Array = []
	var done: Dictionary = completed.get(player_id, {}).duplicate()
	var tally: Dictionary = tallies.get(player_id, {}).duplicate()
	for quest_id in active.get(player_id, []):
		var data: QuestData = catalog[quest_id]
		if progress(player_id, quest_id) >= data.count:
			bonus += data.reward_cash
			titles.append(data.title)
			done[quest_id] = done.get(quest_id, 0) + 1
			tally.erase(quest_id)
			print("[Quests] Player %d completed '%s' (+$%d)" % [player_id, quest_id, data.reward_cash])
		else:
			still_active.append(quest_id)  # not done yet: keep it for the next trip up
	if not titles.is_empty():
		_set_quests.rpc(player_id, still_active, done, tally)
	return [bonus, titles]


# --- Joining and leaving ---

## Host -> a computer that just joined (network ID "peer"): everyone's quests.
func send_state_to(peer: int) -> void:
	_receive_state.rpc_id(peer, active, completed, tallies)


@rpc("authority", "call_remote", "reliable")
func _receive_state(active_now: Dictionary, completed_now: Dictionary, tallies_now: Dictionary) -> void:
	active = active_now
	completed = completed_now
	tallies = tallies_now


## Host: a player quit. Their quests go with them.
func player_left(player_id: int, _last_position: Vector3) -> void:
	_forget_player.rpc(player_id)


@rpc("authority", "call_local", "reliable")
func _forget_player(player_id: int) -> void:
	active.erase(player_id)
	completed.erase(player_id)
	tallies.erase(player_id)
