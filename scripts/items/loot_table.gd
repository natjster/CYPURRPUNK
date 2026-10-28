class_name LootTable
extends Resource
## A LOOT TABLE: everything that lies around a district when it's built. A list of LootSpawn
## lines (loot_spawn.gd), placed top to bottom by the Items node (item_manager.gd).
##
## The city's table is res://loot/city.tres (Items > Loot Table in main.tscn points at it).
## No code needed to change the loot:
##   - more / fewer of something: open city.tres, expand Spawns, change a line's Count.
##   - a new kind of loot: make its item card (SETUP_GUIDE section 9), then in city.tres click
##     Spawns > Add Element > New LootSpawn, and fill in Item Id, Count, Where...
##   - a different district type (later): duplicate city.tres and point Loot Table at the copy.

## The lines, placed top to bottom.
@export var spawns: Array[LootSpawn] = []
