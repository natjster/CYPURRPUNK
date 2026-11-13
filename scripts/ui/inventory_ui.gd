class_name InventoryScreen
extends Control
## INVENTORY SCREEN — press Tab or I (controller Y) to open / close (Esc / B closes too).
## Part of the HUD (scenes/ui/hud.tscn > HUD > Frame > Inventory), drawn in the shared ocean-blue
## style (scripts/ui/hud_style.gd, colours in ui/hud_style.tres).
##
## THE BACKPACK VIEW (a "No Man's Sky" style callout screen):
##   - The camera glides in behind your cat (cat_player.gd, "Inventory Camera" exports) so its
##     BACKPACK sits on the left of the screen. Your cat stands still while it's open.
##   - Thin ocean-blue CALLOUT LINES run from the real 3D backpack (its PackAnchor marker) and from
##     your paws to translucent boxes on the right:
##
##       ┌ JOB ─────────────────────────────── [ABANDON] ┐   your one quest
##       ┌ LEFT PAW ┐ ┌ RIGHT PAW ┐ ┌ 1 ┐ ┌ 2 ┐            paws + QUICK USE (keys 1 / 2)
##   (o)─┤ BACKPACK  4/6                         │          one backpack for EVERYTHING: fish,
##       │ [icon $50] [icon $50] [icon  ]        │          koi, scrap, spare guns (3 per row,
##       │ [icon $20] [  ----  ] [ ---- ]        │          more rows with BIGGER BACKPACK)
##       └───────────────────────────────────────┘
##       ┌ what the highlighted thing is, its price, the buttons ┐
##
##     Each slot shows the item's side-view picture (ui/icons/items/<id>.png), its name and a
##     PRICE BADGE: what the shop pays for loot ($50 fish), or what gear costs to buy.
##     CONSUMABLES (catnip, catdip) STACK in one backpack slot, like a QUICK USE slot ("x3" in the
##     corner; ItemManager.pack_stacks). A click uses / moves / sells / drops ONE off the stack.
##   - AT THE LITTERBOX (standing at it in the sewers, or pressing E there) a LITTERBOX box opens
##     on the left, under your cat, with its own callout line to the litterbox.
##
## CLICKS (the d-pad / stick moves a highlight instead on a controller; A = click, X = drop):
##   backpack gear   = take it into your paws          paw    = put it in the backpack
##   backpack catnip = into a QUICK USE slot           quick  = put one back in the backpack
##   backpack loot   = (nothing: sell it at the Black Markitten, or bury it in the litterbox)
##   at the litterbox: click anything of yours = bury it; click a litterbox slot = dig it out
##   Right-click (X) = drop it on the ground in front of you.
##   JOB: ABANDON (press twice) drops your quest, progress lost: only down in the sewers.
##
## (Selling happens in THE BLACK MARKITTEN's own window now: its SELL strip, scripts/ui/shop_screen.gd.)
##
## SPLIT SCREEN: every player has their own inventory in their own HUD (Hud.seat), with their own
## camera glide. InventoryScreen.for_seat(seat) finds it.
## The screen only ASKS the item system (ItemManager) to move things; the host decides, and the
## screen redraws itself from the result. So it's always in sync in multiplayer.
##
## What it builds (all in code, the scene only has the empty node):
##   Inventory (this: draws the panels + callout lines in _draw)
##   ├── Abandon (Button)
##   ├── Slots: one Button per paw / quick slot / backpack slot / litterbox slot, each with a
##   │   SlotFace child that draws the picture, name and price
##   └── Info (Label)  the bottom box's words

## Player 1's inventory screen.
static var instance: InventoryScreen

## Which player's screen this is (its HUD's seat).
var seat: int = 0
## Whose things are showing: this seat's cat (set when it opens).
var owner_cat: CatPlayer = null
## This player's highlighted slot (scripts/ui/seat_focus.gd): their d-pad / arrows move it,
## A / Enter = click it, X = drop it (handled here, so A doesn't "press" the slot itself).
var _focus := SeatFocus.new()

@export_group("Layout")
## Where the right-hand column starts (fraction of the screen width) and its widest size (HUD units).
@export_range(0.3, 0.7) var column_start: float = 0.5
@export var column_max_width: float = 470.0
## Backpack slots per row.
@export var columns: int = 3
## Biggest a backpack slot gets (HUD units); it shrinks when there are many rows.
@export var slot_max_size: Vector2 = Vector2(140, 104)
## Paw and quick-use boxes.
@export var paw_box_size: Vector2 = Vector2(128, 84)
@export var quick_box_size: Vector2 = Vector2(78, 84)
@export var gap: float = 10.0

