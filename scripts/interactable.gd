class_name Interactable
extends Node3D
## THE E KEY (interact): one way for a cat to use anything. Street items, NPCs, payphones,
## the stash lockers and the car all work through this, and so will anything new (a MAINFRAME
## terminal, a scrap machine...). The cat doesn't know what any of them are.
##
## HOW IT WORKS: everything usable joins the group "interactables" and answers three questions:
##     func interact_distance(cat: CatPlayer) -> float  # metres away, or -1 = "can't use me now"
##     func interact_prompt(cat: CatPlayer) -> String   # the HUD line after "[E] ", e.g.
##                                                      # "TALK TO DON CATLEONE" ("" = no line)
##     func interact(cat: CatPlayer) -> void            # E was pressed: do it
## and optionally:
##     func interact_priority() -> int                  # higher wins when two are in reach
##                                                      # (items 30, NPCs 20, stash 10, car 0)
## Each frame the HUD shows the prompt of the BEST one in reach (highest priority, then
## nearest); pressing E uses that one (cat_player.gd).
##
## THE EASY WAY (no code for the "where" part): add an Interactable node. Right-click a node >
## Add Child Node > Interactable, set its Prompt and Radius in the Inspector, and connect its
## "used" signal (Node dock > Signals) to whatever should happen. The stash lockers in the hub
## are one of these (hub.gd _build_stash), made in code:
##     var lockers := Interactable.make(self, stash_spot, "OPEN STASH", stash_radius, 10)
##     lockers.used.connect(func(cat): InventoryScreen.for_seat(cat.slot).open(cat))
##
## Multiplayer: all of this runs on the computer of the cat's OWNER (the player who pressed E).
## Anything other players must see, or anything that changes the game (items, cash), has to
## ask the host with an @rpc, like ItemManager.request_pickup does.

## The group every usable thing joins.
const GROUP := "interactables"

## Emitted (on the presser's computer) when a cat uses this.
signal used(cat: CatPlayer)

## The HUD line after "[E] ", e.g. "OPEN STASH". Empty = no line (still usable).
@export var prompt: String = "USE"
## How close (metres) a cat must be.
@export var radius: float = 2.0
## When two usable things are in reach, the higher priority wins (items 30, NPCs 20, car 0).
@export var priority: int = 10


func _ready() -> void:
	add_to_group(GROUP)


## Make one in code: an Interactable under "parent" at local spot "at".
static func make(parent: Node, at: Vector3, prompt_text: String, reach: float = 2.0, prio: int = 10) -> Interactable:
	var spot := Interactable.new()
	spot.name = "Interactable_" + prompt_text.validate_node_name().replace(" ", "_")
	spot.position = at
	spot.prompt = prompt_text
	spot.radius = reach
	spot.priority = prio
	parent.add_child(spot)
	return spot


# --- The three answers (for this node) ---

func interact_distance(cat: CatPlayer) -> float:
	var distance := global_position.distance_to(cat.global_position)
	return distance if distance < radius else -1.0


func interact_prompt(_cat: CatPlayer) -> String:
	return prompt


func interact(cat: CatPlayer) -> void:
	used.emit(cat)


func interact_priority() -> int:
	return priority


# --- For the cat and the HUD: what can this cat use right now? ---

## The best thing in this cat's reach (highest priority, then nearest), or null.
## Nothing while that player's talk box / inventory / pause menu is open, or they're knocked out.
static func best_for(cat: CatPlayer) -> Node:
	if cat == null or not cat.is_controlled or cat.knocked_out or Hud.wants_input(cat.slot):
		return null
	var best: Node = null
	var best_priority := 0
	var best_distance := 0.0
	for node in cat.get_tree().get_nodes_in_group(GROUP):
		if not node.has_method("interact_distance"):
			continue
		var distance: float = node.interact_distance(cat)
		if distance < 0.0:
			continue
		var node_priority: int = node.interact_priority() if node.has_method("interact_priority") else 0
		if best == null or node_priority > best_priority or (node_priority == best_priority and distance < best_distance):
			best = node
			best_priority = node_priority
			best_distance = distance
	return best


## E pressed: use the best thing in reach. Returns true if there was one.
static func try_use(cat: CatPlayer) -> bool:
	var best := best_for(cat)
	if best == null:
		return false
	best.interact(cat)
	return true


## The HUD line for this cat ("" = nothing to show), without the "[E]" part.
static func prompt_for(cat: CatPlayer) -> String:
	var best := best_for(cat)
	return best.interact_prompt(cat) if best != null else ""
