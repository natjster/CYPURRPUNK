class_name NpcDialog
extends Control
## MEOW-CITY 1999 — the TALK BOX at the bottom of the screen when you talk to an NPC.
## Attach to the "NpcDialog" Control under PS1Overlay in main.tscn. Expected node tree:
##   NpcDialog (Control)        <- this script
##   └── Panel (PanelContainer)   <- FIXED size (set by its offsets): it never grows off-screen
##       └── VBox
##           ├── Speaker (Label)  <- who's talking
##           └── Scroll (ScrollContainer)  <- fills the rest of the box; scrolls when a page is long
##               └── Body (VBoxContainer)
##                   ├── Line (Label)     <- what they say
##                   └── Choices (VBoxContainer)  <- one button per answer, made by code
## To make the box bigger/smaller: select Panel > Inspector > Layout > Transform and change
## Position / Size (now x=16, y=116, 288 x 116 — the screen is 320 x 240).
##
## Whoever wants to talk calls NpcDialog.instance.open(name, line, choices), where each
## choice is [button text, function to run when clicked]. NPCs (scripts/npcs/npc.gd) do this
## for you from their Pages, so you normally never call it yourself.
## It also shows the "[E] TALK TO ..." prompt (PS1Overlay/HUD/Prompt) when your cat is near an NPC,
## and "[E] OPEN STASH" at the stash lockers in the sewers.
## While it's open your cat ignores the keyboard (cat_player.gd checks NpcDialog.is_open),
## and Esc closes it. It sits after the other menus in the scene, so it sees Esc first.

## The one talk box (so NPCs can reach it).
static var instance: NpcDialog
## True while the talk box is up.
static var is_open: bool = false

@onready var speaker_label: Label = $Panel/VBox/Speaker
@onready var scroll: ScrollContainer = $Panel/VBox/Scroll
@onready var line_label: Label = $Panel/VBox/Scroll/Body/Line
@onready var choices_box: VBoxContainer = $Panel/VBox/Scroll/Body/Choices
@onready var prompt_label: Label = $"../HUD/Prompt"


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	is_open = false  # (it's static, so reset it when the scene reloads)
	hide()
	prompt_label.hide()


## Every frame: "[E] TALK TO <name>" while our cat stands next to an NPC (this computer only).
## (Still runs while the talk box is hidden: hiding a Control doesn't stop _process.)
func _process(_delta: float) -> void:
	var cat := Game.instance.my_cat()
	var npc: Npc = null
	if cat != null and cat.is_controlled and not is_open:
		npc = Npc.nearest_in_reach(cat)
	# The stash lockers use the same prompt line (they aren't an NPC, but it's the same E key).
	var stash := npc == null and cat != null and cat.is_controlled and not is_open \
		and not InventoryScreen.instance.visible and UndergroundHub.instance.near_stash(cat)
	prompt_label.visible = npc != null or stash
	if npc != null:
		prompt_label.text = "[%s] TALK TO %s" % [Controls.key_text("interact"), npc.npc_name]
	elif stash:
		prompt_label.text = "[%s] OPEN STASH" % Controls.key_text("interact")


func _input(event: InputEvent) -> void:
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
		button.custom_minimum_size = Vector2(0, 13)
		button.pressed.connect(choice[1])
		choices_box.add_child(button)
	is_open = true
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scroll.follow_focus = true  # arrow keys scroll the list along with the highlighted button
	(choices_box.get_child(0) as Button).grab_focus()
	# Every new page starts at the top (with the NPC's line). Deferred = after the
	# focus-scroll above has happened, so this one wins.
	scroll.set_deferred("scroll_vertical", 0)


## Back to the game: grab the mouse again.
func close() -> void:
	is_open = false
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
