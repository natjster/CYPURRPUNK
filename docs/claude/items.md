# Items, backpack, shop, quick use, melee, weapon models

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

WEAPON MODELS (ROADMAP §5 #6, SETUP_GUIDE §9 "The weapon models"): the 8 weapon scenes' `Model/Mesh` = `models/<weapon>.glb` from
`tools/make_weapon_specs.py` (recipes in CM, `--build` runs cypurr_models `all`; REPLACES the .bbmodels). One shared 128x128 atlas
(`atlas_paint()`, 16x16 swatches, layout in the script docstring; `can()` maps a swatch's X ALONG a round part, Y ROUND it, via the
kit's new poly face `"uvs"` = exact per-corner UVs). Groups: Body, `HeatCoil` (tommy; weapon.gd `find_child`), glow groups. weapon.gd
`_ready`: `LevelKit.psx_ify(Model)` + exports `glow_parts` {part: Color} (`LevelKit.make_parts_glow`, also used by Enemy) / `neon_parts`
{part: strength} (`LevelKit.make_neon_paint_glow` = shader `texture_glow`); `_snap_muzzle_to_model` moves Model/Muzzle onto the glb's
`Muzzle` locator. Melee models stand along +Y (handle at origin). Test: `--weapons_lineup[=a,b] [--lineup_dist --lineup_yaw]`
("DevCapture weapon" lines), `--give=X --portrait=me --portrait_side=1.3 --portrait_dist=1.5 --portrait_height=0.55`.

## Items framework
ONE BACKPACK (Phase 2 UI overhaul): inventory = `{"hands", "pack", "stash", "quick"}` (NO "bag" any more). `pack` holds loot AND
spare gear, 1 slot each EXCEPT consumables (`quick_use`) which stack per `pack_stack_size_for` (= quick stack size): the list
stays flat (one entry per item); slots = `pack_stacks(pid)` [{id,count,index}]; room = `pack_has_room(_in)` / `pack_slots_used`, NEVER
`pack.size()`; inventory buttons carry meta `pack_index` (top item's list index, translated in `_use_slot`). `pack_size_for(pid)` = 6 + 2 per `bigger_pack` tier (3 tiers; old `deep_pockets` merged in
`Upgrades._merge_old_upgrades`). Full pack = `_can_take` false for loot. NOTHING is sold at the exit: fish_heist reports
`loot_value`/`loot_in_pack` (`_extracted(pid, worth, quest, chaos, count)`, Events.player_extracted loot_value = worth) and pays only
quest/chaos; the SHOP buys loot: `ItemManager.request_sell(pid, pack_index | -1)` (`sell_price` incl. gourmet, `pack_sell_value`,
Events.loot_sold), Shopkeeper `_sell_buttons`. Helpers `take_all_loot` (rob), `take_one_loot` (last LOOT only), `count_in_bag`/
`take_from_bag`/`bag_used` (= loot count) read the pack. Cats wear `models/cat_backpack.glb` (`tools/make_backpack_spec.py`) at
`CatModel/BackPack` (`ItemManager.BACKPACK_SPOT`, `_update_backpack`: "Strip" glow cyan->amber->red by fullness; `PackAnchor` locator,
`backpack_anchor(cat)`). INVENTORY = NMS backpack view: `CatPlayer.inventory_open()` blocks moving/looking and glides the camera
(`_update_inventory_camera`, "Inventory Camera" exports, side offset scaled by pane aspect, `inventory_view_amount()`); `inventory_ui.gd`
lays out ocean-blue boxes on the right (`_layout`), draws callout lines from projected 3D anchors (`_project` via
`GameScreen.camera_for_seat`), slots = Buttons + `SlotFace` (icon, name, price badge). Hud hides Names/Scoreboard while it's open.
Test: `--inventory[=0,1]` ("DevCapture inventory"), `--to_stash=pack:0`.
SHOP (Phase 3): `Shopkeeper.interact` -> `ShopScreen` (`scripts/ui/shop_screen.gd`, HUD `Frame/Shop`, `for_seat/is_open_for`; in
`Hud.wants_input` + `cat._menu_open`): right half = 3 tabs (exports melee/consumable/firearm_items, filtered by keeper.stock), rows =
Button + `RowFace` (icon or black silhouette when `!Upgrades.shop_allows`, BUY pill), SELL ALL; it opens the inventory in `shop_mode`
(`open_for_shop`: left column at `shop_column_start`, SELL badges, click = `request_sell(pid, where, index)`, cat camera `shop_camera_side`)
and drives ONE SeatFocus over both (inventory `_input` returns while the shop is open). Prices = `ItemManager.sell_price_for` (loot
100% x gourmet, gear max(1, price/2), scrap 0); `request_sell_all_loot`; `_buy_result`/`_sell_result` -> `ShopScreen.note`. WEAPON CRATES
moved to the workbench page (`Upgrades.PAGES.workbench`). Test: `--talk=ComradeWhiskers --shop_tab/--shop_buy/--shop_sell/--shop_sell_all/
--shop_pad/--shop_close` ("DevCapture shop").
All items go through `scripts/items/item_manager.gd` (`ItemManager.instance`, the `Items` node):
item cards are `ItemData` .tres files in `res://items/` (auto-loaded); held items with behaviour
extend `HeldItem`, guns extend `Weapon` (data-driven via exports). Host referees pickup/drop/
consume; inventories are `{"hands": [right, left], "bag": [...]}` (a 2-paw item fills both slots).
Held scenes are named `HeldR`/`HeldL` under each cat's `CatModel` so their RPCs line up.
World item IDs: city-placed items 0..N in placement order (deterministic), drops from 100000.
Other systems place items by joining group `item_placers` and implementing `place_items()`.
Don't add per-item pickup/sync code elsewhere. User-facing how-to: SETUP_GUIDE.md section 9.
QUICK USE: inventories also hold `"quick": [[ids], [ids]]` (two stacks, `quick_stack_size`; read via `quick_slots(id)` /
`quick_slots_of(inv)`); `ItemData.quick_use` items go there first; keys `quick_1/quick_2` -> host `request_quick_use` ->
owner `_quick_used` calls the scene script's `HeldItem.quick_use(cat)` on a spare copy. Catdip air jump = front flip
(`_flip_time_left`, `_spin_around_middle` shifts CatModel). Test: `--give=catdip --jump_test [--flip_snap=x.png]`, `--press_key=1`.

MELEE: `scripts/items/melee_weapon.gd` (`MeleeWeapon extends Weapon`, overrides `_fire` with a forward BoxShape
query (`swing_radius`/`swing_height`, `max_range` deep, reaches below the feet for flat Roombas), skips own-gang cats,
rpc `show_swing` tweens `Model`). Item `neon_bat` ($20, in `Shopkeeper.stock`). Starting money: `PlayerProfile.starting_cash`
(100) for new saves / once for older ones (`progress/starter` key; `save_now` forces the first save).
Weapon extras (exports, all `_make_hit` -> `Hit`): `pellets_per_shot`, `blast_radius` (`_blast`: sphere query, outward direction; replaces the
direct hit), `stun_seconds` -> `Enemy.take_hit(id, amount, stun, push, city_heat)` -> `_on_stunned`/`_on_pushed`, `enemy_knockback` (`knockback_taken`), `car_launch`
(m/s, x mass), `city_heat_per_hit`, `shots_per_sound`. `show_shot(ends, heat)` = one RPC per pull. STUNNED Roombas ignore `_on_hurt`. `CatHealth.finish_grace_seconds` = no finishing right after going down. Test: SETUP_GUIDE §9, `--rival_volley=N`, `--blast_car`, `--blast_probe`.
