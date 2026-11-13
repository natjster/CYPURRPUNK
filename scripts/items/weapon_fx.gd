class_name WeaponFx
extends RefCounted
## Procedural 3D visual effects for guns (scripts/items/weapon.gd):
##   - Bolt tracers and impact sparks (draw_bolt, burst_sparks)
##   - Muzzle-flash star mesh and world-space gunner flash (flash_star_mesh, show_flash_star)
##   - Ejected brass shell casings and barrel smoke (eject_casing, puff_smoke)
##   - Lobbed projectile dress-up and blast spheres / debris / shockwave rings (dress_lob, draw_blast)
##
## Every world effect is parented to effects_parent(gun) (Game.instance when running in the game),
## so effects stay visible when a passenger gunner's cat is hidden inside a car (cat.visible = false
## hides every child Node3D, even with top_level = true) and aren't deleted if a gun is swapped.

static var _flash_star_mesh: ArrayMesh
static var _casing_mesh: BoxMesh
static var _spark_mesh: BoxMesh
static var _smoke_mesh: BoxMesh


## Where world-space bolts, casings, sparks, smoke, lobbed shots and blasts live.
static func effects_parent(gun: Node) -> Node:
	return Game.instance if Game.instance != null else gun


## Shared mesh for the muzzle-flash STAR: two crossed glowing diamonds along the barrel plus an
## 8-spike forward burst, built once and reused by every gun.
static func flash_star_mesh() -> ArrayMesh:
	if _flash_star_mesh == null:
		var tools := SurfaceTool.new()
		tools.begin(Mesh.PRIMITIVE_TRIANGLES)
		var w := 0.35
		for flip in [Vector3(1, 0, 0), Vector3(0, 1, 0)]:
			var side: Vector3 = flip * w
			for tri in [[Vector3.ZERO, side, Vector3(0, 0, -1)], [Vector3.ZERO, -side, Vector3(0, 0, -1)],
					[Vector3.ZERO, side, Vector3(0, 0, 0.25)], [Vector3.ZERO, -side, Vector3(0, 0, 0.25)]]:
				for corner in tri:
					tools.add_vertex(corner)
		for i in 8:  # the forward-facing burst: 8 spikes, long and short
			var angle := TAU * i / 8.0
			var spike := 0.6 if i % 2 == 0 else 0.3
			tools.add_vertex(Vector3(cos(angle - 0.2), sin(angle - 0.2), 0) * 0.12)
			tools.add_vertex(Vector3(cos(angle + 0.2), sin(angle + 0.2), 0) * 0.12)
			tools.add_vertex(Vector3(cos(angle), sin(angle), 0) * spike)
		_flash_star_mesh = tools.commit()
	return _flash_star_mesh


## Shared little glowing box for impact sparks, projectile trails and blast debris.
static func spark_box() -> BoxMesh:
	if _spark_mesh == null:
		_spark_mesh = BoxMesh.new()
		_spark_mesh.size = Vector3.ONE * 0.05
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		_spark_mesh.material = material
	return _spark_mesh


## Builds the gun's attached muzzle-flash star node under muzzle.
static func make_flash_star(muzzle: Node3D, material: StandardMaterial3D) -> MeshInstance3D:
	var star := MeshInstance3D.new()
	star.mesh = flash_star_mesh()
	star.material_override = material
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.visible = false
	muzzle.add_child(star)
	return star


## Flashes the muzzle star (or spawns a brief world-space star when the gun is hidden inside a car).
static func show_flash_star(gun: Weapon, color: Color) -> void:
	if gun._flash_star == null:
		return
	gun._flash_material.albedo_color = Color(color.lerp(Color.WHITE, 0.45), 0.95)
	var roll := gun._rng.randf() * TAU
	var star_scale := Vector3.ONE * gun.muzzle_flash_size * gun._rng.randf_range(0.75, 1.3)
	if not gun.is_visible_in_tree() and gun._muzzle != null and gun.is_inside_tree():
		var world_star := MeshInstance3D.new()
		world_star.mesh = gun._flash_star.mesh
		world_star.material_override = gun._flash_material
		world_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_star.top_level = true
		effects_parent(gun).add_child(world_star)
		world_star.global_transform = gun._muzzle.global_transform
		world_star.rotate_object_local(Vector3.FORWARD, roll)
		world_star.scale = star_scale
		gun.get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(world_star):
				world_star.queue_free())
		return
	gun._flash_star.rotation = Vector3(0, 0, roll)
	gun._flash_star.scale = star_scale
	gun._flash_star.visible = true


