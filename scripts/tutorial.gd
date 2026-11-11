class_name Tutorial
extends Node
## CYPURRPUNK — THE TUTORIAL: a guided training run that walks a new player through one whole
## raid, step by step. Attach to the "Tutorial" node under Main in main.tscn.
## Start it from the menu: PLAY > TUTORIAL (or launch the game with "--tutorial").
##
## What the player sees:
##   - A box at the top of the screen (HUD "TutorialBox") with the current step in yellow and a
##     white line saying what to do.
##   - The real game's big BLUE ARROW (HUD "Compass", scripts/ui/hud_compass_arrow.gd) just under
##     the box, pointing at the thing to go to, with its name and distance ("SHOP  12m").
##     Steps 1-7 and 9: this script points it. Step 8: fish_heist.gd points it, exactly like in a
##     real raid (nearest ringing PAYPHONE first, then the EXIT once you've called).
##   - A glowing cyan beacon (an arrow bobbing over a ring of light) floating above the target
##     (steps 1-7 and 9 only: at step 8 you find the payphone and exit with the blue arrow alone).
##
## The 9 steps (all the text is editable: select Tutorial in main.tscn, Inspector > Step 1..9):
##   PART 1 - THE SEWERS     1 take MITTENS' FISH from Lil' Mittens   2 buy a weapon at the shop
##                           3 open + close the stash lockers         4 visit the Mainframe
##                           5 talk to Don: SEND ME UP TOP
##   PART 2 - THE CITY       6 grab 3 fish   7 smash a VAC-COP, pick up its ELECTRONICS
##                           8 answer a payphone, then extract at the exit manhole
##   PART 3 - BACK HOME      9 feed the electronics to the Mainframe (E opens its window: FEED)  -> TUTORIAL COMPLETE, back to the menu
##
## How it keeps a beginner from getting stuck (only while Game.is_tutorial()):
##   - A training save: $100, an empty stash, nothing read from or written to the real save
##     (scripts/player_profile.gd).
##   - The heat is FROZEN (no surprise Deep Clean). At step 8 it jumps to exit_heat so the exit
##     opens and the payphones ring at once.
##   - Your HP never drops below Min Health (cat_health.gd asks health_floor()).
##   - The 6-slot backpack has room for the 3 fish AND the electronics (they come home in it).
##   - Don won't send you up before step 5 (hub.gd asks allows_deploy()).
##   - Spare fish appear at the centre crossroads if there aren't enough nearby.
##   - A VAC-COP is moved near you at step 7 if none is close, and the one you smash drops ELECTRONICS
##     (normally only the MEGA VAC-COP boss does).
##
## It joins the GAME SYSTEMS (scripts/game_systems.gd): start_district() starts step 1.
## Solo only (a tutorial run is always a one-player game on this computer, so this computer is
## the host and can change the rules directly).
## Test: --tutorial --capture=shots/t.png  (and --tutorial_auto plays all 9 steps by itself).

@export_group("The Training Run")
## The city number for the tutorial (always the same city). Meow-Mart is built right by the
## centre crossroads, next to the manhole you come up from.
@export var city_seed: int = 1999
## Your gang's MAINFRAME charge at the start (%). Feeding the electronics at the end adds 25%.
@export_range(0.0, 100.0, 25.0) var mainframe_charge: float = 75.0
## Your HP never goes below this in the tutorial (so a beginner can't get knocked out).
@export var min_health: int = 25
## The quest Lil' Mittens gives (its id in res://quests/), and how many fish it wants.
@export var quest_id: String = "mittens_fish"
@export var fish_needed: int = 3
## The heat jumps to this at step 8 (the exit opens at 75 heat with the Mainframe at 75%).
## If your Mainframe's exit opens later than this, the heat goes to that number instead.
@export var exit_heat: float = 75.0

@export_group("Helping Out")
## Spare fish: if fewer fish than you still need are lying within this many metres of you,
## one more appears at the centre crossroads every Spare Fish Seconds.
@export var spare_fish_search: float = 80.0
@export var spare_fish_seconds: float = 3.0
## Step 7: if the nearest VAC-COP is further than this (metres), one is moved...
@export var bot_guide_distance: float = 25.0
## ...this far in front of you.
@export var bot_place_distance: float = 12.0
## Step 4: stand this close to the Mainframe (metres) for this long (seconds).
@export var mainframe_visit_distance: float = 3.5
@export var mainframe_visit_seconds: float = 1.5

