class_name CatHealth
extends Node
## CYPURRPUNK — CAT HEALTH, DOWNED CATS, REVIVES, ROBBERIES and KNOCKOUTS. Attach to the "Health"
## node in main.tscn. Reach it from anywhere with CatHealth.instance.
##
## How it plays:
##   - Every cat has max_health hit points (100), shown as the Cyberpunk-style HEALTH BAR
##     top-left of the HUD (scripts/ui/hud_health_bar.gd). Other cats' bars float over their
##     heads once they're hurt (scripts/ui/hud_health_bars.gd).
##   - A VAC-COP bonk takes some (Roomba > Hunting > Bonk Damage, 34 = three bonks and you're
##     down). So do the OTHER GANG's guns (PvP, scripts/teams.gd): each bolt takes the gun's damage
##     (pistol 40, Purr-Tommy 25). Your own gang's bolts do nothing to you (friendly fire is off).
##   - At 0 HP you're DOWNED, not out:
##       * You flop over but KEEP everything you carry. You can only crawl (crawl_speed) and meow
##         for help. VAC-COPs leave you alone.
##       * A GANG-MATE who walks up and HOLDS [E] for revive_seconds picks you back up with
##         revive_health HP, loot and all. Over your head your gang sees a cyan "DOWNED" bar that
##         drains as you bleed out (seen through walls, from far away).
##       * A RIVAL who walks up and HOLDS [E] for rob_seconds ROBS you: your loot bag goes into
##         theirs (what doesn't fit drops on the street). You stay downed.
##       * A RIVAL who SHOOTS you while you're down finishes you off: knocked out on the spot.
##       * Nobody comes within bleed_out_seconds (or you HOLD [E] for give_up_seconds to give
##         up)? You're KNOCKED OUT: EVERYTHING you carry (paws, backpack and loot bag) drops on
##         the street where you fell, you lie there for knockout_seconds, then wake up back in
##         the sewers with nothing. Anyone can go up and grab your stuff: you, a friend... or a rival.
##   - Nobody left in your gang who could save you (solo, or the rest of your gang is down too)?
##     Then there's no waiting: straight to KNOCKED OUT.
##   - The DEEP CLEAN (max heat) knocks out everyone still up top at once, downed or not.
##   - Back down in the sewers (the hub) you're healed to full straight away.
##   - Cats in the car or in the hub can't be hurt.
##   - Every down, knockout, revive and robbery shows in the FEED (top-left, under your health
##     bar: Hud.feed), e.g. "CLAWD DOWNED MITTENS".
##
## Other things can hurt cats too: call  CatHealth.instance.damage(player_id, amount, "WHO")
## ON THE HOST (e.g. a future trap or a dog). "WHO" shows in the feed and on the knocked-out
## screen. Pass instant = true to skip the downed stage (the DEEP CLEAN does).
##
## Multiplayer: the HOST is the referee, same as cash and quests. Damage, going down, revives,
## robberies and knockouts are only ever decided on the host, which tells everyone (_set_health,
## _set_downed, _set_reviving...). Other computers only ASK: request_shot (a bolt hit a rival),
## request_hold (holding E on a downed cat), request_give_up. The host checks every ask makes
## sense (right gang, close enough, sane damage). The downed player's own computer plays the
## fall-over and moves its cat down (owners move their own cat).

@export var max_health: int = 100
## How long a knocked-out cat lies on the street before waking up in the sewers (seconds).
@export var knockout_seconds: float = 3.0

@export_group("Downed and Revives")
## How long a downed cat waits for a gang-mate before it's knocked out (seconds).
@export var bleed_out_seconds: float = 25.0
## How long a gang-mate has to HOLD the interact button (E / Pad X) next to a downed cat (seconds).
@export var revive_seconds: float = 3.0
## How close (metres) a cat must be to start a revive (or robbery). They may drift a little
## further (revive_slack) while holding before it's cancelled.
@export var revive_radius: float = 2.0
@export var revive_slack: float = 1.0
## HP a revived cat gets back (100 = full). 35 = one more bonk and you're down again.
@export var revive_health: int = 35
## How fast a downed cat crawls, compared to walking (0.25 = a quarter speed, 0 = can't move).
@export var crawl_speed: float = 0.25
## How long a downed player holds the interact button to give up (go straight to knocked out).
@export var give_up_seconds: float = 1.5
## How far away (metres) gang-mates see a downed cat's bar, even through walls.
@export var downed_seen_from: float = 150.0

