class_name Npc
extends StaticBody3D
## CYPURRPUNK — THE NPC FRAMEWORK: any character you can walk up to and talk to.
## Don Catleone (scenes/npcs/don_catleone.tscn) is built on it, and so is the starter
## scene scenes/npcs/npc_template.tscn — duplicate that to make a new NPC (SETUP_GUIDE §8).
##
## Expected node tree (only the root and CollisionShape3D are required):
##   MyNpc (StaticBody3D)      <- this script
##   ├── CollisionShape3D      <- so cats bump into them instead of walking through
##   ├── Model (Node3D)        <- their meshes; turns to look at the nearest cat (optional)
##   │   └── Tail              <- swishes slowly (optional)
##   └── NameTag (Label3D)     <- floating name (group "hud_name_tags": the HUD draws it sharp); text = Npc Name (optional)
##
## Talking: cat_player.gd calls Npc.try_talk() when E is pressed. The nearest NPC in reach
## opens the talk box (NpcDialog) at its FIRST page. The whole conversation is data in the
## Inspector: Pages (NpcPage) -> Choices (NpcChoice). No code needed for a normal chatty NPC.
##
## Special behaviour: a choice's Action word runs here. Built in:
##   send_up_top, return_to_hub, and quest:<id> (gives the player that quest, e.g.
##   quest:mittens_fish — quest cards live in res://quests/, see quest_manager.gd).
## Pages can also depend on a quest's state (NpcPage "Only If Quest"). For anything else, either
##   - make a script that starts with  extends Npc  and write  func _on_action(action, cat):
##   - or connect the action_chosen signal from another node (Node tab > Signals).
##
## SEWER BREACH: every NPC standing directly under a sewer (Hub / GangHub in main.tscn) grabs a gun
## when the bots break in, and fights until the breach ends. It needs no setup: the "Sewer breach"
## group in the Inspector picks their gun and battle cries. (Payphones aren't under a sewer: they
## stay out of it. A sewer NPC with an empty Breach Weapon does too.)
##
## Multiplayer: NPCs aren't networked. Every computer has its own copy standing in the
## same place, and talking only affects YOUR cat. Actions that must change the shared game
## (give items, spend cash...) should ask the host, the same way items do.

## Fired when a choice with an Action is picked (after the built-in actions run).
signal action_chosen(action: String, cat: CatPlayer)

## Shown above the talk box, on the "[E] TALK TO ..." prompt and on the NameTag.
@export var npc_name: String = "STRAY CAT"
## The word on the prompt before the name: "[E] TALK TO STRAY CAT", "[E] USE PAYPHONE".
@export var prompt_verb: String = "TALK TO"
## How close (metres) you must be to talk.
@export var talk_radius: float = 3.0
## The conversation. The first page is the greeting. See npc_page.gd.
@export var pages: Array[NpcPage] = []
## Their talking VOICE: a sound name in sounds/sfx/ (e.g. "meow_blip_don" plays meow_blip_don_1..4.wav),
## chattered while their line types out in the talk box. Empty = silent. New voices are made with the
## Sound Lab (tools/sound_specs/npc_voices.json, SETUP_GUIDE §20).
@export var voice: String = ""

@export_group("Sewer rebellion")
## THE SEWER REBELLION (scripts/upgrades.gd): 0 = always in the sewer (the boss, the shopkeeper,
## payphones...). 1-5 = a RECRUIT: hidden (invisible, no collision, can't be talked to, doesn't fight
## in a breach) until this sewer's gang has recruited this cat (number 1-5 = its workbench tab - 1; any order) at the TINKER WORKBENCH. (NPCs sell no
## upgrades any more: everything is bought at the workbench.)
@export_range(0, 5) var rebellion_tier: int = 0
## ONE QUEST AT A TIME: said instead of handing out a quest when you already have one.
## {giver} = whoever gave you your current job ("me" if it was this NPC). One picked at random.
@export_multiline var busy_lines: PackedStringArray = [
	"You're already on a job for {giver}. Finish that first.",
	"One job at a time, kid. {giver} is still waitin' on you.",
	"Whoa. You're workin' for {giver} right now. Drop that job first if you wanna help me.",
]

