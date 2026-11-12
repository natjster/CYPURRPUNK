class_name CarJuice
extends Node3D
## CYPURRPUNK — ARCADE FEEL + FEEDBACK for the getaway car (and the bike / van rides).
## Attach to the "Juice" node under GetawayCar in scenes/getaway_car.tscn. All knobs: open that
## scene, click Juice in the Scene panel, and look at the Inspector.
##
## What it adds:
##   LAUNCH        stomping the gas from slow speed pulls harder (an arcade "jump off the line").
##   DRIFT TURBO   hold the handbrake through a corner while steering: sparks fly off the back wheels,
##                 BLUE after a moment, ORANGE after longer. Let go of the handbrake = a speed kick
##                 (bigger for orange). Classic kart racer stuff.
##   BODY LEAN     the car body leans out of turns, squats when you floor it and dips its nose when
##                 you brake (just the model: the physics body never tilts).
##   LANDINGS      after a jump the body squashes down and springs back, with a thump, dust and shake.
##   TYRE SMOKE    puffs off the back wheels while drifting or wheel-spinning.
##   SPEED CAMERA  the chase camera pulls back a little the faster you go, and rattles at top speed.
##   RUMBLE        controllers buzz while drifting, on landings and on the turbo.
##
## How it plugs in: getaway_car.gd _integrate_forces calls handling() (only on the computer that runs
## the car); everything you SEE runs here in _physics_process on EVERY computer, worked out from how
## the car moves, so other players see the lean / sparks / smoke with no extra network messages.
## (The turbo kick itself sends one small "_turbo_fx" message so everyone sees the flash.)

@export_group("Launch")
## Extra pull when you hit the gas from standstill (1.8 = 80% stronger), fading to normal at top speed.
@export var launch_accel_bonus: float = 1.8

@export_group("Drift Turbo")
## Drift this many seconds for a BLUE spark turbo...
@export var turbo_blue_seconds: float = 0.6
## ...and this many for an ORANGE one.
@export var turbo_orange_seconds: float = 1.2
## Speed kick on letting go of the handbrake (metres per second).
@export var turbo_blue_kick: float = 4.0
@export var turbo_orange_kick: float = 7.5
## You must be going at least this fast (m/s) and sliding sideways this much (m/s) for it to count.
@export var drift_min_speed: float = 6.0
@export var drift_min_slide: float = 1.5
## The handbrake slows you down less than before while you drift (multiplies the car's Handbrake Drag).
@export var drift_drag_scale: float = 0.3
## While drifting, this much of the sideways slide the tyres scrub off is turned into forward speed
## instead (0 = none, 1 = all of it), so a drift keeps you fast. Arcade!
@export var drift_carry: float = 0.4
## The widest a drift can slide (degrees between where the nose points and where the car is going).
## Past this, the slide is swung back toward the nose without losing speed, so the car holds a
## stylish sideways drift instead of spinning out. 0 = off.
@export var drift_max_angle: float = 40.0

@export_group("Body Lean")
## How far the body leans out of a turn (degrees at full speed + full steer).
@export var roll_degrees: float = 7.0
## How far the nose lifts when you floor it / dips when you brake (degrees).
@export var pitch_degrees: float = 4.0
## How springy the lean is (higher = snappier).
@export var lean_spring: float = 10.0

@export_group("Landing")
## Falling faster than this (m/s) when the wheels touch down = a landing bounce.
@export var landing_speed: float = 3.0
## How much the body squashes on a big landing (0.25 = 25% shorter for a moment).
@export var landing_squash: float = 0.25
## Wobble of the squash springing back.
@export var squash_spring: float = 14.0
@export var squash_damping: float = 0.3

@export_group("Speed Camera")
## The chase camera pulls back this many metres at top speed.
@export var camera_pullback: float = 1.6
## Road rattle near top speed: a little camera bump (0..1, scripts/feedback.gd) every 0.25 s. 0 = off.
@export var top_speed_shake: float = 0.12

