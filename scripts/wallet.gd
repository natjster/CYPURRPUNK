class_name Wallet
extends Node
## CYPURRPUNK — THE WALLET: every player's cash. Attach to the "Wallet" node in main.tscn.
## Reach it from anywhere with Wallet.instance.
##
## Who uses it:
##   - The heist (fish_heist.gd) pays you when you extract:   Wallet.instance.earn(id, 120)
##   - The sewer shop (ItemManager.request_buy) takes the price: Wallet.instance.spend(id, 50)
##   - Your save file (player_profile.gd) brings your cash back:  Wallet.instance.set_cash(id, n)
##   - Anyone can ask how rich a player is:                       Wallet.instance.cash_of(id)
## A new way to earn or pay (selling scrap, feeding the MAINFRAME...) just calls earn / spend:
## nothing else needs changing.
##
## It also draws the SCOREBOARD (everyone's cash, richest first, top-right of the HUD), but only
## while you're down in the sewers: up in the city the HUD stays clean.
##
## Multiplayer: the HOST is the referee, same as health and quests. Every computer keeps a copy
## of everyone's cash; only the host changes it, and tells everyone (_set_cash).

## Emitted on EVERY computer when a player's cash changes (after the change).
signal cash_changed(player_id: int, cash: int)

## The one wallet (Wallet.instance).
static var instance: Wallet

## Player ID -> cash. Everyone keeps a copy; only the host changes it (via RPC).
var cash := {}


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	add_to_group(GameSystems.GROUP)  # late joiners and quitting players (game_systems.gd)


# --- Questions anyone can ask (every computer has the answers) ---

## How much cash a player has.
func cash_of(player_id: int) -> int:
	return cash.get(player_id, 0)


## True if this player has a wallet at all (they're playing, or were until just now).
func knows(player_id: int) -> bool:
	return cash.has(player_id)


# --- Changing cash (host only) ---

## Host only: give a player "amount" cash ("why" is for the console log).
func earn(player_id: int, amount: int, why: String = "") -> void:
	if not multiplayer.is_server() or amount == 0:
		return
	_set_cash.rpc(player_id, cash_of(player_id) + amount)
	if why != "":
		print("[Wallet] Player %d +$%d (%s), now $%d" % [player_id, amount, why, cash_of(player_id)])


## Host only: take "amount" from a player's cash (the sewer shop calls this).
## Returns false (and takes nothing) if they can't afford it.
func spend(player_id: int, amount: int) -> bool:
	if not multiplayer.is_server() or cash_of(player_id) < amount:
		return false
	_set_cash.rpc(player_id, cash_of(player_id) - amount)
	return true


## Host only: set a player's cash outright (their save file, or a test's --cash=N).
func set_cash(player_id: int, amount: int) -> void:
	if multiplayer.is_server():
		_set_cash.rpc(player_id, maxi(amount, 0))


## Host -> everyone: this player's cash is now "amount".
@rpc("authority", "call_local", "reliable")
func _set_cash(player_id: int, amount: int) -> void:
	cash[player_id] = amount
	cash_changed.emit(player_id, amount)


# --- Game systems (scripts/game_systems.gd) ---

## Host -> a computer that just joined (network ID "peer"): everyone's cash.
func send_state_to(peer: int) -> void:
	_receive_state.rpc_id(peer, cash)


@rpc("authority", "call_remote", "reliable")
func _receive_state(cash_now: Dictionary) -> void:
	cash = cash_now


## Host: a player quit. Their cash goes with them (it's safe in their own save file).
func player_left(player_id: int, _last_position: Vector3) -> void:
	_forget_player.rpc(player_id)


@rpc("authority", "call_local", "reliable")
func _forget_player(player_id: int) -> void:
	cash.erase(player_id)


# --- HUD: the scoreboard (HUD label "Scoreboard", scenes/ui/hud.tscn) ---

func _process(_delta: float) -> void:
	if Game.instance == null:
		return
	for cat in Game.instance.playing_cats():  # split screen: every player gets their own
		_update_scoreboard(cat)


func _update_scoreboard(my_cat: CatPlayer) -> void:
	var me := my_cat.player_id
	var seat := my_cat.slot
	var in_sewers := not Game.instance.is_up_top(me)
	Hud.show_element("Scoreboard", in_sewers, seat)
	if not in_sewers:
		return
	var rows: Array = []
	for node in Game.instance.players.get_children():
		var cat := node as CatPlayer
		rows.append([cash_of(cat.player_id), cat.get_node("NameTag").text if cat.player_id != me else "YOU"])
	rows.sort_custom(func(a, b): return a[0] > b[0])  # richest first
	var lines := PackedStringArray()
	for row in rows:
		lines.append("%s $%d" % [row[1], row[0]])
	Hud.set_text("Scoreboard", "\n".join(lines), seat)
