class_name ItemData
extends Resource
## An ITEM CARD: everything the game needs to know about one kind of item.
##
## Every item is one of these saved as a .tres file in the res://items/ folder. The game
## loads every card in that folder automatically, so adding an item = adding a card
## (plus its model scene). See SETUP_GUIDE.md, "Adding a new item or weapon".
##
## Two kinds of item:
##   LOOT  goes in your loot bag (fish). Cash value is paid at the drop-off.
##         Shown stacked on your cat (one in the mouth, the rest on its head).
##   HELD  goes in your paws (weapons, tools, catnip). Uses 1 or 2 paws.
##         Left Mouse uses the item in your right paw, Right Mouse the one in your left.
##         A 2-paw item (the tommy gun) takes both and uses Left Mouse.

enum Kind { LOOT, HELD }

## Unique name used in code and in other settings, e.g. "tommy_gun". No spaces.
@export var id: String = ""
## Name shown to players, e.g. "PURR-TOMMY".
@export var display_name: String = ""
@export var kind: Kind = Kind.HELD
## One line shown when you hover the item in the inventory screen.
@export_multiline var description: String = ""

@export_group("Held items")
## 1 = one paw (you can hold two: dual wield). 2 = both paws.
@export_range(1, 2) var hands: int = 1
## Where it sits, relative to the cat (-Z is the cat's nose). This is the RIGHT paw;
## the left paw uses the same spot mirrored.
@export var hold_offset: Vector3 = Vector3(0.28, 0.45, -0.2)
@export var hold_scale: float = 1.0
## Over-the-shoulder camera while holding it (nice for aiming weapons).
@export var shoulder_camera: bool = false

@export_group("Loot")
## Cash paid for each one delivered to the drop-off.
@export var cash_value: int = 0
## Room it takes in the loot bag.
@export var bag_space: int = 1
## HEAVY loot: your cat's speed is multiplied by this while it's in your bag
## (1.0 = no change, 0.8 = 20% slower). With several heavy things, the slowest one counts.
@export_range(0.3, 1.0, 0.05) var carry_speed: float = 1.0
## NOISY loot: VAC-COPs spot you from this many times further away while you carry it
## (1.0 = normal, 1.6 = they notice you from 60% further). The loudest item counts.
@export_range(1.0, 3.0, 0.1) var noise: float = 1.0
## HEAT added the moment someone picks it up (scripts/heat_meter.gd). 0 = none.
## Big prizes should make the whole city angry.
@export var heat_on_pickup: float = 0.0
## Message shown to EVERY player when someone picks it up ("" = nobody is told).
## %s is replaced with the cat's name, e.g. "%s GRABBED THE GOLDEN KOI!"
@export var pickup_announcement: String = ""

@export_group("Shop")
## Price at the Black Markitten, the shop down in the sewers (scenes/npcs/comrade_whiskers.tscn).
## 0 = not for sale. The shopkeeper only sells items in his Stock list that have a price.
@export var price: int = 0

@export_group("In the world")
## The item's model. For held items with behaviour, the scene's root has a script that
## extends HeldItem (or Weapon). The same scene is shown lying on the street.
@export var scene: PackedScene
## Picked up just by walking into it (true), or by pressing E (false).
@export var auto_pickup: bool = false
## Size when lying on the street.
@export var world_scale: float = 1.0
## Colour of the little light under it on the street. Alpha 0 = no light.
@export var glow_color: Color = Color(1, 1, 1, 0)