@export_group("PvP (the other gang)")
## How long a rival HOLDS the interact button next to a downed cat to rob its loot bag (seconds).
@export var rob_seconds: float = 2.0
## Can a rival finish off a downed cat by shooting it? (false = shots on downed cats do nothing.)
@export var shots_finish_downed: bool = true
## Seconds after going down when shots can't finish a cat off yet. Without this, the rest of a
## scattergun's pellets (or the Red Dot's beam) would knock it out in the same instant.
@export var finish_grace_seconds: float = 1.5
## The host ignores a "I shot a rival" claim from further away than this (metres; guns reach 60).
@export var pvp_max_range: float = 75.0
## ...or claiming more damage than this in one bolt (a pistol crit is about 90).
@export var pvp_max_damage: int = 120

## Host: player ID -> the clock time (ms) shots may finish them off from (finish_grace_seconds).
var _finish_allowed_at := {}

## The one health node (CatHealth.instance).
static var instance: CatHealth

## Player ID -> hit points. Everyone keeps a copy; only the host changes it (via RPC).
## A player who isn't in the list has full health.
var health := {}
## Player ID -> seconds left before a DOWNED cat bleeds out. Only downed cats are in it.
## Everyone keeps a copy (the host's is the real one; the others count down to show it).
var downed := {}
## Downed player ID -> {"by": who's holding E on it, "left": seconds of holding left,
## "total": seconds the whole hold takes, "rob": true = a rival robbing, false = a revive}.
## Only cats someone is working on right now are in it. Same copies as above.
var reviving := {}

## Host only: downed player ID -> what downed them (for the knocked-out message later).
var _down_cause := {}
## This computer: seat -> seconds the (downed) player in that seat has been holding "give up".
var _give_up_held := {}


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	add_to_group(GameSystems.GROUP)  # late joiners / quitting players / new districts (game_systems.gd)


# --- Questions anyone can ask (every computer has the answers) ---

func get_health(player_id: int) -> int:
	return health.get(player_id, max_health)


## True while a cat is at 0 HP: DOWNED (waiting for a revive) or KNOCKED OUT (on its way to the
## sewers). Roombas leave these cats alone, they can't pick things up or extract.
func is_down(player_id: int) -> bool:
	return get_health(player_id) <= 0


## True while a cat is DOWNED: on the ground, waiting for a gang-mate (can still be revived).
func is_downed(player_id: int) -> bool:
	return downed.has(player_id)


## Seconds a downed cat has left before it bleeds out (0 if it isn't downed).
func bleed_out_left(player_id: int) -> float:
	return downed.get(player_id, 0.0)


## The player ID holding E on this downed cat right now (reviving OR robbing it), or 0.
func reviver_of(player_id: int) -> int:
	return reviving[player_id].by if reviving.has(player_id) else 0


## True while a rival is robbing this downed cat (not reviving it).
func is_being_robbed(player_id: int) -> bool:
	return reviving.has(player_id) and reviving[player_id].get("rob", false)


## 0..1: how far along the revive (or robbery) of this downed cat is (0 = nobody's on it).
func revive_progress(player_id: int) -> float:
	if not reviving.has(player_id):
		return 0.0
	var total: float = reviving[player_id].get("total", revive_seconds)
	return clampf(1.0 - reviving[player_id].left / maxf(total, 0.01), 0.0, 1.0)


# --- Getting hurt (host only) ---