@export_group("Sounds")
## Tyre squeal while drifting: which sound (sounds/sfx/<name>.wav), its loudness and pitch.
@export var skid_sound: String = "scratch"
@export var skid_volume_db: float = -10.0
@export var skid_pitch: float = 0.55

const BLUE := Color(0.35, 0.75, 1.0)
const ORANGE := Color(1.0, 0.55, 0.1)

@onready var car: GetawayCar = get_parent()

# --- Driver's computer (the car's authority) ---
var _drift_time: float = 0.0    # seconds of drifting so far (turbo charge)
var _was_handbrake := false
var _pending_kick: float = 0.0  # turbo speed to add on the next physics step

# --- Every computer ---
var _last_pos: Vector3
var _velocity: Vector3 = Vector3.ZERO      # measured from how the car moved (works on frozen copies too)
var _last_forward_speed: float = 0.0
var _look_drift: float = 0.0               # seconds this computer has SEEN the car drifting (spark colour)
var _roll: float = 0.0
var _pitch: float = 0.0
var _squash: float = 0.0
var _squash_speed: float = 0.0
var _was_grounded := true
var _air_time: float = 0.0
var _base_arm: float = -1.0
var _sparks: Array[CPUParticles3D] = []
var _smoke: Array[CPUParticles3D] = []
var _skid: AudioStreamPlayer3D


func _ready() -> void:
	_last_pos = car.global_position
	_last_yaw = car.global_rotation.y
	# Two back wheels: one spark stream + one smoke stream each (built in code, chunky PS1 cubes).
	for side in [-1.0, 1.0]:
		var spot := Node3D.new()
		add_child(spot)
		spot.position = Vector3(0.75 * side, 0.1, 1.2)
		var spark := CarFx.particles(spot, PackedColorArray([Color.WHITE, BLUE, Color(BLUE, 0.0)]),
			0.08, 24, 0.35, 5.0, Vector3(side * 0.6, 0.8, 1.0), 35.0, -14.0)
		_sparks.append(spark)
		var smoke := CarFx.particles(spot, PackedColorArray([Color(0.8, 0.8, 0.85, 0.55), Color(0.4, 0.4, 0.45, 0.0)]),
			0.35, 16, 0.9, 1.5, Vector3(0, 1, 1), 40.0, 1.5)
		_smoke.append(smoke)
	if skid_sound != "":
		_skid = Sound.attach_loop(skid_sound, self, -80.0)
		if _skid != null:
			_skid.pitch_scale = skid_pitch


## Called from getaway_car.gd _integrate_forces on the computer that runs the car, after the normal
## engine / grip / steering. Takes the new velocity and gives back the arcade-tuned one.
func handling(velocity: Vector3, forward: Vector3, forward_speed: float, side_speed: float,
		gas: float, on_ground: bool, dt: float) -> Vector3:
	var top := maxf(car.max_speed, 0.1)
	if on_ground:
		# LAUNCH: extra pull at low speed, none at top speed.
		if gas > 0.0 and forward_speed >= 0.0 and forward_speed < top:
			var low := 1.0 - clampf(forward_speed / top, 0.0, 1.0)
			velocity += forward * car.engine_accel * gas * (launch_accel_bonus - 1.0) * low * dt
		# DRIFTS lose less speed: give back part of what the handbrake drag took.
		if car.handbrake and forward_speed > 0.0:
			velocity += forward * forward_speed * minf(car.handbrake_drag * dt, 1.0) * (1.0 - drift_drag_scale)
			velocity += forward * absf(side_speed) * minf(car.drift_grip * dt, 1.0) * drift_carry
			# Hold the drift angle (no spin-outs): swing the slide back toward the nose, same speed.
			var flat := Vector3(velocity.x, 0.0, velocity.z)
			var max_angle := deg_to_rad(drift_max_angle)
			if drift_max_angle > 0.0 and flat.length() > drift_min_speed:
				var angle := forward.angle_to(flat.normalized())
				if angle > max_angle:
					var held := forward.slerp(flat.normalized(), max_angle / angle) * flat.length()
					velocity = Vector3(held.x, velocity.y, held.z)
		# DRIFT TURBO: charge while sliding with the handbrake held and steering.
		var drifting := car.handbrake and forward_speed > drift_min_speed and absf(side_speed) > drift_min_slide \
			and absf(car.steer) > 0.2
		if drifting:
			_drift_time += dt
		elif not car.handbrake and _was_handbrake:
			# Let go of the handbrake: cash in the charge.
			var level := turbo_level(_drift_time)
			if level > 0:
				_pending_kick = turbo_orange_kick if level == 2 else turbo_blue_kick
				_turbo_fx.rpc(level)
			_drift_time = 0.0
		elif not car.handbrake:
			_drift_time = 0.0
	_was_handbrake = car.handbrake
	if _pending_kick > 0.0:
		velocity += forward * _pending_kick
		_pending_kick = 0.0
	return velocity


