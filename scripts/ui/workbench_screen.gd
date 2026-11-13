class_name WorkbenchScreen
extends Control
## THE TINKER WORKBENCH — the ONLY place to buy SEWER UPGRADES and to RECRUIT the SEWER REBELLION.
## Press E at the workbench on the east wall of your sewer (hub.gd _build_workbench). Drawn in the shared
## ocean-blue style (scripts/ui/hud_style.gd). Lives at scenes/ui/hud.tscn > HUD > Frame > Workbench.
##
##   ┌ TINKER WORKBENCH                                   $240   3 SCRAP ┐
##   │ [DON] [WHISKERS] [MITTENS] [ ? ] [ ? ] [ ? ] [ ? ]                  │  <- 7 portrait tabs (LB / RB)
##   │ ┌portrait┐  LIL' MITTENS            ┌ STUFFED CHEEKS   [■ □] 1/2 ┐ │
##   │ │        │  STREET RUNNER           │ snack stacks 3->4->5        │ │  <- upgrade cards: click = BUY
##   │ └────────┘  "Psst..."               │ BUY — $160 + 1 SCRAP        │ │
##   │             QUEST IN SEWER: ...     └─────────────────────────────┘ │
##   │ what the highlighted thing does / "UPGRADED! ..."                   │
##   └──────────────────────────────────────────────────────────────────────┘
## TABS (Upgrades.WORKBENCH_TABS): 0 = your boss (Don / Pawnie), 1 = your shopkeeper (Whiskers / Clawd),
## 2-6 = the 5 REBELLION RECRUITS. A recruit you haven't got yet is a "?" (no name, no face): its tab
## only says WHAT KIND of upgrades they bring (Upgrades.RECRUIT_TYPES + the upgrade names). EVERY "?"
## offers RECRUIT TO THE REBELLION (cash + scrap, upgrade "recruit_N"), so you choose who joins first;
## the price goes up with each recruit your gang already has. Recruiting reveals their face here,
## walks them into the sewer (npc.gd), gives you their quest to take, and opens their upgrades.
## CONTROLLER: d-pad / stick moves the highlight, A = click, LB / RB = tabs, B / Y / Esc / Tab = leave.
## The host checks every purchase (Upgrades.request_buy); messages show in the bottom box.

@export_group("Layout")
@export var panel_max_width: float = 980.0
@export var tab_max_size: float = 86.0
@export var card_height: float = 74.0
@export var gap: float = 8.0

@export_group("Words")
@export var title_font_size: int = 22
@export var name_font_size: int = 20
@export var card_title_size: int = 16
@export var detail_font_size: int = 13
@export var note_seconds: float = 3.5
## The bottom box before anything is highlighted.
@export var default_info: String = "Pick a cat on top (LB / RB). Click an upgrade card to buy it. Pick a \"?\" by the upgrades it brings and recruit it. Esc / Tab: leave."

const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)
const AMBER := Color(1.0, 0.75, 0.3)

var seat: int = 0
var owner_cat: CatPlayer = null
var hub: UndergroundHub = null
var tab: int = 0

var _focus := SeatFocus.new()
var _tabs: Array[Button] = []
var _cards: Array[Button] = []      # upgrade cards (reused; hidden when not needed)
var _rides: Array[Button] = []      # SELECT VEHICLE buttons (tab 6)
var _recruit: Button                # the big RECRUIT button
var _built := false
var _note := ""
var _note_good := true
var _note_left := 0.0
var _celebrating_until := 0.0  # a NEW RECRUIT message isn't replaced by the plain "UPGRADED!" right after it
var _info := ""
var _last_key := ""
var _panel := Rect2()
var _content := Rect2()
var _info_rect := Rect2()


func _enter_tree() -> void:
	seat = (owner as Hud).seat if owner is Hud else 0


## This player's workbench screen (seat 0 = player 1), or null.
static func for_seat(seat_number: int) -> WorkbenchScreen:
	var hud := Hud.of(seat_number)
	return hud.get_node_or_null("Frame/Workbench") as WorkbenchScreen if hud != null else null