@export_group("Look")
## The step line (top, big) and the hint line (under it).
@export var step_color: Color = Color(1, 0.9, 0.25)
@export var hint_color: Color = Color(1, 1, 1)
## The beacon over the target: its colour, how high over the target it floats (metres), how far
## it bobs up and down, and how fast it spins.
@export var beacon_color: Color = Color(0.2, 1, 1)
@export var beacon_height: float = 2.6
@export var beacon_bob: float = 0.3
@export var beacon_spin: float = 1.5

@export_group("Finale")
@export var finale_text: String = "TUTORIAL COMPLETE!\nYOU'RE READY FOR MEOW-CITY."
@export var finale_color: Color = Color(0.3, 1, 1)
## How long the banner shows before you go back to the start menu (seconds).
@export var finale_seconds: float = 4.0

# The words: keep each hint to ONE short line (about 50 letters) so the box stays small.
# {E} = your interact key, {TAB} = your inventory key, {fish} = fish in your bag,
# {need} = fish needed, {heat} = the heat the exit opened at.
@export_group("Step 1 - Quest")
@export var step1_title: String = "STEP 1/9: TAKE A QUEST FROM LIL' MITTENS"
@export_multiline var step1_hint: String = "[{E}] Lil' Mittens (east wall) -> accept MITTENS' FISH"
@export_group("Step 2 - Shop")
@export var step2_title: String = "STEP 2/9: BUY A WEAPON"
@export_multiline var step2_hint: String = "[{E}] Comrade Whiskers: buy a PAW-PISTOL or NEON BAT"
@export_group("Step 3 - Stash")
@export var step3_title: String = "STEP 3/9: CHECK THE LITTERBOX"
@export_multiline var step3_hint: String = "[{E}] the glowing LITTERBOX: loot in it is safe"
## Shown if you closed the stash with your weapon still inside it.
@export_multiline var step3_take_back: String = "Take your weapon back: [{E}] the LITTERBOX, click it"
@export_group("Step 4 - Mainframe")
@export var step4_title: String = "STEP 4/9: CHECK THE MAINFRAME"
@export_multiline var step4_hint: String = "Walk to the junk-pile computer. ELECTRONICS keep it charged"
@export_group("Step 5 - Deploy")
@export var step5_title: String = "STEP 5/9: DEPLOY TO THE CITY"
@export_multiline var step5_hint: String = "[{E}] Don Catleone (north end) -> SEND ME UP TOP"
## Don says this if you ask to go up before step 5.
@export_multiline var too_early_to_deploy: String = "Not so fast, kid. Finish your prep down here first - follow the yellow line at the top."
@export_group("Step 6 - Fish")
@export var step6_title: String = "STEP 6/9: GRAB 3 FISH"
@export_multiline var step6_hint: String = "Follow the beacon to Meow-Mart, [{E}] fish ({fish}/{need})"
@export_group("Step 7 - Electronics")
@export var step7_title: String = "STEP 7/9: DESTROY A VAC-COP"
@export_multiline var step7_hint: String = "Shoot or smash the VAC-COP: it drops ELECTRONICS"
@export_multiline var step7_pickup: String = "PICK UP THE PURPLE ELECTRONICS [{E}]!"
## Shown if a VAC-COP bonked a fish out of your bag.
@export_multiline var step7_fish_back: String = "A bot knocked a fish loose! [{E}] it ({fish}/{need})"
@export_group("Step 8 - Payphone + Extract")
## Shown before you've answered a payphone (the blue arrow points at the nearest PAYPHONE).
@export var step8_title: String = "STEP 8/9: FOLLOW THE ARROW TO A PAYPHONE"
@export_multiline var step8_hint: String = "Exit open! [{E}] a ringing PAYPHONE to call Don"
## Shown the moment you've answered (the blue arrow flips to the EXIT).
@export var step8_exit_title: String = "STEP 8/9: FOLLOW THE ARROW TO THE EXIT"
@export_multiline var step8_exit: String = "The arrow points at your EXIT manhole now. Go!"
@export_group("Step 9 - Feed")
@export var step9_title: String = "STEP 9/9: FEED THE MAINFRAME"
@export_multiline var step9_hint: String = "Home! [{E}] the Mainframe, then FEED (+25%)"

