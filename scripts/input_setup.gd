extends Node
## Registers every keyboard control the game uses, so you never have to
## click through Project Settings > Input Map by hand.
## Loaded automatically on startup (it's an Autoload named "InputSetup").
## To rebind a key, change it here — e.g. swap KEY_E for KEY_F.

const ACTIONS := {
	# On foot
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],  # Zoomies!
	"interact": [KEY_E],    # Pick up an item, enter / exit the car
	"drop": [KEY_G],        # Drop what's in your paws
	"inventory": [KEY_TAB, KEY_I],  # Open / close the inventory screen
	# In the car (W/S/A/D reuse the move_* actions above)
	"handbrake": [KEY_SPACE],
}

## Mouse-button controls (kept separate because they're a different kind of input).
const MOUSE_ACTIONS := {
	"shoot": [MOUSE_BUTTON_LEFT],      # Use the item in your right paw (or a 2-paw item)
	"use_left": [MOUSE_BUTTON_RIGHT],  # Use the item in your left paw
}


func _ready() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key  # "physical" = same key position on any keyboard layout
			InputMap.action_add_event(action, event)
	for action in MOUSE_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for button in MOUSE_ACTIONS[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
