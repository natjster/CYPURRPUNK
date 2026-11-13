class_name MainframeScreen
extends Control
## THE MAINFRAME's window: press E at the junk-pile computer on the west wall of your sewer
## (hub.gd _build_mainframe). It explains what the Mainframe does, shows its battery cells live,
## and has the FEED button (1 ELECTRONICS = +25%; when it's full: HACK the rival's instead).
## Drawn in the shared ocean-blue style (scripts/ui/hud_style.gd), like the shop and the workbench.
## Lives at scenes/ui/hud.tscn > HUD > Frame > Mainframe (one per player, split screen too).
##
##   ┌ THE MAINFRAME — CATLEONE FAMILY                    2 ELECTRONICS IN PACK ┐
##   │ ┌cells┐   SYSTEM ONLINE  63%           WHAT IT DOES                       │
##   │ │ ▒▒▒ │   ...                          our home-made computer jams ...     │
##   │ │ ███ │   YOUR EXIT OPENS AT 75 HEAT   ┌ tier table: cells, name, exit ┐  │
##   │ │ ███ │   CITY STARTS AT 0 HEAT        └───────────────────────────────┘  │
##   │ └─────┘   [ FEED 1 ELECTRONICS (+25%) ]   [ LEAVE ]                         │
##   │ what the highlighted thing does / "MAINFRAME +25% ..."                      │
##   └─────────────────────────────────────────────────────────────────────────────┘
## CONTROLLER: d-pad / stick moves the highlight, A = click, B / Y / Esc / Tab = leave.
## The host does the feeding (Mainframe.request_feed); its answer shows in the bottom box (note).

@export_group("Layout")
## The window's widest size (HUD units; the window is 960 wide).
@export var panel_max_width: float = 900.0
## Height of the FEED / LEAVE buttons.
@export var button_height: float = 46.0
@export var gap: float = 10.0

@export_group("Words")
@export var title_font_size: int = 22
@export var big_font_size: int = 20
@export var detail_font_size: int = 13
## How long a FEED result stays in the bottom box (seconds).
@export var note_seconds: float = 4.0
## The paragraph under WHAT IT DOES. {drain} = the slow drain per minute, {seal} = the drain per sealed district.
@export_multiline var about_text: String = "We scrounged this thing together from OVERCLEAN junk. It jams the city's sensors: the more charge, the sooner it tracks down a PAYPHONE for you up top (call your boss on one to find your EXIT) and the calmer the city starts. It slowly drains (-{drain}% a minute while anyone's up top, -{seal}% every time a district is sealed). It only eats ELECTRONICS, and only a MEGA VAC-COP carries those. Empty = one LAST RAID, then OVERCLEAN breaks into the sewer."
## The bottom box before anything is highlighted.
@export var default_info: String = "Press FEED with ELECTRONICS in your backpack. SCRAP doesn't go in here: spend it at the TINKER WORKBENCH. Esc / Tab: leave."

const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)
const AMBER := Color(1.0, 0.75, 0.3)
const PURPLE := Color(0.8, 0.4, 1.0)  # (the ELECTRONICS glow colour, items/electronics.tres)

var seat: int = 0
var owner_cat: CatPlayer = null
var hub: UndergroundHub = null

var _focus := SeatFocus.new()
var _feed: Button
var _leave: Button
var _built := false
var _note := ""
var _note_good := true
var _note_left := 0.0
var _info := ""
var _panel := Rect2()
var _gauge := Rect2()
var _stats := Rect2()
var _about := Rect2()
var _table := Rect2()
var _info_rect := Rect2()


func _enter_tree() -> void:
	seat = (owner as Hud).seat if owner is Hud else 0


## This player's Mainframe window (seat 0 = player 1), or null.
static func for_seat(seat_number: int) -> MainframeScreen:
	var hud := Hud.of(seat_number)
	return hud.get_node_or_null("Frame/Mainframe") as MainframeScreen if hud != null else null


static func is_open_for(seat_number: int) -> bool:
	var screen := for_seat(seat_number)
	return screen != null and screen.visible


func is_open() -> bool:
	return visible


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # clicks on the window don't reach the game
	_build.call_deferred()


func _build() -> void:
	_feed = HudStyle.make_button(self, "FEED", big_font_size - 2)
	_feed.pressed.connect(_press_feed)
	_feed.mouse_entered.connect(_on_highlight.bind(_feed))
	_leave = HudStyle.make_button(self, "LEAVE", big_font_size - 2)
	_leave.pressed.connect(close)
	_leave.mouse_entered.connect(_on_highlight.bind(_leave))
	_focus.press_on_accept = false
	_focus.highlighted.connect(_on_highlight)
	_built = true


# --- Opening / closing ---

