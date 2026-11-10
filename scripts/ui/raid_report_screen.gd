class_name RaidReportScreen
extends Control
## CYPURRPUNK — THE RAID REPORT SCREEN: ONE big "after the raid" screen per computer, covering
## the whole window. Everyone on the couch reads it together; online, every computer shows its
## own copy of the same report (the numbers come from scripts/raid_report.gd).
##
## WHERE IT LIVES: scenes/main.tscn > Main > PS1Overlay > RaidReportScreen, next to the other
## full-screen menus (start menu, pause, settings, MY CAT). Like them it's drawn in the menu
## layer over the whole game picture (scripts/ui/game_screen.gd _build_menu_view), laid out in
## GAME PIXELS (the picture is 240 tall; 320 wide on 4:3, wider on a wide screen). It uses the
## whole width, not the menus' 320-wide middle column (it's in PS1Overlay's Full Width Children).
## The scene only has the empty node: the table is built by code below.
##
## WHILE IT'S UP (RaidReportScreen.is_up()):
##   - the split-screen panes and every player's HUD hide behind it (Hud.menu_open() counts it),
##   - every cat ignores its buttons (cat_player.gd _menu_open), so nobody walks, shoots, opens the
##     inventory or drives,
##   - every local player's presses come HERE (game_screen.gd _input hands them over with the
##     player's seat): their GRAB / TALK button (or A / Enter) marks THEIR OWN row READY. Sticks and
##     d-pads do nothing. A controller nobody has claimed does nothing.
##   - Player 1's Esc / START still opens the pause menu ON TOP (so someone can leave the game);
##     close it and the report is still there.
##
## What it looks like (top to bottom):
##   RAID REPORT
##   DISTRICT 3 - CLEAN GETAWAY
##       CAT / RAID   CASH        BOTS  DOWN/REV  AWARD              READY
##   P1 # MITTENS     $120          3    1 / 2   BIG FISH            READY
##        EXTRACTED   +$50 QUEST                 BROUGHT HOME $120
##      # BEANS       $0            0    2 / 0   BUTTERPAWS           ...
##        VACUUMED                               LOST 3 LOOT TO BOTS
##   CASH BROUGHT HOME $820
##   NEXT DISTRICT IN 9   WAITING FOR 2
##   discord.gg/...                    <- RaidReport > Discord Invite (hidden when empty)
## Players on THIS computer get a coloured P1..P4 tag and their name in their seat colour; other
## computers' cats are plain. # = a little square in the cat's fur colour. TURF WAR: a line with
## each gang's name, colour and cash above its cats.
##
## THE REVEAL plays once per computer: the rows slide in one by one (a thunk each), then the
## awards STAMP down one by one (that's the clip). Timing: Main > RaidReport > Timing.
##
## Fits any screen: with few cats the text is bigger (Roomy ...); with many cats, or a narrow
## 4:3 screen, the whole table shrinks to fit (never below Min Scale).

@export_group("Text sizes (game pixels: the screen is 240 tall)")
## The big title (and with lots of cats, Compact Title Size, to leave room for the rows).
@export var title_size: int = 16
@export var compact_title_size: int = 12
## "DISTRICT 3 - CLEAN GETAWAY", the gang lines and the cash total.
@export var subtitle_size: int = 10
## Rows (names, numbers, award titles) when there are many cats...
@export var row_size: int = 8
## ...and the small second lines (quest bonus, MEGAs, award lines, column names).
@export var small_size: int = 7
## With this many cats or fewer, the rows use the bigger "roomy" sizes below.
@export var roomy_rows: int = 4
@export var roomy_row_size: int = 10
@export var roomy_small_size: int = 8

@export_group("Layout")
## With more cats than Roomy Rows, the two lines of each row are pulled this many game pixels
## closer together (they overlap the font's empty space), so 8 cats fit a 240-pixel screen
## without shrinking (shrinking blurs small text in the PS1 UI look).
@export var line_squeeze: int = 4
## Space between columns (game pixels).
@export var column_gap: int = 4
## Space around the whole report (game pixels).
@export var margin: float = 2.0
## How dark the game behind the report gets (0 = not at all, 1 = black).
@export_range(0.0, 1.0) var dim: float = 0.88
## The smallest the report may shrink to fit (1 = never shrinks).
@export var min_scale: float = 0.55
## Longer cat names are cut short with "..." so the table stays narrow.
@export var max_name_letters: int = 12

## The one report screen (main.tscn > PS1Overlay > RaidReportScreen).
static var instance: RaidReportScreen

## True while the report is up on this computer.
var is_open: bool = false

