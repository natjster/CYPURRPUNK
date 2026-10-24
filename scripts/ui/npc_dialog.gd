class_name NpcDialog
extends Control
## MEOW-CITY 1999 — the TALK BOX at the bottom of the screen when you talk to a hub cat.
## Attach to the "NpcDialog" Control under PS1Overlay in main.tscn. Expected node tree:
##   NpcDialog (Control)        <- this script
##   └── Panel (PanelContainer)
##       └── VBox
##           ├── Speaker (Label)  <- who's talking
##           ├── Line (Label)     <- what they say
##           └── Choices (VBoxContainer)  <- one button per answer, made by code
##
## Whoever wants to talk calls NpcDialog.instance.open(name, line, choices), where each
## choice is [button text, function to run when clicked] (see hub_npc.gd).
## While it's open your cat ignores the keyboard (cat_player.gd checks NpcDialog.is_open),
## and Esc closes it. It sits after the other menus in the scene, so it sees Esc first.

## The one talk box (so NPCs can reach it).
static var instance: NpcDialog
## True while the talk box is up.
static var is_open: bool = false

@onready var speaker_label: Label = $Panel/VBox/Speaker
@onready var line_label: Label = $Panel/VBox/Line
@onready var choices_box: VBoxContainer = $Panel/VBox/Choices


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	is_open = false  # (it's static, so reset it when the scene reloads)
	hide()


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
	(choices_box.get_child(0) as Button).grab_focus()


## Back to the game: grab the mouse again.
func close() -> void:
	is_open = false
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
