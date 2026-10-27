class_name NpcDialog
extends Control
## CYPURRPUNK — the TALK BOX at the bottom of the screen when you talk to an NPC.
## Part of the HUD (scenes/ui/hud.tscn > HUD > Frame > NpcDialog), so it's drawn sharp at your
## monitor's real resolution, on top of the low-res game. Node tree:
##   NpcDialog (Control)        <- this script
##   └── Panel (PanelContainer)   <- FIXED size (set by its offsets): it never grows off-screen
##       └── VBox
##           ├── Speaker (Label)  <- who's talking
##           └── Scroll (ScrollContainer)  <- fills the rest of the box; scrolls when a page is long
##               └── Body (VBoxContainer)
##                   ├── Line (Label)     <- what they say
##                   └── Choices (VBoxContainer)  <- one button per answer, made by code
## To make the box bigger/smaller: open scenes/ui/hud.tscn, select NpcDialog > Panel >
## Inspector > Layout > Transform and change Size (in HUD units: the screen is 720 tall).
## On a narrow split screen it shrinks by itself to fit (_fit_panel), never past that size.
## It's anchored to the bottom middle of the screen, so it stays centred on wide monitors.
## Colours / borders of the box and buttons: ui/hud_theme.tres.
##
## Whoever wants to talk calls NpcDialog.for_cat(cat).open(name, line, choices), where each
## choice is [button text, function to run when clicked]. NPCs (scripts/npcs/npc.gd) do this
## for you from their Pages, so you normally never call it yourself.
## SPLIT SCREEN: every player has their own talk box in their own HUD (Hud.seat), so two players
## can talk to two NPCs at once. NpcDialog.for_seat(seat) / for_cat(cat) finds the right one.
## It also shows the "[E] TALK TO ..." prompt (the HUD's "Prompt" label) when your cat is near
## an NPC, and "[E] OPEN STASH" at the stash lockers in the sewers.
## While it's open your cat ignores the keyboard (cat_player.gd checks NpcDialog.is_open_for),
## the mouse and keys go to this box instead of the game (scripts/ui/game_screen.gd), and Esc
## closes it.

## Player 1's talk box.
static var instance: NpcDialog

## Which player's talk box this is (its HUD's seat).
var seat: int = 0
## True while this talk box is up.
var is_open: bool = false

## Height of each answer button (HUD units).
@export var choice_height: float = 40.0

@onready var speaker_label: Label = $Panel/VBox/Speaker
@onready var scroll: ScrollContainer = $Panel/VBox/Scroll
@onready var line_label: Label = $Panel/VBox/Scroll/Body/Line
@onready var choices_box: VBoxContainer = $Panel/VBox/Scroll/Body/Choices
@onready var panel: PanelContainer = $Panel

## The box's size as set in hud.tscn: [left, top, right, bottom] offsets.
var _design: Array[float] = []
## This player's highlighted answer (scripts/ui/seat_focus.gd), moved by their own d-pad / arrows.
var _focus := SeatFocus.new()


func _enter_tree() -> void:
	seat = (owner as Hud).seat if owner is Hud else 0
	if seat == 0:
		instance = self


func _ready() -> void:
	hide()
	Hud.show_element("Prompt", false, seat)
	_design = [panel.offset_left, panel.offset_top, panel.offset_right, panel.offset_bottom]
	resized.connect(_fit_panel)
	_focus.highlighted.connect(func(button: Button): scroll.ensure_control_visible(button))  # long pages scroll along
	_fit_panel()


## Split screen: a narrow or short screen gets a smaller box (but never bigger than in hud.tscn).
func _fit_panel() -> void:
	if _design.is_empty():
		return
	var margin := 12.0
	var half_width := minf((_design[2] - _design[0]) / 2.0, size.x / 2.0 - margin)
	panel.offset_left = -half_width
	panel.offset_right = half_width
	panel.offset_top = maxf(_design[1], -(size.y - margin * 2.0))


## This player's talk box (seat 0 = player 1), or null.
static func for_seat(seat_number: int) -> NpcDialog:
	var hud := Hud.of(seat_number)
	return hud.get_node_or_null("Frame/NpcDialog") as NpcDialog if hud != null else null


## The talk box of the player steering this cat.
static func for_cat(cat: CatPlayer) -> NpcDialog:
	return for_seat(cat.slot)


## Is this player's talk box open?
static func is_open_for(seat_number: int) -> bool:
	var dialog := for_seat(seat_number)
	return dialog != null and dialog.is_open


## Every frame: "[E] TALK TO <name>" while our cat stands next to an NPC (this computer only).
## (Still runs while the talk box is hidden: hiding a Control doesn't stop _process.)
func _process(_delta: float) -> void:
	var game := Game.instance
	var cat := game.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat)) if game != null else null
	if cat != null and not cat.reads_input():
		cat = null
	var npc: Npc = null
	if cat != null and cat.is_controlled and not is_open:
		npc = Npc.nearest_in_reach(cat)
	# The stash lockers use the same prompt line (they aren't an NPC, but it's the same E key).
	var inventory := InventoryScreen.for_seat(seat)
	var stash := npc == null and cat != null and cat.is_controlled and not is_open \
		and not (inventory != null and inventory.visible) and UndergroundHub.instance.near_stash(cat)
	Hud.show_element("Prompt", npc != null or stash, seat)
	var key := Controls.display_name(Controls.binding("interact", Controls.PAD_SLOT)) if Seats.uses_pad(seat) \
		else Controls.key_text("interact")
	if npc != null:
		Hud.set_text("Prompt", "[%s] %s %s" % [key, npc.prompt_verb, npc.npc_name], seat)
	elif stash:
		Hud.set_text("Prompt", "[%s] OPEN STASH" % key, seat)


func _input(event: InputEvent) -> void:
	if Seats.seat_of_event(event) != seat:
		return  # another player's button (player 1's HUD hears every button first)
	if is_open and _focus.handle(event):  # up / down picks an answer, A / Enter says it
		get_viewport().set_input_as_handled()
		return
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Show a line and the answer buttons. choices = [[text, Callable], ...]
func open(speaker: String, line: String, choices: Array) -> void:
	speaker_label.text = speaker
	line_label.text = line
	for old in choices_box.get_children():
		choices_box.remove_child(old)
		old.queue_free()
	for choice in choices:
		var button := Button.new()
		button.text = "> " + choice[0]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, choice_height)
		button.pressed.connect(choice[1])
		choices_box.add_child(button)
	is_open = true
	show()
	if seat == 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # (the mouse is player 1's)
	_focus.set_buttons(choices_box.get_children())  # the first answer is highlighted
	# Every new page starts at the top (with the NPC's line). Deferred = after the
	# focus-scroll above has happened, so this one wins.
	scroll.set_deferred("scroll_vertical", 0)


## Back to the game: grab the mouse again.
func close() -> void:
	is_open = false
	hide()
	_focus.clear()
	if seat == 0:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
