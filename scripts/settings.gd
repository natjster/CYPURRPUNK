extends Node
## CYPURRPUNK — every player setting in one place (screen, sound, mouse, controller, effects).
## Loaded automatically on startup (it's an Autoload named "Settings").
##
## Other scripts just read the values, e.g. Settings.mouse_speed, and listen to the
## "changed" signal if they need to react when the player changes something.
## Everything is saved to user://settings.cfg (on Windows: %APPDATA%\MeowCity1999\settings.cfg).
##
## To ADD a setting:
##   1. add a variable below with its default value,
##   2. add it to SAVED (so it's saved to disk),
##   3. use it in apply() (or wherever it matters),
##   4. add a row for it in scripts/ui/settings_menu.gd (ROWS list).

## Fired after any setting changes (and once after loading).
signal changed

const SAVE_PATH: String = "user://settings.cfg"

# --- The settings and their defaults ---
# Player: your cats (made in the CHOOSE YOUR CAT screen, scripts/ui/cat_creator.gd)
## Every cat you've made: [{"id": "cat_1761400000_42", "name": "WHISKERS", "look": {...}}].
## "look" is a CatLook dictionary (scripts/cat/cat_look.gd). Each cat also has its OWN saved
## cash and stash, kept by player_profile.gd in a file named after its "id".
## Use the functions under "Your cats" below rather than changing this list directly.
var cats: Array = []
## The id of the cat you play as.
var current_cat_id: String = ""
# Display
## Fullscreen always uses your monitor's own (biggest) resolution.
var fullscreen: bool = false
## Window size in pixels when NOT fullscreen (pick from resolution_choices()).
## The game itself is always drawn at 320x240 and then blown up to fill this
## (scripts/ui/game_screen.gd); the HUD on top is drawn at this full size, so it stays sharp.
var resolution: Vector2i = Vector2i(1280, 960)
## How the 320x240 picture is blown up to fill the screen:
## true  = SHARP: whole-number zoom only (every game pixel is the same size), may leave a black border.
## false = FILL:  zooms as big as fits (fills the screen height), some pixel rows a hair bigger.
var pixel_perfect: bool = true
## true  = WIDE: the game stays 240 pixels tall but gets wider to fill widescreen / ultrawide
##         monitors (e.g. 573x240 on 21:9) - you see more of the city to the sides.
## false = 4:3: always exactly 320x240, with black bars at the sides on wide monitors.
var widescreen: bool = true
## false = PS1: HUD and menus are chunky low-res pixels and the CRT effect covers everything.
## true  = MODERN: HUD and menus are crisp at full resolution; only the 3D world gets the CRT effect.
var modern_ui: bool = false
var vsync: bool = true
## Split screen with 2 players on one computer: true = side by side, false = top + bottom.
var split_side_by_side: bool = true
# Audio (0.0 = silent, 1.0 = full)
var master_volume: float = 0.8
var music_volume: float = 0.8
var sfx_volume: float = 0.8
# Controls
## Multiplies the cat's mouse_sensitivity (1.0 = normal).
var mouse_speed: float = 1.0
var invert_y: bool = false
## Multiplies how fast the right stick turns the camera (1.0 = normal).
var stick_speed: float = 1.0
## true = push the right stick up to look down.
var invert_stick_y: bool = false
## Controller rumble (shakes when you get hit, shoot, get knocked out...).
var rumble: bool = true
# Camera / effects
var field_of_view: float = 70.0
## How strong the curved-TV look is (0 = off, 1 = full). Colour dithering always stays.
var crt_strength: float = 1.0
## PS1 vertex wobble + texture warping. Off = steadier picture (comfort option).
var ps1_wobble: bool = true
var volumetric_fog: bool = true

## Which variables get saved: [section in the file, variable name].
const SAVED: Array = [
	["player", "cats"], ["player", "current_cat_id"],
	["display", "fullscreen"], ["display", "resolution"], ["display", "pixel_perfect"], ["display", "widescreen"],
	["display", "vsync"], ["display", "split_side_by_side"], ["display", "modern_ui"],
	["audio", "master_volume"], ["audio", "music_volume"], ["audio", "sfx_volume"],
	["controls", "mouse_speed"], ["controls", "invert_y"],
	["controls", "stick_speed"], ["controls", "invert_stick_y"], ["controls", "rumble"],
	["effects", "field_of_view"], ["effects", "crt_strength"], ["effects", "ps1_wobble"],
	["effects", "volumetric_fog"],
]

