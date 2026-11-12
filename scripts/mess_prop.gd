class_name MessProp
extends Node3D
## CYPURRPUNK — ONE THING A CAT CAN MAKE A MESS WITH. The rules (who may knock what, the heat, the
## loot) live in scripts/mess_manager.gd; this script is only the prop itself: its model, its hit
## box, and how it looks knocked over / busted / tidied.
##
## THE KINDS (Kind below):
##   BIN, CONE, BOX       tip over and spill litter (a heavy BIN needs ZOOMIES to run over)
##   POSTER               OVERCLEAN's poster on a wall: scratched to shreds
##   VENDING   (STREET PROPS PACK) FISH 2 GO machine: KICK it -> it jolts back, the screen dies,
##                        the flap swings open, sparks + snacks spill (the host drops one fish, once)
##   HYDRANT              WRENCH OPEN -> the cap pops off and a WATER GEYSER erupts for Hydrant
##                        Geyser Seconds: it launches cats (and cars) skyward and shorts out bots
##   CART                 SHOVE / run into it -> it rolls ~8.5 m, bowling over props and bots, then
##                        tips onto its side where it stopped
##   NEON_SIGN            KICK OVER / run into it -> it falls flat and the neon dies in sparks
##   DUMPSTER             RUMMAGE -> the lid flies open and trash bags spill (the host may find SCRAP)
##
## Made in code by the city (city_generator.gd _add_mess_prop), never placed by hand, so you won't
## find these in a .tscn. What one looks like in the Remote scene tree while the game runs:
##   MessProp (Node3D)               <- this script; "id" = its number (same on every computer)
##   ├── Model (the .glb from res://models/, made PS1 by LevelKit.psx_ify)
##   ├── Hitbox (StaticBody3D)       <- guns and bats hit this (Hit framework: receive_hit below).
##   │                                  BINS, VENDING machines, HYDRANTS and DUMPSTERS are also solid
##   │                                  for cats (collision layer 4); the rest only stop bullets (layer 5).
##   ├── Glow (OmniLight3D)          <- vending machines + neon signs only, while powered
##   ├── Geyser (Node3D)             <- hydrants only, while the water's spraying
##   └── Debris (Node3D)             <- the litter it spills, only while knocked over
##
## The Blockbench models' PART NAMES matter (tools/make_street_prop_specs.py): Screen / Flap (vending),
## Cap (hydrant), Handle (cart), SignFace (neon), Lid (bin, dumpster).
##
## MULTIPLAYER: every computer builds the same props in the same order from the city seed, so prop
## number 17 is the same bin everywhere. Only the host decides a prop got knocked or tidied, and
## tells everyone (MessManager._set_knocked). Nothing here is synced by itself: the geyser and the
## cart's roll run on every computer from that one message. Where a cart stops is worked out from
## the BUILDINGS only (never cats or cars), so it stops in the same spot everywhere.

enum Kind { BIN, CONE, BOX, POSTER, VENDING, HYDRANT, CART, NEON_SIGN, DUMPSTER }

## Collision layers (Project Settings > Layer Names > 3D Physics would call them 4 and 5).
## Layer 4 (value 8): solid for cats (cat_player.gd adds it to their mask), but the car's mask is
## layers 1 + 3 and VAC-COPs only look at layer 1, so cars and bots never crash into a bin.
const SOLID_LAYER := 8
## Layer 5 (value 16): nothing walks into it, but guns and bats (which test every layer) hit it.
const HIT_ONLY_LAYER := 16

## Which prop this is (set by the city: its place in CityGenerator.mess_props).
var id: int = -1
var kind: Kind = Kind.BIN
## Every computer: true while knocked over / busted (MessManager says so).
var knocked: bool = false
## Every computer: which way it fell (for late joiners).
var fall_yaw: float = 0.0
## Host: the VAC-COP on its way to tidy this up (so two bots don't both come), or null.
var claimed_by: Node = null
## Host: the player who knocked it (a rolling CART's strikes are credited to them).
var knocked_by: int = 0
## Set by the city before setup(): false = a BLACKOUT district, so screens and neon stay dark.
var powered: bool = true

## How far a knocked-over bin's lid swings open (degrees around its hinge).
var lid_open_degrees: float = 115.0