@export_group("Idle animation")
## Turn the Model to face the nearest cat.
@export var look_at_players: bool = true
## How far away (metres) a cat can be and still get looked at.
@export var look_range: float = 8.0
## How fast they turn to look (bigger = snappier).
@export var turn_speed: float = 3.0
## How far the Tail swishes (radians). 0 = still.
@export var tail_swish: float = 0.35
## Swishes per second-ish.
@export var tail_speed: float = 1.6

@export_group("Sewer breach")
## The gun they grab: a scene name in res://scenes/items/ ("tommy_gun", "pistol", "red_dot",
## "hairball_blaster", "yarn_zooka", "cucumber_launcher"). Empty = this NPC doesn't fight.
@export var breach_weapon: String = "pistol"
## Yelled now and then over their head, one picked at random.
@export var breach_cries: PackedStringArray = []
## Shown (in red) from when a bot flattens them until the breach ends.
@export var knockdown_cry: String = "OOF! THEY GOT ME!"
## Health a shot takes off a bot (a VAC-COP has 100). Small on purpose: the NPCs help out, they
## don't win the fight for you. Every pellet and every blast counts as one shot.
@export var breach_damage: int = 3
## Seconds between shots. 0 = the gun's own fire rate.
@export var breach_fire_seconds: float = 0.0
## Colour of their shots. Fully see-through (the default) = the gun's own colours.
@export var breach_color: Color = Color(0, 0, 0, 0)
## Bolts per shot. 0 = the gun's own number.
@export var breach_pellets: int = 0
## Sweep slowly from side to side (a laser beam) instead of a random spray.
@export var breach_sweep: bool = false
## How wildly they aim (1 = normal stormtrooper, 2 = twice as bad).
@export var breach_wildness: float = 1.0

@export_group("Sewer breach tuning")
## How far off target a shot can go, sideways and up/down (radians).
@export var breach_yaw_jitter: float = 0.35
@export var breach_pitch_jitter: float = 0.12
## Seconds a hit stuns a bot, and how hard it shoves it (metres per second).
@export var breach_stun: float = 0.15
@export var breach_push: float = 1.0
## They only shoot at bots this close to the middle of their sewer (metres).
@export var breach_search_radius: float = 35.0
## A bot this close knocks them flat (metres).
@export var breach_knockdown_radius: float = 1.8
## How high and how fast they hop on the spot.
@export var breach_hop_height: float = 0.14
@export var breach_hop_speed: float = 14.0
## Where the gun sits on the Model.
@export var breach_gun_spot: Vector3 = Vector3(0.32, 0.55, -0.45)
## Blast guns: seconds in the air, how high the arc goes, how far from the target it can land (metres).
@export var breach_lob_seconds: float = 0.7
@export var breach_lob_height: float = 2.5
@export var breach_lob_scatter: float = 2.5
## How long a battle cry stays up, and the longest wait before the next (seconds).
@export var breach_cry_seconds: float = 2.5
@export var breach_cry_wait: float = 7.0

## Every NPC joins this group, so the cat can find who's nearby.
const GROUP := "npcs"
## Size of the battle cry letters (metres per pixel) and how high it floats over the NPC.
const CRY_PIXEL_SIZE := 0.008
const CRY_HEIGHT := 2.1
const CRY_MAX_DISTANCE := 50.0
## How often (seconds) a fighting NPC picks a target and checks for bots at its feet.
const THINK_SECONDS := 0.1
const CRY_COLOR := Color(1.0, 0.9, 0.3)
const KNOCKDOWN_COLOR := Color(1.0, 0.2, 0.15)

var _model: Node3D
var _tail: Node3D
var _clock: float = 0.0
var _greeting: NpcPage  # the page this conversation started on (its buttons are the "menu")

