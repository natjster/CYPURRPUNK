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
`take_from_bag`/`bag_used` (= loot count) read the pack. HIDDEN since 12 Nov 2026 (`ItemManager.show_backpack` = false: node still
built, `visible` off, anchor still works). Cats wear `models/cat_backpack.glb` (`tools/make_backpack_spec.py`) at
`CatModel/BackPack` (`ItemManager.BACKPACK_SPOT`, `_update_backpack`: "Strip" glow cyan->amber->red by fullness; `PackAnchor` locator,
`backpack_anchor(cat)`). INVENTORY = NMS backpack view: `CatPlayer.inventory_open()` blocks moving/looking and glides the camera
(`_update_inventory_camera`, "Inventory Camera" exports, side offset scaled by pane aspect, `inventory_view_amount()`); `inventory_ui.gd`
lays out ocean-blue boxes on the right (`_layout`), draws callout lines from projected 3D anchors (`_project` via
`GameScreen.camera_for_seat`), slots = Buttons + `SlotFace` (icon, name, price badge). Hud hides Names/Scoreboard while it's open.
Test: `--inventory[=0,1]` ("DevCapture inventory"), `--to_stash=pack:0`.
SHOP (Phase 3): E = normal NPC talk box; his choice action `shop` (SHOW ME THE GOODS) -> `Shopkeeper.open_shop` -> `ShopScreen` (`scripts/ui/shop_screen.gd`, HUD `Frame/Shop`, `for_seat/is_open_for`; in
`Hud.wants_input` + `cat._menu_open`): ONE centred window like MainframeScreen/WorkbenchScreen (dims the sewer, own mouse
mode): 3 tabs (exports melee/consumable/firearm_items, filtered by keeper.stock), item tiles = Button + `ItemTile` (icon or black
silhouette when `is_locked` = `!Upgrades.shop_allows`); click a tile = `selected` (big picture + detail card), `_buy` buys it
(`_press_row` = pick + buy, for tests). SELL strip = Button + `SellTile` from `_sellables()` (hands, quick, pack grouped by id;
meta where/index -> `request_sell(pid, where, index)`), `sell_from(where, n)` for tests, SELL ALL. The backpack view has no
shop mode any more. Prices = `ItemManager.sell_price_for` (loot
100% x gourmet, gear max(1, price/2), scrap + electronics 0); `request_sell_all_loot`; `_buy_result`/`_sell_result` -> `ShopScreen.note`. WEAPON CRATES
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
rpc `show_swing` tweens `Model`; COMBO + slam shockwave: see ui-hud.md MELEE JUICE). SLAM = only `can_slam` weapons (frozen
tuna): HOLD TO CHARGE, MeleeWeapon `use_tick` override (press = normal `_fire`, keep holding -> `slam_charge` (owner-side) fills
after `slam_hold_delay` over `slam_hold_seconds`; full -> `_fire` with charge 1 = step 2 slam (air = dive), then `_wait_release`;
release early = 0). Combo loops 0/1 otherwise. HUD: paw dict `"charge"` (-1 = none) -> `HudWeaponDisplay._draw_slam_meter`. MELEE BUTTON (action
`melee`, F / MMB / pad RB): `scripts/cat/cat_melee.gd` (`CatMelee`, node `Player/Melee`, `cat.melee`), ticked from ItemManager
`_use_held_items` (`melee_tick`). SPIN ATTACK: 2-paw items get right click via `HeldItem.alt_use_tick` (ItemManager loop, hand 0); MeleeWeapon `can_spin`
(tuna) -> `_spin` (sphere query, outward Hit, sets `cat.spin_left/spin_speed` = cat_player whirls the model yaw, synced as
usual) + rpc `show_spin` (`_shockwave(spot, spin_radius)`). Test `--spin_test`. BOOMERANG = RIGHT CLICK (ItemManager calls
`cat.melee.throw_next()`; also the MELEE button): left bat first, then the right-paw bat (needs left empty / a bat); left-bat
"use_left" never swings. `_throw(weapon, hand)`, `show_throw(item, hand, ...)`, `weapon.in_flight` set at once on the owner.
Test `--melee_test=throw2 --give=neon_bat,neon_bat`. Throwable MeleeWeapon -> `_throw` = BOOMERANG (owner simulates the OUT path + first target, Hit
applied on arrival via the `_thrown` stand-in; the bat NEVER leaves the inventory: `show_throw` rpc hides HeldL + sets
`MeleeWeapon.in_flight` (use_tick skips) on every computer, `_flights` + `_update_flights` fly the copy out then home on the cat;
owner bonks return-path targets (`throw_return_damage`); `_catch` unhides.). Left paw empty (no 2-paw item) -> `_scratch` (stand-in `_claws`
MeleeWeapon for Hit numbers; `show_scratch` rpc: ImmediateMesh claw marks + `paw_pose(side)` / `body_pitch()` / `body_forward()`
read by cat_player `_animate_legs_and_tail` + lean). `ItemData.offhand` (bat) = left paw first (`_free_paw_for`, request_equip);
right paw empty -> "shoot" also uses the left paw. Test: `--melee_test=scratch[:N]|throw`, `--combo_test --slam_charged`. `Hit.push_scale` multiplies cat/car shove. Item `neon_bat` ($20, in `Shopkeeper.stock`). Starting money: `PlayerProfile.starting_cash`
(100) for new saves / once for older ones (`progress/starter` key; `save_now` forces the first save).
Weapon extras (exports, all `_make_hit` -> `Hit`): `pellets_per_shot`, `blast_radius` (`_blast`: sphere query, outward direction; replaces the
direct hit), `stun_seconds` -> `Enemy.take_hit(id, amount, stun, push, city_heat)` -> `_on_stunned`/`_on_pushed`, `enemy_knockback` (`knockback_taken`), `car_launch`
(m/s, x mass), `city_heat_per_hit`, `shots_per_sound`. `show_shot(ends, heat)` = one RPC per pull. STUNNED Roombas ignore `_on_hurt`. `CatHealth.finish_grace_seconds` = no finishing right after going down. Test: SETUP_GUIDE §9, `--rival_volley=N`, `--blast_car`, `--blast_probe`.