# --- STREET PROPS PACK tuning (plain vars: every prop is made in code, so the Inspector can't
# reach them; change the numbers here) ---
## DUMPSTER: how far the lid swings open (degrees round its back hinge).
var dumpster_lid_degrees: float = 125.0
## VENDING: how far the machine jolts back when kicked (degrees), and how wide the flap opens.
var vending_tilt_degrees: float = 8.0
var vending_flap_degrees: float = 70.0
## HYDRANT: how long the geyser sprays (seconds), how tall it is (metres).
var hydrant_geyser_seconds: float = 12.0
var geyser_height: float = 6.0
## HYDRANT: VAC-COPs / drones within this flat distance get shorted out (host)...
var geyser_stun_radius: float = 2.4
var geyser_stun_seconds: float = 3.5
var geyser_stun_cooldown: float = 1.5
var geyser_push: float = 7.0
## ...cats this close are launched straight up (owner's computer), cars this close bounce (driver's).
var geyser_launch_radius: float = 1.3
var geyser_launch_speed: float = 13.5
var geyser_launch_cooldown: float = 0.6
var geyser_car_radius: float = 2.0
var geyser_car_bounce: float = 8.5
## CART: how far it rolls (metres) in how long (seconds), then how far over it tips.
var cart_roll_distance: float = 8.5
var cart_roll_seconds: float = 0.7
var cart_tip_degrees: float = 88.0
## CART: props within this of its path get knocked over, bots within Cart Bowl Bot Reach get bowled.
var cart_bowl_prop_reach: float = 1.1
var cart_bowl_bot_reach: float = 1.4
var cart_bowl_damage: int = 25
var cart_bowl_stun: float = 3.0
var cart_bowl_push: float = 14.0
## NEON_SIGN: how far over it falls.
var neon_tip_degrees: float = 85.0

var _model: Node3D
var _body: StaticBody3D
var _debris: Node3D
var _tween: Tween
var _home_transform: Transform3D  # the model standing up
var _fallen_transform: Transform3D  # the model lying down (worked out when it falls)
var _rolled_transform: Transform3D  # CART: where it stops rolling, before it tips
var _lid: Node3D  # (bins: the lid pops off; dumpsters: it swings open)
var _lid_home: Transform3D
var _poster: Node3D  # (posters: the clean sheet...)
var _torn: Node3D    # ...and the shredded strips under it
var _flap: Node3D    # (vending: the dispense flap)
var _flap_home: Transform3D
var _cap: Node3D     # (hydrant: the cap that pops off)
var _cap_home: Transform3D
var _cap_side: Vector3 = Vector3.RIGHT
var _glow_meshes: Array[MeshInstance3D] = []  # the parts that glow (screen, neon face, cart handle)
var _light: OmniLight3D
var _flicker_left: float = 0.0  # seconds of the screen / neon fizzing out
var _sparks_left: float = 0.0   # seconds the glowing sparks in the debris keep fizzing
var _sparks: Array[MeshInstance3D] = []
var _geyser: Node3D
var _geyser_left: float = 0.0
var _geyser_column: Array[MeshInstance3D] = []
var _geyser_drops: Array[MeshInstance3D] = []
var _geyser_clock: float = 0.0
var _zapped: Dictionary = {}     # host: {enemy instance id: time it was last shorted out}
var _launched: Dictionary = {}   # this computer: {cat / car instance id: time it was last launched}
var _roll_left: float = 0.0      # CART: seconds left of the roll (host bowls things over meanwhile)
var _bowled: Dictionary = {}     # host: {node instance id: true} already hit by this roll



## How wide the prop is (metres from its middle), for bumping into it and for bots parking next to it.
func radius() -> float:
	match kind:
		Kind.BIN: return 0.36
		Kind.CONE: return 0.3
		Kind.BOX: return 0.36
		Kind.VENDING: return 0.65
		Kind.HYDRANT: return 0.3
		Kind.CART: return 0.5
		Kind.NEON_SIGN: return 0.4
		Kind.DUMPSTER: return 1.1
		_: return 0.5


## Built by the city: "model_path" = the .glb, solid = cats can't walk through it.
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
		_flap = _model.find_child("Flap", true, false) as Node3D
		if _flap != null:
			_flap_home = _flap.transform
		_cap = _model.find_child("Cap", true, false) as Node3D
		if _cap != null:
			_cap_home = _cap.transform
		# The glowing bits: the vending SCREEN (+ its FISH 2 GO header), the NEON face, the cart HANDLE.
		match kind:
			Kind.VENDING: _make_glow("Screen", 3.0)
			Kind.NEON_SIGN: _make_glow("SignFace", 4.0)
			Kind.CART: _make_glow("Handle", 2.2)
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
		Kind.VENDING: LevelKit.add_collision(_body, Vector3(0, 0.925, 0), Vector3(1.1, 1.85, 0.75))
		Kind.HYDRANT: LevelKit.add_collision(_body, Vector3(0, 0.425, 0), Vector3(0.55, 0.85, 0.55))
		Kind.CART: LevelKit.add_collision(_body, Vector3(0, 0.475, 0), Vector3(0.75, 0.95, 1.05))
		Kind.NEON_SIGN: LevelKit.add_collision(_body, Vector3(0, 0.525, 0), Vector3(0.75, 1.05, 0.65))
		Kind.DUMPSTER: LevelKit.add_collision(_body, Vector3(0, 0.65, 0), Vector3(2.1, 1.3, 1.25))
	_body.set_meta("solid_layer", _body.collision_layer)
	# A little pool of coloured light from the screen / the neon (not in a BLACKOUT).
	if powered and kind == Kind.VENDING:
		_light = LevelKit.add_light(self, Vector3(0, 1.3, -0.9), Color(0.35, 0.9, 1.0), 1.2, 3.5, 30.0)
	elif powered and kind == Kind.NEON_SIGN:
		_light = LevelKit.add_light(self, Vector3(0, 0.7, -0.7), Color(1.0, 0.3, 0.75), 0.9, 3.0, 30.0)
	if _light != null:
		_light.name = "Glow"
	_show_glow(1.0 if powered else 0.0)
	add_to_group(Interactable.GROUP)  # E = knock it over / scratch it / kick it (interact_* below)


