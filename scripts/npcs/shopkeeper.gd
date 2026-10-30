class_name Shopkeeper
extends Npc
## CYPURRPUNK — a SHOPKEEPER: a normal NPC (npc.gd) who can also sell items.
## Comrade Whiskers, who runs THE BLACK MARKITTEN down in the sewers
## (scenes/npcs/comrade_whiskers.tscn), is one.
##
## How it works:
##   - Talk to him like any NPC. Give one of his choices the Action  shop  and clicking it
##     opens the SHOP PAGE: one "BUY <ITEM> - $<price>" button per item in Stock, then BACK.
##   - Prices live on the item cards (res://items/*.tres > Shop > Price), so the same price
##     shows everywhere. Items with no price (0) are skipped, even if they're in Stock.
##   - Clicking BUY asks the HOST (ItemManager.request_buy), which checks your cash, takes it,
##     and puts the item in your paws (or backpack). The answer pops up on screen.
##     The shop page stays open so you can keep shopping.
##
## To sell something new: give its item card a Price, then add its id to Stock in the
## Inspector (select ComradeWhiskers under Hub in main.tscn, or open his scene).

## Item ids for sale, top to bottom, e.g. "pistol". Prices come from the item cards.
@export var stock: Array[String] = ["neon_bat", "catnip", "catdip", "frozen_tuna", "red_dot", "hairball_blaster", "pistol", "yarn_zooka", "tommy_gun", "cucumber_launcher"]
## What he says on the shop page. One is picked at random. %d = your cash.
@export_multiline var shop_lines: PackedStringArray = ["Take your pick. You've got $%d."]
## Button that leaves the shop page (goes back to the greeting).
@export var back_text: String = "BACK"


## The "shop" action opens the shop page. Anything else goes to the normal NPC handling.
func _on_action(action: String, cat: CatPlayer) -> void:
	if action == "shop":
		open_shop(cat)
	else:
		super(action, cat)


## Show the shop page: what he says + a BUY button per item in stock + BACK.
func open_shop(cat: CatPlayer) -> void:
	var my_cash: int = Wallet.instance.cash_of(cat.player_id)
	var line: String = shop_lines[randi() % shop_lines.size()] if not shop_lines.is_empty() else "Take your pick."
	if line.contains("%d"):
		line = line % my_cash
	var buttons := []
	for item_id in stock:
		var data: ItemData = ItemManager.instance.catalog.get(item_id)
		if data == null or data.price <= 0:
			continue  # unknown item, or it has no price on its card
		buttons.append(["BUY %s - $%d" % [data.display_name, data.price], _buy.bind(cat, item_id)])
	buttons.append([back_text, talk.bind(cat)])
	NpcDialog.for_cat(cat).open(npc_name, line, buttons)


## A BUY button: ask the host, then re-open the shop page (so the cash line is fresh).
func _buy(cat: CatPlayer, item_id: String) -> void:
	ItemManager.instance.request_buy.rpc_id(1, cat.player_id, item_id)
	# Give the host's answer (new cash) a moment to arrive before redrawing the page.
	await get_tree().create_timer(0.2).timeout
	if NpcDialog.is_open_for(cat.slot):
		open_shop(cat)
