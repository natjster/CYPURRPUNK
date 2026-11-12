class_name Shopkeeper
extends Npc
## CYPURRPUNK — a SHOPKEEPER: an NPC (npc.gd) who runs THE BLACK MARKITTEN.
## Comrade Whiskers (scenes/npcs/comrade_whiskers.tscn, in the Hub) and Clawd (GangHub) are ones.
##
## How it works:
##   - Press E on him to TALK (the normal NPC talk box: npc.gd + his pages in the Inspector). The
##     "SHOW ME THE GOODS" button (choice action "shop") opens the SHOP SCREEN (scripts/ui/shop_screen.gd,
##     in your own HUD): your backpack on the left (click = SELL), his goods on the right in three tabs (MELEE /
##     CONSUMABLES / FIREARMS; click a row = BUY).
##   - Prices live on the item cards (res://items/*.tres > Shop > Price). He sells at that price and
##     buys gear back at half; street loot he buys at its full Cash Value (+GOURMET FENCE); scrap
##     never (ItemManager.sell_price_for). The HOST checks every buy and sale.
##   - Guns from a WEAPON CRATE you haven't unlocked show as black silhouettes: the crates are bought
##     at the TINKER WORKBENCH now (scripts/upgrades.gd "workbench" page), not from him.
##
## To sell something new: give its item card a Price, add its id to Stock below (Inspector: select
## ComradeWhiskers under Hub in main.tscn, or open his scene) AND to one of the shop screen's tab
## lists (select Shop in scenes/ui/hud.tscn: Melee / Consumable / Firearm Items).

## Item ids he sells. Prices come from the item cards; the shop screen's tabs decide the order.
@export var stock: Array[String] = ["neon_bat", "catnip", "catdip", "frozen_tuna", "red_dot", "hairball_blaster", "pistol", "yarn_zooka", "tommy_gun", "cucumber_launcher"]
## What he says when the shop opens (one at random, under the title). %d = your cash.
@export_multiline var shop_lines: PackedStringArray = ["Take your pick. You've got $%d."]


## (E = talk, like every NPC: npc.gd's interact. No override here, so he chats first.)

## The "shop" action (his SHOW ME THE GOODS button) opens the shop screen.
func _on_action(action: String, cat: CatPlayer) -> void:
	if action == "shop":
		open_shop(cat)
	else:
		super(action, cat)


## Open THE BLACK MARKITTEN for this cat.
func open_shop(cat: CatPlayer) -> void:
	var screen := ShopScreen.for_seat(cat.slot)
	if screen == null:
		return
	NpcDialog.for_cat(cat).close()
	screen.open(cat, self)