const STEPS := 9
const DONE := 10
const POWER_ID := Mainframe.FUEL_ID  # (step 7: the bot drops ELECTRONICS, step 9 feeds them)
const FISH_ID := "fish"

## The one tutorial node (Tutorial.instance).
static var instance: Tutorial

## The step we're on: 0 = not started, 1..9, DONE (10) = finished.
var step: int = 0
## A part of the step: step 3 (1 = weapon left in the stash), 7 (1 = pick up the electronics,
## 2 = get your fish back), 8 (1 = the exit is revealed, go there).
var phase: int = 0

var _beacon: Node3D
var _beacon_arrow: Node3D
var _clock: float = 0.0
var _stash_was_open: bool = false
var _visit_time: float = 0.0
var _charge_before: float = 0.0
var _power_dropped: bool = false
var _spare_fish_left: float = 0.0
var _bot_check_left: float = 0.0
var _finale_left: float = -1.0
var _box_shown: bool = false  # (so a normal game doesn't look the HUD box up every frame)


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	add_to_group(GameSystems.GROUP)  # start_district() starts step 1 (scripts/game_systems.gd)
	process_physics_priority = 100  # after the heat meter, so the frozen heat stays frozen
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	Events.player_extracted.connect(_on_player_extracted)
	_build_beacon()


# --- Asked by other scripts (they all answer "normal game" when it isn't a tutorial) ---

## Is a tutorial running right now?
static func active() -> bool:
	return Game.is_tutorial() and instance != null and is_instance_valid(instance) \
		and instance.step >= 1 and instance.step <= STEPS


## The lowest HP a player can drop to (cat_health.gd). 0 = normal (no floor).
static func health_floor() -> int:
	return instance.min_health if active() else 0


## May Don send this cat up top? (hub.gd) Only from step 5 on in a tutorial.
static func allows_deploy() -> bool:
	return not active() or instance.step >= 5


## game.gd, just before a tutorial game starts: the training-run rules.
func prepare() -> void:
	step = 0
	var mainframe := Mainframe.instance
	mainframe.charges[Teams.CATLEONE] = mainframe_charge


## Host: the game started (game_systems.gd). Off we go.
func start_district() -> void:
	if Game.is_tutorial() and step == 0:
		_go_to(1)


# --- The steps ---

func _go_to(new_step: int) -> void:
	step = new_step
	phase = 0
	_stash_was_open = false
	_visit_time = 0.0
	_power_dropped = false
	if step == 8:
		Sound.play("heat_up")  # the exit just opened
	if step == 9:
		_charge_before = Mainframe.instance.charge_of(Teams.CATLEONE)
	if step == DONE:
		print("[Tutorial] TUTORIAL COMPLETE!")
		_finale_left = finale_seconds
		_beacon.visible = false
		Sound.play("koi_grab")
		Hud.banner(finale_text, finale_seconds, finale_color, 0)
		return
	print("[Tutorial] %s" % _title_of(step).replace("STEP ", "Step "))
	Sound.play("click")


func _process(delta: float) -> void:
	_clock += delta
	if not Game.is_tutorial() or Game.instance == null:
		_hide()
		return
	if step == DONE:
		_hide()
		_finale_left -= delta
		if _finale_left <= 0.0:
			_finale_left = 999.0
			Game.instance._back_to_menu(false)  # (reloads the scene: the start menu is back)
		return
	var cat := Game.instance.my_cat()
	if step < 1 or cat == null:
		_hide()
		return
	_check_step(cat, delta)
	if step == DONE:
		return
	_show(cat, _target(cat))


