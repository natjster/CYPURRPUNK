class_name RecruitReveal
extends Node3D
## THE NEW-RECRUIT REVEAL: when your gang recruits a SEWER REBELLION cat at the TINKER WORKBENCH,
## every gang member down in that sewer gets a short "camera shot" of the new cat popping into
## the sewer: the camera cuts to the empty spot, the cat drops in with a squash-and-bounce, a burst
## of sparkles in the gang colour, a flash of light, a meow and a big "NEW RECRUIT!" banner.
## Then the camera goes back to your cat (and the workbench comes back on the new cat's tab, if you
## had it open). Gang members up in the city just get a line in the feed.
##
## The hub (scripts/hub.gd _ready) makes one of these by itself: there's nothing to add in the
## editor. Every computer plays it by itself when Upgrades says "a gang recruited" (the _recruited
## RPC in scripts/upgrades.gd), so there's nothing extra sent over the network.
##
## TUNING: the numbers below are @export, but this node is made in code, so change the defaults
## here in the script (e.g. reveal_seconds = 3.5 makes the shot longer).
##
## How it hooks in:
##   game_screen.gd view_override_for(cat)   asks camera_for(cat) first: our camera instead of the cat's
##   cat_player.gd _menu_open()              is_watching(cat): the cat stands still during the shot
##   npc.gd pop_in(delay)                    the cat's squash-and-bounce + sparkles
##   recruit_home.gd pop_delay               their furniture pops in at the same moment
##
## Test: --reveal_test=N (recruits cat N for your gang right away; prints "DevCapture reveal ...").

## How long the whole shot lasts (seconds).
@export var reveal_seconds: float = 3.4
## How long the camera looks at the empty spot before the cat pops in (seconds).
@export var pop_delay: float = 0.7
## Where the camera starts: this far in front of the cat (metres)...
@export var camera_distance: float = 3.6
## ...and this high above the cat's feet (metres).
@export var camera_height: float = 1.6
## The camera slowly pushes in this far during the shot (metres), for a bit of drama.
@export var push_in: float = 0.8
## ...while circling this far round the cat (degrees).
@export var orbit_degrees: float = 14.0
## What the camera looks at: this high above the cat's feet (metres). Higher = the cat sits lower
## on screen, out from under the "NEW RECRUIT!" banner.
@export var look_height: float = 1.0
@export var camera_fov: float = 52.0
## How long the "NEW RECRUIT!" banner stays up (seconds).
@export var banner_seconds: float = 3.5

## The one playing right now (only one recruit reveal at a time; a second one replaces it).
static var _playing: RecruitReveal = null

var _hub: UndergroundHub
var _camera: Camera3D
var _npc: Npc
var _left: float = 0.0
var _start_spot: Vector3
var _focus: Vector3
## Workbenches we closed for the shot, to open again after: [{seat, cat, tab}]
var _reopen: Array = []


func _ready() -> void:
	name = "RecruitReveal"
	_hub = get_parent() as UndergroundHub
	_camera = Camera3D.new()
	_camera.name = "RevealCamera"
	_camera.fov = camera_fov
	add_child(_camera)
	if Upgrades.instance != null:
		Upgrades.instance.recruited.connect(_on_recruited)


## Is this cat's player watching a recruit reveal right now? (Then the cat doesn't move.)
static func is_watching(cat: CatPlayer) -> bool:
	return camera_for(cat) != null


## The camera this player looks through instead of their cat's, or null.
static func camera_for(cat: CatPlayer) -> Camera3D:
	var reveal := _playing
	if reveal == null or not is_instance_valid(reveal) or reveal._left <= 0.0 or cat == null:
		return null
	if not reveal._shows_to(cat):
		return null
	return reveal._camera


## Only gang members (on this computer) who are down in this sewer, awake, get the shot.
func _shows_to(cat: CatPlayer) -> bool:
	if not is_instance_valid(cat) or not cat.is_multiplayer_authority() or cat.team != _hub.team:
		return false
	if cat.knocked_out:
		return false
	return UndergroundHub.hub_at(cat.global_position) == _hub


