class_name CatMoves
extends Node
## CAT MOVES: the feline parkour that makes running around fun.
## A child node of the Player (scenes/player.tscn: Player > Moves), so every knob is in one place:
## open scenes/player.tscn, click "Moves" in the Scene panel, and the Inspector shows them all.
##
##   SNAPPY JUMPS  coyote time (you can still jump a split second after running off a ledge), a jump
##                 buffer (press jump just BEFORE you land and it still counts), tap = short hop,
##                 hold = full jump, and the cat falls faster than it rises (less floaty).
##   POUNCE        jump during ZOOMIES = a long, low leap forward. Keeps its speed in the air.
##   WALL KICK     jump while touching a wall in mid-air = kick off it with a claw scratch. Two per
##                 jump: bounce between two alley walls to climb. Landing refills them.
##   CLAMBER       in mid-air, push into a ledge just above your paws and the cat scrambles up onto it
##                 (crates, bins, counters, low walls).
##   SQUASH & STRETCH  the body stretches in the air and squashes with a wobble when it lands, and
##                 tilts nose-up while rising / nose-down while falling. Worked out from how the cat
##                 moves, on EVERY computer, so other players see it with no network messages.
##
## How it plugs in: CatPlayer._physics_process (our own cats only) calls jump(), air_target(),
## clamber() and gravity_multiplier(); CatPlayer._update_footsteps (every cat on every computer)
## calls animate(). This node only changes the cat's velocity and its model's scale.

@export_group("Snappy Jumps")
## Seconds after running off a ledge that a jump still works (feels fair, not "I DID press it!").
@export var coyote_seconds: float = 0.12
## Seconds BEFORE landing that a jump press is remembered and fires the moment the paws touch down.
@export var jump_buffer_seconds: float = 0.12
## Let go of jump while still going up: the upward speed is multiplied by this (0.45 = a short hop).
## 1 = off (every jump is full height).
@export var short_hop_cut: float = 0.45
## Gravity multiplier while FALLING (1 = same as going up). Higher = less floaty, more "thwump".
@export var fall_gravity: float = 1.6
## The fastest the cat can fall (metres per second).
@export var max_fall_speed: float = 22.0
## How much you can steer in mid-air (1 = as much as on the ground, 0 = not at all).
## Lower keeps your momentum: pounces and wall kicks carry you.
@export var air_control: float = 0.5

@export_group("Pounce")
## Jump during ZOOMIES: this much extra forward speed (metres per second). 0 = no pounce.
@export var pounce_boost: float = 3.5
## Pounce height compared to a normal jump (0.9 = a bit lower and longer).
@export var pounce_lift: float = 0.9

@export_group("Wall Kick")
## Wall kicks allowed per jump (landing refills them). 0 = no wall kicks.
@export var wall_kicks: int = 2
## How hard the kick pushes you away from the wall (metres per second).
@export var wall_kick_push: float = 5.5
## Kick height compared to a normal jump.
@export var wall_kick_lift: float = 1.0
## Seconds after a kick that steering is ignored, so the kick really carries you off the wall.
@export var wall_kick_lock: float = 0.2
## How close a wall has to be to kick off it (metres from the cat's middle; the cat is 0.3 wide).
@export var wall_kick_reach: float = 0.6

@export_group("Clamber")
## The highest a ledge can be above the cat's paws for it to scramble up (metres). 0 = off.
@export var clamber_reach: float = 1.1
## How far above the ledge the scramble lifts the cat, so it clears the edge (metres).
@export var clamber_clearance: float = 0.35

@export_group("Squash and Stretch")
## How much the body stretches tall while flying through the air (0.12 = 12% taller).
@export var air_stretch: float = 0.12
## How much it squashes on a big landing (0.35 = 35% shorter for a moment).
@export var land_squash: float = 0.35
## Wobble speed of the squash springing back (higher = quicker, tighter wobble).
@export var squash_spring: float = 16.0
## Wobble damping (lower = more boing, 1 = no wobble at all).
@export var squash_damping: float = 0.35
## Nose tilt in the air: up while rising, down while falling (degrees). Keep under 20.
@export var air_pitch_degrees: float = 14.0
## Falling faster than this (metres per second) when landing = a full squash and a soft "thump".
@export var hard_landing_speed: float = 7.0

# --- Owner-only state (our own cat's _physics_process) ---
var _coyote_left: float = 0.0   # seconds a ground jump is still allowed
var _buffer_left: float = 0.0   # seconds a jump press is still remembered
var _hop_rising := false        # a ground jump is going up and can still be cut short
var _kicks_left: int = 0        # wall kicks left this jump
var _lock_left: float = 0.0     # seconds steering is still ignored after a wall kick
var _pounce_speed: float = 0.0  # > 0 while flying through a pounce: the speed to keep
var _clamber_cooldown: float = 0.0

