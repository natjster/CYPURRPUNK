class_name CatMelee
extends Node3D
## CYPURRPUNK — the MELEE button (F / middle mouse / pad RB): node Player > Melee.
##
## What the button does depends on your paws:
##   * A THROWABLE weapon (the NEON BAT) -> THROW it like a BOOMERANG (also RIGHT MOUSE / LT, sent here by
##     ItemManager as throw_next). It spins out, bonks the first VAC-COP / rival cat / car it hits (dazing
##     VAC-COPs), turns round and swoops back into your paw (bonking things on the way back too). Two bats
##     = throw the left one, then the right one while the first is still out.
##   * Nothing in your LEFT paw -> SCRATCH with your bare claws: fast swipes, right paw, left paw, then
##     a big X RAKE with both. Hold the button to keep scratching. Neon claw marks rip across the air
##     in front of you, the cat lunges and pounces into each swipe, the camera punches, and a hit
##     freezes the claw marks for a split second (hit-stop) with sparks.
##   * Anything else in the left paw (a pistol, the tuna...) -> nothing.
##
## Like every weapon, it doesn't work in the sewers' safe zone. All the numbers are in the Inspector
## (click Player in scenes/player.tscn, then the Melee node). Hits go through the hit framework
## (scripts/hit.gd), exactly like the bat: VAC-COPs, rival cats and cars all take them.
##
## Multiplayer: the scratcher's computer finds what it hit and hands out the Hits (like the bat),
## then tells every computer to draw the swipe (show_scratch). A throw never takes the bat out of your
## inventory: every computer hides the bat in your paw and flies a spinning copy out and back
## (show_throw + _update_flights); only the thrower's computer hands out the Hits.

@export_group("Scratch")
## Swipes per second while you hold the button.
@export var scratch_rate: float = 4.5
## Damage of one swipe (the X RAKE does Rake Damage times this).
@export var scratch_damage: int = 14
@export_range(0.0, 1.0) var scratch_crit_chance: float = 0.1
## How far in front of you a swipe reaches, and how wide it is (metres to each side).
@export var scratch_range: float = 1.7
@export var scratch_width: float = 0.9
## Shoves: rival cats (sideways / up), cars, VAC-COPs (metres per second).
@export var scratch_cat_knockback: float = 4.0
@export var scratch_cat_hop: float = 1.5
@export var scratch_car_impulse: float = 30.0
@export var scratch_enemy_knockback: float = 3.0
## The cat lurches into each swipe this fast (metres per second; 0 = stand still).
@export var scratch_lunge: float = 3.5

@export_group("Scratch Combo")
## Keep scratching: RIGHT swipe -> LEFT swipe -> X RAKE (both paws). Wait longer than this between
## swipes (seconds) and it starts over.
@export var combo_window: float = 0.55
## The X RAKE: damage x this, shove x this, VAC-COPs dazed this long (seconds).
@export var rake_damage: float = 2.0
@export var rake_push: float = 2.0
@export var rake_stun: float = 0.4

@export_group("Scratch Feel")
## Camera jolt when a swipe connects / when the rake connects (0 = none, 1 = huge).
@export_range(0.0, 1.0) var hit_shake: float = 0.16
@export_range(0.0, 1.0) var rake_shake: float = 0.32
## HIT-STOP: the claw marks freeze this long when a swipe connects (seconds).
@export var hit_stop: float = 0.06
## Camera punch on every swipe: roll (degrees, random side), zoom (FOV degrees), nod (degrees).
@export var camera_roll_degrees: float = 2.5
@export var camera_fov_punch: float = 2.0
@export var camera_nod_degrees: float = -0.8
## POUNCE: the cat dips its nose into each swipe (radians) and shoots forward this far (metres).
@export var pounce_pitch: float = 0.2
@export var pounce_forward: float = 0.18
## The front paw swings up this far (radians) before raking down.
@export var paw_raise: float = 2.4
## Sounds (res://sounds/sfx/, no .wav): the swipe whoosh and the claws connecting.
@export var swipe_sound: String = "swing"
@export var hit_sound: String = "scratch"