@export_group("Words")
@export var title_font_size: int = 17
@export var name_font_size: int = 13
@export var price_font_size: int = 13
@export var info_font_size: int = 15

@export_group("Callout lines")
## The glowing dot on the 3D backpack / paws, and the line width (Hud.line keeps it visible in
## the PS1 look).
@export var anchor_dot_radius: float = 5.0
@export var line_width: float = 2.0
## How far the panels slide in from the right as the view opens (HUD units).
@export var slide_in: float = 40.0
## SHOP MODE: where our column starts (fraction of the screen width; the cat stands left of it).

## The JOB strip's colours.
const JOB_COLOR := Color(1, 0.8, 0.3)
const ABANDON_COLOR := Color(1, 0.35, 0.3)

var _paw_buttons: Array[Button] = []    # [left paw, right paw] as shown on screen (hands[1], hands[0])
var _quick_buttons: Array[Button] = []  # [quick use 1, quick use 2]
var _pack_buttons: Array[Button] = []
var _stash_buttons: Array[Button] = []
var _abandon_button: Button
var _info: Label
var _job_text := ""
var _last_key := ""
var _at_stash := false
var _built := false
## True after the first ABANDON press (the second one really drops the job).
var _abandon_armed := false
## Where things went this frame (HUD units), for _draw.
var _rects := {}
var _view := 0.0  # 0..1: how far the camera glide is (the boxes fade + slide in with it)


func _enter_tree() -> void:
	seat = (owner as Hud).seat if owner is Hud else 0
	if seat == 0:
		instance = self


## This player's inventory screen (seat 0 = player 1), or null.
static func for_seat(seat_number: int) -> InventoryScreen:
	var hud := Hud.of(seat_number)
	return hud.get_node_or_null("Frame/Inventory") as InventoryScreen if hud != null else null


func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # clicks on the screen don't reach the game
	_build.call_deferred()  # after the game (and its ItemManager, which knows the slot counts) is ready


func _build() -> void:
	for i in 2:  # left paw (hands[1]), right paw (hands[0])
		_paw_buttons.append(_slot("hand", 1 - i))
	for i in 2:
		_quick_buttons.append(_slot("quick", i))
	_abandon_button = Button.new()
	_abandon_button.name = "Abandon"
	_abandon_button.text = "ABANDON"
	_abandon_button.focus_mode = Control.FOCUS_NONE
	_abandon_button.set_meta("where", "quest")
	_abandon_button.set_meta("index", 0)
	_abandon_button.set_meta("item", "")
	_abandon_button.add_theme_font_size_override("font_size", name_font_size + 1)
	_abandon_button.add_theme_color_override("font_color", ABANDON_COLOR)
	_abandon_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_abandon_button.add_theme_stylebox_override("normal", _box_style(false))
	_abandon_button.add_theme_stylebox_override("hover", _box_style(true))
	_abandon_button.add_theme_stylebox_override("pressed", _box_style(true))
	_abandon_button.gui_input.connect(_on_slot_input.bind(_abandon_button, "quest", 0))
	add_child(_abandon_button)
	_info = Label.new()
	_info.name = "Info"
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", info_font_size)
	_info.add_theme_color_override("font_color", HudStyle.current().text_color)
	_info.add_theme_constant_override("outline_size", 0)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)
	_focus.press_on_accept = false
	_focus.highlighted.connect(_on_slot_hover)  # show what the highlighted item is
	Controls.changed.connect(func():  # switched keyboard <-> controller: redo the hints line
		if visible:
			_show_hints())
	_built = true


func _input(event: InputEvent) -> void:
	if Seats.seat_of_event(event) != seat:
		return  # another player's button (player 1's HUD hears every button first)
	if ShopScreen.is_open_for(seat):
		return  # at the shop, the shop screen handles every button
	if event.is_action_pressed("inventory") and not Hud.menu_open() and not NpcDialog.is_open_for(seat):
		var cat := Game.instance.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat))
		if visible:
			_set_open(false)
		elif cat != null and cat.reads_input():
			_set_open(true, cat)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()
	elif visible and _focus.handle(event):  # d-pad / arrows: move the highlight
		get_viewport().set_input_as_handled()
	elif visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_drop")):
		# Controller / keyboard: A (Enter) = click the highlighted slot, X = drop it.
		var slot := _focus.current
		if slot != null and slot.has_meta("where"):
			_use_slot(slot, slot.get_meta("where"), slot.get_meta("index"), event.is_action_pressed("ui_drop"))
			get_viewport().set_input_as_handled()


