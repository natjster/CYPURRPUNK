class_name GameSystems
## THE GAME SYSTEMS FRAMEWORK: one list of every host-run system (cash, health, quests, heat,
## items, the car, the VAC-COP patrol...), so game.gd never has to name them one by one.
##
## How a system joins: in its _ready(), call
##     add_to_group(GameSystems.GROUP)
## then write any of these functions it needs (all optional - leave out the ones you don't):
##
##   func start_district() -> void
##       HOST ONLY. A new game just started, or the crew moved to a NEW DISTRICT (new city seed).
##       Called after the city is built and the host's cat exists. Reset your state here
##       (e.g. heat back to 0, a fresh Roomba patrol, the car back at its parking spot).
##
##   func send_state_to(peer: int) -> void
##       HOST ONLY. A computer just joined (network ID "peer"; it has already built the city).
##       Send it everything it needs to catch up, e.g. _receive_state.rpc_id(peer, my_dict).
##
##   func player_left(player_id: int, last_position: Vector3) -> void
##       HOST ONLY. A player quit (their computer left, or a split-screen player dropped out).
##       Forget them; last_position = where their cat was (to drop their stuff there).
##       Their cat still exists while this runs; it is deleted right after.
##
## Systems are called in the order they appear in the scene tree (main.tscn, top to bottom),
## so a system that others depend on (Items) should sit above them.
##
## Example - a new "Scrap" system: add a Node under Main, give it a script that does
## add_to_group(GameSystems.GROUP) in _ready and has send_state_to / player_left. Done:
## late joiners and quitting players are handled, no edits to game.gd.

const GROUP := "game_systems"


## Host: call "method" with "args" on every system that has it (see the list above).
static func call_all(tree: SceneTree, method: String, args: Array = []) -> void:
	for system in tree.get_nodes_in_group(GROUP):
		if system.has_method(method):
			system.callv(method, args)
