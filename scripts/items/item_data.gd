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