## True while our sewer is breached and we're fighting (each computer works this out for itself).
var fighting: bool = false
## False while this RECRUIT hasn't joined the rebellion yet (rebellion_tier): hidden and switched off.
var present: bool = true
var _home: UndergroundHub = null  # the sewer we live in (null for payphones up in the city)
var _presence_check: float = 0.0
## True once a bot has flattened us (the host decides, see _knocked_down). Lasts until the breach ends.
var is_knocked_down: bool = false
## Shots this computer has drawn for us, and (host only) how many landed. The test tool prints them.
var breach_shots: int = 0
var breach_hits: int = 0

var _hub: UndergroundHub  # the sewer we defend (null = we stay out of breaches)
var _gun: Weapon
var _muzzle: Node3D
var _cry_label: Label3D
var _aim_at: Vector3
var _think_left: float = 0.0
var _fire_left: float = 0.0
var _cry_left: float = 0.0
var _model_home_position: Vector3
var _model_home_rotation: Vector3


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Interactable.GROUP)  # E talks to us (scripts/interactable.gd)
	_model = get_node_or_null("Model")
	_tail = get_node_or_null("Model/Tail")
	if _model != null:
		_model_home_position = _model.position
		_model_home_rotation = _model.rotation
	_home = get_parent() as UndergroundHub
	if not breach_weapon.is_empty():
		_hub = _home
	# (Whether a RECRUIT is here yet is checked from the first frame on: _process. The game isn't
	# ready to say who's playing while the scene is still loading.)
	var tag := get_node_or_null("NameTag") as Label3D
	if tag != null:
		tag.text = npc_name
	if pages.is_empty():
		push_warning("NPC %s has no Pages: add one in the Inspector so they have something to say." % name)


func _process(delta: float) -> void:
	_clock += delta
	_presence_check -= delta
	if _presence_check <= 0.0:
		_presence_check = 0.25
		_update_presence()
	if not present:
		return  # not recruited yet: not here at all
	if _tail != null:
		_tail.rotation.z = sin(_clock * tail_speed) * tail_swish
	if _hub != null and _hub.breached != fighting:
		if _hub.breached:
			_start_fighting()
		else:
			_stop_fighting()
	if fighting:
		_fight(delta)
	elif look_at_players and _model != null:
		var nearest := _nearest_cat()
		if nearest != null:
			# Measured in the NPC's OWN space (to_local), because Model's rotation is relative to
			# the NPC: an NPC turned in the level (e.g. Rotation Y = 90 in main.tscn) still looks right.
			var to_cat := to_local(nearest.global_position)
			var target_yaw := atan2(-to_cat.x, -to_cat.z)  # same maths as the player cats (face -Z)
			_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


## THE SEWER REBELLION: is this cat in the sewer yet? Every computer works it out from the synced
## upgrades (Upgrades.is_recruited), so a new recruit appears for everyone at once. Recruits can be
## picked in any order, so this checks THIS cat's number, not "how many".
func is_recruited() -> bool:
	return rebellion_tier <= 0 or _home == null or Upgrades.is_recruited(_home.team, rebellion_tier)


## Show / hide this NPC (and switch its collision and fighting off) to match is_recruited().
func _update_presence() -> void:
	var now := is_recruited()
	if now == present:
		return
	present = now
	visible = now
	for shape in find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred("disabled", not now)
	if not now and fighting:
		_stop_fighting()
	if now:
		print("[NPC] %s joined the rebellion (tier %d)" % [npc_name, rebellion_tier])


## Which way this cat faces when nobody's near (its model's own turn in the level). The recruit
## reveal (scripts/recruit_reveal.gd) puts its camera in front of that.
func front_basis() -> Basis:
	var basis := global_basis
	if _model != null:
		basis = basis * Basis.from_euler(_model_home_rotation)
	return basis.orthonormalized()


