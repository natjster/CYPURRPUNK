# 8. The extraction loop — VAC-COPs, their backup & HEAT

[Back to the contents page](../SETUP_GUIDE.md) · [Start of §8](08-the-extraction-loop-the-sewers.md)

### VAC-COPs (police Roombas — the enemy)
Eight police Roombas patrol the city's sidewalks (more as the HEAT rises, see below). When one spots a cat **on foot** within 14 m,
its red/blue siren flashes, its eye turns red, and it charges. It's faster than a walking cat but
slower than **zoomies** (Shift) — so run! If it touches you it **bonks** you flying,
**vacuums up one fish** (the last loot you picked up, never your gear) from your backpack and takes **34 HP**.
Then it backs off for a couple of seconds. Three bonks and you're **knocked out** (see
**Health & knockouts** below).

**Getting your fish back:** destroy it. It has **100 health**: about **3 pistol shots** (40 each)
or **4 tommy-gun bolts** (25 each), or **run it over** with the car at speed. Once you (or any
other player) have **shot** it, a red **health bar** floats over it, and every hit pops a **damage number** off it
(see **Health bars & damage numbers** below). It explodes and spits out everything it vacuumed — press E on the fish to grab them.
A new Roomba rolls out somewhere else 15 seconds later. Cats in the car and cats in the hub are
safe. Shoot a Roomba and it gets angry and chases *you*.

**Where it lives:** `scenes/roomba.tscn` (script `scripts/roomba.gd`, built on the enemy
framework `scripts/enemy.gd`, §16). The **Roombas** node in
`main.tscn` (script `scripts/roomba_patrol.gd`) puts them out when a game is hosted, and its
sibling **RoombaSpawner** (a MultiplayerSpawner) copies them to every player.

**The look (Nov 2026):** an armoured black-and-white police-enforcer disc, built in Blockbench
(`models/blockbench/roomba.bbmodel` -> `models/roomba.glb`, 258 triangles, 128x128 texture with
"VAC-COP" / "PROTECT & SUCTION" stencils, vents and rivets, a hazard-striped ram bumper, a dust-bin
dome with twin police lights, and two corner whisker brushes that spin). The MEGA VAC-COP is the
same model at 2.6x. Its wide **cyclops visor (the Eye)** glows cyan on patrol and red when it
chases (it can be made a **weak spot**: see "The EYE weak spot" below).

