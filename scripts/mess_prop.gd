class_name MessProp
extends Node3D
## CYPURRPUNK — ONE THING A CAT CAN MAKE A MESS WITH: a trash bin, a traffic cone, a cardboard box
## or an OVERCLEAN poster on a wall. (The rules live in scripts/mess_manager.gd; this script is only
## the prop itself: its model, its hit box, and how it looks knocked over / scratched / tidied.)
##
## Made in code by the city (city_generator.gd _add_mess_prop), never placed by hand, so you won't
## find these in a .tscn. What one looks like in the Remote scene tree while the game runs:
##   MessProp (Node3D)               <- this script; "id" = its number (same on every computer)
##   ├── Model (the .glb from res://models/, made PS1 by LevelKit.psx_ify)
##   ├── Hitbox (StaticBody3D)       <- guns and bats hit this (Hit framework: receive_hit below).
##   │                                  A BIN is also solid for cats (collision layer 4); cones,
##   │                                  boxes and posters only stop bullets (layer 5).
##   └── Debris (Node3D)             <- the litter it spills, only while knocked over
##
## MULTIPLAYER: every computer builds the same props in the same order from the city seed, so prop
## number 17 is the same bin everywhere. Only the host decides a prop got knocked or tidied, and
## tells everyone (MessManager._set_knocked). Nothing here is synced by itself.

enum Kind { BIN, CONE, BOX, POSTER }

## Collision layers (Project Settings > Layer Names > 3D Physics would call them 4 and 5).
## Layer 4 (value 8): solid for cats (cat_player.gd adds it to their mask), but the car's mask is
## layers 1 + 3 and VAC-COPs only look at layer 1, so cars and bots never crash into a bin.
const SOLID_LAYER := 8
## Layer 5 (value 16): nothing walks into it, but guns and bats (which test every layer) hit it.
const HIT_ONLY_LAYER := 16

## Which prop this is (set by the city: its place in CityGenerator.mess_props).
var id: int = -1
var kind: Kind = Kind.BIN
## Every computer: true while knocked over / scratched (MessManager says so).
var knocked: bool = false
## Every computer: which way it fell (for late joiners).
var fall_yaw: float = 0.0
## Host: the VAC-COP on its way to tidy this up (so two bots don't both come), or null.
var claimed_by: Node = null

var _model: Node3D
var _body: StaticBody3D
var _debris: Node3D
var _tween: Tween
var _home_transform: Transform3D  # the model standing up
var _fallen_transform: Transform3D  # the model lying down (worked out when it falls)
var _lid: Node3D  # (bins: the lid pops off and lands beside the can)
var _lid_home: Transform3D
var _poster: Node3D  # (posters: the clean sheet...)
var _torn: Node3D    # ...and the shredded strips under it
## How far a knocked-over bin's lid swings open (degrees around its hinge).
var lid_open_degrees: float = 115.0


## How wide the prop is (metres from its middle), for bumping into it and for bots parking next to it.
func radius() -> float:
	match kind:
		Kind.BIN: return 0.36
		Kind.CONE: return 0.3
		Kind.BOX: return 0.36
		_: return 0.5


## Built by the city: "model_path" = the .glb, solid = a bin cats can't walk through.
func setup(prop_id: int, prop_kind: Kind, model_path: String, solid: bool) -> void:
	id = prop_id
	kind = prop_kind
	name = "Mess%d" % prop_id
	_model = LevelKit.instantiate_model(model_path, self)
	if _model != null:
		_model.name = "Model"
		_home_transform = _model.transform
		_lid = _model.find_child("Lid", true, false) as Node3D
		if _lid != null:
			_lid_home = _lid.transform
		_poster = _model.find_child("Poster", true, false) as Node3D
		_torn = _model.find_child("Torn", true, false) as Node3D
		if _torn != null:
			_torn.visible = false
	# The hit box (a plain box the size of the prop).
	_body = StaticBody3D.new()
	_body.name = "Hitbox"
	_body.collision_layer = SOLID_LAYER if solid else HIT_ONLY_LAYER
	_body.collision_mask = 0
	add_child(_body)
	match kind:
		Kind.BIN: LevelKit.add_collision(_body, Vector3(0, 0.55, 0), Vector3(0.66, 1.1, 0.66))
		Kind.CONE: LevelKit.add_collision(_body, Vector3(0, 0.35, 0), Vector3(0.5, 0.7, 0.5))
		Kind.BOX: LevelKit.add_collision(_body, Vector3(0, 0.33, 0), Vector3(0.7, 0.66, 0.7))
		Kind.POSTER: LevelKit.add_collision(_body, Vector3(0, 0.7, -0.05), Vector3(1.0, 1.4, 0.1))
	_body.set_meta("solid_layer", _body.collision_layer)
	add_to_group(Interactable.GROUP)  # E = knock it over / scratch it (interact_* below)