## Has this step been done yet? (Every frame.)
func _check_step(cat: CatPlayer, delta: float) -> void:
	var me := cat.player_id
	var items := ItemManager.instance
	var hub := UndergroundHub.of(cat)
	match step:
		1:
			if QuestManager.instance.state_of(me, quest_id) == "active":
				_go_to(2)
		2:
			if _has_gear(me):
				_go_to(3)
		3:
			var inventory := InventoryScreen.for_seat(cat.slot)
			if inventory != null and inventory.visible:
				if hub.near_stash(cat):
					_stash_was_open = true
			elif _stash_was_open:
				# Closed again. Make sure they kept a weapon to take up top.
				if _has_gear(me):
					_go_to(4)
				else:
					phase = 1
		4:
			if Motion.flat_distance(cat.global_position, hub.to_global(hub.mainframe_spot)) < mainframe_visit_distance:
				_visit_time += delta
				if _visit_time >= mainframe_visit_seconds:
					_go_to(5)
		5:
			if Game.instance.is_up_top(me):
				_go_to(6)
		6:
			if items.count_in_bag(me, FISH_ID) >= fish_needed:
				_go_to(7)
		7:
			if _power_dropped or items.count_in_bag(me, POWER_ID) > 0:
				phase = 1
				if items.count_in_bag(me, POWER_ID) > 0:
					if items.count_in_bag(me, FISH_ID) >= fish_needed:
						_go_to(8)
					else:
						phase = 2
		8:
			if FishHeist.instance.is_revealed(cat.team):
				phase = 1
			# (Done when Events.player_extracted fires: _on_player_extracted.)
		9:
			if Mainframe.instance.charge_of(cat.team) > _charge_before:
				_go_to(DONE)


## Host, every physics frame: the tutorial's rule changes (frozen heat, spare fish, a nearby bot).
func _physics_process(delta: float) -> void:
	if not active() or not multiplayer.is_server():
		return
	var cat := Game.instance.my_cat()
	if cat == null:
		return
	# The heat is frozen: at the district's starting heat until step 8, then at the exit heat.
	var heat := HeatMeter.instance
	var hold := Mainframe.instance.starting_heat()
	if step >= 8:
		hold = _exit_heat(cat)
	heat.heat = hold
	if step == 6 or (step == 7 and phase == 2):
		_spare_fish(cat, delta)
	if step == 7 and phase == 0:
		_bring_a_bot(cat, delta)


## The heat the exit opens at for this cat's gang (at least exit_heat).
func _exit_heat(cat: CatPlayer) -> float:
	return maxf(exit_heat, Mainframe.instance.exit_heat(cat.team))


## Host: not enough fish nearby? One more appears at the centre crossroads every few seconds.
func _spare_fish(cat: CatPlayer, delta: float) -> void:
	_spare_fish_left -= delta
	if _spare_fish_left > 0.0:
		return
	_spare_fish_left = spare_fish_seconds
	var items := ItemManager.instance
	var still_needed := fish_needed - items.count_in_bag(cat.player_id, FISH_ID)
	var lying := 0
	for id in items.world:
		if items.world[id].item == FISH_ID and Motion.flat_distance(items.world[id].pos, cat.global_position) < spare_fish_search:
			lying += 1
	if lying < still_needed:
		var centre := FishHeist.instance.entry_position(cat.team)
		var angle := randf() * TAU
		items.drop_on_street(FISH_ID, centre + Vector3(cos(angle), 0, sin(angle)) * 3.5)
		print("[Tutorial] A spare fish appears at the crossroads")


## Host, step 7: no VAC-COP close by? Move one over (bot_place_distance in front of the cat).
func _bring_a_bot(cat: CatPlayer, delta: float) -> void:
	_bot_check_left -= delta
	if _bot_check_left > 0.0:
		return
	_bot_check_left = 5.0
	var bot := _nearest_bot(cat)
	if bot == null or bot.global_position.distance_to(cat.global_position) <= bot_guide_distance:
		return
	var camera := GameScreen.instance.camera_for_seat(cat.slot)
	var ahead := -camera.global_basis.z if camera != null else Vector3.FORWARD
	ahead = Vector3(ahead.x, 0, ahead.z).normalized()
	bot.global_position = cat.global_position + ahead * bot_place_distance + Vector3(0, 0.1, 0)
	bot.sync_position = bot.global_position
	print("[Tutorial] Moved %s near the player" % bot.name)


## Host: step 7's bot is smashed -> it drops ELECTRONICS where it stood.
func _on_enemy_destroyed(enemy: Enemy) -> void:
	if not active() or step != 7 or _power_dropped:
		return
	var cat := Game.instance.my_cat()
	if cat == null or (enemy.killed_by != cat.player_id and enemy.killed_by != 0):
		return
	if enemy.is_boss and enemy.drop_on_destroy == POWER_ID:
		_power_dropped = true  # a boss drops its own electronics
		return
	ItemManager.instance.drop_on_street(POWER_ID, enemy.global_position)
	_power_dropped = true
	print("[Tutorial] The smashed VAC-COP dropped ELECTRONICS")


