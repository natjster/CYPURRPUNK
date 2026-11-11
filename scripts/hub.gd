class_name UndergroundHub
extends Node3D
## CYPURRPUNK — THE SEWERS: the underground hub where every cat starts.
## Attach to the "Hub" node in main.tscn. That node sits 200 m BELOW the city
## (position 0, -200, 0), so the hub and the city are one world and one multiplayer game:
## going "up top" or "back down" is just moving your cat between the two.
##
## How it plays:
##   - Joining or hosting puts your cat here, at the south end of the tunnel.
##   - It's a SAFE ZONE: guns don't fire down here (see ItemManager._use_held_items), unless it's
##     being BREACHED (below; ask UndergroundHub.is_safe(where)).
##   - Walk up to DON CATLEONE (the boss cat at the north end) and press E to talk.
##     Pick "SEND ME UP TOP" and he sends you into the city (deploy()).
##   - COMRADE WHISKERS runs THE BLACK MARKITTEN on the west wall: the only place to get
##     gear (guns, catnip, catdip). He also BUYS the fish you bring home
##     (SELL buttons on his shop page): that's where cash comes from.
##     He's a Shopkeeper NPC (scripts/npcs/shopkeeper.gd); his shop is built in _build_shop().
##   - THE MAINFRAME, the scrounged-together computer in the middle of the west wall
##     (scripts/mainframe.gd, _build_mainframe): its screen shows THIS gang's charge (OVERCLOCK
##     ACTIVE / SYSTEM ONLINE / POWER LOW / WARNING / CRITICAL), its rack 4 battery cells. Press E
##     there for its window (scripts/ui/mainframe_screen.gd): FEED it ELECTRONICS (+25%), or when
##     it's full HACK the rival gang's (-25%).
##   - THE CAT-CAM TV on the east wall, across the water from the Mainframe (_build_catcam): press E
##     to watch your crew up top over their shoulder (scripts/spectator.gd).
##   - In the city, climb down the EXIT manhole once it opens (fish_heist.gd): you're
##     brought back down here (return_cat()) with your loot still in your backpack.
##
##   - THE NORTH BREACH TUNNEL: a dark pipe behind a heavy BLAST GATE at the north end of the west
##     walkway. It stays shut... until a gang's Mainframe hits 0%. Then the SEWER BREACH comes
##     (scripts/mainframe.gd): the gate slides up, the tunnel pulses red, a horde pours out of it
##     (roomba_patrol.gd) and THIS sewer stops being a safe zone until the breach is over.
##     A BreachCamera up in the south-west corner lets the rival gang watch it live.
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
##
## TWO GANGS, TWO SEWERS (scripts/teams.gd): every gang has its own copy of this tunnel.
##   "Hub"     (Team 0) = Don Catleone's, at (0, -200, 0)
##   "GangHub" (Team 1) = Pawnie & Clawd's, at (200, -200, 0): same tunnel, its own leader (Pawnie)
##                        and shopkeeper (Clawd), set in the Inspector (Leader / Shopkeeper).
## The tunnels are sealed boxes far apart, so nobody can walk into the other gang's.
## Find a cat's sewer with UndergroundHub.of(cat); UndergroundHub.instance is the Team 0 one
## (it also runs the fog / music, which are shared by the whole world).

## The Team 0 hub (Don's). It also runs the mood and music for the whole world.
static var instance: UndergroundHub
## Every gang's hub, by team number (Teams.CATLEONE, Teams.BURROW...).
static var by_team := {}

## Anything below this height is "in the hub" (the city floor is at 0, the hub at -200).
const DEPTH_LINE: float = -100.0
## mood_at's answer up in the city (down in a sewer it's that sewer's gang number).
const CITY_MOOD: int = -1
## mood_at's answer inside MEOW-MART (scripts/interiors/meow_mart_interior.gd): no rain, the store's
## fluorescent haze (its Look exports), its hum instead of the rain.
const MART_MOOD: int = -2

@export_group("Gang")
## Which gang lives here (scripts/teams.gd: 0 = Catleone Family, 1 = Burrow Gang).
@export var team: int = Teams.CATLEONE
## The boss who sends cats up top (a "send_up_top" choice in their talk). Their corner gets a
## glow and crates. Left empty = a child node called DonCatleone.
@export var leader: Npc
## The shopkeeper: their stall is built around them (the Black Markitten). Left empty = a child
## node called ComradeWhiskers.
@export var shopkeeper: Npc
## The colour of the glow over the leader's corner.
@export var leader_glow: Color = Color(1, 0.4, 0.8)
## The name on messages from the boss when they won't send you up.
@export var boss_name: String = "DON CATLEONE"
## What the boss says when the hatch is sealed (DEEP CLEAN)...
@export_multiline var line_sealed: String = "Hatch is sealed, kid. Sit tight - we're movin' to a new district."
## ...and when you've already had your one trip up this district.
@export_multiline var line_had_your_trip: String = "You had your shot up there, kid. That hatch is shut behind ya. Sit tight till we hit the next district."
## ...and during a SEWER BREACH (scripts/mainframe.gd).
@export_multiline var line_breach: String = "ARE YOU CRAZY?! THEY'RE IN THE TUNNEL!"

@export_group("Payphone (the boss on the line)")
## What this gang's boss says when one of their cats calls from a payphone up top
## (scripts/npcs/payphone.gd). Before the exits open (no way down yet; no hint where)...
@export_multiline var phone_too_early: String = "Keep your whiskers on, kid! My boys are still diggin' through the pipes!"
## ...once they're open (the gang's exit arrow switches on; {where} = "north-east" etc.)...
@export_multiline var phone_exit_open: String = "My boys' little paws found a way down, sending you the deets now!"
## ...and after the hatch is sealed (the DEEP CLEAN).
@export_multiline var phone_sealed: String = "They found our hole, kid! We had to seal it - you're on your own!"

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
## How far (metres) from this gang's ENTRY manhole you pop out, up the street towards the middle
## of the city (your gang's car is parked further up that street, right in front of you).
## (Where each gang's manhole is: fish_heist.gd entry_position - opposite corners.)
@export var surface_distance: float = 3.5

@export_group("Stash")
## Where you stand to use THE LITTERBOX (your safe stash, on the east wall), relative to the Hub node.
## The litterbox is built just east of this spot, against the wall.
@export var stash_spot: Vector3 = Vector3(11.0, 0, -9.0)
## How close (metres) you must be to the litterbox spot to open it.
@export var stash_radius: float = 2.5
## The HUD line after "[E] " when you're at the litterbox.
@export var stash_prompt: String = "STORE YOUR SHIT"
## The litterbox's plastic colour.
@export var litterbox_color: Color = Color(0.55, 0.2, 0.6)
## Its neon strip, sign and light.
@export var litterbox_glow: Color = Color(0.4, 0.9, 1)
## The sand.
@export var sand_color: Color = Color(0.62, 0.55, 0.4)