## 0 = no turbo yet, 1 = blue, 2 = orange.
func turbo_level(seconds: float) -> int:
	if seconds >= turbo_orange_seconds:
		return 2
	return 1 if seconds >= turbo_blue_seconds else 0


## Driver -> everyone: the turbo went off. A flash of sparks, a whoosh, and (for riders) a kick.
@rpc("any_peer", "call_local", "unreliable")
func _turbo_fx(level: int) -> void:
	var colour := ORANGE if level == 2 else BLUE
	Sound.play_at("boost", car.global_position, -6.0 if level == 2 else -10.0)
	var burst := CarFx.particles(car.get_parent(), PackedColorArray([Color.WHITE, colour, Color(colour, 0.0)]),
		0.14, 30, 0.5, 8.0, car.global_basis.z, 40.0, -8.0)
	burst.global_position = car.global_position + car.global_basis.z * 1.4 + Vector3.UP * 0.3
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.emitting = true
	get_tree().create_timer(1.5).timeout.connect(burst.queue_free)
	_squash = -0.08  # a little rear-squat "kick"
	for cat in _local_riders():
		Feedback.shake(cat.player_id, 0.35 if level == 2 else 0.2)
		Seats.rumble(cat.player_id, 0.6, 0.9 if level == 2 else 0.6, 0.25)


func _local_riders() -> Array[CatPlayer]:
	var out: Array[CatPlayer] = []
	if Game.instance == null:
		return out
	for cat in Game.instance.local_cats():
		if car.has_occupant(cat.player_id):
			out.append(cat)
	return out