**The EYE weak spot is switched OFF** (since 11 Nov 2026): the eye still glows, but a shot into it
does normal damage. To bring it back, open a bot's scene (e.g. `scenes/roomba.tscn`),
select the root node > Inspector > **Eye Weak Spot** > tick **Eye Is Weak Spot**. When ticked, on
every bot (VAC-COP, MEGA VAC-COP, LINT-TRAPPER, SQUIRT-DRONE)
a bolt into the glowing eye is ALWAYS a critical hit: double damage (or the gun's own Crit
Multiplier if that's bigger), the big yellow CRIT number and a white-hot flash of the visor (no
extra sound: **Eye Crit Sound** is empty; type a `sfx/` file name there to give it one). Shots into the back of the body don't count, and
explosions (the YARN-ZOOKA's blast) never do. Tuning: select the bot's root node > Inspector >
**Eye Weak Spot**: **Eye Crit Radius** (how close to the eye's middle counts, metres; grows with
the model's scale, so the MEGA VAC-COP's eye is a bigger target), **Eye Crit Multiplier**, **Eye
Path** and **Eye Crit Sound**. Test: `--host --eye_test [--roomba=boss|drone|trapper]` prints one
eye shot and one body shot ("DevCapture eye_test" lines: with the weak spot off both say crit=false).

```
Roomba (CharacterBody3D, collision Layer 2)   script: roomba.gd (extends enemy.gd)
├── CollisionShape3D
├── Model (= models/roomba.glb) > Body, Cap, Bumper, Eye, SirenRed, SirenBlue, Brush, Brush2
├── SirenLight (OmniLight3D)       <- red/blue on the street while chasing
└── MultiplayerSynchronizer        <- sync_position, sync_yaw, state, health
```

**Tuning:**
- Select **Roombas** in `main.tscn`: **Roomba Count** (20 patrolling a calm district),
  **Respawn Seconds**, **Min Spawn Distance** (never appears this close to a cat or the centre
  crossroads).
- **How many at once:** 20 calm, +5 per heat level (35 at level 4), +2 per player beyond the 2nd,
  and +40 more in the DEEP CLEAN. Tested: 80 VAC-COPs + the boss still ran at ~400 fps (uncapped)
  on this PC, and a calm district only ~10% slower than the old 8-Roomba game.
- **Performance** (select the root of `scenes/roomba.tscn`, group **Performance**): Far Distance +
  Far Think Every (Roombas further than 60 m from every cat think every 4th frame), Replans Per
  Second (a chasing Roomba re-plans its route 10 times a second), Draw Distance (75 m: the fog hides
  them beyond that; the boss uses 250), Hum Distance (35 m). Their siren lights fade out past 25 m,
  and their positions are only sent over the network when they change.
- Open `scenes/roomba.tscn`, select the root **Roomba**: **Driving** (Patrol Speed, Chase Speed,
  Turn Speed), **Hunting** (Sight Range, Lose Range, Bump Range, Bump Push, Bump Hop, Stun Seconds,
  Steals Loot, **Bonk Damage** = HP a bonk takes off a cat, 0 = harmless, **Heat Scaling** = gets
  faster and sharper-eyed with heat).
- Further down the Inspector, the **Enemy** part (shared by every enemy, `enemy.gd`):
  **Toughness** (**Max Health**, **Display Name** = the name over its health bar, **Health Bar
  Height**, Car Smash Speed, Car Smash Radius), **Boss** (Is Boss, Drop On Destroy: see **HEAT and
  the MEGA VAC-COP**), **Sounds** (Hit Sound, Explode Sound), **Network Smoothing**.
- Roombas are on collision **Layer 2**, so cats and the car pass over them instead of getting
  stuck (Inspector > Collision > Layer). Guns still hit them.

**Multiplayer:** the host runs every Roomba's brain; everyone else's copy glides to where the
host says it is. Bonks, stolen fish and explosions are all decided by the host.

### SQUIRT-DRONEs and LINT-TRAPPERs (the VAC-COP's backup)
Every new patrol unit has a **20%** chance of being a LINT-TRAPPER and a **15%** chance of being a
SQUIRT-DRONE; the other 65% are VAC-COPs. The mix is the same for the district start, heat
reinforcements, replacements and the DEEP CLEAN swarm. Both count as kills for the MEGA VAC-COP
call-in and the Smash 5 quest.

**SQUIRT-DRONE** (60 health, about 2 pistol shots): a quadcopter hovering **3.8 m** up. Cars drive
underneath and can't smash it, so shoot it, or jump and swing at it (a bat takes two hits, the
Frozen Tuna one). Its spotlight is cyan on patrol and turns red on the cat it tracks.
- It spots cats from 18 m and holds about 6 m away from them.
- With a clear view of a cat it adds **0.25 heat per second**. **This stacks:** three drones on you
  add 0.75 per second.
- Every 2 seconds it fires a water zap at the spot you're standing on. The zap takes 0.25 seconds
  to land, so keep moving. A hit (1.4 m splash) takes **15 HP** with a small hop. It never steals.
- A **stun** (YARN-ZOOKA) makes it sink to **1 m**, in easy reach of a melee swing.

**LINT-TRAPPER** (80 health, can be run over like a VAC-COP): a mop-bot with a hot-pink roller. It
never bonks and never steals.
- While chasing it leaves a pink puddle behind it every 1.2 seconds.
- Within 7.5 m it lobs a glob at your feet every 3.5 seconds (a puddle where it lands).
- Puddles last 6 seconds. Touch one on the ground and you have **STICKY PAWS**: half speed until
  3 seconds after you leave it (zoomies 9 -> 4.5 m/s, slow enough for a VAC-COP to catch you).
  You hear a splat and an amber **paw-in-glue badge** appears next to your health bar (top-left),
  draining as the 3 seconds run out (section 13, "Buff and debuff badges").
  Jumping over a puddle keeps you clean.

**The look (Nov 2026):** both are Blockbench models now. The LINT-TRAPPER (`models/lint_trapper.glb`)
is a heavy purple-and-black street-sweeper tank: a wide sticky glue roller up front that spins,
a glowing pink glue canister at the back, hazard-striped side skirts, twin sirens and a glowing
visor. The SQUIRT-DRONE (`models/squirt_drone.glb`) is an angular OVERCLEAN quad-copter: four arms
with spinning propellers, a glowing cyan water tank slung underneath with a spray nozzle, twin
sirens and a glowing lens on its nose. Both eyes can be **weak spots** (off by default, see VAC-COPs
above). What glows, in which colour: root node > Inspector > **Look > Glow Parts**.

