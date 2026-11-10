class_name Spectator
extends Node
## CYPURRPUNK — THE CAT-CAM: spectating your crew after a knockout or an early extract.
## Attach to the "Spectator" node under Main (scenes/main.tscn).
##
## Nobody should sit staring at a sewer wall while their friends finish the raid. So:
##   - KNOCKED OUT up top? Once you wake up in the sewer, the screen switches to a teammate who's
##     still up there (after Knockout Spectate Delay seconds), looking over their shoulder.
##   - In the sewer, walk up to the CAT-CAM TV (next to the litterbox side, across from the
##     Mainframe: hub.gd _build_catcam) and press E: "[E] WATCH CREW UP TOP".
##   - Already had your trip up this district? Just press JUMP in the sewer to watch.
##
## While you watch (each player on the couch watches on their OWN screen):
##   LEFT / RIGHT (A / D, the left stick)   = the next / previous cat up top
##   MEOW (M / pad B)                       = HECKLE over the walkie-talkie: your cat's voice and
##                                            a line like "WHISKERS (RADIO): BEHIND YOU!" types out
##                                            over the watched cat's head, in the city, for
##                                            everyone. VAC-COPs nearby hear the squawk too!
##   E or JUMP                              = back to your own cat in the sewer (shop, stash, feed
##                                            the Mainframe), any time
## Your cat stands still in the sewer while you watch (cat_player.gd _menu_open).
## Watching stops by itself when nobody is left up top, or when a SEWER BREACH siren starts.
##
## WHO YOU CAN WATCH: co-op = every teammate up top. TURF WAR = your own gang while any of them are
## up top; once your whole gang is home, the RIVAL gang's cats.
##
## THE CAMERA: a camera of our own (one per player on this computer) copies the watched cat's
## camera every frame. Every cat shares where its camera points (cat_player.gd sync_camera_yaw /
## sync_camera_pitch), so you see exactly what they see, even online. In a car (driving or riding)
## it's the car's chase camera. game_screen.gd shows it (camera_for), with the city's fog, rain,
## moon and music.
##
## Nothing here changes the game except the heckle (an RPC everyone runs; only the host lets the
## bots hear it), so this works the same on every computer.
##
## Test (DevCapture): --add_local=1 --spectate[=SEAT] [--heckle] [--spectate_exit=F]

## The one Spectator (Spectator.instance).
static var instance: Spectator

@export_group("Entering")
## After a knockout up top: once you're back in the sewer, wait this long (seconds) before the
## screen switches to a teammate.
@export var knockout_spectate_delay: float = 1.5
## Give up on switching after a knockout if you haven't made it back to the sewer by then (seconds).
@export var knockout_spectate_timeout: float = 20.0
## Right after you start (or stop) watching, buttons are ignored this long (seconds), so the same
## E / JUMP press doesn't switch you straight back.
@export var button_grace_seconds: float = 0.35
## Already had your trip up this district: pressing JUMP in the sewer starts watching.
@export var jump_to_watch_after_trip: bool = true

@export_group("Heckle (MEOW while watching)")
## Shortest time between two heckles from the same player (seconds).
@export var heckle_cooldown: float = 3.0
## What your cat yells over the walkie-talkie (one picked at random). Shown as
## "<YOUR NAME> (RADIO): <LINE>" over the cat you're watching.
@export var heckle_lines: PackedStringArray = PackedStringArray([
	"FASTER, FURBALL!",
	"BEHIND YOU!",
	"DON'T DROP THE FISH!",
	"RUN, YOU MANIAC!",
	"BRING ME BACK A SARDINE!",
	"OH LAWD THEY COMIN'!",
])
## VAC-COPs within this many metres of the watched cat hear the radio squawk and come to look.
@export var heckle_heard_from: float = 18.0
## The colour of the radio line.
@export var heckle_color: Color = Color(0.55, 1.0, 0.75)
## How high over the watched cat the line floats (metres; their own MEOW line is at about 1.15,
## their name at 1.45, so this sits above both). In a car it's higher (Car Height).
@export var heckle_height: float = 1.9
@export var heckle_car_height: float = 2.4
## How long the line stays up after it has typed out (seconds).
@export var heckle_hold_seconds: float = 2.0
## How fast it types (letters per second).
@export var heckle_letters_per_second: float = 18.0
## The radio click / squawk (sounds/sfx/radio_squawk.wav) and how loud it is (decibels).
@export var heckle_sound: String = "radio_squawk"
@export var heckle_sound_db: float = -4.0

