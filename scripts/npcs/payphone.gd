class_name Payphone
extends Npc
## CYPURRPUNK — a PAYPHONE on the sidewalk. Use it (E) to call YOUR gang's boss in the sewers:
## Don Catleone for the Catleone Family, Pawnie for the Burrow Gang (scripts/teams.gd).
## fish_heist.gd puts a few in every district (scenes/props/payphone.tscn), in random spots, so
## you have to find them by exploring. Both gangs use the same phones.
##
## What the boss says depends on the heat (fish_heist.gd):
##   - Before the EXIT manholes open (heat under 3/4): their crew is still digging for a way back
##     down. No hint where - there IS no way down yet.
##   - Once they're open (the crews broke through), every payphone in the district RINGS
##     (sounds/sfx/phone_ring.wav) until every gang in the game has called. Calling then tells
##     you where YOUR gang's exit is, and the HUD arrow to it switches on for your gang only.
##   - After the hatch is sealed: nobody's coming. Good luck.
##
## The LINES belong to each boss, not the phone: select Hub (Don) or GangHub (Pawnie) in main.tscn
## and look under "Payphone (the boss on the line)" in the Inspector (scripts/hub.gd). Write {where}
## in a line and it's replaced by the direction, e.g. "north-east".
##
## Multiplayer: like every NPC, the payphone isn't networked. The CALL asks the host to switch
## the arrow on for the caller's gang (FishHeist.request_reveal_exit).

## A small light on top that blinks while the phone rings.
@onready var _ring_light: OmniLight3D = get_node_or_null("RingLight")
var _ring_sound: AudioStreamPlayer3D
var _ringing: bool = false


func _ready() -> void:
	look_at_players = false  # it's a phone
	if pages.is_empty():
		# The bosses' lines (hub.gd) are used instead of Pages; this one stops the "no Pages" warning.
		var page := NpcPage.new()
		page.lines = PackedStringArray(["*click*"])
		pages.append(page)
	super._ready()
	set_ringing(false)


## Pick up the phone: your own boss answers, and what they say depends on the heat.
func talk(cat: CatPlayer) -> void:
	var heist := FishHeist.instance
	var boss := UndergroundHub.of(cat)
	var where := heist.exit_direction_name(cat.team)  # (only used once the exit is open: {where})
	var line := boss.phone_too_early
	if heist.sealed:
		line = boss.phone_sealed
	elif heist.exit_is_open():
		line = boss.phone_exit_open
		heist.request_reveal_exit.rpc_id(1, cat.player_id)  # the host switches our gang's arrow on
	Sound.play("click")
	var dialog := NpcDialog.for_cat(cat)
	dialog.open("%s (PHONE)" % boss.boss_name, line.replace("{where}", where), [["HANG UP", dialog.close]])


## Ring (bell sound + blinking light) or stop. fish_heist.gd calls this on every computer.
func set_ringing(ringing: bool) -> void:
	if ringing == _ringing:
		return
	_ringing = ringing
	if ringing:
		_ring_sound = Sound.attach_loop("phone_ring", self)
	elif _ring_sound != null:
		_ring_sound.queue_free()
		_ring_sound = null
	if _ring_light != null:
		_ring_light.visible = ringing


func _process(delta: float) -> void:
	super._process(delta)
	if _ringing and _ring_light != null:
		_ring_light.light_energy = 3.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.3 else 0.3