## Sound buses. Sounds played through the Sound autoload (scripts/sound.gd) pick the right one
## by themselves; a hand-placed AudioStreamPlayer should pick "Music" or "SFX" (Inspector > Bus)
## so the volume sliders work for it.
const BUSES: Array[String] = ["Music", "SFX"]

## Window sizes offered in SETTINGS > DISPLAY > RESOLUTION (only the ones that fit your monitor
## are shown, plus the monitor's own size). Add more here if you like: Vector2i(width, height).
const COMMON_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(640, 480), Vector2i(800, 600), Vector2i(960, 720), Vector2i(1024, 768),
	Vector2i(1280, 720), Vector2i(1280, 960), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1600, 1200), Vector2i(1920, 1080), Vector2i(1920, 1440), Vector2i(2560, 1080),
	Vector2i(2560, 1440), Vector2i(2880, 2160), Vector2i(3440, 1440), Vector2i(3840, 2160),
]

## A fresh copy of the defaults, used by "RESET".
var _defaults: Dictionary = {}
## The screen mode last pushed to the window (see apply()).
var _applied_screen: String = ""
## True when started by the DevCapture test tool (see _ready).
var _is_test_run: bool = false


func _ready() -> void:
	for entry in SAVED:
		_defaults[entry[1]] = get(entry[1])
	_make_audio_buses()
	# Test runs (DevCapture, "--capture=...") use the defaults and never save, so they
	# can't change your real settings or cat name, and every test looks the same.
	for arg in OS.get_cmdline_user_args():
		_is_test_run = _is_test_run or arg.begins_with("--capture")
	if not _is_test_run:
		load_settings()
	apply()


## Change one setting, apply it straight away and save.
func set_value(setting: String, value: Variant) -> void:
	set(setting, value)
	apply()
	save_settings()


## Put every setting back to its default (your cats are kept).
func reset_to_defaults() -> void:
	for setting in _defaults:
		if setting != "cats" and setting != "current_cat_id":
			set(setting, _defaults[setting])
	apply()
	save_settings()


# --- Your cats ---

## The cat you play as ({"id", "name", "look"}), or {} if you haven't made one yet.
func current_cat() -> Dictionary:
	for cat in cats:
		if cat.get("id", "") == current_cat_id:
			return cat
	return {}


## Play as another of your cats.
func select_cat(id: String) -> void:
	current_cat_id = id
	apply()
	save_settings()


## Make a brand-new cat (no name yet, default look) and play as it. Returns it.
## select = false: just add it to your cats (a couch player who joins in plays it, scripts/seats.gd),
## optionally with a name and look.
func new_cat(select: bool = true, cat_name: String = "", look: Dictionary = {}) -> Dictionary:
	var cat := {
		"id": "cat_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 10000],
		"name": cat_name,
		"look": look if not look.is_empty() else CatLook.default_look(),
	}
	cats.append(cat)
	if select:
		select_cat(cat.id)
	else:
		save_settings()
	return cat


## Change the current cat, e.g. update_current_cat({"name": "WHISKERS"}) or {"look": look}.
## Makes a cat first if you have none.
func update_current_cat(changes: Dictionary) -> void:
	var cat := current_cat()
	if cat.is_empty():
		cat = new_cat()
	cat.merge(changes, true)  # changes the cat inside the list
	apply()
	save_settings()


## Delete one of your cats (its saved cash + stash too: player_profile.gd forget_cat()).
func delete_cat(id: String) -> void:
	for i in cats.size():
		if cats[i].get("id", "") == id:
			cats.remove_at(i)
			break
	if current_cat_id == id:
		current_cat_id = cats[0].id if not cats.is_empty() else ""
	apply()
	save_settings()