## Where a VAC-COP parks to tidy it: in front of a poster / vending machine / dumpster (their
## backs are to a wall), where a rolled CART came to rest, else right at the prop.
func tidy_spot() -> Vector3:
	match kind:
		Kind.POSTER, Kind.VENDING:
			return global_position - global_basis.z * 0.9  # (the front faces -Z)
		Kind.DUMPSTER:
			return global_position - global_basis.z * 1.1
		Kind.CART:
			if knocked:
				var rest := global_transform * _fallen_transform.origin
				return Vector3(rest.x, global_position.y, rest.z)
	return global_position


## Can a cat knock this over just by running into it? (Posters are on walls; vending machines,
## hydrants and dumpsters are far too heavy: E, a hit or a car.) Bins need zoomies (MessManager).
func cat_can_bump() -> bool:
	return kind in [Kind.BIN, Kind.CONE, Kind.BOX, Kind.CART, Kind.NEON_SIGN]


## Can a rolling CART bowl this over? (Light things standing on the pavement.)
func cart_can_bowl() -> bool:
	return kind in [Kind.BIN, Kind.CONE, Kind.BOX, Kind.CART, Kind.NEON_SIGN]


## True while a burst hydrant's geyser is spraying (VAC-COPs won't come to tidy it till it stops).
func geyser_active() -> bool:
	return _geyser_left > 0.0


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
	var spot := tidy_spot() if kind == Kind.POSTER else global_position
	# Height check: the sewer hub is 200 m straight BELOW the city, so a flat (map) distance alone let cats
	# down there knock over street props right above their heads. Too far up/down = out of reach.
	if absf(cat.global_position.y - spot.y) > MessManager.instance.interact_height:
		return -1.0
	var distance := Motion.flat_distance(cat.global_position, spot)
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
	# Things that end up lying down stop blocking cats and bullets. The heavy ones (vending machine,
	# hydrant, dumpster) stay standing where they are, so they stay solid.
	if kind not in [Kind.VENDING, Kind.HYDRANT, Kind.DUMPSTER]:
		_body.collision_layer = 0
	if _model == null:
		return
	var push := Vector3(-sin(yaw), 0, -cos(yaw))
	var local_push := (global_basis.inverse() * push).normalized()
	if local_push == Vector3.ZERO:
		local_push = Vector3.FORWARD
	var fallen := _home_transform
	match kind:
		Kind.VENDING:
			# Jolts back a little (top away from the street), doesn't fall.
			fallen.basis = Basis(Vector3.RIGHT, deg_to_rad(vending_tilt_degrees)) * _home_transform.basis
			fallen.origin = _home_transform.origin + Vector3.BACK * 0.06
			_flicker_left = 1.2  # the screen fizzes, then dies
		Kind.HYDRANT, Kind.DUMPSTER, Kind.POSTER:
			pass  # (the hydrant's cap, the dumpster's lid, the poster's sheet do the moving)
		Kind.CART:
			fallen = _cart_fallen(local_push)
		_:
			fallen = _tipped(local_push)
	_fallen_transform = fallen
	if kind == Kind.HYDRANT:
		# The cap flies off to one side of the push.
		_cap_side = local_push.cross(Vector3.UP).normalized()
		if _cap_side == Vector3.ZERO:
			_cap_side = Vector3.RIGHT
	match kind:
		Kind.VENDING, Kind.DUMPSTER, Kind.HYDRANT:
			_spill_debris(Vector3.FORWARD)  # out of the front, onto the pavement
		_:
			_spill_debris(local_push)
	if kind == Kind.CART:
		_debris.position = _rolled_transform.origin  # the junk falls out where it stops
		_debris.visible = instant
	if kind == Kind.POSTER:
		if _poster != null:
			_poster.visible = false
		if _torn != null:
			_torn.visible = true
	if kind == Kind.NEON_SIGN:
		_flicker_left = 0.6
	if instant:
		_flicker_left = 0.0
		_set_fall(1.0, local_push)
		_show_glow(0.0)
		for spark in _sparks:  # (the sparks already fizzled out before this player arrived)
			spark.visible = false
		return
	if kind == Kind.HYDRANT:
		_start_geyser()
	if kind in [Kind.VENDING, Kind.NEON_SIGN]:
		_sparks_left = 2.5
	if kind == Kind.CART:
		_roll_left = cart_roll_seconds
		_bowled.clear()
	_play_tween(0.0, 1.0, _knock_seconds(), local_push)
	Sound.play_at(_knock_sound(), global_position + Vector3.UP * 0.4, -2.0)