## THE NEW-RECRUIT POP (scripts/recruit_reveal.gd calls this when our gang recruits us): after
## "delay" seconds we drop in squashed flat, bounce up to full size, and a burst of sparkles in the
## gang colour + a flash of light + a meow go off. delay 0 = straight away. Our name tag stays hidden
## for tag_hidden seconds (the reveal's banner already says the name).
func pop_in(delay: float, tag_hidden: float = 0.0) -> void:
	_update_presence()  # (don't wait for the next presence check: show us now)
	if _model == null:
		return
	var tag := get_node_or_null("NameTag") as Label3D
	_model.rotation = _model_home_rotation  # (face the camera's way, not the last cat we looked at)
	_model.scale = Vector3(0.001, 0.001, 0.001)  # (here, but too small to see until the pop)
	if tag != null:
		tag.visible = false
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func():
		_model.scale = Vector3(1.4, 0.15, 1.4)
		_pop_burst())
	tween.tween_property(_model, "scale", Vector3(0.85, 1.25, 0.85), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if tag != null:
		get_tree().create_timer(maxf(tag_hidden, delay)).timeout.connect(func(): tag.visible = true)


## The sparkles, the flash and the meow of pop_in. Everything cleans itself up after.
func _pop_burst() -> void:
	var color := Teams.color_of(maxi(0, _home.team)) if _home != null else Color(1, 0.85, 0.3)
	var sparks := CPUParticles3D.new()
	sparks.name = "RecruitSparks"
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 60
	sparks.lifetime = 1.1
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.gravity = Vector3(0, -4.0, 0)
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 4.0
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.4
	var box := BoxMesh.new()  # (little cubes, like the gun sparks in weapon.gd: they show up at 240p)
	box.size = Vector3.ONE * 0.08
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.disable_fog = true  # (the sewer fog would swallow them)
	box.material = material
	sparks.mesh = box
	var fade := Gradient.new()  # gang colour -> gold
	fade.offsets = PackedFloat32Array([0.0, 1.0])
	fade.colors = PackedColorArray([color.lightened(0.4), Color(1, 0.85, 0.3)])
	var shrink := Curve.new()  # full size -> gone
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.7, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	sparks.scale_amount_curve = shrink
	sparks.color_ramp = fade
	# (Added to the game, like the bat's sparks in melee_weapon.gd, so they fly free of us.)
	var world: Node = Game.instance if Game.instance != null else get_tree().root
	world.add_child(sparks)
	sparks.global_position = global_position + Vector3(0, 0.5, 0)
	sparks.emitting = true
	get_tree().create_timer(sparks.lifetime + 0.5).timeout.connect(sparks.queue_free)
	var flash := OmniLight3D.new()
	flash.name = "RecruitFlash"
	flash.position = Vector3(0, 1.0, 0)
	flash.light_color = color.lightened(0.4)
	flash.light_energy = 8.0
	flash.omni_range = 5.0
	add_child(flash)
	var dim := flash.create_tween()
	dim.tween_property(flash, "light_energy", 1.0, 0.8)
	dim.tween_property(flash, "light_energy", 0.0, 1.5)
	dim.tween_callback(flash.queue_free)
	Sound.play_at(voice if voice != "" else "meow", global_position)
	Sound.play("buy", -4.0)  # (a little "ta-da" on top)


func _nearest_cat() -> Node3D:
	var nearest: Node3D = null
	var best := look_range
	for cat in Game.instance.players.get_children():
		var d := global_position.distance_to((cat as Node3D).global_position)
		if (cat as Node3D).visible and d < best:
			nearest = cat
			best = d
	return nearest


# --- The E key (scripts/interactable.gd): "[E] TALK TO <name>" when a cat is close ---

func interact_distance(cat: CatPlayer) -> float:
	if fighting or not present:
		return -1.0  # nobody stops to chat in a firefight
	var distance := global_position.distance_to(cat.global_position)
	return distance if distance < talk_radius else -1.0


func interact_prompt(_cat: CatPlayer) -> String:
	return "%s %s" % [prompt_verb, npc_name]


func interact(cat: CatPlayer) -> void:
	talk(cat)


## Talking beats the stash and the car, but a street item right at your feet comes first.
func interact_priority() -> int:
	return 20


# --- The conversation ---

## Start talking: greet with the first page whose quest condition fits (see npc_page.gd).
func talk(cat: CatPlayer) -> void:
	for page in pages:
		if page.fits(cat.player_id):
			_greeting = page
			show_page(cat, page.id)
			return
	push_warning("NPC %s has no page that fits right now (check Only If Quest)." % npc_name)


## Open the talk box on the page with this id. Scripts can call this to jump around too.
func show_page(cat: CatPlayer, page_id: String) -> void:
	var page := _find_page(page_id)
	if page == null:
		push_warning("NPC %s has no page with Id '%s'." % [npc_name, page_id])
		NpcDialog.for_cat(cat).close()
		return
	var lines := page.lines_now()  # (CO-OP: the page's Co-op Lines, if it has any: npc_page.gd)
	var line := "..." if lines.is_empty() else lines[randi() % lines.size()]
	var fallback := _greeting if _greeting != null else pages[0]
	var choices := page.choices if not page.choices.is_empty() else fallback.choices
	var buttons := []
	for choice in choices:
		buttons.append([choice.text, _choose.bind(cat, choice)])
	if buttons.is_empty():
		buttons.append(["BYE", NpcDialog.for_cat(cat).close])  # never leave the player stuck
	NpcDialog.for_cat(cat).open(npc_name, line, buttons, voice)  # in the talking player's own HUD


func _find_page(page_id: String) -> NpcPage:
	for page in pages:
		if page.id == page_id:
			return page
	return null


## A button was clicked: message, then action, then the next page (or close).
func _choose(cat: CatPlayer, choice: NpcChoice) -> void:
	# ONE QUEST AT A TIME: already on a job? Then this NPC says so instead of giving theirs.
	if choice.action.begins_with("quest:") and QuestManager.instance.current_quest(cat.player_id) != "":
		_say_busy(cat)
		return
	if choice.go_to.is_empty():
		NpcDialog.for_cat(cat).close()  # close first, so an action can open something else
	if not choice.message.is_empty():
		var message := choice.message
		if choice.action == "send_up_top":
			# A DISTRICT TWIST (scripts/district_twist.gd): the boss's send-off reminds you of it.
			message = DistrictTwist.send_off_line(message)
		Hud.show_message("%s: %s" % [npc_name, message], 4.0, cat.slot)
	if not choice.action.is_empty():
		_run_action(choice.action, cat)
	if not choice.go_to.is_empty():
		show_page(cat, choice.go_to)


## "You're already on a job for PAULIE. Finish that first." (one of busy_lines) + an OK button.
func _say_busy(cat: CatPlayer) -> void:
	var giver := QuestManager.instance.giver_of(cat.player_id)
	if giver == npc_name:
		giver = "me"
	elif giver == "":
		giver = "somebody else"
	var line := "You're already on a job. Finish that first." if busy_lines.is_empty() \
			else busy_lines[randi() % busy_lines.size()]
	NpcDialog.for_cat(cat).open(npc_name, line.replace("{giver}", giver), [["OK", NpcDialog.for_cat(cat).close]], voice)


func _run_action(action: String, cat: CatPlayer) -> void:
	if action.begins_with("quest:"):
		# "quest:mittens_fish" = give the player that quest (quest_manager.gd asks the host).
		QuestManager.instance.start_quest(cat.player_id, action.trim_prefix("quest:"), npc_name)
	else:
		match action:
			"send_up_top":
				UndergroundHub.of(cat).deploy(cat)  # (the cat's own gang's sewer: hub.gd)
			"return_to_hub":
				UndergroundHub.of(cat).return_cat(cat)
			_:
				_on_action(action, cat)
	action_chosen.emit(action, cat)


## Override this in a script that "extends Npc" to give an NPC its own actions:
##   func _on_action(action: String, cat: CatPlayer) -> void:
##       if action == "pet_me":
##           Hud.show_message("Purrrr.")
func _on_action(action: String, _cat: CatPlayer) -> void:
	if action_chosen.get_connections().is_empty():
		push_warning("NPC %s: nobody handles the action '%s'." % [npc_name, action])


# --- The sewer breach: take up arms ---
# Shots aren't sent over the network: every computer sprays its own (the shots are random anyway),
# and only the HOST's shots hurt the bots. Bot health is synced, so everyone sees the same fight.

func _start_fighting() -> void:
	fighting = true
	is_knocked_down = false
	_think_left = 0.0
	_fire_left = randf_range(0.0, 1.0)  # (so the whole sewer doesn't open fire on the same frame)
	_cry_left = randf_range(0.0, breach_cry_wait * 0.5)
	# Anyone mid-conversation down here has bigger problems now.
	for cat in Game.instance.local_cats():
		if UndergroundHub.hub_at(cat.global_position) == _hub and NpcDialog.is_open_for(cat.slot):
			NpcDialog.for_cat(cat).close()
	_make_cry_label()
	_take_up_gun()


func _stop_fighting() -> void:
	fighting = false
	is_knocked_down = false
	if _gun != null:
		_gun.queue_free()
		_gun = null
		_muzzle = null
	if _cry_label != null:
		_cry_label.hide()
	if _model != null:
		_model.position = _model_home_position
		_model.rotation = _model_home_rotation


func _make_cry_label() -> void:
	if _cry_label != null:
		return
	_cry_label = Label3D.new()
	_cry_label.name = "BattleCryLabel"
	_cry_label.position = Vector3.UP * CRY_HEIGHT
	_cry_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cry_label.pixel_size = CRY_PIXEL_SIZE
	_cry_label.outline_size = 10
	# Too blurry to read at game pixels, so it's a name tag: every HUD (the rival's LIVE FEED too)
	# draws it sharp, as far as a sewer is long.
	_cry_label.add_to_group(HudNameTags.GROUP)
	_cry_label.set_meta("max_distance", CRY_MAX_DISTANCE)
	_cry_label.hide()
	add_child(_cry_label)


## Put a real gun scene in their paws. It's never "held", so its own firing code stays asleep; we
## only use it to draw shots (Weapon.draw_shot), so an NPC's gun looks and sounds like yours.
func _take_up_gun() -> void:
	var path := "res://scenes/items/%s.tscn" % breach_weapon
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	var gun := scene.instantiate() if scene != null else null
	if not gun is Weapon:
		push_warning("NPC %s: Breach Weapon '%s' isn't a gun in res://scenes/items/." % [npc_name, breach_weapon])
		if gun != null:
			gun.free()
		return
	_gun = gun
	if breach_color.a > 0.0:
		_gun.bolt_color = breach_color
		_gun.hot_color = breach_color
		_gun.blast_color = breach_color
	_gun.position = breach_gun_spot
	(_model if _model != null else self as Node3D).add_child(_gun)
	_muzzle = _gun.get_node_or_null("Model/Muzzle")


func _fight(delta: float) -> void:
	_update_cry(delta)
	if is_knocked_down:
		if _model != null:
			_model.rotation.y += delta * 1.2  # spinning slowly on their back, in pain
		return
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = THINK_SECONDS
		_look_for_bots()
		if is_knocked_down:
			return
	if _model != null:
		_model.position.y = _model_home_position.y + absf(sin(_clock * breach_hop_speed)) * breach_hop_height
		var to_target := to_local(_aim_at)
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-to_target.x, -to_target.z), 1.0 - exp(-turn_speed * 3.0 * delta))
	_fire_left -= delta
	if _fire_left <= 0.0 and _gun != null:
		_fire_left = breach_fire_seconds if breach_fire_seconds > 0.0 else 1.0 / _gun.fire_rate
		_shoot()