@export_group("Tinker Workbench")
## Where you stand to use the TINKER WORKBENCH (SEWER UPGRADES: DELUXE LITTERBOX + MAINFRAME
## CAPACITOR, scripts/upgrades.gd), relative to the Hub node. The bench (models/workbench.glb)
## is built just east of this spot, against the east wall, facing you. (z -4 = between the
## litterbox (z -11..-7) and the CAT-CAM TV (z 0). Keep it 4+ m from both: closer and the E prompts
## overlap, and it used to sit right on top of the TV.)
@export var workbench_spot: Vector3 = Vector3(11.0, 0, -4.0)
## How close (metres) you must be to use it.
@export var workbench_radius: float = 2.5
## The HUD line after "[E] " at the bench.
@export var workbench_prompt: String = "TINKER WORKBENCH"
## The colour of its lamp's light.
@export var workbench_light: Color = Color(1.0, 0.8, 0.45)

@export_group("Mainframe")
## Where you stand to use THE MAINFRAME (the junk-pile computer on the west wall), relative to the Hub node.
@export var mainframe_spot: Vector3 = Vector3(-11.0, 0, 0)
## How close (metres) you must be to the mainframe spot.
@export var mainframe_radius: float = 2.5
## Font size of the charge % on the Mainframe's screen (the only words on it).
@export var mainframe_percent_size: int = 64

@export_group("CAT-CAM TV")
## Where you stand to watch the CAT-CAM (a chunky TV on a crate on the east wall, across the water
## from the Mainframe), relative to the Hub node. The TV is built just east of this spot.
## Press E there to watch your crew up top (scripts/spectator.gd).
@export var catcam_spot: Vector3 = Vector3(11.5, 0, 0)
## How close (metres) you must be to the TV.
@export var catcam_radius: float = 2.5
## The HUD line after "[E] " at the TV.
@export var catcam_prompt: String = "WATCH CREW UP TOP"
## The TV screen's glow colour.
@export var catcam_glow: Color = Color(0.35, 0.75, 1.0)

@export_group("Breach Tunnel")
## East-west middle of the tunnel mouth (metres; -8 = the west walkway).
@export var tunnel_x: float = -8.0
## The tunnel's width, height and how far north it runs past the north wall (metres).
@export var tunnel_width: float = 6.0
@export var tunnel_height: float = 4.5
@export var tunnel_depth: float = 12.0
## How long the BLAST GATE takes to slide up, and to slam shut (seconds).
@export var gate_open_seconds: float = 1.2
@export var gate_slam_seconds: float = 0.2
## The red emergency light in the tunnel: dim normally, pulsing bright during a breach.
@export var tunnel_light_color: Color = Color(1, 0.08, 0.05)
@export var tunnel_light_idle: float = 1.2
@export var tunnel_light_breach: float = 9.0
## Pulses per second during a breach.
@export var tunnel_light_pulse: float = 1.5

@export_group("Breach Camera")
## The security camera the rival gang watches a breach through, relative to the Hub node...
@export var breach_camera_spot: Vector3 = Vector3(-10, 5.5, 16)
## ...and the spot it looks at (the tunnel mouth and walkways).
@export var breach_camera_target: Vector3 = Vector3(-6, 0.5, -16)
## How wide it sees (degrees).
@export var breach_camera_fov: float = 62.0

@export_group("Mood")
## Fog and ambient colours while you're down here.
@export var sewer_fog_color: Color = Color(0.03, 0.07, 0.05)
@export var sewer_fog_albedo: Color = Color(0.55, 0.85, 0.65)
@export var sewer_ambient_color: Color = Color(0.35, 0.55, 0.45)
@export var sewer_ambient_energy: float = 0.6

@export_group("Gang Look")
## What sets each gang's sewer apart (GangHub's are set in main.tscn: rust and amber). Floor, walls
## and the crates' neon grid:
@export var concrete_tint: Color = Color(0.45, 0.5, 0.46)
@export var wall_tint: Color = Color(0.3, 0.36, 0.33)
@export var crate_tint: Color = Color(0.3, 0.9, 0.8)
## The water's colour, and the glow on it and coming up off it.
@export var water_tint: Color = Color(0.03, 0.12, 0.09)
@export var water_glow_color: Color = Color(0.2, 1, 0.7)
## The hanging work lights.
@export var work_light_color: Color = Color(1, 0.65, 0.32)
## The banner over the shop and the shop's light.
@export var banner_color: Color = Color(0.35, 0.02, 0.03)
@export var shop_light_color: Color = Color(1, 0.2, 0.15)
## On = timber posts and roof beams, like a tunnel dug by paw (the Burrow Gang's).
@export var wood_supports: bool = false

@export_group("Music")
## Music down here and up top: file names in res://sounds/music/ (without .wav). "" = silence.
@export var hub_music: String = "hub"
@export var city_music: String = "city"
## Background loops: file names in res://sounds/ambience/. "" = silence.
@export var hub_ambience: String = "sewer"
@export var city_ambience: String = "rain"

## The leader (Don Catleone in Team 0's): only used here to decorate their corner (lights, crates).
var npc: Npc
@onready var _environment: Environment = $"../WorldEnvironment".environment
@onready var _moonlight: Light3D = $"../Moonlight"
@onready var _rain: GPUParticles3D = $"../Rain"

## The mood the world's look is on now (mood_at).
var _view_mood: int = CITY_MOOD
var _city_mood := {}  # the night-city fog/ambient values, to put back when you go up
## Split screen: copies of the world's look with the OTHER moods (by mood_at number), for screens
## whose camera is somewhere else. Made when needed.
var _other_moods := {}

var _concrete: ShaderMaterial
var _wall: ShaderMaterial
var _water: ShaderMaterial
var _metal: ShaderMaterial
var _crate: ShaderMaterial
var _timber: ShaderMaterial
var _neon: ShaderMaterial
var _pitch_black: ShaderMaterial
## True while THIS sewer is breached (set on every computer by set_breached): no safe zone here,
## the gate is up and the tunnel pulses red.
var breached: bool = false
## The security camera in this sewer (the rival gang watches a breach through it).
var breach_camera: Camera3D
## The BLAST GATE (a StaticBody3D, so it really stops cats and bots) and the tunnel's red light.
var _gate: StaticBody3D
var _tunnel_light: OmniLight3D
var _gate_tween: Tween
## THE MAINFRAME's CRT prop (built in _build_props, coloured by _update_mainframe_crt).
var _crt_screen: MeshInstance3D
var _crt_light: OmniLight3D
var _crt_sign: Label3D
## The INTEL line under the CRT: this district's DISTRICT TWIST (scripts/district_twist.gd).
## The moonlight's normal brightness (a BLACKOUT dims it).
var _moon_energy: float = 1.0
var _crt_key := ""  # what the CRT shows now, so it's only rewritten when that changes
## THE MAINFRAME's model (models/mainframe.glb), its spinning desk fan, and the 4 glowing battery
## cells in its rack (the CHARGE GAUGE: they go dark one by one as the charge drains).
var _mainframe_model: Node3D
var _mainframe_fan: Node3D
var _gauge_cells: Array[MeshInstance3D] = []
var _gauge_cell_height: float = 0.5


