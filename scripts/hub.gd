class_name UndergroundHub
extends Node3D
## CYPURRPUNK — THE SEWERS: the underground hub where every cat starts.
## Attach to the "Hub" node in main.tscn. That node sits 200 m BELOW the city
## (position 0, -200, 0), so the hub and the city are one world and one multiplayer game:
## going "up top" or "back down" is just moving your cat between the two.
##
## How it plays:
##   - Joining or hosting puts your cat here, at the south end of the tunnel.
##   - It's a SAFE ZONE: guns don't fire down here (see ItemManager._use_held_items).
##   - Walk up to DON CATLEONE (the boss cat at the north end) and press E to talk.
##     Pick "SEND ME UP TOP" and he sends you into the city (deploy()).
##   - COMRADE WHISKERS runs THE BLACK MARKITTEN on the west wall: the only place to get
##     gear (guns, catnip, catdip). Pay with the cash you earn extracting fish.
##     He's a Shopkeeper NPC (scripts/npcs/shopkeeper.gd); his shop is built in _build_shop().
##   - In the city, climb down the EXIT manhole once it opens (fish_heist.gd): your loot is
##     cashed in and you're brought back down here (return_cat()).
##
## The tunnel is built from code in _ready() (like the city), but it is always the SAME:
## it doesn't use the city seed or any randomness, so every computer builds it identically.
## Don Catleone himself is a normal NPC scene placed under this node in main.tscn
## (scenes/npcs/don_catleone.tscn, built on the NPC framework in scripts/npcs/npc.gd),
## so you can move him in the editor. Talking and the "[E] TALK" prompt are handled there.
##
## Mood: while YOUR camera is down here, the rain switches off and the fog turns sewer-green
## on your screen only (_update_mood). Back up top, the night city returns.
## Split screen: each player's screen gets the fog of where ITS camera is (environment_for),
## the moon shines while anyone on this computer is up top, and the music follows them too.

## The one hub, so cats, items and the heist can find it (UndergroundHub.instance).
static var instance: UndergroundHub

## Anything below this height is "in the hub" (the city floor is at 0, the hub at -200).
const DEPTH_LINE: float = -100.0

@export_group("Size")
## Half the tunnel's width (metres, east-west).
@export var half_width: float = 14.0
## Half the tunnel's length (metres, north-south).
@export var half_length: float = 20.0
## Floor to ceiling (metres).
@export var height: float = 7.0
## Width of the sewage channel running down the middle.
@export var channel_width: float = 4.0

@export_group("Spawning")
## Where new cats appear, relative to the Hub node (south end, west walkway).
@export var spawn_spot: Vector3 = Vector3(-8, 0, 14)
## Where Don Catleone sends you in the city (the centre crossroads).
@export var surface_spot: Vector3 = Vector3(0, 0, 4)

@export_group("Stash")
## Where you stand to use THE STASH (the lockers on the east wall), relative to the Hub node.
## The lockers are built just east of this spot, against the wall.
@export var stash_spot: Vector3 = Vector3(11.0, 0, -9.0)
## How close (metres) you must be to the stash spot to open it.
@export var stash_radius: float = 2.5

@export_group("Mood")
## Fog and ambient colours while you're down here.
@export var sewer_fog_color: Color = Color(0.03, 0.07, 0.05)
@export var sewer_fog_albedo: Color = Color(0.55, 0.85, 0.65)
@export var sewer_ambient_color: Color = Color(0.35, 0.55, 0.45)
@export var sewer_ambient_energy: float = 0.6

@export_group("Music")
## Music down here and up top: file names in res://sounds/music/ (without .wav). "" = silence.
@export var hub_music: String = "hub"
@export var city_music: String = "city"
## Background loops: file names in res://sounds/ambience/. "" = silence.
@export var hub_ambience: String = "sewer"
@export var city_ambience: String = "rain"

## Don Catleone: only used here to decorate his corner (lights, crates).
@onready var npc: Npc = $DonCatleone
## Comrade Whiskers: only used here to build his shop, the Black Markitten, around him.
@onready var shopkeeper: Npc = $ComradeWhiskers
@onready var _environment: Environment = $"../WorldEnvironment".environment
@onready var _moonlight: Light3D = $"../Moonlight"
@onready var _rain: GPUParticles3D = $"../Rain"

