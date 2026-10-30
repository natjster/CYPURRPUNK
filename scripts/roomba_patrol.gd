class_name RoombaPatrol
extends Node3D
## THE VAC-COP PATROL: puts police Roombas (scenes/roomba.tscn) on the city's sidewalks and
## sends a new one some time after one is destroyed.
## Attach to the "Roombas" node in main.tscn. Its sibling "RoombaSpawner" (a
## MultiplayerSpawner pointing at Roombas) copies every Roomba to every player's game,
## including players who join later.
##
## How many are out follows the HEAT (scripts/heat_meter.gd): every heat level adds a few, and
## The MEGA VAC-COP (scenes/roomba_boss.tscn) is called in every boss_every_kills VAC-COPs the
## crew destroys (up to bosses_per_district times), one more arrives every time the heat
## reaches one of the boss_on_levels (levels 2-4: heat 25, 50, 75), and one always comes out for
## the DEEP CLEAN. None (except the DEEP CLEAN's) ever come before boss_min_heat (25).
## At max heat fish_heist.gd also seals the hatch and starts the DEEP CLEAN (Events.district_sealed):
## we set deep_clean_extra to Deep Clean Roombas, and a swarm that many strong pours in close to the cats still up top,
## hunting them from much further away (roomba.gd _can_chase).
## THE MAINFRAME (scripts/mainframe.gd) at 0% (CRITICAL) puts one MEGA VAC-COP out as soon as a
## district starts. Every MEGA VAC-COP drops SCRAP when destroyed (roomba_boss.tscn drop_on_destroy).
## A SEWER BREACH (scripts/mainframe.gd, Events.sewer_breached) pours a horde into each breached
## sewer's north tunnel. Those bots (breach_hub set) stay down there and aren't part of the patrol:
## nothing replaces them, and the city's patrol waits until the breach is over.
##
## Only the HOST creates Roombas (start_district(), called through game_systems.gd when a game starts). Where they appear
## is random each game — they're not part of the city seed, so they never change the city.

const ROOMBA_SCENE: PackedScene = preload("res://scenes/roomba.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/roomba_boss.tscn")
const LINT_TRAPPER_SCENE: PackedScene = preload("res://scenes/lint_trapper.tscn")
const SQUIRT_DRONE_SCENE: PackedScene = preload("res://scenes/squirt_drone.tscn")

## How many Roombas patrol the city at once when the city is calm (HEAT level 1).
## Hotter levels add more (HeatMeter.extra_roombas_per_level, on the Heat node).
@export var roomba_count: int = 20
## More players = more VAC-COPs: this many extra for every player beyond the second
## (8 players with 2.0 = 12 extra). Decimals are fine (0.5 = one extra per two players).
@export var extra_roombas_per_player: float = 2.0
## Seconds before a destroyed Roomba is replaced.
@export var respawn_seconds: float = 15.0
## New Roombas never appear closer than this to a cat, or to the centre crossroads where
## cats arrive from the hub.
@export var min_spawn_distance: float = 25.0
## When the heat goes UP a level, one reinforcement Roomba arrives every this many seconds
## until there are enough. (When it cools down, spare Roombas far from cats go home just as slowly.)
@export var reinforce_seconds: float = 2.0

@export_group("Patrol Mix")
## Out of every new patrol unit (0.20 = 20%), how many are LINT-TRAPPERS and SQUIRT-DRONES. The rest
## are regular VAC-COPs. The same mix goes for every spawn: district start, heat reinforcements,
## replacements and the DEEP CLEAN swarm.
@export var lint_trapper_chance: float = 0.20
@export var squirt_drone_chance: float = 0.15

