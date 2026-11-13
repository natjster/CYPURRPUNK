class_name MeleeWeapon
extends Weapon
## CYPURRPUNK — a MELEE weapon (the NEON BAT, the FROZEN TUNA): a "gun" whose shot is a short SWING.
## The FROZEN TUNA (Can Slam on) builds a SLAM METER and then GROUND SLAMS. The NEON BAT (Throwable
## on) can be thrown with the MELEE button from your LEFT paw (scripts/cat/cat_melee.gd).
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
## Camera jolt when the swing CONNECTS (0 = none, 1 = huge). See scripts/feedback.gd.
@export_range(0.0, 1.0) var hit_shake: float = 0.3

@export_group("Throw")
## THROWABLE: holding this in your LEFT paw (offhand), the MELEE button (F / RB) throws it. It spins
## through the air, bonks the first thing it hits and lands on the street for you to pick back up.
## (The throw's speed / reach live on the cat: Player > Melee in the Inspector.)
@export var throwable: bool = false
## A thrown hit does this many times the swing's damage, and shoves this many times as hard.
@export var throw_damage: float = 1.5
@export var throw_push: float = 1.6
## VAC-COPs hit by the thrown weapon are dazed this long (seconds).
@export var throw_stun: float = 1.0

@export_group("Swing Juice")
## How far the bat sweeps sideways across you (radians) on top of the overhead swing: a slash, not a chop.
@export var swing_sweep: float = 1.1
## HIT-STOP: when the swing connects, the bat freezes this long mid-swing (seconds). Sells the impact.
@export var hit_stop: float = 0.07
## The swinging cat lurches forward this fast (metres per second). 0 = stand still.
@export var lunge_speed: float = 4.5
## NEON TRAIL behind the bat's tip. Seconds a bit of trail takes to fade (0 = no trail).
@export var trail_fade: float = 0.22
## Trail colour (the bat's Bolt Color is used while this is fully see-through).
@export var trail_color: Color = Color(0, 0, 0, 0)
## Makes the trail reach past the real tip of the bat (1 = exactly the bat, 1.5 = a big neon arc).
@export var trail_reach: float = 2.2
## SPARKS where it hits: how many (0 = none), and how bright the flash of light at the spot is.
@export var spark_count: int = 16
@export var impact_light: float = 3.0

@export_group("Combo")
## THE COMBO: keep swinging and it goes FOREHAND -> BACKHAND -> FOREHAND...
## Wait longer than this between swings (seconds) and the combo starts over at the forehand.
@export var combo_window: float = 0.9
## Can this weapon GROUND SLAM at all? Only the FROZEN TUNA can (scenes/items/frozen_tuna.tscn).
## Off = holding the button just keeps swinging forehand / backhand.
@export var can_slam: bool = false
## THE SLAM METER = HOLD TO CHARGE (like reviving a friend): tap = a normal swing; keep HOLDING the
## button and the meter on the weapon box fills while you raise the fish overhead; when it's full you
## GROUND SLAM on your own. Let go early = the meter empties again.
## Seconds of holding before the meter starts filling (so a normal tap never charges).
@export var slam_hold_delay: float = 0.25
## Seconds of holding (after that) to fill the meter all the way.
@export var slam_hold_seconds: float = 1.0
## Seconds after a slam before you can swing again.
@export var slam_recover: float = 0.5
## The sound when you start charging (res://sounds/sfx/, no .wav; "" = none).
@export var slam_charge_sound: String = "pa_chime"
## The SLAM: damage x this, shove x this (VAC-COPs, rival cats and cars all fly further).
@export var finisher_damage: float = 1.75
@export var finisher_push: float = 2.2
## The slam reaches this much further / wider than a normal swing (1 = the same).
@export var finisher_reach: float = 1.3
## VAC-COPs hit by the slam are dazed this long (seconds; they stop driving). 0 = no daze.
@export var finisher_stun: float = 0.8
## Camera jolt and bat freeze when the slam connects (a normal swing uses Hit Shake / Hit Stop).
@export_range(0.0, 1.0) var finisher_shake: float = 0.65
@export var finisher_hit_stop: float = 0.15
## SHOCKWAVE: the slam hits the ground and everything within this radius of the impact gets hit too
## (metres, 0 = no shockwave). Shows as a neon ring racing out across the street.
@export var shockwave_radius: float = 2.6
## The boom the slam makes (res://sounds/sfx/, no .wav; "" = none) and how loud (dB).
@export var finisher_sound: String = "explode"
@export var finisher_volume: float = -9.0
## AIR SLAM: fill the meter while in the air and you DIVE down (metres per second) into the slam.
## 0 = no dive (it slams wherever you are).
@export var air_slam_speed: float = 16.0

