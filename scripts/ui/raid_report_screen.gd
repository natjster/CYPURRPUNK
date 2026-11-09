class_name RaidReportScreen
extends Control
## CYPURRPUNK — THE RAID REPORT on one player's screen (the numbers come from
## scripts/raid_report.gd, the same report on every screen).
## Part of every player's HUD (scenes/ui/hud.tscn > HUD > Frame > RaidReportScreen); like the
## split-screen pause menu it builds its own boxes, so the scene only needs the empty node.
##
## What it looks like (built by code, top to bottom):
##   RAID REPORT                                  <- title
##   DISTRICT 3 - CLEAN GETAWAY                   <- how it ended for the crew
##   [card] [card] [card] [card]                  <- one per cat (TURF WAR: a row per gang, under
##                                                   the gang's name and cash, in its colour)
##   CASH BROUGHT HOME $820                       <- the crew's total
##   [E] READY     NEXT DISTRICT IN 9 - READY 1/3 <- the READY button and the countdown
##   discord.gg/...                               <- RaidReport > Discord Invite (hidden when empty)
## Each card: the cat's name (with a little square of its fur colour), how its raid ended, cash
## (+ quest bonus), VAC-COPs smashed (MEGAs called out), downed / revived, (MESS MADE, hidden
## until Phase 1) and finally its AWARD.
##
## THE REVEAL: the cards flip in one by one (a thunk each), then the awards STAMP down one by one.
## The timing is on the RaidReport node in main.tscn (Intro / Card / Award Seconds).
##
## Fits any screen: on a small split-screen pane, or with many cats, the whole report shrinks to
## fit. Text sizes below are for a full screen (HUD units: the screen is 720 tall).
##
## Controls: A / Enter (or this player's interact key) presses READY; player 1 can also click it.
## While it's up the player's cat ignores their buttons (cat_player.gd _menu_open).

@export_group("Text sizes (HUD units)")
@export var title_size: int = 46
@export var subtitle_size: int = 28
@export var name_size: int = 30
@export var cash_size: int = 34
@export var stat_size: int = 24
@export var award_title_size: int = 32
@export var award_line_size: int = 24
@export var footer_size: int = 26

@export_group("Layout")
## How wide each cat's card is (HUD units).
@export var card_width: float = 250.0
## Space around the report (HUD units).
@export var margin: float = 16.0
## How dark the game behind the report gets (0 = not at all, 1 = black).
@export_range(0.0, 1.0) var dim: float = 0.8
## The smallest the report may shrink to fit a small screen (1 = never shrinks).
@export var min_scale: float = 0.35

## Which player's report this is (its HUD's seat).
var seat: int = 0
## True while it's up.
var is_open: bool = false

var _report: Dictionary = {}
var _content: VBoxContainer
var _title: Label
var _subtitle: Label
var _sections: VBoxContainer
var _total: Label
var _ready_button: Button
var _status: Label
var _invite: Label
## Every card, in reveal order, and its award box.
var _cards: Array[Control] = []
var _award_boxes: Array[Control] = []
## How far the reveal has got (seconds since it opened), and the countdown on screen.
var _t: float = 0.0
var _left: float = 0.0
var _shown_cards: int = 0
var _shown_awards: int = 0
var _scale: float = 1.0
var _focus := SeatFocus.new()


func _enter_tree() -> void:
	seat = (owner as Hud).seat if owner is Hud else 0


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0.02, 0.0, 0.05, dim)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_title = _label("RAID REPORT", title_size, Color(1, 0.4, 0.85))
	_subtitle = _label("", subtitle_size, Color.WHITE)
	_sections = VBoxContainer.new()
	_sections.add_theme_constant_override("separation", 10)
	_content.add_child(_sections)
	_total = _label("", footer_size, Color(1, 0.85, 0.3))
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 18)
	_content.add_child(footer)
	_ready_button = Button.new()
	_ready_button.add_theme_font_size_override("font_size", footer_size)
	_ready_button.pressed.connect(_on_ready_pressed)
	footer.add_child(_ready_button)
	_status = _label("", footer_size - 4, Color(0.8, 0.8, 0.95), footer)
	_invite = _label("", footer_size - 6, Color(0.55, 0.65, 1))


