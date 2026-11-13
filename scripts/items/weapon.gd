class_name Weapon
extends HeldItem
## Base script for every gun. A new gun usually needs NO new code: make a scene with this
## script on its root, set the numbers below in the Inspector, and make an item card.
##
## The scene needs:
##   Model (Node3D)              <- the gun's look: usually a Blockbench model (models/<gun>.glb,
##                                  made by tools/make_weapon_specs.py) dropped in as a child
##   Model/Muzzle (Marker3D)     <- tip of the barrel; bolts start here. If the model has its own
##                                  "Muzzle" marker, this one is moved onto it when the gun appears.
##   Model/Muzzle/MuzzleFlash    <- optional OmniLight3D that flashes on each shot
##   HeatCoil                    <- optional part anywhere under Model that glows hotter as you fire
## The model gets the PS1 look automatically; Glow Parts / Neon Parts (Look) say which parts glow.
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

@export_group("Feel")
## Camera kick on every shot (0 = none, 1 = huge; shotguns ~0.25, a tommy gun ~0.06).
## Scaled by SETTINGS > EFFECTS > SCREEN SHAKE. See scripts/feedback.gd.
@export_range(0.0, 1.0) var camera_kick: float = 0.12
## RECOIL: each shot tips your aim UP this many degrees (you pull it back down, Helldivers-style).
@export var recoil_degrees: float = 0.8
## ...and nudges it left or right by up to this many degrees.
@export var recoil_sideways_degrees: float = 0.25
## Share of the climb that settles back by itself (1 = all of it, 0 = you pull every bit down).
@export_range(0.0, 1.0) var recoil_return: float = 0.6
## While AIMING DOWN SIGHTS the recoil is multiplied by this (0.6 = 40% less kick).
@export_range(0.0, 1.0) var ads_recoil_scale: float = 0.6
## While AIMING DOWN SIGHTS the spread is multiplied by this (0.3 = shots much tighter).
@export_range(0.0, 1.0) var ads_spread_scale: float = 0.3
## Spread BLOOM: each shot adds this many degrees of extra wobble (shrinks back when you stop),
## so tapping is accurate and holding the trigger sprays. The crosshair opens up with it.
@export var spread_bloom_degrees: float = 0.3
## The most bloom can grow to (degrees).
@export var max_bloom_degrees: float = 3.0
## Camera ROLL punch per shot (degrees, random left or right).
@export var camera_roll_degrees: float = 0.6
## ZOOM punch per shot: the view widens this many degrees for a split second (feels like a THUMP).
@export var fov_punch_degrees: float = 1.0
## The gun MODEL slams back this far in the paw on each shot (metres)...
@export var gun_kickback: float = 0.07
## ...and its nose flips up this many degrees.
@export var gun_kick_degrees: float = 9.0
## How long the model takes to settle back (seconds).
@export var gun_kick_time: float = 0.12
## Size of the bright muzzle-flash STAR at the barrel tip (metres; 0 = no star, just the light).
@export var muzzle_flash_size: float = 0.35
## Spit out a brass SHELL CASING on each shot (lasers and launchers: off).
@export var eject_casings: bool = true
@export var casing_color: Color = Color(1.0, 0.75, 0.25)
## Sparks that burst off whatever a bolt hits (0 = none). Blasts don't use them.
@export var impact_sparks: int = 7

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
## How fast the shot flies to where you aimed (metres per second), and the longest it may take.
@export var lob_speed: float = 30.0
@export var lob_max_seconds: float = 1.2
## How high its arc goes on a long shot (metres; short shots arc lower).
@export var lob_height: float = 3.0
## How many hops it takes along the floor before it goes off (a cucumber grenade). A wall stops them.
@export var lob_bounces: int = 0
## How far (metres), how high and how long (seconds) each hop is.
@export var lob_bounce_distance: float = 2.0
@export var lob_bounce_height: float = 0.8
@export var lob_bounce_seconds: float = 0.3
## What flies through the air. Empty = a ball of yarn.
@export var lob_mesh: Mesh
## A LOOPING sound riding on the shot while it flies (res://sounds/sfx/, no .wav). Empty = silent.
@export var lob_loop_sound: String = ""
## Pitch of that loop (1 = as recorded, 1.5 = higher and faster).
@export var lob_loop_pitch: float = 1.0
## The sound of each hop along the floor (Lob Bounces). Empty = silent.
@export var lob_bounce_sound: String = ""
## How bright the light the flying shot carries is (0 = no light). Lights up the street as it goes.
@export var lob_glow: float = 0.0
## How many glowing bits trail behind the flying shot (0 = no trail).
@export var lob_trail: int = 0

