class_name Roomba
extends Enemy
## VAC-COP — a police Roomba that patrols the city and hunts cats on foot.
## Built on the enemy framework (scripts/enemy.gd): health, getting shot, getting run over,
## exploding, health bar and network gliding all come from there. This script is only the
## VAC-COP's own behaviour.
## Attach to the root of scenes/roomba.tscn. Expected node tree:
##   Roomba (CharacterBody3D)       <- this script
##   ├── CollisionShape3D
##   ├── Model (Node3D)             <- turns to face where it drives
##   │   ├── Body, Cap, Bumper      <- MeshInstance3D (Body flashes when shot)
##   │   ├── Eye                    <- glows red while chasing
##   │   ├── SirenRed, SirenBlue    <- flash while chasing
##   │   └── Brush, Brush2          <- the corner whisker brushes, spin (Brush2 optional, the other way)
##   ├── SirenLight (OmniLight3D)   <- red/blue light on the street while chasing
##   └── MultiplayerSynchronizer    <- shares sync_position, sync_yaw, state, health
##
## What it does:
##   PATROL  — drives slowly between random sidewalk spots.
##   CHASE   — spots a cat on foot within sight_range and drives at it (faster than a walking
##             cat, slower than zoomies — so SHIFT saves you).
##   BONK    — touching a cat knocks it flying, VACUUMS UP one piece of loot from its bag and
##             takes bonk_damage HP. A cat at 0 HP is knocked out and drops everything
##             (cat_health.gd). Then the Roomba backs off for a moment (STUNNED).
##   TIDY    — MESS-MAKING (scripts/mess_manager.gd): a patrolling bot that spots a knocked-over
##             bin / cone / box or a scratched poster within Mess Notice Range drives over
##             (TIDY_GO) and tidies it up for Tidy Seconds (TIDYING: "TIDYING..." over it, vacuum
##             noise, brush whirring). While it's busy it's half-blind (Distracted Sight), so a
##             mess is a distraction. Bosses, SEWER BREACH bots, drones and Lint-Trappers don't tidy.
##   INVESTIGATE — a cat MEOWED within earshot (cat_player.gd): it drives to where it heard it
##             ("?" over it) and looks around, then goes back to patrolling.
##   Shoot it (each bolt takes the gun's Damage off its Max Health) or ram it with the car
##   (faster than Car Smash Speed) and it explodes, spitting out everything it vacuumed.
##   Shooting it also makes it chase the shooter.
## Cats in the car and cats down in the hub are ignored.
## The HEAT (scripts/heat_meter.gd) makes it chase faster and spot cats from further away, and a
## cat carrying NOISY loot (the golden koi) is spotted from further too.
## scenes/roomba_boss.tscn (the MEGA VAC-COP) is this same scene with bigger numbers + "Is Boss".
## Roombas sit on collision LAYER 2 (Inspector > CollisionObject3D > Collision > Layer) and
## only bump into layer 1 (the city). So cats and the car pass over them instead of getting
## stuck on them, and guns still hit them (bolts check every layer).
## EXCEPT the MEGA VAC-COP: roomba_boss.tscn is ALSO on layer 3, and the getaway car's Mask
## includes layer 3 (getaway_car.tscn: Collision > Mask = layers 1 + 3). So driving into the boss
## is a crash, like hitting a wall: the car stops dead and the boss isn't hurt.
##
## MULTIPLAYER: the HOST runs every Roomba's brain (this script's _physics_process). Everyone
## else's copy just glides to the synced position (enemy.gd). Roombas are created by the host
## (roomba_patrol.gd) and copied to everyone by a MultiplayerSpawner.
##
## PERFORMANCE (there can be 70+ of them): a Roomba far from every cat thinks only every few
## frames (far_think_every), a chasing one re-plans its route a few times a second, its model
## isn't drawn beyond draw_distance (the fog hides it anyway), its siren light fades out with
## distance, and its hum only plays when it's near a player on this computer.
##
## THE SEWER BREACH (scripts/mainframe.gd): a bot of the horde has breach_hub set. It's born in that
## sewer's tunnel, hunts every cat in that sewer wherever it is, and finds its way with the sewer's
## next_stop instead of the city's streets. Fallen in the channel? It hops back out.
##
## OTHER HUNTERS: the SQUIRT-DRONE (squirt_drone.gd) and LINT-TRAPPER (lint_trapper.gd) extend this
## script, so they patrol, chase, get stunned, save CPU and get spawned exactly like a VAC-COP. They
## only replace these four small functions: _fall (how it stays up), _chase_point (where it drives),
## _attack (what it does while chasing) and _show_light (its light).

