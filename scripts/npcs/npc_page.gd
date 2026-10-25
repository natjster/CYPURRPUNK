class_name NpcPage
extends Resource
## MEOW-CITY 1999 — ONE PAGE of an NPC's conversation: something they say + the answer buttons.
## An NPC (npc.gd) has a list of these under "Pages" in the Inspector.
## The FIRST page is what they say when you walk up and press E.
##
##   Id       a short name other choices use to jump here ("about", "howto", ...)
##   Lines    what the NPC says. Put several to have one picked at random each time.
##   Choices  the answer buttons (NpcChoice). Leave EMPTY to reuse the first page's buttons,
##            so "WHO ARE YOU?"-style answer pages don't need the menu copied into them.

## Short name for this page. Choices jump here by typing it into their "Go To".
@export var id: String = "hello"
## What the NPC says. One is picked at random.
@export_multiline var lines: PackedStringArray = ["..."]
## The answer buttons. Empty = use the first page's buttons.
@export var choices: Array[NpcChoice] = []