# --- Look state (every computer, every cat) ---
var _squash: float = 0.0        # + = stretched tall, - = squashed flat
var _squash_speed: float = 0.0
var _was_grounded := true
var _last_vertical: float = 0.0

@onready var _cat: CatPlayer = get_parent()


## Gravity multiplier for this frame: falling pulls harder than rising (less floaty).
func gravity_multiplier(vertical_speed: float) -> float:
	return fall_gravity if vertical_speed < 0.0 else 1.0


## Owner, once a physics frame, before moving. Handles ground jumps (with coyote time, the jump buffer
## and short hops), POUNCES and WALL KICKS. Changes _cat.velocity.
## Returns what happened: "jump", "pounce", "kick" or "" (nothing: CatPlayer may still do its catdip
## mid-air jump then).
func jump(delta: float, on_floor: bool, pressed: bool, held: bool, direction: Vector3, zooming: bool) -> String:
	var jump_speed := _cat.jump_velocity
	_lock_left = maxf(_lock_left - delta, 0.0)
	_clamber_cooldown = maxf(_clamber_cooldown - delta, 0.0)
	if on_floor:
		_coyote_left = coyote_seconds
		_kicks_left = wall_kicks
		_pounce_speed = 0.0
		_lock_left = 0.0
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)
	_buffer_left = jump_buffer_seconds if pressed else maxf(_buffer_left - delta, 0.0)
	# The velocity clamp for falling lives here too (one place that runs every frame).
	_cat.velocity.y = maxf(_cat.velocity.y, -max_fall_speed)

	# SHORT HOP: let go of jump while still rising = stop rising sooner.
	if _hop_rising:
		if _cat.velocity.y <= 0.0:
			_hop_rising = false
		elif not held:
			_cat.velocity.y *= short_hop_cut
			_hop_rising = false

	# GROUND JUMP (or a POUNCE during zoomies).
	if _buffer_left > 0.0 and _coyote_left > 0.0:
		_buffer_left = 0.0
		_coyote_left = 0.0
		_hop_rising = true
		var flat := Vector3(_cat.velocity.x, 0.0, _cat.velocity.z)
		if zooming and pounce_boost > 0.0 and direction != Vector3.ZERO:
			# POUNCE: a long low leap in the direction you're pushing, faster than you were running.
			_pounce_speed = flat.length() + pounce_boost
			var leap := direction * _pounce_speed
			_cat.velocity = Vector3(leap.x, jump_speed * pounce_lift, leap.z)
			Sound.play_everywhere("jump", _cat.global_position, -5.0)
			Sound.play_everywhere("swing", _cat.global_position, -12.0)  # a little whoosh
			return "pounce"
		_cat.velocity.y = jump_speed
		Sound.play_everywhere("jump", _cat.global_position, -6.0)
		return "jump"

	# WALL KICK: in the air, a fresh jump press next to a wall.
	if pressed and not on_floor and _kicks_left > 0:
		var wall := _wall_normal_near()
		if wall != Vector3.ZERO:
			_kicks_left -= 1
			_buffer_left = 0.0
			_hop_rising = false
			# Keep some of the speed along the wall, swap the speed into it for a push away from it.
			var flat := Vector3(_cat.velocity.x, 0.0, _cat.velocity.z)
			var along := flat - wall * flat.dot(wall)
			var away := along * 0.5 + wall * wall_kick_push
			_cat.velocity = Vector3(away.x, jump_speed * wall_kick_lift, away.z)
			_pounce_speed = 0.0
			_lock_left = wall_kick_lock
			Sound.play_everywhere("scratch", _cat.global_position, -6.0)  # claws on the wall
			Sound.play_everywhere("jump", _cat.global_position, -9.0)
			return "kick"
	return ""


## Owner: true just after a wall kick (CatPlayer skips steering then and faces where it flies).
func steering_locked() -> bool:
	return _lock_left > 0.0


## Owner: how quickly speed changes this frame compared to on the ground (less steering in mid-air).
func acceleration_scale(on_floor: bool) -> float:
	return 1.0 if on_floor else air_control


## Owner: in the middle of a POUNCE, keep flying at the pounce's speed while you steer (instead of
## slowing down to normal running speed in mid-air).
func air_target(target: Vector3, on_floor: bool) -> Vector3:
	if on_floor or _pounce_speed <= 0.0 or target == Vector3.ZERO:
		return target
	return target.normalized() * maxf(target.length(), _pounce_speed)


