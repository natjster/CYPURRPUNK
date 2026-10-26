extends Node
## MEOW-CITY 1999 — the CONTROLS framework: every key / mouse button the game uses.
## Loaded automatically on startup (it's an Autoload named "Controls").
##
## What it does:
##   - registers all input actions in code (you never touch Project Settings > Input Map),
##   - lets the player rebind them (SETTINGS > KEYS), two keys per action,
##   - saves the player's keys to user://controls.cfg (%APPDATA%\MeowCity1999\controls.cfg),
##   - tells on-screen prompts which key to show: Controls.key_text("interact") -> "E".
##
## Game code never cares WHICH key is pressed — it asks for the action by name, e.g.
##   Input.is_action_pressed("sprint")   or   event.is_action_pressed("interact")
##
## To ADD a control: add a line to ACTIONS below (it shows up in the KEYS menu by itself),
## then use its action name in your script. To change a DEFAULT key, edit "keys" below.
## Esc is not in here on purpose: it always opens / closes menus and can't be rebound.

## Fired after any key changes (and once after loading), so prompts can update their text.
signal changed

const SAVE_PATH: String = "user://controls.cfg"

## Every control, in the order the KEYS menu lists them. Each line is a Dictionary:
##   action  = the name scripts use (Input.is_action_pressed("jump"))
##   label   = the text in the KEYS menu
##   context = when it's used: "foot" (walking), "car" (driving) or "any" (both).
##             Two controls can share a key only when they're never used at the same time
##             (e.g. JUMP on foot and HANDBRAKE in the car are both SPACE).
##   keys    = the default keys, up to 2. Key names as Godot writes them ("W", "Space",
##             "Shift", "Up", "Tab"...) or mouse buttons: "Mouse Left", "Mouse Right",
##             "Mouse Middle", "Wheel Up", "Wheel Down", "Mouse 4", "Mouse 5".
const ACTIONS: Array = [
	{"action": "move_forward", "label": "FORWARD / GAS", "context": "any", "keys": ["W", "Up"]},
	{"action": "move_back", "label": "BACK / BRAKE", "context": "any", "keys": ["S", "Down"]},
	{"action": "move_left", "label": "LEFT", "context": "any", "keys": ["A", "Left"]},
	{"action": "move_right", "label": "RIGHT", "context": "any", "keys": ["D", "Right"]},
	{"action": "jump", "label": "JUMP", "context": "foot", "keys": ["Space"]},
	{"action": "sprint", "label": "ZOOMIES", "context": "foot", "keys": ["Shift"]},
	{"action": "interact", "label": "GRAB / TALK / CAR", "context": "any", "keys": ["E"]},
	{"action": "drop", "label": "DROP", "context": "foot", "keys": ["G"]},
	{"action": "shoot", "label": "USE RIGHT PAW", "context": "foot", "keys": ["Mouse Left"]},
	{"action": "use_left", "label": "USE LEFT PAW", "context": "foot", "keys": ["Mouse Right"]},
	{"action": "inventory", "label": "INVENTORY", "context": "any", "keys": ["Tab", "I"]},
	{"action": "meow", "label": "MEOW", "context": "foot", "keys": ["M"]},
	{"action": "handbrake", "label": "HANDBRAKE", "context": "car", "keys": ["Space"]},
]

## How many keys each action can have (the two columns in the KEYS menu).
const SLOTS: int = 2

## Mouse button number -> the name used in ACTIONS and the save file.
const MOUSE_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "Mouse Left", MOUSE_BUTTON_RIGHT: "Mouse Right",
	MOUSE_BUTTON_MIDDLE: "Mouse Middle", MOUSE_BUTTON_WHEEL_UP: "Wheel Up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down", MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}
## Short versions for the small screen (key names are just upper-cased).
const MOUSE_SHORT: Dictionary = {
	"Mouse Left": "LMB", "Mouse Right": "RMB", "Mouse Middle": "MMB",
	"Wheel Up": "WHEEL UP", "Wheel Down": "WHEEL DN", "Mouse 4": "MOUSE 4", "Mouse 5": "MOUSE 5",
}

## The player's keys right now: {action: ["W", "Up"]} ("" = empty slot).
var bindings: Dictionary = {}
## True when started by the DevCapture test tool: use the default keys, never save.
var _is_test_run: bool = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		_is_test_run = _is_test_run or arg.begins_with("--capture")
	_use_defaults()
	if not _is_test_run:
		_load()
	apply()


# --- Reading the keys (for prompts and the KEYS menu) ---