## Draws one bolt tracer and its impact light + spark burst in world space.
static func draw_bolt(gun: Weapon, start: Vector3, end: Vector3, color: Color) -> void:
	var length := start.distance_to(end)
	if length < 0.05 or not gun.is_inside_tree():
		return
	var parent := effects_parent(gun)
	var bolt := MeshInstance3D.new()
	bolt.mesh = gun._bolt_mesh
	bolt.material_override = gun._bolt_material
	bolt.set_instance_shader_parameter("instance_tint", color)
	bolt.top_level = true
	parent.add_child(bolt)
	bolt.global_transform = Transform3D(Basis.looking_at(end - start), (start + end) * 0.5)
	bolt.scale = Vector3(1, 1, length)
	gun.get_tree().create_timer(gun.bolt_time).timeout.connect(bolt.queue_free)

	var spark := OmniLight3D.new()
	spark.light_color = color
	spark.light_energy = 3.0
	spark.omni_range = 1.5
	spark.top_level = true
	parent.add_child(spark)
	spark.global_position = end - (end - start).normalized() * 0.2
	gun.get_tree().create_timer(gun.bolt_time * 1.5).timeout.connect(spark.queue_free)
	if length < gun.max_range * 0.95:  # (a miss into the sky: no sparks in mid-air)
		burst_sparks(gun, end, (start - end).normalized(), color)


## A brass shell casing spins out of the right side of the gun, arcs and drops away.
static func eject_casing(gun: Weapon) -> void:
	if gun._gun_model == null or not gun.is_inside_tree():
		return
	if _casing_mesh == null:
		_casing_mesh = BoxMesh.new()
		_casing_mesh.size = Vector3(0.035, 0.035, 0.09)
	var casing := MeshInstance3D.new()
	casing.mesh = _casing_mesh
	casing.material_override = LevelKit.psx_material({"albedo_color": gun.casing_color, "emission_color": gun.casing_color, "emission_energy": 0.6})
	casing.top_level = true
	casing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effects_parent(gun).add_child(casing)
	var gun_basis := gun._gun_model.global_basis.orthonormalized()
	var from := gun._gun_model.global_position + gun_basis.y * 0.08
	casing.global_position = from
	var out := gun_basis.x * gun._rng.randf_range(0.5, 0.8) + gun_basis.z * gun._rng.randf_range(0.0, 0.2)
	var seconds := 0.55
	var tween := casing.create_tween().set_parallel()
	tween.tween_method(func(t: float):
		casing.global_position = from + out * t + Vector3.UP * (1.6 * t - 3.2 * t * t), 0.0, 1.0, seconds)
	tween.tween_property(casing, "rotation", Vector3(gun._rng.randf_range(8, 14), gun._rng.randf_range(-4, 4), 0), seconds)
	tween.chain().tween_callback(casing.queue_free)


## A burst of little glowing chips flying off where a bolt hit ("back" = back towards the shooter).
static func burst_sparks(gun: Weapon, where: Vector3, back: Vector3, color: Color) -> void:
	if gun.impact_sparks <= 0 or not gun.is_inside_tree():
		return
	var sparks := CPUParticles3D.new()
	sparks.mesh = spark_box()
	sparks.amount = gun.impact_sparks
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.lifetime = 0.35
	sparks.direction = back
	sparks.spread = 55.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 7.0
	sparks.gravity = Vector3(0, -14, 0)
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.4
	sparks.color = color.lerp(Color.WHITE, 0.3)
	sparks.top_level = true
	effects_parent(gun).add_child(sparks)
	sparks.global_position = where + back * 0.1
	sparks.emitting = true
	gun.get_tree().create_timer(0.6).timeout.connect(sparks.queue_free)


## The flying shot's extras: a light it carries, a glowing trail and its whirr (all optional).
static func dress_lob(gun: Weapon, ball: MeshInstance3D) -> void:
	if gun.lob_glow > 0.0:
		var light := OmniLight3D.new()
		light.light_color = gun.blast_color
		light.light_energy = gun.lob_glow
		light.omni_range = 3.0
		ball.add_child(light)
	if gun.lob_trail > 0:
		var trail := CPUParticles3D.new()
		trail.mesh = spark_box()
		trail.amount = gun.lob_trail
		trail.lifetime = 0.35
		trail.local_coords = false  # bits stay where they were dropped: a streak behind the shot
		trail.spread = 180.0
		trail.initial_velocity_min = 0.2
		trail.initial_velocity_max = 0.8
		trail.gravity = Vector3(0, -2, 0)
		trail.scale_amount_min = 0.8
		trail.scale_amount_max = 1.8
		trail.color = gun.blast_color.lerp(Color.WHITE, 0.35)
		ball.add_child(trail)
		trail.emitting = true
	if gun.lob_loop_sound != "":
		var whirr := Sound.attach_loop(gun.lob_loop_sound, ball, -6.0)
		if whirr != null:
			whirr.pitch_scale = gun.lob_loop_pitch


