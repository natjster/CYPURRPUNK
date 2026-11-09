class_name RaidReport
extends Node
## CYPURRPUNK — THE RAID REPORT: when a district ends, every player gets a report card for the
## round before the next district starts. Attach to the "RaidReport" node in main.tscn.
##
## WHAT IT SHOWS (drawn by scripts/ui/raid_report_screen.gd, one per player, in their own HUD):
##   - a title, the district number and how it ended for the crew: CLEAN GETAWAY, MESSY GETAWAY
##     (someone got vacuumed), CAUGHT IN THE DEEP CLEAN, NOBODY LEFT THE COUCH, SURVIVED THE
##     SEWER BREACH, or WIPED OUT BY THE BREACH
##   - one CARD per cat: name, how the raid ended for them (EXTRACTED / VACUUMED / STAYED HOME /
##     LEFT EARLY), cash brought home (the quest bonus shown separately), VAC-COPs smashed
##     (MEGA VAC-COPs called out), times downed, team-mates revived
##   - one SILLY AWARD per cat, revealed last (the clip!). Awards are cards in res://raid_awards/
##     (scripts/raid_award.gd explains how to add one)
##   - the crew's total cash, and a small Discord invite line (Discord Invite below; empty = hidden)
##   TURF WAR: the same cards, grouped under each gang's name and colour. No scores, no winner.
##   No report in the TUTORIAL, or behind the start menu's showcase city.
##
## HOW LONG IT HOLDS THE NEXT DISTRICT: the report is up for Report Seconds. Every player can
## press READY; once every player is ready (and the awards have all been shown) the next district
## starts at once. Down in the sewers nothing can hurt anyone meanwhile: the hatch is sealed, so
## nobody can go up, the heat is already maxed, and the cats' buttons go to the report.
##
## HOW IT GETS ITS NUMBERS (host only): it listens to the EVENTS autoload (scripts/events.gd) all
## district long: went up, extracted, downed, revived, knocked out, robbed, hurt, loot vacuumed,
## enemy destroyed, the breach ending, and (Phase 1) mess made. Nothing else calls into it except
## the two places a district ENDS, which call RaidReport.end_district() instead of
## Game.new_district(): fish_heist.gd (after the DEEP CLEAN / the all-home rush) and
## mainframe.gd (after a SEWER BREACH's banner). It starts the new district itself when done.
## The host builds the finished report (numbers + awards) and sends ONE message to every
## computer, so every screen shows exactly the same thing. All numbers are kept by PLAYER id
## (scripts/player_id.gd): couch players on one computer get their own cards.
##
## Testing: --raid_report[=N] (host) shows a report right now with made-up numbers (N = that many
## cards, made-up quitters fill the gap); every computer prints "DevCapture report:" lines.

## The one report node (RaidReport.instance).
static var instance: RaidReport

## Where the award cards are (every .tres file in it is loaded).
const AWARDS_FOLDER := "res://raid_awards/"

@export_group("Timing")
## Switch the report off completely (districts then change straight away, like before).
@export var enabled: bool = true
## The longest the report stays up (seconds), unless everyone presses READY sooner. With many
## cats it stays up a little longer by itself, so every award gets seen.
@export var report_seconds: float = 14.0
## After the last award shows up, the report stays at least this long (seconds), even if everyone
## is already READY (so the awards can't be skipped: they're the punchline).
@export var read_seconds_after_awards: float = 2.0
## The reveal: pause before the first card (seconds)...
@export var intro_seconds: float = 0.8
## ...then one card every this many seconds...
@export var card_seconds: float = 0.45
## ...then a pause, and one AWARD every this many seconds (with a stamp sound).
@export var award_seconds: float = 0.75

@export_group("Extras")
## A line at the bottom of the report, e.g. "JOIN THE CREW: discord.gg/abc123". Empty = no line.
## (ROADMAP section 6: every stranger who plays sees the invite.) The host's text is the one shown.
@export var discord_invite: String = ""
## MESS MADE: the number of messes each cat made. Hidden until mess-making exists (Phase 1).
## Tick this when it does: the line appears on every card. (The number comes from
## Events.mess_made: see scripts/events.gd.)
@export var show_mess_stat: bool = false

