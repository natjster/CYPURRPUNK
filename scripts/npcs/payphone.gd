class_name Payphone
extends Npc
## CYPURRPUNK — a PAYPHONE on the sidewalk. Use it (E) to call Don Catleone in the sewers.
## fish_heist.gd puts a few in every district (scenes/props/payphone.tscn), in random spots, so
## you have to find them by exploring.
##
## What Don says depends on the heat (fish_heist.gd):
##   - Before the EXIT manhole opens (heat under 3/4): his crew is still digging for a way back
##     down. No hint where - there IS no way down yet.
##   - Once it's open (they broke through), every payphone in the district RINGS
##     (sounds/sfx/phone_ring.wav) until someone picks one up. Calling then tells you where the
##     exit is, and the HUD arrow to it switches on for the whole crew.
##   - After the hatch is sealed: nobody's coming. Good luck.
##
## The lines are in the Inspector (select Payphone in payphone.tscn). Write {where} in a line and
## it's replaced by the direction, e.g. "north-east". The talk box shows the caller as npc_name.
##
## Multiplayer: like every NPC, the payphone isn't networked. The CALL asks the host to switch
## the arrow on for everyone (FishHeist.request_reveal_exit).

@export_group("What Don says")
## Calling before the exit is open.
@export_multiline var line_too_early: String = "Kid! You're still kickin'. Listen - there ain't a way back down yet. Every pipe we know, OVERCLEAN's got plugged. My boys are diggin' as fast as their little paws go. Grab what you can and keep your head down. When we break through, every phone in town's gonna ring."
## Calling once the exit is open: the arrow switches on.
@export_multiline var line_exit_open: String = "THERE you are! The boys broke through - there's a hole open, {where} side. I put it on your map. Get down here before the vacuums find it too!"
## Calling after the hatch was sealed (the DEEP CLEAN).
@export_multiline var line_sealed: String = "...kid? They found our hole. We had to seal it. I'm sorry. Nobody's comin'. Make 'em remember you."

## A small light on top that blinks while the phone rings.
@onready var _ring_light: OmniLight3D = get_node_or_null("RingLight")
var _ring_sound: AudioStreamPlayer3D
var _ringing: bool = false


func _ready() -> void:
	look_at_players = false  # it's a phone
	if pages.is_empty():
		# The lines above are used instead of Pages; this one stops the "no Pages" warning.
		var page := NpcPage.new()
		page.lines = PackedStringArray(["*click*"])
		pages.append(page)
	super._ready()
	set_ringing(false)


## Pick up the phone: Don's line depends on the heat (see the top of this file).
func talk(cat: CatPlayer) -> void:
	var heist := FishHeist.instance
	var where := heist.exit_direction_name()  # (only used once the exit is open: {where})
	var line := line_too_early
	if heist.sealed:
		line = line_sealed
	elif heist.exit_is_open():
		line = line_exit_open
		heist.request_reveal_exit.rpc_id(1, cat.player_id)  # the host switches the arrow on
	Sound.play("click")
	var dialog := NpcDialog.for_cat(cat)
	dialog.open("DON CATLEONE (PHONE)", line.replace("{where}", where), [["HANG UP", dialog.close]])


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