@export_group("Claw Marks")
## The neon CLAW MARKS that rip across the air in front of you.
@export var claw_color: Color = Color(1.0, 0.35, 0.8)
## How long one mark is, how thick (metres), and the space between the three marks.
@export var claw_length: float = 1.15
@export var claw_width: float = 0.1
@export var claw_gap: float = 0.16
## How long a mark takes to rip across (seconds), and to fade out after.
@export var claw_wipe: float = 0.06
@export var claw_fade: float = 0.26
## How far in front of the cat the marks are drawn, and how high (metres).
@export var claw_distance: float = 0.95
@export var claw_height: float = 0.5
## SPARKS where a swipe hits (0 = none).
@export var spark_count: int = 10

@export_group("Throw")
## THE BOOMERANG BAT. How fast it flies OUT (metres per second), how much it aims up above where you
## look, and how much it dips on the way (gravity, metres per second per second; 0 = dead straight).
@export var throw_speed: float = 24.0
@export var throw_lift: float = 0.1
@export var throw_gravity: float = 3.0
## How long it flies OUT before it turns round (seconds; x Throw Speed = its reach). It also turns
## round early when it bonks something or hits a wall.
@export var throw_out_seconds: float = 0.45
## How fast it comes BACK (metres per second; it chases you if you run), and how wide it swoops out
## to one side on the way (0 = straight back, 1 = a big curve).
@export var throw_return_speed: float = 20.0
@export_range(0.0, 2.0) var throw_curve: float = 0.8
## It's CAUGHT when it gets this close to you (metres), or after this long coming back (seconds).
@export var throw_catch_distance: float = 0.8
@export var throw_return_max_seconds: float = 2.5
## Things it bonks on the way BACK take this share of the throw's damage (0 = it only hits going out).
@export_range(0.0, 2.0) var throw_return_damage: float = 0.6
## How close it must pass to something to bonk it (metres).
@export var throw_radius: float = 0.5
## Spins per second while it flies.
@export var throw_spin: float = 3.0
## Seconds between two throws (or a throw and a scratch).
@export var throw_cooldown: float = 0.5

## The cat this belongs to (the Player node).
@onready var cat: CatPlayer = get_parent() as CatPlayer

var _cooldown: float = 0.0
var _combo_step: int = 0  # 0 right swipe, 1 left swipe, 2 X RAKE
var _combo_until: float = 0.0
## Stand-in "weapons" the Hits point at (the hit framework reads a hit's weapon for its shove
## numbers). Not in the scene tree; freed with this node.
var _claws: MeleeWeapon
var _thrown: MeleeWeapon
## Bats of ours out flying (every computer): [{node, held, points, out, time, returning, ...}].
var _flights: Array = []
var _rng := RandomNumberGenerator.new()
## The swipe animation (every computer): which paw (0 right, 1 left, 2 both) and how far through it (0..1+).
var _anim_paw: int = 0
var _anim_time: float = 99.0
var _anim_freeze: float = 0.0
## Claw marks being drawn: [{start, dir, side, age, freeze, hot}] in world space.
var _marks: Array = []
var _mesh: ImmediateMesh
var _mesh_node: MeshInstance3D
## For the test line: swipes made, and what the last swipe / throw did.
var scratches: int = 0
var last_result: String = ""

const SWIPE_TIME := 0.16  # how long the paw / body pounce takes (seconds)


func _ready() -> void:
	_rng.randomize()
	_claws = MeleeWeapon.new()
	_thrown = MeleeWeapon.new()
	_mesh = ImmediateMesh.new()
	_mesh_node = MeshInstance3D.new()
	_mesh_node.name = "ClawMarks"
	_mesh_node.mesh = _mesh
	_mesh_node.top_level = true  # world space: the marks stay where they were ripped
	_mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # glows on the dark street
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	_mesh_node.material_override = material
	add_child(_mesh_node)


func _exit_tree() -> void:
	for stand_in in [_claws, _thrown]:
		if is_instance_valid(stand_in):
			stand_in.free()