@export_group("Colours")
@export var extracted_color: Color = Color(0.5, 1, 0.55)
@export var vacuumed_color: Color = Color(1, 0.4, 0.35)
@export var stayed_home_color: Color = Color(0.7, 0.7, 0.8)
@export var good_ending_color: Color = Color(0.5, 1, 0.55)
@export var bad_ending_color: Color = Color(1, 0.4, 0.35)

## Every award card, in hand-out order (lowest "order" first).
var awards: Array[RaidAward] = []
## True while a report is up (on every computer).
var showing: bool = false
## The report on screen now (every computer), or {} (see _build for what's in it).
var current: Dictionary = {}
## Player IDs that pressed READY, and the ones the host waits for (every computer).
var ready_ids: Array = []
var waiting_for: Array = []

## Host: the numbers so far this district, player ID -> one card's numbers (see _new_stats).
var _stats: Dictionary = {}
## Host: which district this is (1 = the first of the game).
var _district: int = 0
## Host: how a SEWER BREACH ended this district ("" = there wasn't one).
var _breach_ending: String = ""
## Host: did the DEEP CLEAN catch anyone up top?
var _deep_cleaned: bool = false
## Host: seconds the report has been up, and the soonest it may end / the latest it will.
var _elapsed: float = 0.0
var _earliest_end: float = 0.0
var _latest_end: float = 0.0


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	add_to_group(GameSystems.GROUP)  # start_district / send_state_to / player_left (game_systems.gd)
	_load_awards()
	# The district's moments (scripts/events.gd). Each handler counts on the HOST only.
	Events.player_went_up.connect(func(id, _first): _count(id, "went_up", 1, true))
	Events.player_extracted.connect(_on_extracted)
	Events.player_downed.connect(func(id, _cause): _count(id, "downs", 1))
	Events.player_revived.connect(func(_id, by): _count(by, "revives", 1))
	Events.player_robbed.connect(func(_id, by): _count(by, "robbed", 1))
	Events.player_knocked_out.connect(_on_knocked_out)
	Events.player_hurt.connect(func(id, amount, _cause): _count(id, "damage", amount))
	Events.loot_vacuumed.connect(func(id, _item): _count(id, "vacuumed", 1))
	Events.mess_made.connect(func(id, amount): _count(id, "mess", amount))
	Events.enemy_destroyed.connect(_on_enemy_destroyed)
	Events.sewer_breach_ended.connect(_on_breach_ended)


## Every award card in res://raid_awards/, sorted by their Order number.
func _load_awards() -> void:
	for file in DirAccess.get_files_at(AWARDS_FOLDER):
		file = file.trim_suffix(".remap")  # (exported games rename resources)
		if not file.ends_with(".tres"):
			continue
		var card := load(AWARDS_FOLDER + file) as RaidAward
		if card != null and card.id != "":
			awards.append(card)
	awards.sort_custom(func(a: RaidAward, b: RaidAward) -> bool:
		return a.order < b.order if a.order != b.order else a.id < b.id)  # (same order on every computer)


# --- Counting (host only) ---

## One card's numbers before anything happened.
func _new_stats(player_id: int) -> Dictionary:
	return {"id": player_id, "name": "CAT", "team": 0, "swatch": Color(0.6, 0.6, 0.6),
		"loot": 0, "bonus": 0, "bots": 0, "bosses": 0, "downs": 0, "revives": 0, "damage": 0,
		"vacuumed": 0, "knockouts": 0, "robbed": 0, "went_up": 0, "extracted": 0, "left": 0,
		"mess": 0, "ending": ""}


## Host: this player's numbers (made the first time we hear of them), with their name and look
## brought up to date while their cat is still here.
func _row(player_id: int) -> Dictionary:
	if not _stats.has(player_id):
		_stats[player_id] = _new_stats(player_id)
	var row: Dictionary = _stats[player_id]
	var cat := Game.instance.cat_for(player_id) if Game.instance != null else null
	if cat != null:
		row.name = cat.display_name()
		row.team = cat.team
		var fur: Variant = cat.look.get("fur") if cat.look is Dictionary else null
		if fur is Color:
			row.swatch = fur
	return row


## Host: add "amount" to one of a player's numbers (set = use it as the new value instead).
func _count(player_id: int, stat: String, amount: int, set_it: bool = false) -> void:
	if not multiplayer.is_server() or player_id == 0 or showing:
		return
	var row := _row(player_id)
	row[stat] = amount if set_it else int(row.get(stat, 0)) + amount