## Aim at the nearest bot in our sewer (or the tunnel mouth, if none are in yet). Host: a bot at our
## feet knocks us flat.
func _look_for_bots() -> void:
	var nearest: Enemy = null
	var best := INF
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var bot := node as Enemy
		if bot.health <= 0 or bot.is_queued_for_deletion() or UndergroundHub.hub_at(bot.global_position) != _hub:
			continue
		if bot.global_position.distance_to(_hub.global_position) > breach_search_radius:
			continue
		var distance := Motion.flat_distance(bot.global_position, global_position)
		if distance < breach_knockdown_radius and multiplayer.is_server():
			_knocked_down.rpc()
			return
		if distance < best:
			best = distance
			nearest = bot
	if nearest != null:
		_aim_at = nearest.global_position
	else:
		_aim_at = _hub.to_global(Vector3(_hub.tunnel_x, 0.8, -_hub.half_length))


## Host -> everyone: a bot got us. On our back until the breach ends.
@rpc("authority", "call_local", "reliable")
func _knocked_down() -> void:
	if is_knocked_down:
		return
	is_knocked_down = true
	if _gun != null:
		_gun.hide()
	if _model != null:
		_model.position = _model_home_position + Vector3.UP * 0.25  # (the Model's middle is above its feet)
		_model.rotation.x = -PI * 0.48
	Sound.play_at("meow", global_position)
	if _cry_label != null:
		_cry_label.text = knockdown_cry
		_cry_label.modulate = KNOCKDOWN_COLOR
		_cry_label.show()


