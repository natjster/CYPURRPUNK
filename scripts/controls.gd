extends Node
## CYPURRPUNK — the CONTROLS framework: every key, mouse button and CONTROLLER button the game uses.
## Loaded automatically on startup (it's an Autoload named "Controls").
##
## What it does:
##   - registers all input actions in code (you never touch Project Settings > Input Map),
##   - lets the player rebind them (SETTINGS > KEYS): two keyboard/mouse keys + one controller
##     button per action,
##   - saves the player's keys to user://controls.cfg (%APPDATA%\MeowCity1999\controls.cfg),
##   - tells on-screen prompts which key to show: Controls.key_text("interact") -> "E", or "X"
##     when the player is using a controller (whatever they touched last decides),
##   - rumbles the controller: Controls.rumble(0.3, 0.7, 0.25).
##
## Game code never cares WHICH key is pressed — it asks for the action by name, e.g.
##   Input.is_action_pressed("sprint")   or   event.is_action_pressed("interact")
## The keyboard AND the controller both trigger the same action, so this works for both.
##
## To ADD a control: add a line to ACTIONS below (it shows up in the KEYS menu by itself),
## then use its action name in your script. To change a DEFAULT key, edit "keys" / "pad" below.
## Esc and the controller's START button are not in ACTIONS on purpose: they always open /
## close menus and can't be rebound (see FIXED).

## Fired after any key changes (and once after loading), and when the player switches between
## keyboard and controller, so prompts can update their text.
signal changed

const SAVE_PATH: String = "user://controls.cfg"

## Every control, in the order the KEYS menu lists them. Each line is a Dictionary:
##   action  = the name scripts use (Input.is_action_pressed("jump"))
##   label   = the text in the KEYS menu
##   context = when it's used: "foot" (walking), "car" (driving) or "any" (both).
##             Two controls can share a key only when they're never used at the same time
##             (e.g. JUMP on foot and HANDBRAKE in the car are both SPACE).
##   keys    = the default keyboard / mouse keys, up to 2. Key names as Godot writes them
##             ("W", "Space", "Shift", "Up", "Tab"...) or mouse buttons: "Mouse Left",
##             "Mouse Right", "Mouse Middle", "Wheel Up", "Wheel Down", "Mouse 4", "Mouse 5".
##   pad     = the default controller button ("" = none). Names are "Pad " + one of PAD_BUTTONS
##             or PAD_AXES below, e.g. "Pad A", "Pad RT", "Pad Left Stick Up". They're written
##             the Xbox way; PlayStation pads show CROSS / CIRCLE / L2... on screen by themselves.
const ACTIONS: Array = [
	{"action": "move_forward", "label": "FORWARD / GAS", "context": "any", "keys": ["W", "Up"], "pad": "Pad Left Stick Up"},
	{"action": "move_back", "label": "BACK / BRAKE", "context": "any", "keys": ["S", "Down"], "pad": "Pad Left Stick Down"},
	{"action": "move_left", "label": "LEFT", "context": "any", "keys": ["A", "Left"], "pad": "Pad Left Stick Left"},
	{"action": "move_right", "label": "RIGHT", "context": "any", "keys": ["D", "Right"], "pad": "Pad Left Stick Right"},
	{"action": "look_up", "label": "LOOK UP", "context": "any", "keys": [], "pad": "Pad Right Stick Up"},
	{"action": "look_down", "label": "LOOK DOWN", "context": "any", "keys": [], "pad": "Pad Right Stick Down"},
	{"action": "look_left", "label": "LOOK LEFT", "context": "any", "keys": [], "pad": "Pad Right Stick Left"},
	{"action": "look_right", "label": "LOOK RIGHT", "context": "any", "keys": [], "pad": "Pad Right Stick Right"},
	{"action": "jump", "label": "JUMP", "context": "foot", "keys": ["Space"], "pad": "Pad A"},
	{"action": "sprint", "label": "ZOOMIES", "context": "foot", "keys": ["Shift"], "pad": "Pad L3"},
	{"action": "interact", "label": "GRAB / TALK / CAR", "context": "any", "keys": ["E"], "pad": "Pad X"},
	{"action": "drop", "label": "DROP", "context": "foot", "keys": ["G"], "pad": "Pad D-Pad Down"},
	{"action": "shoot", "label": "USE RIGHT PAW", "context": "foot", "keys": ["Mouse Left"], "pad": "Pad RT"},
	{"action": "use_left", "label": "USE LEFT PAW", "context": "foot", "keys": ["Mouse Right"], "pad": "Pad LT"},
	{"action": "inventory", "label": "INVENTORY", "context": "any", "keys": ["Tab", "I"], "pad": "Pad Y"},
	{"action": "meow", "label": "MEOW", "context": "foot", "keys": ["M"], "pad": "Pad B"},
	{"action": "gas", "label": "GAS (TRIGGER)", "context": "car", "keys": [], "pad": "Pad RT"},
	{"action": "brake", "label": "BRAKE (TRIGGER)", "context": "car", "keys": [], "pad": "Pad LT"},
	{"action": "handbrake", "label": "HANDBRAKE", "context": "car", "keys": ["Space"], "pad": "Pad RB"},
]