## Glow colours of the boxes on the Black Markitten's shelves.
const SHOP_GOODS_COLORS: Array[Color] = [Color(1, 0.35, 0.7), Color(0.3, 1, 0.35), Color(0.3, 0.8, 1), Color(1, 0.8, 0.2)]
var _in_hub_view: bool = false
var _city_mood := {}  # the night-city fog/ambient values, to put back when you go up
## Split screen: a copy of the world's look with the OTHER mood (sewer while player 1 is up top,
## city while they're down here), for screens whose camera is somewhere else. Made when needed.
var _other_mood: Environment = null

var _concrete: ShaderMaterial
var _wall: ShaderMaterial
var _water: ShaderMaterial
var _metal: ShaderMaterial
var _cardboard: ShaderMaterial
var _crate: ShaderMaterial
var _neon: ShaderMaterial


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	_make_materials()
	_build_tunnel()
	_build_props()
	_city_mood = {
		"fog_light_color": _environment.fog_light_color,
		"volumetric_fog_albedo": _environment.volumetric_fog_albedo,
		"ambient_light_color": _environment.ambient_light_color,
		"ambient_light_energy": _environment.ambient_light_energy,
	}
	Settings.changed.connect(func(): _other_mood = null)  # e.g. VOLUMETRIC FOG changed: copy it again


## True if this spot is down in the hub (the safe zone).
static func is_in_hub(where: Vector3) -> bool:
	return where.y < DEPTH_LINE


# --- Moving cats between the hub and the city (called on the cat OWNER's computer) ---

## True if this cat is standing at THE STASH lockers (where the inventory shows your stash).
func near_stash(cat: CatPlayer) -> bool:
	return cat != null and cat.global_position.distance_to(to_global(stash_spot)) < stash_radius


## Where cat number n appears when it joins: rows of three on the walkway, facing Don.
## A spawn spot nobody else is standing on (up to 12 spots: 3 across, 4 rows), so 8 cats
## arriving at once don't land on top of each other.
func free_spawn_position(cat: CatPlayer) -> Vector3:
	for n in 12:
		var spot := spawn_position(n)
		var taken := false
		for other in Game.instance.players.get_children():
			if other != cat and (other as Node3D).global_position.distance_to(spot) < 1.0:
				taken = true
		if not taken:
			return spot
	return spawn_position(randi() % 12)


func spawn_position(n: int) -> Vector3:
	return to_global(spawn_spot + Vector3((n % 3) * 1.5 - 1.5, 0, (n / 3) * 1.5))


## "SEND ME UP TOP": pop the cat out of the ENTRY manhole in the city's centre crossroads.
func deploy(cat: CatPlayer) -> void:
	if FishHeist.instance.sealed:
		# The DEEP CLEAN is on up there: wait for the next district.
		Hud.show_message("DON CATLEONE: Hatch is sealed, kid. Sit tight - we're movin' to a new district.", 4.0, cat.slot)
		return
	var spread := Vector3(randf_range(-3, 3), 0, randf_range(0, 3))  # don't land on each other
	cat.teleport_to(surface_spot + spread, 0.0)
	print("[Hub] %s went up to the city" % cat.name)


## Extracted: back down the drain to the hub.
func return_cat(cat: CatPlayer) -> void:
	cat.teleport_to(free_spawn_position(cat), 0.0)
	print("[Hub] %s extracted back to the hub" % cat.name)


# --- Every frame: the mood (this computer only) ---

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var in_hub := camera != null and is_in_hub(camera.global_position)
	if in_hub != _in_hub_view:
		_in_hub_view = in_hub
		_update_mood(in_hub)
	# Split screen: is ANY of this computer's players up top? Then the moon shines (it lights
	# the whole world, so it can't be on for one screen only) and the city music plays.
	var anyone_up := not in_hub
	if GameScreen.instance != null:
		for view_camera in GameScreen.instance.view_cameras():
			anyone_up = anyone_up or not is_in_hub(view_camera.global_position)
	_moonlight.visible = anyone_up
	# Music + background sound (sounds/music/hub.wav or city.wav, sounds/ambience/sewer.wav or
	# rain.wav). Same track as before = nothing happens.
	Sound.play_music(city_music if anyone_up else hub_music)
	Sound.play_ambience(city_ambience if anyone_up else hub_ambience)


## Split screen: the look a screen whose camera is in the hub (or not) should use, or null for
## "the world's own look" (when it matches player 1's screen). game_screen.gd asks every frame.
func environment_for(in_hub: bool) -> Environment:
	if in_hub == _in_hub_view:
		return null
	if _other_mood == null:
		_other_mood = _environment.duplicate()
		_set_mood(_other_mood, in_hub)
	return _other_mood


