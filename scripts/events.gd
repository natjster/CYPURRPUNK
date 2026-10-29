extends Node
## CYPURRPUNK — GAME EVENTS: one place where the big moments of a raid are announced.
## Autoload "Events" (Project > Project Settings > Globals > Autoload).
##
## Why: the system where something HAPPENS shouldn't have to know every system that CARES.
## The heist doesn't call the Roomba patrol when the hatch seals; it just announces
## "district sealed", and the patrol (and anything you add later) listens:
##
##     func _ready() -> void:
##         Events.district_sealed.connect(_on_district_sealed)
##
##     func _on_district_sealed() -> void:
##         print("the MAINFRAME loses a chunk")
##
## A connection from a node goes away by itself when that node is freed (e.g. when the game
## reloads back to the start menu), so you never have to disconnect.
##
## WHO HEARS IT: each event says whether it fires on EVERY computer or on the HOST only.
## Game rules (cash, heat, spawning) should only be changed by the host, so a listener that
## changes them checks `multiplayer.is_server()` first, or listens to a host-only event.
##
## The events (add new ones here, with a comment saying who emits them and where):

## EVERY computer: the hatch was just sealed at max heat; the DEEP CLEAN starts (fish_heist.gd).
signal district_sealed()

## EVERY computer: a player climbed down the exit. loot_value = what their loot was worth,
## quest_bonus = extra cash from quests finished just now (fish_heist.gd).
signal player_extracted(player_id: int, loot_value: int, quest_bonus: int)

## EVERY computer: a player hit 0 HP and is DOWNED, waiting for a teammate to revive them.
## cause = who did it, e.g. "A VAC-COP" (cat_health.gd).
signal player_downed(player_id: int, cause: String)

## EVERY computer: a downed player was picked back up by teammate "by" (cat_health.gd).
signal player_revived(player_id: int, by: int)

## EVERY computer: a rival "by" robbed this downed player's loot bag (cat_health.gd).
signal player_robbed(player_id: int, by: int)

## A player is KNOCKED OUT for good (bled out, gave up, nobody could help, or the DEEP CLEAN):
## their loot spills and they go back to the sewers. EVERY computer. cause = e.g. "A VAC-COP"
## (cat_health.gd).
signal player_knocked_out(player_id: int, cause: String)

## EVERY computer: the heat went up or down a level (1..5; 5 = max). (heat_meter.gd)
signal heat_level_changed(level: int)

## HOST only: a player picked up (or bought) an item (item_manager.gd).
signal item_picked_up(player_id: int, item_id: String)

## HOST only: an enemy was destroyed, just before it's removed (enemy.gd). Its position, drops
## and is_boss are still readable.
signal enemy_destroyed(enemy: Enemy)


# --- Testing: --event_log prints every event as it happens ("[Events] ..." lines) ---

func _ready() -> void:
	if not "--event_log" in OS.get_cmdline_user_args():
		return
	for info in (get_script() as Script).get_script_signal_list():  # only the events above
		var event: String = info.name
		# (A signal can only call a function that takes exactly its number of values.)
		match info.args.size():
			0: connect(event, func(): _log(event, []))
			1: connect(event, func(a): _log(event, [a]))
			2: connect(event, func(a, b): _log(event, [a, b]))
			3: connect(event, func(a, b, c): _log(event, [a, b, c]))


func _log(event: String, values: Array) -> void:
	var shown := values.map(func(v): return (v as Node).name if v is Node else v)
	print("[Events] %s %s (%s)" % [event, shown, "host" if multiplayer.is_server() else "client"])