## Stand it back up and sweep the litter away (a VAC-COP tidied it, or a new district).
func show_standing(instant: bool) -> void:
	knocked = false
	claimed_by = null
	_body.collision_layer = _body.get_meta("solid_layer", HIT_ONLY_LAYER)
	_stop_geyser()
	_roll_left = 0.0
	_flicker_left = 0.0
	_sparks_left = 0.0
	_sparks.clear()
	if _debris != null:
		_debris.queue_free()
		_debris = null
	if _poster != null:
		_poster.visible = true
	if _torn != null:
		_torn.visible = false
	_show_glow(1.0 if powered else 0.0)
	if _model == null:
		return
	if instant or kind == Kind.POSTER:
		_set_fall(0.0, Vector3.ZERO)
	else:
		_play_tween(1.0, 0.0, 0.9 if kind == Kind.CART else 0.35, Vector3.ZERO)
	if not instant:
		Sound.play_at("prop_standup", global_position + Vector3.UP * 0.3, -6.0)


func _height() -> float:
	match kind:
		Kind.BIN: return 1.15
		Kind.CONE: return 0.72
		Kind.BOX: return 0.66
		Kind.NEON_SIGN: return 1.05
		_: return 1.4


func _knock_sound() -> String:
	match kind:
		Kind.BIN: return "bin_clatter"            # sounds/sfx/bin_clatter.wav
		Kind.CONE: return "cone_bounce"           # sounds/sfx/cone_bounce.wav
		Kind.BOX: return "box_thump"              # sounds/sfx/box_thump.wav
		Kind.VENDING: return "vending_smash"      # sounds/sfx/vending_smash.wav  (tools/sound_specs/street_props.json)
		Kind.HYDRANT: return "hydrant_burst"      # sounds/sfx/hydrant_burst.wav
		Kind.CART: return "cart_roll"             # sounds/sfx/cart_roll.wav
		Kind.NEON_SIGN: return "sign_spark"       # sounds/sfx/sign_spark.wav
		Kind.DUMPSTER: return "dumpster_rummage"  # sounds/sfx/dumpster_rummage.wav
		_: return "poster_scratch"                # sounds/sfx/poster_scratch.wav


## How long the knock-over animation takes (seconds).
func _knock_seconds() -> float:
	match kind:
		Kind.CART: return cart_roll_seconds + 0.25  # roll, then tip
		Kind.DUMPSTER: return 0.55
		Kind.HYDRANT: return 0.7
		_: return 0.45


## BIN / CONE / BOX / NEON_SIGN: tipped over round its foot, lying where it fell.
func _tipped(local_push: Vector3) -> Transform3D:
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
		Kind.NEON_SIGN:
			tip_degrees = neon_tip_degrees
			lift = 0.3
	var fallen := _home_transform
	fallen.basis = Basis(axis, -deg_to_rad(tip_degrees)) * _home_transform.basis
	# Rotating round the bottom middle sinks half of it into the street: lift it back out and
	# move it along the push, so it lies where it fell (its foot stays roughly put).
	fallen.origin = _home_transform.origin + Vector3.UP * lift + local_push * (0.5 * _height() + slide)
	return fallen


## CART: where it rolls to (stopping short of a wall) and how it lies there, tipped on its side.
## Sets _rolled_transform (the end of the roll, still upright) too.
func _cart_fallen(local_push: Vector3) -> Transform3D:
	var world_push := (global_basis * local_push).normalized()
	var distance := _cart_room(world_push)
	_rolled_transform = Transform3D(Basis.looking_at(local_push, Vector3.UP), _home_transform.origin + local_push * distance)
	# On its side: rolled over round the way it was going, lifted by half its width, and moved
	# sideways by half its height so it lies where it stopped.
	var side := Vector3.UP.cross(local_push).normalized()
	var fallen := _rolled_transform
	fallen.basis = Basis(local_push, deg_to_rad(cart_tip_degrees)) * _rolled_transform.basis
	fallen.origin = _rolled_transform.origin + Vector3.UP * 0.36 - side * 0.45
	return fallen


