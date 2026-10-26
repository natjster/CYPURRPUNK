extends Node
## MEOW-CITY 1999 — every player setting in one place (screen, sound, mouse, effects).
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
var fullscreen: bool = false
## Window size as a multiple of the 320x240 game picture (4 = 1280x960).
var window_scale: int = 4
var vsync: bool = true
# Audio (0.0 = silent, 1.0 = full)
var master_volume: float = 0.8
var music_volume: float = 0.8
var sfx_volume: float = 0.8
# Controls
## Multiplies the cat's mouse_sensitivity (1.0 = normal).
var mouse_speed: float = 1.0
var invert_y: bool = false
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
	["display", "fullscreen"], ["display", "window_scale"], ["display", "vsync"],
	["audio", "master_volume"], ["audio", "music_volume"], ["audio", "sfx_volume"],
	["controls", "mouse_speed"], ["controls", "invert_y"],
	["effects", "field_of_view"], ["effects", "crt_strength"], ["effects", "ps1_wobble"],
	["effects", "volumetric_fog"],
]

## Sound buses. Future sounds should pick "Music" or "SFX" on their AudioStreamPlayer
## (Inspector > Bus) so the volume sliders work for them.
const BUSES: Array[String] = ["Music", "SFX"]

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
func new_cat() -> Dictionary:
	var cat := {
		"id": "cat_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 10000],
		"name": "",
		"look": CatLook.default_look(),
	}
	cats.append(cat)
	select_cat(cat.id)
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
	var screen_key := "%s/%d" % [fullscreen, window_scale]
	if screen_key != _applied_screen and DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor():
		_applied_screen = screen_key
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var wanted := Vector2i(320, 240) * window_scale
			if DisplayServer.window_get_size() != wanted:
				DisplayServer.window_set_size(wanted)
				# Keep the window centred on the screen it's on.
				var screen := DisplayServer.window_get_current_screen()
				var area := DisplayServer.screen_get_usable_rect(screen)
				DisplayServer.window_set_position(area.position + (area.size - wanted) / 2)
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


## The biggest window size that still fits this screen (used by the settings menu).
func max_window_scale() -> int:
	if DisplayServer.get_name() == "headless":
		return 6
	var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	return clampi(mini(area.size.x / 320, area.size.y / 240), 1, 8)


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