## Where a VAC-COP parks to tidy it (posters: on the pavement in front of the wall).
func tidy_spot() -> Vector3:
	if kind == Kind.POSTER:
		return global_position - global_basis.z * 0.9  # (the poster's front faces -Z)
	return global_position


# --- Shooting / hitting it (the Hit framework, scripts/hit.gd) ---

## Runs on the shooter's computer: a bolt or a bat hit us. Ask the host to knock us over.
func receive_hit(hit: Hit) -> bool:
	if not knocked and hit.shooter != null and MessManager.instance != null:
		MessManager.instance.knock(hit.shooter.player_id, id, hit.direction)
	return false  # (no damage number: it's a bin)


# --- The E key (scripts/interactable.gd) ---

func interact_distance(cat: CatPlayer) -> float:
	if knocked or MessManager.instance == null or not cat.visible or cat.is_downed():
		return -1.0
	var distance := Motion.flat_distance(cat.global_position, tidy_spot() if kind == Kind.POSTER else global_position)
	return distance if distance < MessManager.instance.interact_reach + radius() else -1.0


func interact_prompt(_cat: CatPlayer) -> String:
	if MessManager.instance == null:
		return ""
	return MessManager.instance.prompt_for(kind)


func interact(cat: CatPlayer) -> void:
	MessManager.instance.knock(cat.player_id, id, Motion.flat(global_position - cat.global_position).normalized())


## Below everything else (items 30, NPCs 20, stash 10, the car 0): never steals the car's E.
func interact_priority() -> int:
	return -5


# --- How it looks (every computer; MessManager calls these) ---

## Knock it over towards "fall_yaw" (the direction it was pushed, as a turn around the vertical).
## instant = no animation and no sound (a late joiner catching up).
func show_knocked(yaw: float, instant: bool) -> void:
	knocked = true
	fall_yaw = yaw
	_body.collision_layer = 0  # lying down: walk over it, shoot past it
	if _model == null:
		return
	var push := Vector3(-sin(yaw), 0, -cos(yaw))
	var local_push := (global_basis.inverse() * push).normalized()
	if local_push == Vector3.ZERO:
		local_push = Vector3.FORWARD
	var axis := Vector3.UP.cross(local_push).normalized()  # tip over around this (sideways) line
	var tip_degrees := 90.0
	var lift := 0.0
	var slide := 0.0
	match kind:
		Kind.BIN:
			lift = 0.33
		Kind.CONE:
			tip_degrees = 104.0  # (like the city's old fallen cones: rim and tip both on the ground)
			lift = 0.22
		Kind.BOX:
			lift = 0.34
			slide = 0.35  # a box tumbles a little further
	var fallen := _home_transform
	if kind != Kind.POSTER:
		fallen.basis = Basis(axis, -deg_to_rad(tip_degrees)) * _home_transform.basis
		# Rotating round the bottom middle sinks half of it into the street: lift it back out and
		# move it along the push, so it lies where it fell (its foot stays roughly put).
		fallen.origin = _home_transform.origin + Vector3.UP * lift + local_push * (0.5 * _height() + slide)
	_fallen_transform = fallen
	_spill_debris(local_push)
	if kind == Kind.POSTER:
		if _poster != null:
			_poster.visible = false
		if _torn != null:
			_torn.visible = true
	if instant:
		_model.transform = fallen
		_pop_lid(local_push, 1.0)
		return
	_play_tween(0.0, 1.0, 0.45, local_push)
	Sound.play_at(_knock_sound(), global_position + Vector3.UP * 0.4, -2.0)


