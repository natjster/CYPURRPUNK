extends Node
## CYPURRPUNK — PLAYER FEEDBACK ("game juice"): the little shakes, flashes and dings that tell you
## something happened. Autoload "Feedback" (Project > Project Settings > Globals > Autoload).
##
## What it does:
##   - SCREEN SHAKE: your camera jolts when you get hit, go down, fire a gun, smash a bot, or a bot
##     blows up near you. Strength = SETTINGS > EFFECTS > SCREEN SHAKE (0 = off).
##   - HITMARKER: a little "X" flashes on the crosshair (+ a "tik") when your shot / swing lands.
##     It turns RED with a "ding-DING" when YOU smash an enemy (kill confirm).
##   - HURT FLASH: the edges of your screen flash red when you get hurt, and slowly pulse red while
##     your health is low (scripts/ui/hud_hurt_flash.gd).
##   - LOOT TOASTS: "+ GOLDFISH  $40" slides in on the right when something goes in your backpack
##     (scripts/ui/hud_loot_toast.gd).
##
## Other scripts call (these all do nothing for players who aren't on this computer):
##   Feedback.shake(player_id, 0.3)          # 0 = nothing, 1 = huge
##   Feedback.shake_near(position, 0.5, 12)  # every local cat within 12 m, weaker further away
##   Feedback.hit_landed(seat, crit)         # Hud.damage_number calls this for you
##   Feedback.hurt(player_id, amount)        # cat_health.gd calls it
## Host only:
##   Feedback.enemy_smashed(killer_id, position, is_boss)   # enemy.gd explode() calls it
##
## Split screen: each couch player shakes only their own camera (game_screen.gd copies the
## camera's h_offset / v_offset onto their pane).

# --- Tuning (change the numbers here; they're plain variables, not Inspector fields,
#     because an autoload has no scene to click on) ---

## How far the camera can jolt at full shake (metres, sideways / up-down).
var max_shake_offset: float = 0.22
## How fast shake dies away (per second). Higher = shorter shakes.
var shake_decay: float = 2.6
## How fast the shake wobbles (higher = more buzzy, lower = more wobbly).
var shake_speed: float = 38.0
## Shake when you get hurt, per point of damage (a 20 damage hit = 0.4).
var hurt_shake_per_damage: float = 0.02
## Shake when YOU smash an enemy / a boss.
var kill_shake: float = 0.25
var boss_kill_shake: float = 0.7
## A bot blowing up near you: how hard (right next to it) and how far it reaches (metres).
var boom_shake: float = 0.35
var boom_radius: float = 12.0
var boss_boom_shake: float = 0.9
var boss_boom_radius: float = 30.0
## Shortest gap between two hitmarker "tik" sounds (a shotgun lands 8 pellets at once).
var hitmarker_sound_gap: float = 0.05

## player id -> how much shake ("trauma", 0..1) their camera has right now.
var _trauma: Dictionary = {}
## Cats whose camera we jolted last frame (so we can put it back to 0 when the shake ends).
var _shaking: Dictionary = {}
var _time: float = 0.0
var _last_tik: float = -1.0


func _ready() -> void:
	# The host tells each player when their loot lands in their backpack.
	Events.item_picked_up.connect(_on_item_picked_up)


# --- Screen shake ---

## Shake this player's camera (only if they play on this computer). Adds up, max 1.
func shake(player_id: int, amount: float) -> void:
	if amount <= 0.0 or not PlayerId.is_local(player_id) or Settings.screen_shake <= 0.0:
		return
	_trauma[player_id] = minf(float(_trauma.get(player_id, 0.0)) + amount, 1.0)


## Shake every cat on this computer that is within "radius" metres of "where" (weaker further away).
func shake_near(where: Vector3, amount: float, radius: float) -> void:
	if Game.instance == null:
		return
	for cat in Game.instance.local_cats():
		var distance := cat.global_position.distance_to(where)
		if distance < radius:
			shake(cat.player_id, amount * (1.0 - distance / radius))


