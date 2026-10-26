class_name CatHealth
extends Node
## MEOW-CITY 1999 — CAT HEALTH and KNOCKOUTS. Attach to the "Health" node in main.tscn.
## Reach it from anywhere with CatHealth.instance.
##
## How it plays:
##   - Every cat has max_health hit points (top-left of the HUD, under your cash: "HP ###").
##   - A VAC-COP bonk takes some (Roomba > Hunting > Bonk Damage). At 0 you're KNOCKED OUT:
##     EVERYTHING you carry (paws, backpack and loot bag) drops on the street where you fell.
##     You lie there for knockout_seconds, then wake up back in the sewers with nothing.
##     Anyone can go up and grab your stuff: you, a friend... or a rival.
##   - Back down in the sewers (the hub) you're healed to full straight away.
##   - Cats in the car or in the hub can't be hurt.
##
## Other things can hurt cats too: call  CatHealth.instance.damage(player_id, amount, "WHO")
## ON THE HOST (e.g. a future trap or a dog). "WHO" shows on the knocked-out screen.
##
## Multiplayer: the HOST is the referee, same as cash and quests. Damage is only ever done on
## the host (damage()), which tells everyone the new health (_set_health). The knocked-out
## player's own computer plays the fall-over and moves its cat down (owners move their own cat).

@export var max_health: int = 3
## How long a knocked-out cat lies on the street before waking up in the sewers (seconds).
@export var knockout_seconds: float = 3.0
## Colour of the HP line on the HUD (it flashes white when you get hurt).
@export var hud_color: Color = Color(1, 0.35, 0.45)

## The one health node (CatHealth.instance).
static var instance: CatHealth

## Player ID -> hit points. Everyone keeps a copy; only the host changes it (via RPC).
## A player who isn't in the list has full health.
var health := {}

var _flash_time: float = 0.0



func _enter_tree() -> void:
	instance = self


# --- Questions anyone can ask (every computer has the answers) ---

func get_health(player_id: int) -> int:
	return health.get(player_id, max_health)


## True while a cat is knocked out (0 HP). Roombas leave knocked-out cats alone.
func is_down(player_id: int) -> bool:
	return get_health(player_id) <= 0


# --- Getting hurt (host only) ---

## Host only: take "amount" HP from a player. "cause" = who did it, e.g. "A VAC-COP".
## Does nothing to cats in the hub, or ones already knocked out.
func damage(player_id: int, amount: int, cause: String) -> void:
	if not multiplayer.is_server() or amount <= 0 or is_down(player_id):
		return
	var cat := Game.instance.cat_for(player_id)
	if cat == null or UndergroundHub.is_in_hub(cat.global_position):
		return
	var left := maxi(get_health(player_id) - amount, 0)
	_set_health.rpc(player_id, left)
	if left == 0:
		# Knocked out: everything they carry spills onto the street where they fell.
		ItemManager.instance.drop_everything(player_id, cat.global_position)
		print("[Health] Player %d was knocked out by %s" % [player_id, cause])
		_knocked_out.rpc_id(PlayerId.peer_of(player_id), player_id, cause)  # to that player's computer


## Host only, every physics frame: cats down in the sewers heal to full.
## (That's also how a knocked-out cat gets its HP back once it wakes up down there.)
func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	for node in Game.instance.players.get_children():
		var player_id := (node as CatPlayer).player_id
		if get_health(player_id) < max_health and UndergroundHub.is_in_hub((node as Node3D).global_position):
			_set_health.rpc(player_id, max_health)


# --- What the host tells everyone ---

## Host -> everyone: this player's HP is now "hp".
@rpc("authority", "call_local", "reliable")
func _set_health(player_id: int, hp: int) -> void:
	# Our own first player got hurt? (The one HUD shows them; split screen gives each player their own later.)
	if player_id == PlayerId.first_local() and hp < get_health(player_id):
		_flash_time = 0.6  # we got hurt: flash the HP line
		if hp > 0:
			Sound.play("hurt")  # (0 HP plays "knockout" instead, see _knocked_out)
			Controls.rumble(0.3, 0.7, 0.25)  # thump on the controller
	health[player_id] = hp


## Host -> the knocked-out player's computer: fall over, wait, wake up in the sewers.
@rpc("authority", "call_local", "reliable")
func _knocked_out(player_id: int, cause: String) -> void:
	var cat := Game.instance.cat_for(player_id)
	if cat == null or not cat.is_multiplayer_authority():
		return
	cat.knocked_out = true  # lies on its side and ignores the keyboard (cat_player.gd)
	if player_id == PlayerId.first_local():
		Sound.play("knockout")
		Controls.rumble(0.8, 1.0, 0.7)  # big shake on the controller
		Game.instance.show_message("KNOCKED OUT BY %s!\nYour gear and loot are lying in the street." % cause, knockout_seconds + 1.5)
	await get_tree().create_timer(knockout_seconds).timeout
	if is_instance_valid(cat):
		cat.knocked_out = false
		UndergroundHub.instance.return_cat(cat)  # wake up down the drain (and get healed there)


## Host -> a computer that just joined (network ID "peer"): everyone's HP.
func send_state_to(peer: int) -> void:
	_receive_state.rpc_id(peer, health)


@rpc("authority", "call_remote", "reliable")
func _receive_state(health_now: Dictionary) -> void:
	health = health_now


## Host: a player quit.
func player_left(player_id: int) -> void:
	_forget_player.rpc(player_id)


@rpc("authority", "call_local", "reliable")
func _forget_player(player_id: int) -> void:
	health.erase(player_id)


# --- HUD: "HP ##-" under your cash ---

func _process(delta: float) -> void:
	var me := PlayerId.first_local()
	if Game.instance.my_cat() == null:
		return
	var hp := get_health(me)
	Hud.set_text("Health", "HP " + "#".repeat(hp) + "-".repeat(maxi(max_health - hp, 0)) + ("  KNOCKED OUT" if hp <= 0 else ""))
	_flash_time = maxf(_flash_time - delta, 0.0)
	var blink := _flash_time > 0.0 and fmod(_flash_time, 0.2) < 0.1
	Hud.set_color("Health", Color.WHITE if blink else hud_color)
