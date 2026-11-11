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
## Colours / borders of the box and buttons: ui/hud_theme.tres (ocean blue, like ui/hud_style.tres;
## the corner brackets come from HudStyle.draw_corners).
##
## Whoever wants to talk calls NpcDialog.for_cat(cat).open(name, line, choices), where each
## choice is [button text, function to run when clicked]. NPCs (scripts/npcs/npc.gd) do this
## for you from their Pages, so you normally never call it yourself.
## SPLIT SCREEN: every player has their own talk box in their own HUD (Hud.seat), so two players
## can talk to two NPCs at once. NpcDialog.for_seat(seat) / for_cat(cat) finds the right one.
## (The "[E] TALK TO ..." line is the HUD's Prompt, drawn by hud.gd for anything usable.)
## While it's open your cat ignores the keyboard (cat_player.gd checks NpcDialog.is_open_for),
## the mouse and keys go to this box instead of the game (scripts/ui/game_screen.gd), and Esc
## closes it.

## Player 1's talk box.
static var instance: NpcDialog

## Which player's talk box this is (its HUD's seat).
var seat: int = 0
## True while this talk box is up.
var is_open: bool = false
## Who we're talking to (set by npc.gd just before open(); null = nobody in the world, e.g. a
## script's message). The cat's TALK CAMERA (cat_player.gd _update_talk_camera) turns to frame them.
var talking_to: Node3D = null

## Height of each answer button (HUD units).
@export var choice_height: float = 40.0

@export_group("Talking voice")
## How fast an NPC's line types itself out, in letters per second (0 = the whole line at once).
## Press A / E / Enter while it types to show the rest straight away.
@export var letters_per_second: float = 26.0
## On = one voice blip (the NPC's Voice, e.g. sounds/sfx/meow_blip_don_1..4.wav) at the start of
## every WORD as it types. Off = a blip every Blip Gap Seconds while letters appear (faster chatter).
@export var blip_per_word: bool = true
## The shortest time between two blips, in seconds (with Blip Per Word on, a short word right
## after another can be skipped so the blips never pile on top of each other).
@export var blip_gap_seconds: float = 0.2
## A long speech stops chattering after this many blips (the text keeps typing).
## 0 = never stop: the NPC keeps talking until the whole line has typed out.
@export var max_blips_per_line: int = 0
## How loud the blips are, in decibels (0 = as loud as the files, -6 = about half).
@export var blip_volume_db: float = -10.0

@onready var speaker_label: Label = $Panel/VBox/Speaker
@onready var scroll: ScrollContainer = $Panel/VBox/Scroll
@onready var line_label: Label = $Panel/VBox/Scroll/Body/Line
@onready var choices_box: VBoxContainer = $Panel/VBox/Scroll/Body/Choices
@onready var panel: PanelContainer = $Panel

## The box's size as set in hud.tscn: [left, top, right, bottom] offsets.
var _design: Array[float] = []
## This player's highlighted answer (scripts/ui/seat_focus.gd), moved by their own d-pad / arrows.
var _focus := SeatFocus.new()
## The typewriter: how many letters of the line are showing (a fraction while typing), -1 = done.
var _typed: float = -1.0
## The voice blip sound being used for this line ("" = silent).
var _voice: String = ""
var _blip_wait: float = 0.0
var _blips_left: int = 0


func _enter_tree() -> void:
	seat = (owner as Hud).seat if owner is Hud else 0
	if seat == 0:
		instance = self


func _ready() -> void:
	hide()
	_design = [panel.offset_left, panel.offset_top, panel.offset_right, panel.offset_bottom]
	resized.connect(_fit_panel)
	# The bright corner brackets every other HUD box has (HudStyle), drawn over the theme's box.
	panel.draw.connect(func(): HudStyle.draw_corners(panel, Rect2(Vector2.ZERO, panel.size)))
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


func _input(event: InputEvent) -> void:
	if Seats.seat_of_event(event) != seat:
		return  # another player's button (player 1's HUD hears every button first)
	# Still typing? A / E / Enter shows the rest of the line (instead of picking an answer).
	if is_open and _typed >= 0.0 and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		get_viewport().set_input_as_handled()
		_finish_typing()
		return
	if is_open and _focus.handle(event):  # up / down picks an answer, A / Enter says it
		get_viewport().set_input_as_handled()
		return
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Show a line and the answer buttons. choices = [[text, Callable], ...]
## voice = the speaker's blip sound (a name in sounds/sfx/, e.g. "meow_blip_don"): the line types
## itself out while it chatters. "" = no voice (the line still types out).
func open(speaker: String, line: String, choices: Array, voice: String = "") -> void:
	speaker_label.text = speaker
	line_label.text = line
	_voice = voice
	_blip_wait = 0.0
	_blips_left = max_blips_per_line if max_blips_per_line > 0 else 1_000_000  # (0 = no limit)
	_typed = 0.0 if letters_per_second > 0.0 else -1.0
	# Lay the WHOLE line out first and only hide the letters not typed yet, so the answer buttons
	# sit still instead of sliding down as the text wraps onto more lines.
	line_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	line_label.visible_characters = 0 if _typed >= 0.0 else -1
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


## The typewriter and the voice: a few more letters each frame, and a blip now and then while
## letters (not spaces or punctuation) are appearing.
func _process(delta: float) -> void:
	if _typed < 0.0 or not is_open:
		return
	# Keep the box as tall as the WHOLE line (all its wrapped rows), not just the typed part, so
	# the answer buttons don't slide down as the text types onto a new row.
	line_label.custom_minimum_size.y = line_label.get_line_count() * (line_label.get_line_height()
			+ line_label.get_theme_constant("line_spacing"))
	var before := int(_typed)
	_typed += letters_per_second * delta
	var shown := int(_typed)
	var total := line_label.get_total_character_count()
	_blip_wait -= delta
	if _voice != "" and _blip_wait <= 0.0 and _blips_left > 0:
		var text := line_label.text
		for i in range(before, mini(shown, text.length())):
			var letter := text[i]
			if not _is_letter(letter):
				continue
			# One blip per word: only the first letter of a word (the letter before it isn't one).
			if blip_per_word and i > 0 and _is_letter(text[i - 1]):
				continue
			Sound.play(_voice, blip_volume_db)
			_blip_wait = blip_gap_seconds
			_blips_left -= 1
			break
	if shown >= total:
		_finish_typing()
	else:
		line_label.visible_characters = shown


## A letter or a digit (not a space or punctuation). Apostrophes count, so "I'll" is one word.
static func _is_letter(letter: String) -> bool:
	return letter.to_upper() != letter.to_lower() or letter.is_valid_int() or letter == "'"


## Show the whole line now (typing done or skipped).
func _finish_typing() -> void:
	_typed = -1.0
	line_label.visible_characters = -1
	line_label.custom_minimum_size.y = 0.0  # (back to sizing itself)


## Back to the game: grab the mouse again.
func close() -> void:
	is_open = false
	talking_to = null
	_typed = -1.0
	hide()
	_focus.clear()
	if seat == 0:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
