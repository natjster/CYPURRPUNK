class_name Hud
extends CanvasLayer
## CYPURRPUNK — the HUD framework: everything on screen during a game that isn't the world
## or a menu (HP, the extraction arrow, everyone's cash in the sewers, prompts, crosshair, messages).
## Kept simple on purpose: no cash / loot / heat lines while you're up in the city.
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
##       ├── Bars         <- health bars over enemies / hurt cats (scripts/ui/hud_health_bars.gd)
##       ├── Damage       <- damage numbers off things you shoot (scripts/ui/hud_damage_numbers.gd)
##       ├── Top          <- stays up while you talk / shop: Health (your health bar, top-left,
##       │                   scripts/ui/hud_health_bar.gd), Heat (the red/blue heat bar, top-right,
##       │                   scripts/ui/hud_heat_bar.gd), DropOff (top-middle), Scoreboard
##       │                   (under Heat, everyone's cash: only shown in the sewers, wallet.gd)
##       ├── Middle       <- hidden while a window is open: Popup, Crosshair, Message, Prompt, Held
##       ├── Inventory    <- the Tab screen (scripts/ui/inventory_ui.gd)    } "windows": while one is
##       ├── NpcDialog    <- the talk box (scripts/ui/npc_dialog.gd)        } open, it gets the mouse
##       └── PlayerPause  <- split screen: one player's pause menu (scripts/ui/player_pause.gd)
##
## HOW OTHER SCRIPTS USE IT (every function is "static": call it on the class, from anywhere):
##   Hud.set_text("DropOff", "EXTRACT ^ 9m")  change a label's words (by node name)
##   Hud.show_element("Crosshair", true)      show / hide one piece
##   Hud.set_color("DropOff", Color.WHITE)    change a label's text colour
##   Hud.damage_number(where, 38, false, seat) a damage number popping off a world position
##   Hud.show_message("DON: Go get 'em.", 4)  the line of text in the middle, for N seconds
##   Hud.popup("EXTRACTED +$80", 2.5)         the big text that fades out (e.g. extraction)
##   Hud.set_in_game(true)                    the whole HUD on (in a game) / off (start menu)
##   Hud.element("Scoreboard")                the node itself, for anything else
##
## ADDING A NEW HUD PIECE: open scenes/ui/hud.tscn, right-click Top (or Middle) > Add Child Node >
## Label, give it a unique name (e.g. "Ammo"), pick an anchor in the toolbar (Layout > Anchors
## Preset, e.g. Top Right) so it sticks to that corner on every screen shape, then from your
## script call Hud.set_text("Ammo", "...").
##
## The whole HUD hides itself while a full-screen menu (pause, settings, MY CAT) is open.
## While a HUD window (talk box, inventory) is open, the mouse and keys go to the HUD instead of
## the game (scripts/ui/game_screen.gd asks Hud.wants_input()).
##
## SPLIT SCREEN: every player on this computer has their OWN HUD on their own part of the screen
## (shrunk to fit), with their own talk box and inventory. Player 1's is this scene in
## game_screen.tscn; players 2-4's are copies made by scripts/ui/game_screen.gd (each inside its
## own little SubViewport, so each player has their own highlighted button). Each HUD knows its
## SEAT (0 = player 1, scripts/seats.gd). The functions below take an optional seat:
##   Hud.set_text("DropOff", "...", cat.slot) player 2's line (seat left out = player 1)
##   Hud.show_message("HI", 3, cat.slot)      only player 2 sees it
##   Hud.show_message("KOI GRABBED!")         messages / popups with no seat: EVERY player sees them

## Player 1's HUD (Hud.instance).
static var instance: Hud
## Every player's HUD on this computer, by seat (0 = player 1). Use Hud.of(seat).
static var huds: Array = [null, null, null, null]
## In a game right now? (So a HUD made later starts in the right state.)
static var _playing: bool = false

## Which player this HUD belongs to (their seat). Set before it's added to the scene.
var seat: int = 0

## How long the big popup takes to fade away at the end (seconds).
@export var popup_fade_seconds: float = 1.0

## True while we're in a game (Hud.set_in_game).
var in_game: bool = false

var _message_time: float = 0.0
var _popup_time: float = 0.0

@onready var frame: Control = $Frame
@onready var middle: Control = $Frame/Middle


func _enter_tree() -> void:
	huds[seat] = self
	if seat == 0:
		instance = self


func _exit_tree() -> void:
	if huds[seat] == self:
		huds[seat] = null


func _ready() -> void:
	in_game = _playing
	frame.clip_contents = true  # split screen: nothing spills onto another player's screen
	frame.hide()
	element("Message").hide()
	element("Popup").hide()


# --- The functions other scripts call ---

## The HUD of the player in this seat (0 = player 1), or null.
static func of(seat_number: int) -> Hud:
	if seat_number < 0 or seat_number >= huds.size():
		return null
	var hud: Hud = huds[seat_number]
	return hud if hud != null and is_instance_valid(hud) else null