## Battle cries come and go. (Once knocked down the red one just stays up.)
func _update_cry(delta: float) -> void:
	if is_knocked_down or _cry_label == null or breach_cries.is_empty():
		return
	_cry_left -= delta
	if _cry_left > 0.0:
		return
	if _cry_label.visible:
		_cry_label.hide()
		_cry_left = randf_range(breach_cry_wait * 0.3, breach_cry_wait)
	else:
		_cry_label.text = breach_cries[randi() % breach_cries.size()]
		_cry_label.modulate = CRY_COLOR
		_cry_label.show()
		_cry_left = breach_cry_seconds


func _shoot() -> void:
	breach_shots += 1
	var from := _muzzle.global_position if _muzzle != null else _gun.global_position
	if _gun.blast_radius > 0.0:
		_gun.draw_shot(PackedVector3Array(), 0.0)  # flash and bang now, the blast when it lands
		var landing := _aim_at + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * breach_lob_scatter
		_gun.lob(from, landing, breach_lob_height, breach_lob_seconds, _lob_landed)  # (the same shot a player's gun fires)
		return
	var aim := _sprayed_aim((_aim_at - from).normalized())
	var ends := PackedVector3Array()
	var spread := deg_to_rad(_gun.spread_degrees)
	for i in breach_pellets if breach_pellets > 0 else maxi(_gun.pellets_per_shot, 1):
		ends.append(_shoot_bolt(from, aim.rotated(Vector3.UP, randf_range(-spread, spread))))
	_gun.draw_shot(ends, 0.0)


