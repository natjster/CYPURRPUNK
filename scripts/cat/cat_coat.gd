class_name CatCoat
extends Resource
## CYPURRPUNK — one COAT PATTERN a cat can have (MY CAT > COAT): tabby, tiger, calico, ...
## Same cat model, same colours: a coat only changes the pattern painted over the FUR colour.
##
## Every coat card lives in res://cat_coats/ (one .tres each). To add one: in the FileSystem
## dock right-click res://cat_coats/ > Create New > Resource... > CatCoat, fill in the boxes
## below in the Inspector, save. The MY CAT screen picks it up, no code needed.
## The pictures come from tools/make_cat_coats.py (or draw your own, see the help on each box).

## Saved in the player's cat (never rename it once players use it), e.g. "calico".
@export var id: String = ""
## Shown in the MY CAT screen (short: about 8 letters fit).
@export var display_name: String = ""
## Menu order (lowest first). The lowest one is the default for cats saved before coats existed.
@export var order: int = 0
## Pattern on the body, head, ears and cheeks (32x32 grey picture: light grey = the fur
## colour, darker = stripes/spots; see-through pixels = the MARKINGS colour). Empty = plain fur.
@export var body_texture: Texture2D
## Pattern on the legs and tail (16x16, same rules). Empty = plain fur.
@export var limb_texture: Texture2D
## How many times the limb picture repeats along a leg (x = round it, y = along it).
@export var limb_uv_scale: Vector2 = Vector2(1, 1.5)
