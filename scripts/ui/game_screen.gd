class_name GameScreen
extends Control
## MEOW-CITY 1999 — the very top scene (scenes/game_screen.tscn, the one Godot starts).
## It puts two pictures on your monitor:
##
##   1. The GAME: the whole of scenes/main.tscn (the 3D city, the pixel menus, the CRT + dither
##      look) is drawn inside GameView/GameViewport at PS1 size, 240 pixels tall, then blown up
##      to fill the window with sharp, blocky pixels.
##   2. The HUD (scenes/ui/hud.tscn, scripts/ui/hud.gd): cash, HP, prompts, crosshair... drawn
##      ON TOP at your monitor's REAL resolution, so its text stays crisp instead of being
##      squashed into 240 pixel rows.
##
## SPLIT SCREEN (couch co-op, scripts/seats.gd): with 2-4 players on this computer the game
## picture is cut into one screen per player. Player 1 keeps GameView; players 2-4 get
## GameView2..4, built by this script. Each extra screen has its own little SubViewport that
## looks at the SAME world (the city isn't built twice) through a camera that copies that
## player's cat camera every frame, with its own rain and sewer/city fog. A second little
## SubViewport ("Post") then gives that picture the CRT + dither look.
##   2 players: side by side (or top + bottom: SETTINGS > DISPLAY > 2-PLAYER SPLIT)
##   3-4 players: four corners (an empty corner says "PRESS START TO JOIN")
## Full-screen menus (pause, settings, MY CAT) go back to one big screen while they're open.
## The whole picture stays 240 game pixels tall, so each player's screen is half or a quarter
## of it: chunky, like a real PS1 split screen.
## Every player also gets their OWN HUD (cash, HP, prompts, inventory, talk box) on their own
## screen, shrunk to fit (hud_scale_for). Player 1's is the HUD node; players 2-4's are copies of
## scenes/ui/hud.tscn made here, each in its own SubViewport ("Hud2".."Hud4") so each player
## has their own highlighted button. Each controller's presses go to its player's HUD first.
##
## Node tree:
##   GameScreen (this script)
##   ├── HUD                 <- the sharp overlay (a CanvasLayer, always drawn on top)
##   ├── Bars                <- black behind everything (the border you see in 4:3 / SHARP mode)
##   ├── GameView            <- shows player 1's game picture, blown up
##   │   └── GameViewport    <- the 320x240-ish "PS1 screen" the game is drawn into
##   │       └── Main        <- scenes/main.tscn (the actual game)
##   ├── GameView2..4        <- made by this script: players 2-4 (hidden until they join)
##   │   ├── GameViewport > Camera3D       <- their 3D view
##   │   └── Post > Dither                 <- the CRT look on top (what you see)
##   ├── Hud2..4             <- made by this script: players 2-4's HUDs (sharp, real resolution)
##   │   └── Viewport > HUD (scenes/ui/hud.tscn, Hud.seat = 1..3)
##   └── JoinHint            <- made by this script: "PRESS START TO JOIN" in an empty corner
##
## The size settings (SETTINGS > DISPLAY): see pixel_perfect and widescreen in scripts/settings.gd.
## This script also passes your mouse and keyboard on to the game inside GameViewport.

## The one game screen (GameScreen.instance).
static var instance: GameScreen

## The game picture is always this many pixels tall (the PS1 look).
@export var game_height: int = 240
## ...and at least this many pixels wide (4:3). With ASPECT = WIDE it grows wider to fill the window.
@export var design_width: int = 320
## Split screen: the black line between players' screens, in game pixels (0 = none).
@export var divider: int = 1
## Split screen: how big a player's HUD is on a smaller screen, compared to "just shrink it to
## fit" (1.0). Higher = bigger text (crowded), lower = smaller. Never bigger than full size.
@export var split_hud_boost: float = 1.25

@onready var hud: Hud = $HUD
@onready var game_view: TextureRect = $GameView
@onready var game_viewport: SubViewport = $GameView/GameViewport

## Players 2-4's screens, in order: {"view": TextureRect, "viewport": SubViewport (3D),
## "post": SubViewport (CRT look), "camera": Camera3D, "rain": GPUParticles3D, "dither": ColorRect,
## "seat": which seat it shows (-1 = hidden)}.
var _extra_panes: Array[Dictionary] = []
var _join_hint: Label
## Players 2-4's HUDs, by seat (index 1-3; index 0 unused): {"view": TextureRect,
## "viewport": SubViewport, "hud": Hud}.
var _seat_huds: Array = [null]
## What the screen was last laid out for, so it's only re-done when something changes.
var _layout_key: String = ""


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	process_priority = 100  # run after the cats have moved their cameras this frame
	game_view.texture = game_viewport.get_texture()
	_build_extra_panes()
	get_viewport().size_changed.connect(_fit)
	Settings.changed.connect(_fit)
	_fit()