## Underground: no rain, green fog. Up top: the night city as it was.
func _update_mood(in_hub: bool) -> void:
	_other_mood = null  # the other screens' copy flips too: make it again when needed
	_rain.visible = not in_hub
	_rain.emitting = not in_hub
	_set_mood(_environment, in_hub)


## Put the sewer (or city) fog and light colours into an Environment.
func _set_mood(environment: Environment, in_hub: bool) -> void:
	environment.fog_light_color = sewer_fog_color if in_hub else _city_mood.fog_light_color
	environment.volumetric_fog_albedo = sewer_fog_albedo if in_hub else _city_mood.volumetric_fog_albedo
	environment.ambient_light_color = sewer_ambient_color if in_hub else _city_mood.ambient_light_color
	environment.ambient_light_energy = sewer_ambient_energy if in_hub else _city_mood.ambient_light_energy


# --- Building the tunnel ---

func _make_materials() -> void:
	var asphalt := preload("res://textures/asphalt.png")
	_concrete = LevelKit.psx_material({"albedo_texture": asphalt, "albedo_color": Color(0.45, 0.5, 0.46), "world_uv": true, "world_uv_scale": 0.4, "specular": 0.4, "roughness": 0.4})
	_wall = LevelKit.psx_material({"albedo_texture": asphalt, "albedo_color": Color(0.3, 0.36, 0.33), "world_uv": true, "world_uv_scale": 0.3})
	_water = LevelKit.psx_material({"albedo_color": Color(0.03, 0.12, 0.09), "specular": 0.7, "roughness": 0.15, "emission_color": Color(0.2, 1, 0.6), "emission_energy": 0.04})
	_metal = LevelKit.psx_material({"albedo_color": Color(0.26, 0.28, 0.3), "specular": 0.5, "roughness": 0.4})
	_cardboard = LevelKit.psx_material({"albedo_color": Color(0.55, 0.4, 0.22)})
	_crate = LevelKit.psx_material({"albedo_texture": preload("res://textures/neon_grid.png"), "albedo_color": Color(0.3, 0.9, 0.8)})
	_neon = LevelKit.psx_material({"emission_color": Color.WHITE, "emission_energy": 5.0})


## Floor, sewage channel, walls and ceiling. No two surfaces overlap (they'd flicker).
func _build_tunnel() -> void:
	var w := half_width
	var l := half_length
	var c := channel_width * 0.5
	var walkway := w - c  # width of each walkway

	# Walkways either side of the channel: 1 m thick slabs with their top at floor level (0).
	LevelKit.add_box(self, Vector3(-(c + walkway * 0.5), -0.5, 0), Vector3(walkway, 1, l * 2), _concrete, true)
	LevelKit.add_box(self, Vector3(c + walkway * 0.5, -0.5, 0), Vector3(walkway, 1, l * 2), _concrete, true)
	# Channel bottom (1 m lower) and the murky water in it (looks only — you can wade in it).
	LevelKit.add_box(self, Vector3(0, -1.5, 0), Vector3(channel_width, 1, l * 2), _wall, true)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(channel_width, l * 2)
	plane.subdivide_width = 1
	plane.subdivide_depth = int(l * 2 / LevelKit.PIECE_SIZE)
	water.mesh = plane
	water.material_override = _water
	water.position = Vector3(0, -0.6, 0)
	add_child(water)
	# Two bridges over the channel (their tops line up with the walkways).
	for z in [-8.0, 8.0]:
		LevelKit.add_box(self, Vector3(0, -0.25, z), Vector3(channel_width, 0.5, 3), _concrete, true)
		for side in [-1.0, 1.0]:  # railings
			LevelKit.add_box(self, Vector3(0, 0.45, z + side * 1.4), Vector3(channel_width, 0.1, 0.1), _metal, false)

	# Walls and ceiling: 1 m thick boxes just outside the room.
	LevelKit.add_box(self, Vector3(-w - 0.5, height * 0.5 - 1, 0), Vector3(1, height + 2, l * 2 + 2), _wall, true)
	LevelKit.add_box(self, Vector3(w + 0.5, height * 0.5 - 1, 0), Vector3(1, height + 2, l * 2 + 2), _wall, true)
	LevelKit.add_box(self, Vector3(0, height * 0.5 - 1, -l - 0.5), Vector3(w * 2, height + 2, 1), _wall, true)
	LevelKit.add_box(self, Vector3(0, height * 0.5 - 1, l + 0.5), Vector3(w * 2, height + 2, 1), _wall, true)
	LevelKit.add_box(self, Vector3(0, height + 0.5, 0), Vector3(w * 2 + 2, 1, l * 2 + 2), _wall, true)

	# Big pipes along the ceiling, and ribs across it every 5 m (makes it read as a tunnel).
	for x in [-w + 1.2, w - 1.2]:
		var pipe := LevelKit.add_cylinder(self, Vector3(x, height - 1.0, 0), 0.45, l * 2, _metal)
		pipe.rotation.x = PI / 2
	for z in range(-int(l) + 5, int(l), 5):
		LevelKit.add_box(self, Vector3(0, height - 0.3, z), Vector3(w * 2, 0.6, 0.6), _wall, false)


