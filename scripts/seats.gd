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
## JOINING: press START on a controller nobody has claimed
##   - in the start menu's SOLO / MULTIPLAYER (or HOST / JOIN) screen = the COUCH LOBBY: the new
##     player picks one of your saved cats with left / right (or NEW CAT), B = leave again. When the
##     game starts (solo, host or join) they all come along (start_lobby_players).
##   - during a game = drop in straight away, playing your next saved cat nobody is using (a new
##     one called "PLAYER 2" is made if there isn't one). They leave again with their own pause
##     menu's DROP OUT (that drops only them, not the whole computer).
## Two players never play the same cat (each cat has its own cash and stash).
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
## Each player's colour: the frame + "P2" tag around their split screen. Change them here.
const SEAT_COLORS: Array[Color] = [Color(1, 0.35, 0.8), Color(0.3, 0.9, 1), Color(1, 0.85, 0.3), Color(0.45, 1, 0.45)]

## The controller (Godot device number) of each seat, -1 = none yet.
var pads: Array[int] = []
## Which seats have a player right now. Seat 0 is always taken during a game.
var taken: Array[bool] = []
## The controller last used in the start menu (that's player 1 holding it): START on it in the
## game means "pause", not "a new player joins".
var _menu_pad: int = -1
## A controller whose START is joining a new player right now (its press opens no menu).
var _joining: int = -1
## The couch lobby (start menu): seat -> the saved cat id they picked ("" = a NEW CAT, made
## when the game starts).
var lobby_cats := {}
## Seats whose controller is unplugged right now (seat -> true). Their pause menu is up until it's
## back (or until START on another free controller takes over the seat).
var _unplugged := {}
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
	lobby_cats.clear()
	_unplugged.clear()
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


# --- Each player's colour and own settings ---

## This player's colour (the frame around their split screen).
func color(seat: int) -> Color:
	return SEAT_COLORS[seat % SEAT_COLORS.size()]


## Right-stick camera speed for this player (1.0 = normal). Player 1's is SETTINGS > CONTROLS >
## STICK SPEED; couch players set theirs in their own pause menu, saved with their cat.
func stick_speed(seat: int) -> float:
	return Settings.stick_speed if seat == 0 else float(_player_settings(seat).get("stick_speed", 1.0))


## Does this player push the right stick up to look down?
func invert_stick_y(seat: int) -> bool:
	return Settings.invert_stick_y if seat == 0 else bool(_player_settings(seat).get("invert_stick_y", false))


## Does this player's controller rumble?
func rumble_on(seat: int) -> bool:
	return Settings.rumble if seat == 0 else bool(_player_settings(seat).get("rumble", true))


## Change one of a player's own settings ("stick_speed", "invert_stick_y", "rumble") and save it:
## player 1's into Settings, a couch player's onto the saved cat they play (so it follows them).
func set_player_setting(seat: int, key: String, value: Variant) -> void:
	if seat == 0:
		Settings.set_value(key, value)
		return
	var cat := _saved_cat(seat)
	if cat.is_empty():
		return
	var own: Dictionary = cat.get("controls", {})
	own[key] = value
	cat["controls"] = own  # (changes the cat inside Settings.cats)
	Settings.save_settings()


## A couch player's own settings ({} = all normal), kept on their saved cat.
func _player_settings(seat: int) -> Dictionary:
	return _saved_cat(seat).get("controls", {})


## The saved cat (in Settings.cats) the player in this seat plays, or {}.
func _saved_cat(seat: int) -> Dictionary:
	if Game.instance == null:
		return {}
	var cat_id := str(Game.instance.local_player_info(seat).get("cat_id", ""))
	for cat in Settings.cats:
		if cat.get("id", "") == cat_id:
			return cat
	return {}


# --- Rumble ---

## Shake the controller of the player with this player ID (if they're on this computer, on a
## controller, and RUMBLE is ON). Same numbers as Controls.rumble.
func rumble(player_id: int, weak: float, strong: float, seconds: float) -> void:
	var seat := PlayerId.slot_of(player_id)
	if not PlayerId.is_local(player_id) or not rumble_on(seat):
		return
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
		if _in_lobby() and pressed_button and event.button_index == JOY_BUTTON_START and event.device != _menu_pad:
			_join_lobby(event.device)  # the couch lobby: a new player sits down
			return
		_menu_pad = event.device
		return  # in the start menu every other controller just works the menus
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
	# Someone's controller is unplugged? This new one takes over their seat (and cat).
	for lost in _unplugged.keys():
		pads[lost] = device
		_unplugged.erase(lost)
		_rebuild_actions()
		_resume_after_unplug(lost)
		Hud.show_message("PLAYER %d IS BACK (NEW CONTROLLER)" % (lost + 1), 3.0)
		print("[Seats] Controller %d took over player %d's seat" % [device, lost + 1])
		changed.emit()
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
	Hud.show_message("PLAYER %d JOINED AS %s!  (%s > DROP OUT to leave)" % [seat + 1, cat.get("name", ""), Controls.display_name("Pad Start")], 4.0)
	print("[Seats] Controller %d joined as player %d (%s)" % [device, seat + 1, cat.get("name", "")])
	changed.emit()


# --- The couch lobby (start menu) ---

## Is the start menu's SOLO / MULTIPLAYER or HOST / JOIN screen up (where couch players gather)?
func _in_lobby() -> bool:
	var game := Game.instance
	return game != null and is_instance_valid(game) and not game.pause_menu.enabled \
		and (game.main_menu.mode_screen.visible or game.main_menu.play_screen.visible)


