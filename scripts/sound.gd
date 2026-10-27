extends Node
## MEOW-CITY 1999 — every sound in the game goes through here (an Autoload named "Sound").
##
## ADDING / SWAPPING A SOUND needs no code: drop a .wav, .ogg or .mp3 file into one of these
## folders and it's picked up by its file name the next time the game starts:
##   res://sounds/sfx/       one-off effects (gunshots, pickups...)  -> SFX volume slider
##   res://sounds/ambience/  background loops (rain, sewer drips)    -> SFX volume slider
##   res://sounds/music/     music loops (one per area)              -> MUSIC volume slider
## The sound's name is the file name without the extension: sfx/shoot.wav is "shoot".
## Several versions of one sound? Number them: meow_1.wav, meow_2.wav... are all "meow",
## and a random one plays each time (great for footsteps and meows).
## To replace a placeholder, just overwrite the file with your own (same name).
##
## Scripts play sounds like this:
##   Sound.play("buy")                         - plain, not in 3D (menus, "you got hurt")
##   Sound.play_at("shoot", where)             - from a spot in the world, only on THIS computer
##   Sound.play_everywhere("bonk", where)      - from a spot, on EVERY player's computer
##   Sound.attach_loop("engine_loop", node)    - a sound that loops forever, riding along on a node
##   Sound.play_music("city") / Sound.play_ambience("rain")   - fades over from what was playing
## Asking for a sound that has no file yet is fine: nothing plays (a note is printed once).
##
## Test runs: add --sound_log to print every sound that plays ("[Sound] ..." lines).

## How much each play's pitch is randomly nudged (0.08 = up to 8% higher or lower), so sounds
## that repeat a lot don't sound robotic. 0 = always exactly the same.
const PITCH_VARIATION: float = 0.08
## 3D sounds: how far away (metres) they can still be heard at all.
const HEARING_RANGE: float = 45.0
## 3D sounds: bigger = stays loud further away.
const LOUDNESS_SIZE: float = 6.0
## How many one-off sounds may play at once (the oldest ones keep playing; new ones are skipped).
const MAX_VOICES: int = 32
## Seconds music and ambience take to fade from one track to the next.
const FADE_SECONDS: float = 2.0
## PS1 muffle: everything above this pitch (Hz) is softened, like a cheap TV speaker.
## Higher = brighter. 0 = off. (Added to the SFX and Music buses.)
const RETRO_CUTOFF_HZ: float = 7000.0
## How loud music and ambience play, in decibels (0 = full file volume, -6 = about half).
const MUSIC_DB: float = -8.0
const AMBIENCE_DB: float = -10.0

## Which bus (volume slider) each folder plays on. See Settings.BUSES.
const FOLDERS: Dictionary = {"sfx": "SFX", "ambience": "SFX", "music": "Music"}

## {"sfx": {"meow": [stream, stream]}, "music": {...}, ...} — filled from the folders.
var _sounds: Dictionary = {}
## Looping copies of streams (made once each, see _looping).
var _loop_copies: Dictionary = {}
## Names we already said "no file for that" about (so it's said once, not every frame).
var _missing: Dictionary = {}
## What is playing on each background channel: {"music": [id, player], "ambience": [...]}.
var _channels: Dictionary = {}
var _voices: int = 0
var _log: bool = false
var _rng := RandomNumberGenerator.new()  # pitch nudges only — NOT the city's RNG
## Looping sounds made by attach_loop (e.g. the car engine): placed every frame for the nearest
## player's ears (_process).
var _loops: Array[AudioStreamPlayer3D] = []
## What every button runs when pressed (see _on_node_added).
var _click: Callable = play.bind("click", -4.0)


func _ready() -> void:
	_rng.randomize()
	_log = "--sound_log" in OS.get_cmdline_user_args()
	for folder in FOLDERS:
		_sounds[folder] = _load_folder("res://sounds/%s/" % folder)
	_add_retro_filter()
	# Every button in every menu clicks when pressed (sfx/click.wav). Catches buttons made later too.
	get_tree().node_added.connect(_on_node_added)


# --- Playing sounds ---