## Players 2-4's screens (hidden until someone joins in).
func _build_extra_panes() -> void:
	var world := game_viewport.find_world_3d()  # the one world everybody's screen looks at
	var main := Game.instance
	for i in PlayerId.MAX_LOCAL - 1:
		var view := TextureRect.new()
		view.name = "GameView%d" % (i + 2)
		view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # sharp, blocky pixels
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.hide()
		add_child(view)
		move_child(view, game_view.get_index() + 1 + i)

		var viewport := SubViewport.new()
		viewport.name = "GameViewport"
		viewport.size = Vector2i(design_width, game_height)
		viewport.world_3d = world
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED  # not drawn while hidden
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		viewport.positional_shadow_atlas_size = game_viewport.positional_shadow_atlas_size
		viewport.audio_listener_enable_3d = false  # we hear the world from player 1's camera
		view.add_child(viewport)

		var camera := Camera3D.new()
		camera.name = "Camera3D"
		camera.current = true
		viewport.add_child(camera)
		# The CRT + 15-bit dither look, in a second viewport that reads the 3D picture
		# (shaders/psx_post.gdshader "use_source_texture"). Its own copy of player 1's material,
		# kept in step with CRT TV LOOK by _copy_crt_settings.
		var post := SubViewport.new()
		post.name = "Post"
		post.size = viewport.size
		post.render_target_update_mode = SubViewport.UPDATE_DISABLED
		post.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		view.add_child(post)
		view.texture = post.get_texture()
		var dither := ColorRect.new()
		dither.name = "Dither"
		var material := main.crt_material.duplicate() as ShaderMaterial
		material.set_shader_parameter("use_source_texture", true)
		material.set_shader_parameter("source_tex", viewport.get_texture())
		dither.material = material
		dither.set_anchors_preset(Control.PRESET_FULL_RECT)
		dither.mouse_filter = Control.MOUSE_FILTER_IGNORE
		post.add_child(dither)
		# Their own rain, falling around their camera (scripts/rain_follow.gd).
		var rain := main.get_node("Rain").duplicate() as GPUParticles3D
		rain.name = "Rain%d" % (i + 2)
		rain.emitting = false
		rain.visible = false
		rain.set("follow", camera)
		main.add_child(rain)

		_extra_panes.append({"view": view, "viewport": viewport, "post": post, "camera": camera, "rain": rain, "dither": dither, "seat": -1})
	Settings.changed.connect(_copy_crt_settings)
	_copy_crt_settings()

	# Players 2-4's HUDs, each in its own SubViewport (their own highlighted button).
	for seat in range(1, PlayerId.MAX_LOCAL):
		var hud_view := TextureRect.new()
		hud_view.name = "Hud%d" % (seat + 1)
		hud_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hud_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_view.hide()
		add_child(hud_view)
		var hud_viewport := SubViewport.new()
		hud_viewport.name = "Viewport"
		hud_viewport.transparent_bg = true
		hud_viewport.size_2d_override_stretch = true  # laid out in HUD units, drawn at real resolution
		hud_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		hud_viewport.gui_embed_subwindows = true
		hud_view.add_child(hud_viewport)
		hud_view.texture = hud_viewport.get_texture()
		var seat_hud := preload("res://scenes/ui/hud.tscn").instantiate() as Hud
		seat_hud.seat = seat  # before it enters the tree: it registers as that player's HUD
		hud_viewport.add_child(seat_hud)
		_seat_huds.append({"view": hud_view, "viewport": hud_viewport, "hud": seat_hud})

	_join_hint = Label.new()
	_join_hint.name = "JoinHint"
	_join_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_join_hint.add_theme_font_size_override("font_size", 28)
	_join_hint.add_theme_color_override("font_color", Color(1, 0.4, 0.8))
	_join_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_join_hint.hide()
	add_child(_join_hint)


## Every frame: re-cut the screen if players joined / left or a menu opened, and point the
## extra screens' cameras where their players' cats are looking.
func _process(_delta: float) -> void:
	var seats := shown_seats()
	var key := "%s %s" % [seats, Settings.split_side_by_side]
	if key != _layout_key:
		_fit()
	_follow_cameras()