## (New states go at the END: "state" is synced as a number.)
enum State { PATROL, CHASE, STUNNED, TIDY_GO, TIDYING, INVESTIGATE }

@export_group("Driving")
@export var patrol_speed: float = 2.2
## Cats walk at 4.5 and zoom at 9 (cat_player.gd), so 5.5 catches walkers but not zoomers.
@export var chase_speed: float = 5.5
## How quickly it turns (higher = twitchier).
@export var turn_speed: float = 5.0

@export_group("Hunting")
## Starts chasing a cat on foot closer than this (metres).
@export var sight_range: float = 14.0
## Gives up the chase when the cat gets further than this.
@export var lose_range: float = 22.0
## How close counts as touching a cat.
@export var bump_range: float = 1.0
## How hard a bonk knocks the cat (metres per second), and the little hop.
@export var bump_push: float = 10.0
@export var bump_hop: float = 4.5
## Seconds it backs off after a bonk (so it doesn't bonk the same cat 60 times a second).
@export var stun_seconds: float = 2.5
## Does a bonk vacuum one piece of loot out of the cat's bag?
@export var steals_loot: bool = true
## HP a bonk takes off the cat (cats have 100, see the Health node; 34 = three bonks). At 0 the
## cat is knocked out and drops EVERYTHING it carries (cat_health.gd). 0 = bonks never hurt.
@export var bonk_damage: int = 34
## Cats in a CAR get chased too: the bot rams the car instead. Car damage per ram = Bonk Damage x
## this (cars have 300 HP: scripts/car_health.gd).
@export var car_damage_multiplier: float = 0.6
## A car is bigger than a cat: it counts as touching the car this much further out (metres).
@export var car_bump_extra_range: float = 2.0
## How hard a SEWER BREACH bot hops out of the sewage channel (metres per second; it's 1 m deep).
@export var channel_hop: float = 6.0
## Does the HEAT level (scripts/heat_meter.gd) make it faster and sharper-eyed?
@export var heat_scaling: bool = true

@export_group("Mess + Meows")
## Does it stop to tidy up messes (MESS-MAKING)? Bosses, drones and Lint-Trappers never do.
@export var tidies_messes: bool = true
## It notices a mess this close (metres) while patrolling.
@export var mess_notice_range: float = 14.0
## Seconds it spends tidying one mess.
@export var tidy_seconds: float = 3.5
## While on its way to a mess or tidying it, it only spots cats this much closer (0.35 = a third
## of its usual Sight Range). The distraction!
@export var distracted_sight: float = 0.35
## Does it come to look when a cat meows nearby? (How far a meow carries: the cat's Meow Heard From.)
@export var hears_meows: bool = true
## Gives up looking for the meowing cat after this many seconds.
@export var investigate_seconds: float = 7.0

@export_group("Performance")
## Further than this (metres) from every cat, a patrolling Roomba only thinks every
## far_think_every frames (it still drives just as far: each think covers the skipped time).
@export var far_distance: float = 60.0
@export var far_think_every: int = 4
## While chasing, the route to the cat is re-planned this many times a second (not every frame).
@export var replans_per_second: float = 10.0
## The model isn't drawn further away than this (metres). The fog hides it by then anyway.
@export var draw_distance: float = 75.0
## The vacuum hum only plays within this distance (metres) of a player on this computer.
@export var hum_distance: float = 35.0