## Controls that can't be rebound (they work the same in every menu). Godot's own ui_* menu
## actions already have Enter / Esc / arrow keys / d-pad; these add the controller to them.
##   pause        = open / close the pause menu (Esc, START)
##   ui_accept    = press the highlighted menu button (A)
##   ui_cancel    = back / close (B)
##   ui_tab_left / ui_tab_right = previous / next tab in SETTINGS (LB / RB)
##   ui_drop      = drop the highlighted item in the inventory (X)
const FIXED: Dictionary = {
	"pause": ["Escape", "Pad Start"],
	"ui_accept": ["Pad A"],
	"ui_cancel": ["Pad B"],
	"ui_tab_left": ["Pad LB"],
	"ui_tab_right": ["Pad RB"],
	"ui_drop": ["Pad X"],
}

## How many keyboard / mouse keys each action can have (the first two columns in the KEYS menu).
const SLOTS: int = 2
## The slot number of the controller button (the third column in the KEYS menu).
const PAD_SLOT: int = 2
## Sticks and triggers closer to the middle than this (0 = centre, 1 = pushed all the way)
## count as "not pushed". Raise it if your character creeps along on its own (stick drift).
const STICK_DEADZONE: float = 0.2
## How far a stick / trigger must be pushed to bind it in the KEYS menu.
const BIND_THRESHOLD: float = 0.6

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
## Controller button number -> its name (written after "Pad " in ACTIONS and the save file).
const PAD_BUTTONS: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_DPAD_UP: "D-Pad Up", JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left", JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
}
## Stick directions and triggers: name -> [axis, direction (-1 or +1)].
const PAD_AXES: Dictionary = {
	"Left Stick Left": [JOY_AXIS_LEFT_X, -1], "Left Stick Right": [JOY_AXIS_LEFT_X, 1],
	"Left Stick Up": [JOY_AXIS_LEFT_Y, -1], "Left Stick Down": [JOY_AXIS_LEFT_Y, 1],
	"Right Stick Left": [JOY_AXIS_RIGHT_X, -1], "Right Stick Right": [JOY_AXIS_RIGHT_X, 1],
	"Right Stick Up": [JOY_AXIS_RIGHT_Y, -1], "Right Stick Down": [JOY_AXIS_RIGHT_Y, 1],
	"LT": [JOY_AXIS_TRIGGER_LEFT, 1], "RT": [JOY_AXIS_TRIGGER_RIGHT, 1],
}
## How controller names look on the small screen (anything missing is just upper-cased).
const PAD_SHORT: Dictionary = {
	"Left Stick Left": "LS LEFT", "Left Stick Right": "LS RIGHT", "Left Stick Up": "LS UP",
	"Left Stick Down": "LS DN", "Right Stick Left": "RS LEFT", "Right Stick Right": "RS RIGHT",
	"Right Stick Up": "RS UP", "Right Stick Down": "RS DN",
	"D-Pad Up": "DPAD UP", "D-Pad Down": "DPAD DN", "D-Pad Left": "DPAD LT", "D-Pad Right": "DPAD RT",
}
## The same buttons on a PlayStation controller.
const PLAYSTATION_NAMES: Dictionary = {
	"A": "CROSS", "B": "CIRCLE", "X": "SQUARE", "Y": "TRIANGLE", "LB": "L1", "RB": "R1",
	"LT": "L2", "RT": "R2", "Back": "SHARE", "Start": "OPTIONS", "Guide": "PS",
}

## The player's keys right now: {action: ["W", "Up", "Pad Left Stick Up"]} ("" = empty slot).
## Slots 0 and 1 are keyboard / mouse, slot 2 (PAD_SLOT) is the controller.
var bindings: Dictionary = {}
## True while the player is using a controller (they touched it last). Prompts show controller
## buttons then, and the inventory / menus highlight a button so the d-pad can move around.
var using_pad: bool = false
## Which controller they touched last (the one that rumbles). 0 = the first one plugged in.
var pad_device: int = 0
## True when started by the DevCapture test tool: use the default keys, never save.
var _is_test_run: bool = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		_is_test_run = _is_test_run or arg.begins_with("--capture")
	_use_defaults()
	if not _is_test_run:
		_load()
	_add_fixed_actions()
	apply()
	# (Seats passes player 1's key presses / mouse moves / controller presses to notice_device, so
	# we always know whether PLAYER 1 is on the keyboard or a controller. Other players' controllers
	# don't count: they never change player 1's prompts.)