@export_group("Launcher Juice")
## Puffs of smoke out of the barrel on every shot (0 = none). Nice on launchers.
@export var muzzle_smoke: int = 0
## Chunks that fly up out of the blast (0 = none).
@export var blast_debris: int = 0
## A flat ring that races out along the ground from the blast.
@export var blast_ring: bool = false

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
## Parts of the model (Blockbench group names, e.g. "Laser") that GLOW as a whole, in this colour.
@export var glow_parts: Dictionary = {}
## How bright the Glow Parts are (0 = no glow, 3 = neon).
@export var glow_energy: float = 3.0
## Parts whose BRIGHT painted pixels glow in their own colour (neon tubes, frost, lit slits), and
## how strongly: part name -> 1 (soft) .. 4 (blazing). The dark paint around them stays dark.
@export var neon_parts: Dictionary = {}
## The sound each shot makes: a file name in res://sounds/sfx/ (without .wav), e.g. "shoot".
@export var shot_sound: String = "shoot"
## Play the sound on every Nth shot only (for very fast guns: 25 sounds a second is just noise).
@export var shots_per_sound: int = 1
## How loud the shot sound is (decibels: 0 = as recorded, -6 = about half).
@export var shot_volume_db: float = -4.0
## A LOOPING sound that plays for as long as this gun keeps firing (THE RED DOT's laser hum).
## Empty = none. Use it instead of Shot Sound on very fast guns.
@export var hum_sound: String = ""
## How loud the hum is (decibels).
@export var hum_volume_db: float = -3.0
## How much higher the hum gets as the gun heats up (0.5 = up to 50% higher).
@export var hum_heat_pitch: float = 0.5
## Plays once when the hum starts (empty = none).
@export var hum_start_sound: String = ""
## Plays (only for the shooter) the moment a slow gun can fire again: a reload "chk-CHAK". Empty = none.
@export var ready_sound: String = ""
## How hard the shooter's controller rumbles on each shot (0 = none, 1 = full).
@export_range(0.0, 1.0) var fire_rumble: float = 0.4

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
var _lob_material: ShaderMaterial
var _rng := RandomNumberGenerator.new()  # spread only — NOT the city's RNG
var _gun_model: Node3D
var _gun_rest := Transform3D.IDENTITY  # where the model sits in the paw when not kicking
var _kick_tween: Tween
var _flash_star: MeshInstance3D           # the muzzle-flash star (built in _ready)
var _flash_material: StandardMaterial3D
static var _casing_mesh: BoxMesh
static var _spark_mesh: BoxMesh
static var _smoke_mesh: BoxMesh
var _hum: AudioStreamPlayer3D      # the laser hum while it's playing (hum_sound)
var _hum_until: float = 0.0        # when the hum stops if no more shots come


func _ready() -> void:
	var model := get_node_or_null("Model")
	if model != null:
		# The Blockbench model -> the game's PS1 look (keeps its painted texture, crisp pixels),
		# then the glowing bits.
		LevelKit.psx_ify(model)
		LevelKit.make_parts_glow(model, glow_parts, glow_energy)
		LevelKit.make_neon_paint_glow(model, neon_parts)
	_muzzle = get_node_or_null("Model/Muzzle")
	_muzzle_flash = get_node_or_null("Model/Muzzle/MuzzleFlash")
	_snap_muzzle_to_model(model)
	_coil = model.find_child("HeatCoil", true, false) as MeshInstance3D if model != null else null
	if _coil != null and _coil.get_active_material(0) is ShaderMaterial:
		# Own copy of the coil material so its glow can change without touching other guns.
		_coil_material = (_coil.get_active_material(0) as ShaderMaterial).duplicate()
		_coil_material.set_shader_parameter("emission_textured", true)  # the painted windings show in the glow
		_coil.set_surface_override_material(0, _coil_material)
	# Bolts: one shared thin box, stretched per shot. White glow; colour comes from instance_tint.
	_bolt_mesh.size = Vector3(bolt_width, bolt_width, 1.0)
	_bolt_material = LevelKit.psx_material({"albedo_color": Color.BLACK, "emission_color": Color.WHITE, "emission_energy": 8.0})
	_rng.randomize()
	if _muzzle_flash != null:
		_muzzle_flash.light_energy = 0.0
	_gun_model = model as Node3D
	if _gun_model != null:
		_gun_rest = _gun_model.transform
	_build_flash_star()
	_update_heat_look()