## A centred label with its own size and colour, added to "parent" (default: the report's column).
## Text on a card has no outline (the card is dark already, and an outline smears small PS1 text).
func _label(text: String, font_size: int, color: Color, parent: Control = null, outlined: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", Hud.outline(6) if outlined else 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else _content).add_child(label)
	return label


## This player's report screen (seat 0 = player 1), or null.
static func for_seat(seat_number: int) -> RaidReportScreen:
	var hud := Hud.of(seat_number)
	return hud.get_node_or_null("Frame/RaidReportScreen") as RaidReportScreen if hud != null else null


## Is this player's report up?
static func is_open_for(seat_number: int) -> bool:
	var screen := for_seat(seat_number)
	return screen != null and screen.is_open


## The player this screen belongs to.
func _player_id() -> int:
	return PlayerId.make(multiplayer.get_unique_id(), seat)


# --- Opening and closing ---

## Put up this report (scripts/raid_report.gd sends it: see build_report for what's in it).
func open(report: Dictionary) -> void:
	_report = report
	# Anything else this player had open makes way (the report is on top until it's done).
	var dialog := NpcDialog.for_seat(seat)
	if dialog != null and dialog.is_open:
		dialog.close()
	var inventory := InventoryScreen.for_seat(seat)
	if inventory != null and inventory.visible:
		inventory._set_open(false)
	_build(report)
	_t = 999.0 if report.get("skip_reveal", false) else 0.0
	_left = float(report.seconds_left)
	_shown_cards = 0
	_shown_awards = 0
	is_open = true
	show()
	_focus.set_buttons([_ready_button])
	if seat == 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # (the mouse is player 1's)
		Sound.play("report_open")
	_update_footer()


## Take it down (the next district is coming).
func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	_focus.clear()
	if seat == 0 and not Hud.wants_input(0):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Make the title, the cards and the footer for this report.
func _build(report: Dictionary) -> void:
	for old in _sections.get_children():
		_sections.remove_child(old)
		old.queue_free()
	_cards.clear()
	_award_boxes.clear()
	_subtitle.text = "DISTRICT %d — %s" % [int(report.district), report.ending]
	_subtitle.add_theme_color_override("font_color", report.ending_color)
	var rows: Array = report.rows
	for gang in report.gangs:
		if report.turf:  # TURF WAR: each gang's cards under its own name
			var header := _label("%s   $%d" % [gang.name, int(gang.total)], subtitle_size, gang.color, _sections)
			header.add_theme_constant_override("outline_size", Hud.outline(6))
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sections.add_child(flow)
		for row in rows:
			if int(gang.team) == -1 or int(row.team) == int(gang.team):
				flow.add_child(_card(row, report.get("show_mess", false)))
	# Every card as wide as the widest one, so the rows line up neatly.
	var widest := card_width
	for card in _cards:
		widest = maxf(widest, card.get_combined_minimum_size().x)
	for card in _cards:
		card.custom_minimum_size.x = widest
	_total.text = "CASH BROUGHT HOME $%d" % int(report.total)
	_invite.text = str(report.get("invite", ""))
	_invite.visible = _invite.text != ""


## One cat's card.
func _card(row: Dictionary, show_mess: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(card_width, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.04, 0.12, 0.95)
	style.border_color = (row.color as Color).darkened(0.25)
	style.set_border_width_all(int(Hud.line(2)))
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	# Name, with a little square of the cat's fur colour.
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 8)
	box.add_child(name_row)
	var swatch := ColorRect.new()
	swatch.color = row.swatch
	swatch.custom_minimum_size = Vector2(name_size * 0.6, name_size * 0.6)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(swatch)
	var cat_name := _label(str(row.name).to_upper(), name_size, row.color, name_row, false)
	# A long name is cut short with "..." instead of stretching the card.
	cat_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cat_name.clip_text = true
	cat_name.custom_minimum_size.x = card_width - 20 - swatch.custom_minimum_size.x - 8
	_label(str(row.ending) + ("  (LEFT)" if int(row.left) and row.ending != "LEFT EARLY" else ""), stat_size, row.ending_color, box, false)
	_label("$%d" % int(row.cash), cash_size, Color(1, 0.85, 0.3), box, false)
	if int(row.bonus) > 0:
		_label("INCL. +$%d QUEST" % int(row.bonus), stat_size - 4, Color(1, 0.85, 0.3).darkened(0.15), box, false)
	var bots := "BOTS SMASHED %d" % int(row.bots)
	if int(row.bosses) > 0:
		bots += "  (%d MEGA!)" % int(row.bosses)
	_label(bots, stat_size, Color(0.4, 1, 1) if int(row.bosses) == 0 else Color(1, 0.45, 0.85), box, false)
	_label("DOWNED %d   REVIVED %d" % [int(row.downs), int(row.revives)], stat_size, Color(0.85, 0.85, 1), box, false)
	# MESS MADE: hidden until mess-making exists (Phase 1; RaidReport > Show Mess Stat).
	if show_mess:
		_label("MESS MADE %d" % int(row.get("mess", 0)), stat_size, Color(1, 0.6, 0.2), box, false)
	# The award, hidden until its turn in the reveal.
	var award := VBoxContainer.new()
	award.add_theme_constant_override("separation", 0)
	award.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(award)
	var rule := ColorRect.new()
	rule.color = (row.color as Color).darkened(0.4)
	rule.custom_minimum_size = Vector2(0, Hud.line(2))
	award.add_child(rule)
	var title := _label(str(row.award_title), award_title_size, row.award_color, award, false)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var line := _label(str(row.award_line), award_line_size, Color(0.9, 0.9, 1), award, false)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	award.modulate.a = 0.0
	card.modulate.a = 0.0
	_cards.append(card)
	_award_boxes.append(award)
	return card


# --- Every frame: the reveal, the countdown, fitting the screen ---

func _process(delta: float) -> void:
	if not is_open:
		return
	_t += delta
	_left = maxf(_left - delta, 0.0)
	var count := _cards.size()
	var intro := float(_report.intro)
	var awards_start := intro + count * float(_report.card) + 0.4
	# The cards flip in...
	while _shown_cards < count and _t >= intro + _shown_cards * float(_report.card):
		_pop(_cards[_shown_cards], 1.12, 0.18)
		_shown_cards += 1
		if seat == 0 and _t < 900.0:
			Sound.play("report_row")
	# ...then the awards stamp down.
	while _shown_awards < count and _t >= awards_start + _shown_awards * float(_report.award):
		_pop(_award_boxes[_shown_awards], 1.8, 0.22)
		_shown_awards += 1
		if seat == 0 and _t < 900.0:
			Sound.play("report_award")
	_update_footer()
	_fit()


## Show a hidden piece with a little bounce (from "from_scale" down to normal).
func _pop(piece: Control, from_scale: float, seconds: float) -> void:
	piece.modulate.a = 1.0
	piece.pivot_offset = piece.size / 2.0
	piece.scale = Vector2.ONE * from_scale
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "scale", Vector2.ONE, seconds)