## Stand it back up and sweep the litter away (a VAC-COP tidied it, or a new district).
func show_standing(instant: bool) -> void:
	knocked = false
	claimed_by = null
	_body.collision_layer = _body.get_meta("solid_layer", HIT_ONLY_LAYER)
	if _debris != null:
		_debris.queue_free()
		_debris = null
	if _poster != null:
		_poster.visible = true
	if _torn != null:
		_torn.visible = false
	if _model == null:
		return
	if instant or kind == Kind.POSTER:
		_model.transform = _home_transform
		_pop_lid(Vector3.ZERO, 0.0)
	else:
		_play_tween(1.0, 0.0, 0.35, Vector3.ZERO)
	if not instant:
		Sound.play_at("prop_standup", global_position + Vector3.UP * 0.3, -6.0)


func _height() -> float:
	match kind:
		Kind.BIN: return 1.15
		Kind.CONE: return 0.72
		Kind.BOX: return 0.66
		_: return 1.4


func _knock_sound() -> String:
	match kind:
		Kind.BIN: return "bin_clatter"      # sounds/sfx/bin_clatter.wav
		Kind.CONE: return "cone_bounce"     # sounds/sfx/cone_bounce.wav
		Kind.BOX: return "box_thump"        # sounds/sfx/box_thump.wav
		_: return "poster_scratch"          # sounds/sfx/poster_scratch.wav


func _play_tween(from: float, to: float, seconds: float, push: Vector3) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if kind == Kind.POSTER:
		return  # (a poster doesn't fall: it's just shredded)
	_tween = create_tween()
	_tween.tween_method(_set_fall.bind(push), from, to, seconds) \
		.set_trans(Tween.TRANS_BOUNCE if to > from else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 0 = standing, 1 = lying where it fell.
func _set_fall(amount: float, push: Vector3) -> void:
	if not is_instance_valid(_model):
		return
	_model.transform = _home_transform.interpolate_with(_fallen_transform, amount)
	_pop_lid(push, amount)


## Bins: the lid flips open on its hinge (amount 0 = shut, 1 = hanging wide open). The Lid part's
## pivot is the hinge (models/blockbench/trash_bin.bbmodel: the Lid group's origin).
func _pop_lid(push: Vector3, amount: float) -> void:
	if _lid == null:
		return
	if amount <= 0.0 or push == Vector3.ZERO:
		_lid.transform = _lid_home
		return
	_lid.transform = _lid_home.rotated_local(Vector3.BACK, deg_to_rad(lid_open_degrees) * amount)


## A few bits of litter on the pavement where it fell (every computer makes the same bits: the
## random numbers come from the prop's own number, not the city's RNG, so the city is unchanged).
func _spill_debris(push: Vector3) -> void:
	if _debris != null:
		_debris.queue_free()
	_debris = Node3D.new()
	_debris.name = "Debris"
	add_child(_debris)
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7919 + 13
	var count := 3 if kind == Kind.CONE else 6
	var colors: Array[Color] = [Color(0.35, 0.4, 0.3), Color(0.55, 0.5, 0.35), Color(0.75, 0.7, 0.6), Color(0.3, 0.25, 0.2)]
	if kind == Kind.BOX:
		colors = [Color(0.9, 0.88, 0.8), Color(0.6, 0.45, 0.28), Color(0.85, 0.85, 0.9)]
	elif kind == Kind.POSTER:
		colors = [Color(0.92, 0.88, 0.75), Color(0.25, 0.4, 0.75), Color(0.8, 0.2, 0.15)]
	elif kind == Kind.CONE:
		colors = [Color(0.95, 0.45, 0.12), Color(0.9, 0.9, 0.9)]
	var out := push if push != Vector3.ZERO else Vector3.FORWARD
	if kind == Kind.POSTER:
		out = Vector3.FORWARD  # paper bits fall on the pavement in front of the wall
	for i in count:
		var spot := out * rng.randf_range(0.4, 1.6) + out.cross(Vector3.UP) * rng.randf_range(-0.6, 0.6)
		var size := Vector3(rng.randf_range(0.12, 0.28), 0.08, rng.randf_range(0.1, 0.22))
		# (0.08 m tall, never a flat sheet: a sheet a few cm above the street would flicker.)
		var bit := LevelKit.add_box(_debris, spot + Vector3.UP * 0.04, size, MessManager.instance.debris_material if MessManager.instance != null else null, false)
		bit.rotation.y = rng.randf() * TAU
		bit.set_instance_shader_parameter("instance_tint", colors[rng.randi() % colors.size()])