## A puff of grey smoke out of the barrel that drifts up and fades ("forward" = where the barrel points).
static func puff_smoke(gun: Weapon, where: Vector3, forward: Vector3) -> void:
	if not gun.is_inside_tree():
		return
	if _smoke_mesh == null:
		_smoke_mesh = BoxMesh.new()
		_smoke_mesh.size = Vector3.ONE * 0.16
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo = true
		_smoke_mesh.material = material
	var smoke := CPUParticles3D.new()
	smoke.mesh = _smoke_mesh
	smoke.amount = gun.muzzle_smoke
	smoke.one_shot = true
	smoke.explosiveness = 0.9
	smoke.lifetime = 0.7
	smoke.direction = forward
	smoke.spread = 25.0
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 4.0
	smoke.damping_min = 4.0
	smoke.damping_max = 6.0
	smoke.gravity = Vector3(0, 0.8, 0)  # smoke rises a little
	smoke.scale_amount_min = 0.7
	smoke.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(0.75, 0.75, 0.8, 0.8))
	fade.set_color(1, Color(0.4, 0.4, 0.45, 0.0))
	smoke.color_ramp = fade
	smoke.top_level = true
	effects_parent(gun).add_child(smoke)
	smoke.global_position = where
	smoke.emitting = true
	smoke.finished.connect(smoke.queue_free)


## Expanding neon blast sphere + flash light + optional debris and ground ring.
static func draw_blast(gun: Weapon, centre: Vector3) -> void:
	var parent := effects_parent(gun)
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(gun.blast_color, 0.45)  # see-through: standing in it mustn't blind you
	mesh.material = material

	var ball := MeshInstance3D.new()
	ball.mesh = mesh
	ball.scale = Vector3.ONE * 0.2
	var flash := OmniLight3D.new()
	flash.light_color = gun.blast_color
	flash.light_energy = 8.0
	flash.omni_range = gun.blast_radius * 2.0
	ball.add_child(flash)
	parent.add_child(ball)
	ball.global_position = centre

	var tween := ball.create_tween().set_parallel()
	tween.tween_property(ball, "scale", Vector3.ONE * gun.blast_radius, gun.blast_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, gun.blast_time)
	tween.tween_property(flash, "light_energy", 0.0, gun.blast_time)
	tween.chain().tween_callback(ball.queue_free)
	Sound.play_at(gun.blast_sound, centre)
	if gun.blast_debris > 0:
		_blast_debris(parent, centre, gun.blast_debris, gun.blast_radius, gun.blast_color)
	if gun.blast_ring:
		_blast_ring(parent, centre, gun.blast_radius, gun.blast_time, gun.blast_color)
	Feedback.shake_near(centre, 0.45, gun.blast_radius * 2.5)


static func _blast_debris(parent: Node, centre: Vector3, amount: int, radius: float, color: Color) -> void:
	var debris := CPUParticles3D.new()
	debris.mesh = spark_box()
	debris.amount = amount
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.lifetime = 0.9
	debris.direction = Vector3.UP
	debris.spread = 75.0
	debris.initial_velocity_min = 4.0
	debris.initial_velocity_max = 4.0 + radius * 2.0
	debris.gravity = Vector3(0, -18, 0)
	debris.scale_amount_min = 1.5
	debris.scale_amount_max = 3.5
	debris.color = color.lerp(Color.WHITE, 0.25)
	debris.top_level = true
	parent.add_child(debris)
	debris.global_position = centre + Vector3.UP * 0.2
	debris.emitting = true
	debris.finished.connect(debris.queue_free)


static func _blast_ring(parent: Node, centre: Vector3, radius: float, duration: float, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	mesh.rings = 16
	mesh.ring_segments = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.lerp(Color.WHITE, 0.3), 0.9)
	mesh.material = material
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = centre + Vector3.UP * 0.1
	ring.scale = Vector3(0.3, 0.15, 0.3)
	var grow := radius * 1.3
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(grow, 0.15, grow), duration * 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration * 1.4)
	tween.chain().tween_callback(ring.queue_free)