## THE MAINFRAME's E spot: "[E] THE MAINFRAME (63%)". Pressing it opens its window
## (scripts/ui/mainframe_screen.gd): what it does, its battery cells, and the FEED button.
class MainframeTerminal extends Interactable:
	var hub: UndergroundHub

	func interact_distance(cat: CatPlayer) -> float:
		if Mainframe.instance == null:
			return -1.0
		return super(cat)

	func interact_prompt(cat: CatPlayer) -> String:
		var mainframe := Mainframe.instance
		var have := ItemManager.instance.count_in_bag(cat.player_id, Mainframe.FUEL_ID)
		return "THE MAINFRAME (%d%%)%s" % [mainframe.percent(cat.team), "  - FEED ELECTRONICS" if have > 0 else ""]

	func interact(cat: CatPlayer) -> void:
		var window := MainframeScreen.for_seat(cat.slot)
		if window != null:
			window.open(cat, hub)


func _enter_tree() -> void:
	by_team[team] = self
	if team == Teams.CATLEONE:
		instance = self


func _ready() -> void:
	npc = leader if leader != null else get_node_or_null("DonCatleone") as Npc
	if shopkeeper == null:
		shopkeeper = get_node_or_null("ComradeWhiskers") as Npc
	_make_materials()
	_build_tunnel()
	_build_props()
	_build_breach_tunnel()
	_city_mood = {
		"fog_light_color": _environment.fog_light_color,
		"volumetric_fog_albedo": _environment.volumetric_fog_albedo,
		"ambient_light_color": _environment.ambient_light_color,
		"ambient_light_energy": _environment.ambient_light_energy,
	}
	Settings.changed.connect(func(): _other_moods.clear())  # e.g. VOLUMETRIC FOG changed: copy it again
	_moon_energy = _moonlight.light_energy
	# A new city = maybe a new DISTRICT TWIST (a BLACKOUT is darker): put the city's look on again.
	($"../City" as CityGenerator).generated.connect(_on_city_generated)


## A new district was built: a BLACKOUT (scripts/district_twist.gd) darkens the night city.
func _on_city_generated(_seed: int) -> void:
	if self != instance:
		return  # (the world's look is Team 0's hub's job)
	var twist := DistrictTwist.instance
	_moonlight.light_energy = _moon_energy * (twist.blackout_moonlight_multiplier if DistrictTwist.is_blackout() else 1.0)
	_other_moods.clear()
	if _view_mood == CITY_MOOD:
		_set_mood(_environment, CITY_MOOD)


## True if this spot is down in a hub, any gang's (the safe zone).
static func is_in_hub(where: Vector3) -> bool:
	return where.y < DEPTH_LINE


## True if this spot is somewhere nothing can hurt you: down in a sewer that ISN'T being breached.
static func is_safe(where: Vector3) -> bool:
	if not is_in_hub(where):
		return false
	var hub := hub_at(where)
	return hub == null or not hub.breached


## The sewer this spot is in, or null (the hubs are 200 m apart, so "the nearest" is easy).
static func hub_at(where: Vector3) -> UndergroundHub:
	if not is_in_hub(where):
		return null
	for hub in by_team.values():
		if is_instance_valid(hub) and absf(where.x - (hub as UndergroundHub).global_position.x) < 60.0:
			return hub
	return null


## The sewer this gang lives in (Team 0's if there's no hub for it).
static func for_team(team_number: int) -> UndergroundHub:
	var hub: UndergroundHub = by_team.get(team_number)
	return hub if hub != null and is_instance_valid(hub) else instance


## This cat's own gang's sewer: where it starts, comes home to, and has its stash.
static func of(cat: CatPlayer) -> UndergroundHub:
	return for_team(cat.team) if cat != null else instance


# --- Moving cats between the hub and the city (called on the cat OWNER's computer) ---

## True if this cat is standing at THE STASH lockers (where the inventory shows your stash).
func near_stash(cat: CatPlayer) -> bool:
	return cat != null and cat.global_position.distance_to(to_global(stash_spot)) < stash_radius


## True if this cat is standing at THE MAINFRAME (where electronics can be fed in: mainframe.gd).
func near_mainframe(cat: CatPlayer) -> bool:
	return cat != null and cat.global_position.distance_to(to_global(mainframe_spot)) < mainframe_radius + 0.5


## Where cat number n appears when it joins: rows of three on the walkway, facing Don.
## A spawn spot nobody else is standing on (up to 12 spots: 3 across, 4 rows), so 8 cats
## arriving at once don't land on top of each other.
## Each player starts looking at a different spot (from their player ID): two computers sending
## cats home at the same moment can't see each other's choice yet, and two cats landing on the
## same spot used to shove one of them metres up into the air.
func free_spawn_position(cat: CatPlayer) -> Vector3:
	var first := posmod(hash(cat.player_id), 12) if cat != null else 0
	for i in 12:
		var n := (first + i) % 12
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
	if Mainframe.instance.breach_busy:
		# A SEWER BREACH (mainframe.gd): nobody goes anywhere until it's over.
		Hud.show_message("%s: %s" % [boss_name, line_breach], 4.0, cat.slot)
		return
	if FishHeist.instance.sealed:
		# The DEEP CLEAN is on up there: wait for the next district.
		Hud.show_message("%s: %s" % [boss_name, line_sealed], 4.0, cat.slot)
		return
	if not Tutorial.allows_deploy():
		# TUTORIAL (scripts/tutorial.gd): the sewer steps come first.
		Hud.show_message("%s: %s" % [boss_name, Tutorial.instance.too_early_to_deploy], 4.0, cat.slot)
		return
	if FishHeist.instance.has_been_up(cat.player_id):
		# One trip per district (fish_heist.gd went_up): extracted or flattened, you've had yours.
		Hud.show_message("%s: %s" % [boss_name, line_had_your_trip], 5.0, cat.slot)
		return
	# Up our gang's own ENTRY manhole (its corner of the city), a few steps up the north-south
	# street towards the middle, facing up that street: our gang's car is parked right ahead
	# (getaway_car.gd parking_spot uses the same street).
	var manhole := FishHeist.instance.entry_position(team)
	var up_street := Vector3(0, 0, -signf(manhole.z) if manhole.z != 0.0 else -1.0)
	var spread := Vector3(randf_range(-2.5, 2.5), 0, randf_range(-1, 1))  # side by side, not on each other
	cat.teleport_to(manhole + up_street * surface_distance + spread, atan2(-up_street.x, -up_street.z))
	print("[Hub] %s went up to the city" % cat.name)