func _on_player_extracted(player_id: int, _loot_value: int, _quest_bonus: int) -> void:
	if active() and step == 8 and player_id == PlayerId.first_local():
		_go_to(9)


# --- Where the beacon goes ---

## The spot the current step wants you to go to (Vector3.INF = nowhere in particular).
func _target(cat: CatPlayer) -> Vector3:
	var hub := UndergroundHub.of(cat)
	match step:
		1:
			return _npc_spot(hub, "LilMittens")
		2:
			return hub.shopkeeper.global_position if hub.shopkeeper != null else Vector3.INF
		3:
			return hub.to_global(hub.stash_spot)
		4, 9:
			return hub.to_global(hub.mainframe_spot)
		5:
			return hub.npc.global_position if hub.npc != null else Vector3.INF
		6:
			return _nearest_item(cat, FISH_ID)
		7:
			if phase == 1:
				return _nearest_item(cat, POWER_ID)
			if phase == 2:
				return _nearest_item(cat, FISH_ID)
			var bot := _nearest_bot(cat)
			return bot.global_position if bot != null else Vector3.INF
		8:
			if phase == 1:
				return FishHeist.instance.exit_for(cat.team)
			return _nearest_payphone(cat)
	return Vector3.INF


func _npc_spot(hub: UndergroundHub, npc_name: String) -> Vector3:
	var npc := hub.get_node_or_null(npc_name) as Node3D
	return npc.global_position if npc != null else Vector3.INF


func _nearest_item(cat: CatPlayer, item_id: String) -> Vector3:
	var items := ItemManager.instance
	var best := Vector3.INF
	for id in items.world:
		var pos: Vector3 = items.world[id].pos
		if items.world[id].item == item_id and (best == Vector3.INF or pos.distance_to(cat.global_position) < best.distance_to(cat.global_position)):
			best = pos
	return best


## The nearest regular VAC-COP (not a boss), or null.
func _nearest_bot(cat: CatPlayer) -> Roomba:
	var best: Roomba = null
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var bot := node as Roomba
		if bot == null or bot.is_boss or bot.is_queued_for_deletion() or bot.health <= 0:
			continue
		if UndergroundHub.is_in_hub(bot.global_position):
			continue
		if best == null or bot.global_position.distance_to(cat.global_position) < best.global_position.distance_to(cat.global_position):
			best = bot
	return best


func _nearest_payphone(cat: CatPlayer) -> Vector3:
	var best := Vector3.INF
	for node in FishHeist.instance.get_children():
		if node is Payphone and not node.is_queued_for_deletion():
			var pos := (node as Node3D).global_position
			if best == Vector3.INF or pos.distance_to(cat.global_position) < best.distance_to(cat.global_position):
				best = pos
	return best


## Does this player carry a weapon or other gear (paws or backpack, not quick-use snacks)?
func _has_gear(player_id: int) -> bool:
	var items := ItemManager.instance
	var inventory := items.get_inventory(player_id)
	for item_id in Array(inventory.get("hands", [])) + Array(inventory.get("pack", [])):
		var data: ItemData = items.catalog.get(item_id)
		if data != null and data.kind == ItemData.Kind.HELD and not data.quick_use:
			return true
	return false


# --- On screen: the HUD box and the beacon ---

func _title_of(n: int) -> String:
	return [step1_title, step2_title, step3_title, step4_title, step5_title, step6_title,
		step7_title, step8_title, step9_title][clampi(n - 1, 0, STEPS - 1)]


func _hint_of(cat: CatPlayer) -> String:
	var hint: String = [step1_hint, step2_hint, step3_hint, step4_hint, step5_hint, step6_hint,
		step7_hint, step8_hint, step9_hint][step - 1]
	if step == 3 and phase == 1:
		hint = step3_take_back
	elif step == 7 and phase == 1:
		hint = step7_pickup
	elif step == 7 and phase == 2:
		hint = step7_fish_back
	elif step == 8 and phase == 1:
		hint = step8_exit
	var fish := mini(ItemManager.instance.count_in_bag(cat.player_id, FISH_ID), fish_needed)
	return hint.replace("{E}", Hud.key_for("interact", cat.slot)) \
		.replace("{TAB}", Hud.key_for("inventory", cat.slot)) \
		.replace("{fish}", str(fish)).replace("{need}", str(fish_needed)) \
		.replace("{heat}", str(int(_exit_heat(cat))))