## The seats (players on this computer, scripts/seats.gd) that get a screen right now:
## [0] alone, [0, 1] with two players... Just [0] while a full-screen menu is open.
func shown_seats() -> Array[int]:
	var seats: Array[int] = [0]
	var game := Game.instance
	if game == null or not is_instance_valid(game) or Hud.menu_open():
		return seats
	for seat in range(1, PlayerId.MAX_LOCAL):
		var cat := game.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat))
		if cat != null and cat.reads_input():
			seats.append(seat)
	return seats


## The camera a player's screen looks through (seat 0 = player 1), or null if they have no
## screen right now.
func camera_for_seat(seat: int) -> Camera3D:
	if seat == 0:
		return game_viewport.get_camera_3d()
	for pane in _extra_panes:
		if pane.seat == seat:
			return pane.camera
	return null


## How big a player's screen is in game pixels (for placing things on it, e.g. name tags).
func screen_size_for_seat(seat: int) -> Vector2:
	if seat == 0:
		return Vector2(game_viewport.size)
	for pane in _extra_panes:
		if pane.seat == seat:
			return Vector2(pane.viewport.size)
	return Vector2.ONE


## The cameras of every screen being shown (player 1's first). The hub uses this to decide
## the music and the moon (scripts/hub.gd).
func view_cameras() -> Array[Camera3D]:
	var cameras: Array[Camera3D] = []
	var first := game_viewport.get_camera_3d()
	if first != null:
		cameras.append(first)
	for pane in _extra_panes:
		if pane.seat != -1:
			cameras.append(pane.camera)
	return cameras


## Works out how big the game picture is and where it sits, whenever the window changes size,
## the display settings change, or players join / leave (split screen).
func _fit() -> void:
	var window := Vector2(get_window().size)  # real screen pixels
	if window.x < 1.0 or window.y < 1.0:
		return  # minimised
	var seats := shown_seats()
	_layout_key = "%s %s" % [seats, Settings.split_side_by_side]
	# This scene is laid out in "HUD units" (Project Settings > Display > Window: 720 tall),
	# which Godot scales to the real window. units_per_pixel turns real pixels into those units.
	var units_per_pixel := get_viewport_rect().size.y / window.y

	# How many screen pixels one game pixel becomes.
	var zoom := minf(window.x / design_width, window.y / game_height)
	if Settings.pixel_perfect:
		zoom = maxf(1.0, floorf(zoom))  # SHARP: whole numbers only, every game pixel the same size
	# WIDE: the game gets wider to fill the window; 4:3: it stays 320 wide with black side bars.
	var width := design_width
	if Settings.widescreen:
		width = maxi(design_width, floori(window.x / zoom))

	# Centre the blown-up picture in the window (on whole pixels, so the blocks stay even).
	var whole := Vector2(width, game_height)
	var corner := ((window - whole * zoom) / 2.0).floor()
	# Cut it into one screen per player (game pixels): player 1 first.
	var rects := _pane_rects(seats.size(), Vector2i(width, game_height))
	_place(game_view, game_viewport, rects[0], corner, zoom, units_per_pixel)
	for i in _extra_panes.size():
		var pane: Dictionary = _extra_panes[i]
		var shown := i + 1 < seats.size()
		pane.seat = seats[i + 1] if shown else -1
		pane.view.visible = shown
		pane.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
		pane.post.render_target_update_mode = pane.viewport.render_target_update_mode
		if shown:
			_place(pane.view, pane.viewport, rects[i + 1], corner, zoom, units_per_pixel)
			pane.post.size = pane.viewport.size
		else:
			pane.rain.emitting = false
			pane.rain.visible = false
	# Three players: the fourth corner invites a fourth.
	_join_hint.visible = seats.size() == 3
	if _join_hint.visible:
		_join_hint.text = "PRESS %s\nTO JOIN" % Controls.display_name("Pad Start")
		_join_hint.position = (corner + Vector2(rects[3].position) * zoom) * units_per_pixel
		_join_hint.size = Vector2(rects[3].size) * zoom * units_per_pixel

	# Every player's HUD sits on their own screen, shrunk to fit.
	hud.fit_to(Rect2(game_view.position, game_view.size), hud_scale_for(game_view.size))
	for seat in range(1, PlayerId.MAX_LOCAL):
		var seat_hud: Dictionary = _seat_huds[seat]
		var pane_index := seats.find(seat)
		var shown := pane_index > 0
		seat_hud.view.visible = shown
		seat_hud.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
		if not shown:
			continue
		var pane_view: TextureRect = _extra_panes[pane_index - 1].view
		seat_hud.view.position = pane_view.position
		seat_hud.view.size = pane_view.size
		seat_hud.viewport.size = Vector2i((pane_view.size / units_per_pixel).round())  # real pixels: sharp
		seat_hud.viewport.size_2d_override = Vector2i(pane_view.size.round())  # laid out in HUD units
		(seat_hud.hud as Hud).fit_to(Rect2(Vector2.ZERO, pane_view.size), hud_scale_for(pane_view.size))