## The READY button and the countdown line.
func _update_footer() -> void:
	var report_node := RaidReport.instance
	if report_node == null:
		return
	var me_ready := report_node.is_ready(_player_id())
	# A controller player presses A (the fixed "press the button" button); keyboard: their interact key.
	var key := Controls.display_name(Controls.FIXED["ui_accept"][0]) if Seats.uses_pad(seat) else Controls.key_text("interact")
	_ready_button.text = "READY!" if me_ready else "[%s] READY" % key
	var counts := report_node.ready_count()
	_status.text = "NEXT DISTRICT IN %d   READY %d/%d" % [ceili(_left), counts[0], counts[1]]


## Shrink the whole report to fit this screen (split screen / lots of cats), centred.
## (The cards wrap onto more rows when the screen is narrow; each frame tries the size that fits.)
func _fit() -> void:
	var room := size - Vector2(margin, margin) * 2.0
	if room.x <= 0.0 or room.y <= 0.0:
		return
	_content.size = Vector2(room.x / _scale, 0.0)
	var need := _content.get_combined_minimum_size()
	var fit := minf(1.0, minf(room.y / maxf(need.y, 1.0), room.x / maxf(need.x, 1.0)))
	_scale = clampf(fit, min_scale, 1.0)
	_content.scale = Vector2.ONE * _scale
	_content.size = Vector2(room.x / _scale, need.y)
	_content.position = (size - _content.size * _scale) / 2.0


# --- READY ---

func _input(event: InputEvent) -> void:
	if not is_open or Seats.seat_of_event(event) != seat:
		return  # another player's button (player 1's HUD hears every button first)
	if _focus.handle(event) or Seats.event_is(seat, event, "interact"):
		if Seats.event_is(seat, event, "interact"):
			_on_ready_pressed()
		get_viewport().set_input_as_handled()


## This player is ready for the next district (the host waits for everyone, or the clock).
func _on_ready_pressed() -> void:
	var report_node := RaidReport.instance
	if report_node == null or report_node.is_ready(_player_id()):
		return
	report_node.request_report_ready.rpc_id(1, _player_id())
	Sound.play("click")