@export_group("Look")
## The two colours its siren flashes (the lights on the model and the glow on the street).
@export var siren_color_1: Color = Color(1, 0.1, 0.15)
@export var siren_color_2: Color = Color(0.15, 0.3, 1)
## How the Brush part spins: around which axis, and how fast (radians per second).
@export var brush_axis: Vector3 = Vector3.UP
@export var brush_spin: float = 14.0
## Pitch of its hum (1 = normal, 2 = an octave up: the drone's whine).
@export var hum_pitch: float = 1.0

## Host: the sewer this bot was sent into by a SEWER BREACH (null = a normal city patrol).
var breach_hub: UndergroundHub = null

## Synced to everyone: what it's doing (the lights and sounds follow it).
var state: State = State.PATROL

var _target: Vector3
var _chase_id: int = 0
var _stun_left: float = 0.0
var _stuck_check_at: Vector3
var _stuck_time: float = 0.0
var _clock: float = 0.0
## Sounds (every computer): the vacuum hum, and what we were doing last frame (to hear the siren
## start the moment a chase begins).
var _hum: AudioStreamPlayer3D
var _last_state: State = State.PATROL
var _last_status: State = State.PATROL  # (for the status tag: what we showed last frame)
var _skipped_time: float = 0.0  # host: time saved up while thinking less often (far away)
var _frame: int = 0  # host: counts physics frames, for thinking less often
var _route_point: Vector3  # host: where the chase is headed (re-planned replans_per_second)
var _replan_left: float = 0.0
var _hum_check_left: float = 0.0  # every computer: time until we check if anyone can hear us
var _rng := RandomNumberGenerator.new()  # patrol choices only — NOT the city's RNG
var _mess: MessProp = null  # host: the mess we're tidying (TIDY_GO / TIDYING)
var _busy_left: float = 0.0  # host: seconds of tidying / investigating left
var _mess_check_left: float = 0.0  # host: time until we look around for messes again
var _noise_spot: Vector3  # host: where we heard the meow
var _tidy_sound_left: float = 0.0  # every computer: time until the next vacuum noise
var _status_tag: Label3D  # every computer: "TIDYING..." / "?" over us (made when first needed)

@onready var eye: MeshInstance3D = $Model/Eye
@onready var siren_red: MeshInstance3D = $Model/SirenRed
@onready var siren_blue: MeshInstance3D = $Model/SirenBlue
@onready var brush: Node3D = get_node_or_null("Model/Brush")  # (optional: the drone has rotors)
@onready var brush_2: Node3D = get_node_or_null("Model/Brush2")  # (optional: a second corner brush)
@onready var siren_light: Light3D = $SirenLight


func _ready() -> void:
	super()  # health, health bar, network (enemy.gd)
	_stuck_check_at = global_position
	_rng.randomize()
	_frame = _rng.randi_range(0, 99)  # so far-away Roombas don't all think on the same frame
	_hum = Sound.attach_loop("roomba_hum", self, -12.0)  # sounds/sfx/roomba_hum.wav
	# Don't draw the model beyond draw_distance (each part is a separate draw for the GPU).
	for part in model.find_children("*", "MeshInstance3D"):
		(part as MeshInstance3D).visibility_range_end = draw_distance
	# The siren light fades out with distance (lights are the expensive part of a swarm).
	siren_light.distance_fade_enabled = true
	siren_light.distance_fade_begin = 25.0
	siren_light.distance_fade_length = 10.0
	if is_multiplayer_authority():
		_pick_patrol_target()


# --- The host's brain ---