## CART: how far it can roll along "dir" before it'd hit a wall (buildings, crates, the map edge:
## STATIC bodies on layer 1 only, so cats and cars never change where it stops = same everywhere).
func _cart_room(dir: Vector3) -> float:
	if not is_inside_tree():
		return cart_roll_distance
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * (cart_roll_distance + 0.6), 1)
	var skip: Array[RID] = []
	for attempt in 8:  # step past anything that isn't a static wall
		query.exclude = skip
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return cart_roll_distance
		if hit.collider is StaticBody3D:
			return clampf(from.distance_to(hit.position) - 0.6, 0.0, cart_roll_distance)
		skip.append(hit.rid)
	return cart_roll_distance


func _play_tween(from: float, to: float, seconds: float, push: Vector3) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if kind == Kind.POSTER:
		return  # (a poster doesn't fall: it's just shredded)
	_tween = create_tween()
	var trans := Tween.TRANS_BOUNCE if to > from else Tween.TRANS_QUAD
	if kind == Kind.CART or kind == Kind.HYDRANT or kind == Kind.DUMPSTER:
		trans = Tween.TRANS_LINEAR  # (these shape their own motion in _set_fall)
	_tween.tween_method(_set_fall.bind(push), from, to, seconds).set_trans(trans).set_ease(Tween.EASE_OUT)


## 0 = standing, 1 = lying where it fell / busted wide open.
func _set_fall(amount: float, push: Vector3) -> void:
	if not is_instance_valid(_model):
		return
	match kind:
		Kind.CART:
			# Roll first (fast, slowing down), then tip over in the last bit.
			var roll_end := cart_roll_seconds / (cart_roll_seconds + 0.25)
			var roll := clampf(amount / roll_end, 0.0, 1.0)
			var tip := clampf((amount - roll_end) / (1.0 - roll_end), 0.0, 1.0)
			roll = 1.0 - (1.0 - roll) * (1.0 - roll)
			var rolling := _home_transform.interpolate_with(_rolled_transform, roll)
			_model.transform = rolling.interpolate_with(_fallen_transform, tip * tip)
			if _debris != null and amount >= 0.98:
				_debris.visible = true
		Kind.DUMPSTER:
			# The whole thing shudders while the lid swings open.
			var shake := sin(amount * PI * 7.0) * (1.0 - amount) * deg_to_rad(2.5)
			_model.transform = _home_transform.rotated_local(Vector3.FORWARD, shake)
		Kind.HYDRANT:
			_model.transform = _home_transform
		_:
			_model.transform = _home_transform.interpolate_with(_fallen_transform, amount)
	_pop_lid(push, amount)
	if _flap != null:
		_flap.transform = _flap_home.rotated_local(Vector3.RIGHT, deg_to_rad(vending_flap_degrees) * clampf(amount, 0.0, 1.0))
	if _cap != null:
		_move_cap(amount)


## Bins: the lid flips open on its hinge (amount 0 = shut, 1 = hanging wide open). The Lid part's
## pivot is the hinge (models/blockbench/trash_bin.bbmodel: the Lid group's origin).
## Dumpsters: the lid swings up and over on its BACK hinge (dumpster.bbmodel).
func _pop_lid(push: Vector3, amount: float) -> void:
	if _lid == null:
		return
	if kind == Kind.DUMPSTER:
		var open := clampf(amount, 0.0, 1.0)
		_lid.transform = _lid_home.rotated_local(Vector3.RIGHT, deg_to_rad(dumpster_lid_degrees) * (1.0 - (1.0 - open) * (1.0 - open)))
		return
	if amount <= 0.0 or push == Vector3.ZERO:
		_lid.transform = _lid_home
		return
	_lid.transform = _lid_home.rotated_local(Vector3.BACK, deg_to_rad(lid_open_degrees) * amount)


## HYDRANT: the cap flies up and off (amount 0 = on, 1 = lying tilted on the pavement beside it).
func _move_cap(amount: float) -> void:
	var t := clampf(amount, 0.0, 1.0)
	if t <= 0.0:
		_cap.transform = _cap_home
		return
	var lying := _cap_home
	lying.basis = Basis(_cap_side.cross(Vector3.UP).normalized(), deg_to_rad(80.0)) * _cap_home.basis
	lying.origin = _cap_home.origin + _cap_side * 0.55 + Vector3.DOWN * (_cap_home.origin.y - 0.15)
	var moved := _cap_home.interpolate_with(lying, t)
	moved.origin += Vector3.UP * sin(t * PI) * 1.1  # (an arc: up, over, down)
	_cap.transform = moved


