class_name HudNameTags
extends Control
## CYPURRPUNK — names floating over cats' and NPCs' heads, drawn by the HUD so they're sharp.
## Lives at scenes/ui/hud.tscn > HUD > Frame > Names (under everything else on the HUD).
##
## HOW IT WORKS: cats (scenes/player.tscn) and NPCs (scenes/npcs/*.tscn) still have their
## "NameTag" Label3D in the 3D scene: that's the MARKER saying where the name goes, what it says
## (Text) and its colour (Modulate). Every Label3D in the group "hud_name_tags" is made invisible
## in 3D, and this script puts a sharp HUD label on the screen exactly where it would have been.
##   - It shrinks with distance, like a real sign (between Min and Max Font Size).
##   - It fades out towards Max Distance, and hides behind walls (like the 3D one did).
##   - Hiding the Label3D (e.g. your own cat's name) hides the HUD name too.
## Street items use the same markers, made in code (ItemManager._make_item_tag), with metadata:
##   - "max_distance": this tag's own limit instead of Max Distance.
##   - "press_e" + "item_name": shown as "[E] PAW-PISTOL", with each player's own button.
##
## GIVE SOMETHING NEW A NAME TAG: add a Label3D child where the name should float, type the
## name in its Text, pick a colour in Modulate, then Node dock > Groups > add "hud_name_tags".

## The group a Label3D joins to be drawn here.
const GROUP := "hud_name_tags"

## Names further away than this (metres) aren't shown.
@export var max_distance: float = 30.0
## Names fade out over this many metres before max_distance.
@export var fade_distance: float = 8.0
## How tall the name would be standing in the world (metres). It shrinks with distance like a sign.
@export var world_text_height: float = 0.28
## Never smaller than this (HUD units: the screen is 720 tall), so far names stay readable...
@export var min_font_size: int = 14
## ...and never bigger than this, so a cat right next to the camera doesn't fill the screen.
@export var max_font_size: int = 32
## Hide names when a wall / building is between the camera and them.
@export var hide_behind_walls: bool = true
## Which physics layers count as walls for hide_behind_walls (layer 1 = the city and hub).
@export_flags_3d_physics var wall_layers: int = 1

## Label3D instance id -> its HUD Label.
var _labels := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	# Split screen: each player's HUD places names using THAT player's camera and screen size.
	var seat: int = (owner as Hud).seat if owner is Hud else 0
	var screen := GameScreen.instance
	var camera: Camera3D = screen.camera_for_seat(seat) if screen != null else null
	var game_size: Vector2 = screen.screen_size_for_seat(seat) if screen != null else Vector2.ONE
	var me: CatPlayer = Game.instance.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat)) if Game.instance != null else null
	var seen := {}
	if camera != null:
		for node in get_tree().get_nodes_in_group(GROUP):
			var tag := node as Label3D
			if tag == null:
				continue
			tag.transparency = 1.0  # see-through: the HUD draws the name instead
			if me != null and tag.get_parent() == me:
				continue  # (no need to see your own name)
			var id := tag.get_instance_id()
			seen[id] = true
			if not _labels.has(id):
				_labels[id] = _new_label()
			var label: Label = _labels[id]
			label.visible = _place(label, tag, camera, game_size, seat)
	# Forget the names of things that are gone (a player left, the scene changed).
	for id in _labels.keys():
		if not seen.has(id):
			_labels[id].queue_free()
			_labels.erase(id)


## Put the HUD label where the Label3D is on screen. Returns false if it shouldn't show.
func _place(label: Label, tag: Label3D, camera: Camera3D, game_size: Vector2, seat: int) -> bool:
	if not tag.is_visible_in_tree() or tag.text == "":
		return false
	var where := tag.global_position
	if camera.is_position_behind(where):
		return false
	var distance := camera.global_position.distance_to(where)
	# A tag can set its own limit (street items do); everything else uses Max Distance.
	var limit: float = tag.get_meta("max_distance", max_distance)
	if distance > limit:
		return false
	if hide_behind_walls and _behind_wall(camera, tag):
		return false

	# Size: how many HUD units one metre is at that distance, times the name's height in metres.
	var units_per_metre := size.y / (2.0 * distance * tan(deg_to_rad(camera.fov) / 2.0))
	var font_size := clampi(roundi(world_text_height * units_per_metre), min_font_size, max_font_size)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", maxi(4, font_size / 4))
	# Press-E gear shows THIS player's button, so each split-screen pane can read differently.
	if tag.get_meta("press_e", false):
		label.text = "[%s] %s" % [Hud.key_for("interact", seat), tag.get_meta("item_name", tag.text)]
	else:
		label.text = tag.text
	label.add_theme_color_override("font_color", Color(tag.modulate, 1.0))
	var fade := clampf((limit - distance) / maxf(fade_distance, 0.01), 0.0, 1.0)
	label.modulate.a = tag.modulate.a * fade

	# Position: the game picture is game_size pixels; this HUD layer covers it exactly.
	var on_screen := camera.unproject_position(where) * (size / game_size)
	label.size = label.get_combined_minimum_size()
	label.position = (on_screen - label.size / 2.0).round()
	return true


## Is there a wall between the camera and this name? (The cat / NPC itself, our own cat and
## cars don't count.)
func _behind_wall(camera: Camera3D, tag: Label3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, tag.global_position, wall_layers)
	var skip: Array[RID] = []
	var owner_body := tag.get_parent() as CollisionObject3D
	if owner_body != null:
		skip.append(owner_body.get_rid())
	var seat: int = (owner as Hud).seat if owner is Hud else 0
	var my_cat := Game.instance.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat)) if Game.instance != null else null
	if my_cat != null:
		skip.append(my_cat.get_rid())
	for car in get_tree().get_nodes_in_group("cars"):
		if car is CollisionObject3D:
			skip.append(car.get_rid())
	query.exclude = skip
	return not camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _new_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label