func _process(delta: float) -> void:
	_time += delta
	if Game.instance == null:
		return
	for player_id in _trauma.keys():
		var cat := Game.instance.cat_for(player_id)
		var trauma: float = maxf(float(_trauma[player_id]) - shake_decay * delta, 0.0)
		if cat == null or trauma <= 0.0:
			_trauma.erase(player_id)
			if cat != null:
				_still(cat)
			continue
		_trauma[player_id] = trauma
		# Squared, so small knocks stay gentle and big ones really kick. Two different wobbles
		# (sideways, up-down) so it never looks like a straight line.
		var strength := trauma * trauma * max_shake_offset * Settings.screen_shake
		var t := _time * shake_speed + float(player_id % 97)
		cat.camera.h_offset = strength * (sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.4)
		cat.camera.v_offset = strength * (sin(t * 1.3 + 4.1) * 0.6 + sin(t * 2.9) * 0.4)
		_shaking[player_id] = cat


## Put a cat's camera back where it belongs.
func _still(cat: CatPlayer) -> void:
	cat.camera.h_offset = 0.0
	cat.camera.v_offset = 0.0
	_shaking.erase(cat.player_id)


# --- Hits and kills ---

## One of OUR shots / swings just landed (Hud.damage_number calls this): flash the hitmarker.
func hit_landed(seat: int, crit: bool) -> void:
	var marker := Hud.element("Hitmarker", seat) as HudHitmarker
	if marker != null:
		marker.flash(HudHitmarker.CRIT if crit else HudHitmarker.HIT)
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_tik >= hitmarker_sound_gap:
		_last_tik = now
		Sound.play("hitmarker", -6.0)


## Host: "killer_id" just smashed an enemy at "where". Tells the killer's computer (kill confirm)
## and shakes everyone near the explosion.
func enemy_smashed(killer_id: int, where: Vector3, is_boss: bool) -> void:
	if not multiplayer.is_server():
		return
	_boom.rpc(where, is_boss)
	if killer_id == 0:
		return
	if PlayerId.is_local(killer_id):
		_kill_confirmed(killer_id, is_boss)
	else:
		_kill_confirmed.rpc_id(PlayerId.peer_of(killer_id), killer_id, is_boss)


## Host -> everyone: a bot blew up here; shake whoever is close.
@rpc("authority", "call_local", "unreliable")
func _boom(where: Vector3, is_boss: bool) -> void:
	if is_boss:
		shake_near(where, boss_boom_shake, boss_boom_radius)
	else:
		shake_near(where, boom_shake, boom_radius)


## Host -> the killer's computer: you got it! Red hitmarker, ding, a kick.
@rpc("authority", "call_remote", "reliable")
func _kill_confirmed(killer_id: int, is_boss: bool) -> void:
	if not PlayerId.is_local(killer_id):
		return
	var marker := Hud.element("Hitmarker", PlayerId.slot_of(killer_id)) as HudHitmarker
	if marker != null:
		marker.flash(HudHitmarker.BOSS_KILL if is_boss else HudHitmarker.KILL)
	Sound.play("kill_confirm", -2.0 if is_boss else -5.0)
	shake(killer_id, boss_kill_shake if is_boss else kill_shake)
	Seats.rumble(killer_id, 0.5, 0.5 if is_boss else 0.25, 0.25 if is_boss else 0.12)
	print("[Feedback] kill confirmed for player %d (boss %s)" % [killer_id, is_boss])


# --- Getting hurt ---

## One of OUR players lost "amount" HP: red screen edges + a jolt (cat_health.gd calls it).
func hurt(player_id: int, amount: int) -> void:
	if not PlayerId.is_local(player_id):
		return
	shake(player_id, clampf(amount * hurt_shake_per_damage, 0.1, 0.7))
	var flash := Hud.element("HurtFlash", PlayerId.slot_of(player_id)) as HudHurtFlash
	if flash != null:
		flash.flash(amount)


# --- Loot toasts ---

## Host: something went into a player's backpack. Tell their computer.
func _on_item_picked_up(player_id: int, item_id: String) -> void:
	if PlayerId.is_local(player_id):
		_got_item(player_id, item_id)
	else:
		_got_item.rpc_id(PlayerId.peer_of(player_id), player_id, item_id)


## Host -> the owner: show "+ ITEM" on their HUD.
@rpc("authority", "call_remote", "reliable")
func _got_item(player_id: int, item_id: String) -> void:
	if not PlayerId.is_local(player_id) or ItemManager.instance == null:
		return
	var data: ItemData = ItemManager.instance.catalog.get(item_id)
	if data == null:
		return
	var toast := Hud.element("LootToast", PlayerId.slot_of(player_id)) as HudLootToast
	if toast != null:
		toast.add(item_id, data.display_name, data.cash_value)
	Sound.play("loot_get", -8.0)