## The HUD piece with this node name (anywhere under Frame), or null if there isn't one.
static func element(element_name: String, seat_number: int = 0) -> Control:
	var hud := of(seat_number)
	if hud == null:
		return null
	return hud.get_node("Frame").find_child(element_name, true, false) as Control


## Change the words on a HUD label.
static func set_text(element_name: String, text: String, seat_number: int = 0) -> void:
	var label := element(element_name, seat_number) as Label
	if label != null:
		label.text = text


## Show or hide one HUD piece.
static func show_element(element_name: String, shown: bool, seat_number: int = 0) -> void:
	var piece := element(element_name, seat_number)
	if piece != null:
		piece.visible = shown


## Change a label's text colour.
static func set_color(element_name: String, color: Color, seat_number: int = 0) -> void:
	var label := element(element_name, seat_number) as Label
	if label != null:
		label.add_theme_color_override("font_color", color)


## A line of text in the middle of the screen for a few seconds (e.g. what Don says).
## seat_number = only that player sees it; left out (-1) = every player on this computer.
static func show_message(text: String, seconds: float = 4.0, seat_number: int = -1) -> void:
	for hud in _targets(seat_number):
		set_text("Message", text, hud.seat)
		show_element("Message", true, hud.seat)
		hud._message_time = seconds


## The big text in the middle that fades out (e.g. "EXTRACTED +$80").
## seat_number = only that player sees it; left out (-1) = every player on this computer.
static func popup(text: String, seconds: float = 2.5, seat_number: int = -1) -> void:
	for hud in _targets(seat_number):
		set_text("Popup", text, hud.seat)
		show_element("Popup", true, hud.seat)
		hud._popup_time = seconds


## A damage number popping off the world position "where" (Cyberpunk-style), on this player's
## HUD only. crit = a critical hit (bigger, yellow). See scripts/ui/hud_damage_numbers.gd.
static func damage_number(where: Vector3, amount: int, crit: bool = false, seat_number: int = 0) -> void:
	var numbers := element("Damage", seat_number) as HudDamageNumbers
	if numbers != null:
		numbers.spawn(where, amount, crit)


## The HUDs a message goes to: one player's, or everyone's (-1).
static func _targets(seat_number: int) -> Array:
	if seat_number >= 0:
		var hud := of(seat_number)
		return [hud] if hud != null else []
	var all: Array = []
	for i in huds.size():
		if of(i) != null:
			all.append(of(i))
	return all


## True while this player's HUD window (talk box or inventory) is open: it gets their buttons
## (and for player 1 the mouse and keys), not the game.
static func wants_input(seat_number: int = 0) -> bool:
	var inventory := InventoryScreen.for_seat(seat_number)
	return NpcDialog.is_open_for(seat_number) or (inventory != null and inventory.visible) \
		or PlayerPause.is_open_for(seat_number)


## True while a full-screen game menu (pause, settings, MY CAT) is open; the HUD hides under it.
static func menu_open() -> bool:
	var game := Game.instance
	if game == null or not is_instance_valid(game):
		return true
	return PauseMenu.is_open or game.settings_menu.visible or game.cat_creator.visible


## The whole HUD on (in a game) or off (start menu): every player's.
static func set_in_game(on: bool) -> void:
	_playing = on
	for hud in _targets(-1):
		hud.in_game = on


## GameScreen calls this so the HUD covers exactly the game picture (not the black bars).
## hud_scale < 1 shrinks everything (a quarter of the screen gets a smaller HUD that still fits).
func fit_to(rect: Rect2, hud_scale: float = 1.0) -> void:
	offset = rect.position
	scale = Vector2(hud_scale, hud_scale)
	frame.position = Vector2.ZERO
	frame.size = rect.size / hud_scale
	# The message line never runs off a narrow (split) screen: it wraps instead.
	var message := frame.find_child("Message", true, false) as Label
	if message != null:
		if not message.has_meta("design_half_width"):
			message.set_meta("design_half_width", -message.offset_left)
		var half_width := minf(message.get_meta("design_half_width"), frame.size.x / 2.0 - 12.0)
		message.offset_left = -half_width
		message.offset_right = half_width
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


# --- Every frame: timers, and hiding behind menus ---

func _process(delta: float) -> void:
	# (Each player's HUD hides its OWN message / popup: "seat". Leaving it out used to hide
	# player 1's instead, so player 2's messages never went away.)
	if _message_time > 0.0:
		_message_time -= delta
		show_element("Message", _message_time > 0.0, seat)
	if _popup_time > 0.0:
		_popup_time -= delta
		var popup_label := element("Popup", seat)
		popup_label.visible = _popup_time > 0.0
		popup_label.modulate.a = clampf(_popup_time / maxf(popup_fade_seconds, 0.01), 0.0, 1.0)

	# The menus live inside the game picture, UNDER this layer, so get out of their way.
	frame.visible = in_game and not menu_open()
	middle.visible = not wants_input(seat)