## Who each player on this computer is watching: seat -> player id (no entry = not watching).
var watching := {}
## Each watching seat's camera (made the first time they watch).
var _cameras := {}
## Seats knocked out up top, waiting to start watching: seat -> {"since": time, "home_at": time}.
var _after_knockout := {}
## Buttons are ignored until this time, per seat (button_grace_seconds).
var _ignore_until := {}
## Next time each seat may heckle.
var _next_heckle_at := {}
## The radio lines floating over cats: player id -> FloatingLine.
var _radio_lines := {}
## TESTS: how many heckles reached this computer (DevCapture prints it).
var heckles_seen: int = 0
var last_heckle_text: String = ""
var last_heckle_heard: int = -1  # host: how many VAC-COPs heard the last heckle


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	add_to_group(GameSystems.GROUP)
	process_priority = 50  # after the cats moved (their cameras), before GameScreen (100) shows us
	Events.player_knocked_out.connect(_on_knocked_out)


## Is this player on THIS computer (seat 0..3) watching someone right now?
static func is_watching(seat: int) -> bool:
	return instance != null and instance.watching.has(seat)


## The camera this cat's player should look through instead of their own, or null.
## (game_screen.gd asks every frame, after Mainframe.feed_camera_for.)
func camera_for(cat: CatPlayer) -> Camera3D:
	if cat == null or not cat.is_multiplayer_authority() or not watching.has(cat.slot):
		return null
	return _cameras.get(cat.slot)


## The cat this seat is watching, or null.
func watched_cat(seat: int) -> CatPlayer:
	if not watching.has(seat) or Game.instance == null:
		return null
	return Game.instance.cat_for(watching[seat])


# --- Who can watch, and who ---

## Every cat "me" may watch right now, in join order (see WHO YOU CAN WATCH at the top).
func watchable_for(me: CatPlayer) -> Array[CatPlayer]:
	var game := Game.instance
	var mates: Array[CatPlayer] = []
	var rivals: Array[CatPlayer] = []
	if game == null or me == null:
		return mates
	for node in game.players.get_children():
		var other := node as CatPlayer
		if other == null or other == me or other.is_queued_for_deletion() or not game.is_up_top(other.player_id):
			continue
		if _knocked_out(other):
			continue  # flat on the street, on their way home: nothing to watch
		if not Game.is_turf_war() or other.team == me.team:
			mates.append(other)
		else:
			rivals.append(other)
	return mates if not mates.is_empty() else rivals


## Knocked out (not just DOWNED, where a friend can still pick them up).
func _knocked_out(cat: CatPlayer) -> bool:
	var health := CatHealth.instance
	return cat.knocked_out or (health != null and health.is_down(cat.player_id) and not health.is_downed(cat.player_id))


## May this cat's player watch at all right now? (In the sewer, no breach or siren, no talk box /
## inventory open, not lying knocked out, and somebody to watch.)
func can_spectate(me: CatPlayer) -> bool:
	if me == null or not me.reads_input() or Game.instance.is_up_top(me.player_id) or me.knocked_out:
		return false
	var mainframe := Mainframe.instance
	if mainframe != null and (mainframe.breach_busy or not mainframe.warning_teams.is_empty() or mainframe.is_spectating(me)):
		return false
	if Hud.wants_input(me.slot):
		return false
	return not watchable_for(me).is_empty()


# --- Starting and stopping ---

## Start watching for this seat (the first cat up top, or "who" if given). Returns false (and
## tells the player) if there's nobody to watch.
func start(seat: int, who: CatPlayer = null) -> bool:
	var me := _my_cat(seat)
	if me == null:
		return false
	var list := watchable_for(me)
	if list.is_empty() or not can_spectate(me):
		Hud.show_message("NOBODY UP TOP RIGHT NOW", 2.0, seat)
		return false
	if who == null or not who in list:
		who = list[0]
	if not _cameras.has(seat):
		var camera := Camera3D.new()
		camera.name = "SpectatorCamera%d" % (seat + 1)
		add_child(camera)
		# (Godot hands the picture to the first camera it meets. It must never be this one by itself.)
		if get_viewport().get_camera_3d() == camera:
			camera.clear_current(false)
		_cameras[seat] = camera
	watching[seat] = who.player_id
	_ignore_until[seat] = _now() + button_grace_seconds
	_after_knockout.erase(seat)
	_follow(seat)
	Sound.play("click")
	print("[Spectator] Seat %d is watching %s" % [seat, who.display_name()])
	return true