var _report: Dictionary = {}
var _content: VBoxContainer
var _title: Label
var _subtitle: Label
var _grid: GridContainer
var _total: Label
var _status: Label
var _hint: Label
var _invite: Label
## Per row (in reveal order): the cells of that row, and its award cell.
var _row_cells: Array = []
var _award_cells: Array[Control] = []
## Player ID -> the READY label on their row.
var _ready_labels: Dictionary = {}
## How far the reveal has got (seconds since it opened) and the countdown shown.
var _t: float = 0.0
var _left: float = 0.0
var _shown_rows: int = 0
var _shown_awards: int = 0
## Space between the lines inside one cell right now (negative = squeezed: see Line Squeeze).
var _cell_gap: int = 0
## Lots of cats: no "press the button" hint line (the blinking button on each row says it).
var _compact: bool = false


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # (no mouse needed: every player readies with a button)
	var back := ColorRect.new()
	back.color = Color(0.02, 0.0, 0.05, dim)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 2)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_title = _label("RAID REPORT", title_size, Color(1, 0.4, 0.85), _content)
	_subtitle = _label("", subtitle_size, Color.WHITE, _content)
	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", column_gap)
	_grid.add_theme_constant_override("v_separation", 2)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_grid)
	_total = _label("", subtitle_size, Color(1, 0.85, 0.3), _content)
	_status = _label("", row_size, Color(0.85, 0.85, 1), _content)
	_hint = _label("", small_size, Color(0.4, 1, 1), _content)
	_invite = _label("", small_size, Color(0.55, 0.65, 1), _content)