## A few bits of litter on the pavement where it fell (every computer makes the same bits: the
## random numbers come from the prop's own number, not the city's RNG, so the city is unchanged).
## Vending machines and neon signs also spill glowing SPARKS (they fizz out after a moment).
func _spill_debris(push: Vector3) -> void:
	if _debris != null:
		_debris.queue_free()
	_sparks.clear()
	_debris = Node3D.new()
	_debris.name = "Debris"
	add_child(_debris)
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7919 + 13
	var count := 6
	var spread := 1.6
	var size_min := Vector3(0.12, 0.08, 0.1)
	var size_max := Vector3(0.28, 0.08, 0.22)
	var sparks := 0
	var colors: Array[Color] = [Color(0.35, 0.4, 0.3), Color(0.55, 0.5, 0.35), Color(0.75, 0.7, 0.6), Color(0.3, 0.25, 0.2)]
	match kind:
		Kind.CONE:
			count = 3
			colors = [Color(0.95, 0.45, 0.12), Color(0.9, 0.9, 0.9)]
		Kind.BOX:
			colors = [Color(0.9, 0.88, 0.8), Color(0.6, 0.45, 0.28), Color(0.85, 0.85, 0.9)]
		Kind.POSTER:
			colors = [Color(0.92, 0.88, 0.75), Color(0.25, 0.4, 0.75), Color(0.8, 0.2, 0.15)]
		Kind.VENDING:  # snacks: sardine cans, fish crackers, wrappers
			count = 7
			spread = 1.3
			sparks = 5
			colors = [Color(0.4, 0.95, 1.0), Color(1.0, 0.35, 0.75), Color(1.0, 0.85, 0.3), Color(0.8, 0.82, 0.9)]
		Kind.HYDRANT:  # puddles of water
			count = 5
			spread = 1.2
			size_min = Vector3(0.3, 0.08, 0.25)
			size_max = Vector3(0.6, 0.08, 0.45)
			colors = [Color(0.35, 0.65, 0.8), Color(0.25, 0.5, 0.65)]
		Kind.CART:  # whatever was left in the basket
			count = 5
			colors = [Color(1.0, 0.35, 0.75), Color(0.85, 0.75, 0.45), Color(0.4, 0.95, 1.0), Color(0.8, 0.82, 0.9)]
		Kind.NEON_SIGN:  # bright neon plastic shards
			count = 6
			sparks = 6
			colors = [Color(1.0, 0.3, 0.75), Color(0.35, 0.9, 1.0), Color(0.2, 0.2, 0.24)]
		Kind.DUMPSTER:  # a big pile of black trash bags and junk
			count = 9
			spread = 1.9
			size_min = Vector3(0.3, 0.2, 0.28)
			size_max = Vector3(0.55, 0.34, 0.5)
			colors = [Color(0.1, 0.1, 0.12), Color(0.16, 0.16, 0.2), Color(0.3, 0.32, 0.22), Color(0.55, 0.5, 0.35)]
	var out := push if push != Vector3.ZERO else Vector3.FORWARD
	# How far below the prop's own origin the pavement is. Most props stand ON the pavement (0),
	# but a poster hangs on the wall a bit above it, so its paper bits must drop down by its height
	# or they'd float in the air in front of the wall.
	var floor_drop := 0.0
	if kind == Kind.POSTER:
		out = Vector3.FORWARD  # paper bits fall on the pavement in front of the wall
		floor_drop = global_position.y  # (the city's pavement is at height 0)
	var start := 0.4
	if kind == Kind.VENDING or kind == Kind.DUMPSTER:
		start = radius() * 0.6  # (from the front face, not from inside the machine)
	var debris_material: Material = MessManager.instance.debris_material if MessManager.instance != null else null
	for i in count + sparks:
		var is_spark := i >= count
		var spot := out * rng.randf_range(start, start + spread) + out.cross(Vector3.UP) * rng.randf_range(-0.6, 0.6) * (1.6 if kind == Kind.DUMPSTER else 1.0)
		var size := Vector3(rng.randf_range(size_min.x, size_max.x), rng.randf_range(size_min.y, size_max.y), rng.randf_range(size_min.z, size_max.z))
		if is_spark:
			size = Vector3(0.06, 0.06, 0.06)
		# (Never a flat sheet: a sheet a few cm above the street would flicker.)
		var bit := LevelKit.add_box(_debris, spot + Vector3.UP * (size.y * 0.5 - floor_drop + (rng.randf_range(0.0, 0.4) if is_spark else 0.0)),
			size, _spark_mat() if is_spark else debris_material, false)
		bit.rotation.y = rng.randf() * TAU
		if is_spark:
			bit.set_instance_shader_parameter("instance_tint", [Color(1.0, 0.95, 0.6), Color(0.5, 0.95, 1.0), Color(1.0, 0.4, 0.85)][i % 3])
			_sparks.append(bit)
		else:
			bit.set_instance_shader_parameter("instance_tint", colors[rng.randi() % colors.size()])


# --- Glowing parts (vending screen, neon face, cart handle) ---

