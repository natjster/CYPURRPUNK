class_name HudHealthBars
extends Control
## CYPURRPUNK — health bars floating over enemies' (and other cats') heads, Cyberpunk-style,
## drawn by the HUD so they're sharp. Lives at scenes/ui/hud.tscn > HUD > Frame > Bars.
##
## What you see over a VAC-COP:
##        VAC-COP
##   ██████░░░░      <- thin plain red bar; the bit just lost is white-yellow and drains away
##   - It appears once the thing is HURT or is CHASING someone, and fades out further than
##     max_distance or behind walls.
##   - BOSSES (the MEGA VAC-COP) get the same kind of bar floating over them, just bigger
##     (boss_size), with a gold name, and seen from further away (boss_distance).
##   - Other players' cats show a slim bar under their name once they're hurt.
##
## GIVE SOMETHING NEW A HEALTH BAR (e.g. a future guard dog): add its root node to the group
## "hud_health_bars" (Node dock > Groups) and give its script this function:
##   func health_bar_info() -> Dictionary:
##       return {"hp": health, "max": max_health, "position": global_position + Vector3.UP,
##               "show": health < max_health, "name": "GUARD DOG", "boss": false}
## ("show" false or an empty Dictionary = no bar right now.) Roombas (roomba.gd) and cats
## (cat_player.gd) are the examples. Two optional extras: "see_from": 150.0 (metres, instead of
## max_distance) and "through_walls": true (a DOWNED cat uses both, so friends can find it).
## And "progress": 0..1 fills the bar in revive_color over the top (a downed cat's REVIVE METER).

## The group a node joins to get a floating bar.
const GROUP := "hud_health_bars"

## Bars further away than this (metres) aren't shown...
@export var max_distance: float = 35.0
## ...and fade out over this many metres before it.
@export var fade_distance: float = 8.0
## How wide a normal bar is in the world (metres); it shrinks with distance like a sign...
@export var world_width: float = 1.1
## ...but never narrower / wider than these (HUD units: the screen is 720 tall).
@export var min_width: float = 70.0
@export var max_width: float = 150.0
## Boss bars float over the boss like the others, but are seen from this far away (metres)...
@export var boss_distance: float = 60.0
## ...and are this many times bigger (width and thickness).
@export var boss_size: float = 2.0
## Bar thickness (HUD units).
@export var bar_height: float = 4.5
@export var name_font_size: int = 15
## Seconds the white-yellow chip waits before draining, and how fast it drains (bar per second).
@export var chip_delay: float = 0.35
@export var drain_speed: float = 1.2
@export var hide_behind_walls: bool = true
@export_flags_3d_physics var wall_layers: int = 1

@export_group("Colours")
@export var fill_color: Color = Color(1.0, 0.27, 0.32)
@export var chip_color: Color = Color(1.0, 0.93, 0.55)
@export var back_color: Color = Color(0.1, 0.02, 0.05, 0.75)
@export var frame_color: Color = Color(1.0, 0.35, 0.45, 0.8)
@export var name_color: Color = Color(1.0, 0.75, 0.75)
## Other players' cats (friends) get a cyan bar instead of red.
@export var friend_color: Color = Color(0.35, 1.0, 1.0)
## The revive meter filling a downed cat's bar while a friend holds the button.
@export var revive_color: Color = Color(0.45, 1.0, 0.5)

## Instance id -> {shown, chip, wait, alpha} (each bar's animation).
var _anim := {}
## What to draw this frame: [{rect, shown, chip, alpha, name, boss, friend}].
var _draw_list: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var seat: int = (owner as Hud).seat if owner is Hud else 0
	var screen := GameScreen.instance
	var camera: Camera3D = screen.camera_for_seat(seat) if screen != null else null
	var game_size: Vector2 = screen.screen_size_for_seat(seat) if screen != null else Vector2.ONE
	var me: CatPlayer = Game.instance.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat)) if Game.instance != null else null
	_draw_list.clear()
	var seen := {}
	if camera != null:
		for node in get_tree().get_nodes_in_group(GROUP):
			if node == me or not node.has_method("health_bar_info"):
				continue
			var info: Dictionary = node.health_bar_info()
			# Cats of OUR gang get the cyan friend bar; the other gang's get the red one, and
			# their DOWNED beacon isn't shown far off / through walls (that's for their friends).
			var friend: bool = node is CatPlayer and (me == null or (node as CatPlayer).team == me.team)
			if node is CatPlayer and not friend:
				info = info.duplicate()
				info.erase("see_from")
				info.erase("through_walls")
			var id: int = node.get_instance_id()
			seen[id] = true
			var anim: Dictionary = _anim.get(id, {})
			if anim.is_empty():
				anim = {"shown": 1.0, "chip": 1.0, "wait": 0.0, "alpha": 0.0}
				_anim[id] = anim
			_animate(anim, info, delta)
			var boss: bool = info.get("boss", false)
			var too_far: float = info.get("see_from", boss_distance if boss else max_distance)
			var visible_now := _wanted(info, node, camera, me, too_far)
			anim.alpha = move_toward(anim.alpha, 1.0 if visible_now else 0.0, delta * 5.0)
			if anim.alpha > 0.0 and not info.is_empty():
				_add_to_draw_list(info, anim, camera, game_size, friend, boss, too_far)
	for id in _anim.keys():
		if not seen.has(id):
			_anim.erase(id)
	queue_redraw()


