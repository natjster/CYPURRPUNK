extends CanvasLayer
## MEOW-CITY 1999 — keeps the menus readable on widescreen / ultrawide monitors.
## Attach to PS1Overlay in scenes/main.tscn.
##
## The game is always 240 pixels tall. On a wide monitor (SETTINGS > DISPLAY > ASPECT = WIDE)
## it gets WIDER instead (e.g. 573x240 on a 21:9 ultrawide), so the 3D city fills the screen.
## The menus were laid out for a 320x240 screen, so this script keeps every menu in a
## 320-wide column in the middle, while their dark backgrounds (ColorRects that cover the
## whole menu) still stretch edge to edge.
##
## Children listed in full_width_children are left alone: the HUD (its labels are anchored
## to the screen edges / centre in main.tscn) and the CRT + dither effect, which must cover
## the whole screen.

## The width the menus were designed for.
@export var design_width: float = 320.0
## Direct children that should span the full screen width instead of the middle column.
@export var full_width_children: Array[String] = ["HUD", "ColorDepthDither"]


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_columns)
	# Wait one frame so menus that build their nodes in code (inventory, cat creator) exist.
	_fit_columns.call_deferred()


func _fit_columns() -> void:
	var width := get_viewport().get_visible_rect().size.x
	# Extra space on each side of the 320-wide column (0 on a 4:3 screen).
	var margin := maxf(0.0, (width - design_width) / 2.0)
	for child in get_children():
		if not child is Control or child.name in full_width_children:
			continue
		var menu: Control = child
		menu.offset_left = margin
		menu.offset_right = -margin
		# Full-screen dark backgrounds reach back out to the screen edges.
		for part in menu.get_children():
			if part is ColorRect and part.anchor_left == 0.0 and part.anchor_right == 1.0:
				part.offset_left = -margin
				part.offset_right = margin