static func is_open_for(seat_number: int) -> bool:
	var screen := for_seat(seat_number)
	return screen != null and screen.visible


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # clicks on the screen don't reach the game
	_build.call_deferred()


func _build() -> void:
	for i in Upgrades.WORKBENCH_TABS.size():
		var button := _button("")
		button.set_meta("tab", i)
		var face := TabFace.new()
		face.screen = self
		face.index = i
		_face(button, face)
		button.pressed.connect(_set_tab.bind(i))
		button.mouse_entered.connect(_on_highlight.bind(button))
		_tabs.append(button)
	for i in 4:
		var card := _button("")
		var face := CardFace.new()
		face.screen = self
		_face(card, face)
		card.pressed.connect(_press_card.bind(card))
		card.mouse_entered.connect(_on_highlight.bind(card))
		_cards.append(card)
	for vehicle in Upgrades.VEHICLE_UNLOCKS:
		var ride := _button(Upgrades.VEHICLE_NAMES[vehicle])
		ride.set_meta("vehicle", vehicle)
		ride.pressed.connect(_press_ride.bind(vehicle))
		ride.mouse_entered.connect(_on_highlight.bind(ride))
		_rides.append(ride)
	_recruit = _button("RECRUIT")
	_recruit.add_theme_font_size_override("font_size", card_title_size + 2)
	_recruit.pressed.connect(_press_recruit)
	_recruit.mouse_entered.connect(_on_highlight.bind(_recruit))
	_focus.press_on_accept = false
	_focus.highlighted.connect(_on_highlight)
	if Upgrades.instance != null:
		Upgrades.instance.recruited.connect(_on_recruited)
	_built = true


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE  # (the d-pad moves a highlight: _focus, seat_focus.gd)
	button.clip_text = true
	button.add_theme_font_size_override("font_size", card_title_size)
	button.add_theme_color_override("font_color", HudStyle.current().text_color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _box(false))
	button.add_theme_stylebox_override("hover", _box(true))
	button.add_theme_stylebox_override("pressed", _box(true))
	add_child(button)
	return button


func _face(button: Button, face: Control) -> void:
	face.name = "Face"
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(face)


func _box(lit: bool) -> StyleBoxFlat:
	var style := HudStyle.current()
	var box := StyleBoxFlat.new()
	box.bg_color = style.panel_color.lightened(0.12) if lit else style.panel_color
	box.border_color = style.border_color.lightened(0.45) if lit else style.faint_border_color.lerp(style.border_color, 0.45)
	box.set_border_width_all(int(Hud.line(3.0 if lit else 1.5)))
	box.set_content_margin_all(4)
	return box


# --- Opening / closing ---

func open(cat: CatPlayer, at_hub: UndergroundHub) -> void:
	if not _built or cat == null:
		return
	owner_cat = cat
	hub = at_hub
	_note = ""
	_info = default_info
	_last_key = ""
	visible = true
	if seat == 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # (the mouse is player 1's)
	_set_tab(tab)