func open(cat: CatPlayer, at_hub: UndergroundHub) -> void:
	if not _built or cat == null:
		return
	owner_cat = cat
	hub = at_hub
	_note = ""
	_info = default_info
	visible = true
	if seat == 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # (the mouse is player 1's)
	_refill()
	_layout()
	_focus.set_buttons([_feed, _leave], _feed)


func close() -> void:
	if not visible:
		return
	visible = false
	_focus.clear()
	owner_cat = null
	HudStyle.restore_game_mouse(seat)


func _input(event: InputEvent) -> void:
	if not visible or Seats.seat_of_event(event) != seat:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif _focus.handle(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _focus.current != null:
			_focus.current.pressed.emit()
		get_viewport().set_input_as_handled()


# --- What's on it ---

func _team() -> int:
	return hub.team if hub != null else (owner_cat.team if owner_cat != null else 0)


func _electronics() -> int:
	return ItemManager.instance.count_in_bag(owner_cat.player_id, Mainframe.FUEL_ID) if owner_cat != null else 0


## The FEED button's words follow what 1 electronics would do right now (Mainframe.use_for).
func _refill() -> void:
	var mainframe := Mainframe.instance
	if mainframe == null or _feed == null:
		return
	var team := _team()
	var have := _electronics()
	match mainframe.use_for(team):
		Mainframe.FeedUse.FEED:
			_feed.text = "FEED 1 ELECTRONICS  (+%d%%)" % int(mainframe.charge_per_electronics_for(team))
		Mainframe.FeedUse.HACK:
			_feed.text = "HACK RIVAL MAINFRAME  (-%d%%)" % int(mainframe.hack_per_electronics)
		_:
			_feed.text = "MAINFRAME FULL"
	var can := have > 0 and mainframe.use_for(team) != Mainframe.FeedUse.FULL and not mainframe.breach_busy
	_feed.add_theme_color_override("font_color", Color.WHITE if can else Color(1, 1, 1, 0.4))


# --- Every frame ---

func _process(delta: float) -> void:
	if not visible:
		return
	var cat := owner_cat
	if cat == null or not is_instance_valid(cat) or not cat.is_inside_tree() or hub == null \
			or cat.global_position.distance_to(hub.to_global(hub.mainframe_spot)) > hub.mainframe_radius + 2.5 \
			or Hud.menu_open():
		close()
		return
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0:
			_note = ""
	_refill()
	if _focus.current != null:
		_on_highlight(_focus.current)  # (the hint follows the Mainframe: FEED -> FULL after a feed)
	_layout()
	queue_redraw()


func _layout() -> void:
	var w := minf(size.x - 48.0, panel_max_width)
	_panel = Rect2((size.x - w) / 2.0, 52.0, w, size.y - 76.0)
	var x := _panel.position.x + 14.0
	var top := _panel.position.y + 48.0
	var inner_w := w - 28.0
	var info_h := 56.0
	_info_rect = Rect2(x, _panel.end.y - info_h - 10.0, inner_w, info_h)
	var buttons_y := _info_rect.position.y - gap - button_height
	# Left: the battery gauge. Middle: the numbers. Right: what it does + the tier table.
	var body_h := buttons_y - gap - top
	var gauge_w := minf(120.0, inner_w * 0.16)
	_gauge = Rect2(x, top, gauge_w, body_h)
	_stats = Rect2(_gauge.end.x + gap * 1.5, top, inner_w * 0.32, body_h)
	var right_x := _stats.end.x + gap
	var right_w := _panel.end.x - 14.0 - right_x
	_about = Rect2(right_x, top, right_w, body_h * 0.52)
	_table = Rect2(right_x, _about.end.y + gap, right_w, body_h - _about.size.y - gap)
	if _feed != null:
		HudStyle.place(_feed, Rect2(_stats.position.x, buttons_y, _stats.size.x + gap + right_w * 0.55, button_height))
		HudStyle.place(_leave, Rect2(_feed.position.x + _feed.size.x + gap, buttons_y, _panel.end.x - 14.0 - (_feed.position.x + _feed.size.x + gap), button_height))


func _draw() -> void:
	var mainframe := Mainframe.instance
	if not visible or owner_cat == null or not is_instance_valid(owner_cat) or mainframe == null:
		return
	var style := HudStyle.current()
	var font := get_theme_font("font", "Label")
	var team := _team()
	var tier_color := mainframe.tier_color(team)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0.02, 0.05, 0.45))  # dim the sewer behind
	HudStyle.draw_panel(self, _panel)
	HudStyle.draw_text(self, font, _panel.position + Vector2(14, 32), "THE MAINFRAME — %s" % Teams.name_of(team), title_font_size, tier_color, _panel.size.x * 0.6)
	var have := _electronics()
	HudStyle.draw_text_right(self, font, Vector2(_panel.end.x - 14, _panel.position.y + 32), "%d ELECTRONICS IN PACK" % have, title_font_size - 4, PURPLE if have > 0 else Color(style.text_color, 0.5))

	# The 4 battery cells, bottom to top. The top one with juice shows how full it still is.
	HudStyle.draw_panel(self, _gauge, true)
	var charge := mainframe.charge_of(team)
	var critical_flash := mainframe.tier(team) == Mainframe.Tier.CRITICAL and fmod(Time.get_ticks_msec() / 1000.0 * 2.0, 1.0) < 0.5
	var cell_gap := 6.0
	var inner := _gauge.grow(-10.0)
	var cell_h := (inner.size.y - cell_gap * 3.0) / 4.0
	for i in 4:
		var cell := Rect2(inner.position.x, inner.end.y - (i + 1) * cell_h - i * cell_gap, inner.size.x, cell_h)
		var fill := clampf((charge - i * Mainframe.CELL) / Mainframe.CELL, 0.0, 1.0)
		draw_rect(cell, Color(0.05, 0.07, 0.09, 0.9))
		if fill > 0.0:
			var lit := Rect2(cell.position.x, cell.end.y - cell.size.y * fill, cell.size.x, cell.size.y * fill)
			draw_rect(lit, Color(tier_color, 0.85))
		draw_rect(cell, Color(BAD, 0.9) if critical_flash else Color(style.border_color, 0.6), false, Hud.line(1.5))

	# The numbers.
	var sx := _stats.position.x
	var sy := _stats.position.y + 22.0
	var sw := _stats.size.x
	HudStyle.draw_text(self, font, Vector2(sx, sy), mainframe.tier_name(team), big_font_size + 4, tier_color, sw)
	HudStyle.draw_text(self, font, Vector2(sx, sy + 34), "%d%%   %d/4 CELLS" % [mainframe.percent(team), mainframe.cells(team)], big_font_size, Color.WHITE, sw)
	var lines := [
		["PAYPHONE TRACKED AT", "%d HEAT" % int(mainframe.exit_heat(team)), GOOD],
		["CITY STARTS AT", "%d HEAT%s" % [int(mainframe.starting_heat()), "  (OVERCLOCK)" if mainframe.overclock_active else ""], AMBER],
		["SLOW DRAIN", "-%s%% / MIN" % _number(mainframe.drain_per_minute), Color(style.text_color, 0.85)],
		["NEXT CELL DRY IN", _time_to_next_cell(mainframe, team), Color(style.text_color, 0.85)],
	]
	var ly := sy + 72.0
	for line in lines:
		HudStyle.draw_text(self, font, Vector2(sx, ly), line[0], detail_font_size, Color(style.text_color, 0.6), sw)
		HudStyle.draw_text(self, font, Vector2(sx, ly + 18), line[1], detail_font_size + 3, line[2], sw)
		ly += 42.0
	if mainframe.breach_busy:
		HudStyle.draw_text(self, font, Vector2(sx, ly), "LOCKED DOWN: SEWER BREACH", detail_font_size + 1, BAD, sw)
	elif mainframe.tier(team) == Mainframe.Tier.CRITICAL:
		HudStyle.draw_text(self, font, Vector2(sx, ly), "EMPTY! LAST RAID, THEN A BREACH", detail_font_size + 1, BAD if critical_flash else AMBER, sw)

	# What it does.
	HudStyle.draw_panel(self, _about, true)
	HudStyle.draw_text(self, font, _about.position + Vector2(12, 24), "WHAT IT DOES", big_font_size - 2, AMBER, _about.size.x - 24)
	var about := about_text.format({"drain": _number(mainframe.drain_per_minute), "seal": _number(mainframe.drain_per_district)})
	var about_w := _about.size.x - 24.0
	var about_h := _about.size.y - 36.0
	var about_fs := detail_font_size
	while about_fs > 10 and font.get_multiline_string_size(about, HORIZONTAL_ALIGNMENT_LEFT, about_w, about_fs).y > about_h:
		about_fs -= 1
	var about_lines := maxi(1, int(about_h / font.get_height(about_fs)))
	draw_multiline_string(font, _about.position + Vector2(12, 42), about, HORIZONTAL_ALIGNMENT_LEFT, about_w,
		about_fs, about_lines, Color(style.text_color, 0.85))

	# The tier table: which cells, what it's called, when your exit opens. Your row is lit.
	HudStyle.draw_panel(self, _table, true)
	var exits := [mainframe.exit_at_0, mainframe.exit_at_25, mainframe.exit_at_50, mainframe.exit_at_75, mainframe.exit_at_100]
	var row_h := minf(24.0, (_table.size.y - 34.0) / 5.0)
	var tx := _table.position.x + 12.0
	var ty := _table.position.y + 22.0
	HudStyle.draw_text(self, font, Vector2(tx, ty), "CELLS", detail_font_size, Color(style.text_color, 0.6))
	HudStyle.draw_text(self, font, Vector2(tx + 70, ty), "TIER", detail_font_size, Color(style.text_color, 0.6))
	HudStyle.draw_text_right(self, font, Vector2(_table.end.x - 12, ty), "PHONE AT", detail_font_size, Color(style.text_color, 0.6))
	for row in 5:
		var tier_index := 4 - row  # (OVERCLOCK on top)
		var y := ty + 8.0 + row * row_h
		var mine := tier_index == mainframe.tier(team)
		var colour: Color = Mainframe.TIER_COLORS[tier_index]
		if mine:
			draw_rect(Rect2(_table.position.x + 4, y + 2, _table.size.x - 8, row_h - 2), Color(colour, 0.18))
		for c in 4:
			var pip := Rect2(tx + c * 13.0, y + row_h * 0.5 - 3.0, 10.0, 8.0)
			draw_rect(pip, colour if c < tier_index else Color(colour, 0.15), c < tier_index)
		HudStyle.draw_text(self, font, Vector2(tx + 70, y + row_h - 5), Mainframe.TIER_NAMES[tier_index], detail_font_size + (1 if mine else 0),
			colour if mine else Color(colour, 0.65))
		HudStyle.draw_text_right(self, font, Vector2(_table.end.x - 12, y + row_h - 5), "%d HEAT" % int(maxf(exits[tier_index] - Upgrades.exit_heat_discount(team), 0.0)),
			detail_font_size, Color.WHITE if mine else Color(style.text_color, 0.6))

	# The bottom box.
	HudStyle.draw_panel(self, _info_rect, true)
	var shown := _note if _note != "" else _info
	var color := (GOOD if _note_good else BAD) if _note != "" else style.text_color
	draw_multiline_string(font, _info_rect.position + Vector2(10, 22), shown, HORIZONTAL_ALIGNMENT_LEFT, _info_rect.size.x - 20,
		detail_font_size + 1, 3, color)