## START on a free controller in the lobby: a new player sits down with the next free cat.
func _join_lobby(device: int) -> void:
	var seat := taken.find(false)
	if seat == -1:
		return  # 4 already
	if pads[0] == -1:
		pads[0] = _menu_pad if _menu_pad >= 0 else KEYBOARD_ONLY  # player 1 keeps the controller they used
	pads[seat] = device
	taken[seat] = true
	lobby_cats[seat] = ""
	lobby_cats[seat] = _lobby_choices(seat)[0]
	_rebuild_actions()
	print("[Seats] Controller %d sat down in the lobby as player %d" % [device, seat + 1])
	changed.emit()


## A lobby player picks the previous (-1) / next (+1) cat: one of your saved cats nobody else
## here picked, or NEW CAT ("").
func cycle_lobby_cat(seat: int, direction: int) -> void:
	if not lobby_cats.has(seat):
		return
	var choices := _lobby_choices(seat)
	var index := choices.find(lobby_cats[seat])
	lobby_cats[seat] = choices[posmod(index + direction, choices.size())]
	changed.emit()


## A lobby player stands up again (B).
func leave_lobby(seat: int) -> void:
	if not lobby_cats.has(seat):
		return
	lobby_cats.erase(seat)
	taken[seat] = false
	pads[seat] = -1
	if count() == 1 and pads[0] == KEYBOARD_ONLY:
		pads[0] = -1
	_rebuild_actions()
	changed.emit()


## The cats a lobby player can pick: saved, named, not player 1's, not another lobby player's.
## NEW CAT ("") is always last.
func _lobby_choices(seat: int) -> Array:
	var choices: Array = []
	for cat in Settings.cats:
		var id: String = cat.get("id", "")
		if id == Settings.current_cat_id or str(cat.get("name", "")) == "":
			continue
		var used := false
		for other in lobby_cats:
			used = used or (other != seat and lobby_cats[other] == id)
		if not used:
			choices.append(id)
	choices.append("")
	return choices


## The lobby, as text for the start menu: "P2 < WHISKERS >   P3 < NEW CAT >".
func lobby_text() -> String:
	var parts := PackedStringArray()
	for seat in range(1, PlayerId.MAX_LOCAL):
		if lobby_cats.has(seat):
			parts.append("P%d < %s >" % [seat + 1, _cat_name(lobby_cats[seat])])
	var start := Controls.display_name("Pad Start")
	if parts.is_empty():
		return "COUCH CO-OP: PRESS %s ON ANOTHER CONTROLLER" % start
	var lines := "   ".join(parts)
	if parts.size() < PlayerId.MAX_LOCAL - 1:
		lines += "   + %s" % start
	return lines + "\nLEFT / RIGHT = PICK CAT     %s = LEAVE" % Controls.display_name("Pad B")


func _cat_name(cat_id: String) -> String:
	for cat in Settings.cats:
		if cat.get("id", "") == cat_id:
			return str(cat.get("name", "")).to_upper()
	return "NEW CAT"


## game.gd, once we're in a game (solo, hosting or joined): every lobby player joins in with
## the cat they picked (a NEW CAT is made now, called "PLAYER 2" etc.).
func start_lobby_players() -> void:
	for seat in lobby_cats.keys():
		var cat_id: String = lobby_cats[seat]
		var cat: Dictionary = {}
		for saved in Settings.cats:
			if saved.get("id", "") == cat_id and cat_id != Settings.current_cat_id:
				cat = saved
		if cat.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			cat = Settings.new_cat(false, "PLAYER %d" % (seat + 1), CatLook.random_look(rng))
		Game.instance.add_local_player(seat, {"name": cat.get("name", ""), "look": cat.get("look", {}), "cat_id": cat.get("id", "")})
	lobby_cats.clear()


## The host said no (the game is full): that player stands up again.
func refused(seat: int) -> void:
	taken[seat] = false
	pads[seat] = -1
	if count() == 1 and pads[0] == KEYBOARD_ONLY:
		pads[0] = -1
	_rebuild_actions()
	Hud.show_message("THE GAME IS FULL (%d PLAYERS): PLAYER %d CAN'T JOIN" % [Net.MAX_PLAYERS, seat + 1], 4.0)
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


## A controller was unplugged / plugged in (or ran out of battery). Its player's game pauses
## (only theirs, in split screen) until it's back. They keep their seat: the same controller
## plugged back in carries on, or START on another free controller takes the seat over (_join).
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not _in_game():
		return
	var seat := pads.find(device)
	if seat == -1 and _seat0_takes_any_pad() and Controls.using_pad and device == Controls.pad_device:
		seat = 0  # player 1 alone, on the controller they were using
	if seat == -1:
		return
	if not connected:
		_unplugged[seat] = true
		Hud.show_message("PLAYER %d'S CONTROLLER IS UNPLUGGED" % (seat + 1), 3.0, seat)
		if PlayerPause.split_active():
			PlayerPause.for_seat(seat).open("PLAYER %d: CONTROLLER UNPLUGGED\nplug it back in, or press %s on another one" % [seat + 1, Controls.display_name("Pad Start")])
		elif not PauseMenu.is_open:
			Game.instance.pause_menu.opened_by = seat
			Game.instance.pause_menu.open()
	elif _unplugged.has(seat):
		_unplugged.erase(seat)
		Hud.show_message("PLAYER %d'S CONTROLLER IS BACK" % (seat + 1), 3.0, seat)
		_resume_after_unplug(seat)
	print("[Seats] Controller %d (player %d) %s" % [device, seat + 1, "plugged back in" if connected else "unplugged"])


## Close the pause menu that opened because this player's controller was unplugged.
func _resume_after_unplug(seat: int) -> void:
	var menu := PlayerPause.for_seat(seat)
	if menu != null:
		menu.close_unplug_pause()


## Is this player's controller unplugged right now?
func is_unplugged(seat: int) -> bool:
	return _unplugged.has(seat)


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