## Owner only, every physics frame (scripts/items/item_manager.gd _use_held_items): the MELEE button.
## allowed = not in a menu / the safe zone.
func melee_tick(allowed: bool, pressed: bool, just_pressed: bool, delta: float) -> void:
	_cooldown -= delta
	if not allowed or not pressed or _cooldown > 0.0 or cat.riding_car != null:
		return
	var items := ItemManager.instance
	var left := items.held_item(cat, 1)
	var right := items.held_item(cat, 0)
	var two_paws := right != null and right.data != null and right.data.hands == 2
	if _is_throwable(left) or _is_throwable(right):
		if just_pressed:
			throw_next()  # (the MELEE button throws a bat too, like right click)
		if left != null:
			return
	if left == null and not two_paws:
		_scratch()


## Is this a BOOMERANG weapon (Throwable ticked) that's in our paw right now (not out flying)?
func _is_throwable(item: HeldItem) -> bool:
	return item is MeleeWeapon and (item as MeleeWeapon).throwable and not (item as MeleeWeapon).in_flight


## Owner only: RIGHT MOUSE / LT (or the MELEE button) with a bat. Throws the LEFT paw's bat first; if
## that one is already out flying, the RIGHT paw's (two bats = throw one, then the other while the
## first is still coming back). The right paw's bat only flies when the left paw is free or a bat
## (a gun in the left paw keeps right click for itself). Returns true if something was thrown.
func throw_next() -> bool:
	if _cooldown > 0.0 or cat.riding_car != null:
		return false
	var items := ItemManager.instance
	var left := items.held_item(cat, 1)
	var right := items.held_item(cat, 0)
	if _is_throwable(left):
		_throw(left as MeleeWeapon, 1)
		return true
	var left_ok := left == null or (left is MeleeWeapon and (left as MeleeWeapon).throwable)
	if _is_throwable(right) and left_ok:
		_throw(right as MeleeWeapon, 0)
		return true
	return false


# --- SCRATCH ---

## Owner only: one claw swipe. Finds everything in a box in front of us and hands out Hits.
func _scratch() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_cooldown = 1.0 / maxf(scratch_rate, 0.1)
	if now > _combo_until:
		_combo_step = 0
	var step := _combo_step
	var rake := step == 2
	_combo_step = (step + 1) % 3
	_combo_until = now + combo_window
	cat.aim_until = now + 0.3  # the cat turns to face the swipe
	scratches += 1

	var look := -cat.camera.global_basis.z
	var forward := Vector3(look.x, 0, look.z).normalized()
	if forward == Vector3.ZERO:
		forward = -cat.cat_model.global_basis.z
	var reach := 1.2 if rake else 1.0
	var depth := scratch_range * reach
	var centre := cat.global_position + forward * (depth * 0.5 + 0.1) + Vector3.UP * 0.3
	var box := BoxShape3D.new()
	box.size = Vector3(scratch_width * 2.0 * reach, 2.4, depth)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.looking_at(forward, Vector3.UP), centre)
	query.exclude = _own_rids()
	_set_up_claws()
	var paws := Upgrades.melee_multiplier(cat.player_id)  # HEAVY PAWS count for claws too
	var hit_spots := PackedVector3Array()
	var already := {}
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var target := Hit.target_of(result.collider)
		if target == null or already.has(target) or target == cat:
			continue
		if target is CatPlayer and (target as CatPlayer).team == cat.team:
			continue  # our own gang: claws in
		already[target] = true
		var spot: Vector3 = (target as Node3D).global_position if target is Node3D else centre
		var info := _claws._make_hit(forward, spot + Vector3.UP * 0.4)
		info.damage = roundi(info.damage * paws * (rake_damage if rake else 1.0))
		info.enemy_push *= paws * (rake_push if rake else 1.0)
		if rake:
			info.push_scale = rake_push
			info.stun_seconds = maxf(info.stun_seconds, rake_stun)
		if target.receive_hit(info):
			Hud.damage_number(info.position, info.damage, info.crit or rake, cat.slot)
		hit_spots.append(spot + Vector3.UP * 0.4)
	var connected := not already.is_empty()
	# FEEL: camera punch every swipe, a jolt + buzz when it connects, and a lunge forwards.
	cat.aim.kick(camera_nod_degrees, 0.0, 1.0, camera_roll_degrees * (1.6 if rake else 1.0), camera_fov_punch * (1.5 if rake else 1.0), 0.0, 0.0)
	if connected:
		Feedback.shake(cat.player_id, rake_shake if rake else hit_shake)
	Seats.rumble(cat.player_id, 0.35 if connected else 0.15, 0.25 if rake else 0.0, 0.06)
	if scratch_lunge > 0.0 and cat.is_on_floor():
		var lunge := scratch_lunge * (1.4 if rake else 1.0)
		cat.velocity.x += forward.x * lunge
		cat.velocity.z += forward.z * lunge
	last_result = "scratch step=%d hits=%d" % [step, already.size()]
	show_scratch.rpc(step, connected, hit_spots, forward)


