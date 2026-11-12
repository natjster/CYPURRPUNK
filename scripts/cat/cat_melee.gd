class_name CatMelee
extends Node3D
## CYPURRPUNK — the MELEE button (F / middle mouse / pad RB): node Player > Melee.
##
## What the button does depends on your paws:
##   * A THROWABLE weapon (the NEON BAT) in your LEFT paw (offhand) -> THROW it. It spins through the
##     air, bonks the first VAC-COP / rival cat / car it hits (dazing VAC-COPs) and lands on the street,
##     where you pick it back up with E like any item.
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
## then tells every computer to draw the swipe (show_scratch). A throw asks the host to take the bat
## out of your paw and drop it where it lands (ItemManager.request_throw); every computer draws the
## spinning bat (show_throw).

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
## How fast the thrown bat flies (metres per second), how much it aims up above where you look, and
## how hard it falls (gravity, metres per second per second).
@export var throw_speed: float = 24.0
@export var throw_lift: float = 0.2
@export var throw_gravity: float = 14.0
## Longest flight before it just drops (seconds).
@export var throw_max_seconds: float = 1.4
## How close it must pass to something to bonk it (metres).
@export var throw_radius: float = 0.5
## Spins per second while it flies.
@export var throw_spin: float = 3.0
## Seconds before you can throw / scratch again after a throw.
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
	if left is MeleeWeapon and (left as MeleeWeapon).throwable:
		if just_pressed:
			_throw(left as MeleeWeapon)
		return
	if left == null and not two_paws:
		_scratch()


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


# --- THROW ---

## Owner only: throw the weapon in our LEFT paw. Works out its whole flight now (a falling arc, the
## first thing it passes close to gets bonked), asks the host to take it out of our paw and drop it
## where it lands, and shows everyone the spinning flight.
func _throw(weapon: MeleeWeapon) -> void:
	_cooldown = throw_cooldown
	var look := -cat.camera.global_basis.z
	var flat := Vector3(look.x, 0, look.z).normalized()
	if flat == Vector3.ZERO:
		flat = -cat.cat_model.global_basis.z
	var velocity := (look + Vector3.UP * throw_lift).normalized() * throw_speed
	var spot := cat.global_position + Vector3.UP * 0.7 + flat * 0.4
	var space := get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = throw_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.exclude = _own_rids()
	var points := PackedVector3Array([spot])
	var step := 1.0 / 60.0
	var time := 0.0
	var target: Node = null
	var stopped := false
	while time < throw_max_seconds and not stopped:
		var next := spot + velocity * step
		velocity.y -= throw_gravity * step
		time += step
		# Anything to bonk near here?
		query.transform = Transform3D(Basis.IDENTITY, next)
		for result in space.intersect_shape(query, 32):
			var found := Hit.target_of(result.collider)
			if found == null or found == cat or (found is CatPlayer and (found as CatPlayer).team == cat.team):
				continue
			target = found
			break
		# A wall or the ground in the way?
		var ray := PhysicsRayQueryParameters3D.create(spot, next)
		ray.exclude = _own_rids()
		var wall := space.intersect_ray(ray)
		if target != null:
			stopped = true
		elif wall:
			next = wall.position - (next - spot).normalized() * 0.2  # (bounce off a hair, not into it)
			stopped = true
		spot = next
		points.append(spot)
	var land := ItemManager.instance._ground_below(spot)
	if land.y > spot.y + 1.0:
		land = cat.global_position  # (it ended up inside something: drop it at our feet)
	# The Hit, ready now but handed out when the bat GETS there.
	if target != null:
		_copy_weapon_numbers(weapon, _thrown)
		var info := _thrown._make_hit(flat, spot)
		var paws := Upgrades.melee_multiplier(cat.player_id)
		info.damage = roundi(weapon.damage * weapon.throw_damage * paws * (weapon.crit_multiplier if info.crit else 1.0))
		info.enemy_push = (flat + Vector3.UP * 0.4) * weapon.enemy_knockback * weapon.throw_push * paws
		info.push_scale = weapon.throw_push
		info.stun_seconds = maxf(info.stun_seconds, weapon.throw_stun)
		get_tree().create_timer(time).timeout.connect(_throw_landed.bind(target, info))
	last_result = "throw item=%s seconds=%.2f target=%s land=%s" % [weapon.data.id, time, target.name if target != null else "none", land]
	Seats.rumble(cat.player_id, 0.4, 0.2, 0.08)
	cat.aim.kick(-1.0, 0.0, 1.0, camera_roll_degrees, camera_fov_punch, 0.0, 0.0)
	cat.aim_until = Time.get_ticks_msec() / 1000.0 + 0.4
	ItemManager.instance.request_throw.rpc_id(1, cat.player_id, 1, land, time)
	show_throw.rpc(weapon.data.id, points, time, target != null)


## Owner only: the thrown bat reached what it was going to bonk.
func _throw_landed(target: Node, info: Hit) -> void:
	if not is_instance_valid(target) or not is_instance_valid(cat):
		return
	if target.receive_hit(info):
		Hud.damage_number(info.position, info.damage, info.crit, cat.slot)
	Feedback.shake(cat.player_id, 0.3)


## A throw's hit points at this stand-in, a copy of the thrown weapon's numbers (the real one is gone
## from the paw by the time it lands).
func _copy_weapon_numbers(from: MeleeWeapon, to: MeleeWeapon) -> void:
	to.holder = cat
	for property in ["damage", "crit_chance", "crit_multiplier", "cat_knockback", "cat_hop", "car_impulse",
			"car_launch", "enemy_knockback", "stun_seconds", "city_heat_per_hit", "hud_name"]:
		to.set(property, from.get(property))


## Everyone: draw the thrown weapon spinning along its flight, then bonk / clatter at the end.
@rpc("any_peer", "call_local", "reliable")
func show_throw(item_id: String, points: PackedVector3Array, seconds: float, hit_something: bool) -> void:
	if cat == null or multiplayer.get_remote_sender_id() != PlayerId.peer_of(cat.player_id) or points.size() < 2:
		return
	var data: ItemData = ItemManager.instance.catalog.get(item_id)
	if data == null or data.scene == null:
		return
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
	var melee := flying as MeleeWeapon
	var tween := flying.create_tween()
	tween.tween_method(func(t: float):
		if not is_instance_valid(flying):
			return
		var along := t * (points.size() - 1)
		var i := mini(int(along), points.size() - 2)
		flying.global_position = points[i].lerp(points[i + 1], along - i)
		flying.global_basis = Basis(spin_axis, -t * seconds * throw_spin * TAU).scaled(Vector3.ONE * data.hold_scale)  # END OVER END
		if melee != null:
			melee._trail_until = Time.get_ticks_msec() / 1000.0 + 0.05  # its neon trail follows it
	, 0.0, 1.0, maxf(seconds, 0.05))
	tween.tween_callback(func():
		var end := points[points.size() - 1]
		if hit_something:
			Sound.play_at("bonk", end, 0.0)
			if melee != null:
				melee._impact(end, false)
		else:
			Sound.play_at("cone_bounce", end, -4.0)  # clatter on the street
		flying.queue_free())


func _own_rids() -> Array[RID]:
	var skip: Array[RID] = [cat.get_rid()]
	if cat.riding_car != null:
		skip.append(cat.riding_car.get_rid())
	return skip
