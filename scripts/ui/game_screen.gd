class_name GameScreen
extends Control
## CYPURRPUNK — the very top scene (scenes/game_screen.tscn, the one Godot starts).
## It puts two pictures on your monitor:
##
##   1. The GAME: the whole of scenes/main.tscn (the 3D city and the CRT + dither look) is
##      drawn inside GameView/GameViewport at PS1 size, 240 pixels tall, then blown up to fill
##      the window with sharp, blocky pixels.
##   2. The MENUS (start menu, pause, settings, MY CAT: the PS1Overlay node in main.tscn) are
##      lifted out of the game picture when the game starts and drawn ON TOP in MenuView, with
##      the same 320x240 layout (scripts/ui/ps1_overlay.gd).
##   3. The HUD (scenes/ui/hud.tscn, scripts/ui/hud.gd): cash, HP, prompts, crosshair... drawn
##      ON TOP, each player's in its own SubViewport.
##
## THE TWO UI LOOKS (SETTINGS > DISPLAY > UI STYLE, Settings.modern_ui):
##   PS1 (default): the menus and HUDs are drawn just as small as the game picture and blown up
##      with blocky pixels. One CRT effect (CRTOverlay) then covers EVERYTHING together: the 3D
##      world, HUD and menus, like a real PS1 on a TV. The 3D-only CRT is switched off.
##   MODERN: the menus and HUDs are drawn at your monitor's real resolution, so they're crisp, and
##      only the 3D world gets the CRT effect (the 3D-only one; CRTOverlay is hidden).
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
## Each player's screen is drawn with as many pixel ROWS as one full screen (240), so it isn't
## blurrier than playing alone: a half-height screen is drawn at double detail, then shrunk to
## fit (split_full_detail; turn it off for chunky PS1-style half-resolution screens).
## Every player also gets their OWN HUD (cash, HP, prompts, inventory, talk box) on their own
## screen, shrunk to fit (hud_scale_for). Player 1's is the HUD node from game_screen.tscn;
## players 2-4's are copies of scenes/ui/hud.tscn made here. Each sits in its own SubViewport
## ("Hud1".."Hud4"), so each player has their own highlighted button. Each player's presses go
## to their HUD first.
##
## Node tree:
##   GameScreen (this script)
##   ├── Bars                <- black behind everything (the border you see in 4:3 / SHARP mode)
##   ├── GameView            <- shows player 1's game picture, blown up
##   │   └── GameViewport    <- the 320x240-ish "PS1 screen" the game is drawn into
##   │       └── Main        <- scenes/main.tscn (the actual game)
##   │           └── CRT     <- made by this script: the CRT + dither effect (ColorDepthDither),
##   │                          moved here out of PS1Overlay
##   ├── GameView2..4        <- made by this script: players 2-4 (hidden until they join)
##   │   ├── GameViewport > Camera3D       <- their 3D view
##   │   └── Post > Dither                 <- the CRT look on top (what you see)
##   ├── JoinHint            <- made by this script: "PRESS START TO JOIN" in an empty corner
##   ├── MenuView            <- made by this script: the menus, over the whole game picture
##   │   └── MenuViewport > PS1Overlay   <- moved here from main.tscn (Lobby, PauseMenu, ...)
##   ├── Hud1..4             <- made by this script: each player's HUD. Player 1's HUD node is
##   │   └── Viewport > HUD     moved here from game_screen.tscn (Hud.seat = 0..3)
##   └── CRTOverlay          <- made by this script: the CRT + dither over everything (PS1 look)
##
## The size settings (SETTINGS > DISPLAY): see pixel_perfect and widescreen in scripts/settings.gd.
## This script also passes your mouse and keyboard on to the menus, then the game inside GameViewport.

## The one game screen (GameScreen.instance).
static var instance: GameScreen