## The claws' stand-in weapon gets this node's numbers (the hit framework reads them).
func _set_up_claws() -> void:
	_claws.holder = cat
	_claws.damage = scratch_damage
	_claws.crit_chance = scratch_crit_chance
	_claws.cat_knockback = scratch_cat_knockback
	_claws.cat_hop = scratch_cat_hop
	_claws.car_impulse = scratch_car_impulse
	_claws.enemy_knockback = scratch_enemy_knockback
	_claws.city_heat_per_hit = 0.5  # claws are quieter than a bat
	_claws.hud_name = "CLAWS"


## Everyone: play a swipe. step 0 right paw, 1 left paw, 2 X RAKE (both); forward = which way.
@rpc("any_peer", "call_local", "unreliable_ordered")
func show_scratch(step: int, connected: bool, hit_spots: PackedVector3Array, forward: Vector3) -> void:
	if cat == null or multiplayer.get_remote_sender_id() != PlayerId.peer_of(cat.player_id):
		return  # only the cat's own computer may make it scratch
	step = clampi(step, 0, 2)
	forward = Vector3(forward.x, 0, forward.z).normalized()
	if forward == Vector3.ZERO:
		forward = -cat.cat_model.global_basis.z
	cat.aim_until = Time.get_ticks_msec() / 1000.0 + 0.3
	_anim_paw = step
	_anim_time = 0.0
	_anim_freeze = hit_stop if connected else 0.0
	Sound.play_at(swipe_sound, cat.global_position, -7.0 if step < 2 else -4.0)
	if connected:
		Sound.play_at(hit_sound, cat.global_position + forward, -2.0 if step < 2 else 1.0)
	for spot in hit_spots:
		_sparks(spot)
	# The CLAW MARKS: three neon rips across the air in front of the cat, diagonal. The right paw
	# rips down to the left, the left paw down to the right, the X RAKE does both at once.
	var right := forward.cross(Vector3.UP).normalized()
	var middle := cat.global_position + forward * claw_distance + Vector3.UP * claw_height
	var sides: Array = [1.0] if step == 0 else ([-1.0] if step == 1 else [1.0, -1.0])
	var length := claw_length * (1.25 if step == 2 else 1.0)
	for side in sides:
		var dir: Vector3 = (-right * side * 0.75 + Vector3.DOWN * 0.66).normalized()  # (top -> bottom)
		var across := dir.cross(forward).normalized()  # the 3 marks sit side by side across the rip
		for i in 3:
			var start: Vector3 = middle - dir * length * 0.5 + across * claw_gap * (i - 1)
			_marks.append({"start": start, "dir": dir, "length": length * (0.85 if i != 1 else 1.0),
				"age": -0.012 * i, "freeze": _anim_freeze, "hot": connected})


