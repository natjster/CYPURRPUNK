class_name RecruitHome
extends Node3D
## A SEWER REBELLION recruit's OWN THING: the piece of furniture they move in with, so every
## recruit fills out the sewer a bit more (Lil' Mittens' cardboard box, Nonna's kitchen,
## Frankie's garage...). It's hidden until its cat is recruited, then pops into place.
##
## HOW TO ADD ONE (Godot editor):
##   1. Open scenes/main.tscn. Right-click the gang's hub node (Hub or GangHub) > Add Child Node >
##      Node3D, name it e.g. "MittensHome".
##   2. Drag scripts/recruit_home.gd onto it (or Inspector > Script > Load).
##   3. Inspector: Npc = pick the recruit (e.g. LilMittens). Model = the .glb file name in models/
##      without ".glb" (e.g. mittens_box). Move/turn the node with the gizmo: the model's open front
##      (-Z, the blue arrow's back) faces the room.
##   4. Solid Size = the box cats bump into (0,0,0 = walk-through). Sign Text = a glowing sign.
## Models come from tools/make_recruit_home_specs.py (open models/blockbench/<name>.bbmodel in
## Blockbench to repaint one). Parts named Glow / Lamp / Burner light up, Sign glows softly, Trim
## glows in the gang colour, Swing sways (the punching bag).
##
## FRANKIE'S GARAGE: tick Show Ride and the gang's chosen ride (NEON ZOOM-BIKE, MEOW-VAN or the
## interceptor, picked on the TINKER WORKBENCH) is parked inside, and it swaps the moment you pick
## another. Give a home a Prompt and E on it opens the workbench on that recruit's tab.
##
## Every computer works this out by itself from the synced upgrades (Npc.is_recruited), like the
## NPCs do: nothing to send over the network.

## The recruit this belongs to. Empty = always there.
@export var npc: Npc
## The model file in res://models/ (no ".glb").
@export var model: String = ""
## How long the "moving in" pop takes (seconds). 0 = just appear.
@export var pop_seconds: float = 0.45

@export_group("Solid")
## The box cats bump into (metres, model space). (0,0,0) = cats walk through it.
@export var solid_size: Vector3 = Vector3.ZERO
## Where that box's middle sits (metres, model space; Y = height of the middle).
@export var solid_offset: Vector3 = Vector3.ZERO

@export_group("Sign")
## Glowing text over it ("" = no sign). "\n" = new line.
@export var sign_text: String = ""
@export var sign_offset: Vector3 = Vector3(0, 2.0, 0)
@export var sign_color: Color = Color(1, 0.8, 0.4)
@export var sign_size: int = 22

@export_group("Light")
## A warm light pool over it. Energy 0 = no light.
@export var light_color: Color = Color(1, 0.75, 0.45)
@export var light_energy: float = 1.5
@export var light_range: float = 4.0
@export var light_offset: Vector3 = Vector3(0, 1.6, -0.6)

@export_group("Life")
## How bright the glowing parts are (Glow / Lamp / Burner).
@export var glow_energy: float = 3.0
## Puffs of steam (Nonna's gravy). Off by default.
@export var steam: bool = false
@export var steam_offset: Vector3 = Vector3.ZERO
## How far the "Swing" part sways (degrees) and how fast (swings a second).
@export var sway_degrees: float = 4.0
@export var sway_speed: float = 0.6

@export_group("Garage")
## Park the gang's chosen ride inside (Frankie's garage).
@export var show_ride: bool = false
## Where it's parked (metres, model space) and which way its nose points (degrees).
@export var ride_offset: Vector3 = Vector3(0, 0.45, 0.1)
@export var ride_yaw_degrees: float = 90.0
## How much the ride slowly rocks on its springs, like a showroom (metres). 0 = still.
@export var ride_bob: float = 0.02

@export_group("Extra Piece")
## A SECOND model that belongs to this home and moves in with it (Lil' Mittens: the big cardboard-box
## shanty, models/box_shanty.glb). "" = none. Its "Window" part glows like a lit window.
@export var extra_model: String = ""
## Where it sits (metres, this node's space) and how much it's turned (degrees).
@export var extra_offset: Vector3 = Vector3.ZERO
@export var extra_yaw_degrees: float = 0.0
## Its own box cats bump into (metres, the extra piece's space; 0,0,0 = walk-through).
@export var extra_solid_size: Vector3 = Vector3.ZERO
@export var extra_solid_offset: Vector3 = Vector3.ZERO