**Where they live:** `scenes/squirt_drone.tscn` (`scripts/squirt_drone.gd`),
`scenes/lint_trapper.tscn` (`scripts/lint_trapper.gd`) and `scripts/sticky_patch.gd` (the puddle,
built in code). Both scripts **extend the VAC-COP's script** (`roomba.gd`), so they use its
patrolling, street-finding, stun and performance settings. They replace only `_fall`, `_chase_point`,
`_attack` and `_show_light`.

```
SquirtDrone (CharacterBody3D, Layer 2)         LintTrapper (CharacterBody3D, Layer 2)
├── CollisionShape3D                           ├── CollisionShape3D
├── Model > Body, Arm1-2, Tank, Nozzle, Eye,   ├── Model > Body, Hood, Tank, Eye, SirenRed,
│   SirenRed, SirenBlue, Motor1-4,             │   SirenBlue, Brush (Roller, Stripe)
│   Rotors (Rotor1-4 > Blade, Blade2)          ├── SirenLight (OmniLight3D)
├── SirenLight (SpotLight3D)                   └── MultiplayerSynchronizer
└── MultiplayerSynchronizer
```

**Tuning:**
- Select **Roombas** in `main.tscn`, group **Patrol Mix**: **Lint Trapper Chance**, **Squirt Drone
  Chance**.
- Open `scenes/squirt_drone.tscn`, select the root: **Flight** (Hover Height, Stunned Height, Climb
  Strength, Max Climb Speed, Stand Off), **Spotlight and Water Zap** (Heat Per Second, Squirt Seconds,
  Squirt Travel Seconds, Squirt Radius, Squirt Damage, Squirt Push, Squirt Hop, the two light colours).
- Open `scenes/lint_trapper.tscn`, select the root: **Sticky Glue** (Patch Radius, Patch Seconds,
  Trail Seconds, Trail Spacing, Lob Range, Lob Seconds, Lob Flight Seconds, Lob Height, Keep Distance).
- Open `scenes/player.tscn`, select the root: **Sticky Slow**, **Sticky Seconds**.
- Speeds, sight and health are in the same Inspector groups as the VAC-COP's.

**Multiplayer:** the host runs both brains and decides every zap. Each puddle is made on every
computer, and each player's own computer checks their own paws.

**Test:** `--deploy --roomba=drone --bait_roomba=8` (or `--roomba=trapper`), and add
`--stun_roomba=6` for a stun. The `DevCapture roombas` and `DevCapture sticky` lines show the result.

### HEAT and the MEGA VAC-COP (the pressure)
The longer you stay up top, the angrier the city gets. The **HEAT** bar (top-right, flashing
red and blue) is **shared by every player**:

- It's the **district's clock**, but only a slow one: it creeps up **0.111 per second** while any cat is
  in the city (about **15 minutes** from 0 to 100 if you cause no trouble; the exit opens at about 11),
  **+5%** faster for every extra cat up top.