## Stormtrooper aim: nowhere near perfect. Lasers wave about instead.
func _sprayed_aim(aim: Vector3) -> Vector3:
	var yaw := randf_range(-1.0, 1.0)
	var pitch := randf_range(-1.0, 1.0)
	if breach_sweep:
		yaw = sin(_clock * 1.7)
		pitch = sin(_clock * 2.9)
	var side := aim.cross(Vector3.UP).normalized()
	if side == Vector3.ZERO:
		return aim
	return aim.rotated(Vector3.UP, yaw * breach_yaw_jitter * breach_wildness) \
		.rotated(side, pitch * breach_pitch_jitter * breach_wildness)


## One bolt: finds what it hits (only the host's bolts hurt). Returns where it landed.
func _shoot_bolt(from: Vector3, aim: Vector3) -> Vector3:
	var to := from + aim * _gun.max_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	var bot := Hit.target_of(hit.collider) as Enemy
	if bot != null and multiplayer.is_server():
		_hurt_bot(bot, aim)
	return hit.position


## Host: a shot landed. city_heat 0: only players' shots rile up the city.
func _hurt_bot(bot: Enemy, direction: Vector3) -> void:
	breach_hits += 1
	bot.take_hit(0, breach_damage, breach_stun, Motion.flat(direction).normalized() * breach_push, 0.0)


## It landed (the gun has drawn the blast): on the host, a hit for each bot in range.
func _lob_landed(where: Vector3) -> void:
	if not multiplayer.is_server():
		return
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var bot := node as Enemy
		if bot.global_position.distance_to(where) < _gun.blast_radius:
			_hurt_bot(bot, bot.global_position - where)