## The key to show on a prompt for this action, e.g. "E" -> "[E] TALK". "?" if unbound.
func key_text(action: String) -> String:
	for key_name in bindings.get(action, []):
		if key_name != "":
			return display_name(key_name)
	return "?"


## The key in one slot (0 or 1) of an action, as stored ("W", "Mouse Left" or "").
func binding(action: String, slot: int) -> String:
	return bindings[action][slot]


## The menu label of an action ("JUMP"), or the action name if it's not in ACTIONS.
func label_of(action: String) -> String:
	for entry in ACTIONS:
		if entry.action == action:
			return entry.label
	return action


## How a stored key name looks on screen: "Space" -> "SPACE", "Mouse Left" -> "LMB".
## Letter keys show the letter printed on THIS player's keyboard (AZERTY etc.).
func display_name(key_name: String) -> String:
	if key_name == "":
		return "-"
	if MOUSE_SHORT.has(key_name):
		return MOUSE_SHORT[key_name]
	var physical := OS.find_keycode_from_string(key_name)
	var on_this_keyboard := DisplayServer.keyboard_get_keycode_from_physical(physical) if DisplayServer.get_name() != "headless" else physical
	return OS.get_keycode_string(on_this_keyboard if on_this_keyboard != KEY_NONE else physical).to_upper()


## Turns a key press / mouse click into a key name we can store, or "" if it can't be bound
## (mouse movement, key releases, Esc which always means "menu").
func name_from_event(event: InputEvent) -> String:
	if event is InputEventKey and event.pressed and not event.echo:
		var physical: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if physical == KEY_ESCAPE or physical == KEY_NONE:
			return ""
		return OS.get_keycode_string(physical)
	if event is InputEventMouseButton and event.pressed:
		return MOUSE_NAMES.get(event.button_index, "")
	return ""


# --- Changing the keys (used by the KEYS menu) ---

## Put a key in one slot of an action, apply and save. If another control that's used at
## the same time already had this key, it loses it; returns that control's menu label
## (so the menu can say "taken from JUMP"), or "".
func set_binding(action: String, slot: int, key_name: String) -> String:
	var taken_from := ""
	if key_name != "":
		var context: String = _context_of(action)
		for entry in ACTIONS:
			if not _contexts_clash(context, entry.context):
				continue
			for other_slot in SLOTS:
				if (entry.action != action or other_slot != slot) and bindings[entry.action][other_slot] == key_name:
					bindings[entry.action][other_slot] = ""
					if entry.action != action:
						taken_from = entry.label
	bindings[action][slot] = key_name
	apply()
	_save()
	return taken_from


## Every key back to the defaults in ACTIONS.
func reset_to_defaults() -> void:
	_use_defaults()
	apply()
	_save()


## Rebuild Godot's Input Map from `bindings`.
func apply() -> void:
	for entry in ACTIONS:
		var action: String = entry.action
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key_name in bindings[action]:
			var event := _event_from_name(key_name)
			if event != null:
				InputMap.action_add_event(action, event)
	changed.emit()


# --- Inner workings ---

func _use_defaults() -> void:
	for entry in ACTIONS:
		var keys: Array = entry["keys"].duplicate()
		keys.resize(SLOTS)
		for i in SLOTS:
			if keys[i] == null:
				keys[i] = ""
		bindings[entry.action] = keys


## Key name -> an input event Godot can match, or null for "" / unknown names.
func _event_from_name(key_name: String) -> InputEvent:
	if key_name == "":
		return null
	for button in MOUSE_NAMES:
		if MOUSE_NAMES[button] == key_name:
			var click := InputEventMouseButton.new()
			click.button_index = button
			return click
	var keycode := OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		return null
	var key := InputEventKey.new()
	key.physical_keycode = keycode  # "physical" = same key position on any keyboard layout
	return key


func _context_of(action: String) -> String:
	for entry in ACTIONS:
		if entry.action == action:
			return entry.context
	return "any"


## Can two controls be needed at the same moment? ("any" clashes with everything.)
func _contexts_clash(a: String, b: String) -> bool:
	return a == "any" or b == "any" or a == b


func _save() -> void:
	if _is_test_run:
		return
	var config := ConfigFile.new()
	for action in bindings:
		config.set_value("keys", action, bindings[action])
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return  # first time playing: keep the defaults
	for action in bindings:
		var saved: Variant = config.get_value("keys", action, null)
		if saved is Array and saved.size() == SLOTS and saved.all(func(k): return k is String):  # ignore broken / old values
			bindings[action] = saved