- Most heat comes from what you DO: **+2.5** per bot destroyed, **+0.8** per mess (bins, cones, boxes,
  posters), **+0.25/s** per squirt-drone watching you, and a little per gun hit (**+0.15** times the
  gun's City Heat Per Hit). A loud raid (~20 kills plus mess) hits 100 in about 7 minutes.
- **Trouble is smoothed:** heat from trouble waits in a pool and trickles onto the bar at most
  **1 per second** (Heat > **Trouble Heat Per Second Max**; 0 = lands at once). A killing spree costs the
  same in the end, but the bar climbs steadily instead of jumping a whole level in a few seconds. (The golden
  koi doesn't add heat any more: it's already heavy and noisy. To bring it back, set **Heat On
  Pickup** on `items/golden_koi.tres`, e.g. 20.)
- It **never cools down** by itself (extracting and going home don't lower it). Only a new
  district resets it to 0. (The Cooling Down numbers on the Heat node are 0; raise them if you
  ever want cooling back.)
- **75** opens the exit manhole, **90** = Don's warning, **100** = the hatch is sealed and the
  **DEEP CLEAN** starts (see Fish Heist above).

Every 25 heat is one **HEAT LEVEL** (an alarm sound). The HUD shows the heat as ONE bar in the TOP-RIGHT with the
number (0-100) written inside its right end, flashing RED and BLUE like police lights - faster
at each level, with a white flash on the frame when a level goes up. In the sewers the same bar is your
Mainframe, with "MAINFRAME" inside its left end. It's **Frame > Top > Heat** in `scenes/ui/hud.tscn` (script
`scripts/ui/hud_heat_bar.gd`): select it and change the two colours, flash speed and smoothness in the
Inspector; **Shape** has Bar Thickness, Number Font Size, and two extras that are OFF to keep it clean:
**Show Level Ticks** (25/50/75 marks) and **Show Exit Mark** (a notch where your exit opens). Each level above 1 brings
**+5 Roombas** (they roll in one every 2 seconds), and all Roombas chase **7% faster** and spot
you from **10% further**. At level 4, a chasing Roomba is almost as fast as a cat on zoomies
carrying the koi...

**No MEGA VAC-COP ever comes out before 25 heat** (Roombas node > **Boss Min Heat**). Then one
rolls out at **HEAT LEVELS 2-4**: at heat 25, 50 and 75 (even if another is still out; they stay
until destroyed or the district ends). On top of that, **one is called in every time the crew destroys
3 VAC-COPs**, up to **4 times per district** (only when no boss is out, and only from 25 heat on: kills
before that still count, so the boss arrives right at 25), and one always comes out for the DEEP CLEAN at
100 heat (level bosses and the DEEP CLEAN one don't count toward the 4).
The heat bar only shows while you're up in the city - down in the sewers the same bar shows The Mainframe's charge. The car can't run the boss over: driving into
it is a crash, like hitting a wall (the car stops dead and bounces back a little; tune
**Boss Crash Bounce** on the GetawayCar). That works because `roomba_boss.tscn` is also on
collision **layer 3** and the car's **Mask** includes layer 3 (Inspector > CollisionObject3D >
Collision). Everyone hears its
siren. A giant Roomba (`scenes/roomba_boss.tscn`) drives in from across town, following the streets around buildings until it can see you (every Roomba
does this while chasing). It **always knows where you are** (sight 400 m), bonks for **67 HP** (two
bonks = knocked out), can't be run over, and has **600 health** (once it's been shot, a big health bar
floats over it, like the little ones' but twice the size). Destroy it and it spits out **one SCRAP per
cat up top** (fuel for The Mainframe and upgrades; **Drop Once Per Cat** on `roomba_boss.tscn`). Every
regular bot a cat smashes also has a **5%** chance to drop a SCRAP (**Scrap Chance** on each bot scene;
SCRAP MAGNET adds to it). In the DEEP CLEAN, destroying it doesn't stop the swarm.

**Where it lives:** `scripts/heat_meter.gd` on the **Heat** node in `main.tscn` (the number, the
levels, the HUD bar); `scripts/roomba_patrol.gd` on **Roombas** (extra Roombas and the boss).

**Tuning:**
- Select **Heat** in `main.tscn`: **Heating Up** (Heat Per Second, Heat Per Extra Cat, Heat Per Roomba Hit, Heat Per
  Roomba Destroyed, Trouble Heat Per Second Max), **Cooling Down** (Cool Per Extraction, Cool Per Second When Empty, Cool When
  Boss Destroyed), **What Each Level Does** (Extra Roombas Per Level, Speed Per Level, Sight Per
  Level).
- Select **Roombas**: **Reinforce Seconds**, and under **MEGA VAC-COP**: Boss Spawn Distance,
  **Boss Every Kills** (3), **Bosses Per District** (4), **Boss On Levels** ([1, 2, 3, 4]: remove a
  number to skip that level's boss); under **DEEP CLEAN swarm**: Deep Clean
  Roombas, Swarm Min/Max Distance, Swarm Sight Multiplier, Swarm Spawns Per Frame.
- The boss itself: open `scenes/roomba_boss.tscn` and select the root. It's the normal Roomba
  with bigger numbers, so it has the same settings, plus the **Boss** group: Is Boss, **Drop On
  Destroy** (`scrap`), Heat Scaling (off: the boss doesn't get faster with heat).
- How much heat an item adds when grabbed: **Heat On Pickup** on its card.
