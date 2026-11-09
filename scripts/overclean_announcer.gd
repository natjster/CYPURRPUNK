class_name OvercleanAnnouncer
extends Node
## CYPURRPUNK — OVERCLEAN'S VOICE: the city's calm, polite, passive-aggressive robot announcer.
## It talks over the city's loudspeakers when something big happens in a raid:
##
##   the first cat of a district climbs up top ...... "Unregistered shedding has been detected..."
##   the heat reaches level 2, 3 and 4 .............. a cleanliness alert per level
##   a MEGA VAC-COP rolls out ........................ "Heavy sanitation unit deployed..."
##   the hatch seals (heat 100, the DEEP CLEAN) ...... "Sector quarantine initiated..."
##   a cat is knocked out up top ..................... "One stray removed from the premises..."
##
## Each line = a voice file (a two-tone chime, then the voice) + a SUBTITLE on the HUD. Only
## players who are UP TOP hear it (they're the ones near the city's speakers; the sewers are
## safe from it), except the seal, which everyone hears.
##
## Lives on the "Announcer" node in main.tscn. Everything below is in its Inspector: switch it off,
## change the words of a subtitle, or point a moment at a different sound file.
## The voice files are in sounds/sfx/ (overclean_*.wav). They were made with the Sound Lab
## (tools/cypurr_sound.py; the full list is tools/sound_specs/overclean.json). To change what the
## VOICE says, ask Claude to remake that file with new words, and change the subtitle here too.
##
## How it hears about the moments: it listens to the game's Events (scripts/events.gd), which fire
## on EVERY computer, so each computer plays the line for its own players. Nothing is networked.
## Lines never talk over each other: they wait their turn in a short queue.
##
## Test: --deploy --heat_ramp=60 --sound_log --frames=4800  ("[Announcer]" and "[Sound]" lines).

## The one announcer (null on the start menu before the game scene is up).
static var instance: OvercleanAnnouncer

## Switch the whole announcer on or off.
@export var enabled: bool = true
## Also talk in the TUTORIAL? (Off: the tutorial has enough words on screen already.)
@export var in_tutorial: bool = false
## How loud the voice plays, in decibels (0 = as loud as the file, -6 = about half).
@export var volume_db: float = -1.0
## Seconds of quiet after a line before the next one may start.
@export var min_gap_seconds: float = 1.5
## Lines waiting longer than this many seconds are dropped (old news by then).
@export var max_wait_seconds: float = 25.0
## Written in front of every subtitle.
@export var subtitle_prefix: String = "OVERCLEAN: "
## The subtitle's colour (a cold clinical cyan).
@export var subtitle_color: Color = Color(0.75, 0.95, 1.0)

@export_group("First cat up top")
## The voice files to pick from (sounds/sfx/<name>.wav), one at random each district.
@export var deploy_sounds: Array[String] = ["overclean_deploy_1", "overclean_deploy_2", "overclean_deploy_3"]
## The subtitle for each of those files, in the same order.
@export var deploy_lines: Array[String] = [
	"Attention citizens. Unregistered shedding has been detected in this sector. Please remain still for disposal.",
	"Attention citizens. A stray has entered a clean zone. Please remain still for disposal.",
	"Good evening, citizens. Unauthorized paw prints have been detected on the pavement. Disposal units are on their way.",
]
## Seconds to wait after the cat pops out of the manhole before speaking.
@export var deploy_delay: float = 2.0

@export_group("Heat levels")
@export var level_2_sound: String = "overclean_level2"
@export var level_2_line: String = "Cleanliness alert. Hairball levels exceeding municipal tolerance. Additional VAC-COPs dispatched."
@export var level_3_sound: String = "overclean_level3"
@export var level_3_line: String = "Warning. Unauthorized fish handling in progress. Littering is punishable by immediate suction."
@export var level_4_sound: String = "overclean_level4"
@export var level_4_line: String = "Critical mess threshold reached. Please step into the nearest dustbin in an orderly fashion."

@export_group("MEGA VAC-COP")
@export var boss_sound: String = "overclean_boss"
@export var boss_line: String = "Heavy sanitation unit deployed. Have a spotless day."
## Seconds to wait after the boss siren before speaking (so they don't drown each other out).
@export var boss_delay: float = 2.5
## Don't announce another MEGA VAC-COP within this many seconds of the last.
@export var boss_cooldown: float = 45.0

@export_group("Deep Clean (seal)")
@export var seal_sound: String = "overclean_seal"
@export var seal_line: String = "Sector quarantine initiated. Commencing total Deep Clean. Thank you for your cooperation."
## Seconds to wait after the seal siren before speaking.
@export var seal_delay: float = 2.0

@export_group("Knockouts up top")
@export var knockout_sound: String = "overclean_ko"
@export var knockout_line: String = "One stray removed from the premises. Street hygiene restored by 14 percent."
## Don't gloat about another knockout within this many seconds of the last.
@export var knockout_cooldown: float = 25.0

