# 2. The third-person cat controller

[Back to the contents page](../SETUP_GUIDE.md)


### Node tree (`scenes/player.tscn`)
```
Player (CharacterBody3D)            script: cat_player.gd
├── CollisionShape3D                 CapsuleShape3D r=0.3 h=0.9, position y=0.45
├── CatModel                         <- an instance of scenes/cat_model.tscn (the cat's body);
│   │                                   turns to face movement; leans during zoomies
│   ├── Body, Belly, LegL, LegR, Head, EarL, EarR, Muzzle, Nose, EyeL, EyeR, Tail
│   │   (upright "villager" style: big round head, no arms; low-poly spheres/cylinders.
│   │    Colours and hats/shades/collars come from the player's MY CAT look, §11.)
├── Moves (Node)                     script: scripts/cat/cat_moves.gd — CAT MOVES (pounce, wall
│                                    kick, clamber, snappy jumps, squash & stretch). Its knobs live here.
├── Aim (Node)                       script: scripts/cat/cat_aim.gd — AIM DOWN SIGHTS + gun recoil
│                                    (camera distance/side/zoom while aiming, walk + look speed). §9.
├── Melee (Node3D)                   script: scripts/cat/cat_melee.gd — the MELEE button (F / RB):
│                                    bare-claw SCRATCH, and THROWING the offhand bat. Its knobs live here. §9.
├── CameraPivot (Node3D)             position y=0.6 — mouse left/right turns this
│   └── SpringArm3D                  rotation x=-0.35 rad, Spring Length 3.5 — mouse up/down tilts this
│       └── Camera3D                 (its FOV comes from the FIELD OF VIEW setting)
├── NameTag (Label3D)                the player's name, shown to everyone else. Group "hud_name_tags":
│                                    the HUD draws it sharp (§13); this Label3D is just the marker
└── MultiplayerSynchronizer          shares sync_position, sync_model_rotation, player_name, look
```
To change the cat's body shape, open `scenes/cat_model.tscn` (every player cat and the MY CAT
preview use it). Keep the mesh names: the colour options paint meshes by name (§11).

**Key design choice:** only `CatModel` rotates, never the `Player` body. If the body rotated, the
camera (its child) would whip around every time the cat turned.

### What `scripts/cat_player.gd` does
- **WASD relative to camera** — reads input, converts it using `CameraPivot`'s facing, flattens it to the ground.
- **Smooth turning** — `lerp_angle` eases `CatModel` toward the run direction.
- **Gravity + jump** — Space, on the floor (catdip adds mid-air jumps, §9). A catdip
  double jump does a **FRONT FLIP** (a Jedi-style somersault, see "Double Jump Flip" below).
  The fancy cat parkour is the **Moves** node: see "Cat Moves" below.
- **Zoomies (Shift)** — higher top speed, cat leans nose-forward, camera rolls when strafing, FOV widens.
- **Mouse look** — speed and invert-Y come from the Settings menu (§10). Esc opens the pause menu
  (which frees the mouse); if the mouse gets freed another way, click the game to grab it again.
- **Controller** — right stick turns the camera (`_stick_look`, knobs **Stick Turn Speed** /
  **Stick Pitch Ratio**), the left stick is analog (half push = walk at half speed). See §10,
  "Playing with a controller".
- **Items** — E grabs the nearest item, G drops what's in your paws, Left/Right Mouse use them
  (§9). With a gun, the cat turns to face where the camera looks, and the camera slides over the
  right shoulder (**Gun Shoulder Offset**, in the Camera group).
- **Car** — E while standing by the car asks to get in (§3).
- **While the pause menu is open** the cat ignores the keyboard (`PauseMenu.is_open`).

Every number is an `@export`, so select the Player node and tweak speeds in the **Inspector**
(groups: Movement / Camera / Zoomies Juice / Running Animation / Double Jump Flip /
Network Smoothing) — no code editing needed. Jump feel, pounces, wall kicks and clambering are on the
**Moves** child node instead (see "Cat Moves" below).

**Running Animation**: the cat's `LegL`/`LegR` (in `scenes/cat_model.tscn`) swing back and forth
while it runs, and its `Tail` sways side to side all the time, faster the faster it runs.
Knobs: Leg Swing (how far), Leg Swing Speed (steps per second at walking speed), Tail Swish
(how far), Tail Idle Speed (sway speed standing still), Tail Speed Per Mps (extra sway speed per
unit of running speed). Other players' cats animate the same way on your screen automatically.

**Double Jump Flip**: one front flip on every mid-air (catdip) jump, spinning around the cat's middle
with its legs tucked. Knobs: Flip Seconds (how long), Flip Turns (1 = one full flip), Flip Pivot
Height (the spin point, metres above the feet), Flip Leg Tuck.

**Cat Moves** (click **Player > Moves** in `scenes/player.tscn`, script `scripts/cat/cat_moves.gd`):
- **Snappy Jumps**: Coyote Seconds (you can still jump just after running off an edge), Jump Buffer
  Seconds (press jump just before landing and it still fires), Short Hop Cut (let go of Space early =
  small hop; 1 = off), Fall Gravity (falling pulls harder than rising; 1 = floaty old feel), Max Fall
  Speed, Air Control (steering in mid-air: 1 = like the ground, lower keeps your momentum).
- **Pounce**: jump during ZOOMIES = a long low leap. Pounce Boost (extra forward speed; 0 = off),
  Pounce Lift (height compared to a normal jump).
- **Wall Kick**: press jump in mid-air next to a wall = kick off it (claw scratch sound). Wall Kicks
  (per jump, landing refills; 0 = off), Wall Kick Push, Wall Kick Lift, Wall Kick Lock (seconds you
  can't steer after a kick), Wall Kick Reach (how close the wall must be).
- **Clamber**: in mid-air, push into a ledge just above your paws and the cat scrambles on top.
  Clamber Reach (highest ledge above the paws, metres; 0 = off), Clamber Clearance.
- **Squash and Stretch**: Air Stretch, Land Squash, Squash Spring / Squash Damping (the wobble),
  Air Pitch Degrees (nose up rising, nose down falling), Hard Landing Speed (big drops thump).
  Every computer works this out from how each cat moves, so it needs no network.
- Test it: `--host --moves_test` builds a test yard in the sky and prints a `DevCapture moves`
  line for each move (jump, short hop, run jump vs pounce, wall kick, clamber onto a crate).

Keys are handled by the **Controls** framework (`scripts/controls.gd`) — players rebind them in
**SETTINGS > KEYS**. See section 10, "Controls & key binding".
