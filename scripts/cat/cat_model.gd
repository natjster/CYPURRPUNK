extends Node3D
## CYPURRPUNK — THE CAT MODEL: every cat in the game (players, the MY CAT preview and all the
## sewer NPCs) is scenes/cat_model.tscn, which is the Blockbench model models/cat.glb with this
## script on top.
##
## The model's parts are named the way CatLook (scripts/cat/cat_look.gd) expects:
##   CatModel (this node)
##   ├── Body, LegL, LegR, Head, EarL, EarR, Tail   <- painted the FUR colour
##   ├── Belly, Muzzle                              <- painted the MARKINGS colour
##   ├── EyeL, EyeR                                 <- painted the EYES colour (they glow a bit)
##   └── Nose                                       <- painted the NOSE colour
## LegL / LegR turn at the hip and Tail at its root (cat_player.gd and npc.gd animate them).
##
## The colours below are this cat's OWN colours. Player cats are repainted straight away with
## the player's look (cat_player.gd), so these only matter for NPCs: an NPC scene sets them on
## its "Model" node (click Model in the NPC's scene > Inspector > Cat Colours).
##
## To change the SHAPE: open models/blockbench/cat.bbmodel in Blockbench, edit, Ctrl+S, and ask
## Claude to re-export it (SETUP_GUIDE §11 / §20).

@export_group("Cat Colours")
## Fur (body, head, ears, legs, tail).
@export var fur_color: Color = Color(0.95, 0.55, 0.2)
## Markings (tummy patch and the snout).
@export var markings_color: Color = Color(1, 0.93, 0.82)
## Eyes. Bright colours glow a little; black eyes don't.
@export var eyes_color: Color = Color(0.04, 0.03, 0.06)
## The little triangle nose.
@export var nose_color: Color = Color(1, 0.45, 0.6)


func _ready() -> void:
	CatLook.apply(self, own_look())


## This model's own colours as a CatLook look (see cat_look.gd).
func own_look() -> Dictionary:
	return {"fur": fur_color, "markings": markings_color, "eyes": eyes_color, "nose": nose_color}