## Extracted: back down the drain to the hub.
func return_cat(cat: CatPlayer) -> void:
	cat.teleport_to(free_spawn_position(cat), 0.0)
	print("[Hub] %s extracted back to the hub" % cat.name)


# --- Every frame: THE MAINFRAME's CRT (every hub), then the mood (this computer only) ---

func _process(delta: float) -> void:
	_update_mainframe_crt()
	_update_mainframe_model(delta)
	if breached:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * tunnel_light_pulse)
		_tunnel_light.light_energy = lerpf(tunnel_light_idle, tunnel_light_breach, pulse)
	if self != instance:
		return  # the fog / music are the whole world's: Team 0's hub runs them
	var camera := get_viewport().get_camera_3d()
	var mood := mood_at(camera.global_position) if camera != null else CITY_MOOD
	if mood != _view_mood:
		_view_mood = mood
		_update_mood(mood)
	var in_hub := mood != CITY_MOOD
	# Split screen: is ANY of this computer's players up top? Then the moon shines (it lights
	# the whole world, so it can't be on for one screen only) and the city music plays.
	var anyone_up := not in_hub
	var anyone_outdoors := mood == CITY_MOOD  # (not underground and not inside Meow-Mart: under the moon)
	if GameScreen.instance != null:
		for view_camera in GameScreen.instance.view_cameras():
			anyone_up = anyone_up or not is_in_hub(view_camera.global_position)
			anyone_outdoors = anyone_outdoors or mood_at(view_camera.global_position) == CITY_MOOD
	_moonlight.visible = anyone_outdoors
	# Music + background sound (sounds/music/hub.wav or city.wav, sounds/ambience/sewer.wav or
	# rain.wav). Same track as before = nothing happens.
	Sound.play_music(city_music if anyone_up else hub_music)
	var ambience_now := city_ambience if anyone_up else hub_ambience
	if mood == MART_MOOD:
		ambience_now = MeowMartInterior.instance.ambience  # (player 1 is shopping: the fridges' hum)
	Sound.play_ambience(ambience_now)


## THE MAINFRAME's CRT: sign text, screen tint and light colour follow THIS gang's charge
## (scripts/mainframe.gd). CRITICAL (0%) flashes red. Every hub runs this for its own CRT.
func _update_mainframe_crt() -> void:
	var mainframe := Mainframe.instance
	if mainframe == null or _crt_sign == null:
		return
	var colour := mainframe.tier_color(team)
	var critical := mainframe.tier(team) == Mainframe.Tier.CRITICAL
	var flash_on := not critical or fmod(Time.get_ticks_msec() / 1000.0 * 2.0, 1.0) < 0.5
	var key := "%d %s" % [mainframe.percent(team), flash_on]
	if key == _crt_key:
		return
	_crt_key = key
	_crt_sign.text = "%d%%" % mainframe.percent(team)  # (only the number: the window says the rest)
	var shown := colour * 0.5 if flash_on else colour * 0.15  # (dimmer than a plain neon box: the junk around it should read)
	_crt_screen.set_instance_shader_parameter("instance_tint", Color(shown, 1.0))
	_crt_light.light_color = colour
	_crt_light.light_energy = 1.8 if flash_on else 0.5


## Which mood a camera here gets: CITY_MOOD, or the gang number of the sewer it's in.
static func mood_at(where: Vector3) -> int:
	if MeowMartInterior.contains(where):
		return MART_MOOD
	if not is_in_hub(where):
		return CITY_MOOD
	var hub := hub_at(where)
	return hub.team if hub != null else Teams.CATLEONE


## Split screen: the look a screen with its camera here should use, or null for "the world's own
## look" (when it matches player 1's screen). game_screen.gd asks every frame.
func environment_for(where: Vector3) -> Environment:
	var mood := mood_at(where)
	if mood == _view_mood:
		return null
	if not _other_moods.has(mood):
		_other_moods[mood] = _environment.duplicate()
		_set_mood(_other_moods[mood], mood)
	return _other_moods[mood]


## Underground: no rain, that sewer's fog. Up top: the night city as it was.
func _update_mood(mood: int) -> void:
	_other_moods.clear()  # the other screens' copies change too: make them again when needed
	_rain.visible = mood == CITY_MOOD
	_rain.emitting = mood == CITY_MOOD
	_set_mood(_environment, mood)


## Put a sewer's (or the city's) fog and light colours into an Environment.
func _set_mood(environment: Environment, mood: int) -> void:
	if mood == CITY_MOOD:
		environment.fog_light_color = _city_mood.fog_light_color
		environment.volumetric_fog_albedo = _city_mood.volumetric_fog_albedo
		environment.ambient_light_color = _city_mood.ambient_light_color
		environment.ambient_light_energy = _city_mood.ambient_light_energy
		if DistrictTwist.is_blackout():  # the power's out up there: a darker night
			environment.ambient_light_energy *= DistrictTwist.instance.blackout_ambient_multiplier
		return
	if mood == MART_MOOD:
		var mart := MeowMartInterior.instance
		environment.fog_light_color = mart.fog_color
		environment.volumetric_fog_albedo = mart.fog_albedo
		environment.ambient_light_color = mart.ambient_color
		environment.ambient_light_energy = mart.ambient_energy
		return
	var hub := for_team(mood)
	environment.fog_light_color = hub.sewer_fog_color
	environment.volumetric_fog_albedo = hub.sewer_fog_albedo
	environment.ambient_light_color = hub.sewer_ambient_color
	environment.ambient_light_energy = hub.sewer_ambient_energy


# --- Building the tunnel ---