@export_group("Press E")
## The HUD line (after "[E] "). "" = can't be used. Using it opens the TINKER WORKBENCH on this
## recruit's tab.
@export var prompt: String = ""
@export var prompt_radius: float = 3.0

## The ride models, by Upgrades vehicle id (same as getaway_car.gd set_vehicle).
const RIDE_MODELS := {"interceptor": "getaway_car", "cyber_bike": "cyber_bike", "fish_van": "fish_van"}

var present: bool = true
## Set by the recruit reveal (scripts/recruit_reveal.gd): wait this long before the next pop, so
## the furniture pops in together with its cat while the camera is watching. Used once.
var pop_delay: float = 0.0
var _model: Node3D
var _extra: Node3D
var _swing: Node3D
var _ride: Node3D
var _ride_id: String = ""
var _shapes: Array[CollisionShape3D] = []
var _check_timer: float = 0.0
var _checked_once := false
var _time: float = 0.0


func _ready() -> void:
	_model = LevelKit.instantiate_model(model, self) if model != "" else null
	if _model != null:
		_model.name = "Model"
		_light_up(_model)
		_swing = _model.find_child("Swing", true, false) as Node3D
	if solid_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.name = "Solid"
		add_child(body)
		LevelKit.add_collision(body, solid_offset, solid_size)
		for shape in body.find_children("*", "CollisionShape3D", true, false):
			_shapes.append(shape)
	if extra_model != "":
		_build_extra()
	if sign_text != "":
		# A Label3D reads from its +Z side; the room is on our -Z side, so turn it round.
		LevelKit.add_sign(self, sign_text, sign_offset, sign_color, sign_size, PI)
	if light_energy > 0.0:
		LevelKit.add_light(self, light_offset, light_color, light_energy, light_range)
	if steam:
		add_child(_make_steam())
	if prompt != "":
		add_to_group(Interactable.GROUP)


func _process(delta: float) -> void:
	_time += delta
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.25  # (like Npc: checked a few times a second, never in _ready)
		_update_presence()
		if present and show_ride:
			_update_ride()
	if not present:
		return
	if _swing != null and sway_degrees > 0.0:
		_swing.rotation.x = deg_to_rad(sway_degrees) * sin(_time * TAU * sway_speed)
		_swing.rotation.z = deg_to_rad(sway_degrees * 0.4) * sin(_time * TAU * sway_speed * 0.7)
	if _ride != null and ride_bob > 0.0:
		_ride.position.y = ride_offset.y + ride_bob * sin(_time * 1.3)


# --- Moving in ---

func is_here() -> bool:
	return npc == null or npc.is_recruited()


func _update_presence() -> void:
	var now := is_here()
	if now == present and _checked_once:
		return
	var first := not _checked_once
	_checked_once = true
	present = now
	visible = now
	for shape in _shapes:
		shape.set_deferred("disabled", not now)
	if now and not first and pop_seconds > 0.0 and _model != null:
		# Moving in: drops in a little squashed and bounces up to full size.
		var tween := create_tween()
		var popping: Array[Node3D] = [_model]  # (the extra piece, e.g. Mittens' shanty, pops too)
		if _extra != null:
			popping.append(_extra)
		if pop_delay > 0.0:
			for piece in popping:
				piece.scale = Vector3(0.001, 0.001, 0.001)  # (too small to see until the pop)
			tween.tween_interval(pop_delay)
			pop_delay = 0.0
		tween.tween_callback(func():
			for piece in popping:
				piece.scale = Vector3(1.3, 0.2, 1.3))
		for i in popping.size():
			var step := tween.tween_property(popping[i], "scale", Vector3.ONE, pop_seconds) if i == 0 \
				else tween.parallel().tween_property(popping[i], "scale", Vector3.ONE, pop_seconds)
			step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The Extra Piece: its own model (+ solid box), parented to this home so it hides/pops with it.
func _build_extra() -> void:
	var holder := Node3D.new()
	holder.name = "Extra"
	holder.position = extra_offset
	holder.rotation.y = deg_to_rad(extra_yaw_degrees)
	add_child(holder)
	_extra = LevelKit.instantiate_model(extra_model, holder)
	if _extra != null:
		_extra.name = "ExtraModel"
		_light_up(_extra)
		LevelKit.make_neon_paint_glow(_extra, {"Window": 2.5})  # someone's home: the window's lit
	if extra_solid_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.name = "ExtraSolid"
		holder.add_child(body)
		LevelKit.add_collision(body, extra_solid_offset, extra_solid_size)
		for shape in body.find_children("*", "CollisionShape3D", true, false):
			_shapes.append(shape)