## The game picture is always this many pixels tall (the PS1 look).
@export var game_height: int = 240
## ...and at least this many pixels wide (4:3). With ASPECT = WIDE it grows wider to fill the window.
@export var design_width: int = 320
## Split screen: the black line between players' screens, in game pixels (0 = none).
@export var divider: int = 1
## Split screen: ON = every player's screen gets the same detail as one full screen (240 pixel
## rows: a half-height screen is drawn at double resolution). OFF = each screen is just its part
## of the 240-row picture (chunkier, a bit faster).
@export var split_full_detail: bool = true
## Split screen: how big a player's HUD is on a smaller screen, compared to "just shrink it to
## fit" (1.0). Higher = bigger text (crowded), lower = smaller. Never bigger than full size.
@export var split_hud_boost: float = 1.25
## One player, PS1 UI look: how much bigger the whole HUD is drawn, so small text stays readable at
## 240 pixel rows. Up to about 1.33: above that the inventory stops fitting on a 4:3 screen.
@export var ps1_hud_scale: float = 1.33

@onready var hud: Hud = $HUD
@onready var game_view: TextureRect = $GameView
@onready var game_viewport: SubViewport = $GameView/GameViewport

## Players 2-4's screens, in order: {"view": TextureRect, "viewport": SubViewport (3D),
## "post": SubViewport (CRT look), "camera": Camera3D, "rain": GPUParticles3D, "dither": ColorRect,
## "seat": which seat it shows (-1 = hidden)}.
var _extra_panes: Array[Dictionary] = []
var _join_hint: Label
## Menus and the stick: which way each stick is pushed right now ("ui_down"..., "" = middle), so
## one push moves a menu highlight ONE step. Key = "device:axis". (_stick_pushed_again)
var _menu_stick: Dictionary = {}
## Every player's HUD, by seat (0 = player 1): {"view": TextureRect, "viewport": SubViewport,
## "hud": Hud}.
var _seat_huds: Array = []
## What the screen was last laid out for, so it's only re-done when something changes.
var _layout_key: String = ""
## The menus (_build_menu_view): the picture on screen, the viewport they're drawn in,
## and the PS1Overlay node (from main.tscn) that holds them.
var menu_view: TextureRect
var menu_viewport: SubViewport
var _menus  # PS1Overlay (scripts/ui/ps1_overlay.gd)
## Player 1's 3D-only CRT effect (ColorDepthDither from main.tscn). Off in the PS1 UI look.
var _game_dither: ColorRect
## The CRT effect over the whole picture: game, HUD and menus. On in the PS1 UI look.
var _crt_overlay: ColorRect


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	process_priority = 100  # run after the cats have moved their cameras this frame
	game_view.texture = game_viewport.get_texture()
	_build_extra_panes()
	_build_menu_view()
	_build_huds()
	_build_crt_overlay()
	Settings.changed.connect(_copy_crt_settings)
	_copy_crt_settings()
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
	_join_hint = Label.new()
	_join_hint.name = "JoinHint"
	_join_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_join_hint.add_theme_font_size_override("font_size", 28)
	_join_hint.add_theme_color_override("font_color", Seats.color(3))  # player 4's colour
	_join_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_join_hint.hide()
	add_child(_join_hint)


## The menus: take PS1Overlay (start menu, pause, settings, MY CAT) out of the game picture and
## draw it in its own viewport on top. It keeps its 320x240-ish layout (size_2d_override) in both
## UI looks; _fit decides how many real pixels it's drawn with.
## The 3D-only CRT + dither effect is left behind in the game picture (a new "CRT" CanvasLayer).
func _build_menu_view() -> void:
	var main := Game.instance
	_menus = main.get_node("PS1Overlay")
	var crt := CanvasLayer.new()
	crt.name = "CRT"
	crt.layer = _menus.layer
	main.add_child(crt)
	_game_dither = main.get_node("PS1Overlay/ColorDepthDither")
	_game_dither.reparent(crt, false)

	menu_view = TextureRect.new()
	menu_view.name = "MenuView"
	menu_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # blocky pixels in the PS1 UI look
	menu_view.material = _see_through_picture()
	add_child(menu_view)
	menu_viewport = SubViewport.new()
	menu_viewport.name = "MenuViewport"
	menu_viewport.transparent_bg = true  # see the game through it
	menu_viewport.size_2d_override_stretch = true  # laid out in game pixels, whatever size it's drawn
	menu_viewport.gui_embed_subwindows = true
	menu_view.add_child(menu_viewport)
	menu_view.texture = menu_viewport.get_texture()
	_menus.reparent(menu_viewport, false)