func close() -> void:
	if not visible:
		return
	visible = false
	_focus.clear()
	owner_cat = null
	var first := Game.instance.my_cat() if Game.instance != null else null
	if seat == 0 and first != null and first.is_controlled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not visible or Seats.seat_of_event(event) != seat:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_tab_left") or event.is_action_pressed("ui_tab_right"):
		_set_tab(posmod(tab + (1 if event.is_action_pressed("ui_tab_right") else -1), _tabs.size()))
		get_viewport().set_input_as_handled()
	elif _focus.handle(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _focus.current != null:
			_focus.current.pressed.emit()
		get_viewport().set_input_as_handled()


func _set_tab(index: int) -> void:
	tab = clampi(index, 0, _tabs.size() - 1)
	_last_key = ""
	if visible and owner_cat != null:
		_refill()
		_layout()
		_refocus(_tabs[tab])


func _refocus(first: Button = null) -> void:
	var list: Array = _tabs.duplicate()
	for card in _cards:
		if card.visible:
			list.append(card)
	for ride in _rides:
		if ride.visible:
			list.append(ride)
	if _recruit.visible:
		list.append(_recruit)
	_focus.set_buttons(list, first if first != null else _tabs[tab])


# --- What each tab is ---

## The sewer NPC on workbench tab "index" (0 boss, 1 shopkeeper, 2-6 = rebellion tier 1-5), or null.
func npc_for_tab(index: int) -> Npc:
	if hub == null:
		return null
	if index == 0:
		return hub.npc
	if index == 1:
		return hub.shopkeeper
	for child in hub.get_children():
		if child is Npc and (child as Npc).rebellion_tier == index - 1:
			return child
	return null


## The portrait id of an NPC: its scene's file name (scenes/npcs/lil_mittens.tscn -> lil_mittens).
static func portrait_id(npc: Npc) -> String:
	return npc.scene_file_path.get_file().get_basename() if npc != null else ""


## The quest an NPC hands out (its first "quest:<id>" choice), as a title, or "".
static func quest_title(npc: Npc) -> String:
	if npc == null:
		return ""
	for page in npc.pages:
		for choice in page.choices:
			if choice.action.begins_with("quest:"):
				var data: QuestData = QuestManager.instance.catalog.get(choice.action.trim_prefix("quest:"))
				return data.title if data != null else ""
	return ""


func _team() -> int:
	return hub.team if hub != null else (owner_cat.team if owner_cat != null else 0)


## "open" = recruited (its upgrades show), "next" = not recruited yet (any of them can be recruited now).
func tab_state(index: int) -> String:
	return "open" if Upgrades.tab_unlocked(_team(), index) else "next"


func _refill() -> void:
	var state := tab_state(tab)
	var upgrades: Array = Upgrades.WORKBENCH_TABS[tab] if state == "open" else []
	for i in _cards.size():
		var card := _cards[i]
		card.visible = i < upgrades.size()
		(card.get_node("Face") as CardFace).upgrade_id = upgrades[i] if i < upgrades.size() else ""
		card.get_node("Face").queue_redraw()
	var show_rides := state == "open" and tab == Upgrades.WORKBENCH_TABS.size() - 1
	for ride in _rides:
		var vehicle: String = ride.get_meta("vehicle")
		var owned := owner_cat != null and Upgrades.instance.has_vehicle(owner_cat.player_id, vehicle)
		ride.visible = show_rides
		var current := Upgrades.instance.vehicle_of(_team()) == vehicle
		ride.text = ("> %s <" if current else "%s") % Upgrades.VEHICLE_NAMES[vehicle] + ("" if owned else "  (LOCKED)")
		ride.add_theme_color_override("font_color", GOOD if current else (HudStyle.current().text_color if owned else Color(1, 1, 1, 0.35)))
	_recruit.visible = state == "next"
	if state == "next" and owner_cat != null:
		var price: Array = Upgrades.instance.next_cost(owner_cat.player_id, Upgrades.recruit_id(tab - 1))
		_recruit.text = "RECRUIT TO THE REBELLION — $%d + %d SCRAP" % [price[0], price[1]]
	for t in _tabs:
		t.get_node("Face").queue_redraw()
		t.add_theme_stylebox_override("normal", _box(t.get_meta("tab") == tab))


# --- Every frame ---

func _process(delta: float) -> void:
	if not visible:
		return
	var cat := owner_cat
	if cat == null or not is_instance_valid(cat) or not cat.is_inside_tree() or hub == null \
			or cat.global_position.distance_to(hub.to_global(hub.workbench_spot)) > hub.workbench_radius + 2.5 or Hud.menu_open():
		close()
		return
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0:
			_note = ""
	var items := ItemManager.instance
	var key := "%s|%d|%d|%d|%s|%s" % [Upgrades.instance.player_upgrades.get(cat.player_id, {}), Wallet.instance.cash_of(cat.player_id),
		items.scrap_count_of(cat.player_id), Upgrades.rebellion_level(_team()), Upgrades.instance.team_vehicle, tab]
	if key != _last_key:
		_last_key = key
		_refill()
		_refocus(_focus.current if _focus.current != null and _focus.current.visible else _tabs[tab])
	_layout()
	queue_redraw()


func _layout() -> void:
	var w := minf(size.x - 48.0, panel_max_width)
	_panel = Rect2((size.x - w) / 2.0, 56.0, w, size.y - 80.0)
	var x := _panel.position.x + 12.0
	var tab_size := minf(tab_max_size, (w - 24.0 - gap * (_tabs.size() - 1)) / _tabs.size())
	var tabs_w := tab_size * _tabs.size() + gap * (_tabs.size() - 1)
	var tab_x := _panel.position.x + (w - tabs_w) / 2.0
	var tab_y := _panel.position.y + 44.0
	for i in _tabs.size():
		_place(_tabs[i], Rect2(tab_x + i * (tab_size + gap), tab_y, tab_size, tab_size + 16.0))
	var top := tab_y + tab_size + 16.0 + gap * 2
	var info_h := 62.0
	_info_rect = Rect2(x, _panel.end.y - info_h - 10.0, w - 24.0, info_h)
	_content = Rect2(x, top, w - 24.0, _info_rect.position.y - gap - top)
	# Left: who (portrait, name, quote, quest). Right: the cards.
	var cards_x := _content.position.x + _content.size.x * 0.42
	var cards_w := _content.end.x - cards_x
	var count := _cards.filter(func(c): return c.visible).size()
	var ride_h := 36.0 if _rides[0].visible else 0.0
	var h := minf(card_height, (_content.size.y - ride_h - gap * maxf(count, 1)) / maxf(count, 1))
	var y := _content.position.y
	for card in _cards:
		if card.visible:
			_place(card, Rect2(cards_x, y, cards_w, h))
			y += h + gap * 0.75
	if ride_h > 0.0:
		var rw := (cards_w - gap * (_rides.size() - 1)) / _rides.size()
		for i in _rides.size():
			_place(_rides[i], Rect2(cards_x + i * (rw + gap), y + 2.0, rw, ride_h - 4.0))
	_place(_recruit, Rect2(cards_x, _content.position.y + _content.size.y * 0.45, cards_w, 54.0))


func _place(button: Control, rect: Rect2) -> void:
	button.position = rect.position
	button.size = rect.size


func _draw() -> void:
	if not visible or owner_cat == null or not is_instance_valid(owner_cat):
		return
	var style := HudStyle.current()
	var font := get_theme_font("font", "Label")
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0.02, 0.05, 0.45))  # dim the sewer behind
	HudStyle.draw_panel(self, _panel)
	_text(font, _panel.position + Vector2(14, 30), "TINKER WORKBENCH", title_font_size, AMBER)
	var me := owner_cat.player_id
	var money := "$%d    %d SCRAP" % [Wallet.instance.cash_of(me), ItemManager.instance.scrap_count_of(me)]
	_text_right(font, Vector2(_panel.end.x - 14, _panel.position.y + 30), money, title_font_size - 2, GOOD)
	var money_w := font.get_string_size(money, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size - 2).x
	_text_right(font, Vector2(_panel.end.x - 24 - money_w, _panel.position.y + 28), "scrap = backpack + litterbox", detail_font_size, Color(style.text_color, 0.4))
	# The selected cat (left of the content area)
	var npc := npc_for_tab(tab)
	var state := tab_state(tab)
	var portrait_size := minf(150.0, _content.size.y * 0.5)
	var portrait_rect := Rect2(_content.position, Vector2(portrait_size, portrait_size))
	HudStyle.draw_panel(self, portrait_rect, state != "open")
	var portrait := HudStyle.npc_portrait(portrait_id(npc) if state == "open" else "locked_mystery")
	if portrait != null:
		draw_texture_rect(portrait, portrait_rect.grow(-6), false)
	var tx := _content.position.x
	var ty := portrait_rect.end.y + 26.0
	var text_w := _content.size.x * 0.42 - 16.0
	if state == "open":
		_text(font, Vector2(tx, ty), npc.npc_name if npc != null else "?", name_font_size, Color.WHITE, text_w)
		_text(font, Vector2(tx, ty + 20), Upgrades.TAB_ROLES[tab] + ("" if tab < 2 else "   (REBELLION RECRUIT)"), detail_font_size, AMBER, text_w)
		var quote := ""
		if npc != null and not npc.pages.is_empty() and not npc.pages[0].lines.is_empty():
			quote = "\"%s\"" % npc.pages[0].lines[0]
		draw_multiline_string(font, Vector2(tx, ty + 42), quote, HORIZONTAL_ALIGNMENT_LEFT, text_w, detail_font_size, 3, Color(style.text_color, 0.75))
		var quest := quest_title(npc)
		_text(font, Vector2(tx, ty + 42 + detail_font_size * 3.6 + 8), ("QUEST IN SEWER: %s" % quest) if quest != "" else "NO QUEST: %s" % ("DEPLOY + LORE" if tab == 0 else "THE SHOP"),
			detail_font_size + 1, GOOD if quest != "" else Color(style.text_color, 0.5), text_w)
	else:
		_text(font, Vector2(tx, ty), "? ? ?", name_font_size, Color(style.text_color, 0.5), text_w)
		_text(font, Vector2(tx, ty + 20), "REBELLION RECRUIT — %s" % Upgrades.RECRUIT_TYPES[tab], detail_font_size, AMBER, text_w)
		# The right side: what to do about it.
		var cards_x := _content.position.x + _content.size.x * 0.42
		var cards_w := _content.end.x - cards_x
		var box := Rect2(cards_x, _content.position.y, cards_w, _content.size.y * 0.42)
		HudStyle.draw_panel(self, box)
		_text(font, box.position + Vector2(14, 30), "RECRUIT: %s" % Upgrades.RECRUIT_TYPES[tab], name_font_size, AMBER, cards_w - 28)
		# You only get to know WHAT they bring, not who they are.
		var brings := ", ".join(Array(Upgrades.WORKBENCH_TABS[tab]).map(func(u): return Upgrades.INFO[u].name))
		_text(font, box.position + Vector2(14, 54), "BRINGS: " + brings, detail_font_size + 1, GOOD, cards_w - 28)
		var words := "A cat is hiding in the pipes. Recruit them and they move into your sewer: their quest, these upgrades, and one more gun when OVERCLEAN breaches. Recruit #%d of %d for your gang." \
			% [Upgrades.rebellion_level(_team()) + 1, Upgrades.REBELLION_TIERS]
		draw_multiline_string(font, box.position + Vector2(14, 78), words, HORIZONTAL_ALIGNMENT_LEFT, cards_w - 28, detail_font_size + 1, 3,
			Color(style.text_color, 0.8))
	# The bottom box
	HudStyle.draw_panel(self, _info_rect, true)
	var shown := _note if _note != "" else _info
	var color := (GOOD if _note_good else BAD) if _note != "" else style.text_color
	draw_multiline_string(font, _info_rect.position + Vector2(10, 22), shown, HORIZONTAL_ALIGNMENT_LEFT, _info_rect.size.x - 20,
		detail_font_size + 1, 3, color)


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color, max_width: float = -1.0) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, Hud.outline(4), Color(0, 0.03, 0.06, color.a * 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, color)


