# 9. Items & weapons

[Back to the contents page](../SETUP_GUIDE.md)


Every item — fish, the tommy gun, pistols, catnip, catdip, anything you add — goes through one
system, so new items need no new networking or pickup code.

### How players use items
- **Paws:** a cat has a right and left paw. A **1-paw** item (pistol, catnip, catdip) uses one,
  so you can hold two at once (dual wield). A **2-paw** item (the tommy gun) takes both.
  **Left Mouse** uses the right-paw item (or the 2-paw item), **Right Mouse** the left-paw item.
- **AIM DOWN SIGHTS (Helldivers-style):** holding a gun with the LEFT PAW EMPTY (or a 2-paw gun),
  **hold Right Mouse / LT** to aim: the camera snaps in close over the cat's shoulder and zooms,
  the crosshair tightens and gets corner brackets, shots are much tighter and kick less, but you
  walk slower and can't do zoomies. Something in the left paw = Right Mouse uses it as before.
  Knobs: click **Player > Aim** in `scenes/player.tscn` (Ads Camera Distance / Side / Lift, Ads Fov
  Scale = zoom, Ads Speed, Ads Move Speed, Ads Look Speed, and the Recoil settle speeds).
- **GUN FEEL:** every shot kicks your aim UP (recoil you pull back down), rolls and thumps the
  camera, BLOOMS the spread (holding the trigger sprays, tapping stays accurate, the crosshair opens
  up to show it), slams the gun model back in the paw, flashes a spiky muzzle star, spits a shell
  casing and throws sparks off whatever it hits. Per gun: open its scene (e.g.
  `scenes/items/tommy_gun.tscn`), click the root, Inspector > **Feel**: Recoil Degrees / Sideways /
  Return, Ads Recoil Scale, Ads Spread Scale, Spread Bloom Degrees, Max Bloom, Camera Roll, Fov
  Punch, Gun Kickback / Kick Degrees / Kick Time, Muzzle Flash Size, Eject Casings + Casing Color,
  Impact Sparks.
- **BACKPACK (one for everything):** 6 slots (8 / 10 / 12 with BIGGER BACKPACK) for loot (fish,
  koi, scrap) AND gear you aren't holding. Every item takes one slot, EXCEPT consumables (catnip,
  catdip: anything with **Quick Use** ticked), which stack in the backpack like in a QUICK USE slot
  (same size: **Quick Stack Size** + STUFFED CHEEKS; the slot shows "x3"). When both quick slots are
  full, extra catnip goes into the backpack (not your paws). Clicking a stack moves / sells / drops /
  buries ONE of it. (Code: `ItemManager.pack_stacks` / `pack_has_room`.) Your cat WEARS it: a chunky
  purple backpack (`models/cat_backpack.glb`, recipe `tools/make_backpack_spec.py`) whose light
  strip goes cyan (empty) -> amber -> red (full), so you can see who's carrying a haul.
  **The backpack is HIDDEN for now**: to show it again, open `scenes/main.tscn`, click the `Items`
  node, and in the Inspector tick **Show Backpack**.
- **QUICK USE slots:** two of them, used with **1** and **2** (controller: **d-pad left / right**).
  Catnip and catdip go here when you pick them up or buy them (not in your paws), up to 3 of the
  same item stacked per slot; one press uses one. The bottom of the HUD shows them ("1: CATNIP x2").
  Any item card with **Quick Use** ticked works this way (its script needs a `quick_use(cat)`
  function, like `scripts/items/catnip.gd`). Stack size: **Quick Stack Size** on the Items node.
- **Loot comes home:** nothing is sold at the exit. Sell loot at the Black Markitten (SELL buttons on
  the shop screen; the GOURMET FENCE upgrade pays more), bury it in the litterbox, or keep it for a job.
- **E** grabs the nearest item when the HUD says "[E] PICKUP", loot and gear alike. A full backpack
  shows no prompt for loot. **G** drops what's in your paws (right paw first).

