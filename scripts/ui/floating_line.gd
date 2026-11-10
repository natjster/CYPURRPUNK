class_name FloatingLine
extends Label3D
## CYPURRPUNK — a line of words that TYPES OUT in the 3D world, letter by letter, as clean
## outlined text with no box behind it (the same look as item and NPC names on the HUD).
## Used by the PAYPHONES (the boss's line pops up over the phone) and OVERCLEAN's street
## LOUDSPEAKERS (the announcement types out beside the horns).
##
## HOW IT WORKS: this Label3D is only a MARKER (it's in the "hud_name_tags" group): the HUD
## (scripts/ui/hud_name_tags.gd) draws the words sharp on every player's screen where the marker
## is, and its metadata "typed" says how many letters show so far. Nothing here is networked:
## each computer types its own copy.
##
## Use from a script:   $Readout.say("Hello!", Color.CYAN, 2.0, "meow_blip_don")
## In the Inspector you can change how fast it types, how long it stays, and where it wraps.

## How fast the words type out (letters per second), when say() isn't told how long to take.
@export var letters_per_second: float = 22.0
## How long the line stays up after it has finished typing (seconds).
@export var hold_seconds: float = 2.5
## Long lines are broken onto several short lines of about this many letters (0 = never).
@export var wrap_at: int = 28
## How far away (metres) the line can still be read. It fades out just before this.
@export var readable_from: float = 30.0
## How tall the words would stand in the world (metres): they shrink with distance like a sign
## (the HUD keeps them between its Min Font Size and Biggest Font Size below).
@export var text_height: float = 0.28
## The biggest the words get on the HUD (HUD units: the screen is 720 tall), so a long line
## right next to the camera doesn't cover the screen.
@export var biggest_font_size: int = 24
## Voice blips (a sound in sounds/sfx/, e.g. "meow_blip_don") play from here in 3D: one at the
## start of every word, never closer together than this many seconds.
@export var blip_gap_seconds: float = 0.2
## How loud the blips are, in decibels.
@export var blip_volume_db: float = -4.0

var _typed: float = -1.0  # letters shown so far (-1 = not typing)
var _speed: float = 22.0
var _hide_at: float = INF
var _voice: String = ""
var _pitch: float = 1.0
var _blip_wait: float = 0.0
var _hold: float = 2.5


func _ready() -> void:
	add_to_group(HudNameTags.GROUP)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	set_meta("max_distance", readable_from)
	set_meta("max_font_size", biggest_font_size)
	set_meta("text_height", text_height)
	text = ""
	hide()


## Type "line" out. seconds = how long the typing should take (-1 = use Letters Per Second;
## the loudspeakers pass the voice file's length so the words keep up with the voice).
## voice = a blip sound played at every word ("" = silent); pitch = its pitch.
## hold = seconds to stay up after typing (-1 = Hold Seconds).
func say(line: String, color: Color = Color(-1, -1, -1), seconds: float = -1.0, voice: String = "",
		pitch: float = 1.0, hold: float = -1.0) -> void:
	text = wrap_text(line, wrap_at)
	if color.r >= 0.0:
		modulate = color
	_speed = letters_per_second
	if seconds > 0.0:
		_speed = maxf(1.0, text.length() / seconds)
	_voice = voice
	_pitch = pitch
	_hold = hold if hold >= 0.0 else hold_seconds
	_blip_wait = 0.0
	_typed = 0.0
	_hide_at = INF
	set_meta("typed", 0)
	show()


## Stop talking and hide right away.
func stop() -> void:
	_typed = -1.0
	_hide_at = INF
	text = ""
	hide()


## Is a line up (typing, or still showing)?
func is_talking() -> bool:
	return visible and text != ""


## Break a long line onto short lines of about "width" letters, at the spaces.
static func wrap_text(line: String, width: int) -> String:
	if width <= 0 or line.length() <= width:
		return line
	var lines: PackedStringArray = []
	var current := ""
	for word in line.split(" ", false):
		if current != "" and current.length() + 1 + word.length() > width:
			lines.append(current)
			current = word
		else:
			current = word if current == "" else current + " " + word
	if current != "":
		lines.append(current)
	return "\n".join(lines)


func _process(delta: float) -> void:
	if _typed >= 0.0:
		var before := int(_typed)
		_typed += _speed * delta
		var shown := mini(int(_typed), text.length())
		_blip_wait -= delta
		if _voice != "" and _blip_wait <= 0.0:
			for i in range(before, shown):
				# One blip per word: the first letter of a word (the one before it isn't a letter).
				if _is_letter(text[i]) and (i == 0 or not _is_letter(text[i - 1])):
					var player := Sound.play_at(_voice, global_position, blip_volume_db)
					if player != null:
						player.pitch_scale = _pitch * randf_range(0.96, 1.04)
					_blip_wait = blip_gap_seconds
					break
		set_meta("typed", shown)
		if shown >= text.length():
			_typed = -1.0
			set_meta("typed", -1)
			_hide_at = Time.get_ticks_msec() / 1000.0 + _hold
	elif visible and Time.get_ticks_msec() / 1000.0 >= _hide_at:
		stop()


static func _is_letter(c: String) -> bool:
	return c.to_upper() != c.to_lower()