## Owner, before moving: CLAMBER. In mid-air, pushing into a wall whose top is just above our paws?
## Pop up so we land on top of it. Two short rays: one down onto the ledge, one up to check there's
## room for a cat on it.
func clamber(on_floor: bool, direction: Vector3) -> bool:
	if clamber_reach <= 0.0 or on_floor or _clamber_cooldown > 0.0 or direction == Vector3.ZERO:
		return false
	var wall := _wall_normal_near()
	if wall == Vector3.ZERO or direction.dot(-wall) < 0.5:
		return false  # no wall, or we aren't pushing into it
	var feet := _cat.global_position  # (the Player's origin is at its paws)
	var over_ledge := feet - wall * 0.45
	var down := _ray(over_ledge + Vector3.UP * (clamber_reach + 0.05), over_ledge + Vector3.UP * 0.2)
	if down.is_empty() or (down["normal"] as Vector3).y < 0.7:
		return false  # no flat top within reach
	var ledge_top: Vector3 = down["position"]
	if not _ray(ledge_top + Vector3.UP * 0.05, ledge_top + Vector3.UP * 1.0).is_empty():
		return false  # no room up there (a ceiling or a shelf above)
	var rise := ledge_top.y - feet.y + clamber_clearance
	var needed := sqrt(2.0 * _cat.gravity * maxf(rise, 0.0))  # speed to go up exactly that far
	if _cat.velocity.y >= needed:
		return false  # already going up fast enough
	_cat.velocity.y = needed
	# A little shove onto the ledge so we don't hover at the edge.
	_cat.velocity.x -= wall.x * 1.5
	_cat.velocity.z -= wall.z * 1.5
	_hop_rising = false
	_clamber_cooldown = 0.35
	Sound.play_everywhere("scratch", _cat.global_position, -8.0)
	return true


## Owner: the nose tilt for the air (radians, CatPlayer's lean convention: + = nose DOWN).
## Nose up while rising, nose down while falling. 0 on the ground.
func air_lean(on_floor: bool, vertical_speed: float) -> float:
	if on_floor:
		return 0.0
	return -clampf(vertical_speed / maxf(_cat.jump_velocity, 0.1), -1.0, 1.0) * deg_to_rad(air_pitch_degrees)


## EVERY computer, every cat (from CatPlayer._update_footsteps): squash and stretch the model.
## vertical_speed = how fast the cat moved up (+) or down (-) this frame; grounded = on the floor
## (our own cat knows, other cats are guessed from their motion).
## Every computer: stretch the cat tall for a moment ("amount" = 0.25 -> 25% taller), then it
## springs back with the usual wobble. The MEOW shout uses it (cat_player.gd _show_taunt).
func puff(amount: float) -> void:
	_squash = clampf(amount, -0.5, 0.5)
	_squash_speed = 0.0


func animate(delta: float, vertical_speed: float, grounded: bool) -> void:
	var model := _cat.cat_model
	if model == null:
		return
	if absf(vertical_speed) > 30.0 or not _cat.visible:
		vertical_speed = 0.0  # a teleport, or hidden in a car
	var flopped := _cat.knocked_out or _cat.is_downed()
	# LANDING: a squash, harder the faster we came down (and a soft thump on a big drop).
	if grounded and not _was_grounded and _last_vertical < -3.0 and not flopped:
		var hard := clampf(-_last_vertical / hard_landing_speed, 0.35, 1.0)
		_squash = -land_squash * hard
		_squash_speed = 0.0
		if -_last_vertical >= hard_landing_speed:
			Sound.play_at("footstep", _cat.global_position, -2.0)
	_was_grounded = grounded
	_last_vertical = vertical_speed
	# In the air: stretch with speed. On the ground: spring back to normal (with a little wobble).
	var target := 0.0
	if not grounded and not flopped:
		target = clampf(absf(vertical_speed) / 8.0, 0.0, 1.0) * air_stretch
	var k := squash_spring
	_squash_speed += ((target - _squash) * k * k - 2.0 * squash_damping * k * _squash_speed) * delta
	_squash = clampf(_squash + _squash_speed * delta, -0.5, 0.5)
	# Taller = thinner and shorter = wider, so the cat looks like the same amount of cat.
	model.scale = Vector3(1.0 - _squash * 0.5, 1.0 + _squash, 1.0 - _squash * 0.5)


## The nearest wall within wall_kick_reach of the cat's middle (8 flat rays around it), as the
## direction pointing AWAY from the wall. Vector3.ZERO = no wall close enough.
func _wall_normal_near() -> Vector3:
	if _cat.is_on_wall():
		var normal := _cat.get_wall_normal()
		normal.y = 0.0
		if normal.length() > 0.5:
			return normal.normalized()
	var middle := _cat.global_position + Vector3.UP * 0.5
	var best := Vector3.ZERO
	var best_distance := INF
	for i in 8:
		var aim := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0)
		var hit := _ray(middle, middle + aim * wall_kick_reach)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit["normal"]
		if absf(normal.y) > 0.3:
			continue  # a slope or a floor, not a wall
		var distance := middle.distance_to(hit["position"])
		if distance < best_distance:
			best_distance = distance
			best = Vector3(normal.x, 0.0, normal.z).normalized()
	return best


## One ray through the world, hitting what the cat itself bumps into (not the cat).
func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, _cat.collision_mask, [_cat.get_rid()])
	return _cat.get_world_3d().direct_space_state.intersect_ray(query)