func save_settings() -> void:
	if _is_test_run:
		return
	var config := ConfigFile.new()
	for entry in SAVED:
		config.set_value(entry[0], entry[1], get(entry[1]))
	config.save(SAVE_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return  # first time playing: keep the defaults
	for entry in SAVED:
		var value: Variant = config.get_value(entry[0], entry[1], get(entry[1]))
		if typeof(value) == typeof(get(entry[1])):  # ignore broken / old values
			set(entry[1], value)
	# Older versions saved the window size as "4x" ([display] window_scale) instead of a resolution.
	if not config.has_section_key("display", "resolution") and config.has_section_key("display", "window_scale"):
		resolution = Vector2i(320, 240) * clampi(int(config.get_value("display", "window_scale", 4)), 1, 12)
	# Older versions had ONE cat: a name ([player] player_name, or even older [player] name)
	# and a look ([player] cat_look). Turn it into your first cat. Its id is the name its saved
	# cash + stash file already has (profiles/<name>.cfg), so that progress comes along too.
	var old_name: String = str(config.get_value("player", "player_name", config.get_value("player", "name", "")))
	var old_look: Variant = config.get_value("player", "cat_look", {})
	if cats.is_empty() and (old_name != "" or (old_look is Dictionary and not old_look.is_empty())):
		var id := old_name.validate_filename().to_lower()
		cats.append({"id": id if id != "" else "cat", "name": old_name, "look": old_look if old_look is Dictionary else {}})
	if current_cat().is_empty() and not cats.is_empty():
		current_cat_id = cats[0].get("id", "")


## Push the settings into the engine. Scene-specific ones (CRT, fog) are applied by
## game.gd, which listens to the "changed" signal.
func apply() -> void:
	# Screen. Skipped when the game runs inside the Godot editor's own game tab,
	# which can't be resized or made fullscreen.
	# Only touches the window when the screen settings actually changed, so changing
	# e.g. the volume doesn't undo a window you resized by hand.
	# Also skipped on phones (Android): the game always fills the whole screen there.
	var screen_key := "%s/%s" % [fullscreen, resolution]
	if screen_key != _applied_screen and DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor() \
			and not OS.has_feature("mobile"):
		_applied_screen = screen_key
		if fullscreen:
			# Godot's fullscreen fills the monitor at its own native resolution.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			# Never bigger than the monitor (e.g. a saved size from a bigger screen).
			var wanted := resolution.min(DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()))
			if DisplayServer.window_get_size() != wanted:
				DisplayServer.window_set_size(wanted)
				# Keep the window centred on the screen it's on.
				var screen := DisplayServer.window_get_current_screen()
				var area := DisplayServer.screen_get_usable_rect(screen)
				# Keeps the title bar on screen if the window is as big as the monitor.
				DisplayServer.window_set_position(area.position + ((area.size - wanted) / 2).max(Vector2i.ZERO))
	# pixel_perfect and widescreen (how the 320x240 picture is zoomed up to the window) are used
	# by scripts/ui/game_screen.gd, which listens to the "changed" signal below.
	# (Menus stay in a 320-wide middle column either way: scripts/ui/ps1_overlay.gd.)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

	# Sound
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)

	# PS1 wobble lives in a "global shader parameter" every PS1 material reads
	# (see psx_wobble in shaders/psx_lit.gdshader and Project Settings > Shader Globals).
	RenderingServer.global_shader_parameter_set("psx_wobble", 1.0 if ps1_wobble else 0.0)

	changed.emit()


## Your monitor's own (biggest) resolution, e.g. 2560x1440.
func monitor_resolution() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i(1920, 1080)
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())


## The window sizes the RESOLUTION row offers, smallest first: every COMMON_RESOLUTIONS size that
## fits on this monitor, plus the monitor's own size (the biggest). Used by the settings menu.
func resolution_choices() -> Array[Vector2i]:
	var monitor := monitor_resolution()
	var list: Array[Vector2i] = []
	for size in COMMON_RESOLUTIONS:
		if size.x <= monitor.x and size.y <= monitor.y and size != monitor:
			list.append(size)
	list.append(monitor)
	return list


func _make_audio_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))