### The items
Only **fish** lie around the city. All gear is **bought** from Comrade Whiskers at the Black
Markitten in the sewers (§8).

| Item | Paws | Where | What it does |
|---|---|---|---|
| **Purr-Tommy 2099** | 2 | shop, $200 | Hold Left Mouse: plasma bolts; overheats (below) |
| **Paw-Pistol** | 1 | shop, $60 | One shot per click; buy two to dual wield |
| **Neon Bat** | 1 | shop, $20 | MELEE: hold the use button to keep swinging; hits everything right in front of you (below) |
| **Catnip** | quick use | shop, $25 | Press its quick key: 8 s of super zoomies (used up) |
| **Catdip** | quick use | shop, $35 | Press its quick key: 20 s of double jump, with a front flip (used up) |
| **Sardine** | loot | sidewalks | $20 at the drop-off (§8) |
| **Fish** | loot | Meow-Mart + sidewalks | $50 each at the drop-off (§8) |
| **Golden Koi** | loot (2 spaces) | one hidden far away | $400, but heavy and noisy (§8) |
| **Scrap** | loot | regular bots (5%), dumpsters (not MEGA VAC-COPs) | $0, stays in your bag at the exit; pays for SEWER UPGRADES (§25) |
| **Electronics** | loot | ONLY a destroyed MEGA VAC-COP (1 per cat up top) | $0, stays in your bag at the exit; feed it to The Mainframe (§8) |

**The Purr-Tommy:** the drum coil goes from cyan to red as you fire, and the bar bottom-left shows
it (`HEAT [####------]`). About 3 s of non-stop fire overheats it: it blinks and won't fire until
it has cooled all the way down. Bolts shove other cats back with a little hop and nudge the car.
Nobody gets hurt — there is no health yet. Its scene (`scenes/items/tommy_gun.tscn`):
```
TommyGun (Node3D)                    script: weapon.gd (all the numbers are set in the Inspector)
└── Model (Node3D)                   all the meshes
    ├── Receiver, Barrel, Stock, Grip, ForeGrip, SightRail, Drum   (plain MeshInstance3Ds)
    ├── Fin1 / Fin2 / Fin3           glowing pink cooling rings on the barrel
    ├── HeatCoil                     glowing drum core — changes colour with heat
    └── Muzzle (Marker3D)            barrel tip; bolts start here
        └── MuzzleFlash (OmniLight3D)
```

### The pieces
```
items/                       <- ITEM CARDS (one .tres per item). Loaded automatically.
  fish.tres  tommy_gun.tres  pistol.tres  catnip.tres  catdip.tres
scenes/items/                <- the item scenes (the same scene lies on the street and sits in a paw)
models/<weapon>.glb          <- the 8 weapons' Blockbench models (see "The weapon models" below)
scripts/items/
  item_data.gd               <- what an item card can say (name, paws, loot value, shop price, model...)
  item_manager.gd            <- the system ("Items" node in main.tscn): pickup, drop, paws,
                                backpack, bag, placing items in the city, buying, multiplayer, late joiners
  held_item.gd               <- base for held items that DO something (use_tick, hud_text)
  weapon.gd                  <- base for every gun: fire rate, spread, range, knockback,
                                damage + crits, overheat, bolt colours — all Inspector numbers.
                                What a bolt does to what it hits = the hit framework (§16)
  catnip.gd, catdip.gd       <- examples of use-it-once items
scripts/ui/inventory_ui.gd   <- the inventory screen
```
The HUD pieces for items are **Crosshair** and **Held** in `scenes/ui/hud.tscn` (§13); they only
show while you hold something that wants them. **Held** is the ocean-blue gun box bottom-left: it
shows the item's side-view picture from `ui/icons/items/<id>.png`, so a NEW item needs its icon made
too (ask Claude, or run `python tools/cypurr_icons.py item <id>` after adding it to `ITEMS` in that
file, then let Godot import it). No picture yet = the box just shows the item's name.

