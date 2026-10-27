class_name NpcPage
extends Resource
## CYPURRPUNK — ONE PAGE of an NPC's conversation: something they say + the answer buttons.
## An NPC (npc.gd) has a list of these under "Pages" in the Inspector.
## The FIRST page (that fits — see "Only If Quest" below) is what they say when you press E.
##
##   Id       a short name other choices use to jump here ("about", "howto", ...)
##   Lines    what the NPC says. Put several to have one picked at random each time.
##   Choices  the answer buttons (NpcChoice). Leave EMPTY to reuse the greeting page's buttons,
##            so "WHO ARE YOU?"-style answer pages don't need the menu copied into them.
##   Only If Quest / Only If State  (optional) this page can only be the GREETING when the
##            player's quest is in that state. When you walk up, the NPC greets you with the
##            first page (top to bottom) whose condition fits. Pages with no quest always fit.
##            States: not_started, active, ready (active AND objective done), done.
##            (Jumping to a page with Go To ignores these.)

## Short name for this page. Choices jump here by typing it into their "Go To".
@export var id: String = "hello"
## What the NPC says. One is picked at random.
@export_multiline var lines: PackedStringArray = ["..."]
## The answer buttons. Empty = use the greeting page's buttons.
@export var choices: Array[NpcChoice] = []

@export_group("Only greet with this page if")
## A quest card's id (e.g. "mittens_fish"). Empty = no condition.
@export var only_if_quest: String = ""
## The state that quest must be in for this page to be the greeting.
@export_enum("not_started", "active", "ready", "done") var only_if_state: String = "not_started"


## True if this page may be the greeting for this player (see Only If Quest above).
func fits(player_id: int) -> bool:
	return only_if_quest.is_empty() or QuestManager.instance.is_in_state(player_id, only_if_quest, only_if_state)
