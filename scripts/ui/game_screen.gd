class_name GameScreen
extends Control
## MEOW-CITY 1999 — the very top scene (scenes/game_screen.tscn, the one Godot starts).
## It puts two pictures on your monitor:
##
##   1. The GAME: the whole of scenes/main.tscn (the 3D city, the pixel menus, the CRT + dither
##      look) is drawn inside GameView/GameViewport at PS1 size, 240 pixels tall, then blown up
##      to fill the window with sharp, blocky pixels.
##   2. The HUD (scenes/ui/hud.tscn, scripts/ui/hud.gd): cash, HP, prompts, crosshair... drawn
##      ON TOP at your monitor's REAL resolution, so its text stays crisp instead of being
##      squashed into 240 pixel rows.
##
## Node tree:
##   GameScreen (this script)
##   ├── HUD                 <- the sharp overlay (a CanvasLayer, always drawn on top)
##   ├── Bars                <- black behind everything (the border you see in 4:3 / SHARP mode)
##   └── GameView            <- shows the game picture, blown up
##       └── GameViewport    <- the 320x240-ish "PS1 screen" the game is drawn into
##           └── Main        <- scenes/main.tscn (the actual game)
##
## The size settings (SETTINGS > DISPLAY): see pixel_perfect and widescreen in scripts/settings.gd.
## This script also passes your mouse and keyboard on to the game inside GameViewport.

## The one game screen (GameScreen.instance).
static var instance: GameScreen

## The game picture is always this many pixels tall (the PS1 look).
@export var game_height: int = 240
## ...and at least this many pixels wide (4:3). With ASPECT = WIDE it grows wider to fill the window.
@export var design_width: int = 320

@onready var hud: Hud = $HUD
@onready var game_view: TextureRect = $GameView
@onready var game_viewport: SubViewport = $GameView/GameViewport


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	game_view.texture = game_viewport.get_texture()
	get_viewport().size_changed.connect(_fit)
	Settings.changed.connect(_fit)
	_fit()


## Works out how big the game picture is and where it sits, whenever the window changes size
## or the display settings change.
func _fit() -> void:
	var window := Vector2(get_window().size)  # real screen pixels
	if window.x < 1.0 or window.y < 1.0:
		return  # minimised
	# This scene is laid out in "HUD units" (Project Settings > Display > Window: 720 tall),
	# which Godot scales to the real window. units_per_pixel turns real pixels into those units.
	var units_per_pixel := get_viewport_rect().size.y / window.y

	# How many screen pixels one game pixel becomes.
	var zoom := minf(window.x / design_width, window.y / game_height)
	if Settings.pixel_perfect:
		zoom = maxf(1.0, floorf(zoom))  # SHARP: whole numbers only, every game pixel the same size
	# WIDE: the game gets wider to fill the window; 4:3: it stays 320 wide with black side bars.
	var width := design_width
	if Settings.widescreen:
		width = maxi(design_width, floori(window.x / zoom))
	if game_viewport.size != Vector2i(width, game_height):
		game_viewport.size = Vector2i(width, game_height)

	# Centre the blown-up picture in the window (on whole pixels, so the blocks stay even).
	var shown := Vector2(width, game_height) * zoom
	var corner := ((window - shown) / 2.0).floor()
	game_view.position = corner * units_per_pixel
	game_view.size = shown * units_per_pixel
	# The HUD lines up with the game picture (not the black bars around it).
	hud.fit_to(Rect2(game_view.position, game_view.size))


## Your mouse and keys arrive here first. Pass them on to the game inside GameViewport,
## with mouse positions turned into game pixels (so menus and mouse-look work as before).
## (Except while a HUD window - the talk box or inventory - is open: then they stay up here
## for the HUD's own buttons.)
func _input(event: InputEvent) -> void:
	if Hud.wants_input():
		return
	var scale_to_game := Vector2(game_viewport.size) / game_view.size
	var to_game := Transform2D(Vector2(scale_to_game.x, 0), Vector2(0, scale_to_game.y),
		-game_view.position * scale_to_game)
	game_viewport.push_input(event.xformed_by(to_game), true)
	get_viewport().set_input_as_handled()  # the HUD doesn't need them right now