## How big a HUD should be on a screen this size (HUD units): 1 = full size (a 720-tall screen),
## smaller for a half or quarter screen, so the cash, HP and windows still fit.
func hud_scale_for(screen_units: Vector2) -> float:
	var fit := minf(screen_units.y / 720.0, screen_units.x / 960.0)
	return clampf(fit * split_hud_boost, 0.5, 1.0)


## Where each player's screen goes inside the whole picture (game pixels), player 1 first.
func _pane_rects(count: int, whole: Vector2i) -> Array[Rect2i]:
	var w := whole.x
	var h := whole.y
	var half_w := (w - divider) / 2
	var half_h := (h - divider) / 2
	if count <= 1:
		return [Rect2i(0, 0, w, h)]
	if count == 2:
		if Settings.split_side_by_side:
			return [Rect2i(0, 0, half_w, h), Rect2i(w - half_w, 0, half_w, h)]
		return [Rect2i(0, 0, w, half_h), Rect2i(0, h - half_h, w, half_h)]
	return [Rect2i(0, 0, half_w, half_h), Rect2i(w - half_w, 0, half_w, half_h),
		Rect2i(0, h - half_h, half_w, half_h), Rect2i(w - half_w, h - half_h, half_w, half_h)]


## Size one screen's viewport (game pixels) and put its picture on the monitor.
func _place(view: TextureRect, viewport: SubViewport, rect: Rect2i, corner: Vector2, zoom: float, units_per_pixel: float) -> void:
	if viewport.size != rect.size:
		viewport.size = rect.size
	view.position = (corner + Vector2(rect.position) * zoom) * units_per_pixel
	view.size = Vector2(rect.size) * zoom * units_per_pixel


## CRT TV LOOK changed (game.gd sets player 1's CRT material): copy it to players 2-4's screens.
func _copy_crt_settings() -> void:
	var source: ShaderMaterial = Game.instance.crt_material
	for pane in _extra_panes:
		for param in Game.CRT_PARAMS:
			(pane.dither.material as ShaderMaterial).set_shader_parameter(param, source.get_shader_parameter(param))


## Players 2-4's screens look through a copy of their cat's camera (wherever it is: behind the
## cat, or behind the car), with the sewer or city fog of where that camera is.
func _follow_cameras() -> void:
	var game := Game.instance
	if game == null or not is_instance_valid(game):
		return
	for pane in _extra_panes:
		if pane.seat == -1:
			continue
		var cat := game.cat_for(PlayerId.make(multiplayer.get_unique_id(), pane.seat))
		if cat == null:
			continue
		var source: Camera3D = cat.camera
		var camera: Camera3D = pane.camera
		camera.global_transform = source.global_transform
		camera.fov = source.fov
		camera.near = source.near
		camera.far = source.far
		var in_hub := UndergroundHub.is_in_hub(camera.global_position)
		camera.environment = game.hub.environment_for(in_hub)
		pane.rain.visible = not in_hub
		pane.rain.emitting = not in_hub


## Your mouse and keys arrive here first. Pass them on to the game inside GameViewport,
## with mouse positions turned into game pixels (so menus and mouse-look work as before).
## (Except while player 1's HUD window - the talk box or inventory - is open: then their keys,
## mouse and controller stay up here for the HUD's own buttons.)
## Split screen: players 2-4's controller presses go to THEIR HUD first (their inventory and
## talk box), and only on to the game if their HUD didn't want them.
func _input(event: InputEvent) -> void:
	var seat := Seats.seat_of_event(event)
	if seat > 0 and _seat_huds[seat].view.visible:
		var hud_viewport: SubViewport = _seat_huds[seat].viewport
		hud_viewport.push_input(event)
		if hud_viewport.is_input_handled() or Hud.wants_input(seat):
			get_viewport().set_input_as_handled()
			return
	elif seat == 0 and Hud.wants_input(0):
		return
	var scale_to_game := Vector2(game_viewport.size) / game_view.size
	var to_game := Transform2D(Vector2(scale_to_game.x, 0), Vector2(0, scale_to_game.y),
		-game_view.position * scale_to_game)
	game_viewport.push_input(event.xformed_by(to_game), true)
	get_viewport().set_input_as_handled()  # the HUD doesn't need them right now