## Back to your own cat in the sewer.
func stop(seat: int) -> void:
	if not watching.has(seat):
		return
	watching.erase(seat)
	_ignore_until[seat] = _now() + button_grace_seconds
	print("[Spectator] Seat %d stopped watching" % seat)


## Host: a new game or a new district: everybody stops watching (on every computer).
func start_district() -> void:
	_stop_everyone.rpc()


@rpc("authority", "call_local", "reliable")
func _stop_everyone() -> void:
	for seat in watching.keys():
		stop(seat)
	_after_knockout.clear()


## Every computer: someone was knocked out. One of OUR players, up top (not the DEEP CLEAN's
## everybody-at-once wipe)? Watch a teammate once they're back in the sewer.
func _on_knocked_out(player_id: int, cause: String) -> void:
	if not PlayerId.is_local(player_id) or cause == "THE DEEP CLEAN":
		return
	if not Game.instance.is_up_top(player_id):
		return  # (knocked out in a breached sewer: the breach comes first)
	_after_knockout[PlayerId.slot_of(player_id)] = {"since": _now(), "home_at": -1.0}


# --- Every frame ---

func _process(_delta: float) -> void:
	var game := Game.instance
	if game == null or not is_instance_valid(game):
		return
	for seat in PlayerId.MAX_LOCAL:
		var me := _my_cat(seat)
		if me == null:
			watching.erase(seat)
			_after_knockout.erase(seat)
			continue
		if watching.has(seat):
			_watching_frame(seat, me)
		else:
			_waiting_frame(seat, me)
	_place_radio_lines()


## A seat that isn't watching: the after-knockout switch, and JUMP after your trip.
func _waiting_frame(seat: int, me: CatPlayer) -> void:
	if _after_knockout.has(seat):
		var wait: Dictionary = _after_knockout[seat]
		if _now() - wait.since > knockout_spectate_timeout:
			_after_knockout.erase(seat)
		elif not game_up_top(me) and not me.knocked_out:
			if wait.home_at < 0.0:
				wait.home_at = _now()  # just woke up in the sewer
			elif _now() - wait.home_at >= knockout_spectate_delay:
				_after_knockout.erase(seat)
				if can_spectate(me):
					start(seat)
		return
	if jump_to_watch_after_trip and _buttons_live(seat) and FishHeist.instance != null \
			and FishHeist.instance.has_been_up(me.player_id) and not me._menu_open() \
			and Seats.is_just_pressed(seat, "jump") and can_spectate(me):
		start(seat)


func game_up_top(cat: CatPlayer) -> bool:
	return Game.instance.is_up_top(cat.player_id)


## A seat that's watching: keep it allowed, switch away from a cat that left, read the buttons,
## move the camera.
func _watching_frame(seat: int, me: CatPlayer) -> void:
	var list := watchable_for(me)
	if list.is_empty() or not can_spectate(me):
		stop(seat)
		return
	var who := watched_cat(seat)
	if who == null or not who in list:
		# They extracted or got knocked out: on to the next one still up there.
		watching[seat] = list[0].player_id
	elif _buttons_live(seat) and not PauseMenu.is_open and not PlayerPause.is_open_for(seat):
		if Seats.is_just_pressed(seat, "interact") or Seats.is_just_pressed(seat, "jump"):
			stop(seat)
			return
		var step := 0
		if Seats.is_just_pressed(seat, "move_right"):
			step = 1
		elif Seats.is_just_pressed(seat, "move_left"):
			step = -1
		if step != 0 and list.size() > 1:
			watching[seat] = list[posmod(list.find(who) + step, list.size())].player_id
			Sound.play("click")
		if Seats.is_just_pressed(seat, "meow"):
			heckle(seat)
	_follow(seat)


## Point this seat's camera where the watched cat's camera is: over their shoulder on foot, the
## car's chase camera in a car.
func _follow(seat: int) -> void:
	var who := watched_cat(seat)
	var camera: Camera3D = _cameras.get(seat)
	if who == null or camera == null:
		return
	var car := Game.instance.car_of(who.player_id)
	if car != null:
		var arm := car.camera_arm
		camera.global_transform = arm.global_transform * Transform3D(Basis(), Vector3(0, 0, arm.get_hit_length()))
		camera.fov = Settings.field_of_view
	else:
		camera.global_transform = who.camera.global_transform
		camera.fov = who.camera.fov
	camera.near = who.camera.near
	camera.far = who.camera.far


# --- The heckle ---

