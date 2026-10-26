class_name Hud
extends CanvasLayer
## MEOW-CITY 1999 — the HUD framework: everything on screen during a game that isn't the world
## or a menu (cash, HP, loot, the extraction arrow, prompts, crosshair, messages).
##
## It is drawn ON TOP of the game at your monitor's real resolution (see scripts/ui/game_screen.gd),
## so its text is sharp, while the game underneath keeps its chunky 240-pixel PS1 look.
## The layout is a normal scene: open scenes/ui/hud.tscn and move / restyle the labels there.
## Positions are in "HUD units": the screen is always 720 units tall (wider on wide monitors),
## whatever your real resolution, so things stay the same size relative to the screen.
##
## Node tree (scenes/ui/hud.tscn):
##   HUD (this script)
##   └── Frame            <- exactly covers the game picture (resized by GameScreen)
##       ├── Names        <- names over cats' / NPCs' heads (scripts/ui/hud_name_tags.gd)
##       ├── Top          <- stays up while you talk / shop: Cash, Carrying, Health, DropOff, Scoreboard
##       ├── Middle       <- hidden while a window is open: Popup, Crosshair, Message, Prompt, Held
##       ├── Inventory    <- the Tab screen (scripts/ui/inventory_ui.gd)    } "windows": while one is
##       └── NpcDialog    <- the talk box (scripts/ui/npc_dialog.gd)        } open, it gets the mouse
##
## HOW OTHER SCRIPTS USE IT (every function is "static": call it on the class, from anywhere):
##   Hud.set_text("Cash", "$120")            change a label's words (by node name)
##   Hud.show_element("Crosshair", true)      show / hide one piece
##   Hud.set_color("Health", Color.WHITE)     change a label's text colour
##   Hud.show_message("DON: Go get 'em.", 4)  the line of text in the middle, for N seconds
##   Hud.popup("EXTRACTED +$80", 2.5)         the big text that fades out (e.g. extraction)
##   Hud.set_in_game(true)                    the whole HUD on (in a game) / off (start menu)
##   Hud.element("Cash")                      the node itself, for anything else
##
## ADDING A NEW HUD PIECE: open scenes/ui/hud.tscn, right-click Top (or Middle) > Add Child Node >
## Label, give it a unique name (e.g. "Ammo"), pick an anchor in the toolbar (Layout > Anchors
## Preset, e.g. Top Right) so it sticks to that corner on every screen shape, then from your
## script call Hud.set_text("Ammo", "...").
##
## The whole HUD hides itself while a full-screen menu (pause, settings, MY CAT) is open.
## While a HUD window (talk box, inventory) is open, the mouse and keys go to the HUD instead of
## the game (scripts/ui/game_screen.gd asks Hud.wants_input()).

## The one HUD (Hud.instance).
static var instance: Hud

## How long the big popup takes to fade away at the end (seconds).
@export var popup_fade_seconds: float = 1.0

## True while we're in a game (Hud.set_in_game).
var in_game: bool = false

var _message_time: float = 0.0
var _popup_time: float = 0.0

@onready var frame: Control = $Frame
@onready var middle: Control = $Frame/Middle


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	frame.hide()
	element("Message").hide()
	element("Popup").hide()


# --- The functions other scripts call ---

## The HUD piece with this node name (anywhere under Frame), or null if there isn't one.
static func element(element_name: String) -> Control:
	if instance == null:
		return null
	return instance.get_node("Frame").find_child(element_name, true, false) as Control


## Change the words on a HUD label.
static func set_text(element_name: String, text: String) -> void:
	var label := element(element_name) as Label
	if label != null:
		label.text = text


## Show or hide one HUD piece.
static func show_element(element_name: String, shown: bool) -> void:
	var piece := element(element_name)
	if piece != null:
		piece.visible = shown


## Change a label's text colour (e.g. flash the HP line white when you're hurt).
static func set_color(element_name: String, color: Color) -> void:
	var label := element(element_name) as Label
	if label != null:
		label.add_theme_color_override("font_color", color)


## A line of text in the middle of the screen for a few seconds (e.g. what Don says).
static func show_message(text: String, seconds: float = 4.0) -> void:
	if instance == null:
		return
	set_text("Message", text)
	show_element("Message", true)
	instance._message_time = seconds


## The big text in the middle that fades out (e.g. "EXTRACTED +$80").
static func popup(text: String, seconds: float = 2.5) -> void:
	if instance == null:
		return
	set_text("Popup", text)
	show_element("Popup", true)
	instance._popup_time = seconds


## True while a HUD window (talk box or inventory) is open: it gets the mouse and keys, not the game.
static func wants_input() -> bool:
	return NpcDialog.is_open or (InventoryScreen.instance != null and InventoryScreen.instance.visible)


## True while a full-screen game menu (pause, settings, MY CAT) is open; the HUD hides under it.
static func menu_open() -> bool:
	var game := Game.instance
	if game == null or not is_instance_valid(game):
		return true
	return PauseMenu.is_open or game.settings_menu.visible or game.cat_creator.visible


## The whole HUD on (in a game) or off (start menu).
static func set_in_game(on: bool) -> void:
	if instance != null:
		instance.in_game = on


## GameScreen calls this so the HUD covers exactly the game picture (not the black bars).
func fit_to(rect: Rect2) -> void:
	frame.position = rect.position
	frame.size = rect.size


# --- Every frame: timers, and hiding behind menus ---

func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		show_element("Message", _message_time > 0.0)
	if _popup_time > 0.0:
		_popup_time -= delta
		var popup_label := element("Popup")
		popup_label.visible = _popup_time > 0.0
		popup_label.modulate.a = clampf(_popup_time / maxf(popup_fade_seconds, 0.01), 0.0, 1.0)

	# The menus live inside the game picture, UNDER this layer, so get out of their way.
	frame.visible = in_game and not menu_open()
	middle.visible = not wants_input()