## Host only: take "amount" HP from a player. "cause" = who did it, e.g. "A VAC-COP" or a rival's
## name. At 0 HP they go DOWNED (or straight to KNOCKED OUT if instant, or nobody could save
## them). Does nothing to cats in the hub. Hitting a downed cat again only matters if instant
## (it finishes them off); hitting a knocked-out one does nothing.
func damage(player_id: int, amount: int, cause: String, instant: bool = false) -> void:
	if not multiplayer.is_server() or amount <= 0:
		return
	var cat := Game.instance.cat_for(player_id)
	if cat == null or UndergroundHub.is_in_hub(cat.global_position):
		return
	if is_down(player_id):
		if instant and is_downed(player_id):
			_knock_out(player_id, cause)
		return
	var left := maxi(get_health(player_id) - amount, 0)
	_set_health.rpc(player_id, left)
	if left > 0:
		return
	if instant or not _anyone_could_help(player_id):
		_knock_out(player_id, cause)
	else:
		_go_down(player_id, cause)


## Host: is there any other cat IN THE SAME GANG who could still come and help: on its feet, and
## either up top already or down in the sewers with its trip up still unused (fish_heist.gd
## went_up)? If not, a downed cat would only wait for nothing. (Only gang-mates can revive you:
## scripts/teams.gd.)
func _anyone_could_help(player_id: int) -> bool:
	for other_id in Game.instance.player_ids():
		if other_id == player_id or is_down(other_id) or not Teams.same_team(other_id, player_id):
			continue
		if Game.instance.is_up_top(other_id) or not FishHeist.instance.has_been_up(other_id):
			return true
	return false


## Host: this cat is DOWNED. It keeps its stuff; gang-mates have bleed_out_seconds to revive it.
func _go_down(player_id: int, cause: String) -> void:
	_down_cause[player_id] = cause
	_finish_allowed_at[player_id] = Time.get_ticks_msec() + roundi(finish_grace_seconds * 1000.0)
	print("[Health] Player %d is DOWNED by %s" % [player_id, cause])
	_set_downed.rpc(player_id, bleed_out_seconds, cause)


## Host: KNOCKED OUT for good: everything they carry spills onto the street where they fell,
## and their own computer sends them back down to the sewers.
func _knock_out(player_id: int, cause: String) -> void:
	var cat := Game.instance.cat_for(player_id)
	if cat == null:
		return
	if is_downed(player_id):
		_set_downed.rpc(player_id, -1.0, cause)  # not waiting for a revive any more
	_down_cause.erase(player_id)
	if get_health(player_id) > 0:
		_set_health.rpc(player_id, 0)
	ItemManager.instance.drop_everything(player_id, cat.global_position)
	print("[Health] Player %d was knocked out by %s" % [player_id, cause])
	_knocked_out.rpc(player_id, cause)  # everyone hears it; that player's computer acts on it


## Host only, every physics frame: bleeding out, revives / robberies, and healing in the sewers.
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_run_downed(delta)
	# Cats down in the sewers heal to full.
	# (That's also how a knocked-out cat gets its HP back once it wakes up down there.)
	for node in Game.instance.players.get_children():
		var player_id := (node as CatPlayer).player_id
		if get_health(player_id) < max_health and not is_downed(player_id) \
				and UndergroundHub.is_in_hub((node as Node3D).global_position):
			_set_health.rpc(player_id, max_health)


## Host: count down every downed cat, and finish (or cancel) revives and robberies.
func _run_downed(delta: float) -> void:
	for player_id in downed.keys():
		if Game.instance.cat_for(player_id) == null:
			continue  # left the game (player_left tidies up)
		var cause: String = _down_cause.get(player_id, "A VAC-COP")
		# The rest of the gang is down too? Nobody's coming: no point waiting.
		if not _anyone_could_help(player_id):
			_knock_out(player_id, cause)
			continue
		# Someone's holding E on you: the clock stops while they work (revive or robbery).
		if reviving.has(player_id):
			var by: int = reviving[player_id].by
			if not _can_hold(by, player_id, revive_slack):
				_set_reviving.rpc(player_id, 0, 0.0, false)  # they let go / walked off / went down
			elif reviving[player_id].left - delta <= 0.0:
				if reviving[player_id].rob:
					_rob(player_id, by)
				else:
					_revive(player_id, by)
				continue
			else:
				reviving[player_id].left -= delta  # (everyone else counts down their own copy)
				continue
		downed[player_id] -= delta
		if downed[player_id] <= 0.0:
			_knock_out(player_id, cause)


