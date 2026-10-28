class_name LootSpawn
extends Resource
## ONE LINE OF A LOOT TABLE: "put N of this item HERE, and grow it back after S seconds".
## A LootTable (loot_table.gd) is a list of these; the Items node places them for every new city.
## Edit them in the Inspector: open res://loot/city.tres and expand Spawns > a line.

## Where the items go.
enum Where {
	SIDEWALK,           ## random sidewalk spots all over the city
	OUTSIDE_MEOW_MART,  ## a neat row on the sidewalk outside Meow-Mart's door
	FIXED_SPOT,         ## always at "Spot" (the same in every city)
}

## The item card's id (the file name in res://items/, e.g. "fish", "sardine", "golden_koi").
@export var item_id: String = "sardine"
## How many to place.
@export var count: int = 1
## Where they go (see the list above).
@export var where: Where = Where.SIDEWALK
## FIXED_SPOT only: where (metres, the centre crossroads is 0, 0, 0). More than one = a little row.
@export var spot: Vector3 = Vector3.ZERO
## SIDEWALK only: keep at least this far (metres) from Meow-Mart, so you have to travel for it.
## 0 = anywhere. (The golden koi uses 60.)
@export var min_distance_from_meow_mart: float = 0.0
## Seconds before a taken one grows back at its spot. 0 = never (once it's gone, it's gone).
## More players make it faster (Items > Regrow Faster Per Player).
@export var respawn_seconds: float = 20.0
