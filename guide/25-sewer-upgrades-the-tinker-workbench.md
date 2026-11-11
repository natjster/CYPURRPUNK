# 25. SEWER UPGRADES, THE TINKER WORKBENCH and THE SEWER REBELLION

[Back to the contents page](../SETUP_GUIDE.md)


Upgrades make **your** cat better for good. You pay with **cash AND SCRAP** (MEGA VAC-COPs drop one per cat,
regular bots sometimes, dumpsters too). Scrap is ONLY for upgrades: THE MAINFRAME eats ELECTRONICS (§8). Scrap is counted from your **backpack and your litterbox together** (the backpack is used up first).
Upgrades are saved in your cat's save file (with your cash and litterbox), so they're there next game.
The TUTORIAL always starts with none, so it's the same for everyone (but it has every NPC: see below).

**Everything is bought at THE TINKER WORKBENCH** on the east wall of your sewer (between the litterbox
and the CAT-CAM TV): walk up and press **[E] TINKER WORKBENCH**. NPCs don't sell upgrades any more: talking
to them is only for their quests and their stories (Don / Pawnie also send you up top).

### The workbench screen (`scripts/ui/workbench_screen.gd`, HUD > Frame > Workbench)
```
 TINKER WORKBENCH                              scrap = backpack + litterbox   $240   3 SCRAP
 [DON] [WHISKERS] [MITTENS] [RECRUIT ?] [ ? ] [ ? ] [ ? ]        <- 7 portrait tabs (click, or LB / RB)
 ┌portrait┐  LIL' MITTENS               ┌ STUFFED CHEEKS        ■ □  TIER 1/2      BUY — $160 + 1 SCRAP ┐
 │        │  STREET RUNNER (TIER 1)     │ Quick-use snack stacks 3 -> 4 -> 5.                          │
 └────────┘  "I can SMELL them..."      ├ INSIDER TUNNEL (CREW) □ □  TIER 0/2      BUY — $130 + 1 SCRAP ┤
             QUEST IN SEWER: MITTENS' FISH
 what the highlighted thing does / "UPGRADED! ..." / "NEW RECRUIT! ..."
```
- The 7 tabs are your sewer's 7 cats (portraits from the Icon Studio, §20). A cat you haven't recruited
  yet is a **"?"** (no face, no name). Clicking an **upgrade card** buys its next tier (green button =
  you can afford it, red = you can't; MAXED when done). Hover / highlight a card to read it in the
  bottom box. Your cat stands still while the screen is open; Esc / B / Tab / walking away closes it.
- **Controller:** d-pad / stick moves the highlight, **A** = click, **LB / RB** = tabs.

### THE SEWER REBELLION (recruit the cats)
Each sewer **starts with only its boss and its shopkeeper**. The other five are hiding in the pipes and
join one at a time, in this order, when your gang **recruits** them on the workbench's next "?" tab
(**RECRUIT TO THE REBELLION — $X + Y SCRAP**):

| Tier | Cost | Catleone sewer (Hub) | Burrow sewer (GangHub) | Their quest |
|---|---|---|---|---|
| (start) | - | Don Catleone, Comrade Whiskers | Pawnie, Clawd | - |
| 1 | $100 + 1 scrap | Lil' Mittens | Billy the Kitten | MITTENS' FISH |
| 2 | $150 + 1 scrap | Paulie "No-Brooms" | Bumper-Car Benny | SMASH ROOMBAS |
| 3 | $200 + 2 scrap | Sal "The Slapper" | Calamity Clara | GANG DISRESPECT |
| 4 | $250 + 2 scrap | Nonna Catleone | "Gold-Tooth" Gus | GOLDEN KOI HEIST |
| 5 | $320 + 3 scrap | Frankie "Espresso" | Jittery Jax | DAREDEVIL EXTRACT |

- A cat that hasn't joined is **not in the sewer at all** (invisible, can't be bumped into or talked to,
  and doesn't fight in a SEWER BREACH). The moment someone recruits them they appear, offer their quest,
  fight in breaches and open their workbench tab.
- It's a **crew** thing: a sewer has everyone up to the best tier anyone in that gang has recruited, and
  the next recruit continues from there. It's saved with your upgrades.
- To change a recruit's tier: click the NPC's scene root (e.g. `scenes/npcs/lil_mittens.tscn`) > Inspector >
  **Sewer Rebellion > Rebellion Tier** (0 = always there). Prices: the Upgrades node > Costs > `rebellion_tier`.

### Which tab sells what

| Tab (Catleone / Burrow) | Upgrades (tiers) |
|---|---|
| Don Catleone / Pawnie (start) | **BIGGER BACKPACK** (3): 6 -> 8 -> 10 -> 12 slots (an old save's DEEP POCKETS became BIGGER BACKPACK tiers). **MAINFRAME CAPACITOR** (2, crew): 1 ELECTRONICS feeds +35% / +50% instead of +25%. |
| Comrade Whiskers / Clawd (start) | **WEAPON CRATES** (3): 1 = Hairball Blaster + Red Dot, 2 = Tommy Gun + Frozen Tuna, 3 = Yarn-Zooka + Cucumber Launcher (until then they're black silhouettes in the shop). **DELUXE LITTERBOX** (2): 9 -> 15 -> 21 slots. |
| Tier 1: Lil' Mittens / Billy the Kitten | **STUFFED CHEEKS** (2): snack stacks 3 -> 4 -> 5. **INSIDER TUNNEL** (2, crew): your exit opens 5 / 10 heat earlier. |
| Tier 2: Paulie "No-Brooms" / Bumper-Car Benny | **THICK FUR** (2): max HP 100 -> 125 -> 150. **SCRAP MAGNET** (2): smashed bots +15% / +30% chance to drop SCRAP (not bosses). **AFTERBURNER** (2, crew): car BOOST goes from 1 charge (everyone starts with it) to 2 / 3 slowly recharging charges; the exhaust fire sends bots and cats flying (§3). |
| Tier 3: Sal "The Slapper" / Calamity Clara | **HEAVY PAWS** (2): melee +25% / +50% damage and knockback. |
| Tier 4: Nonna Catleone / "Gold-Tooth" Gus | **GOURMET FENCE** (2): the shop pays +20% / +40% for street loot. |
| Tier 5: Frankie "Espresso" / Jittery Jax | **ESPRESSO BLOODSTREAM** (2): walk + zoomies +12% / +24%. **TWIN-TURBO ENGINE** (2, crew): your ride +15% / +30% top speed and pickup. **NEON ZOOM-BIKE** and **ARMORED MEOW-VAN** (unlocks), plus buttons to pick your gang's ride (INTERCEPTOR / ZOOM-BIKE / MEOW-VAN). |

The tabs' upgrade lists are `Upgrades.WORKBENCH_TABS` in `scripts/upgrades.gd` (a programmer's change).

**Crew** upgrades help your whole gang: the gang gets the BEST tier anyone in it owns. So in co-op, one cat
with a Twin-Turbo upgrades everyone's car.

### The rides
- **INTERCEPTOR** (the normal car): 26 m/s, 3 passengers.
- **NEON ZOOM-BIKE** (`models/cyber_bike.glb`): 31 m/s, turns sharper, light, 1 passenger. Its wheel rims glow in your gang colour.
- **ARMORED MEOW-VAN** (`models/fish_van.glb`): 24 m/s, heavy, smashes bots at half the speed, 3 passengers, fish sign on the roof.
- Once you own one, the workbench's Frankie / Jax tab shows its ride button. That changes your **gang's** car for everyone
  (only while it's parked and empty). Your pick is saved and comes back next game.

### Balance targets (Nov 2026 balance pass)
- A careful raid brings home about **$100-200** of loot (6-slot backpack, shared with spare gear), a greedy koi raid **$450-500**, quests $100-250.
- Every upgrade together costs about **$4,700 + 46 scrap** per cat: the first one after 1-2 raids, the
  middle tiers around raid 5, everything around raids 15-20. Scrap is the real gate (bosses drop one per cat
  up top, regular bots 5%); cash mostly buys guns and snacks.
- BIGGER BACKPACK tier 3 costs **3 scrap**: 12 slots is a lot of fish per trip.

### Changing prices and numbers (Godot editor)
- **Prices:** open `scenes/main.tscn`, click the **Upgrades** node (right under Wallet) > Inspector > **Costs**.
  Each upgrade is a list of `[cash, scrap]` pairs, one per tier. Add a pair = one more tier.
- **What a tier gives:** same node > **What Each Tier Gives** (backpack slots per tier, HP per tier, +% per tier...).
- **Which guns are in which crate:** same node > **Weapon Crates** (Starter Stock, Crate 1/2/3 Items).
- **Bike / van stats:** open `scenes/getaway_car.tscn`, click the root > Inspector > **Alternate Vehicles**.
- **Workbench layout / fonts:** select **Workbench** in `scenes/ui/hud.tscn` (Panel Max Width, Tab Max Size, Card Height...).
- **The workbench's spot:** `scenes/main.tscn` > **Hub** (or **GangHub**) > Inspector > **Tinker Workbench** > Workbench Spot.

### The new models (Blockbench)
`models/blockbench/workbench.bbmodel`, `cyber_bike.bbmodel`, `fish_van.bbmodel`: double-click to open in Blockbench,
repaint, Ctrl+S, then ask Claude to re-export (or `python tools/cypurr_models.py export models/blockbench/fish_van.bbmodel`).
Their recipes are in `tools/make_upgrade_specs.py` (re-running it REPLACES the .bbmodel files, so don't after hand edits).
Parts the game looks for: car-like rides need `WheelFL/WheelBL` (+ `WheelFR/WheelBR`), anything named `Trim...` glows in the
gang colour, `Headlight*`, `Taillight*`, `Thrusters`, `Sign` glow white. The workbench's `Lamp` and `Glow` parts glow.

### How it works (for the curious)
`scripts/upgrades.gd` (the **Upgrades** node) keeps every player's tiers; the host checks cash + scrap and takes them
(`request_buy`), then tells everyone. Other scripts just ask it: the backpack size (`ItemManager.pack_size_for`), max HP
(`CatHealth.max_health_for`), the car (`GetawayCar.set_vehicle`), and so on. The inventory screen grows to match (and
scrolls when the litterbox gets big).
The rebellion: `Upgrades.rebellion_level(team)` (best `rebellion_tier` in the gang; 5 in the tutorial),
`tab_unlocked(team, tab)` (request_buy refuses a locked tab's upgrade), the `recruited` signal; `npc.gd`
`rebellion_tier` / `is_recruited()` / `present` (checked 4x a second on every computer).
**Tests:** `--workbench [--workbench_recruit=2 --workbench_buy=stuffed_cheeks --workbench_tab=3]` prints "DevCapture
workbench" lines (tabs, cards, which recruits are in the sewer); `--rebellion_tier=5` puts every recruit in the sewers
(old quest tests: `--talk=<recruit>` does that by itself).

### Testing it (Claude's tools)
- Buy things: `-- --host --cash=3000 --give=scrap,scrap,scrap --buy_upgrade=bigger_pack,thick_fur` (prints a
  `DevCapture upgrades` line after each buy). `--upgrade_log` just prints what you have.
- Pick a ride: `--select_vehicle=fish_van` (prints `DevCapture vehicle`).
- Screenshots: `--workbench` (walks to the bench and opens its page), `--teams=0 --vehicles_lineup --no_hud --cam_follow
  --cam_from=0,2,-0.5 --look_from=0,0.3,-5.5` (bike + van side by side).
- Test saves live in `user://test_profiles/` (add `--fresh_profile` to start over).