## Every player's HUD, each in its own SubViewport (their own highlighted button). Player 1's is
## the HUD node from game_screen.tscn, moved in here; players 2-4's are new copies of hud.tscn.
## They're drawn above the menus, like the HUD always was.
func _build_huds() -> void:
	for seat in PlayerId.MAX_LOCAL:
		var hud_view := TextureRect.new()
		hud_view.name = "Hud%d" % (seat + 1)
		hud_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hud_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # blocky pixels in the PS1 UI look
		hud_view.material = _see_through_picture()
		hud_view.hide()
		add_child(hud_view)
		var hud_viewport := SubViewport.new()
		hud_viewport.name = "Viewport"
		hud_viewport.transparent_bg = true
		hud_viewport.size_2d_override_stretch = true  # laid out in HUD units, whatever size it's drawn
		hud_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		hud_viewport.gui_embed_subwindows = true
		hud_view.add_child(hud_viewport)
		hud_view.texture = hud_viewport.get_texture()
		var seat_hud: Hud = hud
		if seat == 0:
			hud.reparent(hud_viewport, false)
		else:
			seat_hud = preload("res://scenes/ui/hud.tscn").instantiate() as Hud
			seat_hud.seat = seat  # before it enters the tree: it registers as that player's HUD
			hud_viewport.add_child(seat_hud)
		_seat_huds.append({"view": hud_view, "viewport": hud_viewport, "hud": seat_hud})


## A see-through viewport's soft edges are already darkened by their own see-through-ness. This
## stops them being darkened a second time when shown (at 240 rows, small text is nearly all edge).
func _see_through_picture() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	return material


## The CRT + 15-bit dither over the whole picture (the PS1 UI look). It's the last thing drawn, so
## it reads everything under it from the screen. Uses a copy of player 1's material, kept in step
## by _copy_crt_settings, and _fit tells it where the picture is on the monitor.
func _build_crt_overlay() -> void:
	_crt_overlay = ColorRect.new()
	_crt_overlay.name = "CRTOverlay"
	_crt_overlay.material = Game.instance.crt_material.duplicate()
	_crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crt_overlay)


