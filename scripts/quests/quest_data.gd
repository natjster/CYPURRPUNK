class_name QuestData
extends Resource
## CYPURRPUNK — a QUEST CARD: everything the game needs to know about one quest.
##
## Every quest is one of these saved as a .tres file in the res://quests/ folder. The game
## loads every card in that folder automatically (quest_manager.gd), so adding a quest =
## adding a card, then giving it out from an NPC (a choice whose Action is "quest:<id>").
## See SETUP_GUIDE.md, "Quests".
##
## How a quest goes:
##   1. An NPC gives it to you (you now have it ACTIVE).
##   2. You do the objective (see Kind below).
##   3. You EXTRACT with the objective done: the quest is complete and Reward Cash is added
##      on top of what your loot is worth. Extract without it done and the quest stays active.
##   4. Repeatable quests can be picked up again from the NPC afterwards.

## Unique name used in code and in NPC actions, e.g. "mittens_fish". No spaces.
@export var id: String = ""
## Name shown on the HUD, e.g. "MITTENS' FISH".
@export var title: String = ""
## One line saying what to do (for future quest screens; not shown on the HUD yet).
@export_multiline var description: String = ""

## The kinds of objective a quest can have (what "Kind" means on the card):
##   CARRY_ITEM       extract with Count of Item in your loot bag
##   DESTROY_ROOMBAS  smash Count VAC-COPs yourself (gun, melee or car), then extract
##   EXTRACT_AT_HEAT  extract while the city's heat is at least Heat Needed
##   DISRESPECT       do Count of: destroy a MEGA VAC-COP, rob a downed rival, or hit a rival
##                    with a melee weapon; then extract
## DESTROY_ROOMBAS and DISRESPECT progress goes back to 0 if you get knocked out.
enum Kind { CARRY_ITEM, DESTROY_ROOMBAS, EXTRACT_AT_HEAT, DISRESPECT }

@export_group("Objective")
## What you have to do (see the list above).
@export var kind: Kind = Kind.CARRY_ITEM
## CARRY_ITEM only: the item id to bring back (an item card's id, e.g. "fish").
@export var item: String = "fish"
## How many: items in the bag, VAC-COPs smashed, or acts of disrespect.
## (EXTRACT_AT_HEAT: leave it at 1.)
@export var count: int = 3
## EXTRACT_AT_HEAT only: the lowest heat (0-100) that counts.
@export var heat_needed: float = 85.0

@export_group("Reward")
## Bonus cash paid at extraction, on top of the loot's own value.
@export var reward_cash: int = 100
## Can you take it again after finishing it?
@export var repeatable: bool = true