@export_group("Spin Attack")
## SPIN ATTACK (right mouse / LT): the cat whirls round once with the weapon held out, hitting EVERYTHING
## around it and shoving it all away. Only weapons with this ticked (the FROZEN TUNA).
@export var can_spin: bool = false
## How far round the cat it reaches (metres), its damage (x the normal swing), and how hard it shoves
## things away (x the normal knockback; VAC-COPs, rival cats and cars all fly out).
@export var spin_radius: float = 3.2
@export var spin_damage: float = 0.6
@export var spin_push: float = 2.4
## VAC-COPs hit by the spin are dazed this long (seconds).
@export var spin_stun: float = 0.5
## How long the whirl takes (seconds), how many times round, and seconds before you can spin again.
@export var spin_time: float = 0.4
@export var spin_turns: float = 1.0
@export var spin_cooldown: float = 1.5
## Camera jolt when it hits something (0..1), and the whoosh (res://sounds/sfx/, no .wav).
@export_range(0.0, 1.0) var spin_shake: float = 0.4
@export var spin_sound: String = "swing"

var _model: Node3D
var _spin_wait: float = 0.0  # owner: seconds until the next spin
## For the test line: how many things the last spin hit.
var last_spin_hits: int = 0
## The combo: which swing is next (0 forehand, 1 backhand, 2 slam) and until when it carries on.
var combo_step: int = 0
var _combo_until: float = 0.0
## THE SLAM METER, 0 (empty) to 1 (SLAM!). Owner's computer only (shown on the HUD's weapon box).
var slam_charge: float = 0.0
## Hold-to-charge: still holding since the last press, how long, and "let go first" after a slam.
var _holding: bool = false
var _hold_time: float = 0.0
var _wait_release: bool = false
## A BOOMERANG weapon that's out flying (cat_melee.gd show_throw): it's hidden and can't be swung.
var in_flight: bool = false
## Where the last swing's slam hit the ground (for the test line), and the trail's extra reach now.
var last_slam_spot := Vector3.ZERO
var _trail_boost: float = 1.0
var _model_home: Vector3  # the model's resting rotation (the swing starts and ends there)
var _swing_tween: Tween
## Trail: the bat's handle and tip, in the Model's own space (worked out from the mesh in _ready).
var _trail_base := Vector3.ZERO
var _trail_tip := Vector3(0, 0.8, 0)
## Trail samples [{base, tip, age}] in world space, and until when to keep adding new ones.
var _trail_points: Array = []
var _trail_until: float = 0.0
var _trail_mesh: ImmediateMesh
var _trail_node: MeshInstance3D


func _ready() -> void:
	super._ready()
	_model = get_node_or_null("Model")
	if _model != null:
		_model_home = _model.rotation
		_find_bat_ends()
	_make_trail()


