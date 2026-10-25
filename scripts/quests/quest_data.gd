class_name QuestData
extends Resource
## MEOW-CITY 1999 — a QUEST CARD: everything the game needs to know about one quest.
##
## Every quest is one of these saved as a .tres file in the res://quests/ folder. The game
## loads every card in that folder automatically (quest_manager.gd), so adding a quest =
## adding a card, then giving it out from an NPC (a choice whose Action is "quest:<id>").
## See SETUP_GUIDE.md, "Quests".
##
## How a quest goes:
##   1. An NPC gives it to you (you now have it ACTIVE; the HUD tracks it top-left).
##   2. You do the objective (for now: carry Count of Item in your loot bag).
##   3. You EXTRACT with the objective done: the quest is complete and Reward Cash is added
##      on top of what your loot is worth. Extract without it done and the quest stays active.
##   4. Repeatable quests can be picked up again from the NPC afterwards.

## Unique name used in code and in NPC actions, e.g. "mittens_fish". No spaces.
@export var id: String = ""
## Name shown on the HUD, e.g. "MITTENS' FISH".
@export var title: String = ""
## One line saying what to do (for future quest screens; not shown on the HUD yet).
@export_multiline var description: String = ""

@export_group("Objective")
## The item id to bring back (an item card's id, e.g. "fish").
@export var item: String = "fish"
## How many of it must be in your loot bag when you extract.
@export var count: int = 3

@export_group("Reward")
## Bonus cash paid at extraction, on top of the loot's own value.
@export var reward_cash: int = 100
## Can you take it again after finishing it?
@export var repeatable: bool = true