## Gives every mesh under the part called "part_name" its own glowing copy of its material (like
## enemy.gd's Glow Parts): the painted pixels glow. Turned up / down with instance_tint (_show_glow).
func _make_glow(part_name: String, energy: float) -> void:
	var part := _model.find_child(part_name, true, false)
	if part == null:
		return
	var meshes: Array[Node] = part.find_children("*", "MeshInstance3D", true, false)
	if part is MeshInstance3D:
		meshes.append(part)
	for node in meshes:
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.get_active_material(0) is ShaderMaterial:
			continue
		var glow := (mesh.get_active_material(0) as ShaderMaterial).duplicate() as ShaderMaterial
		glow.set_shader_parameter("albedo_color", Color(0.25, 0.25, 0.25))
		glow.set_shader_parameter("emission_color", Color.WHITE)
		glow.set_shader_parameter("emission_energy", energy)
		glow.set_shader_parameter("emission_textured", true)  # the screen's pixel fish glow
		mesh.set_surface_override_material(0, glow)
		_glow_meshes.append(mesh)


## 1 = glowing, 0 = dead dark (busted, or a BLACKOUT). (The cart's handle never goes dark.)
func _show_glow(amount: float) -> void:
	if kind == Kind.CART:
		amount = 1.0
	var tint := Color(0.12, 0.12, 0.14).lerp(Color.WHITE, clampf(amount, 0.0, 1.0))
	for mesh in _glow_meshes:
		if is_instance_valid(mesh):
			mesh.set_instance_shader_parameter("instance_tint", tint)
	if _light != null:
		_light.visible = amount > 0.5


## The shared glowing-spark material (kept on the Mess node: MessManager.spark_material).
static func _spark_mat() -> Material:
	return MessManager.instance.spark_material if MessManager.instance != null else null


# --- HYDRANT: the water geyser ---

## The shared glowing-water material (kept on the Mess node: MessManager.water_material).
static func _water_mat() -> Material:
	return MessManager.instance.water_material if MessManager.instance != null else null


## Build the geyser (made in code from LevelKit boxes): a pulsing column of glowing water straight
## up from the hydrant, and droplets that fountain out and fall back down (_process moves them).
func _start_geyser() -> void:
	_stop_geyser()
	_geyser = Node3D.new()
	_geyser.name = "Geyser"
	_geyser.position = Vector3(0, 0.75, 0)
	add_child(_geyser)
	_geyser_column.clear()
	_geyser_drops.clear()
	var pieces := 6
	for i in pieces:
		var piece_height := geyser_height / pieces
		var width := lerpf(0.32, 0.55, float(i) / (pieces - 1))  # wider towards the top
		var piece := LevelKit.add_box(_geyser, Vector3(0, piece_height * (i + 0.5), 0), Vector3(width, piece_height, width), _water_mat(), false)
		piece.set_instance_shader_parameter("instance_tint", Color(1, 1, 1) if i % 2 == 0 else Color(0.8, 0.95, 1.0))
		_geyser_column.append(piece)
	for i in 14:
		var drop := LevelKit.add_box(_geyser, Vector3.ZERO, Vector3(0.12, 0.16, 0.12), _water_mat(), false)
		_geyser_drops.append(drop)
	var light := LevelKit.add_light(_geyser, Vector3(0, 2.0, 0), Color(0.45, 0.85, 1.0), 1.5, 5.0, 35.0)
	light.name = "GeyserLight"
	_geyser_left = hydrant_geyser_seconds
	_geyser_clock = 0.0
	_zapped.clear()


func _stop_geyser() -> void:
	_geyser_left = 0.0
	if _geyser != null:
		_geyser.queue_free()
		_geyser = null
	_geyser_column.clear()
	_geyser_drops.clear()


## Every frame: the geyser's water moves, sparks / screens fizz.
func _process(delta: float) -> void:
	if _flicker_left > 0.0:
		_flicker_left -= delta
		var on := fmod(Time.get_ticks_msec() / 1000.0, 0.13) < 0.05 and _flicker_left > 0.0
		_show_glow(0.8 if on else 0.0)
	if _sparks_left > 0.0:
		_sparks_left -= delta
		for i in _sparks.size():
			if is_instance_valid(_sparks[i]):
				_sparks[i].visible = _sparks_left > 0.0 and fmod(Time.get_ticks_msec() / 1000.0 + i * 0.07, 0.2) < 0.12
	if _geyser == null:
		return
	_geyser_clock += delta
	# Fading out in the last second, a strong pulse the rest of the time.
	var strength := clampf(_geyser_left, 0.0, 1.0)
	for i in _geyser_column.size():
		var pulse := 1.0 + 0.18 * sin(_geyser_clock * 14.0 + i * 1.3)
		_geyser_column[i].scale = Vector3(pulse, strength, pulse)
		_geyser_column[i].position.y = geyser_height / _geyser_column.size() * (i + 0.5) * strength
	# Droplets: shot up and out from the top, falling back around the hydrant (a parabola each).
	for i in _geyser_drops.size():
		var life := 1.3
		var t := fmod(_geyser_clock + i * life / _geyser_drops.size(), life)
		var angle := i * 2.4
		var out := Vector3(cos(angle), 0, sin(angle)) * (1.4 + 0.25 * (i % 3))
		var up := 3.0 + 1.5 * (i % 2)
		var pos := Vector3(0, geyser_height * 0.85 * strength, 0) + out * t + Vector3.UP * (up * t - 4.9 * t * t)
		_geyser_drops[i].position = pos
		_geyser_drops[i].visible = pos.y > -0.7 and strength > 0.05