## Every frame: re-cut the screen if players joined / left or a menu opened, and point the
## extra screens' cameras where their players' cats are looking.
func _process(_delta: float) -> void:
	var seats := shown_seats()
	var key := "%s %s" % [seats, Settings.split_side_by_side]
	if key != _layout_key:
		_fit()
	_follow_cameras()
	# The menu layer is only drawn while a menu is showing (it still hears keys when hidden,
	# so Esc can open the pause menu).
	var menus_shown: bool = _menus.any_menu_visible()
	menu_view.visible = menus_shown
	menu_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if menus_shown else SubViewport.UPDATE_DISABLED


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
	# Which UI look: see THE TWO UI LOOKS at the top of this script.
	var ps1_ui := not Settings.modern_ui
	# Cut it into one screen per player (game pixels): player 1 first.
	var rects := _pane_rects(seats.size(), Vector2i(width, game_height))
	_place(game_view, game_viewport, rects[0], corner, zoom, units_per_pixel)
	for i in _extra_panes.size():
		var pane: Dictionary = _extra_panes[i]
		var shown := i + 1 < seats.size()
		pane.seat = seats[i + 1] if shown else -1
		pane.view.visible = shown
		pane.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
		# PS1 UI look: show the raw 3D picture, CRTOverlay does the CRT. Modern: the CRT'd "Post" one.
		pane.post.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown and not ps1_ui else SubViewport.UPDATE_DISABLED
		pane.view.texture = pane.viewport.get_texture() if ps1_ui else pane.post.get_texture()
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

	# The menus cover the whole game picture (all players' screens): laid out in game pixels
	# (e.g. 320x240). PS1 look: drawn with that few pixels too. Modern: real pixels, so sharp.
	menu_view.position = corner * units_per_pixel
	menu_view.size = whole * zoom * units_per_pixel
	menu_viewport.size = Vector2i(whole) if ps1_ui else Vector2i((whole * zoom).round())
	menu_viewport.size_2d_override = Vector2i(whole)  # laid out in game pixels
	_menus.fit_columns()

	# One CRT effect at a time: over everything (PS1 look), or on the 3D world only (modern).
	_game_dither.visible = not ps1_ui
	_crt_overlay.visible = ps1_ui
	_crt_overlay.position = menu_view.position
	_crt_overlay.size = menu_view.size
	var overlay := _crt_overlay.material as ShaderMaterial
	overlay.set_shader_parameter("pixel_scale", zoom)
	overlay.set_shader_parameter("area_offset", corner / window)
	overlay.set_shader_parameter("area_scale", whole * zoom / window)

	# Every player's HUD sits on their own screen, shrunk to fit. It's always laid out in HUD units.
	# PS1 look: drawn with the same pixels as that player's game picture. Modern: real pixels.
	for seat in PlayerId.MAX_LOCAL:
		var seat_hud: Dictionary = _seat_huds[seat]
		var pane_index := seats.find(seat)
		var shown := pane_index >= 0
		seat_hud.view.visible = shown
		seat_hud.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
		if not shown:
			continue
		var pane_view: TextureRect = game_view if pane_index == 0 else _extra_panes[pane_index - 1].view
		var pane_viewport: SubViewport = game_viewport if pane_index == 0 else _extra_panes[pane_index - 1].viewport
		seat_hud.view.position = pane_view.position
		seat_hud.view.size = pane_view.size
		seat_hud.viewport.size = pane_viewport.size if ps1_ui else Vector2i((pane_view.size / units_per_pixel).round())
		seat_hud.viewport.size_2d_override = Vector2i(pane_view.size.round())  # laid out in HUD units
		(seat_hud.hud as Hud).fit_to(Rect2(Vector2.ZERO, pane_view.size), hud_scale_for(pane_view.size))


## How big a HUD should be on a screen this size (HUD units): 1 = full size (a 720-tall screen),
## smaller for a half or quarter screen, so the cash, HP and windows still fit.
func hud_scale_for(screen_units: Vector2) -> float:
	var fit := minf(screen_units.y / 720.0, screen_units.x / 960.0)
	if not Settings.modern_ui and shown_seats().size() == 1:
		return fit * ps1_hud_scale
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


## Size one screen's viewport and put its picture on the monitor. rect = where it goes in the
## whole 240-tall picture (game pixels).
func _place(view: TextureRect, viewport: SubViewport, rect: Rect2i, corner: Vector2, zoom: float, units_per_pixel: float) -> void:
	# How much more detail this screen gets: 1 = normal; 2 = a half-height split screen drawn at
	# double resolution, so it has as many pixel rows as one full screen.
	var detail := 1.0
	if split_full_detail:
		detail = maxf(1.0, roundf(float(game_height) / rect.size.y))
	# How many monitor pixels one of its pixels becomes. SHARP (pixel perfect) keeps that a whole
	# number, so every pixel stays the same size.
	var pixel := zoom / detail
	if Settings.pixel_perfect:
		pixel = maxf(1.0, floorf(pixel))
	var render_size := Vector2i((Vector2(rect.size) * zoom / pixel).round())
	if viewport.size != render_size:
		viewport.size = render_size
	view.position = (corner + Vector2(rect.position) * zoom) * units_per_pixel
	view.size = Vector2(rect.size) * zoom * units_per_pixel