## A centred label in its own size and colour, added to "parent".
func _label(text: String, font_size: int, color: Color, parent: Control, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


## Is the Raid Report up on this computer? THE one check other scripts use (cats ignore their
## buttons, the HUDs and split screen hide: Hud.menu_open(); game_screen.gd routes the presses).
static func is_up() -> bool:
	return instance != null and is_instance_valid(instance) and instance.is_open


# --- Opening and closing (scripts/raid_report.gd calls these) ---

## Put up this report (see RaidReport.build_report for what's in it).
func open(report: Dictionary) -> void:
	_report = report
	# Talk boxes and inventories make way (the report is on top until it's done).
	for seat in PlayerId.MAX_LOCAL:
		var dialog := NpcDialog.for_seat(seat)
		if dialog != null and dialog.is_open:
			dialog.close()
		var inventory := InventoryScreen.for_seat(seat)
		if inventory != null and inventory.visible:
			inventory._set_open(false)
		var own_pause := PlayerPause.for_seat(seat)
		if own_pause != null and own_pause.is_open:
			own_pause.close()
	# Bigger text if the cats are few AND it fits this screen without shrinking; else normal size.
	_build(report, report.rows.size() <= roomy_rows)
	if report.rows.size() <= roomy_rows and _needed_scale() < 1.0:
		_build(report, false)
	_t = 999.0 if report.get("skip_reveal", false) else 0.0  # (a late joiner: no drum roll)
	_left = float(report.seconds_left)
	_shown_rows = 0
	_shown_awards = 0
	is_open = true
	show()
	Sound.play("report_open")  # (once per computer: there's only one screen)
	_update_ready()


## Take it down (the next district is coming).
func close() -> void:
	is_open = false
	hide()


# --- Building the table ---

func _build(report: Dictionary, roomy: bool) -> void:
	for old in _grid.get_children():
		_grid.remove_child(old)
		old.queue_free()
	_row_cells.clear()
	_award_cells.clear()
	_ready_labels.clear()
	var rows: Array = report.rows
	var big := roomy_row_size if roomy else row_size
	var small := roomy_small_size if roomy else small_size
	var compact := rows.size() > roomy_rows
	_compact = compact
	_content.add_theme_constant_override("separation", 1 if compact else 2)
	_cell_gap = -line_squeeze if compact else 0
	_grid.add_theme_constant_override("v_separation", 1 if compact else 2)
	_title.add_theme_font_size_override("font_size", compact_title_size if compact else title_size)
	# "DISTRICT 2 — BLACKOUT — CLEAN GETAWAY" when the district had a DISTRICT TWIST (district_twist.gd).
	var twist := str(report.get("twist", ""))
	_subtitle.text = "DISTRICT %d — %s%s" % [int(report.district), (twist + " — ") if twist != "" else "", report.ending]
	_subtitle.add_theme_color_override("font_color", report.ending_color)
	# The column names.
	var dim_color := Color(0.6, 0.55, 0.75)
	for heading in ["", "CAT / RAID", "CASH", "BOTS", "DOWN/REV", "AWARD", "READY"]:
		_add_cell([[heading, small, dim_color]], heading == "CAT / RAID" or heading == "AWARD")
	for gang in report.gangs:
		if report.turf:  # TURF WAR: the gang's name and cash above its cats
			_add_cell([["", small, Color.WHITE]])
			_add_cell([[str(gang.name), big, gang.color]], true)
			_add_cell([["$%d" % int(gang.total), big, gang.color]])
			for i in 4:
				_add_cell([["", small, Color.WHITE]])
		for row in rows:
			if int(gang.team) == -1 or int(row.team) == int(gang.team):
				_add_row(row, big, small)
	_total.text = "CASH BROUGHT HOME $%d" % int(report.total)
	_invite.text = str(report.get("invite", ""))
	_invite.visible = _invite.text != ""


## The seat of this player if they play on THIS computer, otherwise -1.
func _local_seat(player_id: int) -> int:
	if PlayerId.peer_of(player_id) != multiplayer.get_unique_id():
		return -1
	return PlayerId.slot_of(player_id)


## One cat's row: 7 cells, hidden until its turn in the reveal.
func _add_row(row: Dictionary, big: int, small: int) -> void:
	var player_id := int(row.id)
	var seat := _local_seat(player_id)
	var cells: Array[Control] = []
	# 1. "P1".."P4" tag for players on this computer (in their seat colour), empty for others.
	if seat >= 0:
		var tag := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Seats.color(seat)
		style.set_content_margin_all(1)
		style.content_margin_left = 2
		style.content_margin_right = 2
		tag.add_theme_stylebox_override("panel", style)
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label("P%d" % (seat + 1), big, Color(0.05, 0.02, 0.1), tag)
		_grid.add_child(tag)
		cells.append(tag)
	else:
		cells.append(_add_cell([["", small, Color.WHITE]]))
	# 2. The name (seat colour for our players, plain for others) after a fur-colour square, and
	# under it how their raid ended (EXTRACTED / VACUUMED / STAYED HOME / LEFT EARLY).
	var name_cell := VBoxContainer.new()
	name_cell.add_theme_constant_override("separation", _cell_gap)
	name_cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	name_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_box := HBoxContainer.new()
	name_box.add_theme_constant_override("separation", 3)
	name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_cell.add_child(name_box)
	var swatch := ColorRect.new()
	swatch.color = row.swatch
	swatch.custom_minimum_size = Vector2(big * 0.6, big * 0.6)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_box.add_child(swatch)
	var cat_name := str(row.name).to_upper()
	if cat_name.length() > max_name_letters:
		cat_name = cat_name.left(max_name_letters - 1) + "…"
	var name_color: Color = Seats.color(seat) if seat >= 0 else Color(0.9, 0.88, 1)
	_label(cat_name, big, name_color, name_box, HORIZONTAL_ALIGNMENT_LEFT)
	var ending := str(row.ending) + (" (LEFT)" if int(row.left) and row.ending != "LEFT EARLY" else "")
	_label(ending, small, row.ending_color, name_cell, HORIZONTAL_ALIGNMENT_LEFT)
	_grid.add_child(name_cell)
	cells.append(name_cell)
	# 3. Cash, with the quest bonus on its own line.
	var bonus := "+$%d QUEST" % int(row.bonus) if int(row.bonus) > 0 else ""
	cells.append(_add_cell([["$%d" % int(row.cash), big, Color(1, 0.85, 0.3)], [bonus, small, Color(1, 0.75, 0.3)]]))
	# 4. VAC-COPs smashed, MEGAs called out.
	var megas := "%d MEGA!" % int(row.bosses) if int(row.bosses) > 0 else ""
	cells.append(_add_cell([[str(int(row.bots)), big, Color(0.4, 1, 1)], [megas, small, Color(1, 0.45, 0.85)]]))
	# 5. Downed / revived. (MESS MADE goes under it once mess-making exists: RaidReport > Show Mess Stat.)
	var mess := "MESS %d" % int(row.get("mess", 0)) if _report.get("show_mess", false) else ""
	cells.append(_add_cell([["%d / %d" % [int(row.downs), int(row.revives)], big, Color(0.85, 0.85, 1)], [mess, small, Color(1, 0.6, 0.2)]]))
	# 6. The award (stamped down last).
	var award := _add_cell([[str(row.award_title), big, row.award_color], [str(row.award_line), small, Color(0.9, 0.9, 1)]], true)
	award.modulate.a = 0.0
	_award_cells.append(award)
	# 7. READY (filled in by _update_ready).
	var ready_cell := _add_cell([["", big, Color.WHITE]])
	_ready_labels[player_id] = ready_cell.get_child(0)
	cells.append(ready_cell)
	for cell in cells:
		cell.modulate.a = 0.0
	_row_cells.append(cells)


## One grid cell: a column of lines, each [text, size, colour]. Empty lines are skipped.
func _add_cell(lines: Array, left_aligned: bool = false) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", _cell_gap)
	cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in lines.size():
		var line: Array = lines[i]
		if i > 0 and str(line[0]) == "":
			continue
		_label(str(line[0]), int(line[1]), line[2], cell,
			HORIZONTAL_ALIGNMENT_LEFT if left_aligned else HORIZONTAL_ALIGNMENT_CENTER)
	_grid.add_child(cell)
	return cell


# --- Every frame: the reveal, READY, fitting the screen ---

func _process(delta: float) -> void:
	if not is_open:
		return
	_t += delta
	_left = maxf(_left - delta, 0.0)
	var count := _row_cells.size()
	var intro := float(_report.intro)
	var awards_start := intro + count * float(_report.card) + 0.4
	# The rows slide in...
	while _shown_rows < count and _t >= intro + _shown_rows * float(_report.card):
		for cell in _row_cells[_shown_rows]:
			_pop(cell, 1.15, 0.18)
		_shown_rows += 1
		if _t < 900.0:
			Sound.play("report_row")
	# ...then the awards stamp down.
	while _shown_awards < count and _t >= awards_start + _shown_awards * float(_report.award):
		_pop(_award_cells[_shown_awards], 1.8, 0.22)
		_shown_awards += 1
		if _t < 900.0:
			Sound.play("report_award")
	_update_ready()
	_fit()


## Show a hidden piece with a little bounce (from "from_scale" down to normal).
func _pop(piece: Control, from_scale: float, seconds: float) -> void:
	piece.modulate.a = 1.0
	piece.pivot_offset = piece.size / 2.0
	piece.scale = Vector2.ONE * from_scale
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "scale", Vector2.ONE, seconds)