## Play a sound that isn't anywhere in the world (menus, "you got hurt", "SOLD!").
func play(id: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	var stream := _pick("sfx", id)
	if stream == null or _voices >= MAX_VOICES:
		return null
	var player := AudioStreamPlayer.new()
	_setup_one_shot(player, stream, volume_db)
	add_child(player)
	player.play()
	_say("%s" % id)
	return player


## Play a sound coming from a spot in the world, on THIS computer only. Louder when the camera
## is close, quieter far away, and from the left/right speaker depending on where it is.
## Split screen: the game can only listen from ONE camera (player 1's), so a sound that's closer
## to another player on this computer is moved to where it would be for player 1's ears if they
## stood where that player stands (hearing_position): player 2 hears their own fish pickup.
## Use this when every computer already runs the code that makes the sound (e.g. a gunshot
## that's drawn on every screen). Otherwise use play_everywhere.
func play_at(id: String, where: Vector3, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var stream := _pick("sfx", id)
	if stream == null or _voices >= MAX_VOICES:
		return null
	var player := _make_3d_player(stream, volume_db)
	_setup_one_shot(player, stream, volume_db)
	add_child(player)
	player.global_position = hearing_position(where)
	player.play()
	_say("%s at %s%s" % [id, where.snapped(Vector3.ONE * 0.1), _heard_by_note(where)])
	return player


## Play a sound from a spot in the world on EVERY player's computer (including this one).
## Use it for things only one computer knows happened, e.g. the host deciding a Roomba bonked.
func play_everywhere(id: String, where: Vector3, volume_db: float = 0.0) -> void:
	if multiplayer.multiplayer_peer == null:
		play_at(id, where, volume_db)
	else:
		_play_everywhere.rpc(id, where, volume_db)


@rpc("any_peer", "call_local", "unreliable")
func _play_everywhere(id: String, where: Vector3, volume_db: float) -> void:
	play_at(id, where, volume_db)


## Start a sound that loops forever, riding along on "on" (e.g. the car's engine). Returns the
## player so the caller can change its pitch_scale / volume_db as things speed up, or null if
## there's no such sound file. It's freed together with "on".
func attach_loop(id: String, on: Node3D, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var stream := _pick("sfx", id)
	if stream == null:
		return null
	var player := _make_3d_player(_looping(stream), volume_db)
	player.name = "Sound_" + id
	on.add_child(player)
	# It rides along with "on", placed every frame where the nearest player on this computer
	# would hear it (split screen: see hearing_position / _process).
	player.top_level = true
	player.global_position = hearing_position(on.global_position)
	_loops.append(player)
	player.play()
	return player


## Every frame: looping sounds follow what they're attached to, placed for the nearest
## player's ears (split screen). Ones whose owner is gone are forgotten.
func _process(_delta: float) -> void:
	for i in range(_loops.size() - 1, -1, -1):
		var player := _loops[i]
		if not is_instance_valid(player) or not player.is_inside_tree():
			_loops.remove_at(i)
			continue
		player.global_position = hearing_position((player.get_parent() as Node3D).global_position)


## Where a sound at "where" should play so the nearest player on THIS computer hears it right.
## Normally just "where". Split screen: if another player's camera is closer to it than player
## 1's (whose camera is the game's only pair of ears), the sound is moved to the same distance
## and direction from player 1's camera as it really is from that player's camera.
func hearing_position(where: Vector3) -> Vector3:
	var screen := GameScreen.instance
	if screen == null or not is_instance_valid(screen) or not screen.is_node_ready():
		return where  # (still starting up)
	var cameras := screen.view_cameras()  # [player 1's (the ears), then players 2-4's]
	if cameras.size() < 2:
		return where
	var nearest: Camera3D = cameras[0]
	for camera in cameras:
		if camera.global_position.distance_to(where) < nearest.global_position.distance_to(where):
			nearest = camera
	if nearest == cameras[0]:
		return where
	return cameras[0].global_transform * (nearest.global_transform.affine_inverse() * where)


## For --sound_log: "(heard from another player's spot, 3 m away)" when hearing_position moved it.
func _heard_by_note(where: Vector3) -> String:
	if not _log:
		return ""
	var moved := hearing_position(where)
	if moved.is_equal_approx(where):
		return ""
	var ears := GameScreen.instance.view_cameras()[0]
	return " (moved to another player's ears: %.1f m away)" % ears.global_position.distance_to(moved)


## Fade over to this music track (a file in sounds/music/). "" = fade to silence.
## Calling it again with the track that's already playing does nothing, so it's fine to call
## every frame.
func play_music(id: String) -> void:
	_crossfade("music", id, MUSIC_DB)


## Fade over to this background loop (a file in sounds/ambience/). "" = fade to silence.
func play_ambience(id: String) -> void:
	_crossfade("ambience", id, AMBIENCE_DB)


## True if there's a file for this sound effect (handy for tests).
func has_sound(id: String) -> bool:
	return _sounds["sfx"].has(id)


# --- Behind the scenes ---

## Read every sound file in a folder: {"meow": [meow_1, meow_2], "shoot": [shoot]}.
func _load_folder(path: String) -> Dictionary:
	var found := {}
	if not DirAccess.dir_exists_absolute(path):
		return found
	# list_directory also works in the exported game (where the raw files are packed away).
	for file in ResourceLoader.list_directory(path):
		if file.ends_with("/") or not file.get_extension().to_lower() in ["wav", "ogg", "mp3"]:
			continue
		var stream := load(path + file) as AudioStream
		if stream == null:
			continue
		# "meow_2.wav" -> "meow" (a numbered version), "engine_loop.wav" -> "engine_loop".
		var id := file.get_basename()
		var cut := id.rfind("_")
		if cut > 0 and id.substr(cut + 1).is_valid_int():
			id = id.left(cut)
		if not found.has(id):
			found[id] = []
		found[id].append(stream)
	return found


## A random version of a sound, or null (and a one-time note) if it has no file yet.
func _pick(folder: String, id: String) -> AudioStream:
	var versions: Array = _sounds.get(folder, {}).get(id, [])
	if versions.is_empty():
		if not _missing.has(folder + id) and OS.is_debug_build():
			_missing[folder + id] = true
			print("[Sound] No file for '%s' yet (add sounds/%s/%s.wav to hear it)" % [id, folder, id])
		return null
	return versions[_rng.randi() % versions.size()]


func _setup_one_shot(player: Node, stream: AudioStream, volume_db: float) -> void:
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "SFX"
	player.pitch_scale = 1.0 + _rng.randf_range(-PITCH_VARIATION, PITCH_VARIATION)
	_voices += 1
	player.finished.connect(_on_one_shot_finished.bind(player))


func _on_one_shot_finished(player: Node) -> void:
	_voices -= 1
	player.queue_free()


func _make_3d_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "SFX"
	player.unit_size = LOUDNESS_SIZE
	player.max_distance = HEARING_RANGE
	player.attenuation_filter_cutoff_hz = 20500.0  # no extra muffling with distance (the retro filter does it)
	return player


## A copy of the stream that repeats forever (the files themselves are left alone, so the
## same file can still be played once elsewhere).
func _looping(stream: AudioStream) -> AudioStream:
	if _loop_copies.has(stream):
		return _loop_copies[stream]
	var copy: AudioStream = stream.duplicate()
	if copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
		copy.loop_begin = 0
		copy.loop_end = int(copy.get_length() * copy.mix_rate)
	elif "loop" in copy:  # .ogg and .mp3
		copy.loop = true
	_loop_copies[stream] = copy
	return copy


## Music / ambience: start the new track quiet and fade it up while the old one fades out.
func _crossfade(channel: String, id: String, volume_db: float) -> void:
	var now: Array = _channels.get(channel, ["", null])
	if now[0] == id:
		return
	var old: AudioStreamPlayer = now[1]
	if old != null:
		var fade_out := create_tween()
		fade_out.tween_property(old, "volume_db", -60.0, FADE_SECONDS)
		fade_out.tween_callback(old.queue_free)
	var player: AudioStreamPlayer = null
	var stream := _pick(channel, id) if id != "" else null
	if stream != null:
		player = AudioStreamPlayer.new()
		player.stream = _looping(stream)
		player.bus = FOLDERS[channel]
		player.volume_db = -60.0
		add_child(player)
		player.play()
		create_tween().tween_property(player, "volume_db", volume_db, FADE_SECONDS)
		_say("%s now playing: %s" % [channel, id])
	_channels[channel] = [id, player]


## The PS1 muffle: a low-pass filter on the SFX and Music buses (see RETRO_CUTOFF_HZ).
func _add_retro_filter() -> void:
	if RETRO_CUTOFF_HZ <= 0.0:
		return
	for bus_name in ["SFX", "Music"]:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus == -1:
			continue
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz = RETRO_CUTOFF_HZ
		AudioServer.add_bus_effect(bus, filter)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	# (A menu that's taken out and put back is "added" again: only hook it up once.)
	if button != null and not button.pressed.is_connected(_click):
		button.pressed.connect(_click)


func _say(text: String) -> void:
	if _log:
		print("[Sound] " + text)