func _physics_process(delta: float) -> void:
	# Far from every cat and just patrolling: only think every far_think_every frames, with
	# the saved-up time, so it drives the same distance for a fraction of the cost.
	_frame += 1
	_skipped_time += delta
	if state == State.PATROL and far_think_every > 1 and _frame % far_think_every != 0 and _far_from_cats():
		return
	delta = _skipped_time
	_skipped_time = 0.0
	_clock += delta
	_fall(delta)
	_update_flying(delta, is_on_floor())  # launched by a boosting car? (enemy.gd launch)

	if run_over_by_car(delta):
		explode()
		return

	var move := Vector3.ZERO
	var speed := 0.0
	match state:
		State.STUNNED:
			_stun_left -= delta
			if _stun_left <= 0.0:
				state = State.PATROL
				_pick_patrol_target()
		State.PATROL:
			var cat := _find_cat_to_chase()
			if cat != null:
				_chase_id = cat.player_id
				state = State.CHASE
			elif _look_for_mess(delta):
				pass  # (off to tidy it: TIDY_GO from the next frame)
			else:
				move = Motion.flat(_target - global_position)
				speed = patrol_speed
				if move.length() < 1.5 or is_on_wall() or _is_stuck(delta):
					_pick_patrol_target()
		State.TIDY_GO, State.TIDYING:
			var cat := _find_cat_to_chase(distracted_sight)
			if cat != null:
				_drop_mess()
				_chase_id = cat.player_id
				state = State.CHASE
			elif _mess == null or not is_instance_valid(_mess) or not _mess.knocked:
				_back_to_patrol()  # (someone else tidied it, or a new district)
			elif state == State.TIDY_GO:
				var to_mess := Motion.flat(_mess.tidy_spot() - global_position)
				if to_mess.length() < 1.0 + _mess.radius() or (is_on_wall() and to_mess.length() < 2.5):
					state = State.TIDYING
					_busy_left = tidy_seconds
				elif _is_stuck(delta):
					_drop_mess()
					_back_to_patrol()
				else:
					move = to_mess
					speed = patrol_speed * 1.3
			else:
				_busy_left -= delta
				# Turn to face it while tidying (it looks like it's sucking the mess up).
				var face := Motion.flat((_mess.tidy_spot() if _mess.kind == MessProp.Kind.CART else _mess.global_position) - global_position)  # (a cart: where it rolled to)
				if face.length() > 0.1:
					model.rotation.y = lerp_angle(model.rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-turn_speed * delta))
				if _busy_left <= 0.0:
					MessManager.instance.tidy(_mess.id)
					_mess = null
					_back_to_patrol()
		State.INVESTIGATE:
			var cat := _find_cat_to_chase()
			_busy_left -= delta
			if cat != null:
				_chase_id = cat.player_id
				state = State.CHASE
			elif _busy_left <= 0.0:
				_back_to_patrol()
			else:
				var to_noise := Motion.flat(_noise_spot - global_position)
				if to_noise.length() > 1.5 and not _is_stuck(delta):
					move = to_noise
					speed = patrol_speed * 1.6
				else:
					model.rotation.y += delta * 2.5  # there: spin round looking for the cat
		State.CHASE:
			var cat := Game.instance.cat_for(_chase_id)
			if not _can_chase(cat, lose_range):
				state = State.PATROL
				_pick_patrol_target()
			else:
				# Drive at the cat if nothing is in the way, otherwise around the block (streets).
				# (Re-planned a few times a second: it casts a ray, so not every frame.)
				_replan_left -= delta
				if _replan_left <= 0.0:
					_replan_left = 1.0 / replans_per_second
					_route_point = _chase_point(cat)
				move = Motion.flat(_route_point - global_position)
				# Hotter city = faster Roombas (heat_meter.gd).
				speed = chase_speed * (HeatMeter.instance.speed_multiplier() if heat_scaling else 1.0)
				_attack(cat, delta)

	# Drive: ease toward the wanted velocity and turn to face where we're going.
	var wanted := move.normalized() * speed
	var weight := 1.0 - exp(-6.0 * delta)
	if is_flying:
		# Launched by a boosting car (enemy.gd launch): no steering in mid-air, just sail along
		# and spin round and round (the spin is synced, so everyone sees it twirl).
		weight = 0.0
		model.rotation.y += delta * 14.0
	velocity.x = lerpf(velocity.x, wanted.x, weight)
	velocity.z = lerpf(velocity.z, wanted.z, weight)
	if wanted.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-wanted.x, -wanted.z), 1.0 - exp(-turn_speed * delta))
	# move_and_slide() always moves one frame's worth: after skipped frames, move further.
	var catch_up := delta / get_physics_process_delta_time()
	velocity *= catch_up
	move_and_slide()
	velocity /= catch_up

	sync_position = global_position
	sync_yaw = model.rotation.y