@export_group("MEGA VAC-COP (boss)")
## The boss appears at least this far from every cat (it drives in from across town).
@export var boss_spawn_distance: float = 45.0
## Every this many regular VAC-COPs the crew destroys, the MEGA VAC-COP is called in...
@export var boss_every_kills: int = 3
## ...but no more than this many times per district. (The DEEP CLEAN's boss doesn't count.)
@export var bosses_per_district: int = 4
## A MEGA VAC-COP also rolls out every time the heat reaches one of these HEAT LEVELS
## (1 = as soon as the district starts, 2 = heat 25, 3 = heat 50, 4 = heat 75). These come even
## if another boss is still out, and they don't count toward Bosses Per District.
## Remove numbers from the list (Inspector) to skip those levels; empty = no level bosses.
@export var boss_on_levels: Array[int] = [2, 3, 4]
## NO MEGA VAC-COP of any kind (level, kill call) until the heat is at least this much
## (0..100). The DEEP CLEAN's boss comes at max heat, so it's never held back.
@export var boss_min_heat: float = 25.0

@export_group("DEEP CLEAN swarm")
## Extra VAC-COPs that swarm in when the hatch is sealed (the DEEP CLEAN, fish_heist.gd).
@export var deep_clean_roombas: int = 40
## During the DEEP CLEAN, swarm Roombas appear between these distances (metres) from a cat up top.
@export var swarm_min_distance: float = 15.0
@export var swarm_max_distance: float = 40.0
## During the DEEP CLEAN every Roomba spots cats this many times further away than normal.
@export var swarm_sight_multiplier: float = 6.0
## Extra swarm Roombas spawned per physics frame while the DEEP CLEAN fills up.
@export var swarm_spawns_per_frame: int = 2

@export_group("SEWER BREACH horde")
## Regular patrol units (the same Patrol Mix) and MEGA VAC-COPs sent into EACH breached sewer.
@export var breach_roombas: int = 35
@export var breach_bosses: int = 2
## How many pour in per physics frame.
@export var breach_spawns_per_frame: int = 2
## THE 1% MIRACLE: the surviving bots go off one by one over this many seconds (not all at once).
@export var miracle_blast_seconds: float = 2.5

## The one patrol (RoombaPatrol.instance).
static var instance: RoombaPatrol

## Host: how many EXTRA Roombas the DEEP CLEAN wants out right now (0 = no deep clean).
## Set when the hatch is sealed (Events.district_sealed), back to 0 in start_district().
var deep_clean_extra: int = 0

var _respawn_at: Array[float] = []  # host: when each replacement is due
var _clock: float = 0.0
var _next_number: int = 0
var _next_change_at: float = 0.0  # host: when the next reinforcement may arrive / leave
## Host: the highest heat level this district has already sent a level boss for.
var _boss_level_done: int = 0
## Host: regular Roombas destroyed since the last boss call, and bosses called this district.
var _kills_toward_boss: int = 0
var _bosses_called: int = 0
## True once this computer hosts a game (start_district). Before that - in the start menu the
## game counts as its own "host" - no Roombas may be sent out: they'd clash with the real
## host's when we join someone.
var _patrolling: bool = false
var _rng := RandomNumberGenerator.new()
## Host: the bots still to pour in: [{"hub": UndergroundHub, "boss": bool}, ...].
var _breach_queue: Array[Dictionary] = []
## Host: THE 1% MIRACLE's bots still to go off, the seconds between them, and until the next one.
var _blast_queue: Array[Roomba] = []
var _blast_gap: float = 0.0
var _blast_wait: float = 0.0


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	_rng.randomize()
	add_to_group(GameSystems.GROUP)  # late joiners / quitting players / new districts (game_systems.gd)
	Events.district_sealed.connect(_on_district_sealed)  # (scripts/events.gd)
	Events.sewer_breached.connect(_on_sewer_breached)
	Events.sewer_breach_ended.connect(_on_sewer_breach_ended)


## The hatch was sealed at max heat (every computer hears it): the host sends in the swarm.
func _on_district_sealed() -> void:
	if multiplayer.is_server() and _patrolling:
		deep_clean_extra = deep_clean_roombas


## A SEWER BREACH started (every computer hears it): the host lines the horde up.
func _on_sewer_breached(teams: Array) -> void:
	if not multiplayer.is_server():
		return
	for team in teams:
		var hub := UndergroundHub.for_team(team)
		for i in breach_roombas:
			_breach_queue.append({"hub": hub, "boss": false})
		for i in breach_bosses:
			_breach_queue.append({"hub": hub, "boss": true})


