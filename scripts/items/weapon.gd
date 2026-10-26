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
## it hits, asks that thing's owner to apply the knockback, and sends one small "draw a
## bolt to here" message so everyone sees the shot.

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
## How hard a bolt shoves another cat (metres per second). Every bolt that hits a Roomba
## takes 1 of its health (see roomba.gd).
@export var cat_knockback: float = 7.0
## Little hop a zapped cat does.
@export var cat_hop: float = 3.0
## Push on the getaway car per bolt (the car weighs 800).
@export var car_impulse: float = 90.0

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
	_bolt_material = ShaderMaterial.new()
	_bolt_material.shader = preload("res://shaders/psx_lit.gdshader")
	_bolt_material.set_shader_parameter("albedo_color", Color.BLACK)
	_bolt_material.set_shader_parameter("emission_color", Color.WHITE)
	_bolt_material.set_shader_parameter("emission_energy", 8.0)
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
	var camera := holder.camera
	var aim := -camera.global_basis.z
	var spread := deg_to_rad(spread_degrees)
	aim = aim.rotated(camera.global_basis.x, _rng.randf_range(-spread, spread))
	aim = aim.rotated(camera.global_basis.y, _rng.randf_range(-spread, spread))
	holder.aim_until = Time.get_ticks_msec() / 1000.0 + 0.3  # cat turns to face the shot
	Seats.rumble(holder.player_id, 0.4, 0.1, 0.06)  # a little kick on the shooter's controller with every shot

	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + aim * max_range)
	query.exclude = [holder.get_rid()]  # don't shoot yourself
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.position if hit else from + aim * max_range

	if hit:
		var cat := hit.collider as CatPlayer
		var car := hit.collider as GetawayCar
		var roomba := hit.collider as Roomba
		if roomba != null:
			roomba.take_hit.rpc_id(1, holder.player_id)  # the host keeps score of Roomba health
		elif cat != null:
			# The zapped cat's OWN computer moves it, so ask that computer to do the shove.
			cat.get_zapped.rpc_id(cat.get_multiplayer_authority(), aim * cat_knockback + Vector3.UP * cat_hop)
		elif car != null:
			car.take_hit.rpc_id(car.get_multiplayer_authority(), aim * car_impulse, hit.position)

	if heat_per_shot > 0.0:
		heat = minf(heat + heat_per_shot, 1.0)
		if heat >= 1.0:
			is_overheated = true
	show_shot.rpc(end, heat)


## Everyone (including the shooter): draw a bolt from this gun's muzzle to "end".
@rpc("any_peer", "call_local", "unreliable_ordered")
func show_shot(end: Vector3, shot_heat: float) -> void:
	if holder == null or multiplayer.get_remote_sender_id() != PlayerId.peer_of(holder.player_id):
		return  # only the holder may fire
	shots_seen += 1
	var start := _muzzle.global_position if _muzzle != null else global_position
	var length := start.distance_to(end)
	if length < 0.05:
		return
	var color := bolt_color.lerp(hot_color, shot_heat)

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

	if _muzzle_flash != null:
		_muzzle_flash.light_color = color
	_flash_time = 0.05
	Sound.play_at(shot_sound, start, -4.0)  # every computer runs this, so play it just here


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
