# 3. The arcade getaway car

[Back to the contents page](../SETUP_GUIDE.md)


**CO-OP and SOLO games keep the classic layout:** ONE car (GetawayCar), parked by the centre
crossroads, next to the single manhole you come up (the Burrow car is removed for that game, on
every computer). The rest of this paragraph is about **TURF WAR** games (§8 "Game modes").
(Moving a parked car is done inside its physics step, `_teleport` in `getaway_car.gd`: a resting
RigidBody ignores a plain "global_transform =", which once left both cars stuck in the middle.)

**One car per gang.** `main.tscn` has two copies of the same car scene: **GetawayCar** (Team 0,
parked 10 m up the street from the Catleone Family's manhole in the south-west corner) and
**GangCar** (Team 1, by the Burrow Gang's manhole in the north-east corner). They're identical:
**anyone can drive either one**, a gang only decides where it waits. Every district (and after
its last rider extracts) a car goes back to its own spot. Select a car and look under
**Parking** in the Inspector: **Team** (-1 = the old spot by the centre), **Park Distance**.
To add a third car: right-click GangCar > Duplicate. Roombas get run over by any car.
(Code: `Game.instance.cars()` lists them; `Game.instance.car_of(player_id)` = the one a player
is in.) Test: `--teams=1 --deploy --drive --hold=move_forward` drives the Burrow car.

### Node tree (`scenes/getaway_car.tscn`)
```
GetawayCar (RigidBody3D)            script: getaway_car.gd
│   Mass 800, Can Sleep OFF, Axis Lock > Angular X + Z ON, Physics Material: friction 0
├── CollisionShape3D                 BoxShape3D 1.8 x 0.8 x 3.6
├── Model (Node3D)
│   ├── CarModel                     models/getaway_car.glb (the WEDGE CYBER-INTERCEPTOR, see below)
│   └── HeadlightBeam (SpotLight3D)  lights the road ahead
├── GroundRay (RayCast3D)            Target Position (0, -0.8, 0)
├── DoorZone (Area3D)                "press E" range
│   └── CollisionShape3D             BoxShape3D 5 x 2 x 6
├── Health (Node3D)                  script: car/car_health.gd  <- HP, smoke, fire, wrecks
├── Boost (Node3D)                   script: car/car_boost.gd   <- the AFTERBURNER (exhaust fire)
├── Juice (Node3D)                   script: car/car_juice.gd   <- arcade feel: launch, DRIFT TURBO, lean, landings
├── CameraRig (Node3D)               Top Level ON  <- follows the car with lag
│   └── SpringArm3D                  position y=1.2, rotation x=-0.3, Spring Length 7
│                                    (the cat's Camera3D gets moved here while driving)
└── MultiplayerSynchronizer          shares sync_position, sync_rotation
```

Why those settings:
- **Can Sleep OFF** — a sleeping body ignores our driving code.
- **Angular X/Z locked** — the car can only turn left/right, so it can never flip. (Ramps will come later.)
- **Friction 0** — our script handles grip; real friction would fight it.

### The look: the WEDGE CYBER-INTERCEPTOR (`models/getaway_car.glb`)
An 80s/90s wedge car: low sharp nose with a cyan visor headlight bar, dark gunmetal body, tinted
cabin with stepped louvers over the rear window, a little **cat-ear spoiler** on the roof (the
inner ears glow), wide wheel arches, side skirts, twin blue rear **thrusters** and a full-width red
taillight bar. 360 triangles, one 128x128 pixel-art texture.
- **Gang colour:** the neon racing rail along each side, the nose and tail lips and the inner cat
  ears are the model's **Trim** part. The game paints it the car's gang colour and makes it glow:
  **GetawayCar = Catleone pink, GangCar = Burrow orange** (from the car's **Team**, colours in
  `scripts/teams.gd`).
- **Wheels** (`WheelFL/FR/BL/BR`) roll with the car's speed and the front two turn when you steer,
  on every player's screen (other players' cars guess the steering from how they turn).
- **Knobs:** select GetawayCar (or GangCar) in `main.tscn` > Inspector > **Look**: **Trim Glow**,
  **Light Glow** (headlights, taillights, thrusters), **Body Shine** (wet-metal shine),
  **Wheel Steer Degrees** (28), **Wheel Steer Speed**, **Wheel Radius**.
- **Changing the model:** double-click `models/blockbench/getaway_car.bbmodel` to repaint it in
  Blockbench (keep the group names: Body, Trim, HeadlightL/R, TaillightL/R, Thrusters,
  WheelFL/FR/BL/BR), then ask Claude to re-export it (section 20). Claude's recipe is
  `tools/model_specs/getaway_car.json`. The car's collision box is not the model: it stays
  the 1.8 x 0.8 x 3.6 m box in CollisionShape3D.
- Test: `--host --no_hud --car_light=4 --cam_from=6.0,1.0,-13.6 --look_from=3,-0.1,-10 --capture=shots/car.png`
  (`--car_light` = a test-only lamp over each car; `--mode=turf` shows the orange GangCar at 72,0,-62).
  The `DevCapture car_look` line prints each car's trim colour, wheel spin and steering.

### What `scripts/getaway_car.gd` does
Arcade-style: each physics step it nudges velocity directly instead of simulating tyres.
- **W** accelerate · **S** brake, then reverse · **A/D** steer (weaker at low speed, flips in reverse)
- **Space = handbrake** — sideways grip drops from 10 to 1.2 and turning gets 1.5x stronger → drift.
- `is_drifting` turns true during slides (hook tyre smoke/sounds to it later).
- **Drive input is separate from the physics:** the keyboard fills in three variables
  (`throttle`, `steer`, `handbrake`) in `_read_driver_keys()`, and the physics only reads those.
  A future AI driver (the Dog Patrol) can fill in the same three and drive with the same physics.
- **Look around while driving:** move the mouse (or the controller's right stick) to swing the
  camera around the car and tilt it up/down. Stop looking and keep driving forward, and after
  a moment it swings back behind the car by itself (parked, it stays where you left it).
  Knobs: select **GetawayCar** in `main.tscn` > Inspector > **Camera & Exit**:
  **Recenter Delay** (seconds before it swings back, 1.5), **Recenter Speed** (how fast, 2.5),
  **Recenter Min Speed** (only above this speed, m/s, 3), **Min / Max Look Pitch Degrees**
  (how far down / up), **Mouse Sensitivity**, **Stick Turn Speed**. The code is
  `_update_look_around()` and `_turn_camera()` (offsets `look_yaw` / `look_pitch`).

### The interaction (E to enter/exit)
1. `DoorZone` notices a cat walking in → sets that cat's `nearby_car` (the HUD shows "[E] GET IN").
2. The cat presses E (the car is usable like anything else, §16 "Pressing E") → it asks the
   **host** (`request_enter`). The host checks that the car is
   empty and the cat is within 5 m, then tells everyone who the driver is (`set_driver`).
3. Every computer hides that cat (`enter_car`); the driver's computer moves its Camera3D onto the
   car's `CameraRig/SpringArm3D` and starts simulating the car.
4. While driving, E → `request_exit` → the host sets the driver to nobody → `exit_car` puts the
   cat 2.2 m to the car's left (**Exit Offset**) and gives it its camera back.

The E press is marked "handled" so the same key press can't enter and exit in one frame.

### Passengers (riding along)
Once someone is driving, other cats by the door see **"[E] RIDE ALONG"** — online or split screen.
Up to 3 can ride (**Passenger Seats** in the Inspector, group *Passengers*: click `GetawayCar` in
`main.tscn`). Passengers can't steer, but they're the **GUNNERS**: each keeps their OWN camera (floating over the
car's roof), looks around with the mouse / right stick and **shoots with whatever is in their paws**
(guns, the bat, even quick-use snacks). Their shots never hit their own car. Press **E** again to hop
out on the right-hand side (**Passenger Exit Offset**; each next one **Passenger Exit Spacing** further
back). If the driver gets out, the passengers stay in; one of them can hop out and take the wheel.
Driving onto the exit beam extracts everyone in the car together. In code: the host keeps
`passenger_ids` and tells every computer the whole list (`set_passengers`); anything that asks "is this
player in the car?" uses `has_occupant(id)` (or `Game.car_of(id)`), and `remove_occupant(id)` /
`empty_car()` take cats out. Test: `--add_local=2 --pos=1,0.5,-10 --drive --ride_along=1,2 --ride_exit=1`.

**The riding code** lives on the cat: `scripts/cat/cat_ride.gd`, the **Ride** node under Player in
`scenes/player.tscn` (next to Moves). Click it for its knobs: **Ride Height** (where the hidden cat
sits in the car), **Gunner Camera Distance** and **Gunner Camera Lift** (the passenger's view).
While in a car the cat is hidden, but its body rides along INSIDE the car every frame, which is why
the bots keep chasing you when you jump in (they hunt the car). Test: `--add_local=1 --drive
--ride_along=1 --gunner_test` ("DevCapture gunner_test" lines: the passenger shoots a bot).

### Car health and wrecks (`scripts/car/car_health.gd`)
The car has **300 HP** (click **Health** in `scenes/getaway_car.tscn` > Inspector > *Toughness*).
VAC-COPs **still chase you in the car**: they ram it instead of you (a ram = the bot's **Bonk Damage
x Car Damage Multiplier**, set on each bot scene, e.g. `scenes/roomba.tscn` > *Hunting*), SQUIRT-DRONE
zaps dent it, and in TURF WAR the other gang's guns hurt it (your own gang's don't). **Crashing never
hurts it** (walls, buildings, props): only enemies do. To bring crash damage back, tick **Crashes Hurt**
(then losing more than **Crash Speed Loss** m/s almost at once = a dent).
A health bar floats over the car once it's damaged (blue for your gang's car, red for the rival's).
Under half health it smokes, under a fifth it burns (*Look*: **Smoke Below**, **Fire Below**).
At 0 HP it **WRECKS**: a fireball, everyone inside is thrown out and loses **Wreck Occupant Damage**
HP, and nobody can get in. After **Wreck Seconds** it's towed back to its parking spot, fixed.
A new district fixes it too. Test: `--drive --car_test` ("DevCapture car_test" lines), `--drive
--car_chase` (a VAC-COP chases the car and rams it).

### Arcade feel + feedback (`scripts/car/car_juice.gd`)

All knobs: open `scenes/getaway_car.tscn`, click **Juice** in the Scene panel, look at the Inspector.
- **Launch**: flooring it from slow speed pulls harder (Launch Accel Bonus 1.8, fades out at top speed).
- **DRIFT TURBO**: hold the handbrake (Space) through a corner while steering. Sparks fly off the back
  wheels: BLUE after Turbo Blue Seconds (0.6), ORANGE after Turbo Orange Seconds (1.2). Let go of the
  handbrake = a speed kick (Turbo Blue Kick 4 / Turbo Orange Kick 7.5 m/s), a whoosh and a camera kick.
  Drifts keep their speed: Drift Drag Scale (less handbrake slowdown), Drift Carry (sideways slide turned
  into forward speed) and Drift Max Angle (40 degrees: the car holds a sideways slide instead of spinning out).
- **Body Lean**: only the model tilts: leans out of turns (Roll Degrees), squats on gas / dips on brakes
  (Pitch Degrees), Lean Spring = snappiness.
- **Landing**: after a jump the body squashes and springs back with a thump, a dust puff and a shake.
- **Tyre smoke** while drifting or wheel-spinning, a **skid sound** (Skid Sound / Volume / Pitch: any name
  from `sounds/sfx/`), **Speed Camera** (pulls back Camera Pullback metres at top speed, a little road
  rattle near top speed), and controller **rumble** on drifts, landings and turbos.
Everything you see is worked out from how the car moves, on every computer (others see your sparks too).
Test: `--drive --car_juice` ("DevCapture car_juice" lines: launch speeds, turbo level, body roll, kick).

### The AFTERBURNER boost (`scripts/car/car_boost.gd`)
Every car starts with **1 charge** (*Base Charges* on the Boost node). The TINKER WORKBENCH (§25, Paulie
No-Brooms / Bumper-Car Benny's tab) sells **AFTERBURNER**: tier 1 = 2 charges, tier 2 = 3 charges (a CREW
upgrade: the gang's best tier counts, whoever drives).
While driving press **BOOST** (Shift, or A on a controller; rebind it in SETTINGS > KEYS): the car
kicks forward and floors it past its top speed for a moment, with **fire roaring out of the exhaust**
(two flame jets, an orange glow on the street, a trail of fire cubes, a wider + shaking camera).
**Nothing gets killed by the boost: it all goes FLYING.** Bots in the exhaust fire, or rammed while
boosting, are launched into the air, spin, land and lie dazed (bosses are too heavy). Cats on foot
in the fire get launched too (no damage), and bins and cones go over. A used charge comes back after
**Recharge Seconds** (25). The driver sees the **BOOST bar** bottom-left (just above the guns box,
`scripts/ui/hud_boost_bar.gd`, node `scenes/ui/hud.tscn` > Frame > Middle > **Boost**): ONE bar that always
stays the same width and is split into a piece per charge (1, 2 or 3); bright = ready, the next piece fills
up while it recharges. Its colours / thickness / split gap are in the Inspector with Boost selected. Knobs: click **Boost** in `scenes/getaway_car.tscn` (*Boost*, *Sending
stuff flying*, *Look*); how long a launched bot lies dazed is **Launch Daze Seconds** on the bot.
The sound and flame icon come from `python tools/make_boost_assets.py`. Test: `--drive --car_test
[--boost_snap --frames=20]` (the second takes a picture mid-boost).