## If the Blockbench model has its own "Muzzle" marker (the @Muzzle locator), put Model/Muzzle
## exactly there, so bolts and the flash start at the painted barrel tip even after the model is
## reshaped in Blockbench. (No marker: Model/Muzzle stays where the scene put it.)
func _snap_muzzle_to_model(model: Node) -> void:
	if model == null or _muzzle == null:
		return
	for marker in model.find_children("Muzzle", "", true, false):
		if marker == _muzzle:
			continue
		# Add up the positions from the marker back to Model (works before the gun is in the world).
		var offset := Transform3D.IDENTITY
		var node: Node = marker
		while node != null and node != model:
			if node is Node3D:
				offset = (node as Node3D).transform * offset
			node = node.get_parent()
		_muzzle.position = offset.origin
		return


func _process(delta: float) -> void:
	_flash_time = maxf(_flash_time - delta, 0.0)
	if _muzzle_flash != null:
		_muzzle_flash.light_energy = 10.0 * _flash_time / 0.05 if _flash_time > 0.0 else 0.0
	if _flash_star != null:
		_flash_star.visible = _flash_time > 0.0
	_update_hum()


func use_tick(trigger_down: bool, trigger_pressed: bool, delta: float) -> void:
	var was_reloading := _cooldown > 0.0
	_cooldown = maxf(_cooldown - delta, 0.0)
	if was_reloading and _cooldown <= 0.0 and ready_sound != "":
		Sound.play(ready_sound, -6.0)  # "chk-CHAK": you can fire again (only the shooter hears it)
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
	Seats.rumble(holder.player_id, fire_rumble, fire_rumble * 0.25, 0.06 + fire_rumble * 0.1)  # a kick on the shooter's controller with every shot
	Feedback.shake(holder.player_id, camera_kick)  # ...and on their camera (scripts/feedback.gd)
	# RECOIL (scripts/cat/cat_aim.gd): aim climbs, view rolls and thumps, spread blooms. Less when aiming.
	var aimed := lerpf(1.0, ads_recoil_scale, holder.aim.amount())
	holder.aim.kick(recoil_degrees * aimed, recoil_sideways_degrees * aimed, recoil_return,
		camera_roll_degrees * aimed, fov_punch_degrees * aimed, spread_bloom_degrees, max_bloom_degrees)

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
	# Spread = the gun's own wobble + bloom from firing fast, much tighter when aiming down sights.
	var spread := deg_to_rad((spread_degrees + holder.aim.bloom_degrees) * holder.aim.spread_scale(ads_spread_scale))
	aim = aim.rotated(camera.global_basis.x, _rng.randf_range(-spread, spread))
	aim = aim.rotated(camera.global_basis.y, _rng.randf_range(-spread, spread))

	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + aim * max_range)
	query.exclude = own_rids()  # don't shoot yourself (or the car you're riding in)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.position if hit else from + aim * max_range

	if blast_radius > 0.0:
		return end  # it flies there first: the blast does the hitting when it lands (draw_shot)
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
	query.exclude = own_rids()  # your own blast leaves you (and the car you ride in) alone
	var already := {}
	# (128: the answer also lists every street tile and wall in range, not just what can be hit.)
	for result in get_world_3d().direct_space_state.intersect_shape(query, 128):
		var target := Hit.target_of(result.collider)
		if target == null or already.has(target) or target == holder or target == holder.riding_car:
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
		if blast_radius > 0.0:
			var length := start.distance_to(ends[i])
			lob(start, ends[i], minf(lob_height, length * 0.2), minf(length / lob_speed, lob_max_seconds), _shot_landed)
		else:
			_draw_bolt(start, ends[i], pellet_color)

	if _muzzle_flash != null:
		_muzzle_flash.light_color = color
	_flash_time = 0.05
	_show_flash_star(color)
	_kick_model()
	if eject_casings:
		_eject_casing()
	if muzzle_smoke > 0:
		_puff_smoke(start, -_muzzle.global_basis.z if _muzzle != null else -global_basis.z)
	if shot_sound != "" and shots_seen % maxi(shots_per_sound, 1) == 0:
		Sound.play_at(shot_sound, start, shot_volume_db)  # every computer runs this, so play it just here
	if hum_sound != "":
		_keep_humming(shot_heat)


