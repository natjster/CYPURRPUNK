class_name CatPalette
extends Resource
## CYPURRPUNK — the COLOURS players can pick in the MY CAT screen.
## There's one: res://cat_parts/palette.tres. Double-click it and edit the lists in the
## Inspector (click a colour to change it, "+ Add Element" for a new one). No code needed.
## The first colour of each list is the default.

## Main coat: body, head, ears, legs, tail.
@export var fur_colors: Array[Color] = []
## Belly and muzzle.
@export var marking_colors: Array[Color] = []
## Eyes. They glow a little, so bright colours look great in the dark city.
@export var eye_colors: Array[Color] = []
## Nose.
@export var nose_colors: Array[Color] = []


## The list for one colour key of a look ("fur", "markings", "eyes" or "nose").
func colors_for(key: String) -> Array[Color]:
	match key:
		"fur": return fur_colors
		"markings": return marking_colors
		"eyes": return eye_colors
		"nose": return nose_colors
	return []