## EVERY computer: the look and feel, worked out from how the car moved since last frame.
func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	var moved := car.global_position - _last_pos
	_last_pos = car.global_position
	if moved.length() > 8.0 or car.teleport_frame == Engine.get_physics_frames():
		moved = _velocity * delta  # a teleport (parked / towed): ignore that frame
	var vel := moved / delta
	var forward := -car.global_basis.z
	var right := car.global_basis.x
	var forward_speed := forward.dot(vel)
	var side_speed := right.dot(vel)
	var top := maxf(car.max_speed, 0.1)
	var on_ground := car.ground_ray.is_colliding()
	var wrecked := car.health != null and car.health.wrecked

	# --- Landing bounce ---
	if not on_ground:
		_air_time += delta
	elif not _was_grounded:
		var fall := -_velocity.y
		if fall > landing_speed and _air_time > 0.15:
			var hard := clampf(fall / 12.0, 0.3, 1.0)
			_squash_speed = -landing_squash * hard * squash_spring
			Sound.play_at("box_thump", car.global_position, lerpf(-8.0, 2.0, hard))
			_dust_puff()
			for cat in _local_riders():
				Feedback.shake(cat.player_id, 0.15 + 0.35 * hard)
				Seats.rumble(cat.player_id, 0.7, 0.4 + 0.5 * hard, 0.15)
		_air_time = 0.0
	_was_grounded = on_ground

	# --- Body lean: roll out of turns, squat on gas, dip on brakes ---
	var accel := (forward_speed - _last_forward_speed) / delta
	_last_forward_speed = forward_speed
	var turn_rate := wrapf(car.global_rotation.y - _last_yaw, -PI, PI) / delta
	_last_yaw = car.global_rotation.y
	var speed_amount := clampf(absf(forward_speed) / top, 0.0, 1.0)
	var target_roll := 0.0
	var target_pitch := 0.0
	if on_ground and not wrecked:
		target_roll = clampf(turn_rate / 2.5, -1.0, 1.0) * speed_amount * deg_to_rad(roll_degrees)
		target_pitch = clampf(accel / 20.0, -1.0, 1.0) * deg_to_rad(pitch_degrees)
	var w := 1.0 - exp(-lean_spring * delta)
	_roll = lerpf(_roll, target_roll, w)
	_pitch = lerpf(_pitch, target_pitch, w)

	# Squash spring (same idea as the cat's landing squash in scripts/cat/cat_moves.gd).
	_squash_speed += -_squash * squash_spring * squash_spring * delta
	_squash_speed *= pow(squash_damping, delta * 4.0)
	_squash += _squash_speed * delta
	_squash = clampf(_squash, -0.5, 0.5)

	var model := car.get_node_or_null("Model/CarModel") as Node3D
	if model != null:
		# Leaning OUT of a turn: turning left (turn_rate +) rolls the body to the right.
		model.rotation = Vector3(_pitch, 0.0, -_roll)
		model.scale = Vector3(1.0 - _squash * 0.4, 1.0 + _squash, 1.0 - _squash * 0.4)

	# --- Drift sparks + tyre smoke ---
	var drifting := on_ground and not wrecked and forward_speed > drift_min_speed and absf(side_speed) > drift_min_slide
	_look_drift = _look_drift + delta if drifting else 0.0
	var level := turbo_level(_look_drift)
	if car.is_multiplayer_authority():
		level = turbo_level(_drift_time)  # the driver's own computer knows exactly
	var wheelspin := on_ground and car.throttle > 0.8 and forward_speed < 4.0 and car.driver_id != 0
	for i in _sparks.size():
		_sparks[i].emitting = drifting and level > 0
		if level > 0:
			var colour := ORANGE if level == 2 else BLUE
			_sparks[i].color_ramp.set_color(1, colour)
			_sparks[i].color_ramp.set_color(_sparks[i].color_ramp.get_point_count() - 1, Color(colour, 0.0))
		_smoke[i].emitting = drifting or wheelspin
	if _skid != null:
		var target_db := skid_volume_db if (drifting or wheelspin) else -80.0
		_skid.volume_db = lerpf(_skid.volume_db, target_db, 1.0 - exp(-10.0 * delta))
	var riders := _local_riders()
	if drifting:
		for cat in riders:
			Seats.rumble(cat.player_id, 0.25, 0.15, 0.05)

	# --- Speed camera (only if one of OUR cats is in the car) ---
	if _base_arm < 0.0:
		_base_arm = car.camera_arm.spring_length
	var pull := camera_pullback * speed_amount * speed_amount if forward_speed > 0.0 else 0.0
	car.camera_arm.spring_length = lerpf(car.camera_arm.spring_length, _base_arm + pull, 1.0 - exp(-3.0 * delta))
	_rattle_left -= delta
	if top_speed_shake > 0.0 and speed_amount > 0.85 and on_ground and _rattle_left <= 0.0:
		_rattle_left = 0.25
		for cat in riders:
			Feedback.shake(cat.player_id, top_speed_shake)

	_velocity = vel


var _last_yaw: float = 0.0
var _rattle_left: float = 0.0


## A ring of dust cubes under the car (landings).
func _dust_puff() -> void:
	var dust := CarFx.particles(car.get_parent(), PackedColorArray([Color(0.7, 0.68, 0.65, 0.7), Color(0.4, 0.4, 0.4, 0.0)]),
		0.3, 20, 0.7, 4.0, Vector3.UP, 85.0, -2.0)
	dust.global_position = car.global_position + Vector3.UP * 0.1
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.emitting = true
	get_tree().create_timer(1.2).timeout.connect(dust.queue_free)
