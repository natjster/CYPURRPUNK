extends CanvasLayer
## CYPURRPUNK — the menus layer (start menu, pause, settings, MY CAT).
## Attach to PS1Overlay in scenes/main.tscn.
##
## SHARP MENUS: you edit the menus here in main.tscn as always, laid out for a 320x240 screen,
## but when the game starts scripts/ui/game_screen.gd lifts this whole node out of the pixel
## game picture into its own layer on top ("MenuView"), drawn at your monitor's REAL
## resolution. Same layout, same sizes, but crisp text and edges, and no CRT over them (like
## the HUD). The CRT + dither effect (ColorDepthDither) stays behind in the game picture, in a
## CanvasLayer called "CRT", so the 3D city still gets it.
##
## The game is always 240 pixels tall. On a wide monitor (SETTINGS > DISPLAY > ASPECT = WIDE)
## it gets WIDER instead (e.g. 573x240 on a 21:9 ultrawide), so the 3D city fills the screen.
## The menus were laid out for a 320x240 screen, so this script keeps every menu in a
## 320-wide column in the middle, while their dark backgrounds (ColorRects that cover the
## whole menu) still stretch edge to edge.
##
## Children listed in full_width_children are left alone (the CRT + dither effect, while it's
## still in here before the game screen moves it out).

## The width the menus were designed for.
@export var design_width: float = 320.0
## Direct children that should span the full screen width instead of the middle column.
@export var full_width_children: Array[String] = ["ColorDepthDither"]


# Listen to whichever screen we're on right now (we get moved to the sharp menu layer).
func _enter_tree() -> void:
	if not get_viewport().size_changed.is_connected(fit_columns):
		get_viewport().size_changed.connect(fit_columns)
	# Wait one frame so menus that build their nodes in code (cat creator) exist.
	fit_columns.call_deferred()


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(fit_columns):
		get_viewport().size_changed.disconnect(fit_columns)


## Put every menu in the middle 320-wide column (game_screen.gd also calls this after resizing).
func fit_columns() -> void:
	if not is_inside_tree():
		return
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


## Is any menu showing right now? (If not, the sharp menu layer isn't drawn at all.)
func any_menu_visible() -> bool:
	for child in get_children():
		if child is CanvasItem and child.visible and not child.name in full_width_children:
			return true
	return false