## Upgrades says a gang recruited cat number "tier" (every computer).
func _on_recruited(team: int, tier: int) -> void:
	if _hub == null or team != _hub.team:
		return
	_npc = _find_npc(tier)
	if _npc == null:
		return
	var color := Teams.color_of(maxi(0, team))
	# Is anyone on this computer down here to watch? Up in the city = just a feed line.
	var watchers := 0
	for cat in Game.instance.local_cats():
		if (cat as CatPlayer).team == team:
			if _shows_to(cat):
				watchers += 1
			else:
				Hud.feed("NEW RECRUIT: %s JOINED THE REBELLION" % _npc.npc_name.to_upper(), color)
	_npc.pop_in(pop_delay if watchers > 0 else 0.0, reveal_seconds if watchers > 0 else 0.0)
	for home in _hub.get_children():
		if home is RecruitHome and (home as RecruitHome).npc == _npc:
			(home as RecruitHome).pop_delay = pop_delay if watchers > 0 else 0.0
			(home as RecruitHome)._update_presence()  # (now, not at its next check: in time with the cat)
	if watchers == 0:
		return
	_start_shot()
	print("DevCapture reveal started: %s (tier %d, team %d, %d watching)" % [_npc.npc_name, tier, team, watchers])


func _find_npc(tier: int) -> Npc:
	for child in _hub.get_children():
		if child is Npc and (child as Npc).rebellion_tier == tier:
			return child
	return null


func _start_shot() -> void:
	if _playing != null and is_instance_valid(_playing) and _playing != self:
		_playing._finish()
	_playing = self
	_left = reveal_seconds
	_focus = _npc.global_position + Vector3.UP * look_height
	# In front of the cat = the way its model faces (cats face -Z), level with the floor.
	var front := -_npc.front_basis().z
	front.y = 0.0
	front = front.normalized() if front.length() > 0.01 else Vector3.FORWARD
	_start_spot = _clear_spot(_npc.global_position + front * camera_distance + Vector3.UP * camera_height)
	_place_camera(0.0)
	# The workbench covers the screen: put it away for the shot, bring it back after.
	_reopen.clear()
	for cat in Game.instance.local_cats():
		if not _shows_to(cat):
			continue
		var screen := WorkbenchScreen.for_seat(cat.slot)
		if screen != null and screen.visible:
			_reopen.append({"seat": cat.slot, "cat": cat})
			screen.close()
		Hud.banner("NEW RECRUIT!\n%s JOINS THE REBELLION" % _npc.npc_name.to_upper(), banner_seconds,
			Teams.color_of(maxi(0, _hub.team)), cat.slot)
	Sound.play("koi_grab")  # (a prize jingle as the shot starts)


## Pull the camera in if a wall is between it and the cat (so it never ends up inside the wall).
func _clear_spot(wanted: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(_focus, wanted)
	ray.exclude = [_npc.get_rid()]
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return wanted
	return _focus + (hit.position - _focus) * 0.85


## t = 0..1 through the shot: slowly circle and push in towards the cat.
func _place_camera(t: float) -> void:
	var eased := 1.0 - pow(1.0 - t, 2.0)
	var offset := _start_spot - _focus
	offset = offset.rotated(Vector3.UP, deg_to_rad(orbit_degrees) * eased)
	var length := offset.length()
	offset = offset.normalized() * maxf(1.0, length - push_in * eased)
	_camera.global_position = _focus + offset
	_camera.look_at(_focus)


func _process(delta: float) -> void:
	if _playing != self or _left <= 0.0:
		return
	_left -= delta
	_place_camera(clampf(1.0 - _left / reveal_seconds, 0.0, 1.0))
	if _left <= 0.0:
		_finish()


## The shot is over: cameras go back to the cats (game_screen.gd does that by itself once
## camera_for says null), and the workbench comes back on the new recruit's tab.
func _finish() -> void:
	_left = 0.0
	if _playing == self:
		_playing = null
	for entry in _reopen:
		var cat: CatPlayer = entry.cat
		var screen := WorkbenchScreen.for_seat(entry.seat)
		if screen == null or not is_instance_valid(cat) or cat.knocked_out:
			continue
		if _npc != null and _npc.rebellion_tier > 0:
			screen.tab = _npc.rebellion_tier + 1  # workbench tabs: 0 boss, 1 shopkeeper, 2-6 = recruits 1-5
		screen.open(cat, _hub)
		screen.note("NEW RECRUIT! %s JOINS THE REBELLION! Their quest and upgrades are open." % _npc.npc_name, true)
	_reopen.clear()
	print("DevCapture reveal finished")