func _build_props() -> void:
	var w := half_width
	var l := half_length

	# Hanging work lights down both walkways: warm pools of light in the green murk.
	for z in range(-int(l) + 4, int(l), 8):
		for x in [-w + 5.0, w - 5.0]:
			LevelKit.add_box(self, Vector3(x, height - 1.6, z), Vector3(0.05, 1.2, 0.05), _metal, false)  # cable
			var bulb := LevelKit.add_box(self, Vector3(x, height - 2.3, z), Vector3(0.3, 0.2, 0.3), _neon, false)
			bulb.set_instance_shader_parameter("instance_tint", Color(1, 0.7, 0.35))
			LevelKit.add_light(self, Vector3(x, height - 2.6, z), Color(1, 0.65, 0.32), 4.0, 12.0)
	# A cold cyan glow coming up off the water.
	for z in [-14.0, 0.0, 14.0]:
		LevelKit.add_light(self, Vector3(0, -0.2, z), Color(0.2, 1, 0.7), 1.2, 6.0)

	# A ladder up the north wall to a drain grate (where Don "sends you up").
	for side in [-0.5, 0.5]:
		LevelKit.add_box(self, Vector3(-w + 6 + side, height * 0.5, -l + 0.15), Vector3(0.08, height, 0.08), _metal, false)
	for y in range(1, int(height)):
		LevelKit.add_box(self, Vector3(-w + 6, y, -l + 0.15), Vector3(1.0, 0.06, 0.06), _metal, false)

	# Don Catleone's corner: a pink glow over his spot and crates for a desk.
	var don := npc.position
	LevelKit.add_light(self, Vector3(don.x, 3.0, don.z + 1.0), Color(1, 0.4, 0.8), 3.0, 8.0)
	LevelKit.add_light(self, Vector3(don.x - 1.0, 1.6, don.z + 2.0), Color(1, 0.85, 0.6), 2.0, 5.0)  # lights his face
	LevelKit.add_box(self, Vector3(don.x + 2.2, 0.45, don.z + 0.3), Vector3(1.4, 0.9, 0.9), _crate, true)
	LevelKit.add_box(self, Vector3(don.x + 2.2, 1.2, don.z + 0.3), Vector3(0.9, 0.6, 0.7), _crate, true)

	_build_shop()
	_build_stash()

	# THE MAINFRAME: a giant CRT computer on the west wall. Decoration for now — later,
	# players will feed it scrap for server-wide buffs.
	var frame_x := -w + 1.0
	LevelKit.add_box(self, Vector3(frame_x, 2.5, 0), Vector3(2, 5, 6), _metal, true)
	var screen := LevelKit.add_box(self, Vector3(frame_x + 1.15, 2.8, 0), Vector3(0.3, 2.2, 4.0), _neon, false)
	screen.set_instance_shader_parameter("instance_tint", Color(0.2, 1, 0.45))
	LevelKit.add_light(self, Vector3(frame_x + 2.5, 2.8, 0), Color(0.2, 1, 0.45), 2.5, 8.0)
	LevelKit.add_sign(self, "THE MAINFRAME\nOVERCLOCK  OFFLINE", Vector3(frame_x + 1.35, 2.8, 0), Color(0.0, 0.06, 0.02), 32, PI / 2)

	# Cardboard-box shanties along the east wall (the "homes" of sewer cats).
	for z in [4.0, 9.0, 14.0]:
		LevelKit.add_box(self, Vector3(w - 1.4, 0.6, z), Vector3(2.0, 1.2, 2.6), _cardboard, true)
		LevelKit.add_box(self, Vector3(w - 1.4, 1.45, z - 0.3), Vector3(1.4, 0.5, 1.6), _cardboard, false)
	# Crates, trash and junk.
	for spot in [Vector3(-w + 1.0, 0.5, 10), Vector3(-w + 1.0, 0.5, 11.2), Vector3(-w + 1.0, 1.5, 10.6), Vector3(w - 1.0, 0.5, -4), Vector3(-4, 0.5, -17)]:
		LevelKit.add_box(self, spot, Vector3.ONE, _crate, true)