## Host: gravity. (The drone replaces this to hover.)
func _fall(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif breach_hub != null and is_on_wall() and global_position.y < ground_height() - 0.3:
		velocity.y = channel_hop  # down in the sewage channel, nose against its side: hop out


## Host: how high the floor under this bot's world is (0 = the city's streets).
func ground_height() -> float:
	return breach_hub.global_position.y if breach_hub != null else 0.0


## Host, every frame of a chase: the VAC-COP bonks whatever it touches.
func _attack(cat: CatPlayer, _delta: float) -> void:
	if cat.riding_car != null:
		# The cat's in a car: ram the CAR (a car is bigger than a cat, so it counts from further off).
		if Motion.flat_distance(cat.riding_car.global_position, global_position) < bump_range + car_bump_extra_range:
			_bonk_car(cat.riding_car)
		return
	if Motion.flat_distance(cat.global_position, global_position) < bump_range:
		_bonk(cat)


## True if no cat is within far_distance (then nothing up close can see us thinking slowly).
func _far_from_cats() -> bool:
	for node in Game.instance.players.get_children():
		if Motion.flat_distance((node as Node3D).global_position, global_position) < far_distance:
			return false
	return true


## The nearest cat worth chasing, or null. sight = a share of Sight Range (distracted bots see less).
func _find_cat_to_chase(sight: float = 1.0) -> CatPlayer:
	var best: CatPlayer = null
	for node in Game.instance.players.get_children():
		var cat := node as CatPlayer
		if _can_chase(cat, sight_range * sight) and (best == null or Motion.flat_distance(cat.global_position, global_position) < Motion.flat_distance(best.global_position, global_position)):
			best = cat
	return best


## Where to drive to catch "cat". Straight at it when nothing is in the way. Otherwise along
## the streets: the city is a grid (city_generator.gd), so drive down this street to the
## crossing in the cat's row/column, turn, and repeat. Without this the MEGA VAC-COP (which
## spots you from across town) drove straight into the first building and stayed there.
func _chase_point(cat: CatPlayer) -> Vector3:
	var goal := cat.global_position
	if breach_hub != null:
		return breach_hub.next_stop(global_position, goal)  # (no streets down here)
	if _clear_line_to(cat):
		return goal
	var city := Game.instance.city
	var pitch := city.block_size + city.street_width  # streets run along every multiple of this
	var half := city.blocks_per_side / 2
	var on_street := city.street_width * 0.4  # this close to a street's middle = on that street
	var here := global_position
	# Nearest north-south street (x) and east-west street (z), to us and to the cat.
	var my_x := clampi(roundi(here.x / pitch), -half, half)
	var my_z := clampi(roundi(here.z / pitch), -half, half)
	var cat_x := clampi(roundi(goal.x / pitch), -half, half)
	var cat_z := clampi(roundi(goal.z / pitch), -half, half)
	var on_ns := absf(here.x - my_x * pitch) < on_street
	var on_ew := absf(here.z - my_z * pitch) < on_street
	# The street the cat is closest to, and the spot on it right next to the cat.
	var cat_on_ns := absf(goal.x - cat_x * pitch) < absf(goal.z - cat_z * pitch)
	var cat_spot := Vector3(cat_x * pitch, here.y, goal.z) if cat_on_ns else Vector3(goal.x, here.y, cat_z * pitch)

	if (on_ns and cat_on_ns and my_x == cat_x) or (on_ew and not cat_on_ns and my_z == cat_z):
		# Same street as the cat: drive along it to the cat (then straight at it).
		return goal if Motion.flat_distance(cat_spot, here) < 2.0 else cat_spot
	if not on_ns and not on_ew:
		# Off the street (sidewalk, yard): get onto the nearest one first.
		if absf(here.x - my_x * pitch) < absf(here.z - my_z * pitch):
			return Vector3(my_x * pitch, here.y, here.z)
		return Vector3(here.x, here.y, my_z * pitch)
	if on_ns and on_ew:
		# At a crossing: turn toward the cat's column if we're in its row, and the other way round.
		if my_z == cat_z or (my_x != cat_x and absf(goal.x - here.x) > absf(goal.z - here.z)):
			return Vector3(cat_x * pitch, here.y, my_z * pitch)
		return Vector3(my_x * pitch, here.y, cat_z * pitch)
	if on_ns:
		return Vector3(my_x * pitch, here.y, cat_z * pitch)  # down this street to the cat's row
	return Vector3(cat_x * pitch, here.y, my_z * pitch)      # along this street to the cat's column


## True if nothing solid (buildings, crates, the car) is between us and the cat.
func _clear_line_to(cat: CatPlayer) -> bool:
	var from := global_position + Vector3(0, 0.5, 0)
	var skip: Array[RID] = [get_rid(), cat.get_rid()]
	if cat.riding_car != null:
		skip.append(cat.riding_car.get_rid())  # chasing a car: the car itself isn't "in the way"
	var query := PhysicsRayQueryParameters3D.create(from, cat.global_position + Vector3(0, 0.5, 0), 1, skip)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## A cat on foot (visible = not in the car), up in the city, not knocked out, within "reach" metres.
## Noisy loot (the jingling golden koi) and a hot city make "reach" longer.
## A bot of the SEWER BREACH instead hunts any cat in its own sewer, however far away.
func _can_chase(cat: CatPlayer, reach: float) -> bool:
	# (A cat in a car is hidden but still hunted: its body rides along inside the car, so bots
	# chase the CAR: scripts/cat/cat_ride.gd.)
	if cat == null or (not cat.visible and cat.riding_car == null) or cat.unseen_by_bots or CatHealth.instance.is_down(cat.player_id):
		return false
	if breach_hub != null:
		return UndergroundHub.hub_at(cat.global_position) == breach_hub
	if UndergroundHub.is_in_hub(cat.global_position):
		return false
	if MeowMartInterior.contains(cat.global_position):
		return false  # inside Meow-Mart: no bots in there (they wait outside the door in an alarm)
	reach *= ItemManager.instance.loot_noise(cat.player_id)
	if heat_scaling:
		reach *= HeatMeter.instance.sight_multiplier()
	if RoombaPatrol.instance.deep_clean_extra > 0:
		reach *= RoombaPatrol.instance.swarm_sight_multiplier  # the DEEP CLEAN: they hunt you down
	reach *= DistrictTwist.sight_multiplier()  # a BLACKOUT (scripts/district_twist.gd): they see less far
	return Motion.flat_distance(cat.global_position, global_position) < reach


## Knock the cat flying and vacuum one piece of loot out of its bag.
func _bonk(cat: CatPlayer) -> void:
	var player_id := cat.player_id
	var push := Motion.flat(cat.global_position - global_position).normalized() * bump_push + Vector3.UP * bump_hop
	cat.get_zapped.rpc_id(PlayerId.peer_of(player_id), push)  # the cat's owner moves it
	Sound.play_everywhere("bonk", cat.global_position)
	if steals_loot and breach_hub == null:  # (a horde bot just bites: your scrap stays yours)
		var item_id := ItemManager.instance.take_one_loot(player_id)
		if item_id != "":
			stomach.append(item_id)
	# After the vacuuming, so a knockout drops whatever is left (the stolen one stays inside us).
	CatHealth.instance.damage(player_id, bonk_damage, "A VAC-COP")
	print("[Roomba] %s bonked player %d (stomach: %s)" % [name, player_id, stomach])
	state = State.STUNNED
	_stun_left = stun_seconds
	velocity = -push.normalized() * 3.0  # bounce back a little
	velocity.y = 0.0


## Host: rammed a car with cats in it. Dents it (scripts/car_health.gd), shoves it, and bounces off
## stunned like after bonking a cat. (No loot stealing through the car door!)
func _bonk_car(car: GetawayCar) -> void:
	var away := Motion.flat(car.global_position - global_position).normalized()
	if car.health != null:
		car.health.damage(roundi(bonk_damage * car_damage_multiplier), display_name)
	car.take_hit.rpc_id(car.get_multiplayer_authority(), (away * bump_push + Vector3.UP * bump_hop * 0.3) * car.mass * 0.25, global_position)
	Sound.play_everywhere("bonk", global_position)
	state = State.STUNNED
	_stun_left = stun_seconds
	velocity = -away * 3.0
	velocity.y = 0.0


# --- Mess + meows (host) ---

## Host, while patrolling: every half second, look for a mess nearby. True = found one (TIDY_GO).
func _look_for_mess(delta: float) -> bool:
	_mess_check_left -= delta
	if _mess_check_left > 0.0:
		return false
	_mess_check_left = _rng.randf_range(0.4, 0.7)
	if not tidies_messes or is_boss or breach_hub != null or MessManager.instance == null:
		return false
	_mess = MessManager.instance.claim_nearest(global_position, mess_notice_range, self)
	if _mess == null:
		return false
	state = State.TIDY_GO
	_stuck_time = 0.0
	_stuck_check_at = global_position
	return true


## The mess this bot is busy with right now, or null (MessManager asks, to share messes out).
func tidying_prop() -> MessProp:
	return _mess if state == State.TIDY_GO or state == State.TIDYING else null


## Host: let go of our mess (another bot may take it).
func _drop_mess() -> void:
	if _mess != null and is_instance_valid(_mess) and _mess.claimed_by == self:
		_mess.claimed_by = null
	_mess = null


func _back_to_patrol() -> void:
	_drop_mess()
	state = State.PATROL
	_mess_check_left = 1.5  # (catch its breath before looking for the next mess)
	_pick_patrol_target()


## Host (RoombaPatrol.hear_noise): a cat meowed at "spot". A patrolling (or tidying-bound) bot
## comes to look. Returns true if it's coming.
func hear(spot: Vector3) -> bool:
	if not hears_meows or breach_hub != null or not (state == State.PATROL or state == State.TIDY_GO or state == State.INVESTIGATE):
		return false
	_drop_mess()
	_noise_spot = spot
	_busy_left = investigate_seconds
	state = State.INVESTIGATE
	_stuck_time = 0.0
	_stuck_check_at = global_position
	return true


func _pick_patrol_target() -> void:
	if breach_hub != null:
		_target = breach_hub.random_walkway_spot(_rng)
		return
	# A random sidewalk spot not too far away, so it wanders its own neighbourhood.
	for attempt in 8:
		var spot := ItemManager.instance.random_sidewalk_spot(_rng)
		if Motion.flat_distance(spot, global_position) < 35.0:
			_target = spot
			return
	_target = global_position + Vector3(_rng.randf_range(-10, 10), 0, _rng.randf_range(-10, 10))


## Host: true if we've barely moved for 2 seconds (wedged on a corner).
func _is_stuck(delta: float) -> bool:
	_stuck_time += delta
	if _stuck_time < 2.0:
		return false
	var stuck := global_position.distance_to(_stuck_check_at) < 0.5
	_stuck_check_at = global_position
	_stuck_time = 0.0
	return stuck


## Host (enemy.gd): shot but still alive. Angry now: chase whoever shot us (if they're on foot).
func _on_hurt(shooter: CatPlayer) -> void:
	if state == State.STUNNED:
		return  # stunned means stunned: shooting it doesn't wake it up
	if _can_chase(shooter, lose_range):
		_drop_mess()
		_chase_id = shooter.player_id
		state = State.CHASE
		_replan_left = 0.0


## Host (enemy.gd): a stun gun zapped us. Stop dead for that long (a longer stun already running
## is kept). The brain's STUNNED state counts it down.
func _on_stunned(seconds: float) -> void:
	_drop_mess()
	state = State.STUNNED
	_stun_left = maxf(_stun_left, seconds)


# --- Every computer: the flashing lights and the sounds (the gliding is in enemy.gd) ---

func _process(delta: float) -> void:
	super(delta)
	if brush != null:
		brush.rotate_object_local(brush_axis, delta * brush_spin * (3.0 if state == State.TIDYING else 1.0))
	if brush_2 != null:
		brush_2.rotate_object_local(brush_axis, -delta * brush_spin * (3.0 if state == State.TIDYING else 1.0))
	var chasing := state == State.CHASE
	# Sounds: a siren whoop when a chase starts, and the hum revs higher while chasing.
	if chasing and _last_state != State.CHASE:
		Sound.play_at("alert", global_position, -2.0)
	_last_state = state
	var tidying := state == State.TIDYING
	_show_status(delta)
	if _hum != null:
		_hum.pitch_scale = (1.4 if chasing else (1.7 if tidying else 1.0)) * hum_pitch
		# Only hum when a player on this computer is near (dozens of far-away hums cost CPU
		# and you couldn't hear them through the rain anyway). Checked 4 times a second.
		_hum_check_left -= delta
		if _hum_check_left <= 0.0 and GameScreen.instance != null:
			_hum_check_left = 0.25
			var near := false
			for camera in GameScreen.instance.view_cameras():
				near = near or camera.global_position.distance_to(global_position) < hum_distance
			_hum.stream_paused = not near
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.4) < 0.2
	var off := Color(0.08, 0.08, 0.1)
	# Stunned: the eye and sirens fizz on and off, like something shorting out.
	var fizz := state == State.STUNNED and fmod(Time.get_ticks_msec() / 1000.0, 0.14) < 0.07
	var fizz_color := Color(0.8, 0.4, 1)
	siren_red.set_instance_shader_parameter("instance_tint", fizz_color if fizz else (siren_color_1 if chasing and blink else off))
	siren_blue.set_instance_shader_parameter("instance_tint", fizz_color if fizz else (siren_color_2 if chasing and not blink else off))
	_show_light(chasing, blink)
	if eye_flashing():
		eye.set_instance_shader_parameter("instance_tint", Color(3, 2.6, 1.6))  # EYE CRIT: white-hot flash
	elif state == State.STUNNED:
		eye.set_instance_shader_parameter("instance_tint", fizz_color if fizz else off)
	elif state == State.TIDYING or state == State.TIDY_GO:
		eye.set_instance_shader_parameter("instance_tint", Color(0.5, 1, 0.4))  # busy: green
	elif state == State.INVESTIGATE:
		eye.set_instance_shader_parameter("instance_tint", Color(1, 0.7, 0.1))  # curious: amber
	else:
		eye.set_instance_shader_parameter("instance_tint", Color(1, 0.1, 0.1) if chasing else Color(0.2, 0.9, 1))