# --- Reading the keys (for prompts and the KEYS menu) ---

## The key to show on a prompt for this action, e.g. "E" -> "[E] TALK". "?" if unbound.
## Shows the controller button instead while the player is using a controller.
## Also works for the FIXED controls ("pause", "ui_accept"...).
func key_text(action: String) -> String:
	var names: Array = bindings.get(action, FIXED.get(action, []))
	var fallback := "?"
	for key_name in names:
		if key_name == "":
			continue
		if _is_pad_name(key_name) == using_pad:
			return display_name(key_name)
		if fallback == "?":
			fallback = display_name(key_name)  # nothing for this device: show the other one
	return fallback


## The key in one slot (0 / 1 = keyboard, 2 = controller) of an action, as stored
## ("W", "Mouse Left", "Pad A" or "").
func binding(action: String, slot: int) -> String:
	return bindings[action][slot]


## The menu label of an action ("JUMP"), or the action name if it's not in ACTIONS.
func label_of(action: String) -> String:
	for entry in ACTIONS:
		if entry.action == action:
			return entry.label
	return action


## How a stored key name looks on screen: "Space" -> "SPACE", "Mouse Left" -> "LMB",
## "Pad A" -> "A" (or "CROSS" on a PlayStation controller), "Pad Left Stick Up" -> "LS UP".
## Letter keys show the letter printed on THIS player's keyboard (AZERTY etc.).
func display_name(key_name: String) -> String:
	if key_name == "":
		return "-"
	if MOUSE_SHORT.has(key_name):
		return MOUSE_SHORT[key_name]
	if _is_pad_name(key_name):
		var button := key_name.trim_prefix("Pad ")
		if _is_playstation() and PLAYSTATION_NAMES.has(button):
			return PLAYSTATION_NAMES[button]
		return PAD_SHORT.get(button, button.to_upper())
	var physical := OS.find_keycode_from_string(key_name)
	var on_this_keyboard := DisplayServer.keyboard_get_keycode_from_physical(physical) if DisplayServer.get_name() != "headless" else physical
	return OS.get_keycode_string(on_this_keyboard if on_this_keyboard != KEY_NONE else physical).to_upper()


## Turns a key press / mouse click / controller press into a key name we can store, or "" if
## it can't be bound (mouse movement, key releases, a stick only nudged, and Esc / START
## which always mean "menu").
func name_from_event(event: InputEvent) -> String:
	if event is InputEventKey and event.pressed and not event.echo:
		var physical: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if physical == KEY_ESCAPE or physical == KEY_NONE:
			return ""
		return OS.get_keycode_string(physical)
	if event is InputEventMouseButton and event.pressed:
		return MOUSE_NAMES.get(event.button_index, "")
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START or not PAD_BUTTONS.has(event.button_index):
			return ""
		return "Pad " + PAD_BUTTONS[event.button_index]
	if event is InputEventJoypadMotion and absf(event.axis_value) >= BIND_THRESHOLD:
		for axis_name in PAD_AXES:
			if PAD_AXES[axis_name][0] == event.axis and PAD_AXES[axis_name][1] == signf(event.axis_value):
				return "Pad " + axis_name
	return ""


## An input event for a stored key name ("W", "Mouse Left", "Pad A"), or null for "".
## Controller buttons listen to controller number "device" only (-1 = every controller).
## (Seats uses this to give each couch player their own controls.)
func event_for(key_name: String, device: int = -1) -> InputEvent:
	var event := _event_from_name(key_name)
	if event != null and _is_pad_name(key_name):
		event.device = device
	return event


## True for the controller slot of the KEYS menu (slot 2), false for the keyboard slots.
func is_pad_slot(slot: int) -> bool:
	return slot == PAD_SLOT


# --- Rumble ---

## Shake the controller (only while the player is using one, and RUMBLE is ON in SETTINGS > CONTROLS).
## weak = the light, buzzy motor, strong = the heavy one (0..1 each), for this many seconds.
func rumble(weak: float, strong: float, seconds: float) -> void:
	if using_pad and Settings.rumble:
		Input.start_joy_vibration(pad_device, weak, strong, seconds)


# --- Changing the keys (used by the KEYS menu) ---