func _make_materials() -> void:
	var asphalt := preload("res://textures/asphalt.png")
	_concrete = LevelKit.psx_material({"albedo_texture": asphalt, "albedo_color": concrete_tint, "world_uv": true, "world_uv_scale": 0.4, "specular": 0.4, "roughness": 0.4})
	_wall = LevelKit.psx_material({"albedo_texture": asphalt, "albedo_color": wall_tint, "world_uv": true, "world_uv_scale": 0.3})
	_water = LevelKit.psx_material({"albedo_color": water_tint, "specular": 0.7, "roughness": 0.15, "emission_color": water_glow_color, "emission_energy": 0.04})
	_metal = LevelKit.psx_material({"albedo_color": Color(0.26, 0.28, 0.3), "specular": 0.5, "roughness": 0.4})
	_crate = LevelKit.psx_material({"albedo_texture": preload("res://textures/neon_grid.png"), "albedo_color": crate_tint})
	_timber = LevelKit.psx_material({"albedo_color": Color(0.3, 0.19, 0.1)})
	_neon = LevelKit.psx_material({"emission_color": Color.WHITE, "emission_energy": 5.0})
	_pitch_black = LevelKit.psx_material({"albedo_color": Color(0.005, 0.005, 0.008)})


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
	# The north wall comes in three pieces, around the mouth of the breach tunnel (_build_breach_tunnel).
	var mouth_west := tunnel_x - tunnel_width * 0.5
	var mouth_east := tunnel_x + tunnel_width * 0.5
	var wall_top := height + 1.0
	LevelKit.add_box(self, Vector3((-w + mouth_west) * 0.5, height * 0.5 - 1, -l - 0.5), Vector3(mouth_west + w, height + 2, 1), _wall, true)
	LevelKit.add_box(self, Vector3((mouth_east + w) * 0.5, height * 0.5 - 1, -l - 0.5), Vector3(w - mouth_east, height + 2, 1), _wall, true)
	LevelKit.add_box(self, Vector3(tunnel_x, (tunnel_height + wall_top) * 0.5, -l - 0.5), Vector3(tunnel_width, wall_top - tunnel_height, 1), _wall, true)
	LevelKit.add_box(self, Vector3(0, height * 0.5 - 1, l + 0.5), Vector3(w * 2, height + 2, 1), _wall, true)
	LevelKit.add_box(self, Vector3(0, height + 0.5, 0), Vector3(w * 2 + 2, 1, l * 2 + 2), _wall, true)

	# Big pipes along the ceiling, and ribs across it every 5 m (makes it read as a tunnel).
	for x in [-w + 1.2, w - 1.2]:
		var pipe := LevelKit.add_cylinder(self, Vector3(x, height - 1.0, 0), 0.45, l * 2, _metal)
		pipe.rotation.x = PI / 2
	for z in range(-int(l) + 5, int(l), 5):
		LevelKit.add_box(self, Vector3(0, height - 0.3, z), Vector3(w * 2, 0.6, 0.6), _timber if wood_supports else _wall, false)
		if wood_supports:  # a dug tunnel: a timber post up each wall, under every beam
			for x in [-w + 0.2, w - 0.2]:
				LevelKit.add_box(self, Vector3(x, (height - 0.6) * 0.5, z), Vector3(0.4, height - 0.6, 0.4), _timber, false)


## THE NORTH BREACH TUNNEL: a deep pipe running north from the mouth in the north wall, the iron
## BLAST GATE across its mouth, a red emergency light inside, and the security camera that films it.
func _build_breach_tunnel() -> void:
	var l := half_length
	var middle_z := -l - 1.0 - tunnel_depth * 0.5 + 0.5  # (the wall itself is the first metre of the way)
	var length := tunnel_depth - 1.0
	var side := tunnel_width * 0.5
	# Floor (top at 0, like the walkway), side walls, ceiling and a pitch-black far end.
	LevelKit.add_box(self, Vector3(tunnel_x, -0.5, -l - tunnel_depth * 0.5), Vector3(tunnel_width, 1, tunnel_depth), _concrete, true)
	for x in [tunnel_x - side - 0.5, tunnel_x + side + 0.5]:
		LevelKit.add_box(self, Vector3(x, tunnel_height * 0.5, middle_z), Vector3(1, tunnel_height + 2, length), _wall, true)
	LevelKit.add_box(self, Vector3(tunnel_x, tunnel_height + 0.5, middle_z), Vector3(tunnel_width, 1, length), _wall, true)
	LevelKit.add_box(self, Vector3(tunnel_x, tunnel_height * 0.5, -l - tunnel_depth - 0.5), Vector3(tunnel_width + 2, tunnel_height + 2, 1), _pitch_black, true)
	# Ribs around the pipe every 3 m, so it reads as a deep tunnel going off into the dark.
	var z := -l - 2.5
	while z > -l - tunnel_depth:
		LevelKit.add_box(self, Vector3(tunnel_x, tunnel_height - 0.15, z), Vector3(tunnel_width, 0.3, 0.4), _metal, false)
		for x in [tunnel_x - side + 0.1, tunnel_x + side - 0.1]:
			LevelKit.add_box(self, Vector3(x, (tunnel_height - 0.3) * 0.5, z), Vector3(0.2, tunnel_height - 0.3, 0.4), _metal, false)
		z -= 3.0

	# The BLAST GATE: vertical bars + crossbeams. The collision is one solid slab, so nothing
	# squeezes between the bars. Sliding this one node moves all of it (set_breached).
	_gate = StaticBody3D.new()
	_gate.name = "BlastGate"
	_gate.position = Vector3(tunnel_x, 0, -l - 0.2)
	add_child(_gate)
	LevelKit.add_collision(_gate, Vector3(0, tunnel_height * 0.5, 0), Vector3(tunnel_width, tunnel_height, 0.4))
	var bar_x := -side + 0.3
	while bar_x < side:
		LevelKit.add_box(_gate, Vector3(bar_x, tunnel_height * 0.5, 0), Vector3(0.2, tunnel_height, 0.2), _metal, false)
		bar_x += 0.75
	for y in [0.9, tunnel_height - 0.9]:
		LevelKit.add_box(_gate, Vector3(0, y, 0.12), Vector3(tunnel_width, 0.35, 0.12), _metal, false)
	var warning := LevelKit.add_box(_gate, Vector3(0, tunnel_height - 0.9, 0.2), Vector3(tunnel_width, 0.1, 0.04), _neon, false)
	warning.set_instance_shader_parameter("instance_tint", Color(0.8, 0.05, 0.03))

	_tunnel_light = LevelKit.add_light(self, Vector3(tunnel_x, 2.5, -25.0), tunnel_light_color, tunnel_light_idle, 16.0)

	# The security camera. It only ever gets switched on by GameScreen (the rival's live feed).
	breach_camera = Camera3D.new()
	breach_camera.name = "BreachCamera"
	breach_camera.position = breach_camera_spot
	breach_camera.fov = breach_camera_fov
	add_child(breach_camera)
	breach_camera.look_at(to_global(breach_camera_target))
	# (Godot hands the picture to the first camera it meets. That must never be this one.)
	if get_viewport().get_camera_3d() == breach_camera:
		breach_camera.clear_current(false)


