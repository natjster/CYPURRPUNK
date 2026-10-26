extends Node
## MEOW-CITY 1999 — SEATS: which controller belongs to which player on THIS computer (couch co-op).
## Loaded automatically on startup (it's an Autoload named "Seats"), after Controls.
##
## A computer has up to 4 SEATS (PlayerId.MAX_LOCAL). Seat number = the player's slot
## (scripts/player_id.gd): seat 0 is the first player, seat 1 the second...
##   - Seat 0 always has the KEYBOARD + MOUSE, plus one controller.
##   - Every other seat has exactly one controller.
## While seat 0 plays alone, ANY controller drives it (like a normal single-player game); the
## first controller they use becomes theirs ("claimed").
##
## JOINING IN (until there's a proper split-screen lobby): during a game, press START on a
## controller nobody has claimed: a new player drops in, playing your next saved cat that nobody
## is using (MY CAT; a new one called "PLAYER 2" is made if there isn't one). They leave again with
## START > LEAVE GAME on their own controller (that drops only them, not the whole computer).
##
## HOW SCRIPTS READ A SEAT'S BUTTONS: every control in Controls.ACTIONS also exists once per seat,
## named "jump@0", "jump@1"... listening only to that seat's keys / controller. Use the helpers:
##   Seats.is_pressed(cat.slot, "jump")        Seats.is_just_pressed(cat.slot, "shoot")
##   Seats.get_vector(cat.slot, "move_left", "move_right", "move_forward", "move_back")
##   Seats.event_is(cat.slot, event, "interact")  (in _unhandled_input)
## The plain actions ("jump") still exist and react to EVERY device: menus use those.

## Fired when a player joins in or leaves, or a controller is claimed.
signal changed

## pads[0] value for "player 1 is on the keyboard; the other controllers belong to others".
const KEYBOARD_ONLY: int = -2

## The controller (Godot device number) of each seat, -1 = none yet.
var pads: Array[int] = []
## Which seats have a player right now. Seat 0 is always taken during a game.
var taken: Array[bool] = []
## The controller last used in the start menu (that's player 1 holding it): START on it in the
## game means "pause", not "a new player joins".
var _menu_pad: int = -1
## A controller whose START is joining a new player right now (its press opens no menu).
var _joining: int = -1
## What the per-seat controls were last built from, so they're only rebuilt when something
## really changed (rebuilding lets go of every button being held, e.g. the gas trigger).
var _built_from: String = ""


func _ready() -> void:
	reset()
	Controls.changed.connect(_rebuild_actions)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	get_tree().root.window_input.connect(_on_window_input)


## Back to one player with no claimed controller (a new game / back to the start menu).
func reset() -> void:
	pads.clear()
	taken.clear()
	for seat in PlayerId.MAX_LOCAL:
		pads.append(-1)
		taken.append(seat == 0)
	_rebuild_actions()


# --- Reading a seat's buttons ---

## The per-seat name of a control: action("jump", 1) -> "jump@1".
func action(seat: int, action_name: String) -> String:
	return "%s@%d" % [action_name, seat]


func is_pressed(seat: int, action_name: String) -> bool:
	return Input.is_action_pressed(action(seat, action_name))


func is_just_pressed(seat: int, action_name: String) -> bool:
	return Input.is_action_just_pressed(action(seat, action_name))


func get_axis(seat: int, negative: String, positive: String) -> float:
	return Input.get_axis(action(seat, negative), action(seat, positive))


func get_vector(seat: int, left: String, right: String, up: String, down: String) -> Vector2:
	return Input.get_vector(action(seat, left), action(seat, right), action(seat, up), action(seat, down))


## Is this input event "action_name" pressed by THIS seat? (For _unhandled_input.)
func event_is(seat: int, event: InputEvent, action_name: String) -> bool:
	return event.is_action_pressed(action(seat, action_name))


## Which seat an input event belongs to: 0 for keyboard / mouse, the seat whose controller it is,
## or -1 for a controller nobody has claimed (while more than one player is in).
func seat_of_event(event: InputEvent) -> int:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return 0
	if event.device == _joining:
		return -1
	var seat := pads.find(event.device)
	if seat != -1:
		return seat
	return 0 if _seat0_takes_any_pad() else -1


## Is this seat on a controller right now? (Seat 0 only when its player last touched one.)
func uses_pad(seat: int) -> bool:
	return seat > 0 or Controls.using_pad


## How many players this computer has right now.
func count() -> int:
	return taken.count(true)


# --- Rumble ---

## Shake the controller of the player with this player ID (if they're on this computer, on a
## controller, and RUMBLE is ON). Same numbers as Controls.rumble.
func rumble(player_id: int, weak: float, strong: float, seconds: float) -> void:
	if not PlayerId.is_local(player_id) or not Settings.rumble:
		return
	var seat := PlayerId.slot_of(player_id)
	if seat == 0:
		if Controls.using_pad:
			Input.start_joy_vibration(pads[0] if pads[0] >= 0 else Controls.pad_device, weak, strong, seconds)
	elif pads[seat] >= 0:
		Input.start_joy_vibration(pads[seat], weak, strong, seconds)


# --- Joining in and leaving ---

## A player in seat 1-3 leaves (their pause menu's LEAVE GAME). Seat 0 leaves the whole game instead.
func leave(seat: int) -> void:
	if seat <= 0 or not taken[seat]:
		return
	var who := str(Game.instance.local_player_info(seat).get("name", "PLAYER %d" % (seat + 1)))
	Game.instance.remove_local_player(seat)
	taken[seat] = false
	pads[seat] = -1
	if count() == 1 and pads[0] == KEYBOARD_ONLY:
		pads[0] = -1  # alone again: any controller drives player 1 once more
	_rebuild_actions()
	Hud.show_message("PLAYER %d (%s) LEFT" % [seat + 1, who], 3.0)
	changed.emit()


