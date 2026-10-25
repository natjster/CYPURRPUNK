class_name NpcChoice
extends Resource
## MEOW-CITY 1999 — ONE ANSWER BUTTON in an NPC's talk box (e.g. "> WHO ARE YOU?").
## Lives inside an NpcPage's Choices list. Everything is set in the Inspector.
##
## What happens when the player clicks it, in this order:
##   1. Message  (if filled in) pops up on the HUD as "NPC NAME: message".
##   2. Action   (if filled in) runs — see the list below.
##   3. Go To    (if filled in) jumps to the page with that Id. Left empty = the talk box closes.
##
## Built-in actions (type the word into Action):
##   send_up_top   send the cat from the hub up to the city (what Don Catleone does)
##   return_to_hub send the cat back down to the hub
##   quest:<id>    give the player the quest with that id, e.g. quest:mittens_fish
##                 (quest cards are .tres files in res://quests/)
## Any other word is passed to the NPC's own script (Npc._on_action) and its
## "action_chosen" signal, so a special NPC can do special things. See npc.gd.

## The button text. The talk box adds "> " in front.
@export var text: String = "NEVER MIND"
## Shown on the HUD when picked (leave empty for nothing).
@export_multiline var message: String = ""
## What this choice does (see the list above). Empty = nothing special.
@export var action: String = ""
## Id of the page to show next. Empty = close the talk box.
@export var go_to: String = ""