## Owner only: swing! Find everything in the arc in front of where the camera looks.
func _fire() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	holder.aim_until = now + 0.35  # the cat turns to face the swing

	# THE COMBO: which swing is this? (Too long since the last one = back to the forehand.)
	if now > _combo_until:
		combo_step = 0
	var charged := slam_ready()
	# A full SLAM METER = this swing is the SLAM; otherwise forehand / backhand by turns.
	var step := 2 if charged else combo_step % 2
	var air_slam := charged and air_slam_speed > 0.0 and not holder.is_on_floor()
	var slam := step == 2
	if slam:
		slam_charge = 0.0  # used up: hold the button again to fill it
	# (Next swing: forehand <-> backhand; after a slam, the forehand again.)
	combo_step = 0 if slam else 1 - step
	_combo_until = now + combo_window
	Seats.rumble(holder.player_id, 0.9 if slam else 0.5, 0.35 if slam else 0.2, 0.08)

	# Flat "forward" from the camera (melee doesn't care about looking up or down much).
	var look := -holder.camera.global_basis.z
	var forward := Vector3(look.x, 0, look.z).normalized()
	if forward == Vector3.ZERO:
		forward = -holder.cat_model.global_basis.z
	# The swing area: a box in front of us, swing_radius to each side, max_range deep, and tall
	# enough to reach from below our feet to above our head (VAC-COPs are flat on the ground, and
	# a swing while bouncing / jumping should still reach them). The slam reaches further.
	var reach := finisher_reach if slam else 1.0
	var depth := max_range * reach
	var centre := holder.global_position + forward * (depth * 0.5 + 0.1) + Vector3.UP * swing_height_offset
	var box := BoxShape3D.new()
	box.size = Vector3(swing_radius * 2.0 * reach, swing_height, depth)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.looking_at(forward, Vector3.UP), centre)
	query.exclude = own_rids()  # don't bonk yourself (or the car you're riding in)
	var space := get_world_3d().direct_space_state
	var found := space.intersect_shape(query, 16)
	# The SLAM's SHOCKWAVE: also everything in a circle around where the bat hits the ground.
	var slam_spot := _ground_below(holder.global_position + forward * depth * 0.6)
	if slam and shockwave_radius > 0.0:
		var ring := SphereShape3D.new()
		ring.radius = shockwave_radius
		query.shape = ring
		query.transform = Transform3D(Basis.IDENTITY, slam_spot + Vector3.UP * 0.4)
		found.append_array(space.intersect_shape(query, 64))  # (64: street tiles and walls count too)

	var hit_anything := false
	var already := {}
	for result in found:
		var target := Hit.target_of(result.collider)
		if target == null or already.has(target) or target == holder:
			continue
		if target is CatPlayer and (target as CatPlayer).team == holder.team:
			continue  # our own gang: the bat goes right past them (no hit sound either)
		already[target] = true
		var spot: Vector3 = (target as Node3D).global_position if target is Node3D else centre
		# Shove it forwards, and on a slam also OUT from the impact (the shockwave throws things away).
		var push_dir := forward
		if slam:
			var away := Vector3(spot.x - slam_spot.x, 0, spot.z - slam_spot.z)
			push_dir = (forward + away.normalized() * 0.8).normalized() if away.length() > 0.2 else forward
		var info := _make_hit(push_dir, spot + Vector3.UP * 0.5)
		# HEAVY PAWS (scripts/upgrades.gd): +25% / +50% damage and knockback for this cat.
		var paws := Upgrades.melee_multiplier(holder.player_id)
		info.damage = roundi(info.damage * paws * (finisher_damage if slam else 1.0))
		info.enemy_push *= paws * (finisher_push if slam else 1.0)
		if slam:
			info.push_scale = finisher_push
			info.stun_seconds = maxf(info.stun_seconds, finisher_stun)
			info.enemy_push += Vector3.UP * enemy_knockback * 0.6  # pop them up off the ground
		hit_anything = true
		if target.receive_hit(info):
			# (The slam's numbers pop big and yellow, like a crit.)
			Hud.damage_number(info.position, info.damage, info.crit or slam, holder.slot)  # on OUR HUD
	if hit_anything:
		Feedback.shake(holder.player_id, finisher_shake if slam else hit_shake)  # THWACK (scripts/feedback.gd)
	elif slam:
		Feedback.shake(holder.player_id, finisher_shake * 0.4)  # the ground still shakes
	# Lurch into the swing (like a zap, but forwards: cat_player.gd get_zapped). The slam lurches harder.
	if lunge_speed > 0.0 and holder.is_on_floor():
		var lunge := lunge_speed * (1.4 if slam else 1.0)
		holder.velocity.x += forward.x * lunge
		holder.velocity.z += forward.z * lunge
	if air_slam:
		holder.velocity.y = minf(holder.velocity.y, -air_slam_speed)  # DIVE!
	var hit_spots := PackedVector3Array()
	for target in already:
		if target is Node3D:
			hit_spots.append((target as Node3D).global_position + Vector3.UP * 0.4)
	show_swing.rpc(hit_anything, hit_spots, step, slam_spot)