## The breach is over. THE 1% MIRACLE: every bot freezes, then they blow up one after another (one
## big bang of 37 explosions in a frame hurts the sound and the graphics). A wipeout: they just go.
## (Only bosses SHOT in the breach drop scrap: self_destruct doesn't pay out.)
func _on_sewer_breach_ended(survived: bool) -> void:
	if not multiplayer.is_server():
		return
	_breach_queue.clear()
	for child in get_children():
		var roomba := child as Roomba
		if roomba == null or roomba.breach_hub == null:
			continue
		if survived:
			roomba._on_stunned(Enemy.MAX_STUN_SECONDS)
			_blast_queue.append(roomba)
		else:
			roomba.queue_free()
	_blast_queue.shuffle()
	_blast_gap = miracle_blast_seconds / maxi(_blast_queue.size(), 1)
	_blast_wait = 0.0


## Host: set off the next bots of THE 1% MIRACLE. (A cat may still finish one off first.)
func _set_off_bots(delta: float) -> void:
	_blast_wait -= delta
	while _blast_wait <= 0.0 and not _blast_queue.is_empty():
		_blast_wait += _blast_gap
		var roomba: Roomba = _blast_queue.pop_back()
		if is_instance_valid(roomba):
			roomba.self_destruct()


## Host: one bot of the horde, in its sewer's breach tunnel.
func _spawn_breach_bot(hub: UndergroundHub, boss: bool) -> void:
	var roomba := (BOSS_SCENE if boss else _pick_scene()).instantiate() as Roomba
	roomba.name = "%s%d" % ["RoombaBoss" if boss else "Roomba", _next_number]
	_next_number += 1
	roomba.breach_hub = hub
	roomba.position = hub.breach_spawn_spot(_rng)
	roomba.destroyed.connect(roomba_destroyed)
	add_child(roomba, true)


## Host: clear any old Roombas and put a fresh patrol out (a new game or a new district;
## game_systems.gd calls it).
func start_district() -> void:
	for old in get_children():
		old.queue_free()
	_patrolling = true
	_breach_queue.clear()
	_blast_queue.clear()
	_respawn_at.clear()
	deep_clean_extra = 0
	_kills_toward_boss = 0
	_bosses_called = 0
	for i in roomba_count:
		_spawn_one()
	var mainframe := Mainframe.instance
	# A low MAINFRAME (scripts/mainframe.gd) starts the district hotter: the heat levels it
	# starts on don't send level bosses...
	_boss_level_done = HeatMeter.level_of(mainframe.starting_heat()) if mainframe != null else 0
	if _boss_level_done <= 1:
		_boss_level_done = 0
	# ...but at 0% (CRITICAL) one MEGA VAC-COP is already up there: hunt it for SCRAP.
	if mainframe != null and mainframe.boss_at_start():
		_spawn_boss("MAINFRAME CRITICAL")


## Host: scrap was fed into THE MAINFRAME before anyone went up, so the district's starting heat
## changed (heat_meter.gd restart_district_heat): level bosses count from the new heat level.
func restart_heat_levels() -> void:
	var lvl := HeatMeter.instance.level()
	_boss_level_done = lvl if lvl > 1 else 0
	# A hack (or scrap) that lands the lowest gang on 0% still puts the CRITICAL boss up top.
	var mainframe := Mainframe.instance
	if _patrolling and mainframe != null and mainframe.boss_at_start() and _bosses_out() == 0:
		_spawn_boss("MAINFRAME CRITICAL")