func _text_right(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(font, at - Vector2(width, 0), text, font_size, color)


# --- Buying ---

func _press_card(card: Button) -> void:
	var upgrade_id: String = (card.get_node("Face") as CardFace).upgrade_id
	if upgrade_id == "" or owner_cat == null:
		return
	if Upgrades.instance.current_tier(owner_cat.player_id, upgrade_id) >= Upgrades.instance.max_tier(upgrade_id):
		Sound.play("error")
		note("Already maxed out.", false)
		return
	Upgrades.instance.request_buy.rpc_id(1, owner_cat.player_id, upgrade_id)


func _press_recruit() -> void:
	if owner_cat != null and _recruit.visible:
		Upgrades.instance.request_buy.rpc_id(1, owner_cat.player_id, Upgrades.recruit_id(tab - 1))


func _press_ride(vehicle: String) -> void:
	if owner_cat == null:
		return
	if not Upgrades.instance.has_vehicle(owner_cat.player_id, vehicle):
		Sound.play("error")
		note("Unlock the %s first (the card above)." % Upgrades.VEHICLE_NAMES[vehicle], false)
		return
	Upgrades.instance.request_select_vehicle.rpc_id(1, owner_cat.player_id, vehicle)


## A gang recruited a new tier (every computer): if it's ours and we're looking, celebrate and show them.
func _on_recruited(team: int, tier: int) -> void:
	if not visible or team != _team():
		return
	var npc := npc_for_tab(tier + 1)
	_celebrating_until = 0.0  # (a second recruit right after the first still gets its own news)
	note("NEW RECRUIT! %s JOINS THE REBELLION! Their quest and upgrades are open." % (npc.npc_name if npc != null else "A CAT"), true)
	_celebrating_until = Time.get_ticks_msec() / 1000.0 + 1.0
	Sound.play("koi_grab")  # (a prize jingle)
	_set_tab(tier + 1)


## A message in the bottom box for a few seconds (green = good news, red = no).
func note(text: String, good: bool) -> void:
	if good and Time.get_ticks_msec() / 1000.0 < _celebrating_until:
		return  # (keep the NEW RECRUIT news up)
	_note = text
	_note_good = good
	_note_left = note_seconds
	queue_redraw()


func _on_highlight(button: Button) -> void:
	if button == null or owner_cat == null:
		return
	if button.has_meta("tab"):
		var i: int = button.get_meta("tab")
		var npc := npc_for_tab(i)
		match tab_state(i):
			"open":
				_info = "%s — %s. Upgrades: %s." % [npc.npc_name if npc != null else "?", Upgrades.TAB_ROLES[i],
					", ".join(Array(Upgrades.WORKBENCH_TABS[i]).map(func(u): return Upgrades.INFO[u].name))]
			_:
				_info = "? — a REBELLION RECRUIT who brings %s: %s. Recruit them on this tab (any order)." % [Upgrades.RECRUIT_TYPES[i],
					", ".join(Array(Upgrades.WORKBENCH_TABS[i]).map(func(u): return Upgrades.INFO[u].name))]
	elif button == _recruit:
		_info = "Recruit the %s cat: they move into your sewer, offer a quest, fight in breaches and open their upgrades. Shared with your whole gang." % Upgrades.RECRUIT_TYPES[tab]
	elif button.has_meta("vehicle"):
		_info = "Your gang's ride: click to switch to the %s (only while it's parked)." % Upgrades.VEHICLE_NAMES[button.get_meta("vehicle")]
	else:
		var upgrade_id: String = (button.get_node("Face") as CardFace).upgrade_id
		if upgrade_id != "":
			var info: Dictionary = Upgrades.INFO[upgrade_id]
			_info = "%s%s: %s" % [info.name, " (CREW: your whole gang gets the best tier anyone owns)" if info.get("crew", false) else "", info.about]


## One portrait tab on top: the cat's face and name, or a "?" while they're not recruited.
class TabFace extends Control:
	var screen: WorkbenchScreen
	var index := 0

	func _draw() -> void:
		var font := get_theme_font("font", "Label")
		var open := screen.tab_state(index) == "open"
		var npc := screen.npc_for_tab(index)
		var picture := Rect2(4, 4, size.x - 8, size.y - 22)
		var texture := HudStyle.npc_portrait(WorkbenchScreen.portrait_id(npc) if open else "locked_mystery")
		if texture != null:
			var side := minf(picture.size.x, picture.size.y)
			draw_texture_rect(texture, Rect2(picture.get_center() - Vector2(side, side) / 2.0, Vector2(side, side)), false,
				Color.WHITE if open else Color(1, 1, 1, 0.75))
		# Not recruited yet: just the KIND of upgrades they bring (SNACKS / TOUGH / MELEE / CASH / SPEED).
		var label: String = (npc.npc_name if npc != null else "?") if open else Upgrades.RECRUIT_SHORT[index]
		label = label.replace("COMRADE ", "").replace("CATLEONE", "").strip_edges()
		var font_size := 11
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var color := Color.WHITE if open else WorkbenchScreen.AMBER
		draw_string_outline(font, Vector2(maxf(2, (size.x - w) / 2.0), size.y - 5), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 4, font_size, Hud.outline(3), Color(0, 0.03, 0.06))
		draw_string(font, Vector2(maxf(2, (size.x - w) / 2.0), size.y - 5), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 4, font_size, color)


## One upgrade card: name, tier pips, what it does, and BUY — $X + Y SCRAP (or MAXED).
class CardFace extends Control:
	var screen: WorkbenchScreen
	var upgrade_id := ""

	func _draw() -> void:
		if upgrade_id == "" or screen.owner_cat == null:
			return
		var style := HudStyle.current()
		var font := get_theme_font("font", "Label")
		var upgrades := Upgrades.instance
		var me := screen.owner_cat.player_id
		var info: Dictionary = Upgrades.INFO.get(upgrade_id, {})
		var tier := upgrades.current_tier(me, upgrade_id)
		var top := upgrades.max_tier(upgrade_id)
		var maxed := tier >= top
		var title: String = info.get("name", upgrade_id) + (" (CREW)" if info.get("crew", false) else "")
		var buy_w := 190.0
		var text_w := size.x - buy_w - 24.0
		_text(font, Vector2(10, 6 + screen.card_title_size), title, screen.card_title_size, Color.WHITE, text_w)
		# Tier pips: [■ ■ □] TIER 2/3
		var pip := 9.0
		var px := 10.0
		var py := 12.0 + screen.card_title_size
		for i in top:
			var filled := i < tier
			draw_rect(Rect2(px + i * (pip + 4), py, pip, pip), style.border_color if filled else Color(style.border_color, 0.25), filled)
			if not filled:
				draw_rect(Rect2(px + i * (pip + 4), py, pip, pip), Color(style.border_color, 0.6), false, Hud.line(1.0))
		var tier_text := ("UNLOCKED" if top == 1 else "TIER %d/%d" % [tier, top]) if tier > 0 else ("NOT OWNED" if top == 1 else "TIER 0/%d" % top)
		if info.has("tiers") and not maxed:
			tier_text += "   NEXT: " + str(info.tiers[tier])
		_text(font, Vector2(px + top * (pip + 4) + 6, py + pip), tier_text, screen.detail_font_size, WorkbenchScreen.AMBER, text_w - top * (pip + 4))
		if size.y > 56:
			draw_multiline_string(font, Vector2(10, py + pip + 6 + screen.detail_font_size), str(info.get("about", "")), HORIZONTAL_ALIGNMENT_LEFT,
				text_w, screen.detail_font_size, 2, Color(style.text_color, 0.7))
		# The BUY pill
		var pill := Rect2(size.x - buy_w - 8, size.y / 2.0 - 16, buy_w, 32)
		var label := "MAXED"
		var fill := Color(0.12, 0.16, 0.22, 0.85)
		if not maxed:
			var price: Array = upgrades.next_cost(me, upgrade_id)
			label = "%s — $%d + %d SCRAP" % ["UNLOCK" if top == 1 else "BUY", price[0], price[1]]
			var can := Wallet.instance.cash_of(me) >= int(price[0]) and ItemManager.instance.scrap_count_of(me) >= int(price[1])
			fill = Color(0.1, 0.45, 0.25, 0.85) if can else Color(0.35, 0.1, 0.1, 0.8)
		draw_rect(pill, fill)
		draw_rect(pill, Color(style.border_color, 0.6), false, Hud.line(1.0))
		var lw := minf(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, screen.detail_font_size + 1).x, buy_w - 8)
		_text(font, Vector2(pill.get_center().x - lw / 2.0, pill.get_center().y + 5), label, screen.detail_font_size + 1, Color.WHITE, buy_w - 8)

	func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color, max_width: float = -1.0) -> void:
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, Hud.outline(4), Color(0, 0.03, 0.06, color.a * 0.9))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, color)