## CRT TV LOOK changed (game.gd sets player 1's CRT material): copy it to players 2-4's screens
## and the overlay.
func _copy_crt_settings() -> void:
	var source: ShaderMaterial = Game.instance.crt_material
	var targets: Array[ShaderMaterial] = [_crt_overlay.material]
	for pane in _extra_panes:
		targets.append(pane.dither.material)
	for target in targets:
		for param in Game.CRT_PARAMS:
			target.set_shader_parameter(param, source.get_shader_parameter(param))


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
## Each player's presses go to THEIR HUD first (their inventory and talk box), and only on to the
## game if their HUD didn't want them. (Player 1's mouse only goes there while a HUD window is
## open: otherwise it belongs to the menus and the game.)
func _input(event: InputEvent) -> void:
	var seat := Seats.seat_of_event(event)
	if seat == -1:
		# A controller with no seat (co-op): it can't press anyone's buttons. (Its START to join
		# was already handled by scripts/seats.gd.)
		get_viewport().set_input_as_handled()
		return
	if Hud.menu_open() and seat != _menu_driver():
		get_viewport().set_input_as_handled()  # a full-screen menu: only the player who opened it drives it
		return
	if _seat_huds[seat].view.visible and (Hud.wants_input(seat) or not event is InputEventMouse):
		var hud_view: TextureRect = _seat_huds[seat].view
		var hud_viewport: SubViewport = _seat_huds[seat].viewport
		hud_viewport.push_input(event.xformed_by(_to_local(hud_view, Vector2(hud_viewport.size_2d_override))), true)
		if hud_viewport.is_input_handled() or Hud.wants_input(seat):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadMotion and _in_menus() and not _stick_pushed_again(event):
		# A held stick sends a stream of "still pushed" messages; Godot's menus would treat each
		# one as a new press and race the highlight (or a cat's colour) along. Menus get only
		# the moment it's pushed. (Walking and looking read the stick directly: not affected.)
		get_viewport().set_input_as_handled()
		return
	# The menus first (start menu, pause, settings, MY CAT): if one of them used the press
	# (a button, Esc...), the game doesn't get it too.
	menu_viewport.push_input(event.xformed_by(_to_local(menu_view, Vector2(menu_viewport.size_2d_override))), true)
	if not menu_viewport.is_input_handled():
		game_viewport.push_input(event.xformed_by(_to_local(game_view, Vector2(game_viewport.size))), true)
	get_viewport().set_input_as_handled()


## Turns a mouse position on the monitor into a position inside a picture (a TextureRect)
## that shows a viewport laid out this big.
func _to_local(view: TextureRect, laid_out_size: Vector2) -> Transform2D:
	var scale_to := laid_out_size / view.size
	return Transform2D(Vector2(scale_to.x, 0), Vector2(0, scale_to.y), -view.position * scale_to)


## Which player drives the full-screen menus right now: player 1 (the pause menu and settings),
## or the couch player whose MY CAT screen is open (scripts/ui/cat_creator.gd).
func _menu_driver() -> int:
	var creator := Game.instance.cat_creator
	return creator.seat if creator.visible else 0


## Is a menu up in the game picture (the start menu, or pause / settings / MY CAT)?
func _in_menus() -> bool:
	var game := Game.instance
	return game == null or not is_instance_valid(game) or not game.pause_menu.enabled or Hud.menu_open()


## A stick message for the menus: true only at the moment the stick is pushed a new way
## (up / down / left / right), not while it's held there.
func _stick_pushed_again(event: InputEventJoypadMotion) -> bool:
	var key := "%d:%d" % [event.device, event.axis]
	var now := ""
	for action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		if event.is_action_pressed(action):
			now = action
	var before: String = _menu_stick.get(key, "")
	_menu_stick[key] = now
	return now != "" and now != before