## Owner only: the ground under "where" (straight down, up to 8 m), or "where" at our feet' height.
func _ground_below(where: Vector3) -> Vector3:
	var from := Vector3(where.x, holder.global_position.y + 0.5, where.z)
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0)
	ray.exclude = own_rids()
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.position if hit else Vector3(where.x, holder.global_position.y, where.z)


## Everyone (including the swinger): play the swing, and the hit sound if it connected.
@rpc("any_peer", "call_local", "unreliable_ordered")
## step = which combo swing (0 forehand, 1 backhand, 2 SLAM); slam_spot = where the slam hits the ground.
func show_swing(connected: bool, hit_spots: PackedVector3Array = PackedVector3Array(), step: int = 0, slam_spot: Vector3 = Vector3.ZERO) -> void:
	if holder == null or multiplayer.get_remote_sender_id() != PlayerId.peer_of(holder.player_id):
		return  # only the holder may swing
	shots_seen += 1
	step = clampi(step, 0, 2)
	var slam := step == 2
	holder.aim_until = Time.get_ticks_msec() / 1000.0 + 0.35
	Sound.play_at(swing_sound, global_position, -4.0 if not slam else -1.0)
	if connected:
		Sound.play_at(hit_sound, global_position + (-holder.cat_model.global_basis.z), -2.0 if not slam else 1.0)
	for spot in hit_spots:
		_impact(spot, slam)
	if slam:
		last_slam_spot = slam_spot
		if finisher_sound != "":
			Sound.play_at(finisher_sound, slam_spot, finisher_volume)
		_shockwave(slam_spot)
		if not holder.is_multiplayer_authority():  # (the swinger's own camera already shook in _fire)
			Feedback.shake_near(slam_spot, finisher_shake * 0.5, shockwave_radius * 3.0)  # nearby cats feel it
	if _model == null:
		return
	# Forehand: raised back and out to one side -> SLASH across -> (freeze if it hit) -> settle home.
	# Backhand: the same slash from the OTHER side. Slam: straight down over the head, extra far.
	# (Godot turns Y first, then X: so the Y part sweeps the tilted bat across in front of the cat.)
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	var side := -1.0 if step == 1 else 1.0
	var sweep := 0.0 if slam else swing_sweep * side
	var raise := swing_angle * (0.75 if slam else 0.45)
	var follow := swing_angle * (0.8 if slam else 0.55)
	var start := _model_home + Vector3(raise, sweep, 0)
	var middle := _model_home + Vector3(-swing_angle * 0.05, 0, 0)
	var finish := _model_home + Vector3(-follow, -sweep, 0)
	var time := swing_time * (1.25 if slam else 1.0)
	var freeze := (finisher_hit_stop if slam else hit_stop) if connected else 0.0
	_model.rotation = start
	_trail_points.clear()
	_trail_boost = 1.35 if slam else 1.0
	_trail_until = Time.get_ticks_msec() / 1000.0 + time + freeze
	_swing_tween = create_tween()
	_swing_tween.tween_property(_model, "rotation", middle, time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if freeze > 0.0:
		_swing_tween.tween_interval(freeze)  # HIT-STOP: the bat sticks in it for a beat
	_swing_tween.tween_property(_model, "rotation", finish, time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(_model, "rotation", _model_home, swing_time * 1.5).set_trans(Tween.TRANS_SINE)


# --- Juice: trail and sparks ---

## Work out where the bat's handle and tip are: the two ends of the mesh along its longest side.
func _find_bat_ends() -> void:
	var box := AABB()
	var first := true
	var to_model := _model.global_transform.affine_inverse() if _model.is_inside_tree() else Transform3D.IDENTITY
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var inst := node as MeshInstance3D
		if inst.mesh == null:
			continue
		# The mesh's box, moved into the Model's own space.
		var local: AABB = (to_model * inst.global_transform) * inst.get_aabb() if inst.is_inside_tree() else inst.get_aabb()
		box = local if first else box.merge(local)
		first = false
	if first:
		return
	var axis := box.get_longest_axis_index()
	var centre := box.get_center()
	var half := Vector3.ZERO
	half[axis] = box.size[axis] * 0.5
	_trail_base = centre - half * 0.2
	_trail_tip = centre + half


func _make_trail() -> void:
	if trail_fade <= 0.0:
		return
	var trail := LevelKit.add_trail_mesh(self, "SwingTrail")
	_trail_mesh = trail["mesh"]
	_trail_node = trail["node"]


func _process(delta: float) -> void:
	super._process(delta)
	_update_trail(delta)


## Owner only, every physics frame while held (ItemManager _use_held_items). A weapon that CAN SLAM
## swings on the PRESS, then keeps CHARGING while you hold the button: full meter = GROUND SLAM.
func use_tick(trigger_down: bool, trigger_pressed: bool, delta: float) -> void:
	if in_flight:
		_holding = false
		return  # (a thrown boomerang bat is out flying: nothing to swing)
	if not can_slam:
		super.use_tick(trigger_down, trigger_pressed, delta)
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not trigger_down:
		_holding = false
		_wait_release = false
		slam_charge = 0.0  # let go early = the meter empties
		_raise_for_charge()
		return
	if _wait_release:
		return  # just slammed: let go of the button before the next swing
	if not _holding:
		if _cooldown > 0.0:
			return
		_fire()  # the PRESS: a normal forehand / backhand right away
		_cooldown = 1.0 / fire_rate
		_holding = true
		_hold_time = 0.0
		return
	# STILL HOLDING: fill the meter (after a short wait, so a tap never charges).
	_hold_time += delta
	var before := slam_charge
	slam_charge = clampf((_hold_time - slam_hold_delay) / maxf(slam_hold_seconds, 0.05), 0.0, 1.0)
	if before <= 0.0 and slam_charge > 0.0 and slam_charge_sound != "":
		Sound.play(slam_charge_sound, -12.0)  # (only we hear it: it's our meter)
	if slam_charge > 0.0:
		Seats.rumble(holder.player_id, 0.1 + 0.3 * slam_charge, 0.0, delta * 2.0)  # a growing buzz
	_raise_for_charge()
	if slam_charge >= 1.0:
		_fire()  # FULL: GROUND SLAM (in the air: dive into it)
		_cooldown = slam_recover
		_holding = false
		_wait_release = true


## Owner only, every physics frame while held: the RIGHT MOUSE / LT button (ItemManager _use_held_items
## sends it here for a 2-paw weapon, which has no left paw to use). Can Spin = a SPIN ATTACK.
func alt_use_tick(trigger_down: bool, trigger_pressed: bool, delta: float) -> void:
	_spin_wait = maxf(_spin_wait - delta, 0.0)
	if not can_spin or in_flight or not trigger_pressed or _spin_wait > 0.0 or _cooldown > 0.0:
		return
	_spin()


## Owner only: SPIN ATTACK. Hit everything within spin_radius of us and shove it straight AWAY from us.
func _spin() -> void:
	_spin_wait = spin_cooldown
	_cooldown = maxf(_cooldown, spin_time)  # (no normal swing in the middle of the whirl)
	_holding = false  # (cancels a slam you were charging)
	slam_charge = 0.0
	var ball := SphereShape3D.new()
	ball.radius = spin_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, holder.global_position + Vector3.UP * 0.4)
	query.exclude = own_rids()
	var already := {}
	var hit_spots := PackedVector3Array()
	var paws := Upgrades.melee_multiplier(holder.player_id)  # HEAVY PAWS upgrade
	for result in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var target := Hit.target_of(result.collider)
		if target == null or already.has(target) or target == holder:
			continue
		if target is CatPlayer and (target as CatPlayer).team == holder.team:
			continue  # our own gang: no hit
		already[target] = true
		var spot: Vector3 = (target as Node3D).global_position if target is Node3D else holder.global_position
		var away := Vector3(spot.x - holder.global_position.x, 0, spot.z - holder.global_position.z)
		away = away.normalized() if away.length() > 0.1 else -holder.cat_model.global_basis.z
		var info := _make_hit(away, spot + Vector3.UP * 0.5)
		info.damage = roundi(info.damage * spin_damage * paws)
		info.enemy_push = (away + Vector3.UP * 0.5) * enemy_knockback * spin_push * paws
		info.push_scale = spin_push
		info.stun_seconds = maxf(info.stun_seconds, spin_stun)
		hit_spots.append(info.position)
		if target.receive_hit(info):
			Hud.damage_number(info.position, info.damage, info.crit, holder.slot)
	last_spin_hits = already.size()
	Seats.rumble(holder.player_id, 0.6, 0.3, spin_time)
	if not already.is_empty():
		Feedback.shake(holder.player_id, spin_shake)
	# WHIRL: cat_player.gd turns the whole cat round (and the turn reaches the other players with
	# its normal sync).
	holder.spin_left = spin_time
	holder.spin_speed = TAU * spin_turns / maxf(spin_time, 0.05)
	show_spin.rpc(hit_spots)


@rpc("any_peer", "call_local", "unreliable_ordered")
## Everyone: draw the spin. The fish swings out flat, its neon trail draws a circle, a ring of light
## races out along the street, and sparks fly off everything it hit.
func show_spin(hit_spots: PackedVector3Array) -> void:
	if holder == null or multiplayer.get_remote_sender_id() != PlayerId.peer_of(holder.player_id):
		return
	shots_seen += 1
	Sound.play_at(spin_sound, global_position, -1.0)
	if not hit_spots.is_empty():
		Sound.play_at(hit_sound, hit_spots[0], 0.0)
	for spot in hit_spots:
		_impact(spot, false)
	_shockwave(_ground_below(holder.global_position), spin_radius)
	if _model == null:
		return
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	# Held straight out to the side (flat) for the whirl, then back home.
	_model.rotation = _model_home + Vector3(-swing_angle * 0.35, swing_sweep, 0)
	_trail_points.clear()
	_trail_boost = 1.35
	_trail_until = Time.get_ticks_msec() / 1000.0 + spin_time
	_swing_tween = create_tween()
	_swing_tween.tween_interval(spin_time)
	_swing_tween.tween_property(_model, "rotation", _model_home, swing_time * 1.5).set_trans(Tween.TRANS_SINE)


## Owner's view: while charging, lift the fish up over the head (more meter = higher, with a shiver).
func _raise_for_charge() -> void:
	if _model == null or (_swing_tween != null and _swing_tween.is_running()):
		return
	var lift := swing_angle * 0.75 * slam_charge
	var shiver := sin(Time.get_ticks_msec() * 0.06) * 0.04 * slam_charge
	_model.rotation = _model_home + Vector3(lift, shiver, 0)


## Is the SLAM METER full (this swing is the GROUND SLAM)?
func slam_ready() -> bool:
	return can_slam and slam_charge >= 1.0


## Every frame: remember where the bat is while swinging, fade the old bits, redraw the ribbon.
func _update_trail(delta: float) -> void:
	if _trail_node == null:
		return
	for point in _trail_points:
		point.age += delta
	_trail_points = _trail_points.filter(func(p): return p.age < trail_fade)
	if _model != null and Time.get_ticks_msec() / 1000.0 < _trail_until and _model.is_visible_in_tree():
		var base := _model.global_transform * _trail_base
		var tip := _model.global_transform * (_trail_base + (_trail_tip - _trail_base) * trail_reach * _trail_boost)
		_trail_points.append({"base": base, "tip": tip, "age": 0.0})
	_trail_mesh.clear_surfaces()
	_trail_node.global_transform = Transform3D.IDENTITY
	if _trail_points.size() < 2:
		return
	var tint := trail_color if trail_color.a > 0.0 else bolt_color
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for point in _trail_points:
		var life: float = 1.0 - point.age / trail_fade
		# Newest bit = white-hot, cooling to the bat's colour as it fades. The handle end is see-through.
		var hot := tint.lerp(Color.WHITE, life * life * 0.7)
		_trail_mesh.surface_set_color(Color(hot.r, hot.g, hot.b, 0.0))
		_trail_mesh.surface_add_vertex(point.base)
		_trail_mesh.surface_set_color(Color(hot.r, hot.g, hot.b, life * 0.9))
		_trail_mesh.surface_add_vertex(point.tip)
	_trail_mesh.surface_end()


## The bat connected here: a burst of neon sparks and a flash of light (every computer).
## big = the combo SLAM: twice the sparks, flying further, and a brighter flash.
func _impact(where: Vector3, big: bool = false) -> void:
	var world: Node = Game.instance if Game.instance != null else get_tree().root
	var tint := trail_color if trail_color.a > 0.0 else bolt_color
	if spark_count > 0:
		var sparks := CPUParticles3D.new()
		sparks.one_shot = true
		sparks.explosiveness = 1.0
		sparks.amount = spark_count * (2 if big else 1)
		sparks.lifetime = 0.35
		sparks.direction = Vector3.UP
		sparks.spread = 180.0
		sparks.initial_velocity_min = 3.0
		sparks.initial_velocity_max = 11.0 if big else 7.5
		sparks.gravity = Vector3(0, -14, 0)
		sparks.scale_amount_min = 0.6
		sparks.scale_amount_max = 1.2
		var bit := BoxMesh.new()
		bit.size = Vector3(0.07, 0.07, 0.07)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.vertex_color_use_as_albedo = true
		bit.material = glow
		sparks.mesh = bit
		var ramp := Gradient.new()
		ramp.set_color(0, Color.WHITE)
		ramp.set_color(1, tint)
		sparks.color_ramp = ramp
		world.add_child(sparks)
		sparks.global_position = where
		sparks.emitting = true
		get_tree().create_timer(0.8).timeout.connect(sparks.queue_free)
	if impact_light > 0.0:
		var light := OmniLight3D.new()
		light.light_color = tint.lerp(Color.WHITE, 0.4)
		light.light_energy = impact_light * (2.0 if big else 1.0)
		light.omni_range = 3.5
		world.add_child(light)
		light.global_position = where
		var fade := light.create_tween()
		fade.tween_property(light, "light_energy", 0.0, 0.18)
		fade.tween_callback(light.queue_free)


## The SLAM's SHOCKWAVE (every computer): a glowing neon ring wall that races out across the ground from
## "where" to Shockwave Radius and fades, plus a quick flash of light.
func _shockwave(where: Vector3, radius: float = -1.0) -> void:
	if radius < 0.0:
		radius = shockwave_radius  # (the SPIN ATTACK passes its own size)
	if radius <= 0.0:
		return
	var world: Node = Game.instance if Game.instance != null else get_tree().root
	var tint := trail_color if trail_color.a > 0.0 else bolt_color
	# A short open tube (no lids) = a glowing wall of light that races outward. (A flat ring vanishes
	# into the street at 320x240; a wall reads from any angle.)
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 0.45
	tube.radial_segments = 20  # chunky, PS1-style
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # glows on the dark street
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED  # see the inside of the wall too
	glow.albedo_color = tint.lerp(Color.WHITE, 0.5)
	tube.material = glow
	var ring := MeshInstance3D.new()
	ring.name = "SlamShockwave"
	ring.mesh = tube
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ring)
	ring.global_position = where + Vector3.UP * 0.2
	ring.scale = Vector3(0.2, 1.0, 0.2)
	var grow := ring.create_tween().set_parallel(true)
	grow.tween_property(ring, "scale", Vector3(radius, 0.3, radius), 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	grow.tween_property(glow, "albedo_color:a", 0.0, 0.35).set_delay(0.08)
	grow.chain().tween_callback(ring.queue_free)
	if impact_light > 0.0:
		var light := OmniLight3D.new()
		light.light_color = tint
		light.light_energy = impact_light * 1.5
		light.omni_range = radius * 2.0
		world.add_child(light)
		light.global_position = where + Vector3.UP * 0.5
		var fade := light.create_tween()
		fade.tween_property(light, "light_energy", 0.0, 0.3)
		fade.tween_callback(light.queue_free)


## No crosshair: you swing where you're facing.
func wants_crosshair() -> bool:
	return false