## MEOW while watching: ask everyone to show our radio line over the watched cat.
func heckle(seat: int) -> void:
	var me := _my_cat(seat)
	var who := watched_cat(seat)
	if me == null or who == null or heckle_lines.is_empty() or _now() < float(_next_heckle_at.get(seat, 0.0)):
		return
	_next_heckle_at[seat] = _now() + heckle_cooldown
	_radio.rpc(me.player_id, who.player_id, randi() % heckle_lines.size())


## Every computer: "<NAME> (RADIO): <LINE>" types out over the watched cat, in the heckler's voice,
## with a squawk. The host lets the VAC-COPs nearby hear it.
@rpc("any_peer", "call_local", "reliable")
func _radio(from_id: int, to_id: int, line: int) -> void:
	if not PlayerId.sender_owns(from_id):
		return  # (only a player's own computer may heckle in their name)
	var game := Game.instance
	var from := game.cat_for(from_id)
	var to := game.cat_for(to_id)
	if from == null or to == null or heckle_lines.is_empty() or not game.is_up_top(to_id):
		return
	var text := "%s (RADIO): %s" % [from.display_name(), heckle_lines[line % heckle_lines.size()]]
	var label := _radio_line_for(to_id)
	_place_radio_line(to_id, label)
	label.say(text, heckle_color, -1.0, CatLook.voice_sound(from.look), from.voice_pitch(), heckle_hold_seconds)
	Sound.play_at(heckle_sound, label.global_position, heckle_sound_db)
	heckles_seen += 1
	last_heckle_text = text
	print("[Spectator] Radio over %s: %s" % [to.display_name(), text])
	if multiplayer.is_server() and RoombaPatrol.instance != null:
		last_heckle_heard = RoombaPatrol.instance.hear_noise(game.player_position(to_id), heckle_heard_from)
		print("[Spectator] %d VAC-COP(s) heard the radio" % last_heckle_heard)


## The floating radio line for this cat (made the first time someone heckles them).
func _radio_line_for(player_id: int) -> FloatingLine:
	var label: FloatingLine = _radio_lines.get(player_id)
	if label != null and is_instance_valid(label):
		return label
	label = FloatingLine.new()
	label.name = "RadioLine_%d" % player_id
	label.letters_per_second = heckle_letters_per_second
	label.wrap_at = 34
	label.readable_from = 35.0
	add_child(label)
	_radio_lines[player_id] = label
	return label


## Every frame: the radio lines ride along over their cats (or cars). Lines over cats that are
## gone are thrown away.
func _place_radio_lines() -> void:
	for player_id in _radio_lines.keys():
		var label: FloatingLine = _radio_lines[player_id]
		if not is_instance_valid(label) or Game.instance.cat_for(player_id) == null:
			if is_instance_valid(label):
				label.queue_free()
			_radio_lines.erase(player_id)
		elif label.is_talking():
			_place_radio_line(player_id, label)


func _place_radio_line(player_id: int, label: FloatingLine) -> void:
	var in_car := Game.instance.car_of(player_id) != null
	label.global_position = Game.instance.player_position(player_id) + Vector3.UP * (heckle_car_height if in_car else heckle_height)


# --- The HUD line ---

## The line at the top of a watching player's screen (fish_heist.gd _update_hud_for shows it).
## e.g. "WATCHING: MITTENS" and under it "[A/D] SWITCH   [M] HECKLE   [E] SEWERS" (two lines, so the
## top one fits between the health bar and the Mainframe bar)
func hud_text(seat: int) -> String:
	var who := watched_cat(seat)
	var me := _my_cat(seat)
	if who == null or me == null:
		return ""
	var parts: PackedStringArray = []
	if watchable_for(me).size() > 1:
		var keys := "STICK" if Seats.uses_pad(seat) else "%s/%s" % [Hud.key_for("move_left", seat), Hud.key_for("move_right", seat)]
		parts.append("[%s] SWITCH" % keys)
	parts.append("[%s] HECKLE" % Hud.key_for("meow", seat))
	parts.append("[%s] SEWERS" % Hud.key_for("interact", seat))
	return "WATCHING: %s\n%s" % [who.display_name(), "   ".join(parts)]


# --- Little helpers ---

func _my_cat(seat: int) -> CatPlayer:
	var game := Game.instance
	if game == null or multiplayer.multiplayer_peer == null:
		return null
	var cat := game.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat))
	return cat if cat != null and cat.reads_input() else null


func _buttons_live(seat: int) -> bool:
	return _now() >= float(_ignore_until.get(seat, 0.0))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
