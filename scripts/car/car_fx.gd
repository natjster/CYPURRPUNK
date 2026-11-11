class_name CarFx
extends RefCounted
## CYPURRPUNK — little effect builders shared by the car's HEALTH (smoke, fire, the wreck blast:
## scripts/car/car_health.gd) and its BOOST (exhaust flames: scripts/car/car_boost.gd).
## Nothing to attach: the other scripts call these to build their effects in code.
## Everything is chunky low-poly cubes and cones on purpose (the PS1 look).


## A stream of glowing cubes (fire, smoke, sparks). "colours" fades each cube over its life
## (start colour -> end colour; give the end colour alpha 0 to fade out). Starts switched off:
## set .emitting = true to start it. Cubes stay where they were let go (world space), so a
## moving car leaves a trail behind it.
static func particles(parent: Node3D, colours: PackedColorArray, cube_size: float, amount: int,
		lifetime: float, speed: float, direction: Vector3, spread_degrees: float, rise: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = direction
	p.spread = spread_degrees
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, rise, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * cube_size
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # glows by itself, no lighting needed
	look.vertex_color_use_as_albedo = true  # (the colour ramp below paints each cube)
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cube.material = look
	p.mesh = cube
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([colours[0], colours[colours.size() - 1]])
	if colours.size() > 2:
		ramp.add_point(0.45, colours[1])
	p.color_ramp = ramp
	parent.add_child(p)
	return p


## A glowing cone of fire pointing BACKWARDS (+Z, out of the car's tail). Its tip is "length" behind
## where it's placed. Returns the cone's holder: move that onto the exhaust, and scale its .scale.z
## to make the flame longer / shorter.
static func flame_cone(parent: Node3D, colour: Color, length: float, radius: float, glow: float) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.01       # (the tip)
	mesh.bottom_radius = radius  # (at the exhaust pipe)
	mesh.height = length
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.cap_top = false
	var cone := MeshInstance3D.new()
	cone.mesh = mesh
	cone.material_override = LevelKit.psx_material({"albedo_color": colour, "emission_color": colour, "emission_energy": glow})
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A cylinder stands along +Y: tip it over so its top (the thin tip) points backwards (+Z),
	# and slide it back so its wide end sits on the exhaust.
	var holder := Node3D.new()
	holder.add_child(cone)
	cone.rotation.x = PI / 2.0
	cone.position.z = length / 2.0
	parent.add_child(holder)
	return holder


## One-shot fireball at "where" (the car blowing up): a burst of fire cubes, black smoke and a
## flash of orange light. Frees itself when it's done.
static func burst(world: Node3D, where: Vector3) -> void:
	var spot := Node3D.new()
	world.add_child(spot)
	spot.global_position = where
	var fire := particles(spot, PackedColorArray([Color(1, 0.95, 0.5), Color(1, 0.45, 0.05), Color(0.3, 0.05, 0.0, 0.0)]),
		0.45, 60, 0.9, 11.0, Vector3.UP, 80.0, -6.0)
	fire.one_shot = true
	fire.explosiveness = 0.95
	fire.emitting = true
	var smoke := particles(spot, PackedColorArray([Color(0.25, 0.22, 0.2, 0.9), Color(0.05, 0.05, 0.05, 0.0)]),
		0.7, 30, 2.2, 5.0, Vector3.UP, 60.0, 2.0)
	smoke.one_shot = true
	smoke.explosiveness = 0.8
	smoke.emitting = true
	var flash := OmniLight3D.new()
	flash.light_color = Color(1, 0.55, 0.2)
	flash.omni_range = 14.0
	flash.light_energy = 12.0
	spot.add_child(flash)
	var fade := spot.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, 0.8)
	fade.tween_interval(2.0)
	fade.tween_callback(spot.queue_free)