## Host: a Roomba blew up (its "destroyed" signal, enemy.gd). Show the explosion everywhere and
## queue its replacement (the boss has no replacement). Every boss_every_kills regulars
## destroyed calls the boss in.
func roomba_destroyed(roomba: Enemy) -> void:
	_show_explosion.rpc(roomba.global_position)
	if roomba.breach_hub != null:
		return  # the horde is no part of the patrol: no replacement, no boss call
	if roomba.is_boss:
		print("[Roombas] THE MEGA VAC-COP IS DOWN!")
	else:
		_respawn_at.append(_clock + respawn_seconds)
		_kills_toward_boss += 1


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not _patrolling:
		return
	_clock += delta
	if Mainframe.instance.breach_busy:
		# A SEWER BREACH: the horde pours in, and the city's patrol waits until it's over.
		for i in mini(breach_spawns_per_frame, _breach_queue.size()):
			var bot: Dictionary = _breach_queue.pop_front()
			_spawn_breach_bot(bot.hub, bot.boss)
		_set_off_bots(delta)
		return
	for i in range(_respawn_at.size() - 1, -1, -1):
		if _clock >= _respawn_at[i]:
			_respawn_at.remove_at(i)
			_spawn_one()
	_follow_the_heat()


## Host: more Roombas when the city is hot, and the MEGA VAC-COP when it's called in.
func _follow_the_heat() -> void:
	var heat := HeatMeter.instance
	# Level bosses: one every time the heat reaches a level in boss_on_levels (even if another
	# boss is already out). Bosses stay until they're destroyed or the district ends.
	var lvl := heat.level()
	var hot_enough := heat.heat >= boss_min_heat  # no bosses at all below Boss Min Heat
	while _boss_level_done < mini(lvl, HeatMeter.MAX_LEVEL - 1):
		_boss_level_done += 1
		if _boss_level_done in boss_on_levels and hot_enough:
			_spawn_boss("HEAT LEVEL %d" % _boss_level_done)
	# The other bosses only come when no boss is out:
	#   - called in after every boss_every_kills VAC-COPs destroyed, up to bosses_per_district,
	#   - and always out for the DEEP CLEAN (max heat).
	if _bosses_out() == 0:
		var called := _kills_toward_boss >= boss_every_kills and _bosses_called < bosses_per_district \
			and hot_enough  # (kills before heat 25 still count: the boss comes once it's hot enough)
		if called:
			_kills_toward_boss -= boss_every_kills
			_bosses_called += 1
			_spawn_boss("%d/%d kill calls this district" % [_bosses_called, bosses_per_district])
		elif deep_clean_extra > 0 or lvl == HeatMeter.MAX_LEVEL:
			_spawn_boss("DEEP CLEAN")

	# Regular Roombas: how many are out (or on their way back after being smashed)?
	# (During the DEEP CLEAN there's no waiting: the swarm pours in, one every frame.)
	if _clock < _next_change_at and deep_clean_extra == 0:
		return
	var regulars: Array[Roomba] = []
	for child in get_children():
		var roomba := child as Roomba
		if roomba != null and not roomba.is_boss and not roomba.is_queued_for_deletion():
			regulars.append(roomba)
	var wanted := roomba_count + heat.extra_roombas() + deep_clean_extra \
		+ floori(extra_roombas_per_player * maxi(Game.instance.player_count() - 2, 0))
	if regulars.size() + _respawn_at.size() < wanted:
		for i in (swarm_spawns_per_frame if deep_clean_extra > 0 else 1):
			_spawn_one(deep_clean_extra > 0)
		_next_change_at = _clock + reinforce_seconds
	elif regulars.size() + _respawn_at.size() > wanted:
		# Too many for this heat: send one home, but only one nobody is looking at.
		for roomba in regulars:
			if roomba.state == Roomba.State.PATROL and _far_from_cats(roomba.global_position, 30.0):
				roomba.queue_free()
				break
		_next_change_at = _clock + reinforce_seconds


## "swarm" = DEEP CLEAN: appear close to a cat that's still up top.
func _spawn_one(swarm: bool = false) -> void:
	var roomba := _pick_scene().instantiate() as Roomba
	roomba.name = "Roomba%d" % _next_number  # unique names keep everyone's copies matched up
	_next_number += 1
	roomba.position = _swarm_spot() if swarm else _spawn_spot()
	roomba.destroyed.connect(roomba_destroyed)
	add_child(roomba, true)


## Host: which kind of patrol unit comes next (see Patrol Mix).
func _pick_scene() -> PackedScene:
	var roll := _rng.randf()
	if roll < lint_trapper_chance:
		return LINT_TRAPPER_SCENE
	if roll < lint_trapper_chance + squirt_drone_chance:
		return SQUIRT_DRONE_SCENE
	return ROOMBA_SCENE