## Every computer: "TIDYING..." / "?" over the bot, the vacuum noise while tidying, and a little
## chirp when it hears a meow. The tag is a HUD name-tag marker (sharp at 240p, hud_name_tags.gd).
func _show_status(delta: float) -> void:
	var text := ""
	match state:
		State.TIDYING: text = "TIDYING..."
		State.INVESTIGATE: text = "?"
	if state == State.INVESTIGATE and _last_status != State.INVESTIGATE:
		Sound.play_at("roomba_curious", global_position, -4.0)  # sounds/sfx/roomba_curious.wav
	if state == State.TIDYING:
		_tidy_sound_left -= delta
		if _tidy_sound_left <= 0.0:
			_tidy_sound_left = 1.5
			Sound.play_at("roomba_tidy", global_position, -6.0)  # sounds/sfx/roomba_tidy.wav
	else:
		_tidy_sound_left = 0.0
	_last_status = state
	if text == "" and _status_tag == null:
		return
	if _status_tag == null:
		_status_tag = Label3D.new()
		_status_tag.name = "StatusTag"
		_status_tag.position = Vector3.UP * 0.9
		_status_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_status_tag.add_to_group(HudNameTags.GROUP)
		_status_tag.set_meta("max_distance", 28.0)
		add_child(_status_tag)
	_status_tag.text = text
	_status_tag.modulate = Color(0.5, 1, 0.6) if state == State.TIDYING else Color(1, 0.75, 0.2)
	_status_tag.visible = text != ""


## Every computer: the glow on the street. (The drone's spotlight replaces this.)
func _show_light(chasing: bool, blink: bool) -> void:
	siren_light.visible = chasing
	siren_light.light_color = siren_color_1 if blink else siren_color_2