## Every physics frame: the geyser launches things / shorts out bots, a rolling cart bowls.
func _physics_process(delta: float) -> void:
	if _geyser_left > 0.0:
		_geyser_left -= delta
		_geyser_effects()
		if _geyser_left <= 0.0:
			_stop_geyser()
	if _roll_left > 0.0:
		_roll_left -= delta
		if multiplayer.is_server():
			_bowl_along()


## HYDRANT while spraying. Host: VAC-COPs / drones nearby short out and get shoved away. This
## computer: OUR cats standing in it fly up (their owner moves them), OUR driven car bounces.
func _geyser_effects() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var here := global_position
	if multiplayer.is_server():
		for node in get_tree().get_nodes_in_group(Enemy.GROUP):
			var enemy := node as Enemy
			if enemy == null or enemy.health <= 0 or enemy.is_queued_for_deletion():
				continue
			var flat := Motion.flat(enemy.global_position - here)
			if flat.length() > geyser_stun_radius or absf(enemy.global_position.y - here.y) > 4.0:
				continue
			var key := enemy.get_instance_id()
			if now - float(_zapped.get(key, -100.0)) < geyser_stun_cooldown:
				continue
			_zapped[key] = now
			var away := flat.normalized() if flat.length() > 0.05 else Vector3.RIGHT
			enemy._on_stunned(geyser_stun_seconds)
			enemy._on_pushed(away * geyser_push + Vector3.UP * 3.0)
	if Game.instance == null:
		return
	for cat in Game.instance.local_cats():
		if not cat.is_multiplayer_authority() or not cat.visible or cat.is_downed():
			continue
		if Motion.flat_distance(cat.global_position, here) > geyser_launch_radius or cat.global_position.y > here.y + 1.5:  # (a jump pad at its foot)
			continue
		var key := cat.get_instance_id()
		if now - float(_launched.get(key, -100.0)) < geyser_launch_cooldown:
			continue
		_launched[key] = now
		cat.velocity.y = geyser_launch_speed  # WHOOSH (cat_player.gd keeps it: gravity brings it back)
		Sound.play_at("jump", cat.global_position, -4.0)
	for car in Game.instance.cars():
		if car == null or car.driver_id == 0 or not car.is_multiplayer_authority() or car.freeze:
			continue
		if Motion.flat_distance(car.global_position, here) > geyser_car_radius:
			continue
		var key := car.get_instance_id()
		if now - float(_launched.get(key, -100.0)) < geyser_launch_cooldown:
			continue
		_launched[key] = now
		car.linear_velocity.y = maxf(car.linear_velocity.y, geyser_car_bounce)


# --- CART: bowling things over as it rolls (host) ---

## Host, every physics frame of the roll: anything standing near the cart right now goes flying.
## Props are knocked over (credited to whoever shoved the cart); bots are bowled over: stunned,
## shoved along and hurt.
func _bowl_along() -> void:
	if _model == null or MessManager.instance == null:
		return
	var at := global_transform * _model.transform.origin
	var dir := Vector3(-sin(fall_yaw), 0, -cos(fall_yaw))
	for other in MessManager.instance.props():
		if other == self or other.knocked or not other.cart_can_bowl() or _bowled.has(other.get_instance_id()):
			continue
		if Motion.flat_distance(other.global_position, at) < cart_bowl_prop_reach and absf(other.global_position.y - at.y) < 1.5:
			_bowled[other.get_instance_id()] = true
			MessManager.instance.host_knock(knocked_by, other.id, fall_yaw)
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.health <= 0 or enemy.is_queued_for_deletion() or _bowled.has(enemy.get_instance_id()):
			continue
		if Motion.flat_distance(enemy.global_position, at) < cart_bowl_bot_reach and absf(enemy.global_position.y - at.y) < 2.0:
			_bowled[enemy.get_instance_id()] = true
			if knocked_by != 0:
				enemy.killed_by = knocked_by  # (take_hit only credits RPC senders; this is the host itself)
			enemy.take_hit(knocked_by, cart_bowl_damage, cart_bowl_stun, dir * cart_bowl_push + Vector3.UP * 3.0, 1.0)
			print("[Mess] cart #%d bowled over %s" % [id, enemy.name])