## Every computer (mainframe.gd): the breach starts (gate slides up, tunnel pulses) or ends (gate
## slams shut, and any cat still in the tunnel is put back in the sewer before it's locked in).
func set_breached(on: bool) -> void:
	if on == breached:
		return
	breached = on
	if _gate_tween != null:
		_gate_tween.kill()
	_gate_tween = create_tween()
	if on:
		_gate_tween.tween_property(_gate, "position:y", tunnel_height + 0.1, gate_open_seconds).set_trans(Tween.TRANS_SINE)
		return
	_tunnel_light.light_energy = tunnel_light_idle
	_gate_tween.tween_property(_gate, "position:y", 0.0, gate_slam_seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	Sound.play_at("explode", _gate.global_position + Vector3.UP)
	for cat in Game.instance.local_cats():
		if hub_at(cat.global_position) == self and to_local(cat.global_position).z < -half_length + 1.0:
			return_cat(cat)


## Host: a random spot in the breach tunnel, for a bot pouring in (around z = -29..-23, x = -10..-6).
func breach_spawn_spot(rng: RandomNumberGenerator) -> Vector3:
	var reach := tunnel_width * 0.5 - 1.0
	return to_global(Vector3(tunnel_x + rng.randf_range(-reach, reach), 0.1, rng.randf_range(-29.0, -23.0)))


## Host: a random spot on the walkways, for a breach bot with nobody left to chase.
func random_walkway_spot(rng: RandomNumberGenerator) -> Vector3:
	var west := rng.randf() < 0.5
	var x := rng.randf_range(channel_width * 0.5 + 1.0, half_width - 2.0) * (-1.0 if west else 1.0)
	return to_global(Vector3(x, 0, rng.randf_range(-half_length + 2.0, half_length - 2.0)))


## Host: the next spot a breach bot should drive to, on its way from "from" to "to" (world
## positions). Bots out of the tunnel make for its mouth first, and take a bridge over the channel.
func next_stop(from: Vector3, to: Vector3) -> Vector3:
	var here := to_local(from)
	var there := to_local(to)
	var north_end := -half_length
	if (here.z < north_end) != (there.z < north_end):
		return to_global(Vector3(tunnel_x, here.y, north_end + 1.5 if here.z < north_end else north_end - 1.5))
	var bank := channel_width * 0.5
	if absf(here.x) > bank and absf(there.x) > bank and signf(here.x) != signf(there.x):
		var bridge_z := -8.0 if absf(here.z + 8.0) < absf(here.z - 8.0) else 8.0
		return to_global(Vector3(0, here.y, bridge_z))
	return to


func _build_props() -> void:
	var w := half_width
	var l := half_length

	# Hanging work lights down both walkways: warm pools of light in the green murk.
	for z in range(-int(l) + 4, int(l), 8):
		for x in [-w + 5.0, w - 5.0]:
			LevelKit.add_box(self, Vector3(x, height - 1.6, z), Vector3(0.05, 1.2, 0.05), _metal, false)  # cable
			var bulb := LevelKit.add_box(self, Vector3(x, height - 2.3, z), Vector3(0.3, 0.2, 0.3), _neon, false)
			bulb.set_instance_shader_parameter("instance_tint", work_light_color)
			LevelKit.add_light(self, Vector3(x, height - 2.6, z), work_light_color, 4.0, 12.0)
	# A glow coming up off the water (cold cyan in the Catleones' sewer).
	for z in [-14.0, 0.0, 14.0]:
		LevelKit.add_light(self, Vector3(0, -0.2, z), water_glow_color, 1.2, 6.0)

	# The leader's corner (Don Catleone's): a glow over their spot and crates for a desk.
	var don := npc.position
	LevelKit.add_light(self, Vector3(don.x, 3.0, don.z + 1.0), leader_glow, 3.0, 8.0)
	LevelKit.add_light(self, Vector3(don.x - 1.0, 1.6, don.z + 2.0), Color(1, 0.85, 0.6), 2.0, 5.0)  # lights his face
	LevelKit.add_box(self, Vector3(don.x + 2.2, 0.45, don.z + 0.3), Vector3(1.4, 0.9, 0.9), _crate, true)
	LevelKit.add_box(self, Vector3(don.x + 2.2, 1.2, don.z + 0.3), Vector3(0.9, 0.6, 0.7), _crate, true)

	_build_shop()
	_build_stash()
	_build_workbench()

	_build_mainframe()
	_build_catcam()

	_build_shanties()
	# Crates, trash and junk. (The east-wall crate sits in the corner past the litterbox: z -4 on that
	# wall is the TINKER WORKBENCH's spot now.)
	for spot in [Vector3(-w + 1.0, 0.5, 10), Vector3(-w + 1.0, 0.5, 11.2), Vector3(-w + 1.0, 1.5, 10.6), Vector3(w - 1.0, 0.5, -17.5), Vector3(-4, 0.5, -17)]:
		LevelKit.add_box(self, spot, Vector3.ONE, _crate, true)


## THE MAINFRAME (scripts/mainframe.gd): the rebels' home-made computer on the west wall, scrounged
## together from junk: a big old CRT on a pallet, crates, car batteries, a desk fan, a wok for a dish
## (models/mainframe.glb, made by tools/make_mainframe_spec.py; open models/blockbench/mainframe.bbmodel
## in Blockbench to repaint it). This adds the live parts on top of it:
##   - the big glowing SCREEN + its text (tier + %) and the INTEL line (this district's twist),
##   - the CHARGE GAUGE: 4 glowing battery cells in the rack on its right (they drain one by one),
##   - the light, a solid body, and the E spot (MainframeTerminal: opens its window).
## Everything follows Mainframe Spot's Z (Hub > Mainframe in the Inspector); it always stands on the west wall.
func _build_mainframe() -> void:
	var wall_x := -half_width  # the west wall's inside face
	var z := mainframe_spot.z
	# The model's front (-Z) faces east, into the room: a quarter turn the other way.
	_mainframe_model = LevelKit.instantiate_model("mainframe", self, Vector3(wall_x, 0, z), -PI / 2)
	if _mainframe_model != null:
		_mainframe_model.name = "MainframeModel"
		LevelKit.make_neon_paint_glow(_mainframe_model, {"Glow": 3.0})  # little screens, LEDs, the chute's slot
		_mainframe_fan = _mainframe_model.find_child("Fan", true, false) as Node3D
	# The big screen (in front of the CRT's black bezel), its light, its words.
	_crt_screen = LevelKit.add_box(self, Vector3(wall_x + 1.04, 1.94, z), Vector3(0.04, 2.45, 3.3), _neon, false)
	_crt_screen.set_instance_shader_parameter("instance_tint", Color(0.2, 1, 0.45))
	_crt_light = LevelKit.add_light(self, Vector3(wall_x + 2.5, 2.3, z), Color(0.2, 1, 0.45), 2.5, 8.0)
	# Just the charge % on the screen, big (Mainframe Percent Size in the Inspector).
	_crt_sign = LevelKit.add_sign(self, "75%", Vector3(wall_x + 1.09, 1.94, z), Color(0.0, 0.06, 0.02), mainframe_percent_size, PI / 2)
	# THE CHARGE GAUGE: 4 battery cells stacked in the rack (the model's rack is 2.06..2.94 m along Z).
	var cell_gap := 0.08
	_gauge_cell_height = (3.1 - 0.9 - cell_gap * 3.0) / 4.0
	for i in 4:
		var bottom := 0.9 + i * (_gauge_cell_height + cell_gap)
		LevelKit.add_box(self, Vector3(wall_x + 0.55, bottom + _gauge_cell_height / 2.0, z + 2.5), Vector3(0.62, _gauge_cell_height, 0.66), _pitch_black, false)
		var cell := LevelKit.add_box(self, Vector3(wall_x + 0.57, bottom + _gauge_cell_height / 2.0, z + 2.5), Vector3(0.62, _gauge_cell_height - 0.04, 0.58), _neon, false)
		cell.set_meta("bottom", bottom)
		_gauge_cells.append(cell)
	# Solid, so cats bump into it: the whole pile, plus the chute sticking out at the bottom.
	var body := StaticBody3D.new()
	body.name = "MainframeBody"
	for part in [[Vector3(wall_x + 0.6, 2.0, z), Vector3(1.2, 4.0, 6.0)], [Vector3(wall_x + 1.3, 0.35, z), Vector3(0.4, 0.7, 1.0)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = part[1]
		shape.shape = box
		shape.position = part[0]
		body.add_child(shape)
	add_child(body)
	var terminal := MainframeTerminal.new()
	terminal.name = "MainframeTerminal"
	terminal.hub = self
	terminal.position = mainframe_spot
	terminal.radius = mainframe_radius
	terminal.priority = 10
	add_child(terminal)


## Every frame: the gauge cells fill / drain with THIS gang's charge (the top one shrinks as it
## drains), and the desk fan spins faster the more cells are lit (it sputters when it's empty).
func _update_mainframe_model(delta: float) -> void:
	var mainframe := Mainframe.instance
	if mainframe == null or _gauge_cells.is_empty():
		return
	var charge := mainframe.charge_of(team)
	var colour := mainframe.tier_color(team)
	for i in _gauge_cells.size():
		var cell := _gauge_cells[i]
		var fill := clampf((charge - i * Mainframe.CELL) / Mainframe.CELL, 0.0, 1.0)
		cell.visible = fill > 0.0
		if fill > 0.0:
			cell.scale.y = fill
			cell.position.y = float(cell.get_meta("bottom")) + 0.02 + (_gauge_cell_height - 0.04) * fill / 2.0
			cell.set_instance_shader_parameter("instance_tint", Color(colour * (0.6 + 0.4 * fill), 1.0))
	if _mainframe_fan != null:
		var cells := mainframe.cells(team)
		var speed := 2.0 + 3.0 * cells
		if cells == 0:
			speed = 1.5 if fmod(Time.get_ticks_msec() / 1000.0, 1.3) < 0.3 else 0.0  # sputtering
		_mainframe_fan.rotate_y(speed * delta)


## THE CAT-CAM: a chunky old TV on a crate against the east wall. Press E in front of it to watch a
## teammate up top (scripts/spectator.gd). Built around catcam_spot (Hub > CAT-CAM TV in the Inspector).
func _build_catcam() -> void:
	var at := catcam_spot
	var wall_x := half_width  # inside face of the east wall
	var tv_x := wall_x - 0.75
	LevelKit.add_box(self, Vector3(tv_x, 0.45, at.z), Vector3(1.1, 0.9, 1.4), _crate, true)  # the crate it sits on
	LevelKit.add_box(self, Vector3(tv_x + 0.1, 1.45, at.z), Vector3(0.9, 1.1, 1.3), _metal, true)  # the TV's big back
	var screen := LevelKit.add_box(self, Vector3(tv_x - 0.37, 1.45, at.z), Vector3(0.06, 0.8, 1.0), _neon, false)
	screen.set_instance_shader_parameter("instance_tint", catcam_glow * 0.8)
	# Rabbit-ear antennas, leaning out to each side.
	for side in [-1.0, 1.0]:
		var ear := LevelKit.add_box(self, Vector3(tv_x + 0.1, 2.25, at.z + side * 0.25), Vector3(0.03, 0.6, 0.03), _metal, false)
		ear.rotation.x = side * 0.5
	LevelKit.add_sign(self, "CAT-CAM", Vector3(tv_x - 0.42, 2.15, at.z), catcam_glow * 0.5, 26, -PI / 2)
	LevelKit.add_light(self, Vector3(tv_x - 1.2, 1.5, at.z), catcam_glow, 1.8, 5.0)
	var tv := Interactable.make(self, at, catcam_prompt, catcam_radius, 10)
	tv.name = "CatCamTV"
	tv.used.connect(func(cat: CatPlayer):
		if Spectator.instance != null:
			Spectator.instance.start(cat.slot))


## THE BLACK MARKITTEN: Comrade Whiskers' rebel shop on the west wall. Everything is placed
## around wherever he stands (move ComradeWhiskers under Hub in main.tscn and it follows).
## He faces east (+X); the counter is in front of him, the shelves behind him on the wall.
##
## The whole stall is ONE 3D model: models/black_markitten.glb (made by tools/model_specs/black_markitten.json;
## open models/blockbench/black_markitten.bbmodel in Blockbench to repaint it). It holds the counter (with the
## till and a NO BOTS sign), the wall shelves of dodgy goods, the crates either side, a tin awning and the
## BLACK MARKITTEN banner. The model is made for him standing 2 m out from the wall (his spot in main.tscn).
func _build_shop() -> void:
	var at := shopkeeper.position
	# The model's front (-Z) is the customers' side: a quarter turn makes it face east, into the room.
	var stall := LevelKit.instantiate_model("black_markitten", self, Vector3(at.x, 0, at.z), -PI / 2)
	if stall != null:
		stall.name = "BlackMarkitten"
		LevelKit.make_neon_paint_glow(stall, {"Goods": 2.0, "Screen": 3.0})  # the shelf stock + the till's digits
		LevelKit.make_parts_glow(stall, {"Strip": Color(1, 0.15, 0.1)}, 3.0)  # the counter's red neon edge
		LevelKit.make_parts_glow(stall, {"Banner": banner_color}, 5.0)  # Hub > Banner Color
	# Solid bits (no look, just bumping): the counter and the crates either side. The model is
	# turned a quarter, so "along the wall" is Z here and "out into the room" is +X.
	var body := StaticBody3D.new()
	body.name = "BlackMarkittenBody"
	body.position = Vector3(at.x, 0, at.z)
	add_child(body)
	LevelKit.add_collision(body, Vector3(1.3, 0.5, 0), Vector3(0.9, 1.0, 3.4))  # the counter
	LevelKit.add_collision(body, Vector3(0, 0.5, -2.6), Vector3.ONE)  # crate (north side)
	LevelKit.add_collision(body, Vector3(0, 0.95, 2.6), Vector3(1.0, 1.9, 1.0))  # crate stack (south side)
	# A coloured light over the shop, and a warm one so you can see his face.
	LevelKit.add_light(self, Vector3(at.x + 1.0, 3.2, at.z), shop_light_color, 3.0, 8.0)
	LevelKit.add_light(self, Vector3(at.x + 2.0, 1.8, at.z), Color(1, 0.8, 0.55), 2.5, 4.5)


## CARDBOARD-BOX SHANTIES along the east wall: the "homes" of sewer cats. Each is one 3D model,
## models/box_shanty.glb (made by tools/model_specs/box_shanty.json; open models/blockbench/box_shanty.bbmodel
## in Blockbench to repaint it): a big box with a cat-sized doorway, a blanket curtain, a lit window,
## a box on the roof and a tin-can chimney. Add/move homes by changing SHANTY_SPOTS (along the wall, metres).
const SHANTY_SPOTS: Array[float] = [4.0, 9.0, 14.0]
func _build_shanties() -> void:
	var x := half_width - 1.4  # 2 m deep, backed against the east wall
	for i in SHANTY_SPOTS.size():
		var z := SHANTY_SPOTS[i]
		# The doorway (-Z in the model) faces west, into the room; a tiny skew so they don't look stamped out.
		var home := LevelKit.instantiate_model("box_shanty", self, Vector3(x, 0, z), PI / 2 + [0.0, 0.06, -0.05][i % 3])
		if home != null:
			home.name = "BoxShanty%d" % (i + 1)
			LevelKit.make_neon_paint_glow(home, {"Window": 2.5})  # someone's home: the window's lit
		# Solid, so cats bump into it (same size as the old plain box).
		var body := StaticBody3D.new()
		body.name = "BoxShantyBody%d" % (i + 1)
		body.position = Vector3(x, 0, z)
		add_child(body)
		LevelKit.add_collision(body, Vector3(0, 0.6, 0), Vector3(2.0, 1.2, 2.6))


## THE TINKER WORKBENCH (SEWER UPGRADES): a greasy bench of vacuum parts against the east wall.
## E opens its upgrade page (scripts/upgrades.gd "workbench": DELUXE LITTERBOX, MAINFRAME CAPACITOR).
## Model: models/workbench.glb (made from tools/model_specs/workbench.json; open
## models/blockbench/workbench.bbmodel in Blockbench to repaint it). Moves with Workbench Spot.
func _build_workbench() -> void:
	var at := workbench_spot
	var spot := Interactable.make(self, at, workbench_prompt, workbench_radius, 10)
	spot.used.connect(func(cat: CatPlayer): WorkbenchScreen.for_seat(cat.slot).open(cat, self))  # (scripts/ui/workbench_screen.gd)
	# The bench's front (-Z in the model) faces west, out into the room: a quarter turn.
	var bench := LevelKit.instantiate_model("workbench", self, Vector3(half_width - 0.55, 0, at.z), PI / 2)
	bench.name = "Workbench"
	LevelKit.psx_ify(bench)
	for part in ["Lamp", "Glow"]:
		var mesh := bench.find_child(part, true, false) as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as ShaderMaterial
			if material != null:
				var lit := material.duplicate() as ShaderMaterial
				lit.set_shader_parameter("texture_glow", 3.0)
				mesh.set_surface_override_material(surface, lit)
	# Solid, so cats bump into it instead of walking through.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.95, 2.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(half_width - 0.55, 0.47, at.z)
	add_child(body)
	LevelKit.add_sign(self, "TINKER\nWORKBENCH", Vector3(half_width - 0.05, 2.5, at.z), workbench_light * 0.4, 28, -PI / 2)
	LevelKit.add_light(self, Vector3(half_width - 1.4, 1.9, at.z - 0.4), workbench_light, 2.5, 5.0)


## THE LITTERBOX (the stash): one giant glowing litterbox on the east wall where cats bury their
## gear to keep it safe. Built around stash_spot (change it in the Inspector: Hub > Stash and it
## follows). Colours: Hub > Stash > Litterbox Color / Litterbox Glow / Sand Color.
## (In code it's still called "the stash": ItemManager stash_size, near_stash, get_stash...)
func _build_stash() -> void:
	var at := stash_spot
	# Press E here: the inventory opens with your litterbox in it (scripts/interactable.gd).
	var box := Interactable.make(self, stash_spot, stash_prompt, stash_radius, 10)
	box.used.connect(func(cat: CatPlayer): InventoryScreen.for_seat(cat.slot).open(cat))
	var wall_x := half_width  # inside face of the east wall
	# THE MODEL: models/litterbox.glb (made by tools/make_litterbox_spec.py; open
	# models/blockbench/litterbox.bbmodel in Blockbench to repaint it). Its front (-Z) faces west,
	# into the room: a quarter turn. The plastic + sand are painted GREY in the model, so the two
	# Inspector colours (Litterbox Color, Sand Color) still recolour them here.
	var model := LevelKit.instantiate_model("litterbox", self, Vector3(wall_x, 0, at.z), PI / 2)
	if model != null:
		model.name = "LitterboxModel"
		LevelKit.tint_part(model, "Tray", litterbox_color * 1.5)
		LevelKit.tint_part(model, "Sand", sand_color * 1.45)
		LevelKit.make_neon_paint_glow(model, {"Scoop": 1.2})  # the cyan scoop glows a little
	# The SOLID parts (invisible: the model is what you see). Same size as the model's tray:
	# 2 m deep (out from the wall) x 4 m long, rim 0.5 m high, 0.12 m thick walls.
	var depth := 2.0
	var length := 4.0
	var rim := 0.5
	var t := 0.12
	var cx := wall_x - depth * 0.5  # middle of the tray
	var solid := StaticBody3D.new()
	solid.name = "LitterboxSolid"
	add_child(solid)
	LevelKit.add_collision(solid, Vector3(cx, rim * 0.5, at.z - length * 0.5 + t * 0.5), Vector3(depth, rim, t))  # north end
	LevelKit.add_collision(solid, Vector3(cx, rim * 0.5, at.z + length * 0.5 - t * 0.5), Vector3(depth, rim, t))  # south end
	LevelKit.add_collision(solid, Vector3(wall_x - depth + t * 0.5, rim * 0.5, at.z), Vector3(t, rim, length - t * 2))  # front lip
	# The sand: cats can hop in and stand on it (0.35 m up, like the model's sand).
	LevelKit.add_collision(solid, Vector3(cx + t * 0.5, (rim - 0.15) * 0.5, at.z), Vector3(depth - t, rim - 0.15, length - t * 2))
	# A neon strip along the top of the front lip, and a glowing sign on the wall above.
	var strip := LevelKit.add_box(self, Vector3(wall_x - depth + t * 0.5, rim + 0.045, at.z), Vector3(t + 0.04, 0.04, length - t * 2), _neon, false)
	strip.set_instance_shader_parameter("instance_tint", litterbox_glow)
	LevelKit.add_sign(self, "LITTERBOX", Vector3(wall_x - 0.05, 2.4, at.z), litterbox_glow * 0.4, 32, -PI / 2)
	LevelKit.add_light(self, Vector3(wall_x - 1.6, 2.6, at.z), litterbox_glow, 2.5, 6.0)