func _on_extracted(player_id: int, loot_value: int, quest_bonus: int) -> void:
	if not multiplayer.is_server() or showing:
		return
	var row := _row(player_id)
	row.loot += loot_value
	row.bonus += quest_bonus
	row.extracted = 1
	row.ending = "EXTRACTED"


func _on_knocked_out(player_id: int, cause: String) -> void:
	if not multiplayer.is_server() or showing:
		return
	var row := _row(player_id)
	row.knockouts += 1
	if row.ending != "EXTRACTED":  # (home already: a KO in a breached sewer doesn't undo that)
		row.ending = "VACUUMED"
	# Knocked out after the hatch sealed (by the swarm, or by the DEEP CLEAN's final sweep) =
	# the crew got caught in the DEEP CLEAN. (A breach knockout in the sewers is the breach's story.)
	var heist := FishHeist.instance
	if cause == "THE DEEP CLEAN" or (heist != null and heist.sealed and Game.instance.is_up_top(player_id)):
		_deep_cleaned = true


func _on_enemy_destroyed(enemy: Enemy) -> void:
	if enemy.killed_by == 0:
		return  # (nobody's kill: e.g. THE 1% MIRACLE blowing the bots up)
	_count(enemy.killed_by, "bots", 1)
	if enemy.is_boss:
		_count(enemy.killed_by, "bosses", 1)


func _on_breach_ended(survived: bool) -> void:
	if multiplayer.is_server():
		_breach_ending = "breach_survived" if survived else "wiped_out"


# --- The game systems framework (scripts/game_systems.gd), host only ---

## Host: a new game or district: fresh numbers.
func start_district() -> void:
	_stats.clear()
	_breach_ending = ""
	_deep_cleaned = false
	_district += 1


## Host: a player quit. Their card stays on the report (marked LEFT EARLY if they never made it
## home), with the name they had.
func player_left(player_id: int, _last_position: Vector3) -> void:
	if showing:
		waiting_for.erase(player_id)
		_set_ready.rpc(ready_ids, waiting_for)
		return
	var row := _row(player_id)  # (their cat still exists right now: the name is kept)
	row.left = 1


## Host: a computer joined while a report is up: show them the rest of it.
func send_state_to(peer: int) -> void:
	if showing:
		var late := current.duplicate()
		late.seconds_left = maxf(_latest_end - _elapsed, 1.0)
		late.skip_reveal = true  # (they missed the drum roll)
		_show_report.rpc_id(peer, late)
		_set_ready.rpc_id(peer, ready_ids, waiting_for)


# --- Ending a district ---

## The district is over: show the report, then start the next district. Called by fish_heist.gd
## and mainframe.gd in place of Game.new_district(). Host only. Safe to call twice (the second
## call is ignored while the report is up).
static func end_district() -> void:
	if instance == null or not is_instance_valid(instance):
		Game.instance.new_district()
		return
	instance._end_district()


func _end_district() -> void:
	if showing:
		return
	# No report in the tutorial, with nobody playing (the start menu's showcase city), or when
	# switched off: straight on, like before.
	if not enabled or Game.is_tutorial() or Game.instance.player_count() == 0:
		Game.instance.new_district()
		return
	var report := build_report()
	_show_report.rpc(report)
	_set_ready.rpc([], _waiting_list(report))