### Melee: the Neon Bat (`scripts/items/melee_weapon.gd`, class **MeleeWeapon**)
A melee weapon is a gun whose "shot" is a short **swing**: same item system, same shops, same
use buttons, and the same hit rules (VAC-COPs lose health, the OTHER gang's cats take damage and
get knocked back, a downed rival is finished off, your own gang is ignored, it doesn't work in the
sewers). Each swing hits **everything** in a box right in front of you (so two VAC-COPs side by
side both get it), tall enough to reach the ground even while you're bouncing or jumping.
- **Feel / balance** (open `scenes/items/neon_bat.tscn`, select the root **NeonBat**):
  **Fire Rate** = swings per second (2.2), **Automatic** (on = hold to keep swinging),
  **Max Range** = reach (2.6 m), **Damage** (40: three hits for a VAC-COP, fewer with crits),
  **Crit Chance** (12%), **Cat Knockback** / **Car Impulse** (how hard it shoves), and under
  **Swing**: **Swing Radius** (how wide, to each side), **Swing Height**, **Swing Time** /
  **Swing Angle** (the animation), **Swing Sound** (`sounds/sfx/swing.wav`, a placeholder whoosh)
  and **Hit Sound** (`bonk`).
- **Swing Juice** (same Inspector, makes it feel heavy): **Swing Sweep** (how far the bat slashes
  sideways across you), **Hit Stop** (the bat freezes for a split second when it connects, 0.07 s),
  **Lunge Speed** (you lurch forward with each swing; 0 = stand still), the **neon trail** behind the
  tip (**Trail Fade** = how long it lingers, **Trail Reach** = how far past the real bat it stretches,
  **Trail Color** = leave see-through to use the bat's Bolt Color), and on a hit **Spark Count** +
  **Impact Light** (a burst of sparks and a flash where it lands). The Frozen Tuna has the same settings.
  Test: `--host --pos=0,0,6 --give=neon_bat --swing_test --frames=2` (snaps mid-slash).
- **Combo** (same Inspector, group **Combo**): keep swinging and it goes **forehand → backhand →
  forehand...** Pause longer than **Combo Window** (0.9 s) and it starts over at the forehand.
- **GROUND SLAM (Frozen Tuna only)**: open `scenes/items/frozen_tuna.tscn`, select **FrozenTuna**, group
  **Combo**: **Can Slam** is ticked only there (the bat has it off). The tuna slams by **HOLDING** the
  swing button, like reviving a friend: a **tap** is a normal forehand / backhand; keep **holding** and,
  after **Slam Hold Delay** (0.25 s), the **SLAM METER** (a bar under the tuna in the bottom-left weapon
  box, **CHARGING...** above it) fills over **Slam Hold Seconds** (1 s) while the cat lifts the fish over
  its head and the pad buzzes harder. Full = it **SLAMS** on its own. Let go early = the meter empties.
  After a slam, let go and wait **Slam Recover** (0.5 s) before the next swing. Fill it in the air and you
  DIVE into an **AIR SLAM** (**Air Slam Speed** 16 m/s). **Slam Charge Sound** plays when it starts filling.
  The slam hits harder (**Finisher Damage** x1.75), shoves much further
  (**Finisher Push** x2.2), reaches further (**Finisher Reach**), dazes VAC-COPs (**Finisher Stun**),
  shakes harder (**Finisher Shake** / **Finisher Hit Stop**) and sends out a neon **SHOCKWAVE** hitting
  everything within **Shockwave Radius** (3.4 m on the tuna) with a boom (**Finisher Sound** / **Volume**).
  The meter's look: `scenes/ui/hud.tscn` > the weapon box (**HudWeaponDisplay**) > group **Slam Meter**.
  Test: `--host --deploy --give=frozen_tuna --bait_roomba=2 --combo_test [--slam_charged] [--air_slam] --frames=2`
  (prints a "DevCapture combo" line per swing; `--slam_charged` makes the 3rd swing a real HOLD and prints
  "DevCapture slam_hold" lines as the meter fills).
- **SPIN ATTACK (Frozen Tuna, RIGHT CLICK / LT)**: the cat whirls round once with the fish held out flat,
  hitting **everything around you** and shoving it all **away** (a ring of light races out across the street).
  `frozen_tuna.tscn` > **FrozenTuna** > group **Spin Attack**: **Can Spin** (only the tuna), **Spin Radius**
  3.2 m, **Spin Damage** x0.6, **Spin Push** x2.4, **Spin Stun** 0.5 s, **Spin Time** 0.4 s, **Spin Turns**,
  **Spin Cooldown** 1.5 s, **Spin Shake**, **Spin Sound**. It cancels a slam you were charging.
  Test: `--host --deploy --give=frozen_tuna --bait_roomba=1.8 --spin_test --frames=2` ("DevCapture spin").
- **THROWING THE BAT (offhand) = RIGHT CLICK**: the bat's card (`items/neon_bat.tres`) has **Offhand** ticked,
  so it goes in your **LEFT paw** first, leaving the right paw free for a gun. **Right Mouse / LT** (or the
  **MELEE** button, **F** / middle mouse / pad **RB**) **throws** it like a **BOOMERANG**; it swings with
  **Left Mouse / RT** when your right paw is empty. It spins end over end with its neon trail, bonks the first
  VAC-COP / rival cat / car it passes (or a wall), turns round, swoops back to you (it chases you if you run)
  and lands back in your paw, bonking anything it passes on the way back too. It never leaves your backpack.
  **TWO BATS** (buy a second one: it goes in the right paw): right click throws the left one, and right
  click again throws the right one while the first is still coming back. Left click swings the right-paw
  bat. A thrown bat can't be swung or thrown again until it's back. Its numbers: `neon_bat.tscn` > **NeonBat**
  > group **Throw** (**Throwable**, **Throw Damage** x1.5, **Throw Push** x1.6, **Throw Stun** 1 s); the flight
  itself is on the cat (below, **Player > Melee** > group **Throw**: **Throw Cooldown** 0.5 s between two
  throws, **Throw Speed** 24 + **Throw Out Seconds** 0.45 =
  how far it goes, **Throw Return Speed** 20, **Throw Curve** = how wide it swoops back, **Throw Catch
  Distance**, **Throw Return Max Seconds**, **Throw Return Damage** x0.6 on the way back, lift, gravity, spin).
- **CLAW SCRATCH (bare paws)**: nothing in your LEFT paw (and no 2-paw weapon) = the MELEE button
  **scratches**: right swipe, left swipe, then a big **X RAKE** with both paws (x2 damage, x2 shove, dazes
  VAC-COPs). Hold it to keep scratching. Each swipe rips three neon **claw marks** across the air, the cat
  pounces into it (nose dip + forward slide), its front paw flicks up and rakes down, the camera rolls and
  punches, and a hit freezes the marks for a split second with sparks. Works next to a gun in your right paw.
  All the knobs: open `scenes/player.tscn`, click the **Melee** node (script `scripts/cat/cat_melee.gd`):
  groups **Scratch** (rate 4.5/s, damage 14, reach, shoves, lunge), **Scratch Combo** (window, rake
  numbers), **Scratch Feel** (shake, hit stop, camera punch, pounce, paw raise, sounds), **Claw Marks**
  (colour, length, width, how fast they rip and fade) and **Throw**.
  Test: `--host --deploy --bait_roomba=1.3 --melee_test=scratch:3 --frames=2` or
  `--host --deploy --give=neon_bat --melee_test=throw --frames=2` (two bats: `--give=neon_bat,neon_bat
  --melee_test=throw2`) ("DevCapture melee" lines).
- **Price** is on its card: `items/neon_bat.tres` (> Shop > Price, $20).
- **A new melee weapon** (a pipe, claws...): duplicate `neon_bat.tscn` + `neon_bat.tres`, swap the
  model under **Model** (the swing rotates **Model**; see "The weapon models" below), change the
  numbers, give the card a new **Id**, and add that id to the shopkeeper's **Stock**
  (`scripts/npcs/shopkeeper.gd`).
- Test: `--give=neon_bat --deploy --bait_roomba=1.6 --hold=shoot --hold_frames=8` (one swing at
  a VAC-COP; the `DevCapture roombas` line shows its health).

### The funny weapons (sold by both shopkeepers)
All five are ordinary scenes + cards, so every number below is in the Inspector: open the scene in
`scenes/items/` and select its root node. Price, name and paws are on the card in `items/`.

| Weapon | Price | Paws | What it does |
|---|---|---|---|
| FROZEN TUNA | $80 | 2 | Melee. Slow, wide, launches cats and cars. Wet slap: `sounds/sfx/fish_slap.wav` |
| THE RED DOT | $140 | 1 | Hold for a steady laser: 6 damage, 25 shots a second, only **25 m** reach, overheats after ~1.2 s |
| HAIRBALL BLASTER | $120 | 1 | 7 pellets per click, 18 damage each, 22 m range. Hold two! |
| YARN-ZOOKA | $160 | 2 | 4.5 m blast, 35 damage, stuns VAC-COPs (bosses too) for 6 seconds |
| CUCUMBER LAUNCHER | $280 | 2 | 5.5 m blast, 110 damage, huge shove, overheats on the second quick shot |

The settings that make them work, usable on any gun:
- **Hits > Stun Seconds**: each hit stops a VAC-COP for this long. Its eye and sirens fizz.
- **Hits > Enemy Knockback**: shoves VAC-COPs (metres per second). The MEGA VAC-COP only feels a
  fifth of it (**Knockback Taken** in `roomba_boss.tscn`).
- **Hits > Car Launch**: throws the car this fast, away from the hit and upward. Car Impulse alone
  can't launch it, because the car weighs 800: an impulse of 550 is only 0.7 m/s.
- **Hits > City Heat Per Hit**: share of the usual heat each hit on an enemy adds. Keep it low on
  guns that land lots of hits (Red Dot 0.1, Hairball 0.15), or they eat the district clock.
- **Scatter > Pellets Per Shot**: bolts per pull. Their colours fan from Bolt Color to Hot Color.
- **Blast > Blast Radius**: above 0 the shot explodes where it lands, hitting every enemy, rival
  cat and car in range (through walls too) and shoving them outward. **Blast Color**, **Blast
  Time**, **Blast Sound** are the look.
- **Look > Shots Per Sound**: plays the sound on every Nth shot, for very fast guns.
- **Finish Grace Seconds** (on the **Health** node in `main.tscn`, 1.5): shots can't finish off a
  rival for this long after they go down, so a scattergun or the Red Dot can't down and knock out
  a cat in the same instant.
- Test: `--give=yarn_zooka --deploy --bait_roomba=aim --pitch=-25 --hold=shoot --hold_delay=60
  --hold_frames=6 --capture=shots/x.png --frames=200` (the `DevCapture roombas` line shows health
  and STUNNED); `--shoot_rival=1` with a blast gun sets the blast off on the rival.

### Adding a new weapon — no code needed
The **Paw-Pistol** was made exactly this way (`scenes/items/pistol.tscn` + `items/pistol.tres`).
Steps for your next one (e.g. a shotgun):
1. In the FileSystem panel, right-click `scenes/items/pistol.tscn` (or `tommy_gun.tscn`) >
   **Duplicate** > `shotgun.tscn`. Open it, delete **Model/Mesh** and drag your own model
   (`models/shotgun.glb`, see "The weapon models" below) onto **Model**. Put **Model/Muzzle** at
   the barrel tip (or give the model a **Muzzle** marker in Blockbench: the gun snaps to it).
2. Select the root node. In the Inspector set e.g. **Automatic** off (one shot per click),
   **Fire Rate** 2, **Damage** 60, **Crit Chance** 0.1, **Heat Per Shot** 0, **Cat Knockback** 14,
   **Bolt Color**, **Hud Name** "SHOTGUN".
3. Right-click the `items` folder > **Create New > Resource...** > **ItemData** > save as
   `shotgun.tres`. Set **Id** `shotgun`, **Display Name** `SHOTGUN`, **Kind** Held, **Hands** 1 or 2,
   **Scene** = `shotgun.tscn`, **Glow Color** (alpha above 0 to glow on the street).
4. Sell it: on `shotgun.tres` set **Shop > Price** (e.g. 120), then select **Hub >
   ComradeWhiskers** in `main.tscn` and add `shotgun` to his **Stock**. Done.
   (Or make it lie in the city instead: add a line for it to the loot table, below.)

### The weapon models (Blockbench, since 10 Nov 2026)
All eight weapons are painted low-poly **Blockbench** models (§20) instead of grey boxes: the
PAW-PISTOL (cat-ear iron sights, paw-print grip, pink laser rail), the PURR-TOMMY (finned barrel,
a TUNA-TIN drum magazine, a copper **HeatCoil** on top that glows hotter as you fire), the FROZEN
TUNA (a whole frozen bluefin, taped tail handle, icicles), the HAIRBALL BLASTER (sawed-off double
barrel, brass hinge, pink-lit vents), the YARN-ZOOKA (PVC tube, launch bell, a glowing yarn ball
in the mouth, cyan capacitor), the CUCUMBER LAUNCHER (pneumatic mortar, cucumber hopper, a pickle
in the muzzle, red CO2 tank, pressure dial), the NEON BAT (spiralling neon tubes, studded ring)
and THE RED DOT (keychain laser pointer, knurled grip, brass split-ring, DANGER LASER sticker).
Each is under 150 triangles.

**Node tree of a weapon scene** (e.g. `scenes/items/pistol.tscn`):
```
Pistol (Node3D, script weapon.gd / melee_weapon.gd)  <- every number in the Inspector
  Model (Node3D)          <- the swing / tilt rotates this
    Mesh                  <- an instance of models/pistol.glb (the Blockbench model)
    Muzzle (Marker3D)     <- bolts start here (guns only)
      MuzzleFlash (OmniLight3D)
```
- **The PS1 look is automatic**: `weapon.gd` runs `LevelKit.psx_ify` on **Model** when the gun
  appears, so in the editor the model looks plain and in the game it's PS1 (wobble, crisp pixels).
- **The muzzle snaps to the model**: each model has a **Muzzle** marker at its barrel tip; when
  the gun appears, **Model/Muzzle** jumps onto it. Reshape a gun in Blockbench and the bolts still
  start at the new tip, no scene editing needed.
- **What glows** (root node > Inspector > **Look**): **Glow Parts** = model parts (Blockbench group
  names) that glow as a whole, in the colour you pick (Pistol `Laser`; Yarn-Zooka `Yarn`,
  `Capacitor`, `Ring`; Red Dot `Lens`, `Button`), brightness **Glow Energy**. **Neon Parts** = parts
  whose *bright painted pixels* glow in their own colour, the dark paint stays dark (Neon Bat
  `Barrel` = the spiral tubes, Frozen Tuna `Ice`, Hairball `Vents`, Cucumber `Cucumber` + `Gauge`);
  the number is how strong (1 soft .. 4 blazing). The Tommy's **HeatCoil** part is found by name.
- **Size in the paw / on the street**: on the card (`items/<weapon>.tres`): **Hold Offset**
  (where it sits, right paw; the left paw is mirrored), **Hold Scale**, **World Scale**.
- **One shared texture**: all eight use the same 128x128 pixel-art sheet (gunmetal, chrome, brass,
  polymer, wood, tape, neon pink/cyan/green, heat coil, hazard stripes, tuna skin/belly/eye/frost,
  cucumber, yarn, the TUNA tin label, the DANGER LASER sticker, dial, CO2 tank...). The layout is
  listed at the top of `tools/make_weapon_specs.py`. Repainting a swatch in one weapon's .bbmodel
  only changes that weapon (each file keeps its own copy of the sheet).
- **Remaking them**: `python tools/make_weapon_specs.py --build` rewrites all eight from Claude's
  recipes (sizes in centimetres) and **overwrites** hand edits in their .bbmodel files. To change
  just one by hand: open `models/blockbench/<weapon>.bbmodel` in Blockbench, edit, Ctrl+S, then
  `python tools/cypurr_models.py export models/blockbench/<weapon>.bbmodel`.
- Test: `--weapons_lineup` (a rack of every weapon with its own camera, plus one `DevCapture
  weapon` line each: muzzle position, coil found, glow parts, triangles, PS1 shader),
  `--weapons_lineup=pistol --lineup_dist=1.1 --lineup_yaw=35` for one close up;
  `--deploy --give=tommy_gun --portrait=me --portrait_side=1.3 --portrait_dist=1.5
  --portrait_height=0.55` to see one in the cat's paw.

### Adding new loot (example: a silver tuna worth $150)
Duplicate `items/fish.tres` as `silver_tuna.tres`, change **Id**, **Cash Value** 150 and the
**Scene** (e.g. a tinted copy of `scenes/items/fish.tscn`), then add a line for it to the loot
table (below).

### The loot table (`loot/city.tres`: what lies around every district)
Every new district puts down the lines of its loot table, top to bottom. Double-click
`loot/city.tres` in the FileSystem dock and expand **Spawns**. Today it has seven lines:

| Item Id | Count | Where | Respawn Seconds | |
|---|---|---|---|---|
| fish | 5 | Outside Meow Mart | 20 | a row by the door |
| fish | 5 | Sidewalk | 20 | random sidewalks |
| sardine | 8 | Sidewalk | 20 | |
| golden_koi | 1 | Sidewalk | 120 | Min Distance From Meow Mart 60. **Skipped while the Meow-Mart heist is on** (§27): the koi is in the tank instead |
| fresh_catch | 3 | Meow Mart Counter | 90 | inside the store, on the iced counter |
| gourmet_tuna | 4 | Meow Mart Shelf | 90 | inside the store, on the aisle ledges |
| catnip_treats | 2 | Meow Mart Shelf | 120 | |

Each line (a **LootSpawn**, `scripts/items/loot_spawn.gd`) says: **Item Id** (the card's id),
**Count**, **Where** (Sidewalk = random spots all over town, Outside Meow Mart = a row by its
door, Fixed Spot = always at **Spot**, Meow Mart Shelf / Meow Mart Counter = free spots inside the
store, §27), **Min Distance From Meow Mart** (Sidewalk only: makes you
travel for it), and **Respawn Seconds** (how long until a taken one grows back; 0 = never).
**Add a line:** Spawns > **Add Element**, click the new empty slot > **New LootSpawn**, fill it in.
**Remove one:** the trash-can icon next to it. More players make everything grow back faster
(**Items > Regrow Faster Per Player**). The **Items** node's **Loot Table** setting points at this
file: a future district type can have its own table (duplicate the file, point at the copy).

**Loot settings** (on any loot card, Inspector > **Loot**):
- **Cash Value**: what it pays when you climb down the exit manhole.
- **Bag Space**: how many of the 3 bag spaces it fills (the koi takes 2).
- **Carry Speed**: 1 = normal, 0.8 = your cat moves 20% slower while carrying it.
- **Noise**: 1 = normal, 1.6 = VAC-COPs spot you from 60% further away.
- **Heat On Pickup**: HEAT added when someone grabs it (§8).
- **Pickup Announcement**: shown to everyone when it's grabbed; `%s` = the cat's name.

### Adding an item with a new behaviour (a shield, a bomb...)
Copy **catnip** (`scripts/items/catnip.gd`: click for 8 s of speed) or **catdip**
(`scripts/items/catdip.gd`: click for 20 s of double jump; Extra Jumps and Duration are Inspector
settings on `scenes/items/catdip.tscn`). Make a script that starts with `extends HeldItem`, put
it on the root of the item's scene, and write what happens in `use_tick()`. Call `consume()` to
use it up. Anything other players must see goes through an `@rpc` function on that script.

### Tuning the system (select **Items** in `main.tscn`)
Pack Size (the backpack), Pack Light Empty / Half / Full (the strip on the backpack), Interact Radius (E), Item Tag Distance, **Loot Table**
(what lies in each city, see above), Regrow Faster Per Player.

### Inventory screen (Tab or I): the BACKPACK VIEW
Press **Tab** or **I** to open it (Esc or Tab again closes it; the mouse is freed while open).
On a controller: **Y** opens it, the d-pad / stick moves the highlight, **A** = left-click, **X** = drop,
**B** / **Y** close.

It's a "No Man's Sky" style screen: the **camera glides in behind your cat** (and back out when you
close it) so its 3D backpack sits on the left, your cat turns its back to you and stands still, and
thin **ocean-blue callout lines** run from the real backpack and your paws to translucent boxes on the
right (the Phase 1 style, `ui/hud_style.tres`):
```
      JOB: MITTENS' FISH  FISH 1/3  +$100        $240 [ABANDON]   <- your quest + your cash
      PAWS                         QUICK USE
      [LEFT  pic $140] [RIGHT pic $60] [1 pic x2] [2 pic]      <- lines to your paws / belt
 (o)--BACKPACK 4/6                          LOOT $500         <- line from the backpack
      [fish  $50] [koi  $400] [tommy $200]
      [scrap    ] [ EMPTY   ] [ EMPTY    ]
      what the highlighted item is, what it sells for, the buttons
```
- Every slot shows the item's side-view **picture** (Icon Studio, §20), its **name** and a **price
  badge**: green = what the shop pays you (loot), blue = what the shop charges (gear).
- **Click a paw** = put that item in the backpack. **Click a backpack item** = take it into your
  paws (whatever was in the way goes into the backpack). **Right-click anything** = drop it.
  Clicking loot does nothing (it says where to sell it).
- **Click a quick-use slot** = put one back in the backpack. **Clicking catnip / catdip in the
  backpack** moves it into a quick-use slot (if one has room) instead of your paws.
- **Hover** (or highlight) an item to read its description and price.
- **Picking things up:** a held item goes into a quick-use slot (catnip / catdip), else a free paw,
  else the backpack; only if all are full does it swap with what's in your paw.
- **At the litterbox** in the sewers a **LITTERBOX** box opens bottom-left (callout line to the
  litterbox), and clicking moves items between you and it instead (§8, "The stash").
- **Split screen:** every player gets their own glide and boxes in their own pane (the camera slides
  less on a narrow pane, and the boxes shrink to fit).
- Tuning: select **Inventory** in `hud.tscn`: Column Start / Max Width, Columns, Slot Max Size, Paw /
  Quick Box Size, font sizes, Anchor Dot Radius, Line Width, Slide In. The camera glide: select the
  cat in `scenes/player.tscn` > **Inventory Camera** (Distance, Side, Lift, Pitch, Speed).
- Code: `scripts/ui/inventory_ui.gd` (`InventoryScreen`; slots are Buttons with a `SlotFace` that draws
  the picture), `CatPlayer.inventory_open()` / `inventory_view_amount()`, `ItemManager.backpack_anchor(cat)`.
- Test: `--give=pistol,fish,golden_koi --inventory` (or `--inventory=0,1` for split-screen seats, with
  `--join_pad=1`) prints `DevCapture inventory` lines; add `--to_stash=pack:0` for the litterbox.