## Every controller press passes through here first (before menus and cats).
## START on a controller nobody has = join in. Anything else on it, while player 1 has no
## controller yet and plays alone = it becomes player 1's.
func _on_window_input(event: InputEvent) -> void:
	var pressed_button: bool = event is InputEventJoypadButton and event.pressed
	var pushed_stick: bool = event is InputEventJoypadMotion and absf(event.axis_value) >= 0.5
	if not (pressed_button or pushed_stick) or pads.has(event.device):
		return
	if not _in_game():
		_menu_pad = event.device
		return  # in the start menu every controller just works the menus
	var players_own: bool = _seat0_takes_any_pad() and event.device == _menu_pad
	if pressed_button and event.button_index == JOY_BUTTON_START and not players_own:
		# Deferred: this START must not also open the pause menu (the pause menu ignores
		# controllers nobody has claimed, and this one isn't claimed until after this event).
		_joining = event.device
		_join.call_deferred(event.device)
	elif _seat0_takes_any_pad():
		# Player 1 picked up a controller: it's theirs now. (No rebuild needed: while they play
		# alone their controls already listen to every controller.)
		pads[0] = event.device
		changed.emit()


## A new player drops in on controller "device".
func _join(device: int) -> void:
	_joining = -1
	if pads.has(device) or not _in_game():
		return
	var seat := -1
	for free in range(1, PlayerId.MAX_LOCAL):
		if not taken[free] and not Game.instance.extra_local_players.has(free):
			seat = free
			break
	if seat == -1:
		Hud.show_message("%d PLAYERS IS THE MOST ON ONE COMPUTER" % PlayerId.MAX_LOCAL, 3.0)
		return
	if pads[0] == -1:
		pads[0] = KEYBOARD_ONLY  # player 1 never picked up a controller: other ones aren't theirs now
	var cat := _cat_for_new_player(seat)
	pads[seat] = device
	taken[seat] = true
	_rebuild_actions()
	Game.instance.add_local_player(seat, {"name": cat.get("name", ""), "look": cat.get("look", {}), "cat_id": cat.get("id", "")})
	Hud.show_message("PLAYER %d JOINED AS %s!  (%s > LEAVE GAME to drop out)" % [seat + 1, cat.get("name", ""), Controls.display_name("Pad Start")], 4.0)
	print("[Seats] Controller %d joined as player %d (%s)" % [device, seat + 1, cat.get("name", "")])
	changed.emit()


## The saved cat a drop-in player plays: the next one in MY CAT that nobody here is playing,
## or a brand-new one ("PLAYER 2") if they're all taken.
func _cat_for_new_player(seat: int) -> Dictionary:
	var in_use: Array = [Settings.current_cat_id]
	for other in range(1, PlayerId.MAX_LOCAL):
		if taken[other]:
			in_use.append(str(Game.instance.local_player_info(other).get("cat_id", "")))
	var start := maxi(Settings.cats.find(Settings.current_cat()), 0)
	for i in Settings.cats.size():
		var cat: Dictionary = Settings.cats[(start + 1 + i) % Settings.cats.size()]
		if not cat.get("id", "") in in_use and str(cat.get("name", "")) != "":
			return cat
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return Settings.new_cat(false, "PLAYER %d" % (seat + 1), CatLook.random_look(rng))


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	var seat := pads.find(device)
	if seat != -1 and _in_game():
		# The player keeps their seat: plugging the same controller back in carries on.
		Hud.show_message("PLAYER %d'S CONTROLLER %s" % [seat + 1, "IS BACK" if connected else "DISCONNECTED"], 3.0)


# --- Inner workings ---

## Player 1 alone and without a controller of their own: any controller drives them.
func _seat0_takes_any_pad() -> bool:
	return pads[0] == -1 and count() <= 1


func _in_game() -> bool:
	return Game.instance != null and is_instance_valid(Game.instance) and Game.instance.pause_menu.enabled \
		and Game.instance.my_cat() != null


## Make the per-seat copies of every control ("jump@0".."jump@3") from the player's keys
## (Controls.bindings) and each seat's controller.
func _rebuild_actions() -> void:
	if pads.is_empty():
		return  # not set up yet
	var devices: Array[int] = []
	for seat in PlayerId.MAX_LOCAL:
		devices.append(-1 if seat == 0 and (count() <= 1 or pads[0] == -1) else pads[seat])  # -1 = every controller
	var recipe := str(Controls.bindings) + str(devices)
	if recipe == _built_from:
		return  # nothing changed (e.g. Controls.changed because they switched keyboard <-> controller)
	_built_from = recipe
	for seat in PlayerId.MAX_LOCAL:
		var device := devices[seat]
		for entry in Controls.ACTIONS:
			var seat_action := action(seat, entry.action)
			if not InputMap.has_action(seat_action):
				InputMap.add_action(seat_action, Controls.STICK_DEADZONE)
			InputMap.action_erase_events(seat_action)
			var names: Array = Controls.bindings[entry.action]
			if seat == 0:
				for slot in Controls.SLOTS:  # the keyboard + mouse belong to seat 0
					var key := Controls.event_for(names[slot])
					if key != null:
						InputMap.action_add_event(seat_action, key)
			if device >= 0 or device == -1 and seat == 0:
				var pad := Controls.event_for(names[Controls.PAD_SLOT], device)
				if pad != null:
					InputMap.action_add_event(seat_action, pad)