## Host: everything on the report, worked out once (numbers, endings, awards, timing).
## Sent as one message, so every computer shows exactly the same.
func build_report() -> Dictionary:
	# The cards: everyone playing now (in join order), then anyone who quit during the district.
	var ids: Array = []
	for player_id in Game.instance.player_ids():
		ids.append(player_id)
	for player_id in _stats:
		if not player_id in ids:
			ids.append(player_id)
	var rows: Array = []
	for player_id in ids:
		var row: Dictionary = _row(player_id).duplicate()
		row.cash = int(row.loot) + int(row.bonus)
		if row.ending == "":
			if row.left:
				row.ending = "LEFT EARLY"
			elif row.went_up:
				row.ending = "LOST IN THE CITY"  # (up top at the very end: only happens in tests)
			else:
				row.ending = "STAYED HOME"
		rows.append(row)
	# TURF WAR: grouped by gang (stable: join order stays inside each gang).
	var turf := Game.is_turf_war()
	if turf:
		var by_team: Array = []
		for team in Teams.count():
			by_team += rows.filter(func(row): return int(row.team) == team)
		rows = by_team
	# One silly award each (in this final order: ties go to the card nearer the top).
	var given := assign_awards(rows, awards)
	for i in rows.size():
		var card: RaidAward = given[i]
		var row: Dictionary = rows[i]
		row.award_id = card.id if card != null else "honourable"
		row.award_title = card.title if card != null else "HONOURABLE MEOWTION"
		row.award_line = _award_line(card, row) if card != null else "#%d" % (i + 1)
		row.award_color = card.color if card != null else Color.WHITE
		row.ending_color = extracted_color if row.ending == "EXTRACTED" else \
			(vacuumed_color if row.ending == "VACUUMED" else stayed_home_color)
		row.color = Seats.color(i)  # each card's name in its own colour, the same on every screen
	# The gangs (CO-OP: just the one crew).
	var gangs: Array = []
	var total := 0
	for team in (Teams.count() if turf else 1):
		var gang_total := 0
		for row in rows:
			if not turf or int(row.team) == team:
				gang_total += int(row.cash)
		total += gang_total
		if not turf or rows.any(func(row): return int(row.team) == team):
			gangs.append({"team": team if turf else -1, "name": Teams.name_of(team) if turf else "THE CREW",
				"color": Teams.color_of(team) if turf else Color(1, 0.45, 0.85), "total": gang_total})
	var ending := _crew_ending(rows)
	var reveal_end := intro_seconds + rows.size() * card_seconds + 0.4 + rows.size() * award_seconds
	return {"district": _district, "ending": ending[0], "ending_color": ending[1], "total": total,
		"turf": turf, "rows": rows, "gangs": gangs, "invite": discord_invite, "show_mess": show_mess_stat,
		"intro": intro_seconds, "card": card_seconds, "award": award_seconds,
		"reveal_end": reveal_end, "seconds_left": maxf(report_seconds, reveal_end + read_seconds_after_awards + 2.0),
		"skip_reveal": false}


## How the district ended for the crew: [text, colour].
func _crew_ending(rows: Array) -> Array:
	if _breach_ending == "breach_survived":
		return ["SURVIVED THE SEWER BREACH", good_ending_color]
	if _breach_ending == "wiped_out":
		return ["WIPED OUT BY THE BREACH", bad_ending_color]
	if _deep_cleaned:
		return ["CAUGHT IN THE DEEP CLEAN", bad_ending_color]
	if not rows.any(func(row): return int(row.went_up) > 0):
		return ["NOBODY LEFT THE COUCH", stayed_home_color]
	if rows.any(func(row): return row.ending == "VACUUMED"):
		return ["MESSY GETAWAY", Color(1, 0.85, 0.3)]
	return ["CLEAN GETAWAY", good_ending_color]


## The award's small line with the number filled in.
static func _award_line(card: RaidAward, row: Dictionary) -> String:
	return card.line.replace("{value}", str(int(_value(row, card.stat))))


## One of a card's numbers (an empty stat = 0: the safety-net awards).
static func _value(row: Dictionary, stat: String) -> float:
	return float(row.get(stat, 0)) if stat != "" else 0.0


## THE AWARD RULES (scripts/raid_award.gd explains them for humans): award cards are tried in
## order; each goes to the best cat that has none yet and qualifies; a tie goes to the cat
## nearer the top. Returns one card per row (null only if there are more cats than cards).
static func assign_awards(rows: Array, cards: Array[RaidAward]) -> Array:
	var given: Array = []
	given.resize(rows.size())
	var left := rows.size()
	for card in cards:
		if left == 0:
			break
		var best := -1
		for i in rows.size():
			if given[i] != null:
				continue
			var row: Dictionary = rows[i]
			var value := _value(row, card.stat)
			if value < card.at_least or value > card.at_most:
				continue
			if card.needs != "" and _value(row, card.needs) < 1.0:
				continue
			if best == -1:
				best = i
				continue
			var best_value := _value(rows[best], card.stat)
			# Strictly better only: on a tie the earlier card (smaller i) keeps it.
			if (card.pick == RaidAward.Pick.MOST and value > best_value) or \
					(card.pick == RaidAward.Pick.LEAST and value < best_value):
				best = i
		if best != -1:
			given[best] = card
			left -= 1
	return given


