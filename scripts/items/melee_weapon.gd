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
## Camera jolt when the swing CONNECTS (0 = none, 1 = huge). See scripts/feedback.gd.
@export_range(0.0, 1.0) var hit_shake: float = 0.3

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

var _model: Node3D
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
	query.exclude = own_rids()  # don't bonk yourself (or the car you're riding in)
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
		var info := _make_hit(forward, (target as Node3D).global_position + Vector3.UP * 0.5 if target is Node3D else centre)
		# HEAVY PAWS (scripts/upgrades.gd): +25% / +50% damage and knockback for this cat.
		var paws := Upgrades.melee_multiplier(holder.player_id)
		info.damage = roundi(info.damage * paws)
		info.enemy_push *= paws
		hit_anything = true
		if target.receive_hit(info):
			Hud.damage_number(info.position, info.damage, info.crit, holder.slot)  # on OUR HUD
	if hit_anything:
		Feedback.shake(holder.player_id, hit_shake)  # THWACK (scripts/feedback.gd)
	# Lurch into the swing (like a zap, but forwards: cat_player.gd get_zapped).
	if lunge_speed > 0.0 and holder.is_on_floor():
		holder.velocity.x += forward.x * lunge_speed
		holder.velocity.z += forward.z * lunge_speed
	var hit_spots := PackedVector3Array()
	for target in already:
		if target is Node3D:
			hit_spots.append((target as Node3D).global_position + Vector3.UP * 0.4)
	show_swing.rpc(hit_anything, hit_spots)


## Everyone (including the swinger): play the swing, and the hit sound if it connected.
@rpc("any_peer", "call_local", "unreliable_ordered")
func show_swing(connected: bool, hit_spots: PackedVector3Array = PackedVector3Array()) -> void:
	if holder == null or multiplayer.get_remote_sender_id() != PlayerId.peer_of(holder.player_id):
		return  # only the holder may swing
	shots_seen += 1
	holder.aim_until = Time.get_ticks_msec() / 1000.0 + 0.35
	Sound.play_at(swing_sound, global_position, -4.0)
	if connected:
		Sound.play_at(hit_sound, global_position + (-holder.cat_model.global_basis.z), -2.0)
	for spot in hit_spots:
		_impact(spot)
	if _model == null:
		return
	# Raised back and out to the side -> SLASH across -> (freeze a moment if it hit) -> settle home.
	# (Godot turns Y first, then X: so the Y part sweeps the tilted bat across in front of the cat.)
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	var start := _model_home + Vector3(swing_angle * 0.45, swing_sweep, 0)
	var middle := _model_home + Vector3(-swing_angle * 0.05, 0, 0)
	var finish := _model_home + Vector3(-swing_angle * 0.55, -swing_sweep, 0)
	_model.rotation = start
	_trail_points.clear()
	_trail_until = Time.get_ticks_msec() / 1000.0 + swing_time + (hit_stop if connected else 0.0)
	_swing_tween = create_tween()
	_swing_tween.tween_property(_model, "rotation", middle, swing_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if connected and hit_stop > 0.0:
		_swing_tween.tween_interval(hit_stop)  # HIT-STOP: the bat sticks in it for a beat
	_swing_tween.tween_property(_model, "rotation", finish, swing_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
	_trail_mesh = ImmediateMesh.new()
	_trail_node = MeshInstance3D.new()
	_trail_node.name = "SwingTrail"
	_trail_node.mesh = _trail_mesh
	_trail_node.top_level = true  # drawn in world space: the trail stays where the bat WAS
	_trail_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # glows on top of the dark street
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	_trail_node.material_override = material
	add_child(_trail_node)


func _process(delta: float) -> void:
	super._process(delta)
	_update_trail(delta)


## Every frame: remember where the bat is while swinging, fade the old bits, redraw the ribbon.
func _update_trail(delta: float) -> void:
	if _trail_node == null:
		return
	for point in _trail_points:
		point.age += delta
	_trail_points = _trail_points.filter(func(p): return p.age < trail_fade)
	if _model != null and Time.get_ticks_msec() / 1000.0 < _trail_until and _model.is_visible_in_tree():
		var base := _model.global_transform * _trail_base
		var tip := _model.global_transform * (_trail_base + (_trail_tip - _trail_base) * trail_reach)
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
func _impact(where: Vector3) -> void:
	var world: Node = Game.instance if Game.instance != null else get_tree().root
	var tint := trail_color if trail_color.a > 0.0 else bolt_color
	if spark_count > 0:
		var sparks := CPUParticles3D.new()
		sparks.one_shot = true
		sparks.explosiveness = 1.0
		sparks.amount = spark_count
		sparks.lifetime = 0.35
		sparks.direction = Vector3.UP
		sparks.spread = 180.0
		sparks.initial_velocity_min = 3.0
		sparks.initial_velocity_max = 7.5
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
		light.light_energy = impact_light
		light.omni_range = 3.5
		world.add_child(light)
		light.global_position = where
		var fade := light.create_tween()
		fade.tween_property(light, "light_energy", 0.0, 0.18)
		fade.tween_callback(light.queue_free)


## No crosshair: you swing where you're facing.
func wants_crosshair() -> bool:
	return false