## "4 MIN" / "40 S" until the top cell with juice runs dry (at the slow drain), or "-" with no drain.
func _time_to_next_cell(mainframe: Mainframe, team: int) -> String:
	var charge := mainframe.charge_of(team)
	if mainframe.drain_per_minute <= 0.0 or charge <= 0.0:
		return "-"
	var left_in_cell := charge - (mainframe.cells(team) - 1) * Mainframe.CELL
	var minutes := left_in_cell / mainframe.drain_per_minute
	return "%d MIN OF RAIDING" % ceili(minutes) if minutes >= 1.0 else "%d S" % ceili(minutes * 60.0)


## 1.0 -> "1", 1.5 -> "1.5".
static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


# --- Feeding ---

func _press_feed() -> void:
	var mainframe := Mainframe.instance
	if owner_cat == null or mainframe == null:
		return
	if _electronics() <= 0:
		Sound.play("error")
		note("No ELECTRONICS in your backpack. Smash a MEGA VAC-COP up top: it drops one for every cat up there.", false)
		return
	if mainframe.use_for(_team()) == Mainframe.FeedUse.FULL:
		Sound.play("error")
		note("MAINFRAME FULL. Keep your electronics in the litterbox for when it drains.", false)
		return
	mainframe.request_feed.rpc_id(1, owner_cat.player_id)  # (the host answers with Mainframe._feed_result -> note)


## A message in the bottom box for a few seconds (green = good news, red = no).
func note(text: String, good: bool) -> void:
	_note = text
	_note_good = good
	_note_left = note_seconds
	queue_redraw()


func _on_highlight(button: Button) -> void:
	if button == null or owner_cat == null:
		return
	if button == _leave:
		_info = "Back to the sewer."
		return
	match Mainframe.instance.use_for(_team()):
		Mainframe.FeedUse.HACK:
			_info = "Your Mainframe is full: 1 ELECTRONICS HACKS the rival gang's Mainframe instead (-%d%%). Everyone sees it in the feed." % int(Mainframe.instance.hack_per_electronics)
		Mainframe.FeedUse.FULL:
			_info = "Full. Stash your ELECTRONICS in the litterbox: it drains, and you'll want them later."
		_:
			_info = "1 ELECTRONICS = one more battery cell (+%d%%): one tier up, so your exit opens sooner. Only MEGA VAC-COPs drop them." % int(Mainframe.instance.charge_per_electronics_for(_team()))