# --- The glowing parts ---

func _light_up(root: Node) -> void:
	var gang := Teams.color_of(_team())
	for part in ["Glow", "Lamp", "Burner"]:
		_glow(root, part, Color.WHITE, glow_energy, false)
	_glow(root, "Sign", Color.WHITE, 1.2, false)
	for trim in root.find_children("Trim*", "MeshInstance3D", true, false):
		_glow(root, trim.name, gang, 2.5, true)


## (the same trick as getaway_car.gd _glow) tinted = glow in that colour; else the paint glows.
func _glow(root: Node, part_name: String, tint: Color, energy: float, tinted: bool) -> void:
	var part := root.find_child(part_name, true, false) as MeshInstance3D
	if part == null or part.mesh == null:
		return
	for surface in part.mesh.get_surface_count():
		var material := part.get_active_material(surface)
		if not material is ShaderMaterial:
			continue
		var copy := material.duplicate() as ShaderMaterial
		copy.set_shader_parameter("albedo_color", tint)
		if tinted:
			copy.set_shader_parameter("emission_color", tint)
			copy.set_shader_parameter("emission_energy", energy)
		else:
			copy.set_shader_parameter("texture_glow", energy)
		part.set_surface_override_material(surface, copy)


func _team() -> int:
	var hub := get_parent() as UndergroundHub
	return maxi(0, hub.team) if hub != null else 0


# --- Frankie's garage: the gang's chosen ride, parked ---

func _update_ride() -> void:
	var id := Upgrades.instance.vehicle_of(_team()) if Upgrades.instance != null else "interceptor"
	if id == _ride_id or not RIDE_MODELS.has(id):
		return
	_ride_id = id
	if _ride != null:
		_ride.queue_free()
	_ride = LevelKit.instantiate_model(RIDE_MODELS[id], self, ride_offset, deg_to_rad(ride_yaw_degrees))
	if _ride == null:
		return
	_ride.name = "Ride"
	_light_up(_ride)
	for part in ["HeadlightL", "HeadlightR", "TaillightL", "TaillightR", "Thrusters", "Sign"]:
		_glow(_ride, part, Color.WHITE, 2.0, false)
	if _checked_once and pop_seconds > 0.0:
		_ride.scale = Vector3(0.6, 0.6, 0.6)
		create_tween().tween_property(_ride, "scale", Vector3.ONE, pop_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	print("[RecruitHome] %s: parked the %s" % [name, id])


# --- Steam (Nonna's pot) ---

func _make_steam() -> CPUParticles3D:
	var puffs := CPUParticles3D.new()
	puffs.name = "Steam"
	puffs.position = steam_offset
	puffs.amount = 10
	puffs.lifetime = 1.6
	puffs.direction = Vector3.UP
	puffs.spread = 12.0
	puffs.gravity = Vector3(0, 0.3, 0)
	puffs.initial_velocity_min = 0.3
	puffs.initial_velocity_max = 0.5
	puffs.scale_amount_min = 0.6
	puffs.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.9, 0.9, 0.85, 0.35)
	material.vertex_color_use_as_albedo = true
	quad.material = material
	puffs.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.8))
	fade.set_color(1, Color(1, 1, 1, 0))
	puffs.color_ramp = fade
	return puffs


# --- Press E (Interactable framework, scripts/interactable.gd) ---

func interact_distance(cat: CatPlayer) -> float:
	if prompt == "" or not present:
		return -1.0
	var distance := global_position.distance_to(cat.global_position)
	return distance if distance < prompt_radius else -1.0


func interact_prompt(_cat: CatPlayer) -> String:
	return prompt


func interact_priority() -> int:
	return 10


func interact(cat: CatPlayer) -> void:
	var hub := get_parent() as UndergroundHub
	if hub == null:
		return
	var screen := WorkbenchScreen.for_seat(cat.slot)
	if screen == null:
		return
	if npc != null and npc.rebellion_tier > 0:
		screen.tab = npc.rebellion_tier + 1  # workbench tabs: 0 boss, 1 shopkeeper, 2-6 = recruits 1-5
	screen.open(cat, hub)
