class_name Loudspeaker
extends StaticBody3D
## CYPURRPUNK — an OVERCLEAN street LOUDSPEAKER POLE (scenes/props/loudspeaker.tscn).
## The city puts some on sidewalk corners (scripts/city_generator.gd, "Loudspeakers" in the City
## node's Inspector). When OVERCLEAN makes an announcement (scripts/overclean_announcer.gd), the
## words TYPE OUT as floating cyan text beside every pole's horns, in time with the voice, and
## the little light on top blinks red and cyan while it talks.
##
## Node tree:
##   Loudspeaker (StaticBody3D, this script)
##   ├── PoleShape / BaseShape (what cats and cars bump into)
##   ├── Model     (models/loudspeaker.glb, made in the model kit: tools/model_specs/loudspeaker.json)
##   ├── LedGlow   (the glowing box on the tip)  + LedLight (its little light)
##   └── Readout   (Label3D + scripts/ui/floating_line.gd: where the words appear; in the groups
##                 "hud_name_tags" and "overclean_speakers": the announcer types into every one)
##
## Not networked: every computer's announcer types its own lines (they're the same anyway).

## The group every pole's Readout is in (the announcer finds them with it).
const GROUP := "overclean_speakers"

## The light's colour when it's quiet, and the colour it flashes while OVERCLEAN talks.
@export var idle_color: Color = Color(0.5, 0.9, 1)
@export var talking_color: Color = Color(1, 0.25, 0.25)
## How bright the little light on the horns is when quiet / while talking.
@export var idle_light: float = 1.2
@export var talking_light: float = 3.0
## Seconds per blink while talking.
@export var blink_seconds: float = 0.35

@onready var _readout: FloatingLine = $Readout
@onready var _light: OmniLight3D = $LedLight


func _ready() -> void:
	LevelKit.psx_ify($Model)


## Is it showing words right now?
func is_talking() -> bool:
	return _readout.is_talking()


## The words on show right now (for tests).
func readout_text() -> String:
	return _readout.text


func _process(_delta: float) -> void:
	if _readout.is_talking():
		var on := fmod(Time.get_ticks_msec() / 1000.0, blink_seconds * 2.0) < blink_seconds
		_light.light_color = talking_color if on else idle_color
		_light.light_energy = talking_light
	else:
		_light.light_color = idle_color
		_light.light_energy = idle_light