ADS + GUN FEEL (11 Nov 2026): `scripts/cat/cat_aim.gd` (`CatAim`, node `Player/Aim`, `cat.aim`). ItemManager `_use_held_items` sets
`cat.aim.wants_aim` = right paw is a non-melee Weapon AND `held_item(cat,1) == null` AND "use_left" held (so RMB/LT aims only with a
free left paw; reset when the cat is skipped). `is_aiming()` also needs `is_controlled` (no ADS as gunner). cat_player reads
`aim.amount()` in `_update_zoomies_juice` (arm side/length/lift, fov x `ads_fov_scale`; `_camera_fov`/`_camera_tilt` hold the eased
values so `aim.fov_punch()`/`roll()` sit on top), walk speed, `_aim_look_scale()` (mouse + stick), no zoomies, faces camera.
Weapon "Feel" exports: recoil_* -> `aim.kick()` (pitch/yaw straight onto spring_arm/pivot, `recoil_return` share settles back),
bloom (`aim.bloom_degrees`, added to spread x `aim.spread_scale(ads_spread_scale)`), crosshair `HudCrosshair.set_aim(amount, bloom)`
(gap + ADS brackets). draw_shot (every computer, NPC guns too): `_show_flash_star` (SurfaceTool star under Muzzle), `_kick_model`
(`_gun_model`/`_gun_rest`; NOT `_model`, MeleeWeapon owns that name), `_eject_casing`, `_burst_sparks` (CPUParticles3D, skipped on
max-range misses). Test: `--deploy --give=tommy_gun --hold=shoot,use_left --keep_holding --hold_delay=120 --hold_frames=25`
("DevCapture aim" line: aiming/amount/bloom/fov/arm).

GUN SOUNDS + LAUNCHER JUICE (12 Nov 2026): sounds from `tools/make_gun_sfx.py` (numpy, writes sounds/sfx/gun_*, laser_*, launch_*,
blast_*, lob_whirr, cucumber_bounce, launcher_ready). weapon.gd exports: `shot_volume_db`, `hum_sound` (loop via `Sound.attach_loop`
on the gun, `_keep_humming` per drawn shot + `_update_hum` fades it ~1.6 shots after the last; pitch += heat x `hum_heat_pitch`;
red_dot has shot_sound ""), `hum_start_sound`, `ready_sound` (owner, use_tick when `_cooldown` hits 0), `fire_rumble`; Blast group
`lob_loop_sound/pitch`, `lob_bounce_sound` (`_lob_bounced` tween callback per hop), `lob_glow`, `lob_trail` (`_dress_lob`); group
"Launcher Juice": `muzzle_smoke` (`_puff_smoke`), `blast_debris`, `blast_ring` (in `draw_blast`). `_spark_box()` = shared spark mesh.
Test: `--give=cucumber_launcher --pitch=-12 --blast_snap=shots/x.png --frames=200 --sound_log` (fights.gd `_blast_snap`).
