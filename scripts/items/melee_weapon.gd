class_name MeleeWeapon
extends Weapon
## CYPURRPUNK — a MELEE weapon (the NEON BAT): a "gun" whose shot is a short SWING.
## Put this script on the root of a melee item's scene (scenes/items/neon_bat.tscn) instead of
## weapon.gd. It uses the gun's numbers in the Inspector the same way:
##   Fire Rate  = swings per second          Automatic = hold the button to keep swinging
##   Max Range  = how far the swing reaches  Damage / Crit Chance / Crit Multiplier = per hit
##   Cat Knockback / Cat Hop / Car Impulse = how hard it shoves what it hits
## plus the Swing settings below.
##
## A swing hits EVERYTHING in an arc in front of you (several VAC-COPs at once, a rival cat...),
## through the hit framework (scripts/hit.gd), exactly like a bolt: VAC-COPs lose health, the OTHER
## gang's cats take damage and get knocked back, your own gang is left alone (friendly fire off),
## the car gets shoved. Like guns, it doesn't work down in the sewers (the safe zone).
##
## Multiplayer: the swinger's computer finds what it hit and hands each one a Hit (which asks the
## host / owner as needed), then tells everyone to play the swing (show_swing) so they see and
## hear it.

@export_group("Swing")
## How wide the swing is (metres to each side of you).
@export var swing_radius: float = 1.2
## How tall the swing area is (metres), and how high its middle is above your feet (0 = it
## reaches as far below your feet as above: still hits flat VAC-COPs while you're mid-jump).
@export var swing_height: float = 3.2
@export var swing_height_offset: float = 0.2
## How long the swing animation takes (seconds).
@export var swing_time: float = 0.18
## How far the bat swings (radians, from raised to follow-through).
@export var swing_angle: float = 2.2
## The sound of a swing (res://sounds/sfx/, no .wav) and of a swing that connects.
@export var swing_sound: String = "swing"
@export var hit_sound: String = "bonk"

var _model: Node3D
var _model_home: Vector3  # the model's resting rotation (the swing starts and ends there)
var _swing_tween: Tween


func _ready() -> void:
	super._ready()
	_model = get_node_or_null("Model")
	if _model != null:
		_model_home = _model.rotation


## Owner only: swing! Find everything in the arc in front of where the camera looks.
func _fire() -> void:
	holder.aim_until = Time.get_ticks_msec() / 1000.0 + 0.35  # the cat turns to face the swing
	Seats.rumble(holder.player_id, 0.5, 0.2, 0.08)

	# Flat "forward" from the camera (melee doesn't care about looking up or down much).
	var look := -holder.camera.global_basis.z
	var forward := Vector3(look.x, 0, look.z).normalized()
	if forward == Vector3.ZERO:
		forward = -holder.cat_model.global_basis.z
	# The swing area: a box in front of us, swing_radius to each side, max_range deep, and tall
	# enough to reach from below our feet to above our head (VAC-COPs are flat on the ground, and
	# a swing while bouncing / jumping should still reach them).
	var centre := holder.global_position + forward * (max_range * 0.5 + 0.1) + Vector3.UP * swing_height_offset
	var box := BoxShape3D.new()
	box.size = Vector3(swing_radius * 2.0, swing_height, max_range)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.looking_at(forward, Vector3.UP), centre)
	query.exclude = [holder.get_rid()]  # don't bonk yourself
	var found := get_world_3d().direct_space_state.intersect_shape(query, 16)

	var hit_anything := false
	var already := {}
	for result in found:
		var target := Hit.target_of(result.collider)
		if target == null or already.has(target) or target == holder:
			continue
		if target is CatPlayer and (target as CatPlayer).team == holder.team:
			continue  # our own gang: the bat goes right past them (no hit sound either)
		already[target] = true
		var info := Hit.new()
		info.shooter = holder
		info.weapon = self
		info.crit = _rng.randf() < crit_chance
		info.damage = roundi(damage * _rng.randf_range(1.0 - damage_wobble, 1.0 + damage_wobble) * (crit_multiplier if info.crit else 1.0))
		info.direction = forward
		info.position = (target as Node3D).global_position + Vector3.UP * 0.5 if target is Node3D else centre
		hit_anything = true
		if target.receive_hit(info):
			Hud.damage_number(info.position, info.damage, info.crit, holder.slot)  # on OUR HUD
	show_swing.rpc(hit_anything)


## Everyone (including the swinger): play the swing, and the hit sound if it connected.
@rpc("any_peer", "call_local", "unreliable_ordered")
func show_swing(connected: bool) -> void:
	if holder == null or multiplayer.get_remote_sender_id() != PlayerId.peer_of(holder.player_id):
		return  # only the holder may swing
	shots_seen += 1
	holder.aim_until = Time.get_ticks_msec() / 1000.0 + 0.35
	Sound.play_at(swing_sound, global_position, -4.0)
	if connected:
		Sound.play_at(hit_sound, global_position + (-holder.cat_model.global_basis.z), -2.0)
	if _model == null:
		return
	# Raised back -> whoosh forward -> settle home.
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_model.rotation = _model_home + Vector3(swing_angle * 0.45, 0, 0)
	_swing_tween = create_tween()
	_swing_tween.tween_property(_model, "rotation", _model_home - Vector3(swing_angle * 0.55, 0, 0), swing_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(_model, "rotation", _model_home, swing_time * 1.5)


## No crosshair: you swing where you're facing.
func wants_crosshair() -> bool:
	return false