## Lines waiting to be said: [{sound, text, everyone, at (seconds), why}].
var _queue: Array[Dictionary] = []
## Clock (seconds since the announcer started).
var _clock: float = 0.0
## The clock time when the line now playing (plus the gap) is over.
var _busy_until: float = 0.0
## Heat levels already announced in this district (so each is said once).
var _levels_said: Dictionary = {}
var _last_boss_at: float = -1000.0
var _last_knockout_at: float = -1000.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	Events.player_went_up.connect(_on_player_went_up)
	Events.heat_level_changed.connect(_on_heat_level_changed)
	Events.boss_deployed.connect(_on_boss_deployed)
	Events.district_sealed.connect(_on_district_sealed)
	Events.player_knocked_out.connect(_on_player_knocked_out)


# --- The moments (each just queues a line) ---

func _on_player_went_up(_player_id: int, first_in_district: bool) -> void:
	if not first_in_district or deploy_sounds.is_empty():
		return
	var pick := randi() % deploy_sounds.size()  # (not the city's random numbers: this is only a voice)
	var text: String = deploy_lines[pick] if pick < deploy_lines.size() else ""
	say(deploy_sounds[pick], text, false, deploy_delay, "first cat up top")


func _on_heat_level_changed(level: int) -> void:
	if level <= 1:
		_levels_said.clear()  # a new district: every level may be announced again
		return
	if _levels_said.has(level):
		return
	_levels_said[level] = true
	match level:
		2: say(level_2_sound, level_2_line, false, 0.0, "heat level 2")
		3: say(level_3_sound, level_3_line, false, 0.0, "heat level 3")
		4: say(level_4_sound, level_4_line, false, 0.0, "heat level 4")
		# (Level 5 = the seal: _on_district_sealed says that one.)


func _on_boss_deployed() -> void:
	if _clock - _last_boss_at < boss_cooldown:
		return
	_last_boss_at = _clock
	say(boss_sound, boss_line, false, boss_delay, "MEGA VAC-COP")


func _on_district_sealed() -> void:
	# The seal outranks everything still waiting: OVERCLEAN has better things to say now.
	for line in _queue:
		print("[Announcer] (dropped for the seal: %s)" % line.why)
	_queue.clear()
	say(seal_sound, seal_line, true, seal_delay, "district sealed")


func _on_player_knocked_out(player_id: int, _cause: String) -> void:
	if FishHeist.instance != null and FishHeist.instance.sealed:
		return  # the DEEP CLEAN knocks everyone out at once: the seal line already covers it
	var cat := Game.instance.cat_for(player_id) if Game.instance != null else null
	if cat == null or UndergroundHub.is_in_hub(cat.global_position):
		return  # knocked out in the sewers: OVERCLEAN's speakers don't reach down there
	if _clock - _last_knockout_at < knockout_cooldown:
		return
	_last_knockout_at = _clock
	say(knockout_sound, knockout_line, false, 0.5, "cat knocked out up top")


# --- Saying things ---

## Queue a line: play sounds/sfx/<sound>.wav and show "text" as a subtitle, "delay" seconds from
## now, after any line already playing. everyone = every player on this computer hears it (else
## only the ones up top). why = for the test log. Any script may call it:
##   OvercleanAnnouncer.instance.say("overclean_boss", "Have a spotless day.")
func say(sound: String, text: String, everyone: bool = false, delay: float = 0.0, why: String = "") -> void:
	if not enabled or (Game.is_tutorial() and not in_tutorial):
		return
	var line := {"sound": sound, "text": text, "everyone": everyone, "at": _clock + delay, "why": why}
	# Keep the queue in "who may speak first" order (a level-up said right away goes before a
	# boss line that waits for its siren to finish).
	var spot := 0
	while spot < _queue.size() and _queue[spot].at <= line.at:
		spot += 1
	_queue.insert(spot, line)
	print("[Announcer] queued: %s (%s)" % [why, sound])


func _process(delta: float) -> void:
	_clock += delta
	if _queue.is_empty() or _clock < _busy_until:
		return
	var line: Dictionary = _queue[0]
	if _clock < line.at:
		return
	_queue.pop_front()
	if _clock - line.at > max_wait_seconds:
		print("[Announcer] (dropped, waited too long behind other lines: %s)" % line.why)
		return
	var seats := _listeners(line.everyone)
	if seats.is_empty():
		print("[Announcer] (nobody up top to hear: %s)" % line.why)
		return
	var seconds := 4.0  # (if the sound file is missing, the subtitle still shows this long)
	var player := Sound.play(line.sound, volume_db)
	if player != null:
		player.pitch_scale = 1.0  # a voice shouldn't get Sound's random pitch nudge
		seconds = player.stream.get_length()
	_busy_until = _clock + seconds + min_gap_seconds
	if line.text != "":
		for seat in seats:
			Hud.subtitle(subtitle_prefix + line.text, seconds + 0.5, subtitle_color, seat)
	print("[Announcer] %s: %s (%s, %.1f s, seats %s)" % [line.why, line.sound, line.text.left(40) + "...", seconds, seats])


## Which players on THIS computer hear it (their seat numbers): everyone, or only those up top.
func _listeners(everyone: bool) -> Array[int]:
	var seats: Array[int] = []
	if Game.instance == null or not is_instance_valid(Game.instance):
		return seats
	for cat in Game.instance.playing_cats():
		if everyone or not UndergroundHub.is_in_hub(cat.global_position):
			seats.append(cat.slot)
	return seats