## Open the screen for this cat (the cat calls this when E is pressed at the litterbox).
func open(cat: CatPlayer) -> void:
	if not visible:
		_set_open(true, cat)


func _set_open(open_it: bool, cat: CatPlayer = null) -> void:
	if not _built:
		return  # not built yet (the very first frame)
	if open_it:
		owner_cat = cat if cat != null else Game.instance.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat))
		if owner_cat == null:
			return
		_match_sizes()
	visible = open_it
	_last_key = ""
	if open_it:
		if seat == 0:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # (the mouse is player 1's)
		_abandon_armed = false
		_at_stash = UndergroundHub.of(owner_cat).near_stash(owner_cat)
		_show_hints()
		_refocus()
	else:
		_focus.clear()
		var first := Game.instance.my_cat() if Game.instance != null else null
		if seat == 0 and first != null and first.is_controlled:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A highlighted slot for the d-pad / arrows to move around from (the backpack's first slot).
func _refocus() -> void:
	var first: Button = _pack_buttons[0] if not _pack_buttons.is_empty() else _paw_buttons[0]
	_focus.set_buttons([_abandon_button] + _paw_buttons + _quick_buttons + _pack_buttons + _stash_buttons, first)


func _process(_delta: float) -> void:
	if not visible:
		return
	var items := ItemManager.instance
	var cat := owner_cat
	if cat == null or not is_instance_valid(cat) or not cat.is_inside_tree():
		_set_open(false)  # (the cat left: knocked out of the game, a new game, the player quit)
		return
	var at_stash := UndergroundHub.of(cat).near_stash(cat)
	if _match_sizes():
		_refocus()
	_view = cat.inventory_view_amount()
	modulate.a = clampf(_view * 1.6, 0.0, 1.0)
	_layout(cat, at_stash)
	queue_redraw()
	var inventory := items.get_inventory(cat.player_id)
	var quests := QuestManager.instance
	var key := str(inventory) + str(at_stash) + quests.current_quest(cat.player_id) \
		+ quests.progress_text(cat.player_id) + str(_abandon_armed) + str(Wallet.instance.cash_of(cat.player_id))
	if key == _last_key:
		return
	_last_key = key  # only refill the slots when something changed
	if at_stash != _at_stash:
		_at_stash = at_stash
		_show_hints()
	_show_job(cat)
	var hands: Array = inventory.hands
	var two_paws: bool = hands[0] != "" and (items.catalog[hands[0]] as ItemData).hands == 2
	_fill(_paw_buttons[0], "BOTH PAWS" if two_paws else "", hands[1] if not two_paws else hands[0])
	_fill(_paw_buttons[1], "", hands[0])
	var quick := items.quick_slots(cat.player_id)
	for i in 2:
		_fill(_quick_buttons[i], "", quick[i][0] if not quick[i].is_empty() else "", quick[i].size())
	# The backpack as SLOTS: consumables (catnip, catdip) stack, so one slot can show "x3".
	# Each button remembers where its top item sits in the real item list ("pack_index"): that's
	# what a click sends to the host (see _use_slot).
	var stacks := items.pack_stacks(cat.player_id)
	for i in _pack_buttons.size():
		var stack: Dictionary = stacks[i] if i < stacks.size() else {"id": "", "count": 1, "index": -1}
		_pack_buttons[i].set_meta("pack_index", stack.index)
		_fill(_pack_buttons[i], "", stack.id, stack.count)
	var stash := items.get_stash(cat.player_id)
	for i in _stash_buttons.size():
		_fill(_stash_buttons[i], "", stash[i] if i < stash.size() else "")
		_stash_buttons[i].visible = at_stash
	# A d-pad highlight on a litterbox slot that just hid (walked away): back to the backpack.
	if not at_stash and _focus.current != null and _focus.current in _stash_buttons:
		_refocus()


# --- Layout: where every box goes this frame (the camera glides, so this follows it) ---

func _layout(cat: CatPlayer, at_stash: bool) -> void:
	var items := ItemManager.instance
	var slide := (1.0 - _view) * slide_in
	var col_w := minf(size.x * (1.0 - column_start) - 24.0, column_max_width)
	var col_x := size.x - col_w - 24.0 + slide
	var y := 60.0
	# JOB strip
	var job := Rect2(col_x, y, col_w, 40.0)
	_rects.job = job
	_abandon_button.visible = QuestManager.instance.current_quest(cat.player_id) != ""
	_abandon_button.size = Vector2(118, 28)
	_abandon_button.position = Vector2(job.end.x - 124, job.position.y + 6)
	y = job.end.y + gap + 22  # (room for the row's titles and the quick-use line)
	# PAWS + QUICK USE row (shrinks to fit a narrow split-screen pane)
	var quick_w := minf(quick_box_size.x, col_w * 0.18)
	var paw_w := minf(paw_box_size.x, (col_w - 3.0 * gap - 2.0 * quick_w) / 2.0)
	var row_h := minf(paw_box_size.y, maxf(paw_w * 0.7, 56.0))
	var x := col_x
	for i in 2:
		_place(_paw_buttons[i], Rect2(x, y, paw_w, row_h))
		x += paw_w + gap
	x = maxf(x, col_x + col_w - 2.0 * quick_w - gap)
	for i in 2:
		_place(_quick_buttons[i], Rect2(x, y, quick_w, row_h))
		x += quick_w + gap
	y += row_h + gap
	# BACKPACK panel: title + grid, slots shrink to fit what's left above the info box
	var info_h := 74.0
	var rows := ceili(_pack_buttons.size() / float(columns))
	var room := size.y - y - info_h - gap - 36.0 - 24.0
	var slot_w := (col_w - 16.0 - (columns - 1) * 6.0) / columns
	var slot_h := clampf((room - (rows - 1) * 6.0) / maxf(rows, 1), 40.0, slot_max_size.y)
	slot_w = minf(slot_w, slot_max_size.x)
	var pack_rect := Rect2(col_x, y, col_w, 30.0 + rows * slot_h + (rows - 1) * 6.0 + 12.0)
	_rects.pack = pack_rect
	for i in _pack_buttons.size():
		var cell := Vector2(i % columns, i / columns)
		_place(_pack_buttons[i], Rect2(pack_rect.position + Vector2(8, 30) + cell * Vector2(slot_w + 6, slot_h + 6), Vector2(slot_w, slot_h)))
	# INFO box under it
	var info := Rect2(col_x, pack_rect.end.y + gap, col_w, info_h)
	_rects.info = info
	_info.position = info.position + Vector2(10, 4)
	_info.size = info.size - Vector2(20, 8)
	# LITTERBOX (only at it): bottom-left, under the cat
	_rects.erase("stash")
	if at_stash and not _stash_buttons.is_empty():
		var stash_w := minf(size.x * column_start - 48.0, 420.0)
		var stash_cols := clampi(int(stash_w / 70.0), 3, 7)
		var stash_rows := ceili(_stash_buttons.size() / float(stash_cols))
		var cell_w := (stash_w - 16.0 - (stash_cols - 1) * 6.0) / stash_cols
		var cell_h := clampf((size.y * 0.42 - 40.0) / stash_rows - 6.0, 34.0, cell_w)
		var stash_h := 30.0 + stash_rows * (cell_h + 6.0) + 6.0
		var stash_rect := Rect2(24.0 - slide, size.y - stash_h - 24.0, stash_w, stash_h)
		_rects.stash = stash_rect
		for i in _stash_buttons.size():
			var cell := Vector2(i % stash_cols, i / stash_cols)
			_place(_stash_buttons[i], Rect2(stash_rect.position + Vector2(8, 30) + cell * Vector2(cell_w + 6, cell_h + 6), Vector2(cell_w, cell_h)))
	# Where the lines start: the 3D backpack, the paws, the belt, the litterbox (projected).
	_rects.anchor_pack = _project(items.backpack_anchor(cat))
	_rects.anchor_paws = [
		_project(cat.cat_model.to_global(Vector3(-0.3, 0.42, -0.2))),  # left paw
		_project(cat.cat_model.to_global(Vector3(0.3, 0.42, -0.2))),  # right paw
	]
	_rects.anchor_belt = _project(cat.cat_model.to_global(Vector3(0.12, 0.3, -0.12)))
	var hub := UndergroundHub.of(cat)
	_rects.anchor_stash = _project(hub.to_global(hub.stash_spot)) if at_stash else null


func _place(button: Button, rect: Rect2) -> void:
	button.position = rect.position
	button.size = rect.size


## A 3D spot -> this screen (HUD units), using THIS player's camera. null = behind the camera.
func _project(where: Vector3) -> Variant:
	var screen := GameScreen.instance
	var camera: Camera3D = screen.camera_for_seat(seat) if screen != null else null
	if camera == null or camera.is_position_behind(where):
		return null
	var game_size: Vector2 = screen.screen_size_for_seat(seat)
	return camera.unproject_position(where) * (size / game_size)


# --- Drawing: panels, titles, callout lines (the slots draw themselves on top) ---

func _draw() -> void:
	if not visible or _rects.is_empty():
		return
	var style := HudStyle.current()
	var font := get_theme_font("font", "Label")
	# A soft dark fade behind the boxes so they read over a bright street.
	var fade_from := size.x * (column_start - 0.08)
	draw_polygon(PackedVector2Array([Vector2(fade_from, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(fade_from, size.y)]),
		PackedColorArray([Color(0, 0.02, 0.05, 0.0), Color(0, 0.02, 0.05, 0.45), Color(0, 0.02, 0.05, 0.45), Color(0, 0.02, 0.05, 0.0)]))
	# JOB
	var job: Rect2 = _rects.job
	if job.size.y > 0.0:
		HudStyle.draw_panel(self, job)
		var cash_right := job.end.x - (134.0 if _abandon_button.visible else 10.0)
		if owner_cat != null and is_instance_valid(owner_cat):
			_text_right(font, Vector2(cash_right, job.position.y + job.size.y / 2.0 + 5), "$%d" % Wallet.instance.cash_of(owner_cat.player_id), title_font_size, Color(0.55, 1, 0.6))
		_text(font, job.position + Vector2(10, job.size.y / 2.0 + 5), _job_text, name_font_size + 1, JOB_COLOR, cash_right - job.position.x - 62.0)
	# Row titles
	var paw_rect := _paw_buttons[0].get_rect()
	_text(font, paw_rect.position + Vector2(2, -5), "PAWS", title_font_size - 3, style.text_color)
	_text(font, _quick_buttons[0].get_rect().position + Vector2(2, -5), "QUICK USE", title_font_size - 3, style.text_color)
	# BACKPACK
	var pack: Rect2 = _rects.pack
	HudStyle.draw_panel(self, pack)
	var cat := owner_cat
	var items := ItemManager.instance
	if cat != null and is_instance_valid(cat):
		var used: int = items.pack_slots_used(cat.player_id, items.get_inventory(cat.player_id).pack)
		var total := items.pack_size_for(cat.player_id)
		_text(font, pack.position + Vector2(10, 22), "BACKPACK  %d/%d" % [used, total], title_font_size, style.text_color)
		var worth := items.pack_sell_value(cat.player_id)
		if worth > 0:
			_text_right(font, pack.position + Vector2(pack.size.x - 10, 22), "LOOT $%d" % worth, title_font_size - 2, Color(0.55, 1, 0.6))
	# INFO
	HudStyle.draw_panel(self, _rects.info)
	# LITTERBOX
	if _rects.has("stash"):
		var stash: Rect2 = _rects.stash
		HudStyle.draw_panel(self, stash)
		if cat != null and is_instance_valid(cat):
			_text(font, stash.position + Vector2(10, 22), "LITTERBOX  %d/%d   (safe, kept between games)" % [items.get_stash(cat.player_id).size(), items.stash_size_for(cat.player_id)],
				title_font_size - 2, style.text_color, stash.size.x - 20)
	# CALLOUT LINES (fade in with the camera glide)
	var line_color := style.border_color
	line_color.a *= clampf(_view * 1.4 - 0.2, 0.0, 1.0)
	_callout(_rects.anchor_pack, Vector2(pack.position.x, pack.position.y + 22), line_color)
	# Paws: one line from between the paws into the PAWS row's left edge.
	var paws: Array = _rects.anchor_paws
	var left_box := _paw_buttons[0].get_rect()
	if paws[0] != null and paws[1] != null:
		_callout((paws[0] + paws[1]) / 2.0, Vector2(left_box.position.x, left_box.get_center().y), line_color)
	# Quick use: from the belt, up over the PAWS row (in the gap under the JOB strip), down into slot 1.
	var quick_box := _quick_buttons[0].get_rect()
	var over_y: float = (_rects.job as Rect2).end.y + 5.0
	_callout(_rects.anchor_belt, Vector2(quick_box.position.x + 12.0, quick_box.position.y), line_color, false,
		[Vector2(left_box.position.x - 22.0, over_y), Vector2(quick_box.position.x + 12.0, over_y)])
	if _rects.has("stash") and _rects.get("anchor_stash") != null:
		var stash_rect: Rect2 = _rects.stash
		_callout(_rects.anchor_stash, Vector2(stash_rect.position.x + stash_rect.size.x * 0.5, stash_rect.position.y), line_color, true)


## A callout: glowing dot on the 3D spot, a slanted line, then a short flat line into the box.
## from_below = arrive at the box's bottom / top edge (straight up / down) instead of its side.
## via = corner points to pass on the way (instead of the one automatic elbow).
func _callout(from: Variant, to: Vector2, color: Color, from_below: bool = false, via: Array = []) -> void:
	if from == null or color.a <= 0.01:
		return
	var start: Vector2 = from
	var width := Hud.line(line_width)
	var points := PackedVector2Array([start])
	if not via.is_empty():
		for corner in via:
			points.append(corner)
	elif from_below:
		points.append(Vector2(to.x, to.y + (24.0 if start.y > to.y else -24.0)))
	else:
		points.append(Vector2(to.x - 34.0, to.y))
	points.append(to)
	draw_polyline(points, color, width)
	var glow := color
	glow.a *= 0.35
	draw_circle(start, anchor_dot_radius * 2.0, glow)
	draw_circle(start, anchor_dot_radius, color.lightened(0.4))
	draw_circle(to, width * 1.5, color)


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color, max_width: float = -1.0) -> void:
	if text == "":
		return
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, Hud.outline(4), Color(0, 0.03, 0.06, color.a * 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, color)


func _text_right(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(font, at - Vector2(width, 0), text, font_size, color)


# --- Filling the slots ---

## The JOB strip: "JOB: MITTENS' FISH  1/3  +$100" (the hover line has room for the long version).
func _show_job(cat: CatPlayer) -> void:
	var quests := QuestManager.instance
	var quest_id := quests.current_quest(cat.player_id)
	var data: QuestData = quests.catalog.get(quest_id)
	if data == null:
		_abandon_armed = false
		_job_text = "JOB: none - talk to the cats in the sewers"
		return
	var line := "%d/%d" % [mini(quests.progress(cat.player_id, quest_id), data.count), data.count]
	if quests.is_in_state(cat.player_id, quest_id, "ready"):
		line += " - DONE! EXTRACT"
	_job_text = "JOB: %s  %s  +$%d" % [data.title, line, data.reward_cash]
	_abandon_button.text = "SURE? AGAIN" if _abandon_armed else "ABANDON"


## The line at the bottom: what clicks do here (changes at the litterbox / with a controller).
func _show_hints() -> void:
	var on_pad := owner_cat != null and is_instance_valid(owner_cat) and Seats.uses_pad(owner_cat.slot)
	var click := "%s:" % Controls.display_name("Pad A") if on_pad else "Click:"
	var drop := "%s:" % Controls.display_name("Pad X") if on_pad else "Right-click:"
	if _at_stash:
		_info.text = "%s bury in / dig out of the litterbox   %s drop   %s: close" % [click, drop, Controls.key_text("inventory")]
	else:
		_info.text = "%s equip / put away   %s drop   %s: close" % [click, drop, Controls.key_text("inventory")]


## Put an item (or nothing) in a slot. label = words instead of the item's name ("BOTH PAWS").
func _fill(button: Button, label: String, item_id: String, count: int = 1) -> void:
	button.set_meta("item", item_id)
	var face := button.get_node("Face") as SlotFace
	face.item_id = item_id
	face.count = count
	face.label = label
	face.badge = ""
	face.badge_kind = 0
	if item_id != "" and owner_cat != null and is_instance_valid(owner_cat):
		# The PRICE BADGE (every item has one): loot shows what it sells for (green) and gear its
		# shop price (blue). SCRAP: the shop won't take it.
		var items := ItemManager.instance
		var data: ItemData = items.catalog.get(item_id)
		var sale := items.sell_price_for(owner_cat.player_id, item_id)
		if sale <= 0:
			face.badge = "SCRAP" if item_id == Mainframe.SCRAP_ID else ("POWER" if item_id == Mainframe.FUEL_ID else "")
			face.badge_kind = 2
		elif data.kind == ItemData.Kind.LOOT:
			face.badge = "$%d" % sale
			face.badge_kind = 1
		elif data.price > 0:
			face.badge = "$%d" % data.price
	face.queue_redraw()


## Every grid matches this cat's sizes (SEWER UPGRADES grow the backpack and litterbox per cat).
## True = something changed (the d-pad highlight list must be rebuilt).
func _match_sizes() -> bool:
	var cat := owner_cat
	if cat == null or not is_instance_valid(cat):
		return false
	var items := ItemManager.instance
	var changed := _resize(_pack_buttons, "pack", items.pack_size_for(cat.player_id))
	changed = _resize(_stash_buttons, "stash", items.stash_size_for(cat.player_id)) or changed
	return changed


func _resize(list: Array[Button], where: String, count: int) -> bool:
	if list.size() == count:
		return false
	while list.size() < count:
		list.append(_slot(where, list.size()))
	while list.size() > count:
		var old: Button = list.pop_back()
		remove_child(old)
		old.queue_free()
	_last_key = ""  # refill the slots
	return true


## One slot: a Button (clicks, highlight) with a SlotFace on it that draws the picture.
func _slot(where: String, index: int) -> Button:
	var button := Button.new()
	button.name = "%s%d" % [where.capitalize(), index]
	button.focus_mode = Control.FOCUS_NONE  # (the d-pad moves a highlight: _focus, seat_focus.gd)
	button.set_meta("where", where)
	button.set_meta("index", index)
	button.set_meta("item", "")
	button.add_theme_stylebox_override("normal", _box_style(false))
	button.add_theme_stylebox_override("hover", _box_style(true))
	button.add_theme_stylebox_override("pressed", _box_style(true))
	button.gui_input.connect(_on_slot_input.bind(button, where, index))
	button.mouse_entered.connect(_on_slot_hover.bind(button))
	var face := SlotFace.new()
	face.name = "Face"
	face.where = where
	face.index = index
	face.screen = self
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(face)
	add_child(button)
	return button


## A slot's box: translucent ocean blue, brighter with a thicker edge when highlighted.
func _box_style(lit: bool) -> StyleBoxFlat:
	var style := HudStyle.current()
	var box := StyleBoxFlat.new()
	box.bg_color = style.panel_color.lightened(0.12) if lit else style.panel_color
	if lit:
		box.bg_color.a = minf(1.0, style.panel_color.a + 0.12)
	box.border_color = style.border_color.lightened(0.45) if lit else style.faint_border_color.lerp(style.border_color, 0.45)
	box.set_border_width_all(int(Hud.line(3.0 if lit else 1.5)))
	box.set_content_margin_all(4)
	return box


# --- Clicking ---

## Left-click = equip / put away (or, at the litterbox, bury / dig out); right-click = drop.
func _on_slot_input(event: InputEvent, button: Button, where: String, index: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_LEFT or click.button_index == MOUSE_BUTTON_RIGHT:
		_use_slot(button, where, index, click.button_index == MOUSE_BUTTON_RIGHT)
		accept_event()


## What clicking a slot does (drop = right-click / X on a controller).
func _use_slot(button: Button, where: String, index: int, drop: bool) -> void:
	if where == "quest":
		_use_abandon(drop)
		return
	if button.get_meta("item") == "":
		return
	if where == "pack":
		index = button.get_meta("pack_index", index)  # slot number -> where its top item is in the list
	var items := ItemManager.instance
	var cat := owner_cat
	if cat == null or not is_instance_valid(cat) or not cat.is_controlled:
		_info.text = "Can't do that from inside the car."
		return
	var data: ItemData = items.catalog.get(button.get_meta("item"))
	# "Full" for THIS item: catnip still fits on top of a catnip stack with room.
	var pack_full := not items.pack_has_room(cat.player_id, button.get_meta("item"))
	if drop and where != "stash":
		items.request_drop_item.rpc_id(1, cat.player_id, where, index, items.ground_in_front_of(cat))
	elif drop:
		pass  # (litterbox things can't be dropped from here: dig them out first)
	elif _at_stash:
		if where == "stash":
			if pack_full:
				_info.text = "Backpack is full."
			else:
				items.request_from_stash.rpc_id(1, cat.player_id, index)
		elif items.get_stash(cat.player_id).size() >= items.stash_size_for(cat.player_id):
			_info.text = "Litterbox is full."
		else:
			items.request_to_stash.rpc_id(1, cat.player_id, where, index)
	elif where == "pack":
		if data != null and data.kind == ItemData.Kind.LOOT:
			_info.text = "%s: loot. Sell it at the Black Markitten, bury it in the litterbox, or keep it for a job." % data.display_name
		else:
			items.request_equip.rpc_id(1, cat.player_id, index)  # (catnip etc. go to a QUICK USE slot)
	elif pack_full:
		_info.text = "Backpack is full."
	elif where == "quick":
		items.request_quick_to_pack.rpc_id(1, cat.player_id, index)
	elif where == "hand":
		items.request_put_away.rpc_id(1, cat.player_id, index)


## ABANDON: first press asks "SURE?", the second drops the job (only down in the sewers).
func _use_abandon(drop: bool) -> void:
	var cat := owner_cat
	if drop or cat == null or not is_instance_valid(cat):
		return
	if QuestManager.instance.current_quest(cat.player_id) == "":
		return
	if not UndergroundHub.is_in_hub(cat.global_position):
		_info.text = "You can only drop a job down in the sewers."
		return
	if not _abandon_armed:
		_abandon_armed = true
		_info.text = "Abandon this job? Its progress is lost. Press ABANDON again to drop it."
		return
	_abandon_armed = false
	QuestManager.instance.abandon_quest(cat.player_id)
	_info.text = "Job dropped. You're free to take another."


## Hovering / highlighting a slot shows what the item is, what it's worth and what a click does.
func _on_slot_hover(button: Button) -> void:
	var item_id: String = button.get_meta("item")
	if item_id == "" or owner_cat == null or not is_instance_valid(owner_cat):
		return
	var items := ItemManager.instance
	var data: ItemData = items.catalog[item_id]
	var worth := ""
	var sale := items.sell_price_for(owner_cat.player_id, item_id)
	if sale <= 0:
		worth = "  The shop won't buy it." + ("  Spend it at the TINKER WORKBENCH." if item_id == Mainframe.SCRAP_ID else ("  Feed it to THE MAINFRAME." if item_id == Mainframe.FUEL_ID else ""))
	elif data.kind == ItemData.Kind.LOOT:
		worth = "  SELLS FOR $%d." % sale
	else:
		worth = "  SHOP PRICE $%d, SELLS BACK FOR $%d." % [data.price, sale]
	_info.text = "%s: %s%s" % [data.display_name, data.description if data.description != "" else "-", worth]


## Draws one slot's insides: the item's side-view picture, its name, a price badge and a stack
## count (or a dim "EMPTY" / "-" when there's nothing in it).
class SlotFace extends Control:
	var screen: InventoryScreen
	var where := ""
	var index := 0
	var item_id := ""
	var label := ""
	var count := 1
	## The price badge's words ("$50", "SELL $30", "SCRAP"; "" = none) and look (0 = shop price,
	## blue; 1 = what it sells for, green; 2 = the shop won't take it, grey).
	var badge := ""
	var badge_kind := 0

	func _draw() -> void:
		var style := HudStyle.current()
		var font := get_theme_font("font", "Label")
		var name_size: int = screen.name_font_size
		var r := Rect2(Vector2.ZERO, size)
		var title := ""
		match where:
			"hand":
				title = "LEFT" if index == 1 else "RIGHT"
			"quick":
				title = Hud.key_for("quick_%d" % (index + 1), screen.seat)
		var badge_w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, screen.price_font_size).x + 14.0 if badge != "" and item_id != "" else 0.0
		var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size - 1).x
		if title != "" and title_w + badge_w + 8.0 <= size.x:  # (a narrow box: the price badge wins)
			_text(font, Vector2(5, name_size + 3), title, name_size - 1, Color(style.text_color, 0.6))
		if item_id == "":
			var empty_text := "EMPTY" if where in ["hand", "pack"] and size.y > 50 else "-"
			var w := font.get_string_size(empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
			_text(font, Vector2((size.x - w) / 2.0, size.y / 2.0 + name_size * 0.35), empty_text, name_size, Color(style.text_color, 0.3))
			return
		var items := ItemManager.instance
		var data: ItemData = items.catalog.get(item_id)
		if data == null:
			return
		var show_name := size.y > 56
		var icon_box := Rect2(6, (name_size + 6) if title != "" or badge != "" else 6, size.x - 12, 0)
		icon_box.size.y = size.y - icon_box.position.y - ((name_size + 8) if show_name else 6)
		var tint := style.cool_color
		if data.kind == ItemData.Kind.LOOT:
			tint = data.glow_color.lightened(0.35) if data.glow_color.a > 0.0 else Color(0.85, 0.95, 1.0, 0.95)
		HudStyle.draw_icon(self, HudStyle.item_icon(item_id), icon_box, tint)
		if show_name:
			var shown := label if label != "" else data.display_name
			_text(font, Vector2(6, size.y - 6), shown, name_size, style.text_color, size.x - 12)
		if badge != "":
			var w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, screen.price_font_size).x
			var box := Rect2(size.x - w - 10, 3, w + 7, screen.price_font_size + 4)
			var colors: Array = [[Color(0.05, 0.22, 0.36, 0.85), style.text_color], [Color(0.1, 0.45, 0.2, 0.85), Color(0.6, 1, 0.65)],
				[Color(0.15, 0.18, 0.22, 0.85), Color(0.7, 0.75, 0.8)]][clampi(badge_kind, 0, 2)]
			draw_rect(box, colors[0])
			_text(font, box.position + Vector2(3.5, screen.price_font_size + 1), badge, screen.price_font_size, colors[1])
		if count > 1:
			var count_text := "x%d" % count
			var cw := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size + 1).x
			_text(font, Vector2(size.x - cw - 5, size.y - 5), count_text, name_size + 1, Color.WHITE)

	func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color, max_width: float = -1.0) -> void:
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, Hud.outline(4), Color(0, 0.03, 0.06, color.a * 0.9))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, color)