## Every frame: draw the claw marks (rip in, freeze on a hit, fade out).
func _process(delta: float) -> void:
	_update_flights(delta)  # thrown boomerang bats
	_cooldown_visuals(delta)
	_mesh.clear_surfaces()
	_mesh_node.global_transform = Transform3D.IDENTITY
	if _marks.is_empty():
		return
	var view_cam := get_viewport().get_camera_3d()
	for mark in _marks:
		var age: float = mark.age
		var rip := clampf(age / maxf(claw_wipe, 0.001), 0.0, 1.0)  # how much of it has ripped across
		if rip <= 0.0:
			continue
		rip = 1.0 - pow(1.0 - rip, 3.0)  # fast start, eases in at the end: a SLASH
		var fade_age := maxf(age - claw_wipe, 0.0)
		var life := clampf(1.0 - fade_age / maxf(claw_fade, 0.001), 0.0, 1.0)
		var start: Vector3 = mark.start
		var dir: Vector3 = mark.dir
		var length: float = mark.length * rip
		# Face the camera: the ribbon's width goes sideways to the view.
		var to_cam := (view_cam.global_position - start).normalized() if view_cam != null else Vector3.BACK
		var side := dir.cross(to_cam).normalized()
		var hot: Color = claw_color.lerp(Color.WHITE, 0.55 if mark.hot else 0.25)
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var segments := 6
		for s in segments + 1:
			var t := float(s) / segments
			var point := start + dir * length * t
			# Thick in the middle, sharp at both ends (a claw rip), thinner as it fades.
			var width := claw_width * sin(PI * t) * (0.5 + 0.5 * life) * (1.3 if mark.hot else 1.0)
			# The newest end (where the claw is now) is the hottest.
			var colour := hot.lerp(Color.WHITE, (t * 0.6) * (1.0 - fade_age * 4.0))
			colour.a = life * 0.95
			_mesh.surface_set_color(colour)
			_mesh.surface_add_vertex(point - side * width)
			_mesh.surface_set_color(colour)
			_mesh.surface_add_vertex(point + side * width)
		_mesh.surface_end()


func _cooldown_visuals(delta: float) -> void:
	for mark in _marks:
		if mark.freeze > 0.0 and mark.age >= claw_wipe:
			mark.freeze -= delta  # HIT-STOP: fully ripped, then held for a beat before fading
		else:
			mark.age += delta
	_marks = _marks.filter(func(m): return m.age < claw_wipe + claw_fade)
	if _anim_freeze > 0.0 and _anim_time >= SWIPE_TIME * 0.45:
		_anim_freeze -= delta  # the paw / pounce freezes mid-swipe too
	else:
		_anim_time += delta


## The swipe pose for one front leg (cat_player.gd _animate_legs_and_tail, every computer):
## Vector3(raise angle, sideways angle, how much it wins over the walk swing 0..1). side 0 = right leg.
func paw_pose(side: int) -> Vector3:
	var t := _anim_time / SWIPE_TIME
	if t >= 1.0:
		return Vector3.ZERO
	var uses := _anim_paw == 2 or _anim_paw == side
	if not uses:
		return Vector3.ZERO
	# Up fast (0 -> 0.3), RAKE down hard (0.3 -> 0.6), settle (0.6 -> 1).
	var raise: float
	if t < 0.3:
		raise = paw_raise * (t / 0.3)
	elif t < 0.6:
		raise = lerpf(paw_raise, -0.3, (t - 0.3) / 0.3)
	else:
		raise = lerpf(-0.3, 0.0, (t - 0.6) / 0.4)
	var sweep := (0.5 if side == 0 else -0.5) * sin(PI * t)
	return Vector3(raise, sweep, 1.0 - smoothstep(0.75, 1.0, t))


## The POUNCE: how far the cat dips its nose (radians, negative = nose down; owner adds it to the
## model's lean) and slides forward (metres) right now.
func body_pitch() -> float:
	return -pounce_pitch * _pounce_curve()


func body_forward() -> float:
	return pounce_forward * _pounce_curve()


func _pounce_curve() -> float:
	var t := _anim_time / SWIPE_TIME
	if t >= 1.0:
		return 0.0
	var big := 1.4 if _anim_paw == 2 else 1.0
	# Snap in (0 -> 0.35), hold, ease back out.
	return big * (smoothstep(0.0, 0.35, t) if t < 0.35 else 1.0 - smoothstep(0.45, 1.0, t))