## Move this bar's red fill and white-yellow chip toward its health.
func _animate(anim: Dictionary, info: Dictionary, delta: float) -> void:
	if info.is_empty() or float(info.get("max", 0.0)) <= 0.0:
		return
	var target := clampf(float(info.hp) / float(info.max), 0.0, 1.0)
	if target < anim.shown:
		anim.shown = target
		anim.wait = chip_delay
	else:
		anim.shown = minf(anim.shown + drain_speed * delta, target)
	anim.wait = maxf(anim.wait - delta, 0.0)
	if anim.chip < anim.shown:
		anim.chip = anim.shown
	elif anim.wait <= 0.0:
		anim.chip = maxf(anim.chip - drain_speed * delta, anim.shown)


## Should this bar show right now (wants to, in range, in front of the camera, not behind a wall)?
func _wanted(info: Dictionary, node: Node, camera: Camera3D, me: CatPlayer, too_far: float) -> bool:
	if info.is_empty() or not info.get("show", false) or not (node as Node3D).is_visible_in_tree():
		return false
	var where: Vector3 = info.position
	if camera.is_position_behind(where):
		return false
	if camera.global_position.distance_to(where) > too_far:
		return false
	if hide_behind_walls and not info.get("through_walls", false) and _behind_wall(camera, where, node, me):
		return false
	return true


## A bar floating over the thing (bosses: boss_size times bigger, seen out to boss_distance).
func _add_to_draw_list(info: Dictionary, anim: Dictionary, camera: Camera3D, game_size: Vector2, friend: bool, boss: bool, too_far: float) -> void:
	var where: Vector3 = info.position
	if camera.is_position_behind(where):
		return
	var distance := camera.global_position.distance_to(where)
	var units_per_metre := size.y / (2.0 * maxf(distance, 0.1) * tan(deg_to_rad(camera.fov) / 2.0))
	var big := boss_size if boss else 1.0
	var width := clampf(world_width * big * units_per_metre, min_width * big, max_width * big)
	var height := bar_height * (0.7 if friend else big)
	var on_screen := camera.unproject_position(where) * (size / game_size)
	var fade := clampf((too_far - distance) / maxf(fade_distance, 0.01), 0.0, 1.0)
	_draw_list.append({
		"rect": Rect2((on_screen - Vector2(width * 0.5, height)).round(), Vector2(width, height)),
		"shown": anim.shown, "chip": anim.chip, "alpha": anim.alpha * fade,
		"name": info.get("name", ""), "boss": boss, "friend": friend, "progress": float(info.get("progress", 0.0))})


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	for bar in _draw_list:
		var rect: Rect2 = bar.rect
		var a: float = bar.alpha
		var w := rect.size.x
		var fill: Color = friend_color if bar.friend else fill_color
		# A plain rectangle: dark back, red fill, then the white-yellow chip (just lost).
		draw_rect(rect, Color(back_color, back_color.a * a))
		draw_rect(Rect2(rect.position, Vector2(w * bar.shown, rect.size.y)), Color(fill, a))
		if bar.chip > bar.shown:
			draw_rect(Rect2(rect.position.x + w * bar.shown, rect.position.y, w * (bar.chip - bar.shown), rect.size.y), Color(chip_color, a))
		# Revive meter: fills the whole bar from the left over the top while a friend revives.
		if bar.progress > 0.0:
			draw_rect(rect, Color(back_color, back_color.a * a))
			draw_rect(Rect2(rect.position, Vector2(w * bar.progress, rect.size.y)), Color(revive_color, a))
		draw_rect(rect, Color(friend_color if bar.friend else frame_color, frame_color.a * a), false, 1.0)
		# Name above the bar (left-aligned, like Cyberpunk). The boss's is bigger and gold.
		var label: String = bar.name
		if label != "":
			var font_size := name_font_size + (3 if bar.boss else 0)
			var pos := Vector2(rect.position.x, rect.position.y - 5)
			draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.04, 0.01, 0.08, a))
			draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(Color(1, 0.85, 0.3) if bar.boss else name_color, a))


## Is there a wall between the camera and the bar? (The thing itself, our cat and cars don't count.)
func _behind_wall(camera: Camera3D, where: Vector3, node: Node, me: CatPlayer) -> bool:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, where, wall_layers)
	var skip: Array[RID] = []
	if node is CollisionObject3D:
		skip.append((node as CollisionObject3D).get_rid())
	if me != null:
		skip.append(me.get_rid())
	for car in get_tree().get_nodes_in_group("cars"):
		if car is CollisionObject3D:
			skip.append(car.get_rid())
	query.exclude = skip
	return not camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
