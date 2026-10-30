class_name Weapon
extends HeldItem
## Base script for every gun. A new gun usually needs NO new code: make a scene with this
## script on its root, set the numbers below in the Inspector, and make an item card.
##
## The scene needs:
##   Model (Node3D)              <- the gun's meshes
##   Model/Muzzle (Marker3D)     <- tip of the barrel; bolts start here
##   Model/Muzzle/MuzzleFlash    <- optional OmniLight3D that flashes on each shot
##   Model/HeatCoil              <- optional MeshInstance3D that glows hotter as you fire
##
## How a shot works: the owner aims from its camera through the screen centre, finds what
## it hits, rolls the damage and hands it a Hit (the hit framework, scripts/hit.gd: the target
## decides what happens - enemies lose health, cats get shoved, the car gets pushed), and sends
## one small "draw a bolt to here" message so everyone sees the shot.

@export_group("Firing")
## Shots per second.
@export var fire_rate: float = 12.0
## true = hold the button to keep firing. false = one shot per click (pistols).
@export var automatic: bool = true
## How far a bolt reaches (metres).
@export var max_range: float = 60.0
## Random wobble on each shot, in degrees. 0 = laser-perfect.
@export var spread_degrees: float = 1.2

@export_group("Overheat")
## Heat added per shot (1.0 = fully overheated). 0 = this gun never overheats.
@export var heat_per_shot: float = 0.0
## Heat lost per second when not firing.
@export var cool_rate: float = 0.45
## Cooling speed while overheated (locked).
@export var overheated_cool_rate: float = 0.35

@export_group("Hits")
## Health a bolt takes off an enemy (a VAC-COP has 100, the MEGA VAC-COP 600: see roomba.tscn).
## The shooter sees the number pop off what they hit (scripts/ui/hud_damage_numbers.gd).
@export var damage: int = 25
## Each bolt's damage wobbles by up to this fraction (0.1 = 10% either way), like Cyberpunk.
@export_range(0.0, 0.5) var damage_wobble: float = 0.1
## Chance a bolt is a CRITICAL hit (0.1 = 1 in 10): bigger yellow number, more damage.
@export_range(0.0, 1.0) var crit_chance: float = 0.1
## A critical hit does this many times the damage.
@export var crit_multiplier: float = 2.0
## How hard a bolt shoves another cat (metres per second).
@export var cat_knockback: float = 7.0
## Little hop a zapped cat does.
@export var cat_hop: float = 3.0
## Push on the getaway car per bolt (the car weighs 800).
@export var car_impulse: float = 90.0
## Extra: throw the car this fast (metres per second), away from the hit and up into the air.
## Unlike Car Impulse this doesn't care how heavy the car is. 0 = just the push.
@export var car_launch: float = 0.0
## How hard a hit shoves an ENEMY (metres per second, a third of it upward). 0 = not at all.
@export var enemy_knockback: float = 0.0
## How many seconds a hit stuns an enemy (bosses too). 0 = no stun.
@export var stun_seconds: float = 0.0
## Share of the usual city heat each hit on an enemy adds (1 = all of it). Turn it down on guns
## that land many hits per second, or they'd run the district clock out by themselves.
@export_range(0.0, 1.0) var city_heat_per_hit: float = 1.0

@export_group("Scatter")
## Bolts fired by one pull of the trigger (each with its own Spread wobble, and each its own Hit).
## Their colours fan out from Bolt Color to Hot Color.
@export var pellets_per_shot: int = 1

@export_group("Blast")
## More than 0 = the shot EXPLODES where it lands: everything in this many metres gets a Hit,
## shoved away from the middle (not you, not your own gang). 0 = a normal bolt.
@export var blast_radius: float = 0.0
## Colour of the expanding blast sphere.
@export var blast_color: Color = Color(0.3, 1.0, 0.4)
## How long the sphere takes to grow and fade (seconds).
@export var blast_time: float = 0.3
## The sound of the blast (res://sounds/sfx/, no .wav).
@export var blast_sound: String = "explode"

@export_group("Look")
## Bolt colour (shifts toward hot_color as the gun heats up).
@export var bolt_color: Color = Color(0.2, 0.95, 1.0)
@export var hot_color: Color = Color(1.0, 0.15, 0.1)
## How long each bolt stays on screen (seconds).
@export var bolt_time: float = 0.08
## Thickness of the bolts (metres).
@export var bolt_width: float = 0.12
## The name shown on the heat bar.
@export var hud_name: String = "GUN"
## The sound each shot makes: a file name in res://sounds/sfx/ (without .wav), e.g. "shoot".
@export var shot_sound: String = "shoot"
## Play the sound on every Nth shot only (for very fast guns: 25 sounds a second is just noise).
@export var shots_per_sound: int = 1

## 0 = cool, 1 = overheated. Only meaningful on the holder's computer.
var heat: float = 0.0
var is_overheated: bool = false
## How many bolts this computer has drawn (the test tool prints it).
var shots_seen: int = 0