## Put a key in one slot of an action, apply and save. If another control that's used at
## the same time already had this key, it loses it; returns that control's menu label
## (so the menu can say "taken from JUMP"), or "".
## (Keyboard keys only compete with keyboard keys, controller buttons with controller buttons.)
func set_binding(action: String, slot: int, key_name: String) -> String:
	var taken_from := ""
	if key_name != "":
		var context: String = _context_of(action)
		var same_kind: Array = [PAD_SLOT] if is_pad_slot(slot) else range(SLOTS)
		for entry in ACTIONS:
			if not _contexts_clash(context, entry.context):
				continue
			for other_slot in same_kind:
				if (entry.action != action or other_slot != slot) and bindings[entry.action][other_slot] == key_name:
					bindings[entry.action][other_slot] = ""
					if entry.action != action:
						taken_from = entry.label
	bindings[action][slot] = key_name
	apply()
	_save()
	return taken_from


## Every key (and controller button) back to the defaults in ACTIONS.
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
		InputMap.action_set_deadzone(action, STICK_DEADZONE)
		InputMap.action_erase_events(action)
		for key_name in bindings[action]:
			var event := _event_from_name(key_name)
			if event != null:
				InputMap.action_add_event(action, event)
	changed.emit()


# --- Inner workings ---

## Player 1 touched something (scripts/seats.gd sends only player 1's events here):
## keyboard / mouse = using_pad off, a controller press or a real stick push = on.
func notice_device(event: InputEvent) -> void:
	var pad := false
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) < 0.5:
			return  # a resting / drifting stick doesn't count
		pad = true
	elif event is InputEventMouseMotion:
		if event.relative.length() < 4.0:
			return  # a bumped desk doesn't count
	elif not (event is InputEventKey or event is InputEventMouseButton):
		return
	if pad:
		pad_device = event.device
	if pad != using_pad:
		using_pad = pad
		changed.emit()  # prompts switch between "E" and "X"


## Is the controller in use a PlayStation one? (Its name, as Windows reports it.)
func _is_playstation() -> bool:
	var pad_name := Input.get_joy_name(pad_device).to_lower()
	return pad_name.contains("ps") or pad_name.contains("dualsense") or pad_name.contains("dualshock") \
		or pad_name.contains("playstation") or pad_name.contains("sony")


func _is_pad_name(key_name: String) -> bool:
	return key_name.begins_with("Pad ")


## Add the FIXED controls to Godot's Input Map (once, at startup).
func _add_fixed_actions() -> void:
	for action in FIXED:
		if not InputMap.has_action(action):
			InputMap.add_action(action, STICK_DEADZONE)
		for key_name in FIXED[action]:
			var event := _event_from_name(key_name)
			if event != null and not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


func _use_defaults() -> void:
	for entry in ACTIONS:
		var keys: Array = entry["keys"].duplicate()
		keys.resize(SLOTS)
		for i in SLOTS:
			if keys[i] == null:
				keys[i] = ""
		keys.append(entry.get("pad", ""))  # slot 2 = the controller
		bindings[entry.action] = keys


## Key name -> an input event Godot can match, or null for "" / unknown names.
func _event_from_name(key_name: String) -> InputEvent:
	if key_name == "":
		return null
	if _is_pad_name(key_name):
		var button := key_name.trim_prefix("Pad ")
		for index in PAD_BUTTONS:
			if PAD_BUTTONS[index] == button:
				var press := InputEventJoypadButton.new()
				press.button_index = index
				press.device = -1  # any controller
				return press
		if PAD_AXES.has(button):
			var motion := InputEventJoypadMotion.new()
			motion.axis = PAD_AXES[button][0]
			motion.axis_value = PAD_AXES[button][1]
			motion.device = -1
			return motion
		return null
	for mouse_button in MOUSE_NAMES:
		if MOUSE_NAMES[mouse_button] == key_name:
			var click := InputEventMouseButton.new()
			click.button_index = mouse_button
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
		config.set_value("keys", action, bindings[action].slice(0, SLOTS))
		config.set_value("pad", action, bindings[action][PAD_SLOT])
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return  # first time playing: keep the defaults
	for action in bindings:
		var saved: Variant = config.get_value("keys", action, null)
		if saved is Array and saved.size() == SLOTS and saved.all(func(k): return k is String):  # ignore broken / old values
			for i in SLOTS:
				bindings[action][i] = saved[i]
		# (Files saved before controller support have no [pad] section: the default stays.)
		var pad: Variant = config.get_value("pad", action, null)
		if pad is String and (pad == "" or _is_pad_name(pad)):
			bindings[action][PAD_SLOT] = pad