func _sparks(where: Vector3) -> void:
	var world: Node = Game.instance if Game.instance != null else get_tree().root
	if spark_count > 0:
		var sparks := CPUParticles3D.new()
		sparks.one_shot = true
		sparks.explosiveness = 1.0
		sparks.amount = spark_count
		sparks.lifetime = 0.3
		sparks.direction = Vector3.UP
		sparks.spread = 160.0
		sparks.initial_velocity_min = 2.5
		sparks.initial_velocity_max = 6.0
		sparks.gravity = Vector3(0, -14, 0)
		var bit := BoxMesh.new()
		bit.size = Vector3(0.06, 0.06, 0.06)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.vertex_color_use_as_albedo = true
		bit.material = glow
		sparks.mesh = bit
		var ramp := Gradient.new()
		ramp.set_color(0, Color.WHITE)
		ramp.set_color(1, claw_color)
		sparks.color_ramp = ramp
		world.add_child(sparks)
		sparks.global_position = where
		sparks.emitting = true
		get_tree().create_timer(0.7).timeout.connect(sparks.queue_free)
	var light := OmniLight3D.new()
	light.light_color = claw_color.lerp(Color.WHITE, 0.4)
	light.light_energy = 2.0
	light.omni_range = 2.5
	world.add_child(light)
	light.global_position = where
	var fade := light.create_tween()
	fade.tween_property(light, "light_energy", 0.0, 0.15)
	fade.tween_callback(light.queue_free)


# --- THROW (BOOMERANG) ---

## Owner only: throw the weapon in our LEFT paw. Works out its flight OUT now (a straight-ish line;
## the first thing it passes close to gets bonked and it turns round there, or at a wall, or at the end
## of its reach), then everyone's computer flies it back to our paw (show_throw / _update_flights).
## The bat never leaves our inventory: it's just hidden while it's out.
func _throw(weapon: MeleeWeapon, hand: int = 1) -> void:
	_cooldown = throw_cooldown
	weapon.in_flight = true  # (right away on our side, so the next press throws the OTHER paw)
	var look := -cat.camera.global_basis.z
	var flat := Vector3(look.x, 0, look.z).normalized()
	if flat == Vector3.ZERO:
		flat = -cat.cat_model.global_basis.z
	var velocity := (look + Vector3.UP * throw_lift).normalized() * throw_speed
	var spot := cat.global_position + Vector3.UP * 0.7 + flat * 0.4
	var space := get_world_3d().direct_space_state
	var points := PackedVector3Array([spot])
	var step := 1.0 / 60.0
	var time := 0.0
	var target: Node = null
	var stopped := false
	while time < throw_out_seconds and not stopped:
		var next := spot + velocity * step
		velocity.y -= throw_gravity * step
		time += step
		target = _throw_target_near(space, next, [])  # anything to bonk near here?
		# A wall or the ground in the way?
		var ray := PhysicsRayQueryParameters3D.create(spot, next)
		ray.exclude = _own_rids()
		var wall := space.intersect_ray(ray)
		if target != null:
			stopped = true
		elif wall:
			next = wall.position - (next - spot).normalized() * 0.2  # (turn round a hair off the wall)
			stopped = true
		spot = next
		points.append(spot)
	# The Hit, ready now but handed out when the bat GETS there.
	_copy_weapon_numbers(weapon, _thrown)
	if target != null:
		get_tree().create_timer(time).timeout.connect(_throw_landed.bind(target, _throw_hit(weapon, flat, spot, 1.0)))
	last_result = "throw item=%s out_seconds=%.2f target=%s turn=%s" % [weapon.data.id, time, target.name if target != null else "none", spot]
	Seats.rumble(cat.player_id, 0.4, 0.2, 0.08)
	cat.aim.kick(-1.0, 0.0, 1.0, camera_roll_degrees, camera_fov_punch, 0.0, 0.0)
	cat.aim_until = Time.get_ticks_msec() / 1000.0 + 0.4
	show_throw.rpc(weapon.data.id, hand, points, time, target != null)