## Host: back on your feet! Keeps all your stuff.
func _revive(player_id: int, reviver_id: int) -> void:
	_down_cause.erase(player_id)
	_set_reviving.rpc(player_id, 0, 0.0, false)
	_set_downed.rpc(player_id, -1.0, "")
	_set_health.rpc(player_id, revive_health)
	_revived.rpc(player_id, reviver_id)
	print("[Health] Player %d was revived by %d" % [player_id, reviver_id])


## Host: a rival finished robbing a downed cat: its loot bag goes into the robber's.
## (The victim stays downed: their gang can still pick them up, now with an empty bag.)
func _rob(player_id: int, robber_id: int) -> void:
	_set_reviving.rpc(player_id, 0, 0.0, false)
	var taken := ItemManager.instance.steal_bag(player_id, robber_id)
	_robbed.rpc(player_id, robber_id, taken)
	print("[Health] Player %d was robbed by %d (%d loot)" % [player_id, robber_id, taken])


## Host: can "helper" (still) hold E on downed cat "downed_id"? On foot, on its feet, close enough.
## Same gang = a revive. The other gang = a robbery, only while the downed cat has loot.
## slack = extra metres allowed once the hold has started.
func _can_hold(helper_id: int, downed_id: int, slack: float) -> bool:
	var helper := Game.instance.cat_for(helper_id)
	var patient := Game.instance.cat_for(downed_id)
	if helper == null or patient == null or helper == patient or not is_downed(downed_id):
		return false
	if is_down(helper_id) or Game.instance.car_of(helper_id) != null:
		return false
	if helper.team != patient.team and ItemManager.instance.bag_used(downed_id) <= 0 \
			and not is_being_robbed(downed_id):
		return false  # a rival with nothing to rob
	return helper.global_position.distance_to(patient.global_position) <= revive_radius + slack


# --- Asking the host (from the player's own computer) ---