var _cooldown: float = 0.0
var _flash_time: float = 0.0
var _muzzle: Marker3D
var _muzzle_flash: OmniLight3D
var _coil: MeshInstance3D
var _coil_material: ShaderMaterial
var _bolt_mesh := BoxMesh.new()
var _bolt_material: ShaderMaterial
var _rng := RandomNumberGenerator.new()  # spread only — NOT the city's RNG


func _ready() -> void:
	_muzzle = get_node_or_null("Model/Muzzle")
	_muzzle_flash = get_node_or_null("Model/Muzzle/MuzzleFlash")
	_coil = get_node_or_null("Model/HeatCoil")
	if _coil != null:
		# Own copy of the coil material so its glow can change without touching other guns.
		_coil_material = (_coil.get_surface_override_material(0) as ShaderMaterial).duplicate()
		_coil.set_surface_override_material(0, _coil_material)
	# Bolts: one shared thin box, stretched per shot. White glow; colour comes from instance_tint.
	_bolt_mesh.size = Vector3(bolt_width, bolt_width, 1.0)
	_bolt_material = LevelKit.psx_material({"albedo_color": Color.BLACK, "emission_color": Color.WHITE, "emission_energy": 8.0})
	_rng.randomize()
	if _muzzle_flash != null:
		_muzzle_flash.light_energy = 0.0
	_update_heat_look()


func _process(delta: float) -> void:
	_flash_time = maxf(_flash_time - delta, 0.0)
	if _muzzle_flash != null:
		_muzzle_flash.light_energy = 6.0 * _flash_time / 0.05 if _flash_time > 0.0 else 0.0


func use_tick(trigger_down: bool, trigger_pressed: bool, delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var wants_fire := trigger_down if automatic else trigger_pressed
	if wants_fire and not is_overheated and _cooldown <= 0.0:
		_fire()
		_cooldown = 1.0 / fire_rate
	if not trigger_down or is_overheated:
		heat = maxf(heat - (overheated_cool_rate if is_overheated else cool_rate) * delta, 0.0)
		if heat <= 0.0:
			is_overheated = false
	_update_heat_look()


## Owner only: aim from the camera through the middle of the screen, hit whatever is there.
func _fire() -> void:
	holder.aim_until = Time.get_ticks_msec() / 1000.0 + 0.3  # cat turns to face the shot
	Seats.rumble(holder.player_id, 0.4, 0.1, 0.06)  # a little kick on the shooter's controller with every shot

	var ends := PackedVector3Array()  # where each bolt landed
	for i in maxi(pellets_per_shot, 1):
		ends.append(_fire_bolt())

	if heat_per_shot > 0.0:
		heat = minf(heat + heat_per_shot, 1.0)
		if heat >= 1.0:
			is_overheated = true
	show_shot.rpc(ends, heat)


## Owner only: one bolt. Returns where it landed.
func _fire_bolt() -> Vector3:
	var camera := holder.camera
	var aim := -camera.global_basis.z
	var spread := deg_to_rad(spread_degrees)
	aim = aim.rotated(camera.global_basis.x, _rng.randf_range(-spread, spread))
	aim = aim.rotated(camera.global_basis.y, _rng.randf_range(-spread, spread))

	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + aim * max_range)
	query.exclude = [holder.get_rid()]  # don't shoot yourself
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.position if hit else from + aim * max_range

	if blast_radius > 0.0:
		_blast(end, aim)  # the blast does the hitting (so what the bolt struck isn't hit twice)
		return end
	var target := Hit.target_of(hit.collider) if hit else null
	if target != null:
		var info := _make_hit(aim, hit.position)
		if target.receive_hit(info):
			Hud.damage_number(hit.position, info.damage, info.crit, holder.slot)  # pops up straight away on OUR HUD
	return end


## Owner only: a filled-in Hit from this gun. Rolled here so the number we show is the number the
## host takes off. "direction" = which way it shoves.
func _make_hit(direction: Vector3, where: Vector3) -> Hit:
	var info := Hit.new()
	info.shooter = holder
	info.weapon = self
	info.crit = _rng.randf() < crit_chance
	info.damage = roundi(damage * _rng.randf_range(1.0 - damage_wobble, 1.0 + damage_wobble) * (crit_multiplier if info.crit else 1.0))
	info.direction = direction
	info.position = where
	info.stun_seconds = stun_seconds
	info.enemy_push = (direction + Vector3.UP / 3.0) * enemy_knockback
	info.city_heat = city_heat_per_hit
	return info


## Owner only: explode at "centre": a Hit for every enemy, rival cat and car in blast_radius,
## shoved outward from the middle. "aim" = the shove if something is exactly on the middle.
func _blast(centre: Vector3, aim: Vector3) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, centre)
	query.exclude = [holder.get_rid()]  # your own blast leaves you alone
	var already := {}
	# (128: the answer also lists every street tile and wall in range, not just what can be hit.)
	for result in get_world_3d().direct_space_state.intersect_shape(query, 128):
		var target := Hit.target_of(result.collider)
		if target == null or already.has(target) or target == holder:
			continue
		if target is CatPlayer and (target as CatPlayer).team == holder.team:
			continue  # our own gang: no hit, no shove
		already[target] = true
		var where: Vector3 = (target as Node3D).global_position + Vector3.UP * 0.5
		var outward := Motion.flat(where - centre).normalized()
		var info := _make_hit(outward if outward != Vector3.ZERO else Motion.flat(aim).normalized(), where)
		if target.receive_hit(info):
			Hud.damage_number(where, info.damage, info.crit, holder.slot)