## The players the host waits for: everyone on the report who is still in the game.
func _waiting_list(report: Dictionary) -> Array:
	var ids := Game.instance.player_ids()
	var list: Array = []
	for row in report.rows:
		if int(row.id) in ids:
			list.append(int(row.id))
	return list


# --- What the host tells everyone ---

## Host -> everyone: the report goes up on every local player's screen.
@rpc("authority", "call_local", "reliable")
func _show_report(report: Dictionary) -> void:
	showing = true
	current = report
	ready_ids = []
	if multiplayer.is_server():
		_elapsed = 0.0
		_earliest_end = float(report.reveal_end) + read_seconds_after_awards
		_latest_end = float(report.seconds_left)
	for cat in Game.instance.playing_cats():
		var screen := RaidReportScreen.for_seat(cat.slot)
		if screen != null:
			screen.open(report)
	Events.raid_report_shown.emit(report)  # (scripts/events.gd; DevCapture prints it)


## Host -> everyone: who is ready, and who we're waiting for.
@rpc("authority", "call_local", "reliable")
func _set_ready(ready_list: Array, waiting_list: Array) -> void:
	ready_ids = ready_list.duplicate()
	waiting_for = waiting_list.duplicate()


## Host -> everyone: the report comes down (the next district is being built).
@rpc("authority", "call_local", "reliable")
func _hide_report() -> void:
	print("[RaidReport] Report closed")
	showing = false
	current = {}
	for seat in Hud.huds.size():
		var screen := RaidReportScreen.for_seat(seat)
		if screen != null:
			screen.close()


## A player pressed READY (any computer -> host).
@rpc("any_peer", "call_local", "reliable")
func request_report_ready(player_id: int) -> void:
	if not multiplayer.is_server() or not PlayerId.sender_owns(player_id) or not showing:
		return
	if not player_id in ready_ids:
		var now := ready_ids.duplicate()
		now.append(player_id)
		_set_ready.rpc(now, waiting_for)


## Has this player pressed READY?
func is_ready(player_id: int) -> bool:
	return player_id in ready_ids


## How many of the players we wait for are ready: [ready, out of].
func ready_count() -> Array:
	return [waiting_for.filter(func(id): return id in ready_ids).size(), waiting_for.size()]


## Host: count the report down; start the next district when time's up, or everyone's ready.
func _process(delta: float) -> void:
	if not showing or not multiplayer.is_server():
		return
	_elapsed += delta
	var counts := ready_count()
	var all_ready: bool = counts[0] >= counts[1]  # (everyone quit = ready too)
	if _elapsed >= _latest_end or (all_ready and _elapsed >= _earliest_end):
		print("[RaidReport] Next district (%s)" % ("everyone ready" if all_ready else "time up"))
		_hide_report.rpc()
		Game.instance.new_district()


# --- Testing (DevCapture --raid_report) ---

## Host: fill in made-up numbers for everyone (and "extra" made-up quitters), then end the
## district now, so the report shows.
func test_report(cards: int) -> void:
	if not multiplayer.is_server():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1999
	var fake_names := ["MITTENS", "SIR PURRCIVAL", "BEANS", "CHAIRMAN MEOW", "NOODLE", "GRUB", "TOAST"]
	var ids: Array = Game.instance.player_ids()
	for i in maxi(cards - ids.size(), 0):
		var fake_id := PlayerId.make(9000 + i, 0)
		var row := _row(fake_id)
		row.name = fake_names[i % fake_names.size()]
		row.left = 1
		ids.append(fake_id)
	for i in ids.size():
		var row := _row(ids[i])
		row.went_up = 1 if i % 4 != 3 else 0
		if row.went_up:
			row.extracted = 1 if i % 2 == 0 else 0
			row.ending = "EXTRACTED" if row.extracted else "VACUUMED"
			row.knockouts = 1 - row.extracted
			row.loot = rng.randi_range(0, 9) * 20 if row.extracted else 0
			row.bonus = 50 if i == 1 else 0
			row.bots = rng.randi_range(0, 6)
			row.bosses = 1 if i == 2 else 0
			row.downs = rng.randi_range(0, 3)
			row.revives = rng.randi_range(0, 2)
			row.damage = rng.randi_range(0, 300)
			row.vacuumed = rng.randi_range(0, 3)
	_end_district()