## THE BLACK MARKITTEN: Comrade Whiskers' rebel shop on the west wall. Everything is placed
## around wherever he stands (move ComradeWhiskers under Hub in main.tscn and it follows).
## He faces east (+X); the counter is in front of him, the shelves behind him on the wall.
func _build_shop() -> void:
	var at := shopkeeper.position
	var wall_x := -half_width  # inside face of the west wall
	# The counter: a slab of metal on crates, between him and the customers.
	LevelKit.add_box(self, Vector3(at.x + 1.3, 0.45, at.z), Vector3(0.7, 0.9, 3.2), _crate, true)
	LevelKit.add_box(self, Vector3(at.x + 1.3, 0.95, at.z), Vector3(0.9, 0.1, 3.4), _metal, false)
	var strip := LevelKit.add_box(self, Vector3(at.x + 1.76, 0.86, at.z), Vector3(0.04, 0.06, 3.4), _neon, false)  # glowing edge
	strip.set_instance_shader_parameter("instance_tint", Color(1, 0.15, 0.1))
	# Shelves on the wall behind him, stocked with glowing "goods".
	for shelf_y in [1.2, 2.0, 2.8]:
		LevelKit.add_box(self, Vector3(wall_x + 0.35, shelf_y, at.z), Vector3(0.6, 0.08, 4.0), _metal, false)
		for i in 5:
			var goods := LevelKit.add_box(self, Vector3(wall_x + 0.35, shelf_y + 0.17, at.z - 1.6 + i * 0.8), Vector3(0.3, 0.26, 0.3), _neon, false)
			goods.set_instance_shader_parameter("instance_tint", SHOP_GOODS_COLORS[(i + int(shelf_y * 10)) % SHOP_GOODS_COLORS.size()] * 0.5)
	# Crates of "merchandise that fell off a truck" stacked either side.
	for spot in [Vector3(at.x, 0.5, at.z - 2.6), Vector3(at.x, 0.5, at.z + 2.6), Vector3(at.x, 1.5, at.z + 2.6)]:
		LevelKit.add_box(self, spot, Vector3.ONE, _crate, true)
	# A red rebel banner hanging over the shelves.
	var banner := LevelKit.add_box(self, Vector3(wall_x + 0.06, 4.0, at.z), Vector3(0.05, 1.3, 4.6), _neon, false)
	banner.set_instance_shader_parameter("instance_tint", Color(0.35, 0.02, 0.03))
	# Red light over the shop, and a warm one so you can see his face.
	LevelKit.add_light(self, Vector3(at.x + 1.0, 3.2, at.z), Color(1, 0.2, 0.15), 3.0, 8.0)
	LevelKit.add_light(self, Vector3(at.x + 2.0, 1.8, at.z), Color(1, 0.8, 0.55), 2.5, 4.5)


## THE STASH: a row of battered lockers on the east wall where cats keep gear safe.
## Built around stash_spot (change it in the Inspector: Hub > Stash and they follow).
func _build_stash() -> void:
	var at := stash_spot
	# Press E here: the inventory opens with your stash in it (scripts/interactable.gd).
	var lockers := Interactable.make(self, stash_spot, "OPEN STASH", stash_radius, 10)
	lockers.used.connect(func(cat: CatPlayer): InventoryScreen.for_seat(cat.slot).open(cat))
	var wall_x := half_width  # inside face of the east wall
	# Four tall lockers against the wall, each with a glowing lock light.
	for i in 4:
		var z := at.z - 1.5 + i
		LevelKit.add_box(self, Vector3(wall_x - 0.4, 1.1, z), Vector3(0.8, 2.2, 0.9), _metal, true)
		var lock := LevelKit.add_box(self, Vector3(wall_x - 0.82, 1.2, z + 0.25), Vector3(0.04, 0.1, 0.1), _neon, false)
		lock.set_instance_shader_parameter("instance_tint", Color(0.3, 1, 0.4))
	LevelKit.add_light(self, Vector3(wall_x - 1.6, 2.6, at.z), Color(0.4, 0.9, 1), 2.5, 6.0)