## Every computer: our holder's shot landed. Their computer does the hitting, like any shot.
func _shot_landed(where: Vector3) -> void:
	if holder != null and PlayerId.is_local(holder.player_id):
		_blast(where, -holder.global_basis.z)


## A blast gun's shot: arcs through the air from "from" to "to" in "seconds", hops on if this gun's
## shots bounce, then the blast. on_landed(where) runs after that. Every computer flies its own
## copy. It belongs to the gun: stop holding the gun and any shot still in the air is lost.
func lob(from: Vector3, to: Vector3, height: float, seconds: float, on_landed: Callable) -> void:
	if _lob_material == null:
		_lob_material = LevelKit.psx_material({"albedo_color": blast_color, "emission_color": blast_color, "emission_energy": 3.0})
	if lob_mesh == null:
		var yarn := SphereMesh.new()
		yarn.radius = 0.16
		yarn.height = 0.32
		yarn.radial_segments = 7
		yarn.rings = 3
		lob_mesh = yarn
	var ball := MeshInstance3D.new()
	ball.mesh = lob_mesh
	ball.material_override = _lob_material
	ball.top_level = true
	add_child(ball)
	ball.global_position = from
	_dress_lob(ball)
	var path := _lob_hops(from, to)
	var tween := ball.create_tween()
	tween.tween_method(_fly.bind(ball, from, to, height), 0.0, 1.0, seconds)
	for i in range(1, path.size()):
		tween.tween_callback(_lob_bounced.bind(path[i - 1]))
		tween.tween_method(_fly.bind(ball, path[i - 1], path[i], lob_bounce_height), 0.0, 1.0, lob_bounce_seconds)
	tween.tween_callback(_lob_landed.bind(ball, path[-1], on_landed))


## Where a lobbed shot touches down: "to", then a hop onward for each bounce, while there's a
## floor under it and no wall in the way.
func _lob_hops(from: Vector3, to: Vector3) -> PackedVector3Array:
	var path := PackedVector3Array([to])
	var onward := Motion.flat(to - from).normalized() * lob_bounce_distance
	var space := get_world_3d().direct_space_state
	var lift := Vector3.UP * 0.3
	for i in lob_bounces:
		var last := path[-1]
		var has_floor := not space.intersect_ray(PhysicsRayQueryParameters3D.create(last + lift, last - lift * 2.0)).is_empty()
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(last + lift, last + lift + onward))
		if not has_floor or not wall.is_empty():
			break
		path.append(last + onward)
	return path


func _fly(progress: float, ball: MeshInstance3D, from: Vector3, to: Vector3, height: float) -> void:
	ball.global_position = from.lerp(to, progress) + Vector3.UP * height * 4.0 * progress * (1.0 - progress)
	ball.rotation.x = progress * TAU


func _lob_landed(ball: MeshInstance3D, where: Vector3, on_landed: Callable) -> void:
	ball.queue_free()
	draw_blast(where)
	on_landed.call(where)


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
	if length < max_range * 0.95:  # (a miss into the sky: no sparks in mid-air)
		_burst_sparks(end, (start - end).normalized(), color)


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
	if blast_debris > 0:
		_blast_debris(centre)
	if blast_ring:
		_blast_ring(centre)
	Feedback.shake_near(centre, 0.45, blast_radius * 2.5)  # the ground shakes near the boom (scripts/feedback.gd)


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


# --- GUN FEEL: muzzle star, model kick, shell casings, impact sparks (every computer) ---

## The muzzle-flash STAR: two crossed glowing diamonds along the barrel plus a spiky burst facing
## forward, at the barrel tip, shown for one flash.
func _build_flash_star() -> void:
	if _muzzle == null or muzzle_flash_size <= 0.0:
		return
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	_flash_star = MeshInstance3D.new()
	_flash_star.mesh = tools.commit()
	_flash_star.material_override = _flash_material
	_flash_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_star.visible = false
	_muzzle.add_child(_flash_star)