## DEEP CLEAN: a sidewalk spot near (but not on top of) a random cat up in the city.
func _swarm_spot() -> Vector3:
	var targets: Array[Vector3] = []
	for player_id in Game.instance.player_ids():
		if Game.instance.is_up_top(player_id):
			targets.append(Game.instance.player_position(player_id))
	if targets.is_empty():
		return _spawn_spot()
	var target := targets[_rng.randi_range(0, targets.size() - 1)]
	var spot := Vector3.ZERO
	for attempt in 40:
		spot = ItemManager.instance.random_sidewalk_spot(_rng) + Vector3(0, 0.1, 0)
		var d := spot.distance_to(target)
		if d > swarm_min_distance and d < swarm_max_distance:
			break
	return spot


## Host: send one MEGA VAC-COP in from across town (why = for the console log).
func _spawn_boss(why: String) -> void:
	var boss := BOSS_SCENE.instantiate() as Roomba
	boss.name = "RoombaBoss%d" % _next_number
	_next_number += 1
	boss.position = _spawn_spot(boss_spawn_distance)
	boss.destroyed.connect(roomba_destroyed)
	add_child(boss, true)
	print("[Roombas] MEGA VAC-COP DEPLOYED (%s)" % why)
	_boss_siren.rpc()  # everyone hears it coming


## Host: how many MEGA VAC-COPs are out right now.
func _bosses_out() -> int:
	var count := 0
	for child in get_children():
		var roomba := child as Roomba
		if roomba != null and roomba.is_boss and not roomba.is_queued_for_deletion():
			count += 1
	return count


## A random sidewalk spot away from the centre and at least "distance" from every cat.
func _spawn_spot(distance: float = min_spawn_distance) -> Vector3:
	var spot := Vector3.ZERO
	for attempt in 30:
		spot = ItemManager.instance.random_sidewalk_spot(_rng) + Vector3(0, 0.1, 0)
		if Vector2(spot.x, spot.z).length() > min_spawn_distance and _far_from_cats(spot, distance):
			break
	return spot


func _far_from_cats(spot: Vector3, distance: float) -> bool:
	for cat in Game.instance.players.get_children():
		if spot.distance_to((cat as Node3D).global_position) < distance:
			return false
	return true


## Host -> everyone: the MEGA VAC-COP's siren (everywhere at once: it's on its way).
@rpc("authority", "call_local", "reliable")
func _boss_siren() -> void:
	Sound.play("boss_siren")  # sounds/sfx/boss_siren.wav


## Everyone: a flash of orange light and bits of Roomba flying everywhere.
@rpc("authority", "call_local", "reliable")
func _show_explosion(at: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1, 0.55, 0.15)
	flash.light_energy = 8.0
	flash.light_volumetric_fog_energy = 4.0
	flash.omni_range = 7.0
	flash.position = at + Vector3(0, 0.8, 0)
	get_parent().add_child(flash)
	var fade := flash.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, 0.6)
	fade.tween_callback(flash.queue_free)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.85, 0.9)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.06, 0.15)
	for i in 7:
		var bit := MeshInstance3D.new()
		bit.mesh = mesh
		bit.material_override = material
		bit.position = at + Vector3(0, 0.3, 0)
		get_parent().add_child(bit)
		var out := Vector3(cos(i * 0.9), 0, sin(i * 0.9)) * randf_range(1.0, 2.5)
		var fly := bit.create_tween().set_parallel()
		fly.tween_property(bit, "position", at + out + Vector3(0, 1.2, 0), 0.3).set_ease(Tween.EASE_OUT)
		fly.tween_property(bit, "rotation", Vector3(randf() * 8, randf() * 8, 0), 0.7)
		fly.chain().tween_property(bit, "position:y", minf(at.y, 0.1) + 0.03, 0.4).set_ease(Tween.EASE_IN)
		fly.chain().tween_callback(bit.queue_free).set_delay(2.0)