## Everyone (including the shooter): draw this shot's bolts from the muzzle to "ends" (one per
## pellet), plus the blast if this gun has one.
@rpc("any_peer", "call_local", "unreliable_ordered")
func show_shot(ends: PackedVector3Array, shot_heat: float) -> void:
	if holder == null or multiplayer.get_remote_sender_id() != PlayerId.peer_of(holder.player_id):
		return  # only the holder may fire
	draw_shot(ends, shot_heat)


## Draw one shot on this computer: bolts, blast, muzzle flash and sound. Needs no holder, so the
## sewer NPCs fire their guns through it too (npc.gd). Empty "ends" = just the flash and the sound.
func draw_shot(ends: PackedVector3Array, shot_heat: float) -> void:
	shots_seen += 1
	var start := _muzzle.global_position if _muzzle != null else global_position
	var color := bolt_color.lerp(hot_color, shot_heat)
	for i in ends.size():
		# A scattergun's pellets fan out from Bolt Color to Hot Color.
		var pellet_color := bolt_color.lerp(hot_color, float(i) / (ends.size() - 1)) if ends.size() > 1 else color
		_draw_bolt(start, ends[i], pellet_color)
		if blast_radius > 0.0:
			draw_blast(ends[i])

	if _muzzle_flash != null:
		_muzzle_flash.light_color = color
	_flash_time = 0.05
	if shots_seen % maxi(shots_per_sound, 1) == 0:
		Sound.play_at(shot_sound, start, -4.0)  # every computer runs this, so play it just here


## One bolt and the little spark where it landed.
func _draw_bolt(start: Vector3, end: Vector3, color: Color) -> void:
	var length := start.distance_to(end)
	if length < 0.05:
		return

	var bolt := MeshInstance3D.new()
	bolt.mesh = _bolt_mesh
	bolt.material_override = _bolt_material
	bolt.set_instance_shader_parameter("instance_tint", color)
	bolt.top_level = true
	add_child(bolt)
	bolt.global_transform = Transform3D(Basis.looking_at(end - start), (start + end) * 0.5)
	bolt.scale = Vector3(1, 1, length)
	get_tree().create_timer(bolt_time).timeout.connect(bolt.queue_free)

	# Spark where it hit: a short-lived coloured light.
	var spark := OmniLight3D.new()
	spark.light_color = color
	spark.light_energy = 3.0
	spark.omni_range = 1.5
	spark.top_level = true
	add_child(spark)
	spark.global_position = end - (end - start).normalized() * 0.2
	get_tree().create_timer(bolt_time * 1.5).timeout.connect(spark.queue_free)


## The blast: a neon sphere that grows to blast_radius and fades, with a flash of light. It lives
## in the world (not on the gun), so dropping the gun doesn't delete it mid-blast.
func draw_blast(centre: Vector3) -> void:
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
	material.albedo_color = Color(blast_color, 0.45)  # see-through: standing in it mustn't blind you
	mesh.material = material

	var ball := MeshInstance3D.new()
	ball.mesh = mesh
	ball.scale = Vector3.ONE * 0.2
	var flash := OmniLight3D.new()
	flash.light_color = blast_color
	flash.light_energy = 8.0
	flash.omni_range = blast_radius * 2.0
	ball.add_child(flash)
	Game.instance.add_child(ball)
	ball.global_position = centre

	var tween := ball.create_tween().set_parallel()
	tween.tween_property(ball, "scale", Vector3.ONE * blast_radius, blast_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, blast_time)
	tween.tween_property(flash, "light_energy", 0.0, blast_time)
	tween.chain().tween_callback(ball.queue_free)
	Sound.play_at(blast_sound, centre)


## Coil glow: cool colour normally, red-hot as it heats (blinks while overheated).
func _update_heat_look() -> void:
	if _coil_material == null:
		return
	var color := bolt_color.lerp(hot_color, heat)
	var energy := 3.0 + heat * 5.0
	if is_overheated and fmod(Time.get_ticks_msec() / 1000.0, 0.3) < 0.15:
		energy = 0.5
	_coil_material.set_shader_parameter("emission_color", color)
	_coil_material.set_shader_parameter("emission_energy", energy)


func hud_text() -> String:
	if heat_per_shot <= 0.0:
		return hud_name
	var bars := int(round(heat * 10.0))
	return "%s %s[%s]" % [hud_name, "OVERHEAT! " if is_overheated else "", "#".repeat(bars) + "-".repeat(10 - bars)]


func wants_crosshair() -> bool:
	return true