func _show_flash_star(color: Color) -> void:
	if _flash_star == null:
		return
	_flash_material.albedo_color = Color(color.lerp(Color.WHITE, 0.45), 0.95)
	var roll := _rng.randf() * TAU
	var star_scale := Vector3.ONE * muzzle_flash_size * _rng.randf_range(0.75, 1.3)
	if not is_visible_in_tree() and _muzzle != null and is_inside_tree():
		# Hidden inside a car (gunner): spawn a brief world-space flash at the muzzle.
		var world_star := MeshInstance3D.new()
		world_star.mesh = _flash_star.mesh
		world_star.material_override = _flash_material
		world_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_star.top_level = true
		_effects_parent().add_child(world_star)
		world_star.global_transform = _muzzle.global_transform
		world_star.rotate_object_local(Vector3.FORWARD, roll)
		world_star.scale = star_scale
		get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(world_star):
				world_star.queue_free())
		return
	_flash_star.rotation = Vector3(0, 0, roll)  # a new spin every shot
	_flash_star.scale = star_scale
	_flash_star.visible = true


## The gun model slams back in the paw and flips its nose up, then eases back.
func _kick_model() -> void:
	if _gun_model == null or (gun_kickback <= 0.0 and gun_kick_degrees <= 0.0):
		return
	if _kick_tween != null:
		_kick_tween.kill()
	# Back = towards the cat: the barrel points along -Z, so +Z is back. Nose up = turn around X.
	var kicked := _gun_rest.translated_local(Vector3(0, 0, gun_kickback))
	kicked.basis = kicked.basis * Basis(Vector3.RIGHT, deg_to_rad(gun_kick_degrees))
	_gun_model.transform = kicked
	_kick_tween = create_tween()
	_kick_tween.tween_property(_gun_model, "transform", _gun_rest, gun_kick_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Where the casings and sparks go: the game world (so dropping the gun doesn't delete them).
func _effects_parent() -> Node:
	return Game.instance if Game.instance != null else self


## A brass shell casing spins out of the right side of the gun, arcs and drops away.
func _eject_casing() -> void:
	if _gun_model == null or not is_inside_tree():
		return
	if _casing_mesh == null:
		_casing_mesh = BoxMesh.new()
		_casing_mesh.size = Vector3(0.035, 0.035, 0.09)
	var casing := MeshInstance3D.new()
	casing.mesh = _casing_mesh
	casing.material_override = LevelKit.psx_material({"albedo_color": casing_color, "emission_color": casing_color, "emission_energy": 0.6})
	casing.top_level = true
	casing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_effects_parent().add_child(casing)
	var gun_basis := _gun_model.global_basis.orthonormalized()
	var from := _gun_model.global_position + gun_basis.y * 0.08
	casing.global_position = from
	var out := gun_basis.x * _rng.randf_range(0.5, 0.8) + gun_basis.z * _rng.randf_range(0.0, 0.2)
	var seconds := 0.55
	var tween := casing.create_tween().set_parallel()
	tween.tween_method(_fly_casing.bind(casing, from, out), 0.0, 1.0, seconds)
	tween.tween_property(casing, "rotation", Vector3(_rng.randf_range(8, 14), _rng.randf_range(-4, 4), 0), seconds)
	tween.chain().tween_callback(casing.queue_free)


## One step of a casing's arc: out to the side, a little hop up, then falling.
func _fly_casing(t: float, casing: MeshInstance3D, from: Vector3, out: Vector3) -> void:
	casing.global_position = from + out * t + Vector3.UP * (1.6 * t - 3.2 * t * t)


## A burst of little glowing chips flying off where a bolt hit ("back" = back towards the shooter).
func _burst_sparks(where: Vector3, back: Vector3, color: Color) -> void:
	if impact_sparks <= 0 or not is_inside_tree():
		return
	var sparks := CPUParticles3D.new()
	sparks.mesh = _spark_box()
	sparks.amount = impact_sparks
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
	_effects_parent().add_child(sparks)
	sparks.global_position = where + back * 0.1
	sparks.emitting = true
	get_tree().create_timer(0.6).timeout.connect(sparks.queue_free)


## The little glowing box every spark, trail bit and debris chunk is made of (made once, shared).
static func _spark_box() -> BoxMesh:
	if _spark_mesh == null:
		_spark_mesh = BoxMesh.new()
		_spark_mesh.size = Vector3.ONE * 0.05
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		_spark_mesh.material = material
	return _spark_mesh


# --- LAUNCHER JUICE: flying-shot dress-up, barrel smoke, blast debris + ground ring, laser hum ---
# (every computer runs these, like the rest of draw_shot)

## The flying shot's extras: a light it carries, a glowing trail and its whirr (all optional).
func _dress_lob(ball: MeshInstance3D) -> void:
	if lob_glow > 0.0:
		var light := OmniLight3D.new()
		light.light_color = blast_color
		light.light_energy = lob_glow
		light.omni_range = 3.0
		ball.add_child(light)
	if lob_trail > 0:
		var trail := CPUParticles3D.new()
		trail.mesh = _spark_box()
		trail.amount = lob_trail
		trail.lifetime = 0.35
		trail.local_coords = false  # bits stay where they were dropped: a streak behind the shot
		trail.spread = 180.0
		trail.initial_velocity_min = 0.2
		trail.initial_velocity_max = 0.8
		trail.gravity = Vector3(0, -2, 0)
		trail.scale_amount_min = 0.8
		trail.scale_amount_max = 1.8
		trail.color = blast_color.lerp(Color.WHITE, 0.35)
		ball.add_child(trail)
		trail.emitting = true
	if lob_loop_sound != "":
		var whirr := Sound.attach_loop(lob_loop_sound, ball, -6.0)
		if whirr != null:
			whirr.pitch_scale = lob_loop_pitch


## The shot touched the floor and hops on (cucumber grenade): a "boink" and a few sparks.
func _lob_bounced(where: Vector3) -> void:
	if lob_bounce_sound != "":
		Sound.play_at(lob_bounce_sound, where, -3.0)
	if is_inside_tree():
		_burst_sparks(where, Vector3.UP, blast_color)


## A puff of grey smoke out of the barrel that drifts up and fades ("forward" = where the barrel points).
func _puff_smoke(where: Vector3, forward: Vector3) -> void:
	if not is_inside_tree():
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
	smoke.amount = muzzle_smoke
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
	_effects_parent().add_child(smoke)
	smoke.global_position = where
	smoke.emitting = true
	smoke.finished.connect(smoke.queue_free)


## Glowing chunks thrown up and out of the blast, raining back down.
func _blast_debris(centre: Vector3) -> void:
	var debris := CPUParticles3D.new()
	debris.mesh = _spark_box()
	debris.amount = blast_debris
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.lifetime = 0.9
	debris.direction = Vector3.UP
	debris.spread = 75.0
	debris.initial_velocity_min = 4.0
	debris.initial_velocity_max = 4.0 + blast_radius * 2.0
	debris.gravity = Vector3(0, -18, 0)
	debris.scale_amount_min = 1.5
	debris.scale_amount_max = 3.5
	debris.color = blast_color.lerp(Color.WHITE, 0.25)
	debris.top_level = true
	_effects_parent().add_child(debris)
	debris.global_position = centre + Vector3.UP * 0.2
	debris.emitting = true
	debris.finished.connect(debris.queue_free)


## A flat neon ring racing out along the ground to a bit past the blast's edge.
func _blast_ring(centre: Vector3) -> void:
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
	material.albedo_color = Color(blast_color.lerp(Color.WHITE, 0.3), 0.9)
	mesh.material = material
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_effects_parent().add_child(ring)
	ring.global_position = centre + Vector3.UP * 0.1
	ring.scale = Vector3(0.3, 0.15, 0.3)  # squashed flat: a ripple, not a doughnut
	var grow := blast_radius * 1.3
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(grow, 0.15, grow), blast_time * 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, blast_time * 1.4)
	tween.chain().tween_callback(ring.queue_free)


## Every shot of a humming gun: start the hum if it isn't playing, keep it going a moment longer,
## and pitch it up as the gun heats.
func _keep_humming(shot_heat: float) -> void:
	_hum_until = Time.get_ticks_msec() / 1000.0 + 1.6 / maxf(fire_rate, 1.0) + 0.05
	if _hum == null or not is_instance_valid(_hum):
		_hum = Sound.attach_loop(hum_sound, self, hum_volume_db)
		if hum_start_sound != "":
			Sound.play_at(hum_start_sound, global_position, -4.0)
	if _hum != null:
		_hum.pitch_scale = 1.0 + shot_heat * hum_heat_pitch


## Each frame: no shots for a moment = the hum fades out fast (a quick fade, so it doesn't click).
func _update_hum() -> void:
	if _hum == null:
		return
	if not is_instance_valid(_hum):
		_hum = null
		return
	if Time.get_ticks_msec() / 1000.0 < _hum_until:
		return
	var fading := _hum
	_hum = null
	var tween := fading.create_tween()
	tween.tween_property(fading, "volume_db", -40.0, 0.08)
	tween.tween_callback(fading.queue_free)