## Owner only: the first enemy / rival cat / car within throw_radius of `where` (not us, not our gang,
## not anything in `skip`), or null.
func _throw_target_near(space: PhysicsDirectSpaceState3D, where: Vector3, skip: Array) -> Node:
	var ball := SphereShape3D.new()
	ball.radius = throw_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.exclude = _own_rids()
	query.transform = Transform3D(Basis.IDENTITY, where)
	for result in space.intersect_shape(query, 32):
		var found := Hit.target_of(result.collider)
		if found == null or found == cat or skip.has(found) or (found is CatPlayer and (found as CatPlayer).team == cat.team):
			continue
		return found
	return null


## Owner only: the Hit a thrown weapon gives (scale = Throw Return Damage on the way back).
func _throw_hit(weapon: MeleeWeapon, flat: Vector3, spot: Vector3, scale: float) -> Hit:
	var info := _thrown._make_hit(flat, spot)
	var paws := Upgrades.melee_multiplier(cat.player_id)
	info.damage = roundi(weapon.damage * weapon.throw_damage * paws * scale * (weapon.crit_multiplier if info.crit else 1.0))
	info.enemy_push = (flat + Vector3.UP * 0.4) * weapon.enemy_knockback * weapon.throw_push * paws * scale
	info.push_scale = weapon.throw_push * scale
	info.stun_seconds = maxf(info.stun_seconds, weapon.throw_stun)
	return info


## Owner only: the thrown bat reached what it was going to bonk.
func _throw_landed(target: Node, info: Hit) -> void:
	if not is_instance_valid(target) or not is_instance_valid(cat):
		return
	if target.receive_hit(info):
		Hud.damage_number(info.position, info.damage, info.crit, cat.slot)
	Feedback.shake(cat.player_id, 0.3)


## A throw's hit points at this stand-in, a copy of the thrown weapon's numbers.
func _copy_weapon_numbers(from: MeleeWeapon, to: MeleeWeapon) -> void:
	to.holder = cat
	for property in ["damage", "crit_chance", "crit_multiplier", "cat_knockback", "cat_hop", "car_impulse",
			"car_launch", "enemy_knockback", "stun_seconds", "city_heat_per_hit", "hud_name"]:
		to.set(property, from.get(property))


## Everyone: hide the bat in our paw, fly a spinning copy OUT along `points` (bonk at the end if it hit
## something), then _update_flights curves it BACK to our paw.
@rpc("any_peer", "call_local", "reliable")
func show_throw(item_id: String, hand: int, points: PackedVector3Array, seconds: float, hit_something: bool) -> void:
	if cat == null or multiplayer.get_remote_sender_id() != PlayerId.peer_of(cat.player_id) or points.size() < 2:
		return
	var data: ItemData = ItemManager.instance.catalog.get(item_id)
	if data == null or data.scene == null:
		return
	var held := ItemManager.instance.held_item(cat, clampi(hand, 0, 1))
	if held != null:
		held.visible = false  # it's out flying
		if held is MeleeWeapon:
			(held as MeleeWeapon).in_flight = true
	var world: Node = Game.instance if Game.instance != null else get_tree().root
	var flying := data.scene.instantiate() as Node3D
	flying.name = "Thrown"
	flying.scale = Vector3.ONE * data.hold_scale
	world.add_child(flying)
	flying.global_position = points[0]
	var glow := OmniLight3D.new()
	glow.light_color = data.glow_color if data.glow_color.a > 0.0 else claw_color
	glow.light_energy = 1.2
	glow.omni_range = 2.0
	flying.add_child(glow)
	Sound.play_at("swing", points[0], -2.0)
	var spin_axis := (points[points.size() - 1] - points[0]).cross(Vector3.UP).normalized()
	if spin_axis == Vector3.ZERO:
		spin_axis = Vector3.RIGHT
	_flights.append({"node": flying, "held": held, "points": points, "out": maxf(seconds, 0.05), "time": 0.0,
		"returning": false, "back_time": 0.0, "axis": spin_axis, "scale": data.hold_scale, "hit": hit_something,
		"skip": [], "side": 1.0 if _rng.randf() < 0.5 else -1.0})


