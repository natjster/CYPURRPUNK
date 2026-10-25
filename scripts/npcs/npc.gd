class_name Npc
extends StaticBody3D
## MEOW-CITY 1999 — THE NPC FRAMEWORK: any character you can walk up to and talk to.
## Don Catleone (scenes/npcs/don_catleone.tscn) is built on it, and so is the starter
## scene scenes/npcs/npc_template.tscn — duplicate that to make a new NPC (SETUP_GUIDE §8).
##
## Expected node tree (only the root and CollisionShape3D are required):
##   MyNpc (StaticBody3D)      <- this script
##   ├── CollisionShape3D      <- so cats bump into them instead of walking through
##   ├── Model (Node3D)        <- their meshes; turns to look at the nearest cat (optional)
##   │   └── Tail              <- swishes slowly (optional)
##   └── NameTag (Label3D)     <- floating name; its text is set from Npc Name (optional)
##
## Talking: cat_player.gd calls Npc.try_talk() when E is pressed. The nearest NPC in reach
## opens the talk box (NpcDialog) at its FIRST page. The whole conversation is data in the
## Inspector: Pages (NpcPage) -> Choices (NpcChoice). No code needed for a normal chatty NPC.
##
## Special behaviour: a choice's Action word runs here. "send_up_top" and "return_to_hub"
## are built in. For anything else, either
##   - make a script that starts with  extends Npc  and write  func _on_action(action, cat):
##   - or connect the action_chosen signal from another node (Node tab > Signals).
##
## Multiplayer: NPCs aren't networked. Every computer has its own copy standing in the
## same place, and talking only affects YOUR cat. Actions that must change the shared game
## (give items, spend cash...) should ask the host, the same way items do.

## Fired when a choice with an Action is picked (after the built-in actions run).
signal action_chosen(action: String, cat: CatPlayer)

## Shown above the talk box, on the "[E] TALK TO ..." prompt and on the NameTag.
@export var npc_name: String = "STRAY CAT"
## How close (metres) you must be to talk.
@export var talk_radius: float = 3.0
## The conversation. The first page is the greeting. See npc_page.gd.
@export var pages: Array[NpcPage] = []

@export_group("Idle animation")
## Turn the Model to face the nearest cat.
@export var look_at_players: bool = true
## How far away (metres) a cat can be and still get looked at.
@export var look_range: float = 8.0
## How fast they turn to look (bigger = snappier).
@export var turn_speed: float = 3.0
## How far the Tail swishes (radians). 0 = still.
@export var tail_swish: float = 0.35
## Swishes per second-ish.
@export var tail_speed: float = 1.6

## Every NPC joins this group, so the cat can find who's nearby.
const GROUP := "npcs"

var _model: Node3D
var _tail: Node3D
var _clock: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_model = get_node_or_null("Model")
	_tail = get_node_or_null("Model/Tail")
	var tag := get_node_or_null("NameTag") as Label3D
	if tag != null:
		tag.text = npc_name
	if pages.is_empty():
		push_warning("NPC %s has no Pages: add one in the Inspector so they have something to say." % name)


func _process(delta: float) -> void:
	_clock += delta
	if _tail != null:
		_tail.rotation.z = sin(_clock * tail_speed) * tail_swish
	if look_at_players and _model != null:
		var nearest := _nearest_cat()
		if nearest != null:
			var to_cat := nearest.global_position - global_position
			var target_yaw := atan2(-to_cat.x, -to_cat.z)  # same maths as the player cats (face -Z)
			_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _nearest_cat() -> Node3D:
	var nearest: Node3D = null
	var best := look_range
	for cat in Game.instance.players.get_children():
		var d := global_position.distance_to((cat as Node3D).global_position)
		if (cat as Node3D).visible and d < best:
			nearest = cat
			best = d
	return nearest


# --- Finding who to talk to (used by cat_player.gd and the "[E] TALK" prompt) ---

## The closest NPC this cat is in talking range of, or null.
static func nearest_in_reach(cat: CatPlayer) -> Npc:
	var best: Npc = null
	for npc in cat.get_tree().get_nodes_in_group(GROUP):
		if npc is Npc and npc.in_reach(cat) and (best == null or
				npc.global_position.distance_to(cat.global_position) < best.global_position.distance_to(cat.global_position)):
			best = npc
	return best


## E pressed: talk to the nearest NPC in reach. Returns true if a conversation started.
static func try_talk(cat: CatPlayer) -> bool:
	var npc := nearest_in_reach(cat)
	if npc == null:
		return false
	npc.talk(cat)
	return true


func in_reach(cat: CatPlayer) -> bool:
	return global_position.distance_to(cat.global_position) < talk_radius


# --- The conversation ---

## Start talking: show the first page.
func talk(cat: CatPlayer) -> void:
	if not pages.is_empty():
		show_page(cat, pages[0].id)


## Open the talk box on the page with this id. Scripts can call this to jump around too.
func show_page(cat: CatPlayer, page_id: String) -> void:
	var page := _find_page(page_id)
	if page == null:
		push_warning("NPC %s has no page with Id '%s'." % [npc_name, page_id])
		NpcDialog.instance.close()
		return
	var line := "..." if page.lines.is_empty() else page.lines[randi() % page.lines.size()]
	var choices := page.choices if not page.choices.is_empty() else pages[0].choices
	var buttons := []
	for choice in choices:
		buttons.append([choice.text, _choose.bind(cat, choice)])
	if buttons.is_empty():
		buttons.append(["BYE", NpcDialog.instance.close])  # never leave the player stuck
	NpcDialog.instance.open(npc_name, line, buttons)


func _find_page(page_id: String) -> NpcPage:
	for page in pages:
		if page.id == page_id:
			return page
	return null


## A button was clicked: message, then action, then the next page (or close).
func _choose(cat: CatPlayer, choice: NpcChoice) -> void:
	if choice.go_to.is_empty():
		NpcDialog.instance.close()  # close first, so an action can open something else
	if not choice.message.is_empty():
		Game.instance.show_message("%s: %s" % [npc_name, choice.message])
	if not choice.action.is_empty():
		_run_action(choice.action, cat)
	if not choice.go_to.is_empty():
		show_page(cat, choice.go_to)


func _run_action(action: String, cat: CatPlayer) -> void:
	match action:
		"send_up_top":
			UndergroundHub.instance.deploy(cat)
		"return_to_hub":
			UndergroundHub.instance.return_cat(cat)
		_:
			_on_action(action, cat)
	action_chosen.emit(action, cat)


## Override this in a script that "extends Npc" to give an NPC its own actions:
##   func _on_action(action: String, cat: CatPlayer) -> void:
##       if action == "pet_me":
##           Game.instance.show_message("Purrrr.")
func _on_action(action: String, _cat: CatPlayer) -> void:
	if action_chosen.get_connections().is_empty():
		push_warning("NPC %s: nobody handles the action '%s'." % [npc_name, action])