## The shooter's computer -> host: a bolt from "shooter_id" hit cat "target_id" for "amount".
## (cat_player.gd receive_hit sends it; only for the OTHER gang.) The host checks it makes sense.
@rpc("any_peer", "call_local", "reliable")
func request_shot(shooter_id: int, target_id: int, amount: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(shooter_id):
		return
	var shooter := Game.instance.cat_for(shooter_id)
	var target := Game.instance.cat_for(target_id)
	if shooter == null or target == null or shooter.team == target.team:
		return  # friendly fire is off
	if is_down(shooter_id) or not Game.instance.is_up_top(shooter_id) or not Game.instance.is_up_top(target_id):
		return  # (no shooting from the sewers, or at cats down there)
	if Game.instance.car_of(target_id) != null:
		return  # safe inside the car
	if shooter.global_position.distance_to(target.global_position) > pvp_max_range:
		return  # too far to be a real shot
	var who := shooter.display_name()
	if is_downed(target_id):
		if shots_finish_downed and Time.get_ticks_msec() >= _finish_allowed_at.get(target_id, 0):
			_knock_out(target_id, who)  # finished off
		return
	damage(target_id, clampi(amount, 1, pvp_max_damage), who)


## The helper's computer -> host: start (on = true) or stop (on = false) holding E on downed_id.
## Same gang = revive it, the other gang = rob it.
@rpc("any_peer", "call_local", "reliable")
func request_hold(helper_id: int, downed_id: int, on: bool) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(helper_id):
		return
	if on:
		if not reviving.has(downed_id) and _can_hold(helper_id, downed_id, 0.5):
			var rob := not Teams.same_team(helper_id, downed_id)
			_set_reviving.rpc(downed_id, helper_id, rob_seconds if rob else revive_seconds, rob)
	elif reviver_of(downed_id) == helper_id:
		_set_reviving.rpc(downed_id, 0, 0.0, false)


## A downed player's computer -> host: "I give up" (held the interact button).
@rpc("any_peer", "call_local", "reliable")
func request_give_up(player_id: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id) or not is_downed(player_id):
		return
	_knock_out(player_id, _down_cause.get(player_id, "A VAC-COP"))


# --- What the host tells everyone ---

## Host -> everyone: this player's HP is now "hp".
@rpc("authority", "call_local", "reliable")
func _set_health(player_id: int, hp: int) -> void:
	# One of our players got hurt: thump their controller and say ouch.
	# (Their health bar flashes and shows the chip by itself: hud_health_bar.gd.)
	if PlayerId.is_local(player_id) and hp < get_health(player_id) and hp > 0:
		Seats.rumble(player_id, 0.3, 0.7, 0.25)
		Sound.play("hurt")  # (0 HP plays "downed" / "knockout" instead, see below)
	health[player_id] = hp


## Host -> everyone: this player is now DOWNED with "seconds" to bleed out (-1 = not downed any more).
@rpc("authority", "call_local", "reliable")
func _set_downed(player_id: int, seconds: float, cause: String) -> void:
	if seconds < 0.0:
		downed.erase(player_id)
		reviving.erase(player_id)
		return
	downed[player_id] = seconds
	Events.player_downed.emit(player_id, cause)  # every computer hears it (scripts/events.gd)
	var cat := Game.instance.cat_for(player_id)
	if PlayerId.is_local(player_id):
		Seats.rumble(player_id, 0.6, 0.9, 0.5)
		Sound.play("downed")
	if cat != null:
		Sound.play_at("meow", cat.global_position)  # a sad little meow everyone nearby hears
		Hud.feed("%s DOWNED %s" % [cause, cat.display_name()], Teams.color_of(cat.team))
	# (Gang-mates find you by the DOWNED bar over your head: cat_player.gd health_bar_info.)


## Host -> everyone: "by" is holding E on this downed player, "seconds" of holding to go
## (by 0 = stopped). rob = a rival robbing it (not a revive).
@rpc("authority", "call_local", "reliable")
func _set_reviving(downed_id: int, by: int, seconds: float, rob: bool) -> void:
	if by == 0:
		reviving.erase(downed_id)
	else:
		reviving[downed_id] = {"by": by, "left": seconds, "total": seconds, "rob": rob}


## Host -> everyone: this player was just picked up by "by".
@rpc("authority", "call_local", "reliable")
func _revived(player_id: int, by: int) -> void:
	Events.player_revived.emit(player_id, by)
	var cat := Game.instance.cat_for(player_id)
	var helper := Game.instance.cat_for(by)
	if cat != null:
		Sound.play_at("revive", cat.global_position)
		Hud.feed("%s REVIVED %s" % [helper.display_name() if helper != null else "A FRIEND", cat.display_name()],
			Teams.color_of(cat.team))
	if PlayerId.is_local(player_id) and cat != null:
		Seats.rumble(player_id, 0.3, 0.3, 0.3)
		Hud.show_message("%s picked you up." % (helper.display_name() if helper != null else "A friend"), 2.5, cat.slot)
	# (No big popups: the green meter filling up and the cat standing back up say enough.)


## Host -> everyone: rival "by" robbed this downed player of "count" pieces of loot.
@rpc("authority", "call_local", "reliable")
func _robbed(player_id: int, by: int, count: int) -> void:
	Events.player_robbed.emit(player_id, by)
	var cat := Game.instance.cat_for(player_id)
	var robber := Game.instance.cat_for(by)
	var robber_name := robber.display_name() if robber != null else "A RIVAL"
	if cat != null:
		Sound.play_at("pickup", cat.global_position)
		Hud.feed("%s ROBBED %s" % [robber_name, cat.display_name()], Teams.color_of(robber.team if robber != null else 0))
	if PlayerId.is_local(player_id) and cat != null:
		Seats.rumble(player_id, 0.5, 0.2, 0.3)
		Hud.show_message("%s TOOK YOUR LOOT!" % robber_name, 3.0, cat.slot)
	if PlayerId.is_local(by) and robber != null and count > 0:
		Hud.show_message("YOU TOOK %d LOOT FROM %s" % [count, cat.display_name() if cat != null else "THEM"], 3.0, robber.slot)


## Host -> everyone: this player is knocked out. Their own computer makes them fall over, wait,
## and wake up in the sewers.
@rpc("authority", "call_local", "reliable")
func _knocked_out(player_id: int, cause: String) -> void:
	Events.player_knocked_out.emit(player_id, cause)  # every computer hears it (scripts/events.gd)
	var cat := Game.instance.cat_for(player_id)
	if cat != null:
		Hud.feed("%s KNOCKED OUT %s" % [cause, cat.display_name()], Teams.color_of(cat.team))
	if cat == null or not cat.is_multiplayer_authority():
		return
	cat.knocked_out = true  # lies on its side and ignores the keyboard (cat_player.gd)
	Seats.rumble(player_id, 0.8, 1.0, 0.7)  # big shake on their controller
	Sound.play("knockout")
	Hud.show_message("KNOCKED OUT BY %s!\nYour gear and loot are lying in the street." % cause, knockout_seconds + 1.5, cat.slot)
	await get_tree().create_timer(knockout_seconds).timeout
	if is_instance_valid(cat):
		cat.knocked_out = false
		UndergroundHub.of(cat).return_cat(cat)  # wake up down the drain (and get healed there)


## Host -> a computer that just joined (network ID "peer"): everyone's HP, who's downed, revives.
func send_state_to(peer: int) -> void:
	_receive_state.rpc_id(peer, health, downed, reviving)


@rpc("authority", "call_remote", "reliable")
func _receive_state(health_now: Dictionary, downed_now: Dictionary, reviving_now: Dictionary) -> void:
	health = health_now
	downed = downed_now
	reviving = reviving_now


## Host: a new district (or a new game): nobody is lying around up top any more.
func start_district() -> void:
	for player_id in downed.keys():
		_set_downed.rpc(player_id, -1.0, "")
	_down_cause.clear()


## Host: a player quit. (If they were reviving someone, _run_downed cancels it by itself.)
func player_left(player_id: int, _last_position: Vector3) -> void:
	_down_cause.erase(player_id)
	_forget_player.rpc(player_id)


@rpc("authority", "call_local", "reliable")
func _forget_player(player_id: int) -> void:
	health.erase(player_id)
	downed.erase(player_id)
	reviving.erase(player_id)


# --- The "E" on a downed cat (cat_player.gd hands these on: scripts/interactable.gd) ---
# Your own gang: HOLD to REVIVE. The other gang: HOLD to ROB (only if they carry loot).

## How far "helper" is from downed cat "patient", or -1 if helper can't revive / rob it right now.
func downed_distance(patient: CatPlayer, helper: CatPlayer) -> float:
	if patient == helper or not is_downed(patient.player_id) or is_down(helper.player_id):
		return -1.0
	var by := reviver_of(patient.player_id)
	if by != 0 and by != helper.player_id:
		return -1.0  # someone else is already on it
	if patient.team != helper.team and by == 0 and ItemManager.instance.bag_used(patient.player_id) <= 0:
		return -1.0  # a rival with an empty loot bag: nothing to rob
	var distance := patient.global_position.distance_to(helper.global_position)
	var reach := revive_radius + (revive_slack if by == helper.player_id else 0.0)
	return distance if distance <= reach else -1.0


## The HUD prompt line for "helper" next to downed "patient". (The meter itself fills the downed
## cat's health bar: cat_player.gd health_bar_info.)
func downed_prompt(patient: CatPlayer, helper: CatPlayer) -> String:
	var who := patient.display_name()
	var rob := patient.team != helper.team
	if reviver_of(patient.player_id) == helper.player_id:
		return ("ROBBING %s..." if rob else "REVIVING %s...") % who
	return ("HOLD: ROB %s" if rob else "HOLD: REVIVE %s") % who


## "helper" pressed the interact button next to downed "patient": start holding.
## (Letting go is spotted in _process below.)
func start_hold(patient: CatPlayer, helper: CatPlayer) -> void:
	request_hold.rpc_id(1, helper.player_id, patient.player_id, true)


## A little text bar for the HUD: [#####-----].
func _progress_bar(fraction: float, width: int = 10) -> String:
	var filled := clampi(roundi(fraction * width), 0, width)
	return "[" + "#".repeat(filled) + "-".repeat(width - filled) + "]"


# --- Every frame, every computer: count-downs, our players' HUD, letting go, giving up ---

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		# Count down our copies so the bars and numbers move (the host's are the real ones).
		for player_id in downed.keys():
			if not reviving.has(player_id):
				downed[player_id] = maxf(downed[player_id] - delta, 0.0)
		for player_id in reviving.keys():
			reviving[player_id].left = maxf(reviving[player_id].left - delta, 0.0)

	for cat in Game.instance.playing_cats():
		var bar := Hud.element("Health", cat.slot) as HudHealthBar
		if bar != null:
			bar.downed = is_downed(cat.player_id)
			bar.revive_progress = revive_progress(cat.player_id)  # a revive (or robbery) fills our own bar
			bar.being_robbed = is_being_robbed(cat.player_id)
			bar.set_health(get_health(cat.player_id), max_health)
		_watch_hold_button(cat)
		if is_downed(cat.player_id):
			_downed_hud(cat, delta)
		else:
			_give_up_held.erase(cat.slot)


## One of our players is holding E on a downed cat: did they let go of the button (or open a menu)?
func _watch_hold_button(cat: CatPlayer) -> void:
	for downed_id in reviving.keys():
		if reviving[downed_id].by != cat.player_id:
			continue
		var holding := Seats.is_pressed(cat.slot, "interact") and not Hud.wants_input(cat.slot) \
			and not PauseMenu.is_open
		if not holding:
			if not multiplayer.is_server():
				reviving.erase(downed_id)  # (so we only ask once; the host confirms for everyone)
			request_hold.rpc_id(1, cat.player_id, downed_id, false)


## One of our players is downed: show the count-down, and let them hold the button to give up.
func _downed_hud(cat: CatPlayer, delta: float) -> void:
	var key := Hud.key_for("interact", cat.slot)
	var by := reviver_of(cat.player_id)
	var text: String
	if by != 0:
		var helper := Game.instance.cat_for(by)
		var helper_name := helper.display_name() if helper != null else "SOMEONE"
		text = ("%s IS ROBBING YOU!" if is_being_robbed(cat.player_id) else "%s IS REVIVING YOU...") % helper_name
		_give_up_held.erase(cat.slot)
	else:
		var held: float = _give_up_held.get(cat.slot, 0.0)
		if Seats.is_pressed(cat.slot, "interact") and not Hud.wants_input(cat.slot) and not PauseMenu.is_open:
			held += delta
		else:
			held = 0.0
		if held >= give_up_seconds and _give_up_held.get(cat.slot, 0.0) < give_up_seconds:
			request_give_up.rpc_id(1, cat.player_id)  # (once: held stays over the line until reset)
		_give_up_held[cat.slot] = held
		text = "DOWNED! %d\nMEOW FOR HELP - a friend can revive you.\nHOLD [%s] TO GIVE UP %s" % [
			ceili(bleed_out_left(cat.player_id)), key,
			_progress_bar(held / maxf(give_up_seconds, 0.01), 6) if held > 0.0 else ""]
	Hud.show_message(text, 0.25, cat.slot)