## Every row's READY cell, the countdown and the "press your button" hint.
func _update_ready() -> void:
	var host_side := RaidReport.instance
	if host_side == null:
		return
	var blink := 0.55 + 0.45 * absf(sin(_t * 4.0))
	var locals_waiting := false
	for player_id in _ready_labels:
		var label: Label = _ready_labels[player_id]
		var seat := _local_seat(player_id)
		if host_side.is_ready(player_id):
			label.text = "READY"
			label.add_theme_color_override("font_color", Color(0.5, 1, 0.55))
			label.modulate.a = 1.0
		elif not player_id in host_side.waiting_for:
			label.text = "-"  # (left the game: nobody waits for them)
			label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		elif seat >= 0:
			# OUR player, not ready yet: the button THEY press (their pad, or player 1's keyboard).
			label.text = "[%s]" % Hud.key_for("interact", seat)
			label.add_theme_color_override("font_color", Seats.color(seat))
			label.modulate.a = blink
			locals_waiting = true
		else:
			label.text = "..."
			label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	var counts := host_side.ready_count()
	var waiting: int = counts[1] - counts[0]
	_status.text = "NEXT DISTRICT IN %d   %s" % [ceili(_left),
		"EVERYONE'S READY!" if waiting <= 0 else "WAITING FOR %d" % waiting]
	_hint.text = "PRESS THE BUTTON ON YOUR ROW TO READY UP" if locals_waiting else ""
	_hint.visible = locals_waiting and not _compact


## How much the report would have to shrink to fit the screen (1 = it fits as it is).
## (In the PS1 UI look shrinking blurs small text, so a smaller text size is tried first: open.)
func _needed_scale() -> float:
	var room := size - Vector2(margin, margin) * 2.0
	var need := _content.get_combined_minimum_size()
	if room.x <= 0.0 or room.y <= 0.0:
		return 1.0
	return minf(1.0, minf(room.x / maxf(need.x, 1.0), room.y / maxf(need.y, 1.0)))


## Shrink the whole report to fit the screen if needed, and centre it.
func _fit() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_content.size = Vector2.ZERO
	var need := _content.get_combined_minimum_size()
	_content.scale = Vector2.ONE * maxf(_needed_scale(), min_scale)
	_content.size = need
	_content.position = ((size - need * _content.scale.x) / 2.0).floor()


# --- READY (game_screen.gd hands every local player's presses here) ---

## A press from the player in "seat" on this computer while the report is up. Their GRAB / TALK
## button (or A / Enter) readies THEIR OWN cat; anything else is ignored. Returns true if used.
func seat_input(event: InputEvent, seat: int) -> bool:
	if not is_open or seat < 0 or event.is_echo():
		return false
	if not (Seats.event_is(seat, event, "interact") or event.is_action_pressed("ui_accept")):
		return false  # (sticks, d-pads and every other button do nothing here)
	var player_id := PlayerId.make(multiplayer.get_unique_id(), seat)
	var host_side := RaidReport.instance
	if Game.instance.cat_for(player_id) == null or host_side == null or host_side.is_ready(player_id):
		return true
	host_side.request_report_ready.rpc_id(1, player_id)
	Sound.play("click")
	return true