## Every frame (every computer): move the thrown bats. OUT = along the worked-out path; BACK = homing
## on our paw with a sideways swoop, spinning the whole time. The owner also bonks things it passes on
## the way back. Close enough = CAUGHT: the bat is back in the paw.
func _update_flights(delta: float) -> void:
	for flight in _flights.duplicate():
		var flying := flight.node as Node3D
		if not is_instance_valid(flying) or not is_instance_valid(cat):
			_flights.erase(flight)
			continue
		flight.time += delta
		var points: PackedVector3Array = flight.points
		var melee := flying as MeleeWeapon
		if melee != null:
			melee._trail_until = Time.get_ticks_msec() / 1000.0 + 0.05  # its neon trail follows it
		flying.global_basis = Basis(flight.axis, -flight.time * throw_spin * TAU).scaled(Vector3.ONE * flight.scale)  # END OVER END
		if not flight.returning:
			var t := clampf(flight.time / flight.out, 0.0, 1.0)
			var along := t * (points.size() - 1)
			var i := mini(int(along), points.size() - 2)
			flying.global_position = points[i].lerp(points[i + 1], along - i)
			if t >= 1.0:
				flight.returning = true
				var end := points[points.size() - 1]
				if flight.hit:
					Sound.play_at("bonk", end, 0.0)
					if melee != null:
						melee._impact(end, false)
				else:
					Sound.play_at("swing", end, -6.0)  # whoosh as it turns round
			continue
		# BACK: fly at our paw (which may have moved), curving out to one side early on.
		flight.back_time += delta
		var paw := cat.global_position + Vector3.UP * 0.7
		var to_paw := paw - flying.global_position
		var distance := to_paw.length()
		if distance < throw_catch_distance or flight.back_time > throw_return_max_seconds:
			_catch(flight)
			continue
		var side_dir := to_paw.cross(Vector3.UP).normalized() * float(flight.side)
		var swoop := clampf(1.0 - flight.back_time / 0.5, 0.0, 1.0) * throw_curve
		var move := (to_paw.normalized() + side_dir * swoop).normalized() * throw_return_speed * delta
		if move.length() > distance:
			move = to_paw
		var before := flying.global_position
		flying.global_position += move
		# The owner bonks anything it passes on the way back (once each, never what it hit going out).
		if cat.is_multiplayer_authority() and throw_return_damage > 0.0:
			var found := _throw_target_near(get_world_3d().direct_space_state, flying.global_position, flight.skip)
			if found != null:
				flight.skip.append(found)
				var weapon := flight.held as MeleeWeapon
				if weapon != null and is_instance_valid(weapon):
					var dir := flying.global_position - before
					var flat := Vector3(dir.x, 0, dir.z).normalized()
					_throw_landed(found, _throw_hit(weapon, flat, flying.global_position, throw_return_damage))
					Sound.play_at("bonk", flying.global_position, -2.0)
					weapon._impact(flying.global_position, false)
					last_result += " return_hit=%s" % found.name


## Everyone: the bat is back. Show it in the paw again.
func _catch(flight: Dictionary) -> void:
	_flights.erase(flight)
	var flying := flight.node as Node3D
	if is_instance_valid(flying):
		Sound.play_at("cone_bounce", flying.global_position, -8.0)  # *thwap* into the paw
		flying.queue_free()
	var held = flight.held
	if held != null and is_instance_valid(held):
		(held as Node3D).visible = true
		if held is MeleeWeapon:
			(held as MeleeWeapon).in_flight = false
	if is_instance_valid(cat) and cat.is_multiplayer_authority():
		Seats.rumble(cat.player_id, 0.3, 0.1, 0.06)
		last_result += " caught=true"


## Is a throw of ours still out flying? (For tests.)
func is_throw_out() -> bool:
	return not _flights.is_empty()


func _own_rids() -> Array[RID]:
	var skip: Array[RID] = [cat.get_rid()]
	if cat.riding_car != null:
		skip.append(cat.riding_car.get_rid())
	return skip