func _show(cat: CatPlayer, target: Vector3) -> void:
	var seat := cat.slot
	var title := _title_of(step)
	if step == 8 and phase == 1:
		title = step8_exit_title
	_box_shown = true
	Hud.show_element("TutorialBox", true, seat)
	Hud.set_text("TutorialStep", title, seat)
	Hud.set_color("TutorialStep", step_color, seat)
	Hud.set_text("TutorialHint", _hint_of(cat), seat)
	Hud.set_color("TutorialHint", hint_color, seat)
	# The beacon floats over the target (only on the same level as the cat: city or sewers).
	var same_level := target != Vector3.INF and UndergroundHub.is_in_hub(target) == UndergroundHub.is_in_hub(cat.global_position)
	# Step 8 is the real game's way of finding the exit: no beacon, just the blue arrow.
	_beacon.visible = same_level and step != 8
	if _beacon.visible:
		_beacon.global_position = target + Vector3(0, beacon_height + sin(_clock * 2.5) * beacon_bob, 0)
		_beacon_arrow.rotation.y = _clock * beacon_spin
	# THE BLUE ARROW. At step 8 fish_heist.gd drives it (PAYPHONE, then EXIT), so hands off.
	if step != 8:
		_point_compass(cat, target if same_level else Vector3.INF)


func _hide() -> void:
	if _beacon != null:
		_beacon.visible = false
	if _box_shown:
		_box_shown = false
		Hud.show_element("TutorialBox", false, 0)
		var compass := Hud.element("Compass", 0) as HudCompassArrow
		if compass != null:
			compass.hide_arrow()  # (fish_heist.gd takes the arrow back from here)


## Point the big blue arrow (HUD "Compass") at the target, with its name and distance under it
## ("SHOP  12m"). No target (or it's on the other level: city vs sewers) = the arrow hides.
func _point_compass(cat: CatPlayer, target: Vector3) -> void:
	var compass := Hud.element("Compass", cat.slot) as HudCompassArrow
	if compass == null:
		return
	if target == Vector3.INF or GameScreen.instance == null:
		compass.hide_arrow()
		return
	var where := cat.global_position
	var metres := int(Vector2(target.x - where.x, target.z - where.z).length())
	var yaw := FishHeist.instance._screen_angle(where, target, GameScreen.instance.camera_for_seat(cat.slot))
	compass.point_at(yaw, "%s  %dm" % [_compass_name(), metres], false)


## The word under the blue arrow for the current step.
func _compass_name() -> String:
	match step:
		1:
			return "LIL' MITTENS"
		2:
			return "SHOP"
		3:
			return "LITTERBOX"
		4, 9:
			return "MAINFRAME"
		5:
			return "DON CATLEONE"
		6:
			return "FISH"
		7:
			return ["VAC-COP", "ELECTRONICS", "FISH"][clampi(phase, 0, 2)]
	return ""


## The beacon: a glowing upside-down cone (an arrow pointing down at the target) spinning over a
## flat ring, with a light so it glows through the fog. Built once, moved every frame.
func _build_beacon() -> void:
	_beacon = Node3D.new()
	_beacon.name = "Beacon"
	_beacon.top_level = true
	add_child(_beacon)
	var glow := LevelKit.psx_material({"albedo_color": beacon_color, "emission_color": beacon_color, "emission_energy": 4.0})
	_beacon_arrow = Node3D.new()
	_beacon.add_child(_beacon_arrow)
	var cone := CylinderMesh.new()  # top wide, bottom a point: an arrow pointing down
	cone.top_radius = 0.35
	cone.bottom_radius = 0.0
	cone.height = 0.7
	cone.radial_segments = 4
	cone.rings = 1
	var arrow := MeshInstance3D.new()
	arrow.mesh = cone
	arrow.material_override = glow
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon_arrow.add_child(arrow)
	var stem := LevelKit.add_box(_beacon_arrow, Vector3(0, 0.6, 0), Vector3(0.14, 0.5, 0.14), glow, false)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.45
	ring_mesh.outer_radius = 0.6
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 4
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = glow
	ring.position = Vector3(0, -0.6, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(ring)
	LevelKit.add_light(_beacon, Vector3.ZERO, beacon_color, 2.0, 5.0)
	_beacon.visible = false
