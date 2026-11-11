# CYPURRPUNK — Setup & How-It-Works Guide

Everything below is **already built as files in this folder**. You don't have to paste code —
open the project and press Play. The sections explain what each piece is, so you can tweak it
(or rebuild it by hand) in the Godot editor.

```
Meow-City/
├── project.godot              <- project settings (low-res, crunchy pixels, autoloads, version)
├── export_presets.cfg         <- how to build the game for other devices: the Android phone build (§17)
├── scenes/
│   ├── game_screen.tscn       <- the top scene F5 runs: the low-res game + the HUD over it (§13)
│   ├── main.tscn              <- THE game (city, cats, menus), shown inside game_screen.tscn
│   ├── player.tscn            <- the cat
│   ├── cat_model.tscn         <- the cat's body (used by player.tscn and the MY CAT preview, §11)
│   ├── cat_parts/             <- accessory models: fedora, beanie, neon_halo, shades... (§11)
│   ├── getaway_car.tscn       <- the car (the Blockbench model models/getaway_car.glb + headlight beam)
│   ├── roomba.tscn            <- the VAC-COP police Roomba (the enemy)
│   ├── items/                 <- item models: tommy_gun, pistol, catnip, catdip, fish
│   ├── npcs/                  <- characters you talk to: don_catleone, lil_mittens, npc_template (§8)
│   ├── props/                 <- street_lamp (warm light cone), rain (follows the camera)
│   └── ui/                    <- settings_menu.tscn (the Settings screen), hud.tscn (the HUD, §13)
├── items/                     <- ITEM CARDS (.tres), one per item, loaded automatically (§9)
├── loot/city.tres             <- THE LOOT TABLE: what lies where in every district (§9)
├── quests/                    <- QUEST CARDS (.tres), one per quest, loaded automatically (§8)
├── cat_parts/                 <- MY CAT: accessory cards (.tres) + palette.tres (colours) (§11)
├── sounds/                    <- SOUND FILES: sfx/, ambience/, music/ — drop files in, no code (§12)
├── models/                    <- REAL 3D MODELS (.glb): trash_bin, traffic_cone, cardboard_box, overclean_poster, loudspeaker, workbench, cyber_bike, fish_van (§20, §21, §23, §25)
│   └── blockbench/            <- their Blockbench projects (.bbmodel): double-click to edit (§20)
├── tools/                     <- Claude's helpers: the Model Shop + Sound Lab (Python, §20)
├── .mcp.json                  <- tells Claude Code to start those helpers in this project (§20)
├── scripts/
│   ├── game.gd                <- main scene: start a game, spawn cats, late joiners
│   ├── game_systems.gd        <- GameSystems: the list of host-run systems (§16)
│   ├── net.gd                 <- autoload "Net": host / join / leave (the only file that knows HOW we connect)
│   ├── settings.gd            <- autoload "Settings": every player setting, saved to disk
│   ├── controls.gd            <- autoload "Controls": every key + controller button, rebinding, rumble, saved to controls.cfg
│   ├── sound.gd               <- autoload "Sound": plays every sound and the music (§12)
│   ├── events.gd              <- autoload "Events": the big moments (sealed, extracted, knocked out...) (§16)
│   ├── overclean_announcer.gd <- OVERCLEAN's voice over the city loudspeaker poles (§21)
│   ├── loudspeaker.gd         <- one OVERCLEAN loudspeaker pole: its words + blinking light (§21)
│   ├── mess_manager.gd        <- MESS-MAKING rules: knocking props over, heat, the bots tidying (§23)
│   ├── spectator.gd           <- THE CAT-CAM: watching your crew after a knockout, the radio HECKLE (§24)
│   ├── mess_prop.gd           <- one knock-over-able bin / cone / box / poster (§23)
│   ├── district_twist.gd      <- DISTRICT TWISTS: blackout, bin day, clearance, high alert (§26)
│   ├── interiors/             <- places you can go INSIDE: meow_mart_interior.gd (the Meow-Mart heist, §27), hit_relay.gd
│   ├── dev_capture.gd         <- autoload "DevCapture": test/screenshot tool (off in normal play)
│   ├── cat_player.gd          <- cat movement, camera, zoomies, getting in/out of the car
│   ├── getaway_car.gd         <- driving, drifting, who's driving
│   ├── city_generator.gd      <- builds the whole city from one number
│   ├── fish_heist.gd          <- fish spots, manholes, payphones, the DEEP CLEAN, the exit arrow
│   ├── wallet.gd              <- Wallet: every player's cash + the sewer scoreboard (§16)
│   ├── hub.gd                 <- THE SEWERS: the underground hub where cats start, one per gang (§8)
│   ├── teams.gd               <- the two gangs: Catleone Family / Burrow Gang (§8)
│   ├── npcs/                  <- the NPC framework: npc.gd, npc_page.gd, npc_choice.gd (§8)
│   ├── quests/                <- the quest system: quest_data.gd, quest_manager.gd (§8)
│   ├── enemy.gd               <- Enemy: what every enemy shares (health, shot, explode, network) (§16)
│   ├── roomba.gd              <- one VAC-COP (extends Enemy): patrol, chase, bonk, vacuum loot
│   ├── hit.gd                 <- Hit: one way for anything to get shot (§16)
│   ├── interactable.gd        <- Interactable: one way for anything to be used with E (§16)
│   ├── motion.gd              <- Motion: small helpers (distance along the ground, network gliding)
│   ├── level_kit.gd           <- LevelKit: boxes, lights, signs, PS1 materials for code-built places (§16)
│   ├── roomba_patrol.gd       <- puts VAC-COPs in the city and replaces destroyed ones
│   ├── rain_follow.gd         <- keeps the rain above the active camera
│   ├── items/                 <- the item system (§9)
│   ├── cat/                   <- the character creator framework: cat_look, cat_part, cat_palette (§11)
│   ├── cat_health.gd          <- HP, downed cats, revives and knockouts (§8)
│   ├── player_profile.gd      <- saves your cash + stash between games (§8)
│   ├── player_id.gd           <- PlayerId: player numbers vs computer numbers, for split screen (§6)
│   ├── seats.gd               <- autoload "Seats": which controller belongs to which couch player (§10)
│   └── ui/                    <- game_screen + hud (§13), main_menu, pause_menu, settings_menu, inventory_ui, npc_dialog, cat_creator
├── shaders/
│   ├── psx_lit.gdshader       <- wobble, warpy textures, flat shading, glow (3D objects)
│   └── psx_post.gdshader      <- CRT + 15-bit color + dithering (full-screen overlay)
├── trailer/                   <- TRAILER MAKER: shot list, music, captions, editing (Python, §15)
├── textures/                  <- tiny placeholder pixel textures
├── ui/menu_theme.tres         <- the look of every menu (colours, borders)
├── ui/hud_theme.tres          <- the look of the HUD text (font, outline, shadow) (§13)
└── shots/                     <- screenshots from the capture tool (Godot ignores this folder)
```

**Opening it:** install **Godot 4.7.2** (standard edition, not .NET). In the Project Manager
click **Import**, pick `project.godot` in this folder, then **Import & Edit**. Press **F5** to play.

**Where your saves go:** `%APPDATA%\MeowCity1999\` (paste that into the Explorer address bar).
The folder keeps its old name on purpose: the game used to be called MEOW-CITY 1999, and renaming the
folder would lose everyone's saves. It's set in **Project > Project Settings > Application > Config >
Custom User Dir Name**; leave it alone.
Set in Project Settings > Application > Config > **Use Custom User Dir** / **Custom User Dir Name**.

---

## 1. Godot project settings for PS1 graphics

### Resolution and pixel scaling
Already set in `project.godot`. To see/change by hand: **Project > Project Settings**, turn on
**Advanced Settings** (top-right toggle), then:

| Setting path | Value | Why |
|---|---|---|
| Display > Window > Size > Viewport Width | `960` | Size the HUD is designed at (HUD units) |
| Display > Window > Size > Viewport Height | `720` | The screen is always 720 HUD units tall |
| Display > Window > Size > Window Width Override | `1280` | Window opens at 1280x960 (4x the game) |
| Display > Window > Size > Window Height Override | `960` | |
| Display > Window > Stretch > Mode | `canvas_items` | With UI STYLE = MODERN the HUD is drawn sharp at the real resolution |
| Display > Window > Stretch > Aspect | `keep_height` | HUD units: always 720 tall, wider on wide screens |
| Rendering > Textures > Canvas Textures > Default Texture Filter | `Nearest` | No blur |

**The 320x240 game picture is NOT a project setting any more:** the game (`main.tscn`) is drawn
into a 320x240 **SubViewport** inside `scenes/game_screen.tscn`, which blows it up with chunky
pixels, and the HUD is drawn sharp on top (§13). `scripts/ui/game_screen.gd` does the sizing.

(Players can change the resolution, fullscreen and scaling in the in-game Settings, §10. The game
is still *drawn* at 320x240 whatever the resolution; a bigger resolution just shows it bigger.
**SCALING > SHARP** zooms by whole numbers only (square pixels, maybe a black border);
**SCALING > FILL** zooms as big as fits. The resolution list lives in `scripts/settings.gd`
→ `COMMON_RESOLUTIONS`; your monitor's own size is always added as the biggest option.)

**Widescreen / ultrawide (ASPECT = WIDE, the default):** the game stays **240 pixels tall** but
gets wider to match the monitor (16:9 → ~427x240, 21:9 ultrawide → ~573x240), so the city fills
the whole screen and you see more to the sides. Same chunky pixels, no black bars. ASPECT = 4:3
puts back exact 320x240 with side bars. How it works:
- `scripts/ui/game_screen.gd` makes the game picture wider (WIDE) or keeps it 320 wide (4:3).
- `PS1Overlay` has the script `scripts/ui/ps1_overlay.gd`: it keeps every menu in a 320-wide
  column in the middle of the screen (they were designed for 320x240), and stretches their dark
  background ColorRects edge to edge. Children named in its **Full Width Children** list (Inspector)
  are skipped: `ColorDepthDither`.
- **The menus get their own layer** (like the HUD): you still edit them in `main.tscn` under
  `PS1Overlay`, laid out for 320x240, but when the game starts `game_screen.gd` moves the whole
  `PS1Overlay` out of the game picture into a layer on top (`MenuView` > `MenuViewport`). Same
  layout and sizes in both UI STYLEs (§13): PS1 = chunky pixels with the CRT over them, MODERN =
  crisp text at your monitor's real resolution, no CRT over them. (The MY CAT
  preview cat is still drawn at PS1 resolution, so it stays blocky.) While the game runs, look for
  them in the Remote tree under `GameScreen/MenuView/MenuViewport/PS1Overlay`.
- The HUD (§13) covers the game picture, whatever its shape; its labels are anchored (select one
  in `scenes/ui/hud.tscn` > Inspector > **Layout > Anchors Preset**). **When you add a HUD label,
  give it an anchor** (top-left, centre-top, etc.) or it will sit at the left on wide screens.
- The PS1 wobble grid in `psx_lit.gdshader` widens with the screen, so the wobble is the same size
  on every monitor.
- Test without an ultrawide: add `--window=1720x720` to a DevCapture run.

### Vertex jitter + affine textures — `shaders/psx_lit.gdshader`
This replaces the normal material on 3D objects. Every mesh in the game already uses it.

To put it on a **new** object:
1. Select the `MeshInstance3D` > Inspector > **Surface Material Override > 0** > **New ShaderMaterial**.
2. Click the new material > **Shader** > Load > `shaders/psx_lit.gdshader`.
3. Expand **Shader Parameters**: set **Albedo Color**, drag a texture into **Albedo Texture**,
   adjust **Uv Scale** (texture repeats).

Knobs: **Snap Resolution** — lower = more wobble (`160x120` default, `80x60` = drunk mode).
**Affine Mapping** — on/off for the texture warp. The player's **PS1 WOBBLE** setting switches
both off for every material at once (via the `psx_wobble` shader global, §10).
**Affine Fade Start / End** (metres) - the warp fades out near the camera (none closer than
Start, full strength past End), so ground right under the camera doesn't bend and slide as you
move. Defaults 3 / 9; raise both to calm it more.

> Tip: affine warping gets extreme on big flat surfaces. PS1 games fixed that by cutting floors
> into many small triangles — the city generator does the same (§7).

### Color-depth + dither overlay — `shaders/psx_post.gdshader`
A **ColorRect overlay** at the end of `PS1Overlay` in `main.tscn`. Everything drawn before it
(the 3D world) gets the PS1 colours and CRT look. The menus and the HUD do NOT: they're drawn
sharp on top of the finished picture (§13). When the game starts, `game_screen.gd` moves
`ColorDepthDither` into a new CanvasLayer called `CRT` inside the game picture (and the menus out
to the sharp layer), so it only covers the city. You still edit it here.

```
PS1Overlay (CanvasLayer)
├── Lobby, PauseMenu, SettingsMenu, CatCreator   <- moved to the sharp menu layer at start
└── ColorDepthDither (ColorRect)  <- Anchors: Full Rect, Mouse > Filter: Ignore
                                     Material: ShaderMaterial with psx_post.gdshader
```

Knobs: **Color Levels** (32 = PS1, 8 = gritty), **Dither Strength** (0 = off), plus the **CRT**
group. To see the game without it, click the eye icon next to `ColorDepthDither`.

---

## 2. The third-person cat controller

### Node tree (`scenes/player.tscn`)
```
Player (CharacterBody3D)            script: cat_player.gd
├── CollisionShape3D                 CapsuleShape3D r=0.3 h=0.9, position y=0.45
├── CatModel                         <- an instance of scenes/cat_model.tscn (the cat's body);
│   │                                   turns to face movement; leans during zoomies
│   ├── Body, Belly, LegL, LegR, Head, EarL, EarR, Muzzle, Nose, EyeL, EyeR, Tail
│   │   (upright "villager" style: big round head, no arms; low-poly spheres/cylinders.
│   │    Colours and hats/shades/collars come from the player's MY CAT look, §11.)
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
- **Gravity + jump** — Space, only when on the floor (catdip adds mid-air jumps, §9). A catdip
  double jump does a **FRONT FLIP** (a Jedi-style somersault, see "Double Jump Flip" below).
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
Network Smoothing) — no code editing needed.

**Running Animation**: the cat's `LegL`/`LegR` (in `scenes/cat_model.tscn`) swing back and forth
while it runs, and its `Tail` sways side to side all the time, faster the faster it runs.
Knobs: Leg Swing (how far), Leg Swing Speed (steps per second at walking speed), Tail Swish
(how far), Tail Idle Speed (sway speed standing still), Tail Speed Per Mps (extra sway speed per
unit of running speed). Other players' cats animate the same way on your screen automatically.

**Double Jump Flip**: one front flip on every mid-air (catdip) jump, spinning around the cat's middle
with its legs tucked. Knobs: Flip Seconds (how long), Flip Turns (1 = one full flip), Flip Pivot
Height (the spin point, metres above the feet), Flip Leg Tuck.

Keys are handled by the **Controls** framework (`scripts/controls.gd`) — players rebind them in
**SETTINGS > KEYS**. See section 10, "Controls & key binding".

---

## 3. The arcade getaway car

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
`main.tscn`). Passengers can't steer: they get the driver's chase view and press **E** again to hop
out on the right-hand side (**Passenger Exit Offset**; each next one **Passenger Exit Spacing** further
back). If the driver gets out, the passengers stay in; one of them can hop out and take the wheel.
Driving onto the exit beam extracts everyone in the car together. In code: the host keeps
`passenger_ids` and tells every computer the whole list (`set_passengers`); anything that asks "is this
player in the car?" uses `has_occupant(id)` (or `Game.car_of(id)`), and `remove_occupant(id)` /
`empty_car()` take cats out. Test: `--add_local=2 --pos=1,0.5,-10 --drive --ride_along=1,2 --ride_exit=1`.

---

## 4. Testing and fixing errors

**Quick check after any change** (press F5):
1. **Start menu** — the neon title over the rainy city; PLAY / SETTINGS / QUIT work, and PLAY
   leads to CHOOSE YOUR CAT, then SOLO / MULTIPLAYER.
2. **PLAY > HOST** — your cat appears down in **THE SEWERS** (the hub). Walk to Don Catleone
   (north end, under the pink sign), press E, pick **SEND ME UP TOP** — you're in the city.
3. **Walk, jump, zoomies** (WASD, Space, Shift) — W always goes where the camera faces.
4. **Car** — walk to the car, E to get in, drive, hold Space while turning to drift, E to get out.
5. **Items** — extract some fish for cash, then buy gear from Comrade Whiskers at the **Black Markitten**
   (west wall of the sewers). Hold Left Mouse to fire, G to drop, Tab for the inventory.
6. **Esc** — pause menu; SETTINGS changes apply immediately; RESUME grabs the mouse again.

**When you see red errors** (bottom panel, **Debugger > Errors** tab, or red text in **Output**):
1. **Read the first one only.** Later errors are usually caused by the first.
2. Note the **file name and line number** (e.g. `cat_player.gd:84`). Double-click the error to jump there.
3. The most common causes in this project:
   - `Node not found: "CameraPivot/SpringArm3D"` → a node was renamed or moved. Names are case-sensitive and must match the trees in this guide exactly.
   - `Invalid action name "sprint"` → the `Controls` autoload is missing; re-add `scripts/controls.gd` in Project Settings > Globals > Autoload with the name `Controls` (keep it at the top of the list).
   - `Identifier "Settings"` / `"Net"` `not declared` → that autoload is missing; re-add it the same way (`scripts/settings.gd` as `Settings`, `scripts/net.gd` as `Net`).
   - `Parse Error` / `Mixed use of tabs and spaces` → copy-paste damage. Godot scripts must indent with **tabs**. Use **Edit > Convert Indent to Tabs** in the script editor.
   - Shader errors (red text in the shader editor, objects turn pink/missing) → the error names the line; send it to me.
   - `Identifier "CatPlayer" not declared` → the editor hasn't scanned scripts yet. Close and reopen the project.
4. **Yellow warnings** are not errors — the game still runs. Ignore them for now.
5. Still stuck? Copy the **full** error text (right-click > Copy Error) plus the file/line it points to and send it to me.

### The test tool (`scripts/dev_capture.gd`)
Lets Claude (or you) run the game from a terminal, do something, print what happened and save a
screenshot, then quit. Run from inside the `Meow-City` folder:

```bash
C:\GoDot\Godot_v4.7.2-stable_win64_console.exe --path . -- --host --capture=shots/test.png --pos=0,0,6 --yaw=0 --pitch=-12
```

- Useful extras: `--deploy` (go up to the city first — without it you're in the hub),
  `--talk` (open Don's talk box), `--drive` (car view), `--grab=fish`, `--hold=shoot`,
  `--cash=500 --talk=ComradeWhiskers --shop_buy=pistol` (the shop screen), `--wait=N`,
  `--goto_dropoff_after=N` (extract), `--menu=settings`, `--scale=2` (smaller image),
  `--mouse_test` (checks mouse-look still reaches the game through the HUD screen),
  `--click_choice=N` (a real mouse click on a talk-box button), `--press_key=Tab` (a real key),
  `--heat=100` (max HEAT: the DEEP CLEAN), `--kill_roombas=3` (destroys 3 VAC-COPs: the MEGA
  VAC-COP is called in; add `--kill_bosses` to destroy bosses too), `--grab=golden_koi`,
  `--roomba=boss --bait_roomba=7` (put the boss 7 m in front of you) or `--zap_roomba=18` (kill it).
  The full list is at the top of `dev_capture.gd`.
- Test runs **use the default settings and never save**, so they can't change your settings or
  cat name. The tool switches itself off in release (exported) builds.

---

## 5. Atmosphere (rainy neon night)

Built to match the references in your *Game Styling* folder: thick haze, glowing light pools in
the dark, flat-shaded low-poly, dithering and a CRT finish.

### Where each effect lives and its main knobs

| Effect | Where | Knobs (Inspector) |
|---|---|---|
| Fog + haze | `main.tscn` > **WorldEnvironment** > Environment > **Fog** / **Volumetric Fog** | Density (higher = thicker). Volumetric fog is what makes light beams visible in the air. (Players can switch volumetric fog off in Settings.) |
| Glow / bloom | WorldEnvironment > Environment > **Glow** | Intensity, Bloom (soft haze over everything), HDR Threshold (lower = more things glow) |
| Darkness level | WorldEnvironment > Environment > **Ambient Light** > Energy | Raise if the city is too dark to play |
| Glowing objects | any material using `psx_lit` > **Emission Color / Emission Energy** | 0 = off, 3-6 = neon |
| Wet street shine | Street material > **Specular / Roughness** | Specular 0 = dry. Roughness lower = sharper reflections |
| Flat shading | any `psx_lit` material > **Flat Shading** | Off = smooth shading |
| Street lamps | `scenes/props/street_lamp.tscn` > **LightCone** | Energy, Spot Range, Spot Angle, color |
| Headlights | `getaway_car.tscn` > Model > **HeadlightBeam** | Energy, Spot Range |
| Rain | `scenes/props/rain.tscn` | **Amount** (drop count), drop size on the mesh, speed in Process Material > Initial Velocity. Hide the Rain node in `main.tscn` to stop it. |
| CRT | `main.tscn` > PS1Overlay > ColorDepthDither > Material > Shader Parameters > **CRT** | Curvature, Chromatic Aberration, Scanline, Vignette, Noise (0 = off). These are the "full strength" values; the player's CRT TV LOOK setting scales them down. |

**About the CRT scanlines:** the whole game (including the CRT overlay) renders at 320x240, so the
scanlines are fat (one per game pixel row) rather than the thin lines of a real TV. That's a
deliberate trade-off to keep the setup simple. Real thin scanlines would mean restructuring the
scene so the CRT runs at full window size. Doable later if you want it.

---

## 6. Multiplayer

The game starts on the **start menu** (PLAY / SETTINGS / QUIT, see §10). **PLAY** goes to
**CHOOSE YOUR CAT** (§11), then **NEXT** to **SOLO / MULTIPLAYER**. **SOLO** starts a game just
for you (no network, nobody can join). **MULTIPLAYER** shows **HOST** (with an optional city #)
and **JOIN** (with the host's address).

**Game mode online:** the **MODE** row on the landing page (CO-OP or TURF WAR, §8 "Game modes")
only counts for the computer that HOSTS. Everyone who joins plays the host's mode: the host sends
it to each computer as it connects, before the city number, so a late joiner gets it too. The
network game list shows **TURF WAR** after a game's name when it's one. (A joiner who wants to
pick a gang for a TURF WAR game sets their own MODE to TURF WAR first, so the gang rows show.)

### Play two cats on one PC
1. In Godot, open the **Debug** menu > **Customize Run Instances...**
2. Tick **Enable Multiple Instances**, set the count to **2**, click OK.
3. Press **F5**. Two game windows open (drag one aside; they start on top of each other).
4. Window 1: **PLAY** > pick a cat > **NEXT** > **MULTIPLAYER** > **HOST**. Window 2: the same
   but pick a **different cat** (both windows share your saved cats, and two windows playing the
   same cat would overwrite each other's cash + stash), leave the address as `127.0.0.1` and
   click **JOIN**.
5. Click into a window to control that cat. Esc opens the pause menu and frees the mouse, so you
   can switch windows.

Each cat gets its own fur colour (host is always ginger) and a name tag over its head.

**Your cat name:** you name your cat on the CHOOSE YOUR CAT screen (up to 12 characters; NEXT
won't let you go on without one). Everyone else sees it floating over your cat.
Either player can drive the car; the other sees it move. Only one cat fits in the car.

*Shortcut:* in the same Customize Run Instances dialog, you can give instance 1 the launch
argument `--host` and instance 2 `--join` to skip the menu (`--name=Whiskers` names the cat,
`--seed=42` picks the city; `--solo` starts a solo game).

### Play with other computers on the same Wi-Fi/network (up to 8 players)
1. Host clicks **PLAY > (cat) NEXT > MULTIPLAYER > HOST**. If Windows asks about the firewall,
   allow **Private networks** (the game uses UDP ports **7777** for playing and **7778** for
   finding games).
2. On the other PCs, click **PLAY > (cat) NEXT > MULTIPLAYER**. Under JOIN, **ON YOUR NETWORK**
   lists every game being hosted nearby, e.g. `WHISKERS  #4242  3/8` (host's cat, city number,
   players). Click it (or pick it with the d-pad + A). A full game says FULL and can't be picked.
3. Not listed (a picky router or firewall)? On the host PC run `ipconfig`, note the **IPv4
   Address** (e.g. `192.168.1.23`), type it into the JOIN box and click **JOIN**.

Up to 8 players in total: e.g. 8 computers, or 2 computers with 4 couch players each (§10).

### Play with a friend in another house (Invite Codes)
No router setup needed on most home internet:
1. The host clicks **HOST** as normal. If Windows asks about the firewall, click **Allow**. The
   game quietly asks the router to open UDP port 7777 (this is called UPnP) and a few seconds later
   shows `ONLINE READY! INVITE CODE: MEOW-499A-21B0`.
2. The host presses **Esc** (or START) and clicks **COPY CODE**, then sends the code to their
   friend by text or Discord. The button says `OPENING ROUTER PORT...` while the router is thinking.
   In split screen it's in player 1's small pause menu.
3. The friend goes to the HOST / JOIN screen, copies the code, clicks **PASTE CODE**, then **JOIN**.
   (Or: pick the box, type the code on the on-screen keyboard, or press Ctrl+V / its PASTE key.
   `MEOW-` and the dashes are optional, and normal IP addresses still work.)

The port closes again when the host leaves the game. The code is the host's internet address in
disguise, so only share it with people you trust, and expect it to change now and then (internet
providers change it). Don't try your own code from your own house: many routers can't do that.
Test it from a phone hotspot or a friend's house.

**If it says `ROUTER WOULD NOT OPEN UP` (the button says COPY LAN CODE):** that code only works on
your own network or VPN. Try these, easiest first:
1. Turn on **UPnP** in your router's settings page (often `192.168.1.1`; the sticker on the router
   has the address and login), then host again.
2. Install **Tailscale** (free) on both PCs and sign in to the same network. The host's code then
   works for the friend, with no router changes. This also solves **CGNAT**, where your internet
   provider shares one address between many homes and no router setting can help. (Mobile hotspots
   and some fibre and rural providers do this.)
3. On the router page, forward UDP port 7777 to the host PC by hand, look up your public address
   (search "what is my IP"), and send that to your friend.

Script side: all of this is in `scripts/net.gd` (`upnp_status`, `room_code`, `ip_to_code`,
`code_to_ip`). Test: `--test-room-code` (headless), `--host --fake_upnp=73.154.33.176` or
`--fake_upnp=off` (test runs never touch the real router), `--join --address=MEOW-7F00-0001`.

### Bigger games get more of everything (balance knobs)
The more players, the busier the city (counted on the host, players on every computer):

| What | Where (select the node in `main.tscn`, Inspector) | Default |
|---|---|---|
| Extra VAC-COPs for every player beyond the 2nd | **Roombas** > Extra Roombas Per Player | 2 (8 players = +12) |
| Heat rises faster per extra cat up top | **Heat** > Heat Per Extra Cat | 0.05 (+5% each) |
| Loot grows back faster per extra player | **Items** > Regrow Faster Per Player | 0.15 (8 players = about 2x) |

The script side: `Game.instance.player_count()` is how many players the game has right now.

### Network traffic (how often positions are sent)
Cats and the car send where they are **30 times a second**, VAC-COPs **20 times** (everyone's
copies glide smoothly in between). To change it: open `scenes/player.tscn` (or
`getaway_car.tscn`, `roomba.tscn`) > select **MultiplayerSynchronizer** > Inspector >
**Replication Interval** (seconds between updates: 0.033 = 30/sec, 0 = every frame).
Measured: a full 8-player game (2 computers x 4) = the host sends about **12 KB/s**; with 8
separate computers about 85 KB/s. Easy for any home network or Wi-Fi.
Second stress test (2026-10-29, after PvP): 8 players on 2 computers x 4, both gangs, heat 80,
both exits open, both main players shooting rivals, a payphone call, mass knockouts: same city,
manholes and gangs on both computers, 59-60 fps, the client received about 25 KB/s, no errors.
It found cats sent home at the same moment from two computers landing on the same spot (one got
shoved metres up into the air): each player now starts looking for a free spot at a different
place (`hub.gd free_spawn_position`).
Stress test (2026-10-29): 8 players on 4 computers (4 + 2 + 1 + 1, both gangs), heat held at 95
(about 38 VAC-COPs incl. 3 MEGA VAC-COPs), everyone up top: the host sent **about 89 KB/s** and
received 19 KB/s; each other computer received **about 29 KB/s**. All 4 game windows (on ONE PC)
held **60 fps**; the host's physics took about 3 ms a frame. Every computer had the same city and
saw all 8 cats with the right gang. A 9th computer was turned away ("That game is full").
Test: `--net_stats=600` prints KB/s sent / received; `--track=150` shows how smoothly other
players' cats move on screen.

### How it works
```
Net (autoload, scripts/net.gd)    <- host(), join(address), leave(); signals joined / join_failed / host_left
Main (Node3D)                     script: game.gd  <- starts games, spawns cats, catches up late joiners
├── Players (Node3D)               <- every cat lives here, named by PLAYER ID ("1" = host's first player)
├── PlayerSpawner (MultiplayerSpawner)   Spawn Path: ../Players, spawnable: player.tscn
├── LobbyCamera (Camera3D)         <- shows the city behind the start menu
└── PS1Overlay > Lobby (Control)   <- the start menu (§10)
```

- **Who controls what:** each computer moves only its own cat and sends the position to others.
  The car is simulated by whoever is driving it (by the host when it's empty). Everyone else's
  copy is frozen and just follows.
- **The host is the referee** for the car, item pickups/drops and fish deliveries, so two cats
  can't grab the same thing and nobody can give themselves cash.
- **If a player quits,** the host empties the car (if they were driving) and drops everything they
  carried where they stood. If the host quits, everyone returns to the start menu.
- **Finding a player's cat in code:** `Game.instance.cat_for(player_id)`, or `Game.instance.my_cat()`
  for your own (first) player, or `Game.instance.local_cats()` for every player on this computer.

### Player IDs (getting ready for split screen)
Split screen means one computer can have up to **4 players** (8 in a whole game). So the game
keeps two numbers apart (`scripts/player_id.gd`, class **PlayerId**):

| | What it means | Example |
|---|---|---|
| **Network ID** | which COMPUTER (Godot hands it out; host = 1) | `771171244` |
| **Player ID** | which PLAYER / CAT: network ID + seat on that computer | `771171244` (first player), `5066138540` (second player on that computer) |

- The **first** player on a computer has a player ID equal to the computer's network ID, so with
  one player per computer nothing looks different from before.
- **Everything per-player uses player IDs:** the cat nodes under Players, cash, HP, quests,
  inventories, stashes, who's driving. Each `request_...` sent to the host says which player it's
  for, and the host checks that player belongs to the computer that asked
  (`PlayerId.sender_owns(id)`), so nobody can move someone else's stuff.
- **Each couch player plays their own saved cat**, with its own cash and stash file (§8, "The stash
  & saved progress"). The couch is fixed for the whole game (no dropping in or out mid-game): a
  computer's players all come in together from the landing page, and leave together when player 1
  quits.
- **In code:** `PlayerId.make(network_id, seat)`, `PlayerId.peer_of(id)` (which computer),
  `PlayerId.slot_of(id)` (which seat, 0-3), `PlayerId.is_local(id)` (on this computer?),
  `PlayerId.first_local()`. A cat knows its own: `cat.player_id`, `cat.slot`.
  `Game.instance.add_local_player(seat, {"name", "look", "cat_id", "team"})` adds a couch player
  when the game starts (`remove_local_player(seat)` is only used by tests now).
- **Controllers:** couch players join with START on their own controller on the landing page,
  BEFORE the game (§10, "Couch co-op"), and each gets their own part of the screen (§13).
  Test them with DevCapture (these test players have no controller, so they stand still):
  `--add_local=1` (one more player joins in), `--as_local=1` (the test actions use that cat:
  `--grab`, `--goto_dropoff_after`, `--bait_roomba`...), `--remove_local=1` (they drop out).
- **Network log:** lines starting with `[Network]` appear in Godot's **Output** panel (joins/leaves).

### Smooth movement (interpolation)
Network updates arrive in bursts, especially over Wi-Fi. Instead of jumping to each update, other
players' cats and the car **glide** toward the latest position every frame.

- Knobs: select the Player (in `player.tscn`) or GetawayCar > Inspector > **Network Smoothing**.
  - **Network Smoothing**: higher = follows more tightly but shows more of the network's jerkiness;
    lower = silkier but trails slightly behind.
  - **Teleport / Snap Distance**: beyond this gap, jump instead of glide (e.g. after exiting a car).
- Measured with a simulated laggy connection (10 updates/sec): raw updates stood still on 126 of
  150 frames and jumped up to 52 cm at once; the cat on screen moved every frame, max 14 cm.

### Joining mid-game (another computer)
(A whole COMPUTER can still join a game in progress over the network, with the players it set
up on its landing page. Couch players can't drop in to a running game: §10.)
A player who joins late gets the city number first, then every **game system** (§16) sends what
it knows: who is driving the car, every item (on the street and in everyone's paws/bags), everyone's
quests, cash and HP, and the heat. Then their cat appears.

### Known limitations (planned for later)
1. **The host is trusted.** Fine for friends; a public game would need anti-cheat checks.
2. **One getaway car per gang** (4 seats each: a driver and 3 passengers), first come, first served.
3. **Your own cat's camera** moves at the physics rate (60/sec). On a 120 Hz+ monitor this can
   look slightly stuttery; Godot's built-in "physics interpolation" setting can fix that later.

---

## 7. Procedurally generated city

`scripts/city_generator.gd` (on the **City** node in `main.tscn`) builds the city from a single
number, the **city seed**. Same number = exact same city.

- **In the lobby:** type a number in the blue **city #** box before HOST to pick a city, or leave
  it blank for a random one. Players who JOIN get the host's city. (The number is no longer
  shown during a game.)
- **Multiplayer:** the host only sends the number; every computer builds the identical city
  itself (the test tool prints a city "fingerprint"; host and joined player always match).
- **What it builds:** a 6x6 grid of blocks with streets between. Each block has 4 lots: a building
  (taller towards downtown, glowing windows, sometimes a rooftop box and a neon sign with coloured
  light) or an empty yard with crates, a dumpster and a junk pile of trash bins and traffic cones
  (real Blockbench models, §20; more stand on some sidewalk corners and by Meow-Mart's door). Street lamps sit at every
  crossroads and halfway along each block. Invisible walls stop you driving off the edge.
- **Always in the same place, whatever the seed:** each gang's **entry manhole** (Catleone
  Family: the south-west corner crossroads, Burrow Gang: the north-east one) and the car, which
  parks near the centre crossroads.
- **The start menu's city** (city #1999, `generate(seed, true)` in `game.gd`) is a showcase:
  Meow-Mart sits on the lot by the centre crossroads and the Catleone car waits outside it, right
  in the menu camera's view. Nothing runs behind the menu (no heat, no VAC-COPs): only the city
  music and the rain play.
- **Points of interest, somewhere different every district:** **Meow-Mart** (a random lot), the
  **exit manhole** and the **payphones** (placed by `fish_heist.gd`, see §8).

**Tuning** (select **City** in `main.tscn`, Inspector): Blocks Per Side (keep it even), Block
Size, Street Width, Min/Max Height, Empty Lot Chance, Neon Chance, Rooftop Chance, plus the
materials. Building looks: the `Mat_building` material's **Texture Glow** controls how bright the
windows are.

**Why walls are cut into pieces:** every generated box is split into ~2.5 m squares
(`WALL_PIECE_SIZE` in `city_generator.gd`). The PS1 texture warp gets extreme on big triangles,
so without this, windows slanted and "swam" when you looked up at buildings. Textures also use
mipmaps (`filter_nearest_mipmap` in `psx_lit.gdshader`), so distant windows don't sparkle.

**Why the ground is a chessboard of tiles:** streets and sidewalks are separate tiles that never
overlap. An earlier version laid sidewalk slabs 2 cm above the street, and the two surfaces
flickered and streaked against each other, especially with the camera low.

**Performance:** lamps and neon lights fade out beyond ~45 m so only nearby ones cost anything.
Tested at a steady 60 fps on an RTX 4060.

---

## 8. The extraction loop: the Sewers hub + Fish Heist

```
THE SEWERS (hub, safe)  --Don sends you up the entry manhole-->  THE CITY (grab fish)
        ^                                                              |
        +--- climb down the EXIT manhole (opens at 60-95 heat; a payphone +
             call to Don tells you where it is)

  HEAT hits 100: the hatch is SEALED, the DEEP CLEAN swarm wipes out anyone still up top,
  and the rebellion moves to a NEW DISTRICT (a new city seed).
```

### Game modes: CO-OP and TURF WAR
Multiplayer games have a **MODE**, picked on the landing page (§10) by player 1 (online: the host):

- **CO-OP (the default):** one crew against OVERCLEAN. Everyone is in the **Catleone Family**
  (Don's sewer); there's no gang to pick. The city has the classic layout: **one** entry manhole
  in the centre crossroads, **one** car beside it, **one** exit. Nothing of the other gang shows
  up: a full Mainframe just says **MAINFRAME FULL** (no hacking), there's no rival live feed in a
  breach, a wipeout never says "... WINS!", and the payphones stop ringing once your crew has
  called. **SOLO** and the **TUTORIAL** are always CO-OP.
- **TURF WAR:** gang against gang, exactly the rules below ("Two gangs, two sewers"). Best with
  4 or more players.

In code: `Game.is_turf_war()` (static, game.gd) is the one place that says which mode the game
in progress is; `Teams.turf_war_pick` is what the landing page's MODE row shows. `Teams.picked(seat)`
is always the Catleone Family outside TURF WAR. (Which controllers belong to whom is a separate
thing: `Seats.coop`, §10.) Quest pages can have **Co-op Lines** that are said instead of Lines in
CO-OP (Sal the Slapper's respect quest uses them: no rivals to rob or slap, so it's just "destroy a
MEGA VAC-COP"). Select a page in an NPC's **Pages** list to see them.

**Test:** `--mode=coop` / `--mode=turf` (the landing page's MODE; `--teams=...` also means TURF
WAR, and `--mode` wins if you give both). Every capture prints
`DevCapture mode: CO-OP cats=["1:0", ...] entries=1 exits=1 manholes=2 cars=[...]` (each cat's
id:gang). E.g. `--host --add_local=1` (couch CO-OP, both gang 0), `--host --teams=0,1 --add_local=1`
(TURF WAR: entries=2 exits=2, two cars).

### Two gangs, two sewers (`scripts/teams.gd`, class **Teams**)
**This is TURF WAR** (above). Two rebellions hide under the city, and each blames the other for
letting OVERCLEAN take over:

| Gang | Boss (sends you up) | Shop | Sewer node in `main.tscn` | Colour |
|---|---|---|---|---|
| **CATLEONE FAMILY** (team 0) | Don Catleone | Comrade Whiskers (Black Markitten) | **Hub**, at (0, -200, 0) | pink |
| **BURROW GANG** (team 1) | **Pawnie** (red beret) | **Clawd** (fedora, sells the same gear) | **GangHub**, at (200, -200, 0) | orange |

- **Picking:** in TURF WAR every player picks a gang for each game on the landing page (P1: the
  **P1 GANG** button; P2-4: **LB / RB**). CO-OP and SOLO always play for the Catleone Family.
  Online, each computer picks for its own players.
- **What a gang does so far:** you start in your gang's sewer, come home to it (extracting or
  knocked out), and use its stash and shop. The two sewers are sealed boxes 200 m apart: you can't
  walk into the other one. Names over heads are in **your gang's colour**; gang-mates get the cyan
  friend health bar, the other gang a red one (and their DOWNED beacon isn't shown to you far
  off / through walls). **Only gang-mates can revive you**: if you're the only one of your gang
  in the game, a knockdown knocks you out straight away.
- **PvP (guns hurt the other gang):** a bolt that hits a cat of the OTHER gang takes the gun's
  damage (pistol 40, Purr-Tommy 25, crits more) and shoves it; the shooter sees the damage number.
  Bolts on your OWN gang do nothing at all (friendly fire is off). Nobody can be hurt in the
  sewers or inside the car. A rival at 0 HP goes **DOWNED** like after a VAC-COP bonk (or straight
  out if nobody in their gang could save them); **shooting a downed rival finishes them off**
  (knocked out: everything they carry spills on the street).
- **Robbing:** walk up to a downed rival who has loot and **HOLD E** for 2 seconds
  (`HOLD: ROB MITTENS` -> `ROBBING MITTENS...`). Their bar fills **red** ("BEING ROBBED!") and they
  see "CLAWD IS ROBBING YOU!". Done: the loot in their backpack goes into yours (what doesn't fit drops on the
  street next to them); they stay downed, so their gang can still pick them up, empty-pawed.
- **The feed** (top-left, under your health bar, every player): `CLAWD DOWNED MITTENS`,
  `CLAWD KNOCKED OUT MITTENS`, `WHISKERS REVIVED MITTENS`, `CLAWD ROBBED MITTENS`,
  `A VAC-COP DOWNED ...`, in the gang colour. Lines fade after 7 seconds.
- **The host referees every shot:** a client only says "I hit that rival for 38". The host
  ignores it unless the two cats are in different gangs, both up top, the target isn't in the
  car, they're within 75 m, and the damage is at most 120.
- **Tuning** (select **Health** in `main.tscn`, group **PvP (the other gang)**): **Rob Seconds**
  (2), **Shots Finish Downed** (on), **Pvp Max Range** (75), **Pvp Max Damage** (120). How hard a
  gun hits is its **Damage** in `scenes/items/pistol.tscn` / `tommy_gun.tscn` (the same number it
  does to VAC-COPs). The feed: **Feed Seconds** / **Feed Lines** on the HUD root in `hud.tscn`.
- **Each gang's own way in and out (phase 4):**
  - **CO-OP and SOLO are different:** one manhole in the centre crossroads, one car beside it,
    one exit (`Game.is_turf_war()` is false). Everything below is TURF WAR.
  - **Entry manholes in opposite corners:** the Catleone Family comes up the **south-west**
    corner crossroads, the Burrow Gang the **north-east** one (`entry_position` in
    `fish_heist.gd`, worked out from the city size so it's always on a street). You pop out a
    few steps up the street towards the middle, facing up it (**Surface Distance** on each hub),
    with your gang's car parked right in front of you (§3).
  - **One exit per gang:** each opens at the heat its gang's Mainframe says (75 by default, §8), somewhere random (at least 60 m from
    every entry and 45 m from each other: **Exit Min Distance** / **Exit Spacing** on the Heist
    node). Each glows in its gang's colour (pink / orange). Only YOUR gang's exit takes you down;
    the rival's is just a hole in the road to you. (Ambush their exit!)
  - **Payphones put you through to YOUR boss:** Don for the Catleones, Pawnie for the Burrow Gang.
    A call shows the exit arrow to the caller's gang only. The phones keep ringing until every
    gang in the game has called. The bosses' phone lines are on the hubs: select **Hub** or
    **GangHub** > **Payphone (the boss on the line)**.
- **Not yet (next PvP phase):** no team scoreboard or end-of-district results, no spawn protection.
- **The story: The Night of the Big Red Button.** Don Catleone ordered OVERCLEAN off a 3 AM
  infomercial, thinking it was a luxury litter-box cleaner. That same night Pawnie & Clawd snuck
  into the Mainframe room on a candlelit date to hotwire it into a bank-vault cracker for
  Meow-Mart. Don's bootleg wiring plus Clawd's elbow on the Big Red Button woke it up, and it
  decided cats cause 99.8% of the city's mess. It locked the fish in Meow-Mart as bait and sent the
  VAC-COPs. Both gangs fled to the sewers with stolen Mainframe terminals and blame each other.
  Ask Don, Pawnie, Clawd, Comrade Whiskers or any quest giver **WHO LET OVERCLEAN IN?** (their
  **blame** page) to hear their side of it.

**The second sewer** is the same `hub.gd` with its own settings: select **GangHub** in `main.tscn`
and look under **Gang** in the Inspector: **Team** (1), **Leader** (Pawnie: whoever sends cats up
and gets the glowing corner), **Shopkeeper** (Clawd: the stall is built around him), **Leader
Glow**, **Boss Name**, and the two lines the boss says when they won't send you up (**Line
Sealed**, **Line Had Your Trip**). Don's **Hub** has the same settings. Their talk is in
`scenes/npcs/pawnie.tscn` and `clawd.tscn` (Pages, like every NPC). Clawd is a Shopkeeper
(`shopkeeper.gd`), like Comrade Whiskers.

**Add a third gang:** add a name and colour to `NAMES` / `COLORS` in `scripts/teams.gd`, then
copy **GangHub** in `main.tscn` (right-click > Duplicate), set its **Team** to 2, move it to
x = 400, and give it its own leader and shopkeeper.

**Test:** `--teams=1` (you play for the Burrow Gang), `--teams=0,1 --add_local=1` (P1 Catleone,
P2 Burrow), `--talk=Pawnie --choose=2` (her side of the story). The `DevCapture cat` lines print
`team=`. PvP:
- `--teams=0,1,1 --add_local=2 --deploy --hold_all --give=pistol --shoot_rival=5` = you shoot the
  nearest rival 5 times: prints `hp=60`, `hp=20`, `downed=true`, then knocked out.
- `--teams=0,0 --add_local=1 ... --shoot_rival=3 --shoot_friend` = shooting your own gang: `hp=100`.
- `--teams=0,1,1 --add_local=2 --deploy --hold_all --down=1 --down_loot=fish,golden_koi --revive=150`
  = you rob a downed rival: `their_bag=[]  our_bag=["fish", "golden_koi"]`.
- Online: a host `--teams=0,0 --add_local=1 --wait=500 --deploy --hold_all --frames=400`, then a
  client `--join --teams=1 --give=pistol --deploy --shoot_rival=5` (a client's `--give` asks the
  host's test tool).

### The underground hub ("THE SEWERS")
Every cat starts here when you HOST or JOIN (Burrow Gang cats in their own copy: see above). It's a sewer tunnel with a murky channel down the
middle, two bridges, work lights, cardboard-box shanties, **The Mainframe** (a giant CRT on the
west wall: feed it SCRAP, see **The Mainframe** in §8) and, at the north end of the west
walkway, the barred **North Breach Tunnel** (see **The Sewer Breach** in §8). The walls are kept clean: the only writing is on The Mainframe and Lil' Mittens'
sign (every NPC still has its name floating over its head). It's a **safe zone**: guns don't fire down here (catnip and catdip still work), except during a **Sewer Breach** (§8).

**Don Catleone** — the boss cat in the fedora with the cigar, at the north end under a pink
glow. Walk up to him and press **E**. The talk box (bottom of the screen) gives five choices:
**SEND ME UP TOP** (you pop out of the Catleones' manhole, the south-west corner), **WHO ARE YOU?**, **WHO LET
OVERCLEAN IN?** (his side of the story: it was Pawnie & Clawd), **HOW DOES THIS WORK?** and
**NEVER MIND** (or Esc).

**Lil' Mittens** — a scrawny grey kitten with huge blue eyes and a "WILL PURR FOR FISH" sign,
by the cardboard shanties on the east wall. Extremely needy. Gives you the **MITTENS' FISH**
quest (see **Quests** below): bring 3 fish down at once for a **$100 bonus**.

**The quest givers:** each sewer has five, in matching spots, and both casts hand out the same five
quests (table under **Quests** below). Move one by selecting them under **Hub** / **GangHub** in
`main.tscn` and changing **Position**.

**Comrade Whiskers** — a one-eyed ginger rebel in a red beret with a bullet bandolier, behind the
counter of **THE BLACK MARKITTEN** ("Purr-oletariat Liberation Front") on the west wall, south of
the breach tunnel. It's **the only place to get gear**: nothing but fish lies around the city any more.
Press **E** on him and **THE BLACK MARKITTEN shop screen** opens straight away (no talk box). It's in
the ocean-blue style, in your own HUD (split screen: everyone shops on their own screen):
```
 [cat + backpack]  PAWS / QUICK USE           ┌ THE BLACK MARKITTEN               $240 ┐
                   BACKPACK 4/6               │ COMRADE WHISKERS: "Take your pick..."  │
                   [SELL $50][SELL $400]      │ [ SELL ALL LOOT (+$450) ]              │
                   [ SCRAP  ][ EMPTY   ]      │ [MELEE] [CONSUMABLES] [FIREARMS]       │
                   "Click: SELL it ..."       │ [pic] PAW-PISTOL  one shot...  BUY $60 │
                                              │ [###] HAIRBALL BLASTER  LOCKED — ...    │
                                              │ what the highlighted thing is          │
```
- **Left half:** your backpack view (§9) in **shop mode**: the camera pushes your cat further left,
  every slot shows its **SELL** price, and **clicking a slot SELLS it** (paws, quick-use and backpack;
  right-click still drops).
- **Right half:** three **tabs** (click them, or **LB / RB**): **MELEE** (Neon Bat, Frozen Tuna),
  **CONSUMABLES** (Catnip, Catdip), **FIREARMS** (Paw-Pistol, Hairball Blaster, Red Dot, Purr-Tommy,
  Yarn-Zooka, Cucumber Launcher). Each row: the item's side-view picture, name, description and
  **BUY $XX**; **click a row to buy**. Guns from a WEAPON CRATE you haven't unlocked show as a **solid
  black silhouette** with "LOCKED — PURCHASE CRATE N AT WORKBENCH"; clicking one only says where to
  unlock it (the crates are on the **TINKER WORKBENCH** now, §25, not on him).
- **SELL ALL LOOT (+$XXX)** sells every piece of street loot in your backpack in one click (scrap and gear stay).
- **Prices** (`ItemManager.sell_price_for`, the host checks every buy and sale):

| Item | He sells it for | He buys it back for |
|---|---|---|
| Sardine / Fish / Gourmet Tuna / Fresh Catch / Catnip Treats / Golden Koi | - | **$20 / $50 / $60 / $75 / $80 / $400** (100%, +20% / +40% with GOURMET FENCE) |
| Neon Bat / Catnip / Catdip / Paw-Pistol / Frozen Tuna | $20 / $25 / $35 / $60 / $80 | half: $10 / $12 / $17 / $30 / $40 |
| Hairball Blaster / Red Dot / Yarn-Zooka / Purr-Tommy / Cucumber Launcher | $120 / $140 / $160 / $200 / $280 | half: $60 / $70 / $80 / $100 / $140 |
| SCRAP | - | never (badge says SCRAP): feed THE MAINFRAME / pay for upgrades |

- **Controller:** the d-pad / stick moves one highlight over BOTH halves (tabs, SELL ALL, rows, your
  backpack); **A** = click, **X** = drop (backpack), **LB / RB** = tabs, **B / Y / Esc / Tab** = leave.
  Your cat can't move while the shop is open; it also closes if you walk away or a menu opens.

- **Change a price:** double-click the item card (e.g. `items/pistol.tres`) > **Shop > Price**.
  Price 0 = not for sale.
- **Change what he sells / the order:** select **Hub > ComradeWhiskers** in `main.tscn` (or open
  `scenes/npcs/comrade_whiskers.tscn`) > Inspector > **Stock** (item ids, top to bottom).
  **Shop Lines** is what he says at the top of the shop screen (`%d` = your cash). Which TAB an item
  is on: select **Shop** in `scenes/ui/hud.tscn` > **Melee / Consumable / Firearm Items** (an item
  must be in his Stock AND on a tab to show). Layout / fonts / the locked silhouette colours: same node.
- **Move the shop:** drag ComradeWhiskers under **Hub**. The counter, shelves, banner and
  lights are built around him by `_build_shop()` in `scripts/hub.gd`, so they follow (he faces
  his root's blue Z arrow; the counter goes on that side).
- **How it works:** he runs `scripts/npcs/shopkeeper.gd` (an NPC whose E opens
  `scripts/ui/shop_screen.gd`, `ShopScreen`, at **HUD > Frame > Shop**). BUY asks the host
  (`ItemManager.request_buy`: price, crate unlock, room, cash); SELL asks `request_sell(player, where,
  index)` / `request_sell_all_loot(player)` (in the sewers only). Messages ("Bought ...", "Sold ...")
  show in the shop's bottom box. Make another shopkeeper: set an NPC's script to `shopkeeper.gd`.
- **Test:** `--cash=500 --give=pistol,fish --talk=ComradeWhiskers --shop_tab=2 --shop_buy=neon_bat
  --shop_sell=hand:0,pack:0 --shop_sell_all --shop_pad=down,left --shop_close=Tab` ("DevCapture shop" lines).

### The Mainframe & scrap
**SCRAP** only comes from a destroyed **MEGA VAC-COP** (it glows cyan on the street, and you grab
it with E). It takes 1 backpack slot and the shop won't buy it: it comes home in your backpack
like all loot. A knockout loses it, like any loot.

**THE MAINFRAME** is the giant CRT on the west wall of your sewer. **Each gang has its own**, with
a charge of 0-100% in 25% steps. A new game starts both at **75%** (charges are not saved between
games). Each sealed district drains **25%** from every gang with at least one player in the game.

With scrap in your bag, walk up to your gang's Mainframe and press E. 1 scrap does one of these:

- **[E] FEED SCRAP (+25%)** when your Mainframe is under 100%.
- **[E] HACK RIVAL MAINFRAME (-25%)** when yours is at 100% and a rival gang in the game is above
  0%. Everyone sees it in the HUD feed.
- **MAINFRAME FULL** at 100% with nobody to hack (solo, one gang, or the rival is at 0%): it refuses,
  so put spare scrap in your stash for later.

Your gang's charge sets when **your** exit opens. The **lowest** charge of any gang in the game sets
how the shared city starts:

| Charge | CRT says | Your exit opens at | City start (lowest gang) |
|---|---|---|---|
| 100% | OVERCLOCK ACTIVE (cyan) | 60 heat | 0 heat, and heat rises 20% slower |
| 75% | SYSTEM ONLINE (green) | 75 heat | 0 heat |
| 50% | POWER LOW (yellow) | 82 heat | 15 heat |
| 25% | WARNING (orange) | 90 heat | 30 heat |
| 0% | CRITICAL (flashing red) | 95 heat | 50 heat, with 1 MEGA VAC-COP already up top |

- Exit timing follows your charge live, so feeding mid-district can open your exit sooner. Once an
  exit has opened it **stays open** for that district, even if a rival hacks you.
- Anything that changes the lowest charge **before anyone goes up** (feeding, hacking) changes the
  current district's start straight away.
- The seal drains just **before** the next district starts, so 100% only reaches OVERCLOCK if you
  top up in the sewers before anyone goes up. Every gang in the game must be at 100% for it.
- If everyone's home, heat only races to the DEEP CLEAN once **every** gang's exit has opened (or
  everyone has used their trip), so an early exit can't rob the other gang of its turn.
- The payphones ring for any gang with an open exit that hasn't called. If it's not your exit yet,
  your boss still says they're digging.

The top-right bar shows **your gang's Mainframe** in the sewers and the **HEAT** up in the city,
with a white **EXIT** tick where your gang's exit opens.

**Where it lives:** `scripts/mainframe.gd` on the **Mainframe** node in `main.tscn` (one node, all
gangs' charges).

**Tuning:** select **Mainframe** in `main.tscn`: **Charge** (Starting Charge, Drain Per District,
Charge Per Scrap, Hack Per Scrap), **Exit Opens At Heat**, **Starting Heat Per Tier**, **Overclock**
(Overclock Heat Multiplier). The scrap card is `items/scrap.tres`. The CRT's feeding spot: **Hub**
and **GangHub** > **Mainframe**. The EXIT tag's size: `hud.tscn` > **Heat** > Exit Tag Size.

**Test it without playing:** `--mainframe=N` sets every gang's charge, `--mainframe=100,50` sets them
per gang (Catleone, Burrow), and the district restarts on it.
`--mainframe=25 --give=scrap --pos=-11,-199.5,0 --press_key=E` feeds one.
`--teams=0,1 --add_local=1 --mainframe=100,75 --give=scrap --pos=-11,-199.5,0 --press_key=E` hacks.
`--teams=0,1 --add_local=1 --mainframe=100,75 --deploy --heat=70` shows one exit open and one shut.
`--to_stash=bag:0` stashes scrap. On a client, add `--wait=120` first.

### The Sewer Breach (a Mainframe at 0%)
When a gang's Mainframe hits **0%** (hacked from 25%, or drained by a sealed district), it gets a
warning and two chances before OVERCLEAN comes for that gang's sewer:

1. **One last raid:** the next district runs at **0% CRITICAL** (50 heat, a MEGA VAC-COP already up
   top to hunt for scrap, exit at 95 heat), and the gang's cats get a `LAST CHANCE` banner.
2. **The siren:** if that district is sealed with the gang still at 0%, then once no cat is left up top
   and knocked-out cats are home, a siren counts down **15 seconds**
   (`FEED THE MAINFRAME! BREACH IN 12s`). The next district waits for it. Run to the stash and the
   Mainframe: feeding scrap in time stops it.
3. **Otherwise, the breach starts:**

- **The tunnel:** the iron **Blast Gate** at the north end of the west walkway slides up, the tunnel
  pulses red, and a horde pours out: **35 bots + 2 MEGA VAC-COPs**. They hunt every cat in that sewer.
- **No safe zone** in that sewer: guns and melee work, nobody heals, and a cat at 0 HP stays where it
  fell. Gang-mates can still revive you. A knockout here **keeps your gear**.
- **Your loot is safe from the horde:** breach bots hit you but don't vacuum your bag, and nothing
  a breach bot does adds to the city's heat. Anything dropped on a sewer floor (a boss's scrap too)
  stays there through new districts.
- **The sewer fights back:** all 7 NPCs in that sewer grab a gun, hop on the spot and spray the room,
  yelling battle cries over their heads. They're terrible shots and do little damage: they thin the
  front line, they don't win it for you. You can't talk to them or shop until it's over. A bot that
  gets within 1.8 m flattens that NPC, who stays on their back until the breach ends.
- **Everything else waits:** the rival boss refuses to send anyone up ("ARE YOU CRAZY?! THEY'RE IN THE
  TUNNEL!"), the Mainframes are locked, the next district and the city's patrol are on hold.
- **The rival gang watches:** their screens switch to the doomed sewer's security camera, with
  `LIVE FEED: BURROW SEWER BREACHED — 24s` on top. Their cats wait at home. If both gangs are at 0%,
  each fights its own horde and nobody watches.
- **Wipeout** (everyone in the sewer down): a banner for 6 seconds (`CATLEONE FAMILY WINS!`, or
  `SEWER BREACHED!` with one gang), then the bots go, the gate shuts, all cats heal, **every**
  Mainframe resets to 75% and a new district starts. If both gangs were breached, the first one wiped
  out loses at once.
- **The 1% Miracle** (someone still standing after 30 seconds): the gate slams, every bot freezes and
  they blow up one after another over 2.5 seconds, the gang's Mainframe reboots to **25%**, everyone
  heals, and a new district follows the banner. (Only a MEGA VAC-COP you actually destroy drops
  scrap, and only a bot you finish yourself counts for quests: the self-destruct pays nothing.)

**Test it without playing:** `--mainframe=25 --heat=100 --heat_hold=30` drains to 0% (a last raid, no
breach). `--mainframe=0 --heat=100 --heat_hold=30 --breach_warning=2 --breach_seconds=3 --breach_log=60`
runs the siren, the breach and the Miracle. Add `--wait=120 --give=scrap --pos=-11,-199.5,0 --press_key=E`
to feed scrap in time.

**Where it lives:** the rules in `scripts/mainframe.gd`, the tunnel, gate and camera in `scripts/hub.gd`
(`_build_breach_tunnel`), the horde in `scripts/roomba_patrol.gd`, the bots' behaviour in
`scripts/roomba.gd` (`breach_hub`), the live feed in `scripts/ui/game_screen.gd`, the NPCs' fighting
in `scripts/npcs/npc.gd`.

**Who carries what** (both sewers; set on each NPC in `main.tscn`):

| Catleone | Burrow | Gun | Shots |
|---|---|---|---|
| Don Catleone | Pawnie | PURR-TOMMY | fast yellow tracers |
| Comrade Whiskers | Clawd | YARN-ZOOKA | pink yarn balls in an arc, then a blast |
| Nonna Catleone | Calamity Clara | CUCUMBER LAUNCHER | green cucumbers: arc, bounce, blast |
| Frankie Espresso | Jittery Jax | THE RED DOT | sweeping red laser |
| Sal the Slapper | Billy the Kitten | HAIRBALL BLASTER | 5 green pellets |
| Paulie "No-Brooms" | Bumper-Car Benny | PAW-PISTOL | yellow shots |
| Lil' Mittens | Gold-Tooth Gus | PAW-PISTOL | slower, wilder yellow shots |

**Tuning (no code):**
- **Mainframe** in `main.tscn` > **Sewer Breach (0%)**: Breach Warning Seconds (the siren), Breach
  Seconds, Breach Banner Seconds, Breach Reboot Charge.
- **Roombas** in `main.tscn` > **SEWER BREACH horde**: Miracle Blast Seconds, Breach Roombas, Breach
  Bosses, Breach Spawns Per Frame. **This is the difficulty knob:** the horde arrives almost at once, so if nobody ever
  survives, lower Breach Roombas first (or Squirt Drone Chance under **Patrol Mix**).
- **Hub** and **GangHub** > **Breach Tunnel** (size, gate speed, red light), **Breach Camera** (where it
  is, what it looks at, how wide), and **Gang** > Line Breach (what the boss shouts).
- **Any sewer NPC** (click them under Hub or GangHub in `main.tscn`) > **Sewer breach**: Breach Weapon
  (a scene name from `scenes/items/`, empty = they don't fight), Breach Cries, Knockdown Cry, Breach
  Damage, Breach Fire Seconds, Breach Color, Breach Pellets, Breach Sweep, Breach Wildness, Breach
  Bounces. **Sewer breach tuning** has their aim, stun, shove, knockdown distance, hop and arc.
  The red lasers do 1 damage instead of 3 because they fire 20 times a second.

**Test it without playing:**
`--mainframe=0 --breach_log=60` starts one (add `--pos=` to stand somewhere).
`--breach_seconds=2` = the Miracle, `--breach_wipe=120` = a wipeout. `--grab_mouse --hold=shoot` fires a held gun.
`--teams=0,1 --add_local=1 --mainframe=75,0` = watching the rival's feed.
`--breach_knock=100` drops a bot beside each NPC (the "DevCapture breach npcs" line counts them).

### The stash (THE LITTERBOX) & saved progress
**THE STASH is a giant glowing LITTERBOX** (purple tray, sand pile, scoop, a cyan neon
**LITTERBOX** sign) on the **east wall**, across from the Black Markitten (north of Lil' Mittens).
Walk up to it: the prompt says **[E] STORE YOUR SHIT**. Press E (or open the inventory with Tab
while standing there) and the inventory opens with your **LITTERBOX** (9 slots) in a box at the
bottom-left, with a callout line to the litterbox.
(In the code and this guide it's still called "the stash": same thing.)
- **Click** something in your paws or backpack = bury it in the litterbox.
- **Click** something in the litterbox = dig it out into your backpack (equip it from there as usual).
- **Anything** goes in: gear, scrap, and loot too (bury fish now, sell them another day).

Everything in the stash is **safe**: a knockout never touches it. Everyone has their own stash.

**Saved between games:** each of your cats has its own **cash** and **stash**, saved on your own
computer. They come back whenever you play that cat again (CHOOSE YOUR CAT), solo or in anyone's
game.
What you're **carrying is not saved**: anything in your paws, quick-use slots or backpack is lost when
you quit (it drops on the floor in that game). So stash your gear before you leave!

**Starting money:** a new cat starts with **$100**, so it can shop before its first trip up (a
Neon Bat is $20, a Paw-Pistol $60). A cat that already existed with less is topped up to $100
**once** (the save remembers it: `starter = true`). Change the amount: select **Profile** in
`main.tscn` > **Starting Cash** (0 = start broke).

- Save files: `%APPDATA%\MeowCity1999\profiles\<cat id>.cfg`, one per cat (the id is a code like
  `cat_1761400000_42`, made when you create the cat; it's in `settings.cfg` next to the name).
  Deleting a cat in CHOOSE YOUR CAT deletes its file too. Two copies of the game on one PC should
  play different cats, or they share one save.
- It saves by itself whenever your cash or stash changes (`scripts/player_profile.gd` on the
  **Profile** node in `main.tscn`).
- In multiplayer, your computer sends your save to the host when you join; the host checks it
  (only real gear, at most 9 items, cash between $0 and $10,000,000) and uses it. Like the rest of
  the game this trusts players, so it's fine between friends but easy to cheat by editing the file.
- **Tuning:** **Stash Size** on the **Items** node. Move the litterbox: select **Hub** (or
  **GangHub**) > Inspector > **Stash** > **Stash Spot** (where you stand; the litterbox is built
  against the east wall next to it) and **Stash Radius** (how close you must be). Same group:
  **Stash Prompt** (the "[E] STORE YOUR SHIT" text), **Litterbox Color**, **Litterbox Glow** (sign,
  neon strip and light) and **Sand Color**. The model is built in code (`_build_stash()` in
  `scripts/hub.gd`).

**Test it without playing:** `--fresh_profile --cash=500 --give=pistol --to_stash=hand:0
--inventory` stashes the pistol (and shows the screen); run again without `--fresh_profile` and
the printout shows `cash={ 1: 500 }` and `"stash": ["pistol"]`. `--from_stash=0` takes it out.
Test runs save to `test_profiles\` instead, so they never touch your real saves.

**Where it lives:**
- The tunnel: `scripts/hub.gd` on the **Hub** node in `main.tscn`. It's built from code when the
  game starts (like the city), but it's always the same — no seed, no randomness. The Hub node sits
  at **position (0, -200, 0)**: 200 m *under* the city. Everything below -100 m counts as "in the
  hub". Going up or down is just moving your cat between the two.
- Don: `scenes/npcs/don_catleone.tscn`, an NPC (see **NPCs** below), placed under **Hub** in
  `main.tscn`. Drag him in the editor to move him (his sign and crates follow next time you play).
- The talk box: **NpcDialog** in the HUD, `scenes/ui/hud.tscn` (`scripts/ui/npc_dialog.gd`, §13),
  drawn sharp at full resolution. The "[E] TALK TO ..." line above it is the HUD's prompt for
  anything usable (§16 "Pressing E").
- NPC names over their heads: each NPC's **NameTag** (Label3D) sets where the name floats and
  its colour (**Modulate**); the HUD draws it sharp (§13). Its text comes from **Npc Name**.

**Change what Don says:** open `scenes/npcs/don_catleone.tscn`, click the root **DonCatleone**,
and in the Inspector open **Pages** (how pages work is just below).

### NPCs: characters you can talk to
Every talking character uses one script, `scripts/npcs/npc.gd`. Their whole conversation is
data in the Inspector — no code needed:

```
Npc Name        "DON CATLEONE"  (also used for the floating name tag and the [E] prompt)
Talk Radius     how close you must be to press E
Voice           their talking voice: a sound name, e.g. "meow_blip_don" (empty = silent)
Pages           the conversation. The first page (that fits) is what they say when you walk up.
  Page          Id      short name, e.g. "about"
                Lines   what they say (put several: one is picked at random)
                Choices the answer buttons. EMPTY = reuse the greeting page's buttons
                Only If Quest / Only If State  (optional) only GREET with this page when that
                        quest is not_started / active / ready (active + objective done) / done
    Choice      Text    button text, e.g. "WHO ARE YOU?"
                Message pops up on the HUD when clicked (optional)
                Action  "send_up_top", "return_to_hub" or "quest:<id>" (optional, see below)
                Go To   Id of the page to show next. EMPTY = close the talk box
Idle Animation  Look At Players, Look Range, Turn Speed, Tail Swish, Tail Speed
```

**Talking voices:** when an NPC talks, their line types itself out in the talk box while
they chatter in little cat syllables, Animal Crossing style (press **A / E / Enter** to show the
whole line at once). Each NPC's **Voice** is a set of 4 sound files, e.g.
`sounds/sfx/meow_blip_don_1.wav` .. `_4.wav` (one is picked at random for every blip). Every NPC
already has their own (Don deep and bossy, Mittens a squeaky kitten, Jax nervous...): the list,
with each cat's pitch and mood, is `tools/sound_specs/npc_voices.json`. A new NPC: ask Claude
for "a voice for my fishmonger, low and grumpy" (the Sound Lab, §20), or reuse another's name.
Payphone calls use your boss's voice too, but they don't use the talk box: the line floats over
the phone and blips once per word from the phone itself (settings on the payphone's **Readout**, §8).
The talk box blips once per word (**Blip Per Word**; untick it for faster, choppier chatter). Typing speed, how often a blip plays, the most blips per line
(**0 = no limit**, the default: they chatter until the line is done) and their volume: `scenes/ui/hud.tscn` > **Frame > NpcDialog** > Inspector > **Talking Voice**.

**Add a new NPC:**
1. In the FileSystem dock, right-click `scenes/npcs/npc_template.tscn` > **Duplicate...** and
   name it (e.g. `fishmonger.tscn`). It's a plain orange alley cat with a 2-page conversation.
2. Double-click it. Click the root node, rename it, and set **Npc Name**.
3. Edit **Pages**: click a page to open it; click **Lines** / **Choices** to edit them. To add a
   page or a choice: click the list's **+ Add Element**, then on the new `<empty>` slot pick
   **New NpcPage** / **New NpcChoice**. (Tip: right-click an existing page > **Duplicate** —
   or **Make Unique** after copying — so edits don't change the original.)
4. Change the look: recolour the meshes under **Model** (select a mesh > Surface Material
   Override > albedo_color), or swap in your own meshes. Keep anything that should face the
   player under **Model**; a node called **Tail** under Model swishes by itself.
5. Place it: open `main.tscn`, drag your .tscn from the FileSystem onto **Hub** (in the sewers)
   or onto the root **Main** node (in the city, then move it to a fixed spot — the city is
   generated, so pick a spot on a pavement near the centre or Meow-Mart). Save and press F5.

**Special actions (needs a little code):** type your own word into a choice's **Action**, e.g.
`give_fish`. Then either attach a script to your NPC that starts with `extends Npc` and add
`func _on_action(action, cat):` (there's an example in the comments at the bottom of `npc.gd`),
or connect the NPC's **action_chosen** signal (Node tab > Signals) to another node.
NPCs aren't networked: every player has their own copy, so an action that changes the shared
game (giving items, spending cash) must ask the host, like the item system does.

**Test it without playing:** `--talk --choose=1,0` walks up to Don, then clicks button 2 and
then button 1 (0 = top) and prints what happens. `--talk=LilMittens` picks another NPC (its node
name).

### Quests
A quest is a job an NPC gives you, with a cash reward. There are five, all repeatable, and both
gangs share the same cards, so rewards are identical in either sewer:

| Quest card (`quests/`) | Objective | Reward | Catleone (`Hub`) | Burrow (`GangHub`) | Spot |
|---|---|---|---|---|---|
| `mittens_fish` | Extract with 3 fish in your bag | $100 | Lil' Mittens | Billy The Kitten | East wall boxes |
| `smash_roombas` | Smash 5 VAC-COPs (gun, melee or car), extract | $150 | Paulie "No-Brooms" | Bumper-Car Benny | South-east walkway |
| `golden_koi_heist` | Extract with a Golden Koi in your bag | $250 + the koi's $400 | Nonna Catleone | "Gold-Tooth" Gus | North-east, near the boss |
| `daredevil_extract` | Extract alive at 85 heat or more | $150 | Frankie "Espresso" | Jittery Jax | South-west crates |
| `gang_disrespect` | Destroy a MEGA VAC-COP, rob a downed rival, or land a melee hit on a rival; extract | $200 | Sal "The Slapper" | Calamity Clara | West walkway by the Mainframe |

**ONE JOB AT A TIME.** You can only have one quest. Talk to another quest giver and accept their
job while you have one, and they refuse: *"You're already on a job for LIL' MITTENS. Finish that
first."* (lines: **Busy Lines** on any NPC, in the Inspector; `{giver}` = who gave your job).
**Your job shows at the top of the INVENTORY screen (Tab):** `JOB: MITTENS' FISH (for LIL' MITTENS)`
then the progress and reward (`FISH in your backpack: 1/3 +$100`, `DONE! EXTRACT TO GET PAID`
when ready). The **ABANDON** button next to it drops the job (press it twice: the first press asks
"SURE?"; progress is lost). Abandoning only works **down in the sewers**, not mid-raid.
Test: `--quest=smash_roombas --talk=LilMittens --choose=0,0` (she refuses), `--quest=smash_roombas
--abandon_quest` (prints both ABANDON presses).

Getting knocked out drops your bag and resets VAC-COP / disrespect counts to 0. Extracting with
part of a count done keeps it for the next trip. Only the cat that lands the killing blow (or the
car's driver) gets a VAC-COP kill. There's only one Golden Koi in each district.

How **MITTENS' FISH** goes, step by step (the others work the same way):
1. Talk to **Lil' Mittens** > **WHAT DO YOU NEED?** > **FINE. THREE FISH.**
2. Go get the fish. (There's no quest tracker on the HUD: open the inventory (Tab), your JOB and
   its progress are at the top.)
3. Climb down the exit manhole with **all 3 fish in your bag at once**: you get the fish's
   normal $150 **plus a $100 bonus** (the popup says `QUEST DONE +$100`). Extract with fewer
   and you just get the fish money — the quest stays active for your next trip.
4. Talk to him again afterwards: he thanks you and offers it again (it's repeatable).
His lines change with the quest (offer / waiting / "you HAVE them, go extract!" / thank you) using
each page's **Only If Quest** settings — open `scenes/npcs/lil_mittens.tscn` to see how.

**Where it lives:** quest cards are `.tres` files in the `quests/` folder (like item cards, loaded
automatically). `scripts/quests/quest_data.gd` is the card; `scripts/quests/quest_manager.gd` on
the **Quests** node in `main.tscn` keeps track of who has which quest. In multiplayer the host
decides (like cash), and every player has their own quests.

**Change a quest:** double-click its card, e.g. `quests/mittens_fish.tres`: **Title**, **Kind**
(the objective type), **Item** + **Count** (what to bring, or how many kills), **Heat Needed**
(`EXTRACT_AT_HEAT` only), **Reward Cash**, **Repeatable**.

**Add a new quest:**
1. In the FileSystem, right-click `quests/mittens_fish.tres` > **Duplicate...**, name it
   (e.g. `don_guns.tres`), and give it a new **Id** (no spaces), Title, Item, Count and Reward.
2. In an NPC's Pages, add a choice whose **Action** is `quest:` + that id, e.g. `quest:don_guns`.
3. Optional: give that NPC pages with **Only If Quest** = your id, so they say different things
   while you're on the quest and after you've done it.

**Kinds of objective:** `CARRY_ITEM`, `DESTROY_ROOMBAS`, `EXTRACT_AT_HEAT` and `DISRESPECT` (listed
at the top of `quest_data.gd`). A new kind would be added in `quest_manager.gd` (`progress()`).

**Test it without playing:** `--talk=LilMittens --choose=0,0 --grab=fish,fish,fish
--goto_dropoff_after=20 --talk_again_after=40` takes the quest, grabs 3 fish, extracts (prints
`quest bonus $100`) and talks to her again. (Add `--heat=80` so the exit is open.)

**Tuning the hub** (select **Hub**): **Size** (Half Width, Half Length, Height, Channel Width),
**Spawning** (Spawn Spot = where cats appear, Surface Spot = where Don sends you in the city),
**Mood** (the sewer fog colour, fog glow and ambient light), **Gang Look** (floor, wall, crate and
water colours, work lights, shop banner and light, and Wood Supports for timber posts and beams).
**GangHub** has its own values: the Burrow's dug-out rust and amber against the Catleones' green.

**The mood switch:** while *your* camera is in a sewer, the moon and rain switch off and the fog
turns that sewer's colour — on your screen only. Go back up and the rainy night city returns.

### Fish Heist: districts, manholes and payphones

**The story:** OVERCLEAN, the AI, runs the city with its VAC-COP Roombas. The cat rebellion hides
in the sewers (eating rats - nobody likes rats). Each raid is on one **district**. Don sends his
cats up **once**; the hatch shuts behind them while his crew digs for a new way back down. Once
everyone's home (or the heat maxes out) he seals that hole for good and the rebellion moves to a
new district. In the code that just means a new city seed: the whole city is generated again.

**How a district plays:**
1. Talk to Don (or Pawnie) > **SEND ME UP TOP**: you climb out of your gang's **entry manhole**
   (Catleones: the south-west corner, Burrow Gang: the north-east). It's **one-way**: there's no
   going back down it.
   **ONE TRIP PER DISTRICT:** once you've been up, Don won't send you again until the next
   district, whether you extracted or got knocked out ("You had your shot up there, kid..."). The
   sewer HUD line says **THE SEWERS - WAIT FOR THE NEXT DISTRICT**. (Who has been up:
   `went_up` in `fish_heist.gd`, decided by the host.)
2. Grab loot. The **HEAT** creeps up the whole time anyone is up top (about **15 minutes** from a
   fresh district to max if you cause no trouble; smashing bots and making a mess speed it up a lot).
3. At **75 heat** (60-95, set by your gang's Mainframe) your crew breaks through: your gang's **exit manhole** opens somewhere random in
   the city (the lid slides off and a glow in the gang's colour comes out of the hole). At the
   same moment every **payphone** in the district starts **ringing** (bell sound, blinking light).
4. Find a payphone (they're scattered on sidewalks; follow the ringing) and press **E** to call
   your boss. No talk box opens and your cat never stops: the boss's line **types out as floating
   text right above the phone** (in their voice, coming out of the phone), and the **green HUD
   arrow switches from PAYPHONE to EXIT for your whole gang** (not the rival's). (Call before 75 and they say there's no
   way down yet: the crew is still digging. No hint where.)
5. Walk (or drive) onto the open manhole: you're back in the hub WITH your loot (it stays in your
   backpack: nothing is sold at the exit). The popup says what it's worth ("3 LOOT HOME ($150)");
   finished quests pay their bonus now. **Sell the loot at the Black Markitten** (Comrade Whiskers /
   Clawd: press E, then SELL ALL LOOT or click single items in your backpack), bury it in the litterbox, or keep it
   for a job. That was your trip for this district.
6. Watch the **HEAT bar** (top-right): a MEGA VAC-COP rolls out at every heat level (start, 25, 50, 75).
   **Everyone home?** Once every cat is back in the hub (extracted or knocked out) and either the
   exit is open or everyone has used their trip, the heat races to 100 (**Heat Per Second When
   All Home** on the Heat node, 5/s) and the DEEP CLEAN skips its 30-second wait, so the next
   district comes quickly.
7. At **100 heat** the hatch is **SEALED** and the **DEEP CLEAN** starts: the MEGA VAC-COP plus a
   swarm of **40 extra VAC-COPs** pour in near anyone still up top and hunt them from 6x further
   away. You can fight, but after **30 seconds** anyone still up there is knocked out no matter
   what (everything they carry is lost). Don won't send anyone up while it's sealed.
8. A few seconds later a **new district** is built (new city, heat back to 0, fresh patrol) and
   Don can send you up again.

**Loot** (press E to pick it up; it goes in your **backpack**: 6 slots for loot AND spare gear,
one slot each. A full backpack can't pick up more loot). "Worth" = what the shop pays:

| Loot | Worth | Slots (old "bag space", not used any more) | Where | Catch |
|---|---|---|---|---|
| **Sardine** | $20 | 1 | 8 on random sidewalks | none: small fry |
| **Fish** | $50 | 1 | 5 outside **Meow-Mart** + 5 on sidewalks | none |
| **Gourmet Tuna** | $60 | 1 | 4 on the shelves **inside Meow-Mart** (§27) | none |
| **Fresh Catch** | $75 | 1 | 3 on Meow-Mart's iced seafood counter (§27) | none |
| **Catnip Treats** | $80 | 1 | 2 on Meow-Mart's shelves (§27) | none |
| **Golden Koi** | **$400** | 2 | ONE, in the tank in **Meow-Mart's back room** (smash it: §27) | **HEAVY** (20% slower), **NOISY** (VAC-COPs spot you from 60% further), grabbing it plays a sound for everyone, and smashing its tank sets off the **STORE ALARM** |

Fish and sardines grow back after 20 seconds, the store's goods after 90-120 seconds. The koi tank
is refilled with the next district. If you drove onto the exit,
the getaway car goes back to its parking spot.

**HUD (kept simple on purpose):** top-left = your **health bar**; top-middle = the **big green 3D
arrow** (below), or `THE SEWERS - SAFE ZONE` in the hub; top-right = everyone's cash,
**only while you're in the sewers**.

**THE GREEN ARROW ("Crazy Taxi" style, `scripts/ui/hud_compass_arrow.gd`):** a chunky bevelled 3D
arrow at the top-middle of every player's screen. It appears the moment **your gang's exit opens**
while you're up in the city:
1. `PAYPHONE  45m`: it points at the **nearest ringing payphone**. Call your boss on it.
2. `EXIT  80m`: once anyone in your gang has made that call, it points at **your exit manhole**.

It turns to match your camera (on foot or driving), so pointing "up" = straight ahead on screen.
From **90 heat** it bobs and pulses faster (the hatch is about to seal); it's hidden in the sewers,
during a Sewer Breach alarm, before your exit opens and once the hatch seals. In the tutorial it
slides down under the tutorial box. It's drawn in code (no extra 3D scene), so four split-screen
arrows cost nothing.
- **Where:** `scenes/ui/hud.tscn` > HUD > Frame > Top > **Compass** (move it like any Control).
  Select it for the knobs: **Arrow Color**, **Edge Color**, **Label Color**, **Arrow Size**,
  **Tilt Degrees** (how much of its top you see), **Thickness**, **Bevel**, **Snap** (PS1 wobble;
  0 = smooth), **Label Font Size**, **Turn Speed**, **Bob Height/Speed**, **Pulse Amount**,
  **Urgent Speed**, **Urgent Pulse**.
- **When it hurries:** **Heist** node in `main.tscn` > Inspector > **The green arrow (HUD)** >
  **Seal Warning At Heat** (90).
- Test: `--host --deploy --heat=80 --capture=shots/arrow.png` (payphone), add
  `--talk=Payphone0 --choose=0` (exit), `--heat=93 --heat_hold=30` (hurrying). The
  `DevCapture compass` line prints what each player's arrow says and where it points.

**Where it lives:**
- `scripts/fish_heist.gd` on the **Heist** node in `main.tscn`: places loot, manholes and
  payphones for each district, referees extraction, runs the seal and the DEEP CLEAN.
- `scripts/manhole.gd`: the manhole itself (built in code). Its two pictures are
  `textures/manhole_closed.png` and `textures/manhole_open.png` - repaint them in any paint
  program (keep them square, round art in the middle).
- `scenes/props/payphone.tscn` + `scripts/npcs/payphone.gd`: the payphone, an NPC you **USE**.
  What the boss says lives on the boss's sewer: select **Hub** (Don) or **GangHub** (Pawnie) in
  `main.tscn` > Inspector > **Payphone (the boss on the line)**: **Phone Too Early**, **Phone Exit
  Open**, **Phone Sealed** (short one-liners read best floating in the street; `{where}` still
  becomes e.g. "north-east" if you write it). The words appear on the payphone's **Readout** child
  (a Label3D with `scripts/ui/floating_line.gd`): select it to change **Letters Per Second**, **Hold
  Seconds** (how long it stays after typing), **Wrap At** (letters per line) and **Readable From**
  (metres). The payphone root's **Line Color** is the text colour. The ring is `sounds/sfx/phone_ring.wav`.
- `Game.new_district()` in `scripts/game.gd`: builds the next district.
- Loot items (§9): `items/sardine.tres`, `items/fish.tres`, `items/golden_koi.tres`. Where
  they lie and how many: the loot table `loot/city.tres` (§9 "The loot table").

**Tuning:**
- Select **Heist** in `main.tscn`:
  - **Manholes**: Exit Opens At Heat (75), Seal Warning At Heat (90), Exit Radius (how close you
    must get), Exit Min Distance (from the centre).
  - **Payphones**: Payphones (how many), Payphone Spacing, Payphone Min Distance.
  - **The DEEP CLEAN**: Deep Clean Seconds (30), New District Delay.
- Select **Roombas** > **DEEP CLEAN swarm**: Deep Clean Roombas (40, how many swarm in), Swarm
  Min/Max Distance (how close to you they appear), Swarm Sight Multiplier.
- How long a district lasts: **Heat** > Heat Per Second (see **HEAT** below).
- What loot pays, how heavy / noisy it is: open its card in `items/` (see §9, **Loot settings**).
- How much you can carry: **Bag Size** on the **Items** node.

**Test it without playing:**
- `--deploy --heat=80 --heat_hold=400 --talk=Payphone0` calls Don on the first payphone (prints
  `DevCapture payphone: ... line="..." talk box open=false` and then `revealed=true`).
  `--host --heat=80 --talk=Payphone0 --pitch=-8 --frames=100 --capture=shots/payphone_readout.png`
  photographs the floating line over the phone.
- `--deploy --heat=80 --heat_hold=600 --near_exit=6 --hold=move_forward --hold_frames=120` walks
  onto the open exit (prints `extracted`).
- `--deploy --heat=100 --heat_hold=30 --frames=4800` runs a whole DEEP CLEAN and prints
  `[Game] New district: city #...`.

**Multiplayer:** the host referees every pickup and extraction. Loot, manholes and payphones come
from the city number, so every computer places them identically. A payphone call asks the host,
who switches the arrow on for everyone; the host also decides when the hatch is sealed and when
the next district starts (it sends the new city number to everyone). The hub and Don aren't
networked at all: everyone's computer builds the same tunnel, and talking to Don only moves
*your* cat. A player who leaves takes their cash with them (their carried fish drop where they
stood).

**Items stay on their own level:** a cat can only grab things within 3 m above or below it
(`MAX_REACH_HEIGHT` in `item_manager.gd`), and something dropped in the sewers stays in the
sewers. (Before, a cat standing in the hub could pick up fish lying in the city right above it.)

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
chases, and it's a **weak spot**: see "Shoot the EYE" below.

**Shoot the EYE = guaranteed CRIT.** On every bot (VAC-COP, MEGA VAC-COP, LINT-TRAPPER, SQUIRT-DRONE)
a bolt into the glowing eye is ALWAYS a critical hit: double damage (or the gun's own Crit
Multiplier if that's bigger), the big yellow CRIT number and a white-hot flash of the visor (no
extra sound: **Eye Crit Sound** is empty; type a `sfx/` file name there to give it one). Shots into the back of the body don't count, and
explosions (the YARN-ZOOKA's blast) never do. Tuning: select the bot's root node > Inspector >
**Eye Weak Spot**: **Eye Crit Radius** (how close to the eye's middle counts, metres; grows with
the model's scale, so the MEGA VAC-COP's eye is a bigger target), **Eye Crit Multiplier**, **Eye
Path** and **Eye Crit Sound**. Test: `--host --eye_test [--roomba=boss|drone|trapper]` prints one
eye shot and one body shot ("DevCapture eye_test" lines: the eye one says crit=true).

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
sirens and a glowing lens on its nose. Both eyes are **weak spots** (always a crit, see VAC-COPs
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

Every 25 heat is one **HEAT LEVEL** (an alarm sound). The HUD shows the heat as a bar in the TOP-RIGHT, a mirror image
of your health bar (number box on the right, 0-100), flashing RED and BLUE like police lights - faster
at each level, with a white flash on the frame when a level goes up. Tick marks show 25/50/75 (75 = the
exit opens). It's **Frame > Top > Heat** in `scenes/ui/hud.tscn` (script `scripts/ui/hud_heat_bar.gd`):
select it and change the two colours, flash speed and smoothness in the Inspector. Each level above 1 brings
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

### Health, downed cats, revives & knockouts (the risk in "extraction")
Every cat has **100 HP**, shown as the **health bar** top-left under your cash and loot (see
**Health bars & damage numbers** below). Each VAC-COP bonk takes 34, the MEGA VAC-COP's 67.

**At 0 HP you're DOWNED first, not out** (when there's a teammate who could save you):
- You flop on your side but **keep everything you carry**. You can only **crawl** (slowly) and
  **meow** for help. VAC-COPs leave you alone. Your screen says `DOWNED! 25` and counts down.
- Over your head a cyan **DOWNED** bar drains as you bleed out. Teammates can see it **from far
  away and through walls** (there's no "IS DOWN!" message: the bar is how they find you).
- A teammate walks up and **HOLDS E** (Pad X) for **3 seconds** (prompt: `REVIVING MITTENS...`).
  The **revive meter** fills your health bar in **green**: the bar over your head on their
  screen, and your own bar top-left (it says **REVIVING**).
  Your bleed-out clock stops while they do. Letting go or walking off cancels it. Done: you're
  back up with **35 HP** and all your loot ("MITTENS picked you up.").
- Nobody comes in **25 seconds**, or you **hold E for 1.5 s to give up**: you're knocked out (below).
- **Playing solo, or everyone else is down too?** Nobody could come, so there's no waiting: you're
  knocked out straight away.
- The **DEEP CLEAN** (max heat) knocks out everyone still up top at once, downed or not.

**KNOCKED OUT**:
1. **Everything you carry drops on the street where you fell**: the gear in your paws, your
   quick-use snacks and everything in your backpack (fish included). Anyone can grab it: you on your next trip up, a
   friend, or a rival.
2. Your cat flops over on its side for 3 seconds ("KNOCKED OUT BY A VAC-COP!"). You can look
   around but not move. Roombas leave knocked-out cats alone, and you can't extract while down.
3. You wake up back in **the sewers**, with empty paws.

**Healing:** back in the sewers you're healed to full straight away (after extracting or after
a knockout). Cats in the car and in the hub can't be hurt. Your cash and quests are never lost.

So gear you take up top is at risk every time. Gear left in **the stash** (below) is safe.

**Where it lives:** `scripts/cat_health.gd` on the **Health** node in `main.tscn`; the health bar
is **Frame > Top > Health** in `scenes/ui/hud.tscn` (script `scripts/ui/hud_health_bar.gd`, §13). The fall-over is `knocked_out` in `cat_player.gd`.
A downed cat is something teammates "use" with E (§16 **Pressing E**): `cat_player.gd` answers the
E questions and hands them to `cat_health.gd`, where all the revive rules are.

**Tuning** (select **Health** in `main.tscn`): **Max Health**, **Knockout Seconds** (how long
you lie there). Under **Downed and Revives**: **Bleed Out Seconds** (25), **Revive Seconds** (how
long to hold, 3), **Revive Radius** / **Revive Slack** (how close you must be / how far you may
drift while holding), **Revive Health** (35), **Crawl Speed** (0.25 = a quarter of walking, 0 = no
crawling), **Give Up Seconds** (1.5), **Downed Seen From** (how far the DOWNED bar shows, 150 m).
How much a bonk hurts: **Bonk Damage** on the Roomba (above).

**Something new that hurts cats** (a trap, a guard dog...): on the host, call
`CatHealth.instance.damage(player_id, 20, "A GUARD DOG")`. The last part is shown on the
knocked-out screen. Add `, true` at the end to skip the downed stage (straight to knocked out).
Guns hurt cats of the OTHER gang only (PvP: see "Two gangs" above).

**Multiplayer:** the host decides all damage, downs, revives and knockouts and tells everyone,
like cash. The reviver's computer only asks the host ("I'm holding E on Mittens").

**Test downed / revive without playing** (the cat in slot S goes down 1.5 m in front of you):
- `--host --add_local=1 --deploy --down=1 --revive=200` = couch player 2 goes down, you hold E on
  them: prints `REVIVING COUCH 2...`, then `hp=35 downed=false` (`--revive_snap=shots/x.png` saves a
  picture mid-revive). (`--revive=60` = let go
  too early: still downed.)
- `--down=1 --bleed_out=2 --frames=240` = nobody helps: `was knocked out` after 2 s.
- `--down=0 --add_local=1 --hold=interact --hold_frames=120` = you go down and give up.
- `--down=0` with no `--add_local` = solo: knocked out straight away.
- Online: a `--host --wait=400 --deploy --down=0 --frames=500` window, then a
  `--join --deploy --revive=220` one: the client walks to the downed host cat and revives it.

**Test it without playing:** `--give=pistol,catnip --pos=-12,0,-6.5 --yaw=180 --bait_roomba=3
--frames=1500` gives you gear, grabs the fish at Meow-Mart, lets a VAC-COP beat you up and
prints `[Health] Player 1 was knocked out`; afterwards the pistol and catnip are on the street
and your cat is back in the hub with `hp=100`.

### Health bars & damage numbers (Cyberpunk-style, all drawn on the HUD)
Everything here is drawn by the HUD layer (§13: chunky with UI STYLE = PS1, crisp with MODERN).

- **Your health bar** (top-left corner): a number box (`87`) and a thin, plain red bar. When you're hurt the bit you lost turns **white-yellow** and drains away after a
  moment, so you can see how big the hit was; healing fills back in **cyan**. Under 30% the bar
  pulses; at 0 it says **DOWNED** (while a friend can still revive you), then **KNOCKED OUT**.
- **A downed teammate** gets a cyan bar that drains as they bleed out, with `DOWNED 18` (or
  `REVIVING...`) over it, seen from far away and through walls. While someone revives them, a
  **green revive meter** fills the bar (your own bar top-left fills the same way when it's you).
  Any bar can do this: give `health_bar_info()` the extra keys `"see_from": 150.0`,
  `"through_walls": true` and `"progress": 0.5` (0..1). The green is **Revive Color** on both
  **Frame > Bars** and **Frame > Top > Health** in `hud.tscn`.
  Tuning: open `scenes/ui/hud.tscn`, select **Frame > Top > Health**: **Colours** (Fill, Chip,
  Heal, Back, Frame), **Shape** (Bar Thickness, Number Box Width, Number Font Size), **Feel** (Chip Delay, Drain Speed, Low Health). Move / resize it with **Layout >
  Transform**.
- **Enemy health bars** float over a VAC-COP only once a player has shot it: its name (`VAC-COP`) over a
  thin plain red bar, with the same white-yellow chip. They shrink with distance, fade out far
  away and hide behind walls. The **MEGA VAC-COP** gets the same floating bar, just **twice as big**
  (Boss Size) with a gold name, and visible from further away (Boss Distance, 60 m).
- **Other players' cats** get a slim **cyan** bar under their name once they're hurt (handy in co-op).
  Tuning: select **Frame > Bars**: Max Distance, Fade Distance, World Width, Min / Max Width, Bar
  Height, Name Font Size, **Boss Distance / Boss Size**, Chip Delay, Drain
  Speed, Hide Behind Walls, and the **Colours** (Friend Color = other cats' bars).
- **Damage numbers:** every bolt that hits a VAC-COP pops its damage off the spot you hit
  (white, e.g. `27`), floating up and fading. **Critical hits** are bigger and yellow with a `!`
  (`84!`). Only the shooter sees their own numbers (on their own screen in split screen).
  Tuning: select **Frame > Damage**: Lifetime, Rise, Spread, Font Size, Crit Font Size, Color,
  Crit Color.
- **How much a gun does** is on the gun scene's root (e.g. `scenes/items/pistol.tscn`) under
  **Hits**: **Damage** (pistol 40, tommy gun 25), **Damage Wobble** (0.1 = each bolt is up to 10%
  more or less), **Crit Chance** (pistol 0.15, tommy 0.08), **Crit Multiplier** (2 = double).
  Guns still don't hurt other cats (they just shove them).
- **Give something new a health bar** (e.g. a guard dog): if it's an enemy (§16, `extends Enemy`)
  it already has one. Anything else: add its root node to the group `hud_health_bars` (**Node**
  dock > **Groups**) and give its script a `health_bar_info()` function: copy the one in
  `scripts/enemy.gd` and change the numbers. The talking NPCs in the
  hub (Don, Whiskers, Mittens) don't have one: they live in the safe zone and can't be hurt.

**Multiplayer:** the shooter's computer rolls each bolt's damage (so the number you see is the
number taken off) and the host takes it off the VAC-COP; the Roomba's health is copied to every
player by its MultiplayerSynchronizer, so everyone's bars match (late joiners too).

**Test it without playing:** `--give=tommy_gun --pos=-12,0,-6.5 --yaw=180 --pitch=-10
--bait_roomba=aim --hold=shoot --hold_delay=60 --hold_frames=4 --frames=75` parks a VAC-COP in
your sights and fires a short burst (bar + numbers on the screenshot). For the boss bar:
`--heat=100 --roomba=boss --give=pistol --pos=-12,0,-6.5 --yaw=180 --bait_roomba=7 --zap_roomba=4 --frames=110`.

---

## 9. Items & weapons

Every item — fish, the tommy gun, pistols, catnip, catdip, anything you add — goes through one
system, so new items need no new networking or pickup code.

### How players use items
- **Paws:** a cat has a right and left paw. A **1-paw** item (pistol, catnip, catdip) uses one,
  so you can hold two at once (dual wield). A **2-paw** item (the tommy gun) takes both.
  **Left Mouse** uses the right-paw item (or the 2-paw item), **Right Mouse** the left-paw item.
- **BACKPACK (one for everything):** 6 slots (8 / 10 / 12 with BIGGER BACKPACK) for loot (fish,
  koi, scrap) AND gear you aren't holding. Every item takes one slot, EXCEPT consumables (catnip,
  catdip: anything with **Quick Use** ticked), which stack in the backpack like in a QUICK USE slot
  (same size: **Quick Stack Size** + STUFFED CHEEKS; the slot shows "x3"). When both quick slots are
  full, extra catnip goes into the backpack (not your paws). Clicking a stack moves / sells / drops /
  buries ONE of it. (Code: `ItemManager.pack_stacks` / `pack_has_room`.) Your cat WEARS it: a chunky
  purple backpack (`models/cat_backpack.glb`, recipe `tools/make_backpack_spec.py`) whose light
  strip goes cyan (empty) -> amber -> red (full), so you can see who's carrying a haul.
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
| **Scrap** | loot | dropped by a destroyed MEGA VAC-COP | $0, stays in your bag at the exit; feed it to The Mainframe (§8) |

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

---

## 10. Start menu, pause menu and Settings

### What the player sees
- **Start menu:** big flickering CYPURRPUNK title over the rainy city (the camera slowly pans),
  then **PLAY / SETTINGS / QUIT**. The way through:
  ```
  PLAY  ->  SOLO / MULTIPLAYER / TUTORIAL
              SOLO  ->  CHOOSE YOUR CAT (pick / make / name / dress a cat, §11) -- NEXT --> a game just for you
              TUTORIAL  ->  straight into a guided training run with the cat you have now (§19)
              MULTIPLAYER  ->  LOCAL CO-OP / ONLINE CO-OP
                                 -> the LANDING PAGE: everyone on this computer joins and picks a cat,
                                    player 1 picks the MODE (CO-OP or TURF WAR)
                                      LOCAL:  START GAME = everyone into the sewers together
                                      ONLINE: NEXT -> HOST (+ city #) or JOIN (a game on your network)
  ```
  The landing page:
  ```
  [<] P1  WHISKERS [>]       <- player 1: A on < / > = pick your cat, A on the name = make / edit cats
  [<] MODE: CO-OP [>]        <- player 1 only: A on <, > or the name = switch CO-OP <-> TURF WAR
                                (§8 "Game modes"). Online it says (HOST'S CHOICE): only the host's counts.
  [P1 GANG: CATLEONE FAMILY] <- TURF WAR only: player 1: A = switch gang (§8 "Two gangs")
  P2  < MITTENS >  BURROW GANG <- a friend pressed START on their controller; left / right = their cat
                                (players 2-4 have no highlight on this page, so their stick picks),
                                LB / RB = their gang (TURF WAR only), A = edit it (MY CAT), B = leave
  P3   PRESS START TO JOIN
  P4   PRESS START TO JOIN
  [START GAME]  [BACK]       (ONLINE CO-OP: [NEXT])
  ```
  **BACK** (or **Esc**) always goes one step back. The game version shows bottom-left.
  Moving the highlight (stick, d-pad, arrow keys) never changes a value: only **A** / Enter / a click
  does. The up / down paths between the rows are set by hand in `main_menu.gd` `_link_landing_focus`
  (the gang row comes and goes with the mode).
- **Pause menu (Esc, or START on a controller, in a game):** RESUME / MY CAT (restyle or rename the cat you're playing) /
  SETTINGS / LEAVE GAME / QUIT TO DESKTOP (in a tutorial, LEAVE GAME says **EXIT TUTORIAL**). The game does
  **not** stop (it's online) — your cat just stands still and the car rolls to a stop while it's
  open. LEAVE GAME goes back to the start menu; if the host leaves, everyone does.
- **Settings:** five tabs. Click **<** / **>** to change a value; hover a row for a one-line
  explanation at the bottom. Changes apply instantly and are saved. **RESET** = defaults.
  **Esc** = back.
- **No key list on screen during play** — the keys live in **SETTINGS > KEYS**, and prompts
  ("[E] TALK TO...", "[E] PICKUP" by items, "TAB: close" in the inventory) always show the
  player's *current* key. The city number is shown in the pause menu.
- **Controllers** (Xbox, PlayStation, Switch Pro... anything Windows sees) work everywhere,
  including every menu. Whatever the player touched last decides what the prompts show: touch the
  controller and "[E] TALK" becomes "[X] TALK" (PlayStation pads show SQUARE, CROSS, L2...).
  See "Playing with a controller" below.

| Tab | Settings |
|---|---|
| DISPLAY | Screen (window/fullscreen = monitor's max resolution), resolution (window sizes that fit your monitor, biggest = its max), scaling (SHARP = even pixels / FILL = as big as fits), aspect (WIDE = fill wide/ultrawide monitors, still 240 tall / 4:3), VSync, 2-player split (side by side / top + bottom), field of view |
| SOUND | Master, music, sound FX volume |
| CONTROLS | Mouse speed, invert mouse Y, stick speed (right-stick camera), invert stick Y, rumble on/off |
| KEYS | Every control with two keyboard/mouse boxes + a **PAD** (controller) box (scrolls). **RESET KEYS** = default keys and buttons |
| EFFECTS | CRT TV look (0-100%), PS1 wobble on/off, volumetric fog on/off |

Saved to `%APPDATA%\MeowCity1999\settings.cfg` (with your cats: names and looks) and
`controls.cfg` (keys). RESET in Settings never touches your cats.
Delete those files to get a fresh start.

### Playing with a controller
Just plug it in (or pair it) and press a button: no setting needed.

| On foot | | In the car | |
|---|---|---|---|
| Left stick | walk (analog: half push = half speed) | Left stick | steer |
| Right stick | camera | RT / LT | gas / brake + reverse (analog) |
| | | Right stick | look around (swings back when you drive on) |
| A | jump | Left stick up/down | gas / brake too |
| L3 (click left stick) | zoomies | RB | handbrake |
| X | grab / talk / car | X | get out |
| RT / LT | use right / left paw (shoot) | | |
| Y | inventory | | |
| B | meow | | |
| D-pad down | drop | | |
| START | pause menu | | |

**In every menu:** d-pad or left stick = move the highlight (the stick moves ONE step per push:
let it go back to the middle to move again), **A** = press, **B** = back,
**START** = pause / unpause. **The d-pad / stick NEVER change a value by themselves**: on a
"NAME  <  VALUE  >" row, left / right only move the highlight between its **<** and **>**, and
**A** on one changes the value (SETTINGS, CHOOSE YOUR CAT, a player's own split-screen pause,
P1's row on the landing page). In SETTINGS, **LB / RB** switch tabs. In the inventory, **A** =
what a left-click does, **X** = drop, **B** or **Y** = close.

**Typing with a controller - the ON-SCREEN KEYBOARD** (`scripts/ui/on_screen_keyboard.gd`):
the cat name box (CHOOSE YOUR CAT) and the **city #** / address boxes (ONLINE screen) are
buttons: **A** (or Enter / a click) on one opens a little keyboard. D-pad / stick = pick a key,
**A** = type it, **B** = delete a letter, **START** (or DONE) = finished. A real keyboard types
straight into it too (Backspace deletes, Enter = done). NEW (a new cat) and NEXT without a name
open it by themselves. To use it on another text box in code:
`OnScreenKeyboard.hook(my_line_edit, my_menu)` (add `, OnScreenKeyboard.DIGITS` for numbers only);
the letters on each layout are the `LETTERS` / `DIGITS` / `ADDRESS` lists at the top of that script.
(Why buttons and not normal text boxes? Godot 4.7 never lets the d-pad highlight a text box.)

Rumble: getting hit, getting knocked out, every shot, extracting. Turn it off in
SETTINGS > CONTROLS > RUMBLE. To change how strong one is, find `Controls.rumble(` in the script
(`cat_health.gd`, `items/weapon.gd`, `fish_heist.gd`): the numbers are light motor, heavy motor
(0 to 1) and seconds. Right-stick turning speed: select a cat in `scenes/player.tscn` >
Inspector > **Camera** > **Stick Turn Speed** (and **Stick Pitch Ratio** for up/down); players
fine-tune it with STICK SPEED. Stick drift (cat creeps along by itself)? Raise
**STICK_DEADZONE** at the top of `scripts/controls.gd`.

### Couch co-op: more players on one computer (`scripts/seats.gd`, Autoload **Seats**)
Up to **4 players per computer**, each with their own controller (8 in a whole game).

- **The landing page (start menu > PLAY > MULTIPLAYER > LOCAL CO-OP or ONLINE CO-OP):** this is
  where everyone gathers BEFORE anyone goes down into the sewers. Friends press **START** on their
  controllers to take a seat (P2, P3, P4, in their player colour). Each picks a cat with
  **left / right** on their own controller: one of your saved cats (MY CAT) that nobody else
  picked, or NEW CAT (made when the game starts, called "PLAYER 3" etc.). **A** = edit their cat
  in MY CAT (colours, hat, shades...; a NEW CAT is made right then so there's one to dress); only
  their controller drives that screen, DONE or B comes back. **LB / RB** = switch their gang
  (TURF WAR only).
  **Been using a controller in the menus yourself?** It's player 1's then, so its START can't
  "join" like a spare one... except here: on the landing page, **START on player 1's controller
  hands it to a new player** (P2 sits down on it) and player 1 carries on with the keyboard +
  mouse. (The landing page shows a reminder line while player 1 has a controller.)
  **B** = stand up again. Player 1 picks their own cat on the P1 row (left /
  right), or presses A on it to make / edit cats, picks the **MODE** (CO-OP / TURF WAR), and in
  TURF WAR switches gang on the **P1 GANG** button.
  Their controllers don't move player 1's menu.
  LOCAL CO-OP: **START GAME** puts everyone in the sewers. ONLINE CO-OP: **NEXT** goes to HOST /
  JOIN, and everyone comes along into that game. Leaving the landing page (BACK) stands everyone
  up. Two players never play the same cat: each cat has its own cash and stash.
- **No drop-in / drop-out during a game:** everyone sits down on the landing page (where they
  also pick their gang), and the couch stays the same until player 1 leaves the game. START on a
  spare controller mid-game does nothing, EXCEPT when someone's controller is unplugged: then it
  takes over that player's seat (below). In a SOLO game every controller is player 1's.
- **Full games:** a game holds 8 players. A couch player who doesn't fit is told "THE GAME IS
  FULL"; a whole computer that doesn't fit goes back to the start menu with "That game is full."
- **Pausing (each player their own):** with 2+ players, **START** (Esc for player 1) opens a small
  pause menu on YOUR screen only: your cat stops, everyone else keeps playing.
  Everyone's has **MY CAT**: restyle (colours, hat, shades...) the cat THEY play. It takes the
  whole screen while open and only that player's controller drives it; DONE (or B) goes back to
  their pause menu. Player 1's also has SETTINGS (the big pause menu: settings are shared) /
  LEAVE GAME / QUIT TO DESKTOP. Players 2-4's have no leave button (no dropping out).
  Player 1's LEAVE GAME ends the game for this whole computer. Alone, START opens the normal
  big pause menu as always. (`scripts/ui/player_pause.gd`, in every player's HUD.)
- **Each player's own controller settings:** in their pause menu, **STICK SPEED**, **INVERT
  STICK Y** and **RUMBLE** (A on a row's **<** or **>** changes them). A couch player's are saved with the cat
  they play, so they follow that player next time; player 1's are the same ones as SETTINGS >
  CONTROLS.
- **Player colours:** P1 pink, P2 cyan, P3 yellow, P4 green: each player's pause menu title and
  their row on the landing page. (Split screens have no frame or "P2" tag: just a thin black
  line between them, **Divider** below.) Change the colours in `scripts/seats.gd` > **SEAT_COLORS**.
- **Unplugged controller (or flat battery):** that player's game pauses ("CONTROLLER UNPLUGGED")
  and only theirs; plug it back in and it carries on by itself. Lost it for good? Press START on
  any free controller: it takes over that player's seat (same cat, same stuff). Playing alone,
  the normal pause menu opens.
- **Player 1 owns the computer:** player 1 always has the keyboard + mouse, and the first
  controller they touch in the start menu becomes theirs for the session (until they go back to
  the title screen). Every other player has exactly one controller. A controller without a seat
  can't press player 1's buttons: on the landing page and in a co-op game it only does something
  when its START is pressed (= join). Player 1's button prompts ("[E]" or "[X]") and rumble follow
  only player 1's own keyboard / controller, never someone else's. In a SOLO game there's only
  player 1, so every controller drives them. (Want to switch player 1 to a different controller?
  Go back to the title screen and use it there.)
- **Each player's buttons are their own:** their stick walks their cat, their A jumps it, their
  RT fires their gun, their Y opens the inventory with THEIR stuff in it, their rumble.
  The keys/buttons are the same for everyone (SETTINGS > KEYS, PAD column).
- **Split screen:** every player gets their own part of the screen (§13, "How the screen is put
  together").
- **Their own HUD:** every player has their own cash, loot, HP, extraction arrow, prompts,
  messages and scoreboard ("YOU") on their own screen, plus their OWN inventory (Y) and talk box /
  shop: two players can shop and sort their bags at the same time, each moving their own
  highlight with their own controller. Messages about one player (their purchase, their knockout,
  what an NPC says to them) only show on their screen; news for everyone (golden koi grabbed,
  someone joined) shows on all.
- **Shared:** SETTINGS, and the keys / buttons (SETTINGS > KEYS). (MY CAT is each player's own.)
- **Highlighted buttons:** each HUD window (talk box, inventory, pause) keeps its own highlight
  (`scripts/ui/seat_focus.gd`), so four players can each be in a menu at once. The stick moves it
  ONE step per push (let the stick go back to the middle to move again), so a long talk box
  doesn't race to the bottom; the d-pad moves one step per press. (Godot's own
  "focus" allows only one highlighted button in the whole window: don't use `grab_focus()` in
  HUD windows, use a SeatFocus.)
- **In code:** a cat reads its own seat's buttons with `Seats.is_pressed(cat.slot, "jump")`,
  `Seats.is_just_pressed(...)`, `Seats.get_vector(cat.slot, "move_left", "move_right",
  "move_forward", "move_back")` or, for events, `Seats.event_is(cat.slot, event, "interact")`.
  (Behind the scenes every control exists once per seat: `jump@0`, `jump@1`...)
  `Seats.rumble(player_id, light, heavy, seconds)` shakes that player's controller.
- **Testing without controllers:** `--join_pad=1` (fake controller 1 presses START),
  `--pad=Left_Stick_Up --pad_device=1` (push its stick), `--pad_press=1:Start,0:Start` (presses
  on a chosen controller), `--as_local=1` (the test actions use player 2's cat).

### Controls & key binding (`scripts/controls.gd`, Autoload **Controls**)
- **Rebinding (player):** SETTINGS > KEYS, click a box (it shows `...`), press the new key or
  mouse button (Left/Right/Middle click, wheel, side buttons all work). **Esc** cancels,
  **Delete/Backspace** empties the box. Each control has two keyboard boxes (e.g. W *and* Up)
  and one **PAD** box: pick it (A on a controller) and press a controller button, stick
  direction or trigger. **START** cancels. Keyboard boxes ignore controller buttons and the PAD
  box ignores keys.
- **Clashes:** if the key was already used by a control needed at the same time, that control
  loses it and the hint says "SPACE was taken from JUMP - give it a new key!". Controls only
  clash when their **context** overlaps: `foot` (walking), `car` (driving), `any` (both) — so
  JUMP (foot) and HANDBRAKE (car) can both be Space.
- **Esc and START can't be rebound** — they always open/close menus. The other menu buttons
  (A = press, B = back, LB/RB = tabs, X = drop in the inventory) are in **FIXED** in
  `scripts/controls.gd`.
- **Adding a control:** add one line to **ACTIONS** in `scripts/controls.gd`, e.g.
  `{"action": "wave", "label": "WAVE", "context": "foot", "keys": ["V"], "pad": "Pad R3"},`
  It appears in the KEYS menu by itself. In your script use `Input.is_action_pressed("wave")`
  (or `event.is_action_pressed("wave")` in `_unhandled_input`, like MEOW in `cat_player.gd`).
- **Changing a default key:** edit `"keys"` on that line (names like `"F"`, `"Space"`, `"Shift"`,
  `"Up"`, `"Mouse Left"`, `"Wheel Up"`, `"Mouse 4"`), or `"pad"` for the controller (`"Pad A"`,
  `"Pad B"`, `"Pad X"`, `"Pad Y"`, `"Pad LB"`, `"Pad RB"`, `"Pad LT"`, `"Pad RT"`, `"Pad L3"`,
  `"Pad R3"`, `"Pad Back"`, `"Pad D-Pad Up"`..., `"Pad Left Stick Up"`..., `"Pad Right Stick Left"`...).
  Players who already rebound keep theirs until they press RESET KEYS.
- **Showing a key on a prompt:** `Controls.key_text("interact")` gives `"E"` (or whatever the
  player picked), or `"X"` while they're on a controller. Connect `Controls.changed` if the text
  is made once and needs updating (it also fires when they switch keyboard <-> controller).
- **Is the player on a controller?** `Controls.using_pad`. **Rumble:** `Controls.rumble(light, heavy, seconds)`
  (does nothing on keyboard or with RUMBLE off).

### Node tree (in `main.tscn`, under PS1Overlay)
```
(The in-game HUD is NOT here: it's the sharp overlay in scenes/ui/hud.tscn, §13.)
Lobby (Control)                   script: ui/main_menu.gd   theme: ui/menu_theme.tres
├── Shade (ColorRect)             <- darkens the city a little so the text reads
├── Title / Subtitle / Tagline (Label)
├── MainScreen (VBoxContainer)    <- PlayButton, SettingsButton, QuitButton
├── ModeScreen (VBoxContainer)    <- SoloButton, MultiplayerButton, BackButton
├── PlayScreen (PanelContainer) > VBox      <- the MULTIPLAYER screen
│   ├── Columns > HostColumn (HostLabel, SeedInput, HostButton)
│   │           > JoinColumn (JoinLabel, AddressInput, JoinButton)
│   └── BackButton
├── Status (Label)                <- "Connecting..." / errors
└── Version (Label)
PauseMenu (Control)               script: ui/pause_menu.gd
└── Dim, Panel > VBox > Title, ResumeButton, CatButton, SettingsButton, LeaveButton, QuitButton, Note
SettingsMenu                      <- an instance of scenes/ui/settings_menu.tscn
CatCreator (Control)              script: ui/cat_creator.gd  (CHOOSE YOUR CAT / MY CAT; builds itself, §11)
ColorDepthDither (ColorRect)      <- keep this LAST so it covers everything
(The inventory screen and the NPC talk box are in the HUD instead: scenes/ui/hud.tscn, §13.)
```
`scenes/ui/settings_menu.tscn`: SettingsMenu (Control, `scripts/ui/settings_menu.gd`) > Dim,
Panel > VBox > Title, Tabs, Scroll (ScrollContainer) > Rows, Hint, Buttons (ResetButton,
BackButton). The tab buttons and the setting rows are made by the script from its **TABS** list;
the KEYS tab's rows come from `Controls.ACTIONS`. Make the list taller/shorter with
**Scroll > Inspector > Layout > Custom Minimum Size > y** (now 104).

### The pieces
- **`scripts/ui/main_menu.gd`** (on **Lobby**) — the start menu screens. It doesn't connect
  anything itself: it sends `play_pressed` / `solo_pressed` / `host_pressed` / `join_pressed` /
  `settings_pressed` signals, and `game.gd` does the work (e.g. `play_pressed` opens CHOOSE YOUR
  CAT, whose NEXT shows the SOLO / MULTIPLAYER screen again). Inspector knobs on **Lobby** > **Start Menu**: Menu Camera, Camera
  Sway Degrees / Seconds, Title Flicker.
- **`scripts/ui/pause_menu.gd`** (on **PauseMenu**) — Esc / START opens/closes it (B closes) once a game has
  started. While it (or Settings opened from it) is up, `PauseMenu.is_open` is true and the cat,
  car and inventory ignore the keyboard.
- **`scripts/settings.gd`** — Autoload named **Settings**. Holds every setting with its default,
  loads/saves the file, and applies the screen, sound and wobble settings. Other scripts read e.g.
  `Settings.mouse_speed`. `game.gd` applies the two that live in the scene (CRT look and fog).
- **Esc order:** the topmost open thing handles Esc first — the talk box / inventory (in the
  HUD, which always hears keys before the game), then settings, then the pause menu, then the
  start menu. (Godot sends keys to the node lowest in the scene tree first, so keep that order
  under PS1Overlay.)
- **`ui/menu_theme.tres`** — the menu look (dark purple boxes, pink edges, cyan hover).
  Double-click it in the FileSystem dock to change colours in the Theme editor.
- **PS1 wobble** is a *global shader parameter*: Project Settings > **Shader Globals** >
  `psx_wobble` (1 = on). Every `psx_lit` material reads it.
- **Sound buses:** the game creates **Music** and **SFX** buses (under Master). Sounds played by
  the **Sound** autoload (§12) pick the right one themselves. Only if you place an
  AudioStreamPlayer by hand, set its **Bus** in the Inspector to Music or SFX so the sliders work.

### Adding a new setting
1. `scripts/settings.gd`: add `var my_setting: bool = true`, add `["effects", "my_setting"]` to
   **SAVED**, and use it in `apply()` (or anywhere: `Settings.my_setting`).
2. `scripts/ui/settings_menu.gd`: add a row to a tab in **TABS**, e.g.
   `{"setting": "my_setting", "label": "MY THING", "choices": [[true, "ON"], [false, "OFF"]], "hint": "What it does."}`

### Testing shortcut
`--menu=play`, `--menu=settings` (plus `--settings_tab=0..4`, 3 = KEYS) or `--menu=pause` (with
`--host`) open that menu before a DevCapture screenshot. `--rebind=drop,0,Space` (with
`--menu=settings`) rebinds a key like a player would and prints every key (`--rebind=jump,2,Pad_B`
for the PAD box).
Controller tests (fake controller presses, no controller needed): `--pad=Right_Stick_Right`
(hold for `--hold_frames`, prints how far the camera turned / cat moved / car throttle),
`--pad=RT,Left_Stick_Left --drive` (car; add `--car_mouse=300` to look around with the mouse and
`--car_watch=40` to print the car camera's angle as it swings back), `--pad_press=Start,D-Pad_Down,A,B` (presses one by one,
prints which menu is open and which button is highlighted after each).

---

## 11. Character creator (CHOOSE YOUR CAT / MY CAT)

### What the player sees
**PLAY** on the start menu opens **CHOOSE YOUR CAT**: your cats along the top, the look rows on
the left, and the cat slowly turning on the right. (During a game, **MY CAT** in the pause menu
opens the same screen to restyle or rename the cat you're playing; no switching cats mid-game.
Couch players 2-4 get it for THEIR cat: A on their row of the landing page, or MY CAT in their
own pause menu.)
```
<  [ WHISKERS ]  >  2/3  [NEW] [DELETE]     your cats: < > switch, type to rename
FUR       <  [colour]  >        main coat
MARKINGS  <  [colour]  >        belly and muzzle
EYES      <  [colour]  >        bright colours glow a little in the dark
NOSE      <  [colour]  >
HAT       <  FEDORA    >        NONE / BEANIE / FEDORA / GREEN MOHAWK / MOHAWK / NEON HALO
FACE      <  SHADES    >        NONE / CIGAR / CYBER VISOR / HEADBAND / SHADES
NECK      <  NONE      >        NONE / BANDANA / BANDOLIER / BELL COLLAR
VOICE     <  MALE      >        MALE / FEMALE: how your cat sounds when it taunts (you hear it when you switch)
[ BACK ]     [ RANDOM ]     [ NEXT ]        (in a game: [ RANDOM ] [ DONE ])
```
- **Your cats:** you can have as many as you like. **NEW** starts a fresh one (type its name in the
  box), **<** / **>** switch between them, **DELETE** asks "SURE?" and a second click deletes that
  cat **with its cash and stash**. The cat showing when you press NEXT is the one you play.
- **Each cat has its own name, look, cash and stash** (§8 "The stash & saved progress").
- **NEXT needs a name** ("Name your cat first!").
- Everything is **saved straight away** (in `settings.cfg`). Changing your look in the middle of a
  game changes your cat right there, and everyone else sees it.
- **Upgrading from an older version:** your old cat name, look, cash and stash become your first cat.

### The cat model (the original, code-built cat)
Every cat in the game (yours, the MY CAT preview and all 14 sewer NPCs) is the ORIGINAL simple cat
made of Godot shapes (spheres, cylinders and prisms) with the PS1 material: `scenes/cat_model.tscn`
for players and the MY CAT preview; each NPC scene builds its own copy (with its own hat, cigar,
glasses...) under its **Model** node. It wears HAT / FACE / NECK accessories.
- (10 Nov 2026: a Blockbench "armless mascot" cat replaced it for a few hours and was reverted: the
  original was the better look. Its Blockbench file is kept in `models/blockbench/cat.bbmodel` and
  in git history, but nothing in the game uses it.)

### Add a new accessory (no code)
1. **Make its model.** In the FileSystem dock, right-click `scenes/cat_parts/beanie.tscn` >
   **Duplicate...** and name it (e.g. `cowboy_hat.tscn`). Double-click it and change the meshes:
   select a mesh > Inspector > **Mesh** for the shape, **Surface Material Override** > albedo_color
   for the colour. Build it around the **origin (0, 0, 0)**: that point is put on the cat at the
   slot's spot: **hat** = top of the head, **face** = just in front of the eyes, **neck** = round
   the neck.
2. **Make its card.** Right-click `cat_parts/beanie.tres` > **Duplicate...** (e.g.
   `cowboy_hat.tres`). Double-click it and set: **Id** (unique, no spaces, e.g. `cowboy_hat`),
   **Display Name** (what MY CAT shows), **Slot** (hat / face / neck), and drag your `.tscn` into
   **Scene**.
3. **Fit it** (optional): **Fit > Offset** nudges it (metres; -Z is towards the nose),
   **Rotation Degrees** tilts it, **Scale** resizes it. Open MY CAT to check how it sits.

That's it: it's in the MY CAT screen next time you press F5.

### Change the colours (no code)
Double-click `cat_parts/palette.tres`. It has four lists: **Fur Colors**, **Marking Colors**,
**Eye Colors**, **Nose Colors**. Click a colour to change it; **+ Add Element** adds one. The first
colour of each list is what a brand-new cat starts with in MY CAT.

### Where it lives
- `scripts/cat/cat_look.gd` (`CatLook`) — the framework. A cat's **look** is a small list of
  values: four colours plus which part is in each slot. `CatLook.apply(model, look)` paints a cat
  model and puts the parts on. It also loads the part cards and palette, makes random looks, and
  throws away anything broken (unknown parts, wrong types).
- `scripts/cat/cat_part.gd` (`CatPart`) — the accessory card. `scripts/cat/cat_palette.gd`
  (`CatPalette`) — the colour lists.
- `cat_parts/` — the cards and the palette. `scenes/cat_parts/` — the accessory models.
- `scenes/cat_model.tscn` — the cat's body, used by player cats and the MY CAT preview. The colour
  rows paint meshes **by name** (FUR = Body, legs, Head, ears, Tail; MARKINGS = Belly, Muzzle;
  EYES = EyeL/EyeR; NOSE = Nose), listed in `COLOR_PARTS` in `cat_look.gd`.
- `scripts/ui/cat_creator.gd` (`CatCreator`, on **PS1Overlay > CatCreator**) — the screen. It builds
  itself: the cat row, then one row per colour and per slot.
- `scripts/settings.gd` — your cats: `Settings.cats` (each `{"id", "name", "look"}`) and
  `Settings.current_cat_id`, with helpers `current_cat()`, `new_cat()`, `select_cat()`,
  `update_current_cat()`, `delete_cat()`. Each cat's cash + stash file is named after its id.
- **Multiplayer:** your look is the `look` property on your cat (`cat_player.gd`). The cat's
  MultiplayerSynchronizer shares it like the name tag, so everyone (late joiners too) sees it.
  Looks are only for show: they don't change anything about how you play.

### Add a new slot (a little code)
For a fourth kind of accessory (e.g. **back** for capes and jetpacks): in `cat_look.gd` add
`"back"` to **SLOTS** and a spot to **SLOT_ANCHORS** (e.g. `"back": Vector3(0, 0.5, 0.2)`); in
`cat_part.gd` add `"back"` to the Slot list (`@export_enum`); and add `"back": "BACK"` to
**LABELS** in `cat_creator.gd`. The new row then appears in MY CAT by itself.

### Testing shortcut
`--menu=cat` opens CHOOSE YOUR CAT (MY CAT with `--host`/`--solo`), `--menu=mode` the SOLO /
MULTIPLAYER screen, before the screenshot. `--solo` starts a solo game. `--look=N` wears a random look made from the
number N (both on the start menu and with `--host` / `--join`); test runs never save it.
`--wear=hat:mohawk,face:headband,neck:bandolier` wears exact parts (colours too: `fur:#808080`), and
`--portrait=me` (or an NPC's node name, e.g. `--portrait=DonCatleone`) takes a HUD-free close-up of
the face; nudge the camera with `--portrait_dist`, `--portrait_height`, `--portrait_side`. Every
cat's look is printed, e.g. `DevCapture look 1: fur=#383342 hat=neon_halo face=shades neck=-`.

---

## 12. Sound & music

Every sound goes through one Autoload, **Sound** (`scripts/sound.gd`). The sounds themselves
are just files in the `sounds/` folder — **adding or replacing a sound needs no code.**

```
sounds/
├── sfx/          <- one-off effects        (SOUND FX slider)
├── ambience/     <- background loops        (SOUND FX slider)
└── music/        <- music loops, one per area (MUSIC slider)
```

The files there now are **placeholder bleeps** made by Claude. Replace them with real ones.

### Replacing or adding a sound (no code)
1. Get a sound file: `.wav` for short effects, `.ogg` for music and long loops (`.mp3` also works).
2. Name it exactly like the one it replaces (e.g. `shoot.wav`) and drop it into the right folder,
   overwriting the old one. (In Godot: drag it from Explorer into the **FileSystem** dock.)
3. Press Play. It's picked up by its name the next time the game starts.
- **Several versions of one sound:** number them: `meow_1.wav`, `meow_2.wav`, `meow_3.wav`...
  They're all "meow", and a random one plays each time. Great for footsteps and meows.
- Every play is also nudged a little higher or lower at random, so repeats don't sound robotic.
- A sound name the game asks for but has no file yet just stays silent (the Output panel says
  `[Sound] No file for 'x' yet` once).

### The sounds the game uses
| File name (in `sfx/`) | When it plays | Who hears it |
|---|---|---|
| `footstep` (`_1`, `_2`, `_3`) | every cat's steps, quicker when running | everyone nearby |
| `jump` | jumping (and catdip double jumps) | everyone nearby |
| `meow_blip_cat_male` / `meow_blip_cat_female` (`_1`..`_4`) | your cat "talking" its MEOW taunt as it types out over its head (MY CAT > VOICE picks which; each cat a slightly different pitch, §23) | everyone nearby |
| `meow` (`_1`, `_2`) | a downed cat's sad meow, NPCs | everyone nearby |
| `radio_squawk` | the walkie-talkie click when someone HECKLES from the CAT-CAM (§24), over the watched cat | everyone nearby |
| `shoot` | each gun shot (per gun: **Shot Sound** on the gun scene's root) | everyone nearby |
| `pickup` | grabbing an item / fish | everyone nearby |
| `roomba_hum` (loops) | every VAC-COP, revs up while chasing (higher-pitched on a SQUIRT-DRONE) | everyone nearby |
| `squirt` | a SQUIRT-DRONE fires a water zap | everyone nearby |
| `splat` | LINT-TRAPPER glue: a lob, its landing, and your paws getting stuck | everyone nearby (paws: only you) |
| `alert` | a VAC-COP starts chasing | everyone nearby |
| `bonk` | a VAC-COP bonks a cat | everyone nearby |
| `roomba_hit` | a bolt hits a VAC-COP | everyone nearby |
| `explode` | a VAC-COP explodes | everyone nearby |
| `engine_loop` (loops) | the getaway car; pitch follows the speed | everyone nearby |
| `car_door` | getting in / out of the car | everyone nearby |
| `hurt` / `knockout` | you lose HP / you're knocked out for good | just you |
| `downed` | you hit 0 HP and are waiting for a revive (placeholder "wah-wahh") | just you |
| `revive` | a downed cat is picked back up (placeholder rising blip) | everyone nearby |
| `extract` | you climb down the exit manhole | just you |
| `phone_ring` (loops) | payphones while the exit is open and nobody has called Don yet | everyone nearby |
| `koi_grab` | someone grabs a golden koi | everyone (2D) |
| `door_slide` | Meow-Mart's sliding doors open (§27) | everyone nearby |
| `can_clatter` / `shelf_collapse` | a can stack knocked off a shelf / a whole aisle toppling (§27) | everyone nearby |
| `scanner_beep` | [E] SCAN at a Meow-Mart checkout | everyone nearby |
| `plate_click` / `security_door` | the security scale pressed / let go; the EMPLOYEES ONLY door rolling | everyone nearby |
| `tank_shatter` | the golden koi tank breaks | everyone nearby |
| `store_alarm` (loops) | the STORE ALARM klaxon, inside and over the street door | everyone nearby |
| `overclean_mart_alarm` | "Aquatic display breach detected..." | players up top |
| ambience `meow_mart_hum` | fluorescent + fridge hum while player 1 is inside the store | just you |
| `heat_up` | the HEAT goes up a level | everyone (2D) |
| `boss_siren` | the MEGA VAC-COP comes out | everyone (2D) |
| `overclean_*` | OVERCLEAN's announcements (chime + robot voice, §21) | players up top (the seal: everyone) |
| `bin_clatter` / `cone_bounce` / `box_thump` / `poster_scratch` | a bin / cone / box knocked over, a poster scratched (§23) | everyone nearby |
| `vending_smash` / `hydrant_burst` / `cart_roll` / `sign_spark` / `dumpster_rummage` | STREET PROPS PACK: a vending machine kicked, a hydrant wrenched open, a cart shoved, a neon A-frame knocked flat, a dumpster rummaged (§23) | everyone nearby |
| `prop_standup` | a VAC-COP finishes tidying a mess (it stands back up) | everyone nearby |
| `roomba_tidy` | a VAC-COP vacuuming up a mess (repeats while TIDYING) | everyone nearby |
| `roomba_curious` | a VAC-COP heard a meow and comes to look | everyone nearby |
| `overclean_mess_1..3` | OVERCLEAN's remark when the city gets trashed (§23) | players up top |
| `pa_chime`, `scratch` | made by the Sound Lab (§20); not used yet | |
| `meow_blip_<name>` (`_1`..`_4`) | an NPC's talking voice while their line types out (each NPC's **Voice**, §8) | just you |
| `buy` / `error` | the Black Markitten sells you something / says no | just you |
| `click` | any menu button | just you |
| `report_open` / `report_row` / `report_award` | the RAID REPORT appears / each cat's row slides in / each award stamps down (§22) | just you |

Music and background loops change by area (they fade into each other): in the sewers
`music/hub` + `ambience/sewer`, up top (and on the start menu) `music/city` + `ambience/rain`.
Watching someone (CAT-CAM, the breach live feed) counts as being where the camera is.
To use other files, select **Hub** in `main.tscn` > Inspector > **Music** group (Hub Music,
City Music, Hub Ambience, City Ambience: file names without `.wav`; empty = silence).
(10 Nov 2026: a 4-stage synth soundtrack was tried and reverted; it's in git history.)

"Everyone nearby" sounds come from a spot in the 3D world: louder when your camera is close,
left/right speaker by direction, silent beyond 45 m.

### Where to find sounds
- **jsfxr** (sfxr.me, in your browser): click "Pickup", "Laser", "Explosion"... and export a
  `.wav`. Perfect for the retro feel.
- **Freesound.org** (filter by the **CC0** licence = free for anything), **Kenney.nl** audio
  packs, **OpenGameArt.org**. Check each sound's licence before you put it in the game.
- Record your own: real meows from a phone are the best meows.
- **PS1 crunch tip:** save effects at **22050 Hz mono** (Audacity: Tracks > Resample, and
  Tracks > Mix > Mix Stereo Down to Mono). Loops must start and end smoothly or they click.

### Split screen and sound
The game can only listen from ONE spot (Godot can't mix sound for several cameras): player 1's
camera. So a sound that's closer to another player on this computer (player 2's fish pickup,
their gunshot, the car engine while player 2 drives) is played as if player 1's ears were where
that player is: same distance, same direction. Everyone on the couch shares the speakers, so
you hear what's happening to whoever it's happening to. (`Sound.hearing_position`, automatic
for `play_at` / `play_everywhere` / `attach_loop`. `--sound_log` says "moved to another player's
ears" when it does it.)

### Tuning knobs
- **`scripts/sound.gd`** (top of the file, change the number): `PITCH_VARIATION` (random pitch
  nudge), `HEARING_RANGE` (metres), `LOUDNESS_SIZE` (bigger = loud further away), `FADE_SECONDS`
  (music crossfade), `MUSIC_DB` / `AMBIENCE_DB` (music and ambience loudness),
  `RETRO_CUTOFF_HZ` (the PS1 "cheap TV speaker" muffle on all sound; 0 = off).
- **Cat** (`scenes/player.tscn`, root) > **Sounds**: Footstep Interval, Footstep Volume Db, Meow Cooldown.
- **GetawayCar** (`scenes/getaway_car.tscn`, root) > **Engine Sound**: Engine Idle Pitch,
  Engine Top Pitch, Engine Volume Db.
- **Guns** (e.g. `scenes/items/pistol.tscn`, root) > **Look** > **Shot Sound**: which `sfx/` file it fires.

### Making something new play a sound (one line of code)
- `Sound.play("buy")` — plain sound, only you hear it (menus, "you got hurt").
- `Sound.play_at("shoot", where)` — from a spot in the world, on this computer. Use it where
  **every** computer already runs the code (like a shot that's drawn on every screen).
- `Sound.play_everywhere("bonk", where)` — from a spot, sent to **every** player's computer.
  Use it where only one computer knows it happened (usually the host).
- `Sound.attach_loop("engine_loop", self)` — a looping sound that rides along on a node; keep the
  returned player to change its `pitch_scale` / `volume_db`.
- `Sound.play_music("city")` / `Sound.play_ambience("rain")` — fade over to another track.

### Testing shortcut
Add `--sound_log` to a test run: every sound that plays is printed (`[Sound] footstep at (...)`).
Music checks: `--solo` (hub), `--solo --deploy` (city). Look for `[Sound] music now playing: ...`.

---

## 13. The HUD (overlay)

The HUD is everything on screen during a game that isn't the world or a menu: cash, loot / quest
line, HP, the extraction arrow, the scoreboard, the "[E] TALK TO..." prompt, the crosshair, what
you're holding, messages and the big EXTRACTED popup.

**It is drawn on top of the game, and SETTINGS > EFFECTS > UI STYLE picks how it looks:**
- **PS1**: the HUD and menus are drawn 240 pixels tall, like the game, and blown up with
  chunky pixels. One CRT + dither effect (`CRTOverlay`, made by `game_screen.gd`) then covers the
  whole picture, so the HUD and menus bend and scanline together with the 3D city.
- **MODERN** (default): the HUD and menus are drawn at your monitor's real resolution, so they're crisp, and
  only the 3D city gets the CRT effect.

The layout is the same in both, still 720 HUD units tall. PS1 style with one player draws the
whole HUD a third bigger so its text stays readable: select **GameScreen** in `game_screen.tscn` >
**Ps1 Hud Scale** (1.33; above that the inventory stops fitting on a 4:3 screen). Small text drawn
in code (the EXIT / MAINFRAME tags on the heat bar, the gun's name, names over enemies' health
bars) is drawn at least 18 units tall in the PS1 look so it stays readable. If you draw HUD pieces
in code, wrap font sizes in `Hud.text_size(size)`, thin lines in `Hud.line(width)` and text outlines
in `Hud.outline(width)` so they survive the low resolution.

**The top row never overlaps.** Health bar (left), the line in the middle ("THE SEWERS - SAFE
ZONE", the breach clock...) and the heat / Mainframe bar (right) share the screen's width every
frame (`hud.gd` `_layout_top_row`). On a narrow screen (PS1 look on 4:3, every split-screen pane)
the bars shrink to make room for the middle line; if it still doesn't fit, the line drops under the
bars (wrapping if it must) and the FEED + sewer scoreboard move down by its height. The buff badges
also stop short of the middle line. Tuning: select **HUD** in `hud.tscn` > Inspector > **Top Row**:
Top Bar Width (360, the most the bars get), Top Bar Min Width (210, the least before the line drops
down), Top Margin, Top Gap. (The bars' widths set in `hud.tscn` are overwritten by this.) Box borders need to be at least 3
units thick (`ui/hud_theme.tres`), or some edges vanish between the pixel rows.

### How the screen is put together (`scenes/game_screen.tscn`, the scene F5 runs)
```
GameScreen (Control)        script: ui/game_screen.gd  <- sizes everything when the window changes
├── HUD (CanvasLayer)       <- an instance of scenes/ui/hud.tscn, Layer 10 = always on top
├── Bars (ColorRect)        <- black, behind everything (the border in 4:3 / SHARP mode)
├── GameView (TextureRect)  <- shows player 1's game picture, blown up (Texture Filter: Nearest)
│   └── GameViewport (SubViewport)   <- the "PS1 screen", 320x240 (wider on wide monitors)
│       └── Main            <- scenes/main.tscn, the actual game
├── GameView2..4            <- made by the script when couch players join (split screen, below)
│   ├── GameViewport > Camera3D      <- their 3D view (same world, their camera)
│   └── Post > Dither                <- the CRT + dither look on their picture
└── JoinHint (Label)        <- "PRESS START TO JOIN" in the empty corner with 3 players
```
`game_screen.gd` works out the game picture's size from **SCALING** and **ASPECT** (§1, §10), and
passes your mouse and keyboard through to the game. Its Inspector knobs: **Game Height** (240),
**Design Width** (320), **Divider** (the black line between split screens, game pixels) and
**Split Full Detail** (see below).

**Split screen:** with 2-4 players on this computer (couch co-op, §10) the picture is cut up:
2 players side by side (or top + bottom: SETTINGS > DISPLAY > 2-PLAYER SPLIT), 3-4 players in
the four corners. **Every screen gets the same detail as one full screen:** a half-height
screen is drawn with 240 pixel rows (double resolution) and shrunk to fit, so splitting doesn't
make the picture blurrier. (Turn **Split Full Detail** off in the Inspector of GameScreen in
`scenes/game_screen.tscn` for the old chunky look, where each screen is just its half or
quarter of one 240-row picture.) Players 2-4's screens don't build a second city: they look at the same world
through a camera that copies their cat's camera every frame (behind the cat, or behind the car),
each with its own rain and the sewer/city fog of where it is (`hub.gd` `environment_for`).
The moon shines and the city music plays while anyone on this computer is up top. Sound is
heard from player 1's camera. Full-screen menus (pause, settings, MY CAT) go back to one big
screen while open. Player 1's HUD sits on player 1's screen (the inventory and talk box use the
whole picture so they fit).

### The HUD scene (`scenes/ui/hud.tscn`, script `scripts/ui/hud.gd`)
```
HUD (CanvasLayer)            script: ui/hud.gd
└── Frame (Control)          <- resized to cover exactly the game picture; theme: ui/hud_theme.tres
    ├── Names (Control)      <- names over cats' and NPCs' heads (script ui/hud_name_tags.gd)
    ├── Bars (Control)       <- health bars over VAC-COPs / hurt cats, boss bar (ui/hud_health_bars.gd)
    ├── Damage (Control)     <- damage numbers off things you shoot (ui/hud_damage_numbers.gd)
    ├── Top (Control)        <- stays up while you talk / shop
    │   ├── Cash             <- top-left, big green "$120"
    │   ├── Carrying         <- "LOOT 2/6" or "QUEST: MITTENS' FISH 2/3"
    │   ├── Health           <- your health bar, drawn in code (script ui/hud_health_bar.gd)
    │   ├── StatusIcons      <- buff / debuff badges right of the health bar (ui/hud_status_icons.gd)
    │   ├── DropOff          <- top-middle: "EXTRACT ^ 40m" / "THE SEWERS - SAFE ZONE" / the Sewer Breach clock
    │   ├── Heat             <- top-right: flashing red/blue heat bar (script ui/hud_heat_bar.gd)
    │   └── Scoreboard       <- top-right, under Heat: everyone's cash (sewers only)
    ├── Middle (Control)     <- hidden while the talk box or inventory is open
    │   ├── Popup            <- big "EXTRACTED +$150" that fades out
    │   ├── Banner           <- big wrapped text for long news (Sewer Breach results)
    │   ├── Crosshair        <- drawn lines (script ui/hud_crosshair.gd), only with a gun
    │   ├── Message          <- what Don says, "KNOCKED OUT BY...", etc.
    │   ├── Prompt           <- "[E] TALK TO DON CATLEONE" / "[E] STORE YOUR SHIT" / "[E] GET IN" (hud.gd)
    │   └── Held             <- bottom-left: gun picture(s) + 2 quick-use squares (ui/hud_weapon_display.gd)
    ├── Inventory (Control)  <- the Tab screen, builds its own boxes (script ui/inventory_ui.gd, §9)
    └── NpcDialog (Control)  <- the talk box (script ui/npc_dialog.gd, §8)
        └── Panel > VBox > Speaker, Scroll > Body > Line, Choices   <- choice buttons made by the script
```
- **Units:** positions are in "HUD units": the screen is always **720 units tall** (and 960 or
  more wide), whatever the real resolution. So a label 36 units big is 1/20 of the screen
  height on every monitor.
- **Move / restyle a piece:** open `scenes/ui/hud.tscn`, click the label, change **Layout >
  Transform** (position/size), **Theme Overrides > Colors / Font Sizes**, etc. Always keep an
  **anchor** (toolbar **Anchors Preset**: Top Left, Center Top, Top Right, Bottom Left...) so it
  sticks to its corner on wide screens.
- **Fonts and outline for every label:** double-click `ui/hud_theme.tres`. It uses your
  computer's **Consolas** (bold) with a dark outline + drop shadow. To use your own font, drop a
  `.ttf`/`.otf` into the project and set the theme's **Default Font** to it.
- **Crosshair look:** select **Frame > Middle > Crosshair**: Color, Line Length, Gap, Thickness,
  Dot Size, Outline.
- **Popup fade:** select **HUD**: **Popup Fade Seconds**.
- The whole HUD **hides itself while a full-screen menu is open** (pause, settings, MY CAT),
  because those menus live inside the game picture, underneath it.
- **HUD windows (talk box, inventory):** while one is open, your mouse and keys go to it instead
  of the game (`game_screen.gd` asks `Hud.wants_input()`), and the **Middle** pieces hide.
  - **Talk box size:** select **NpcDialog > Panel** > **Layout > Transform > Size** (it's anchored
    to the bottom middle, so it stays centred on wide screens). Button height: **NpcDialog** >
    **Choice Height**. Text sizes: **Speaker** / **Line** > Theme Overrides > Font Sizes.
  - **Inventory:** select **Inventory**: Slot Size, Slot Font Size, Title Font Size, Columns.
  - Box and button colours / borders for both: `ui/hud_theme.tres` (PanelContainer, Button).

### The OCEAN-BLUE style (`ui/hud_style.tres`, script `scripts/ui/hud_style.gd`)
The new HUD pieces (and, next, the inventory, shop and workbench) share ONE set of colours: a
translucent deep-ocean-blue box with a bright cyan-blue edge and brighter corner brackets.
- **Change the look:** FileSystem dock > `ui` > double-click **hud_style.tres**. In the Inspector:
  - **Panels:** Panel Color (the see-through blue inside), Border Color, Faint Border Color (empty
    slots), Border Width, Corner Length (the bright corner brackets; 0 = none), Text Color.
  - **Weapons:** Cool Color (a cool gun: ocean blue), Hot Color (fully heated: red), **Heat Blend**
    (which colours a gun passes through as it heats: VIOLET_SWEEP = blue, violet, pink, red, the
    default; THERMAL = blue, cyan, yellow, orange, red; STRAIGHT = a plain mix, a bit grey in the
    middle), Heat Curve (higher = stays blue longer), Overheat Flash Color + Flashes Per Second.
  - **Buffs and debuffs:** Buff Color (catnip, catdip), Debuff Color (sticky paws, amber), Timer
    Fill Opacity, Ending Soon Seconds (the badge pulses for its last second).
  Press **Ctrl+S**; the game uses it next time it starts.
- Thin lines follow `Hud.line()` so they don't vanish in the chunky PS1 UI look.

### The gun box and quick-use slots (**Frame > Middle > Held**, `scripts/ui/hud_weapon_display.gd`)
```
 OVERHEAT                       <- only while a gun is overheated (flashes)
+----------------------+ +---+
| RMB                  | |1  |  <- QUICK USE 1: the item's picture, key, "x2" stack count
|  [left paw gun]      | +---+
|     [right paw gun]  | +---+
|                  LMB | |2  |  <- QUICK USE 2 (a faint empty frame when there's nothing in it)
+----------------------+ +---+
```
- One gun: its side-view picture, its name top-left and its fire button bottom-right.
- **Heat:** the picture is ocean blue when cool and changes colour towards red as `weapon.heat`
  rises (see Heat Blend above); the box edge warms up too. Overheated = the picture flashes and
  **OVERHEAT** shows above the box. Guns that never overheat (pistol, hairball blaster) stay blue.
- **Dual wield** (two one-paw guns): two pictures overlapping. The RIGHT paw's (LMB / RT) is in
  front, the LEFT paw's (RMB / LT) peeks out behind it, up and to the left. Each heats on its own.
- Button names follow `Hud.key_for` (controller buttons for a pad player).
- Nothing in your paws and nothing in the quick-use slots = the whole thing hides.
- **Tuning** (select **Held** in `hud.tscn`): Weapon Box Size, Quick Slot Size, Gap, Padding, Dual
  Offset (how far the back gun sits up-left), Back Opacity, font sizes, Heat Follow Speed.
  To move it, drag it (it's anchored bottom-left).

### Buff and debuff badges (**Frame > Top > StatusIcons**, `scripts/ui/hud_status_icons.gd`)
Small square badges right of your health bar, one per effect on your cat right now:

| Badge | Effect | Colour |
|---|---|---|
| paw in dripping glue | **STICKY PAWS** (stepped in LINT-TRAPPER glue: half speed) | amber (debuff) |
| jagged leaf + speed lines | **CATNIP** speed boost | blue (buff) |
| tin under a double chevron | **CATDIP** double jump | blue (buff) |

A lighter fill inside each badge drains downwards as the effect runs out; the badge pulses in its
last second. On a narrow screen (4:3 in the PS1 UI look, split screen) there's no room between the
health bar and the heat bar (or the middle line), so the badges sit just under the health bar and the FEED moves down.
Tuning (select **StatusIcons**): Badge Size, Gap, Padding, Pulse Per Second. hud.gd `_update_status`
feeds it from the cat (`sticky_fraction()`, `boost_fraction()`, `air_jump_fraction()`); a new effect
= a line there + a picture from the icon tool (section 20).

Test (pictures in `shots/`):
```powershell
C:\GoDot\Godot_v4.7.2-stable_win64_console.exe --path . -- --solo --deploy --give=red_dot,red_dot,catnip,catnip,catdip --hud_heat=0.35,1.0 --hud_buffs=sticky,catnip,catdip --frames=240 --capture=shots/hud.png
```
`--hud_heat=R,L` holds each paw's gun at that heat (1 = overheated), `--hud_buffs=sticky,catnip,catdip`
switches badges on; it prints a `DevCapture hud loadout` line. Add `--setting=modern_ui:false` for the PS1 look.

### Names over heads (`scripts/ui/hud_name_tags.gd`, on **Frame > Names**)
Cats and NPCs still have a **NameTag** (Label3D) in their own scene: it's the *marker* that says
where the name floats, what it says (**Text**) and its colour (**Modulate**). Every Label3D in the
group **hud_name_tags** is made invisible in 3D, and the HUD draws a sharp label in its place.
- It shrinks with distance like a real sign, fades out far away and hides behind walls.
- Knobs (select **Names**): **Max Distance**, **Fade Distance**, **World Text Height** (how big it
  is in metres), **Min / Max Font Size**, **Hide Behind Walls**, **Wall Layers**.
- **Give something a floating name:** add a **Label3D** child where the name should be, type the
  name in **Text**, pick a **Modulate** colour, then **Node** dock (next to Inspector) > **Groups**
  > type `hud_name_tags` > **Add**.
- Hiding the Label3D (like a cat in a car) hides the HUD name too. Your own cat's name isn't
  shown on your own screen (split screen: the other players still see it on theirs).
- **Items on the street** get their labels here too, made in code (you won't see them in the scene
  tree). They only show the item's name: white for gear, and for loot its glow colour (gold koi,
  cyan scrap) or warm white. How close you must be: **Items** node (in `main.tscn`) > **Item Tag
  Distance** (18 m). Standing in reach of any item, the normal HUD prompt says `[E] PICKUP` (each
  player's own button), like the car's `[E] GET IN`. No prompt = your backpack is full.

### Using it from a script (no node paths needed)
```gdscript
Hud.set_text("DropOff", "EXTRACT ^ 9m")   # change a label's words (by node name)
Hud.show_element("Crosshair", true)       # show / hide one piece
Hud.set_color("DropOff", Color.WHITE)     # change a label's text colour
Hud.damage_number(hit_position, 38, false) # a damage number popping off a spot (true = crit)
Hud.show_message("DON: Go get 'em.", 4.0) # middle-of-screen line for N seconds
Hud.popup("EXTRACTED +$80", 2.5)          # the big fading text
Hud.set_in_game(true)                     # whole HUD on (game) / off (start menu)
Hud.element("Scoreboard")                 # the node itself, for anything else
```

**Split screen (couch co-op): every player has their own HUD.** Add the player's SEAT
(`cat.slot`: 0 = player 1, 1 = player 2...) at the end to talk to their HUD:
```gdscript
Hud.set_text("DropOff", "...", cat.slot)       # player 2's extraction line
Hud.show_message("SOLD!", 3.0, cat.slot)       # only that player sees it
Hud.show_message("THE KOI IS GONE!")           # no seat on a message / popup = EVERY player sees it
for cat in Game.instance.playing_cats():       # every player on this computer
	Hud.set_text("DropOff", "...", cat.slot)
```
(Labels with no seat go to player 1. Their talk box and inventory: `NpcDialog.for_cat(cat)`,
`InventoryScreen.for_seat(cat.slot)`.) Players 2-4's HUDs are made by `game_screen.gd` from
`hud.tscn`, so any piece you add to `hud.tscn` appears on every player's HUD. On a smaller
screen the whole HUD is shrunk to fit (Inspector of **GameScreen** > **Split Hud Boost**: higher =
bigger text), and the talk box and message line get narrower by themselves.

**Add a new HUD piece:** in `hud.tscn` right-click **Top** (or **Middle**) > **Add Child Node** >
**Label**, give it a unique name (e.g. `Ammo`), pick an anchor, then in your script call
`Hud.set_text("Ammo", "...")`.

---

## 14. Backups and undo (git + GitHub Desktop)

The project is a **git repository**: every "commit" is a saved snapshot of the whole project that
you can look at or go back to. Claude commits after each finished piece of work.

**What's left out on purpose** (see `.gitignore`): Godot's `.godot/` cache (rebuilt automatically),
`shots/` screenshots, and finished game builds. Everything else is backed up, including the
small `.uid` and `.import` files Godot makes next to scripts and images. Keep those.

### One-time: put the backup online (private)
1. Make a free account at **github.com** (Sign up).
2. Open **GitHub Desktop** (Start menu). **File > Options > Accounts > Sign in** to GitHub.com.
3. **File > Add local repository...** > Choose `C:\Users\Nathaniel\Meow-City` > **Add repository**.
4. Click **Publish repository** (top bar). Keep **"Keep this code private"** ticked. Click
   **Publish repository**.

### After that
- When GitHub Desktop shows **Push origin** with a number, click it to send the newest snapshots
  online. Do it at the end of each session.
- **History** tab (left) = every snapshot and exactly what changed.
- **Undo a bad change you haven't committed:** Changes tab, right-click the file > **Discard changes**.
- **Go back to an old version:** History tab, right-click a commit > **Revert changes in commit**
  (this adds a new "undo" snapshot, so nothing is lost). Ask Claude if unsure.
- A plain zip copy also exists from before git: `C:\Users\Nathaniel\Meow-City-backup-2026-10-24.zip`.

---

## 15. Making trailers (the `trailer/` folder)

The trailers are made by scripts, so you can re-make them any time the game changes (new
outfits, a new enemy...). Nothing here touches the game itself. You need **Python** and **ffmpeg**
(both already installed on this PC). Open a terminal in the project folder and run, in order:

```
python trailer/record.py      <- films every shot by playing the game (about 10 minutes)
python trailer/music.py       <- makes the soundtrack (a few seconds)
python trailer/edit.py        <- cuts the trailers together (a few minutes)
```

The finished videos land in `shots\trailer\out\`:
- `cypurrpunk_long.mp4` — the 92-second trailer, 1920x1080 (YouTube, Steam, itch.io)
- `cypurrpunk_short_*.mp4` — 20-26-second vertical (1080x1920) cuts for TikTok, Instagram Reels and
  YouTube Shorts: `heist` (the whole game in one go), `boss` (the MEGA VAC-COP), `cats` (dressing up),
  `coop` (split screen), `loop` (how a run goes, step by step).

**How it works**
- `trailer/record.py` = the **shot list**. Each line is one shot: the game starts with test options
  (where the cat stands, what it holds, what it does) and Godot's **Movie Maker** films it at a
  steady 30 fps, with the game's sound. The film camera options (`--cam_from`, `--cam_to`,
  `--cam_orbit`, `--cam_follow`, `--no_hud`...) are listed at the top of `scripts/dev_capture.gd`.
  Run one shot again with e.g. `python trailer/record.py boss_reveal`. The in-game music is muted
  while filming (the trailer has its own). Every shot happens in city #1999 so they match.
- `trailer/music.py` = the soundtrack: an original 120 BPM synthwave track made from maths (no
  samples, so no copyright problems). 1 bar = 2 seconds. `SECTIONS` says which instruments play when.
- `trailer/cards.py` = the captions and the CYPURRPUNK title, as chunky pixel letters.
- `trailer/edit.py` = the **edits**. Each trailer is a list of `(shot, start second, length, caption)`.
  Change a caption's words, swap a shot, or move its start point, then run `edit.py` again. The
  lengths must add up to the music's length (it warns you if not).
- `python trailer/contact.py` makes a picture per shot (`shots\trailer\contact\`) with a frame every
  half second, handy for picking start points.

**Thumbnail:** `python trailer/thumbnail.py` turns stills in `shots\thumb\` (`raw_a.png`, `raw_b.png`) into
1280x720 YouTube thumbnails (`thumbnail_red.jpg`, `thumbnail_blue.jpg`): logo top-left, "REVEAL TRAILER"
bottom-left (change `TAG` in the script). The stills are the hero cat with the MEGA VAC-COP behind it,
taken with DevCapture `--heat=100 --roomba=boss --no_boss_sign --bait_roomba=-7 --portrait=me --portrait_side=0.5`
(`raw_b` = after 80 frames, red siren; `raw_a` = after 40 frames, blue siren).
`thumbnail_gunfight.jpg` uses `gun_40.png`: the cat firing the PURR-TOMMY from the side as a VAC-COP explodes
(`--give=tommy_gun --pos=0,0,-20 --bait_roomba=aim --hold=shoot --hold_frames=40 --keep_holding --frames=1`
`--cam_from=-3.2,0.45,-21.6 --look_from=0.2,0.55,-21.8 --no_hud`). Each thumbnail's still, framing, logo spot and tag
are listed in `THUMBNAILS` at the top of the script.

**Uploading:** TikTok / Reels / Shorts take the vertical files as they are. Add your store link
(Steam / itch.io) in the post text; the trailers end on "COMING SOON" — change that card in `edit.py`
once there's a wishlist page.

---

## 16. Building new things (the frameworks)

The game already has "add a card, no code" systems for items (§9), NPCs and quests (§8), cat
accessories (§11) and sounds (§12). This section covers the frameworks for the bigger pieces:
new game systems, game events, money, things you press E on, new enemies, new things you can shoot, and new places to build.

### Game systems (`scripts/game_systems.gd`, class **GameSystems**)
A **game system** is a node under **Main** that the host runs and that keeps something for every
player or for the whole game. Today these are: **GetawayCar** (who drives), **Items**, **Quests**,
**Heist** (the exit), **Wallet** (cash), **Health**, **Heat** and **Roombas** (the patrol).

Each one joins the group `game_systems` and answers any of three calls. game.gd just calls
"everyone in the group", so it never needs to know which systems exist:

| Call | When (host only) | Example |
|---|---|---|
| `start_district()` | a game starts, or the crew moves to a new district | Heat goes back to 0, a fresh patrol, the car is parked |
| `send_state_to(peer)` | a computer joins mid-game | send everyone's cash to the newcomer |
| `player_left(player_id, last_position)` | a player quits | forget their HP; drop their gear at `last_position` |

**Adding a new system** (e.g. the planned SCRAP or MAINFRAME):
1. In `main.tscn`, right-click **Main > Add Child Node > Node**, name it (e.g. `Mainframe`).
2. Attach a new script. In its `_ready()` write `add_to_group(GameSystems.GROUP)`.
3. Write only the calls from the table that it needs. That's it: late joiners, quitting players
   and new districts are handled without touching game.gd.

The calls go top to bottom in the scene tree order of `main.tscn`. **Items** must stay above the
systems that read items (it sends the items a late joiner needs first).

### Game events (`scripts/events.gd`, the autoload **Events**)
The big moments of a raid are announced in one place. The system where something happens just
says so; anything that cares listens. Nobody has to know who else is listening.

| Event | When | Heard on |
|---|---|---|
| `district_sealed()` | max heat: the hatch seals, the DEEP CLEAN starts | every computer |
| `player_extracted(player_id, loot_value, quest_bonus)` | a player climbed down the exit | every computer |
| `player_downed(player_id, cause)` | a cat hit 0 HP and waits for a revive | every computer |
| `player_revived(player_id, by)` | a teammate picked a downed cat back up | every computer |
| `player_robbed(player_id, by)` | a rival robbed the loot in a downed cat's backpack | every computer |
| `player_knocked_out(player_id, cause)` | a cat is out for good (bled out, gave up, solo, DEEP CLEAN): loot spills | every computer |
| `heat_level_changed(level)` | the heat went up (or down) a level | every computer |
| `item_picked_up(player_id, item_id)` | someone grabbed or bought an item | host only |
| `enemy_destroyed(enemy)` | a VAC-COP (or any enemy) blew up | host only |

**Listening** (e.g. the planned MAINFRAME losing a chunk when a district is sealed):
```
func _ready() -> void:
	Events.district_sealed.connect(_on_district_sealed)

func _on_district_sealed() -> void:
	if multiplayer.is_server():   # game rules: only the host changes them
		print("the MAINFRAME loses a chunk")
```
The Roomba patrol already works this way: it sends in the DEEP CLEAN swarm when it hears
`district_sealed`. **A new event:** add a `signal` line to `events.gd` (with a comment saying who
hears it) and call `Events.my_event.emit(...)` where it happens.
**Testing:** add `--event_log` to a test run to print every event as it fires (`[Events] ...`).

### Money (`scripts/wallet.gd`, class **Wallet**, the **Wallet** node)
Every player's cash lives in one place. The host is the only one who changes it; everyone has a
copy (for the shop page and the sewer scoreboard). Anything that pays or charges calls one line,
**on the host**:

| Line of code | What it does |
|---|---|
| `Wallet.instance.earn(player_id, 120, "sold scrap")` | give cash (the text is for the console log) |
| `Wallet.instance.spend(player_id, 50)` | take cash; returns `false` (and takes nothing) if they can't afford it |
| `Wallet.instance.cash_of(player_id)` | how much they have (works on every computer) |

The exit pays your loot this way, the Black Markitten charges this way, and your save file
(`player_profile.gd`) saves whatever the wallet says. A new way to earn or pay (selling scrap,
feeding the MAINFRAME) needs nothing else. Want to react when cash changes? Connect
`Wallet.instance.cash_changed` (it fires on every computer).

### Pressing E (`scripts/interactable.gd`, class **Interactable**)
Everything you can use with E goes through one system: street items, NPCs, payphones, the stash
lockers and the car. The cat just asks "what's the best thing in reach?" and uses it; the HUD
shows that thing's line ("[E] TALK TO DON CATLEONE", "[E] STORE YOUR SHIT", "[E] GET IN"). When two are
in reach, the higher **priority** wins (items 30, NPCs 20, stash 10, car 0), then the nearer one.

**Making something new usable, no code for the "where" part** (e.g. a MAINFRAME terminal):
1. Right-click the node it belongs to > **Add Child Node** > search **Interactable** > Create.
2. Move it to the spot. In the Inspector set **Prompt** (e.g. `FEED THE MAINFRAME`), **Radius**
   (how close you must be) and **Priority**.
3. Node dock (next to the Inspector) > **Signals** > double-click **used** > connect it to the
   script that should react. That function gets the cat that pressed E.

The stash (the litterbox) is made exactly like that, in code (`_build_stash()` in `scripts/hub.gd`).
**A thing with its own idea of "in reach"** (like the car's door zone or the street items) can
instead join the group `interactables` and write the answers itself:
`interact_distance(cat)` (metres, or -1 = not now), `interact_prompt(cat)` (the line, "" = none),
`interact(cat)`, and optionally `interact_priority()`. See the bottom of `scripts/getaway_car.gd`.
**Multiplayer:** this runs on the computer of the player who pressed E. Anything everyone must
see, or that changes items or cash, asks the host with an `@rpc` (like buying or picking up).

### Getting shot (`scripts/hit.gd`, class **Hit**)
When a gun fires, it finds what the bolt hit and hands it a **Hit**: who shot, which gun, the
damage (already rolled, crits included), which way the bolt flew and where it landed. The gun
doesn't care WHAT it hit. Each shootable thing has one function, `receive_hit(hit)`, that decides:

| Thing | What a hit does | Damage number? |
|---|---|---|
| Any enemy (VAC-COP, MEGA VAC-COP) | loses health (the host keeps score); explodes at 0 | yes |
| Another cat | gets shoved (the gun's **Cat Knockback** / **Cat Hop**) | no |
| The getaway car | gets pushed (the gun's **Car Impulse**) | no |

**Making something new shootable** (a breakable crate, a security camera...): give its script
```
func receive_hit(hit: Hit) -> bool:
	# e.g. ask the host to break it: break_me.rpc_id(1)
	return true   # true = the shooter sees a damage number
```
The function can sit on the node with the collision shape or on its parent (a few levels up is
fine), so a hitbox can be a child node. This runs on the **shooter's** computer, so anything
everyone must see goes through an `@rpc`.

### Enemies (`scripts/enemy.gd`, class **Enemy**)
Everything every enemy needs, in one place: **health** (synced, with the floating health bar once
shot), **getting shot** (`receive_hit` above), **getting run over** by the car, **exploding**
(drops what's inside it + **Drop On Destroy**, heats up the city, or cools it for a boss), and
**network gliding** for the other players. The VAC-COP (`roomba.gd`) is built on it, and only
says how a VAC-COP drives, chases and bonks.

**Making a new enemy** (e.g. a security drone):
1. Duplicate `scenes/roomba.tscn` as `drone.tscn` and give it a new **Model**: build one in
   Blockbench (§20) and drop the `.glb` in as the Model node, like `roomba.tscn` does. Keep a part
   called **Body** (it flashes when shot, or point **Flash Mesh** at another one) and one called
   **Eye** (the crit weak spot: **Eye Weak Spot** in the Inspector). The model gets the PS1 material
   by itself; list the parts that should glow, and their colour, in **Look > Glow Parts** (white =
   your script tints it while playing).
2. Make a new script that starts with `extends Enemy` and put it on the root (replacing
   roomba.gd). Its numbers (Max Health, Display Name, Drop On Destroy, sounds...) are already in
   the Inspector.
3. Write its brain in `_physics_process(delta)` (runs on the host only): move it, set
   `sync_position = global_position` and `sync_yaw = model.rotation.y` at the end, and call
   `if run_over_by_car(delta): explode()` if the car may squash it. Optional: `_on_hurt(shooter)`
   (got shot, still alive), and `_ready` / `_process` (start them with `super()` /
   `super(delta)` so the shared part still runs).
4. Spawn it on the host under a node a **MultiplayerSpawner** watches (like **Roombas** +
   **RoombaSpawner**), and connect its `destroyed` signal if the spawner should react (replace
   it, count kills...). Ask Claude to wire up the spawning.

Copy `scripts/roomba.gd` for a full working example.

### Building places in code (`scripts/level_kit.gd`, class **LevelKit**)
The city, THE SEWERS and the manholes are built by code, not by hand in the editor. They all use
the same kit of building blocks, so a new place (the MAINFRAME room, a new district type...) gets
the PS1 look and the rules below for free:

| Line of code | What it makes |
|---|---|
| `LevelKit.psx_material({"albedo_color": Color(0.3, 0.3, 0.3)})` | a material with the PS1 look (any `psx_lit` shader setting) |
| `LevelKit.add_box(self, center, size, material, true)` | a box; `true` = solid (cats and cars bump into it) |
| `LevelKit.add_cylinder(self, center, radius, length, material)` | a six-sided pipe or pillar |
| `LevelKit.add_light(self, at, color, energy, range)` | a pool of coloured light glowing into the fog |
| `LevelKit.add_sign(self, "TEXT", at, color, font_size, facing)` | glowing neon letters |
| `LevelKit.subdivided_plane(Vector2(w, d))` | a flat floor piece |
| `LevelKit.instantiate_model("trash_bin", self, at, yaw)` | a copy of `res://models/trash_bin.glb` with the PS1 look (§20) |
| `LevelKit.psx_ify(node)` | gives every mesh under a node the PS1 look, keeping its painted texture (§20) |

**The rules it keeps for you:** big surfaces are cut into ~2.5 m pieces (on big triangles the PS1
textures shear and "swim"), and boxes of the same shape share one mesh (a city has hundreds).
Give one box its own colour with `box.set_instance_shader_parameter("instance_tint", Color(...))`
instead of making a new material.
**The rule you keep:** never put two visible surfaces a few cm apart (a floor on a floor): they
flicker. Examples: `_build_shop()` and `_build_stash()` in `scripts/hub.gd`.

---

## 17. Playing on an Android phone (with a controller)

The game runs on an Android phone with a **Bluetooth controller** (Xbox, PlayStation...). There are
no touch controls yet. Touching the screen only clicks menu buttons, like a mouse would.

### What's already set up in the project
- **Project > Export...** has an **Android** preset (`export_presets.cfg`): 64-bit phones only,
  full screen ("immersive mode"), app name CYPURRPUNK, package `com.cypurrpunk.game`, and the
  network permissions online play needs (Internet, Wi-Fi state, and "Wi-Fi multicast", which lets the
  MULTIPLAYER screen find games on your Wi-Fi). Builds go to `build/android/` (not backed up by git).
- **Project Settings > Rendering > Renderer > Rendering Method (Mobile)** = **forward_plus**, the
  same renderer as on PC. The usual phone renderer ("mobile") has **no volumetric fog**, so the
  glowing light pools around lamps, signs and Roombas would vanish. Newer phones (Galaxy S25 and
  similar) handle forward_plus easily because the game only draws 320x240 pixels. If an older phone
  crashes or shows a black screen, change it back to **mobile** (the game still runs, just without fog).
- **Project Settings > Display > Window > Handheld > Orientation** = **Sensor Landscape** (sideways, either way up).
- **Project Settings > Rendering > Textures > VRAM Compression > Import ETC2 ASTC** = on (phones need it).
- On a phone the game skips the window size / fullscreen settings (`scripts/settings.gd` `apply()`).

### One-time setup on your PC
**Already done on this PC** (2026-10-27): the templates, the Android SDK (command-line tools +
platform-tools, build-tools 36.1.0, Android 36) and Java 17. Only needed again on a new computer.
The game has no icon yet, so the phone shows Godot's robot icon: set one in
**Project Settings > Application > Config > Icon** (a square PNG, 192x192 or bigger).

1. **Export templates** (the ready-made Godot engine for phones, about 1 GB): in Godot,
   **Editor > Manage Export Templates... > Download and Install**.
2. **Android SDK** (Google's tools that pack and install apps): the easiest way is to install
   **Android Studio** from developer.android.com/studio. Open it once and let the setup wizard
   install the SDK. It goes to `C:\Users\Nathaniel\AppData\Local\Android\Sdk`, which Godot is already
   pointed at. (You never need to open Android Studio again after that.)
3. **Java 17**: in Godot, **Editor > Editor Settings > Export > Android > Java SDK Path** =
   `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.8-hotspot` (it was set to Java 11, which is too old).
   While you're there, check **Android SDK Path** = the folder from step 2.

### One-time setup on your phone
1. **Settings > About phone > Software information**, tap **Build number** 7 times (it says
   "Developer mode has been turned on").
2. **Settings > Developer options > USB debugging** = on.
3. Plug the phone into the PC with a USB cable and tap **Allow** on the phone's "Allow USB debugging?" popup.
4. Pair the controller: **Settings > Connections > Bluetooth**, then put the controller in pairing mode.

### Putting the game on the phone
- **Quickest (phone plugged in):** a small **Android icon** appears at the top right of the Godot
  editor (next to the play buttons). Click it: Godot builds the game, installs it and starts it on the phone.
- **As a file:** **Project > Export... > Android > Export Project** (untick "Export With Debug" for
  a smaller, faster build) and save `build/android/cypurrpunk.apk`. Copy it to the phone and tap it
  to install (the phone asks once to allow installing apps from that place).

### Playing
- Press a button on the controller in the start menu: the controller becomes player 1's, exactly like on PC.
- **Online co-op with your PC:** both on the same Wi-Fi, host on the PC and join from the phone
  (or the other way round) on the MULTIPLAYER screen. If the game doesn't show up in the list, type the
  host's address instead.
- The first minute can stutter a little while the phone prepares the graphics for the first time.
- Your phone keeps its own saves (cats, cash, stash). They don't move between PC and phone.

### Known limitations (later work)
- No touch controls (on-screen stick and buttons). This is the big one if you want to play without a controller.
- Not tested on slower phones. If one struggles: turn **VOLUMETRIC FOG** off in **SETTINGS**, or
  use the **mobile** renderer (above).

---

## 18. Automatic builds and download links (Windows, Linux, Android)

Every time you push to `main` with GitHub Desktop, GitHub builds all three versions by itself and
puts them on the download page. You don't need Godot open, and your PC can be off.

### Where the downloads are
- **Front page of the project:** https://github.com/natjster/CYPURRPUNK has one-click download links.
  They always give the newest build, so send players that page.
- **Direct links:**
  - https://github.com/natjster/CYPURRPUNK/releases/latest/download/CYPURRPUNK-Windows.zip
  - https://github.com/natjster/CYPURRPUNK/releases/latest/download/CYPURRPUNK-Linux.zip
  - https://github.com/natjster/CYPURRPUNK/releases/latest/download/CYPURRPUNK-Android.apk
- **What changed:** the release page shows the date and your commit message for the newest build.

### Watching a build
- The badge at the top of the front page shows if the last build worked.
- For the details, open the **Actions** tab on GitHub. A yellow dot means building, a green tick
  means done, and a red cross means something failed. Click a run to read why.
- If you push again during a build, the old build stops and the new one starts.
- A failed build changes nothing: players keep the last good version.
- To rebuild without a new push: **Actions > Build > Run workflow**.

### One-time step: keep Android updates working
A phone only installs an update if it's signed with the same key as the version already on it. The
key is kept in a private GitHub secret so every build uses the same one. To add it:
1. Open `build/ci/keystore-base64.txt` in Notepad and copy everything in it.
2. On GitHub: **Settings > Secrets and variables > Actions > New repository secret**.
3. Name = `ANDROID_DEBUG_KEYSTORE_BASE64`, Secret = paste, then **Add secret**.
4. Keep a backup of `build/ci/cypurrpunk-debug.keystore` somewhere safe. Git doesn't back it up.

Until the secret is there, each build gets a new throwaway key. Those APKs install fine, but players
must uninstall the old version first, which also wipes their phone saves. The Actions page shows a
yellow warning when this happens.

### When you update Godot
Open `.github/workflows/build.yml` and change `GODOT_VERSION` (and `GODOT_EDITOR_SERIES`) near the
top to match. If you don't, GitHub keeps building with the old version.

### What runs where
- `.github/workflows/build.yml` is the build recipe GitHub follows.
- `export_presets.cfg` has the **Windows Desktop**, **Linux** and **Android** presets. Windows and
  Linux are packed into one file each, with no separate `.pck`.
- The Android file is a debug build, the same as "Export With Debug" in Godot.
- **Leave this setting alone:** `project.godot` has `export/convert_text_resources_to_binary=false`
  (**Project Settings > Editor > Export > Convert Text Resources to Binary** = off). With it on,
  exported games lost what NPCs say and they only said "...", even though it looked fine in the editor.

### Making a Windows build yourself
**Project > Export... > Windows Desktop > Export Project...**, or from PowerShell:
```powershell
& "C:\GoDot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" build/windows/CYPURRPUNK.exe
```

### Making a Linux build yourself

**Project > Export...** has a **Linux** preset (`export_presets.cfg`) set up to pack the whole game into a single file (`build/linux/cypurrpunk.x86_64`, with `Embed PCK` switched on so there is no extra `.pck` file to lose).

- **In Godot:** **Project > Export... > Linux > Export Project...**, untick **Export With Debug**, and click **Save**.
- **Or from PowerShell:**
  ```powershell
  & "C:\GoDot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Linux" "build/linux/cypurrpunk.x86_64"
  ```
- **Running on Linux:** unzip/download `cypurrpunk.x86_64`. If double-clicking doesn't launch it right away, right-click the file > **Properties > Permissions > Allow executing file as program** (or run `chmod +x cypurrpunk.x86_64 && ./cypurrpunk.x86_64` in a terminal).


## 19. The TUTORIAL (PLAY > TUTORIAL)

A guided training run that walks a new player through one whole raid. Click **PLAY > TUTORIAL**
on the start menu: it starts right away with the cat you have selected (no cat screen), always in
the same city (#1999, Meow-Mart right next to the manhole you come up from).

### What the player sees
- A **box at the top of the screen**, under the "THE SEWERS" line: the step in **yellow** and a
  **white** line saying exactly what to do (with your own keys / buttons).
- Right under the box, the real game's **big GREEN ARROW** (the same one that points at payphones
  and exits in a normal raid), pointing at where to go, with the name and distance under it:
  `LIL' MITTENS  19m`, `SHOP`, `LITTERBOX`, `MAINFRAME`, `DON CATLEONE`, `FISH`, `VAC-COP` /
  `SCRAP`. It hides when the target is on the other level (city vs sewers).
- A **glowing cyan beacon** (a spinning arrow over a ring of light) floating above the place to go,
  on every step **except step 8**.
- **Step 8 teaches the real way out:** no beacon, just the green arrow, exactly like a real raid.
  First it says `PAYPHONE  54m` and points at the nearest ringing payphone; the moment you press E
  on it, Don's line floats above the phone, the step line changes to **FOLLOW THE GREEN ARROW TO THE
  EXIT** and the arrow flips to `EXIT  57m`.
- At the end: a big **TUTORIAL COMPLETE! YOU'RE READY FOR MEOW-CITY.** banner, then back to the start menu.
- The pause menu's leave button says **EXIT TUTORIAL** (quit any time).

### The 9 steps
| Step | What to do | Done when |
|---|---|---|
| 1 | Talk to **Lil' Mittens** (east wall boxes), take MITTENS' FISH | the quest is active |
| 2 | Buy a weapon from **Comrade Whiskers** (PAW-PISTOL $60 / NEON BAT $20) | you hold or carry any gear |
| 3 | Open the **stash lockers** (east wall), then close them | closed again, still carrying a weapon (if you left it inside, it asks you to take it back) |
| 4 | Walk up to **the Mainframe** (west wall CRT) | you stood within 3.5 m for 1.5 s |
| 5 | Talk to **Don Catleone**: SEND ME UP TOP | you're up in the city |
| 6 | Grab **3 fish** (the line counts 0/3, 1/3...) | 3 fish in your backpack |
| 7 | Smash a **VAC-COP**, then pick up the **SCRAP** it drops | scrap (and still 3 fish) in your bag |
| 8 | The heat jumps to **75**: follow the green arrow to a ringing **payphone** (E), then follow it again to the **exit manhole** | you extracted |
| 9 | Feed the scrap to **the Mainframe** (E) | it charged (+25%) |

### The training rules (only in a tutorial)
- **Your real save is never touched.** You get a training save every time: **$100**, an **empty stash**.
  Whatever you earn or buy is gone when the tutorial ends.
- **The heat is frozen** (no surprise DEEP CLEAN). At step 8 it jumps to the exit heat (75) so the
  exit opens and the payphones ring straight away.
- **You can't be knocked out:** your HP never drops below 25.
- **The 6-slot backpack** has room for the 3 fish AND the scrap; they come home in it.
- **Don won't send you up** before step 5 ("Finish your prep down here first").
- **Spare fish:** if there aren't enough fish near you, one appears at the centre crossroads every 3 s.
- **Step 7:** if no VAC-COP is within 25 m, one is moved 12 m in front of you, and the one you smash
  drops scrap (normally only MEGA VAC-COP bosses do). If a bot bonks a fish out of your bag, the
  line tells you to grab it back.
- Your Mainframe starts at 75%, so the scrap at the end takes it to 100% (OVERCLOCK).

### Changing it (no code)
Select **Tutorial** in `scenes/main.tscn` (Scene dock: **Main > Tutorial**). In the Inspector:
- **The Training Run:** City Seed, Mainframe Charge, Min Health, Quest Id, Fish Needed, Exit Heat.
- **Helping Out:** spare fish search / seconds, how far a VAC-COP is moved, the Mainframe visit distance / time.
- **Look:** step / hint colours; the beacon's colour, height, bob and spin. (The green arrow's own
  look is on `scenes/ui/hud.tscn` > **Frame > Top > Compass**.)
- **Finale:** the banner text, colour, and how long before going back to the menu.
- **Step 1 ... Step 9:** every line of text. In the text, `{E}` becomes your interact key, `{TAB}`
  your inventory key, `{fish}` / `{need}` the fish count, `{heat}` the exit heat. Step 8 has two
  titles: **Step8 Title** (before the payphone) and **Step8 Exit Title** (after it), with
  **Step8 Hint** / **Step8 Exit** under them.

The HUD box is `scenes/ui/hud.tscn` > **Frame > Top > TutorialBox** (a PanelContainer with
**TutorialStep** and **TutorialHint** labels): move or restyle it there.

### How it fits together (for the curious)
- `scripts/tutorial.gd` (class `Tutorial`, the **Tutorial** node under Main) is a Game System
  (§16): `start_district()` starts step 1. It only does anything while `Game.is_tutorial()` is true.
- `scripts/game.gd` `tutorial_game()` (from the menu's `tutorial_pressed` signal) sets up the
  training rules (`Tutorial.prepare()`) and starts a solo game. `scripts/player_profile.gd` hands
  out the training save; `hub.gd` asks `Tutorial.allows_deploy()`; `cat_health.gd` asks
  `Tutorial.health_floor()`.
- The green arrow (`Compass`, `scripts/ui/hud_compass_arrow.gd`): `tutorial.gd` points it on steps
  1-7 and 9; `fish_heist.gd` leaves it alone then, and drives it as normal on step 8.

### Testing it without playing
```powershell
& "C:\GoDot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -- --tutorial --tutorial_auto --capture=shots/t.png
```
`--tutorial` starts a tutorial run; `--tutorial_auto` plays all 9 steps by itself and prints a
`[Tutorial] Step X/9: ...` line for each, then `TUTORIAL COMPLETE!`, checks the start menu came
back and the real save wasn't touched, and quits (exit code 0 = passed, 1 = a step got stuck).
It also prints `DevCapture tutorial arrow ...` lines (what the green arrow says, beacon on/off) at
step 1, step 8 before the payphone and step 8 after it. Add `--tutorial_shots` and leave out
`--headless` to also save `shots/tutorial_step1_arrow.png`, `tutorial_step8_payphone.png` and
`tutorial_step8_exit.png`.


---

## 20. Real models from Blockbench + Claude's tool servers (Model Shop, Sound Lab, Icon Studio)

The game is moving from code-built boxes to real low-poly models (ROADMAP.md §5). The first two
were the **trash bin** and the **traffic cone** you see on street corners and in empty yards; the
**getaway car** (the WEDGE CYBER-INTERCEPTOR, section 3) is one too.

### The folders
| Where | What | Who edits it |
|---|---|---|
| `models/blockbench/*.bbmodel` | the **Blockbench projects** (the master copy of each model, texture inside) | you, in Blockbench (double-click the file) |
| `models/*.glb` | what **Godot** loads (made from the .bbmodel) | nobody by hand: it's exported |
| `tools/model_specs/*.json` | Claude's "recipes" the starter models were built from | Claude |
| `tools/sound_specs/overclean.json` | the list of every OVERCLEAN line + effect the Sound Lab made | Claude |

Starter templates, also in `models/blockbench/`:
- `template_cat.bbmodel`: a cat the same size as the game's cat, with the part names the colour
  system needs (Body, Belly, LegL/LegR, Head, Muzzle, Nose, EyeL/EyeR, EarL/EarR, Tail) in the
  groups **Body, Paws, Head (with Ears inside), Tail**, plus three markers: **hat**, **shades**,
  **neck** (where accessories go). Facing north. Model your cat over it and keep the names.
- `template_roomba.bbmodel`: the VAC-COP, with the groups the enemy code looks for: **Body, Eye,
  SirenRed, SirenBlue, Brush**. Keep those names.

**The real ones (in the game since 10 Nov 2026):** `roomba.bbmodel` (VAC-COP and MEGA VAC-COP), `lint_trapper.bbmodel` and
`squirt_drone.bbmodel` (§8). They were first made from recipes in `tools/make_creature_specs.py`
(rounded heads, eyes and octagonal shells are worked out with a bit of maths there); from now on the
.bbmodel files are the master copies: edit them in Blockbench and ask Claude to re-export. Group
names the game needs: the bots need **Body** (flashes when shot), **Eye**
(glows, crit weak spot), **SirenRed**, **SirenBlue**, plus **Brush/Brush2** (VAC-COP brushes),
**Brush** + **Tank** (LINT-TRAPPER roller + glue canister), **Rotors > Rotor1..4** + **Tank**
(SQUIRT-DRONE). A group's pivot is where it turns (brushes, rotors). (`cat.bbmodel` is a mascot cat
that was tried for player cats and reverted on 10 Nov 2026: the game uses the original cat, §11.)

**The weapons (since 10 Nov 2026):** all eight (`pistol`, `tommy_gun`, `frozen_tuna`,
`hairball_blaster`, `yarn_zooka`, `cucumber_launcher`, `neon_bat`, `red_dot` .bbmodel) come from
recipes in `tools/make_weapon_specs.py` and share one 128x128 texture sheet. How they plug into the
weapon scenes, and which parts glow: §9 "The weapon models".

**The rules (from ROADMAP.md):** props under **150 triangles**, characters under **600**,
vehicles under **500**; textures **64x64** (props) or **128x128** (characters, vehicles, and the
weapons' shared sheet). In Blockbench 16 pixels = 1 metre, Y is
up, and the front of a model faces **north**.

### Changing a model yourself
1. Double-click `models/blockbench/trash_bin.bbmodel` (Blockbench opens it).
2. Repaint it (Paint tab) or move / add boxes (Edit tab). **Ctrl+S** to save.
3. Tell Claude "re-export the trash bin" (or run the line below). The new look is in the game the
   next time it starts. Blockbench's own **File > Export > Export glTF Model** (saved over
   `models/trash_bin.glb`) also works.
```powershell
python tools/cypurr_models.py export models/blockbench/trash_bin.bbmodel
```
It prints the triangle count, texture size and groups, and says **NEEDS WORK** if a rule is broken.

### Putting a model into the game (code)
`LevelKit.instantiate_model("res://models/trash_bin.glb", parent, position, yaw)` loads the
model once, puts a copy where you say, and gives it the game's PS1 look: the wobbly vertices,
flat shading and crisp pixels of `psx_lit.gdshader`, keeping the model's own painted texture and
colours. `LevelKit.psx_ify(node)` does just the look, for a model that's already in a scene.
Models have **no collision** on their own: the city puts each bin inside a `StaticBody3D` with a
box (`_add_bin` in `scripts/city_generator.gd`); cones stay walk-through so cars don't stop dead.

**In the editor (no code):** you can drag a `.glb` from the FileSystem dock into a scene. It looks
plain there (Godot's normal material); call `LevelKit.psx_ify($TheModel)` in that scene's script
to give it the PS1 look, or ask Claude.

**Import settings:** a new `.glb` comes with a `.glb.import` file that keeps the texture inside
the model, uncompressed (exact pixels), without level-of-detail copies. Changes you make in
Godot's **Import** tab stay (the export never overwrites an existing .import file).

### How many bins and cones (no code)
Select **City** in `main.tscn` > Inspector > **Street Props (Blockbench Models)**:
**Trash Bin Model / Traffic Cone Model** (which .glb files), **Yard Bins Min/Max** and
**Yard Cones Min/Max** (the junk pile in each empty yard; some cones lie knocked over),
**Corner Prop Chance** (0-1, per sidewalk corner), **Props At Meow Mart**, **Bins Are Solid**.
They're placed with the city's own random numbers, so every player's city still comes out identical.
(This changed the layout of every city seed once: a seed now gives a different city than before.)

### Claude's tool servers (`.mcp.json` + `tools/`)
`.mcp.json` (in the project folder) lists two small helper programs that **Claude Code starts by
itself** when it works in this project (the first time, it asks you to allow them: say yes).
They give Claude new tools. You never run them; they're free and run on this PC.

| Server (file) | Tools it gives Claude |
|---|---|
| **Model Shop** (`tools/model_mcp.py`) | `create_or_edit_bbmodel` (write/change a Blockbench project: boxes, round cans and cones, free-form "poly" shapes like the car's wedge, groups, markers, a painted pixel-art texture), `export_bbmodel_to_glb`, `inspect_model` (triangles, texture size, groups vs the rules), `list_models` |
| **Icon Studio** (`tools/icon_mcp.py`) | `make_item_icon` (an orthographic SIDE PROFILE of any item, rendered from its real scene / .glb: white with darker detail lines, so the HUD can colour it), `make_status_icon` (the sticky paws / catnip / catdip badges), `make_npc_portrait` (coloured head-and-shoulders portrait of a sewer NPC, or `locked_mystery`: a dark silhouette with a "?"), `make_all_icons`, `list_icons` |
| **Sound Lab** (`tools/sound_mcp.py`) | `generate_overclean_voice` (free text-to-speech + robot + loudspeaker echo + chime), `generate_cat_voice_blips` (Animal Crossing style talking cats: `meow_blip_<name>_1..4.wav`; soft and rounded by default, ask for "crunch" for the old harsh PS1 chatter), `generate_ps1_sfx` (crunchy effects: bin clatter, cone bounce, scratch, PA chime, metal clang, plastic tap, or a custom recipe), `list_sounds` |

The real work is in `tools/cypurr_models.py`, `tools/cypurr_sound.py` and `tools/cypurr_icons.py`,
which also run from a terminal (each prints its instructions when run with no arguments).

**Icons** (`ui/icons/`): `items/<id>.png` (64x64 side profiles of every held item and loot),
`status/<id>.png` (32x32 badges), `npcs/<id>.png` (64x64 portraits of all 14 sewer NPCs +
`locked_mystery.png`). The icon tool reads the scenes the way Godot does (BoxMesh / SphereMesh /
CylinderMesh / CapsuleMesh / PrismMesh / TorusMesh sizes, node positions / rotations / scales, and
the .glb files the guns use), so after a model changes, remake its icon:
```powershell
python tools/cypurr_icons.py all
C:\GoDot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
```
How each item is looked at (side view, from above for round tins, laid down for melee) is the
`ITEMS` table at the top of `tools/cypurr_icons.py`. Remake every OVERCLEAN line:
```powershell
python tools/cypurr_sound.py batch tools/sound_specs/overclean.json
```

**One-time setup on a new PC:** Python 3, then `python -m pip install -r tools/requirements.txt`,
and ffmpeg (`winget install Gyan.FFmpeg`). The voice needs internet while it's being made (it uses
Microsoft Edge's free voices); the game never does. `tools/` has a `.gdignore`, so Godot skips it.
If Claude says the tools aren't there, restart Claude Code in this folder (or type `/mcp` in a
terminal Claude Code to see them).

---

## 21. OVERCLEAN, the announcer (`scripts/overclean_announcer.gd`)

OVERCLEAN talks over the city's loudspeakers: a two-tone chime, then a calm, polite, slightly
robotic voice with an echo off the buildings. **Nothing appears at the bottom of the screen:** the
words **type out as floating cyan text beside the horns of the LOUDSPEAKER POLE NEAREST YOU**, in
time with the voice, and vanish a moment after it ends. Only that one pole shows them, and only
when you're within about **10 m** of it (split screen: each player gets their own nearest pole).
Walk over to another pole halfway through and the words carry on there.

### The loudspeaker poles
- A tall steel pole on a concrete base, a junction box with an OVERCLEAN stencil, three flared
  megaphone horns facing the street, and a little light on top that blinks **red and cyan while
  OVERCLEAN talks**. Model: `models/loudspeaker.glb` (104 triangles, 64x64 texture; master copy
  `models/blockbench/loudspeaker.bbmodel`, recipe `tools/model_specs/loudspeaker.json`, §20).
- Scene: `scenes/props/loudspeaker.tscn`:
  ```
  Loudspeaker (StaticBody3D, scripts/loudspeaker.gd)
  ├── PoleShape / BaseShape   (cats and cars bump into it)
  ├── Model                   (the .glb, made PS1 when the city loads)
  ├── LedGlow + LedLight      (the blinking light)
  └── Readout (Label3D, scripts/ui/floating_line.gd, groups "hud_name_tags" + "overclean_speakers")
  ```
  Select **Readout** to change Wrap At (40 letters per line), Text Height (how big the words are),
  Readable From (10 m: how close you must be), Fade Over (2 m: it fades out over the last
  bit), Hold Seconds, Biggest Font Size. Move it to move the words.
  Select the root for the light's Idle / Talking Color and brightness.
- **Where they stand:** the city puts them on sidewalk corners, horns towards the street, never
  on top of a lamp post or corner prop. **Main > City** > Inspector > **Loudspeakers**:
  **Loudspeaker Chance** (0.4 = about 14 poles per city; 0 = none), **Loudspeaker Along** (how far
  from the very corner). They come from the city number, so every player has the same poles.
- Test: `--host --near_speaker=6 --speaker_side=1.5 --speaker_turn=-22 --pitch=6 --announce
  --frames=130 --capture=shots/loudspeaker_readout.png` (prints `DevCapture speaker:` lines:
  how many poles, and how many typed the line: should be 1; `--announce=seal|level2|ko|...` picks the line).

| Moment | What it says (on the poles) | File in `sounds/sfx/` |
|---|---|---|
| The first cat of a district climbs up top | "Unregistered shedding has been detected..." (one of 3) | `overclean_deploy_1` .. `_3` |
| Heat level 2 | "Cleanliness alert. Hairball levels exceeding municipal tolerance..." | `overclean_level2` |
| Heat level 3 | "Warning. Unauthorized fish handling in progress..." | `overclean_level3` |
| Heat level 4 | "Critical mess threshold reached..." | `overclean_level4` |
| A MEGA VAC-COP rolls out | "Heavy sanitation unit deployed. Have a spotless day." | `overclean_boss` |
| Heat 100: the hatch seals (DEEP CLEAN) | "Sector quarantine initiated. Commencing total Deep Clean..." | `overclean_seal` |
| A cat is knocked out up top | "One stray removed from the premises. Street hygiene restored by 14 percent." | `overclean_ko` |

**Who hears it:** only players who are **up top** (the speakers are in the city; the sewers are
safe). The seal is the exception: everyone hears it. Lines never talk over each other (they wait
their turn), each heat level is said once per district, and the boss and knockout lines have a
cooldown so they don't repeat. It stays quiet in the TUTORIAL.

**Changing it (no code):** select **Announcer** in `main.tscn` (Scene dock: **Main > Announcer**).
Inspector: **Enabled**, **In Tutorial**, **Volume Db**, **Min Gap Seconds**, **Subtitle Prefix /
Color** (written in front of / the colour of the words on the poles), then one group per moment
with its **sound** (a file name in `sounds/sfx/` without `.wav`), its **line** (the words on the
poles), and delays / cooldowns. Changing the words doesn't change what the
voice says: ask Claude to remake that line with the Sound Lab (or edit
`tools/sound_specs/overclean.json` and run the batch command in §20), and keep the two matching.

**Adding a new announcement from a script:**
`OvercleanAnnouncer.instance.say("overclean_my_line", "The words on the poles.")`
(add `true` to make everyone hear it, not just players up top).

**Where the moments come from:** game Events (§16): `player_went_up` (new, fish_heist.gd),
`heat_level_changed`, `boss_deployed` (new, roomba_patrol.gd), `district_sealed`,
`player_knocked_out`. The words go to every pole's **Readout** (group `overclean_speakers`).

**Testing:** `--deploy --heat_ramp=40 --sound_log --frames=3300` (plus `--capture=shots/x.png`)
sends your cat up and raises the heat to 100 over 40 seconds; the console prints an
`[Announcer]` line for each announcement (and `[Sound] overclean_...`).

## 22. The RAID REPORT (end of every district)

When a district ends, the whole window turns into a **report card for the round** before the next
city is built. It's meant to be the moment your friends laugh about, and a good 10-second clip.

**One screen per computer.** With 2-4 players on one couch, the split screens and everyone's HUD
fold away behind ONE big report that everyone reads together (like the pause menu covers the whole
window). Online, every computer shows its own copy of the same report.

**What it shows:**
- **RAID REPORT**, the district number, and how it ended for the crew: CLEAN GETAWAY (everyone
  who went up came home), MESSY GETAWAY (someone got vacuumed), CAUGHT IN THE DEEP CLEAN (someone
  was still up top after the seal), NOBODY LEFT THE COUCH, SURVIVED THE SEWER BREACH, or WIPED OUT
  BY THE BREACH.
- **A table with one row per cat** in the game (every computer's): name (with a little square in
  the cat's fur colour) and under it how their raid ended (EXTRACTED / VACUUMED / STAYED HOME /
  LEFT EARLY, "(LEFT)" if they quit afterwards); CASH brought home (quest bonus on its own line);
  BOTS smashed (MEGA VAC-COPs called out); DOWN/REV = times downed / team-mates revived; the AWARD;
  and READY. A cat whose player quit keeps their row.
- **Players on THIS computer** get a coloured **P1..P4** tag and their name in their seat colour
  (the same colours as the lobby and their pause menus). Other computers' cats are plain.
- **One silly award per cat**, stamped down last, one by one (that's the clip). Every cat gets
  exactly one, never two cats the same.
- The crew's **CASH BROUGHT HOME**, the countdown with **WAITING FOR N**, and an optional Discord line.
- **TURF WAR:** the same table, with each gang's name, colour and cash above its cats. No winner.
- No report in the **TUTORIAL** or behind the start menu.
- The reveal and its sounds play once per computer, however many players sit there.

**READY (one per player):** each player presses their own GRAB / TALK button (or A / Enter): the
READY appears on THEIR row only. Until then their row shows their button, blinking ([E] for player
1 on the keyboard, the controller button for pad players). A controller nobody has claimed does
nothing, and sticks / d-pads never change anything. No mouse needed.

**How long it holds the next district:** up to **14 seconds** (a bit longer with lots of cats so
every award is seen). When every player in the game is READY the next district starts at once, but
never before the awards have all been shown plus 2 seconds. While it's up the hatch is sealed and
everyone is home, so nothing can hurt anyone, and nobody's cat moves, shoots, opens the inventory or
drives.

**Esc / START:** player 1's Esc (or START on player 1's controller) opens the pause menu ON TOP of
the report, so someone can still leave the game. Close it and the report is still there (the clock
keeps running underneath). Players 2-4's START does nothing while the report is up, and while
player 1's pause menu is open only player 1 can press anything.

### Changing it (no code)
The numbers and timing: open `scenes/main.tscn`, click **Main > RaidReport**. Inspector:
- **Timing > Enabled**: untick to switch the report off (districts change straight away).
- **Timing > Report Seconds** (14): the longest it stays up.
- **Timing > Read Seconds After Awards** (2): how long it stays after the last award, even if
  everyone pressed READY.
- **Timing > Intro / Card / Award Seconds** (0.8 / 0.45 / 0.75): the speed of the reveal (Card = one
  row).
- **Extras > Discord Invite**: type e.g. `MORE CATS: discord.gg/yourcode` and that line appears at
  the bottom of every report (the host's text is used). Empty = no line.
- **Extras > Show Mess Stat**: the **MESS** number on every row (on; untick to hide it).
- **Colours**: the EXTRACTED / VACUUMED / STAYED HOME colours and the good / bad ending colours.

The look of the screen: in `scenes/main.tscn` click **Main > PS1Overlay > RaidReportScreen** (it
sits with the other full-screen menus, just above PauseMenu so the pause menu draws on top).
Inspector (sizes are in GAME PIXELS: the picture is 240 tall, 320 wide on 4:3):
- **Text Sizes**: Title Size (16) and Compact Title Size (12, used with lots of cats), Subtitle Size,
  Row Size / Small Size (8 / 7: names and numbers / the small second lines), and with up to
  **Roomy Rows** (4) cats the bigger **Roomy Row Size / Roomy Small Size** (10 / 8), used only if
  they fit the screen without shrinking.
- **Layout**: Line Squeeze (pulls a row's two lines together with lots of cats, so 8 fit), Column
  Gap, Margin, Dim (how dark the game behind gets), Min Scale (it shrinks to fit only as a last
  resort: shrinking blurs small text in the PS1 look), Max Name Letters (longer names get "...").

The table is built by code (`scripts/ui/raid_report_screen.gd`), so the scene only has the empty node.

Sounds (`sounds/sfx/`, made with the Sound Lab): `report_open` (when it appears), `report_row`
(each row), `report_award` (each award stamp). Replace a file with your own of the same name.

### The awards (and adding your own)
Each award is a card in the `raid_awards/` folder (FileSystem dock). Click one to see it in the
Inspector:
- **Title** (big, keep it about 14 letters) and **Line** (small, about 18 letters; `{value}` becomes
  the number, e.g. `LOST {value} LOOT TO BOTS`). The whole report shares one 240-pixel-tall screen.
- **Stat**: which number decides it: `cash`, `loot`, `bonus`, `bots`, `bosses`, `downs`, `revives`,
  `damage`, `vacuumed` (loot a VAC-COP sucked out of them), `knockouts`, `robbed`, `went_up`,
  `extracted`, `left`, `mess`. Empty = anyone (a safety-net award).
- **Pick**: MOST or LEAST of that stat wins. **At Least / At Most**: who qualifies (e.g. At Least 1
  = did it at least once). **Needs**: another stat that must be 1+ (GHOST needs `extracted`).
- **Order**: lower numbers are handed out first. **Color**: the title's colour.

How they're handed out: cards are tried in Order; each goes to the best cat that doesn't have one
yet and qualifies; a tie goes to the cat higher up the report (who joined first). The host works
it out once and sends it to everyone, so every screen agrees.

| Order | Award | Goes to |
|---|---|---|
| 10 | BIG FISH | most cash brought home |
| 20 | AMBULANCE | most revives |
| 30 | MEGA MAULER | most MEGA VAC-COPs smashed |
| 40 | BUTTERPAWS | most loot vacuumed out by bots |
| 50 | MOST SHED | most damage taken |
| 60 | FLOOR INSPECTOR | downed 2+ times (most) |
| 70 | BOT BLENDER | 3+ VAC-COPs smashed (most) |
| 80 | SIDE HUSTLE | most quest bonus |
| 90 | STICKY PAWS | robbed a rival (TURF WAR) |
| 100 | AGENT OF CHAOS | most mess made (waiting for Phase 1) |
| 110 | DUST BUNNY | got vacuumed |
| 120 | GHOST | made it home without a scratch |
| 130 | EMPTY PAWS | made it home with $0 |
| 140 | COUCH POTATO | never went up |
| 150 | GONE FISHIN' | quit before the end |
| 200-270 | WARM LOAF, BACKGROUND CAT, GOOD KITTY, SUSPICIOUSLY QUIET, SNACK BREAK, MORALE OFFICER, PARTICIPANT, NAP CHAMPION | anyone left (safety net) |

**To add one:** right-click a card (e.g. `butterpaws.tres`) > **Duplicate...**, give it a new file
name, then change its **Id** (unique, no spaces), Title, Line, Stat and Order in the Inspector. No
code. Keep at least 8 safety-net cards (empty Stat) so 8 players always get different awards.

### MESS
Every bin, cone and box a cat knocks over and every poster it scratches (§23) counts as one mess
(`Events.mess_made`, sent by `mess_manager.gd` on the host). Each row shows **MESS N**, and the
**AGENT OF CHAOS** award ("MADE N MESSES") goes to the biggest slob.

- STREET PROPS PACK models (all props, under 150 triangles, 64x64 textures with dithered grime):
  `vending_machine` (42 tris; groups **Screen** = glows, **Flap** = pivot on its top edge),
  `fire_hydrant` (100; **Cap**), `shopping_cart` (98; **Handle** = glows pink, **Wheels**),
  `neon_sign_prop` (30; **SignFace** = glows), `dumpster` (74; **Lid** = pivot on the BACK hinge).
  Keep those group names if you repaint them in Blockbench. Recipes come from
  `python tools/make_street_prop_specs.py` (re-running it REPLACES the .bbmodel files), then
  `python tools/cypurr_models.py all tools/model_specs/<name>.json`. The model kit gained a `dither`
  paint op (PS1 ordered dithering).
- STREET PROPS PACK sounds: `python tools/cypurr_sound.py batch tools/sound_specs/street_props.json`
  (no internet needed; Sound Lab presets `vending_smash`, `hydrant_burst`, `cart_roll`, `sign_spark`,
  `dumpster_rummage`).

### How it works (for Claude / the curious)
`scripts/raid_report.gd` (node **Main > RaidReport**, a game system: §16) counts everything on the
host from game Events (`player_went_up`, `player_extracted`, `player_downed`, `player_revived`,
`player_robbed`, `player_knocked_out`, `enemy_destroyed`, `sewer_breach_ended`, and `player_hurt`
(cat_health.gd), `loot_vacuumed` (item_manager.gd), `mess_made` (mess_manager.gd, §23)). The two places a
district ends (`fish_heist.gd` after the DEEP CLEAN, `mainframe.gd` after a breach banner) call
`RaidReport.end_district()`; the host builds the report once and sends it to every computer, where
`RaidReportScreen` (one per computer) shows it; then the host calls `Game.new_district()` itself.
`RaidReportScreen.is_up()` is the one "is the report up here?" check: `Hud.menu_open()` counts it
(HUDs and split screen fold away), cats ignore their buttons, and `game_screen.gd` hands every local
player's presses to it with their seat.

### Testing
- `--raid_report[=N]` (host): end the district now with made-up numbers (N = that many rows; made-up
  quitters fill the gap). `--raid_report_after=F` waits F frames first. Every report prints
  `DevCapture report` lines (the crew line, one per row with its award, `awards: ... (OK)` when none
  repeat, the screen's scale and whether split screen folded away) and, once it closes,
  `DevCapture after report` (split screen, HUDs and moving cats back).
- `--report_ready=A,B,...` (with `--report_ready_delay=N` frames): real presses, one by one:
  `S` = seat S's own button, `S:pad`, `S:key`, `S:stick` (must do nothing), `spare:D` (an unclaimed
  controller, must do nothing), `S:pause` (Esc / START). Prints who's ready and whether the report /
  pause menu are up.
- Four on a couch: `--solo --join_pad=1,2,3 --raid_report=4 --report_ready=1:stick,spare:7,2,0,3,1
  --report_ready_delay=300 --frames=2000 --capture=shots/x.png`.
- Solo, the real thing: `--solo --deploy --heat=80 --heat_hold=120 --goto_dropoff_after=90
  --grab=sardine --frames=3400 --capture=shots/x.png`.
- Looks: add `--setting=modern_ui:false` (PS1), `--window=1720x720` (wide), `--raid_report=8` (8 rows).

## 23. MESS-MAKING ("Chaos versus Clean") and the MEOW taunt

You're a cat. OVERCLEAN is a neat freak. So: **make a mess.** Trash bins, traffic cones, cardboard
boxes and OVERCLEAN's "SHEDDING IS A CRIME" posters all over the city can be knocked over or
scratched. Every mess:
- tips the prop over with a clatter (bin lid flaps open, litter spills on the pavement),
- adds a little **HEAT** (0.4 each: ten messes = about 4 heat),
- counts on the **RAID REPORT** (the MESS number, and the AGENT OF CHAOS award, §22),
- and **distracts the VAC-COPs**: a patrolling bot within 14 m drives over, shows **TIDYING...**
  over its head, and vacuums for 3.5 seconds before the prop stands back up. While it's heading to
  a mess or tidying it, it only spots cats a third as far away as usual. So one cat trashes a
  corner while the other sneaks the Golden Koi past!
- When four messes happen within 20 seconds, OVERCLEAN complains over the speakers ("Shedding is
  a crime. Knocking things over is also a crime."), at most once every 75 seconds.

**How to make a mess:**
| Prop | Run into it | Drive into it | Shoot / bat it | E |
|---|---|---|---|---|
| Traffic cone | any walk | yes | yes | KNOCK OVER |
| Cardboard box | any walk | yes | yes | SHOVE |
| Trash bin (solid) | only with ZOOMIES (Shift) | yes | yes | TIP OVER |
| OVERCLEAN poster (on shop walls) | — | — | yes | SCRATCH |

| Fish vending machine (solid) | — | yes | yes | KICK |
| Fire hydrant (solid) | — | yes | yes | WRENCH OPEN |
| Shopping cart | any walk | yes | yes | SHOVE |
| Neon A-frame sign | any walk | yes | yes | KICK OVER |
| Dumpster (solid) | — | yes | yes | RUMMAGE |

Cones lying down when the district starts are old mess (scenery): only standing ones count.

### THE STREET PROPS PACK: props that DO things
Five chunky Blockbench props that each count as a mess (heat, RAID REPORT, bots come to tidy) AND do
something fun:
- **FISH VENDING MACHINE** ("FISH 2 GO", against shop walls, and one by Meow-Mart's door): kick it and
  it jolts back, the glowing screen fizzes out, the dispense flap swings open and sparks + snacks spill
  out. The FIRST bust of each machine per district drops a **sardine** (or, 1 in 5, a **fish**) on the
  pavement in front of it. A machine a VAC-COP repaired still sparks if you kick it again, but it
  won't pay out twice.
- **FIRE HYDRANT** (sidewalk corners, by the kerb): wrench it open and the cap pops off and a glowing
  **WATER GEYSER** sprays for 12 seconds. Step into it (within 1.3 m) and your cat is **launched ~9 m
  into the air** (a jump pad: reach rooftops, escape a chase). Drive through it and your car bounces.
  Any VAC-COP or drone within 2.4 m is **shorted out** (stunned 3.5 s, shoved away). No bot comes to
  tidy a hydrant while it's spraying.
- **MEOW-MART SHOPPING CART** (by Meow-Mart, in yard junk piles, sometimes dumped on a corner): shove
  it (E, or just walk into it) and it **rolls ~8.5 m** the way you pushed, stopping short of walls,
  then tips onto its side. Anything in its path is **bowled over**: bins, cones, boxes, other carts
  and neon signs get knocked down (counted as YOUR messes), and bots get stunned 3 s, flung and take
  25 damage. Line one up at a VAC-COP!
- **NEON A-FRAME SIGN** (sidewalk corners, outside Meow-Mart): a sandwich board with a glowing fish +
  noodle bowl. Knock it flat and the neon dies in a shower of sparks.
- **DUMPSTER** (empty yards, the side of Meow-Mart): rummage it and the lid flies open on its hinge,
  trash bags spill out, and the FIRST rummage of each dumpster per district has a **35% chance of a
  SCRAP**.

Lots more of them on **BIN DAY** (more carts, cones, boxes and bins by Meow-Mart and in the yards; more
hydrants, signs and carts on corners). In a **BLACKOUT** the vending screens and neon signs are dark.

Not counted: bosses, SEWER BREACH bots, SQUIRT-DRONES and LINT-TRAPPERS never stop to tidy.

### MEOW = the taunt
Press **M** (keyboard) or **B** (controller) — rebind it in SETTINGS > KEYS ("MEOW"). **"GO LICK
YOURSELF!"** types out over your cat on everyone's screen, letter by letter, as clean outlined
text (no box, the same look as names and item tags), while your cat "talks" it in little cat syllables, exactly like the NPCs do.
Pick your cat's **VOICE** in MY CAT: **MALE** (low) or **FEMALE** (high). On top of that, every
cat's pitch is nudged by its fur, eye and marking colours, so two cats never sound quite the same. VAC-COPs within **22 m hear it**: they turn amber, a **?**
pops up over them and they drive over to look. Lure them away from a teammate, or into a trap.
(1.2 seconds between meows.)

### Tuning (Inspector)
- **Main > Mess** (`scripts/mess_manager.gd`): Heat Per Mess, Bin Knock Speed (6 m/s: zoomies only),
  Light Knock Speed, Bump Reach, Car Knock Speed / Reach, Interact Reach, the [E] prompts (one per
  kind of prop: Vending Prompt "KICK", Hydrant Prompt, Cart Prompt, Neon Sign Prompt, Dumpster Prompt),
  **Street props pack: loot** (Vending Fish Chance 0.2, Vending Common / Rare Item, Dumpster Scrap
  Chance 0.35), and
  the OVERCLEAN remark rules + their sounds and subtitles (keep the subtitles matching
  `tools/sound_specs/mess.json`).
- **Main > City** (`city_generator.gd`) > Street props: the models, Yard Boxes Min/Max,
  Poster Chance (0.35 per building), Corner Prop Chance, Bins Are Solid, and the STREET PROPS PACK:
  the five model files, **Vending Chance** (0.18 per building), **Yard Dumpster Chance** (0.6), **Yard
  Carts Min/Max** (0-1), **Heavy Props Are Solid** (vending machines, hydrants, dumpsters). Which
  corner prop is picked (bin / cone / box / bin+cone / hydrant / neon sign / cart) is the `roll`
  ladder in `_corner_prop`.
- **The props' own numbers** (geyser 12 s, launch 13.5 m/s, stun 2.4 m, cart roll 8.5 m in 0.7 s,
  bowling reach, damage, lid / tilt angles): the plain `var`s at the top of `scripts/mess_prop.gd`
  (props are built in code, so the Inspector can't reach them).
- **Every VAC-COP scene** (`scenes/roomba.tscn`, root) > Mess + Meows: Tidies Messes, Mess Notice
  Range, Tidy Seconds, Distracted Sight, Hears Meows, Investigate Seconds.
- **scenes/player.tscn** (root) > Meow Taunt: Taunt Lines (add more and one is picked at random),
  Taunt Letters Per Second (typing speed), Taunt Blip Gap / Max Blips / Blip Volume Db, Taunt Seconds
  (how long the line stays after typing), Taunt Color, Meow Heard From. Sounds > Meow Cooldown.
- **A new voice** (e.g. "robot"): add it to `VOICES` and `VOICE_NAMES` in `scripts/cat/cat_look.gd`
  and make its blips: a `"kind": "blips", "cat_id": "cat_robot"` line in `tools/sound_specs/mess.json`.

### The new models and sounds
- `models/blockbench/cardboard_box.bbmodel` (36 triangles, the Flaps group = the two top flaps) and
  `models/blockbench/overclean_poster.bbmodel` (24 triangles: the **Poster** group is the clean sheet,
  **Torn** is the shredded strips shown once scratched — keep those two group names if you repaint
  it). Recipes: `tools/model_specs/cardboard_box.json`, `overclean_poster.json`.
- Sounds: `python tools/cypurr_sound.py batch tools/sound_specs/mess.json` remakes them all (the
  three OVERCLEAN lines, box thump, poster scratch, vacuum tidy, stand-up tap, curious chirp and the
  MALE / FEMALE player voices). New Sound Lab presets `cardboard_thump` and `vacuum`, and a spare tool
  **generate_cat_taunt** (a meow + any line in a squeaky text-to-speech cat voice; not used in the game).

### How it works (for Claude / the curious)
The city builds every mess prop in a fixed order (`CityGenerator.mess_props`, `_add_mess_prop`), so
prop #17 is the same bin on every computer; only that number goes over the network. Whoever noticed
the knock (the cat's owner, the driver, the shooter, the presser) calls `MessManager.knock(player_id,
id, direction)` -> host `request_knock` (checks the player is theirs and up top) -> `_set_knocked`
RPC to everyone (`MessProp.show_knocked`) + heat + `Events.mess_made`. Bots: `roomba.gd` states
`TIDY_GO` / `TIDYING` (`MessManager.claim_nearest` so two bots don't take the same mess,
`MessManager.tidy`) and `INVESTIGATE` (`RoombaPatrol.hear_noise` from the cat's `_meow` RPC on the
host). Late joiners get the knocked list (`send_state_to`). A new district builds a new city, so
every mess is gone. Bins are on collision layer 4 (cats bump into them; cars and bots don't),
other props on layer 5 (only bullets).
SCAVENGING (finding items in the street): the first bust / rummage / knock of a VENDING MACHINE,
DUMPSTER, TRASH BIN or CARDBOARD BOX each district rolls ONE item from that prop's "finds" table and
drops it in front of it. Every item can turn up: food, snacks, the neon bat and every gun (dumpsters
are the gun stashes; the tommy gun, yarn-zooka, cucumber launcher and red dot are rare there).
To change the odds: scenes/main.tscn -> select **Main > Mess** -> Inspector -> **Street Props Pack:
Loot** -> Vending Finds / Dumpster Finds / Bin Finds / Box Finds. Each line is item id -> weight
(bigger = more likely; chance = weight / all weights added up). The empty id "" = "nothing in here".
Ids are the `id` on the item cards in `res://items/`. A typo prints "unknown item id" in the Output.
STREET PROPS PACK: the host pays out loot in `MessManager._drop_loot` (`finds_for(kind)` + `roll_find`,
`_looted_props`, cleared each district) and `host_knock` is the one place a knock happens (a rolling cart calls it directly for
what it bowls over). The geyser and the cart's roll run on every computer from the same `_set_knocked`
message; where a cart stops comes from a ray against the city's STATIC bodies only, so it's the same
spot everywhere. Each computer launches its OWN cats / driven car from the geyser; only the host
stuns bots.

### Testing
Every mess test prints `DevCapture mess (...)` lines: props by kind, which are knocked, made /
tidied counts, heat, and what every bot is doing.
- Knock the 3 nearest props + see them on the report:
  `--host --deploy --mess=3 --raid_report --raid_report_after=250 --frames=400 --capture=shots/x.png`
- Zoomies into a bin with real input: `--host --deploy --ram_prop=bin --frames=200 --capture=shots/x.png`
  (`=cone` / `=box` walk into one; `--ram_trace` prints speed and gap every few frames).
- Scratch a poster with E: `--scratch`. Shoot one: `--shoot_prop`.
- Watch a bot tidy (bots can't see you): `--host --deploy --ram_prop=bin --ghost --face_mess --bait_mess=4
  --mess_log=50 --frames=300 --capture=shots/x.png --scale=2`
- A bot hears a meow from out of sight: `--host --deploy --bait_roomba=18 --meow --frames=160 --capture=shots/x.png`
- Host + late-joining client (both print the same knocked list): host `--host --deploy --mess=2
  --frames=1100`, ~9 s later client `--join --wait=60 --deploy --mess=2 --frames=400`.
- STREET PROPS PACK (KIND = vending, hydrant, cart, neon_sign, dumpster; each prints `DevCapture prop`
  lines: knocked, geyser seconds, where a cart stopped, lid / cap / flap, glow, loot dropped):
  - Kick a machine, have a bot fix it, kick it again (one sardine only):
    `--solo --deploy --use_prop=vending --prop_twice --frames=700 --capture=shots/x.png`
  - Geyser jump pad + a bot shorted out: `--solo --deploy --use_prop=hydrant --geyser_jump --geyser_bot --frames=700 --capture=shots/x.png`
  - Cart bowling (a bot + a cone put in its path): `--solo --deploy --use_prop=cart --cart_bowl --frames=600 --capture=shots/x.png`
  - Run into a cart / sign: `--ram_prop=cart` / `--ram_prop=neon_sign`. Shoot one: `--shoot_prop=vending`.
  - Late joiner's view of each kind: `--instant_props`. Screenshot one: `--look_prop=KIND` (or the film
    camera: `--no_hud --cam_from=X,Y,Z --look_from=X,Y,Z`).
  - Same city everywhere: the `DevCapture mess` line's `layout=` hash must match for the same seed
    (also with `--twist=bin_day`).

## 24. The CAT-CAM: watching your crew after a knockout or an early extract

Got knocked out, or extracted early? You don't have to stare at a sewer wall while your friends
finish the raid. You can **watch them**, over their shoulder, live.

**How you start watching**
- **Knocked out up top:** once you wake up in the sewer, the screen switches to a teammate who is
  still up there by itself (after 1.5 seconds). Not when the DEEP CLEAN flattens everybody at once.
- **The CAT-CAM TV:** a chunky old TV with rabbit ears on a crate on the **east wall**, right across
  the water from the Mainframe (in both gangs' sewers). Walk up and press **E**:
  "[E] WATCH CREW UP TOP". If nobody is up top it says **NOBODY UP TOP RIGHT NOW**.
- **Already had your trip this district?** Just press **JUMP** (Space / pad A) anywhere in the sewer.
  The top line tells you: "THE SEWERS - WAIT FOR THE NEXT DISTRICT   [SPACE] WATCH CREW".

**While you watch** (the top of your screen says who, and which buttons do what):
| Button | What it does |
|---|---|
| **A / D** (or the left stick) | the previous / next cat up top (only shown when there are two or more) |
| **M** (pad **B**) = MEOW | **HECKLE over the walkie-talkie**: a radio squawk, your cat's voice, and a line like **"WHISKERS (RADIO): BEHIND YOU!"** types out over the watched cat's head, in the city, for everyone. **VAC-COPs within 18 m hear the radio and come to look**, so think before you heckle! (3 seconds between heckles.) |
| **E** or **JUMP** | back to your own cat in the sewer, any time (shop, litterbox, feed the Mainframe), then E at the TV or JUMP again to go back |

- You see **exactly what they see**: every cat now shares where its camera points, so online you look
  the same way your friend is looking. In a car (driving or riding along) you get the car's chase camera.
- The fog, rain, moon and city music switch to the city while you watch.
- Your cat stands still in the sewer while you watch (A / D won't walk it into the water).
- **Who you can watch:** in co-op, everyone up top. In TURF WAR, your own gang while any of them are up
  top; once your whole gang is home, you can watch the **rival** gang instead.
- Watching stops by itself when the last cat up top extracts or gets knocked out (if you were watching
  someone who left, it jumps to the next cat still up there), and when a SEWER BREACH siren starts.
- Split screen: each couch player watches on their own part of the screen.

**Tuning (Inspector)**
- **Main > Spectator** (`scripts/spectator.gd`): Knockout Spectate Delay (1.5 s), Knockout Spectate
  Timeout, Button Grace Seconds, Jump To Watch After Trip (untick it to keep JUMP as a plain jump),
  **Heckle Lines** (add your own!), Heckle Cooldown, Heckle Heard From (18 m), Heckle Color, Heckle
  Height / Car Height (how high the line floats), Heckle Hold Seconds, Heckle Letters Per Second, and
  the squawk sound (`sounds/sfx/radio_squawk.wav`, made with the Sound Lab) + its loudness.
- **Main > Hub** (and **GangHub**) **> CAT-CAM TV**: Catcam Spot (where you stand; the TV is built
  just east of it against the wall), Catcam Radius, Catcam Prompt, Catcam Glow (the screen colour).

**Testing** (Godot console exe from the project folder, `--path . -- ...`):
- TV, switch, heckle, back to the sewer: `--host --add_local=2 --spectate --heckle --spectate_switch
  --spectate_exit=20 --frames=30 --capture=shots/x.png` (prints "DevCapture spectate" / "heckle" lines).
- Knocked out, then auto-watch: `--host --add_local=1 --spectate_ko --frames=30 --capture=shots/x.png`
- Watching someone in the car: add `--spectate_car`.
- Online (camera look really arrives): host `--host --spectate --frames=100`, ~4 s later client
  `--join --deploy --yaw=90 --pitch=-10 --frames=400` (host prints "spectate look ... yaw=1.57 (sent 1.57)").
- Screenshot: windowed `--host --name=WHISKERS --add_local=1 --spectate --heckle --frames=150 --scale=3
  --capture=shots/spectate_cam.png`.

## 25. SEWER UPGRADES, THE TINKER WORKBENCH and THE SEWER REBELLION

Upgrades make **your** cat better for good. You pay with **cash AND SCRAP** (the loot the MEGA VAC-COPs
drop). Scrap is counted from your **backpack and your litterbox together** (the backpack is used up first).
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
| Don Catleone / Pawnie (start) | **BIGGER BACKPACK** (3): 6 -> 8 -> 10 -> 12 slots (an old save's DEEP POCKETS became BIGGER BACKPACK tiers). **MAINFRAME CAPACITOR** (2, crew): 1 scrap feeds +35% / +50% instead of +25%. |
| Comrade Whiskers / Clawd (start) | **WEAPON CRATES** (3): 1 = Hairball Blaster + Red Dot, 2 = Tommy Gun + Frozen Tuna, 3 = Yarn-Zooka + Cucumber Launcher (until then they're black silhouettes in the shop). **DELUXE LITTERBOX** (2): 9 -> 15 -> 21 slots. |
| Tier 1: Lil' Mittens / Billy the Kitten | **STUFFED CHEEKS** (2): snack stacks 3 -> 4 -> 5. **INSIDER TUNNEL** (2, crew): your exit opens 5 / 10 heat earlier. |
| Tier 2: Paulie "No-Brooms" / Bumper-Car Benny | **THICK FUR** (2): max HP 100 -> 125 -> 150. **SCRAP MAGNET** (2): smashed bots +15% / +30% chance to drop SCRAP (not bosses). |
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

## 26. DISTRICT TWISTS (a special rule for some districts)

From the **second district of a game** on, every new district has a **60% chance** of a twist: one
special rule for that district only. The first district of a game and the TUTORIAL never get one,
and the same twist never comes twice in a row.

| Twist | What changes |
|---|---|
| **BLACKOUT** | The power grid is down: every street lamp is off (dead grey bulbs), the night and the moon are darker. Only neon signs, bot sirens, payphones and car lights glow. The VAC-COPs see **25% less far**, so you can sneak much closer. |
| **BIN DAY** | **Twice the trash bins, traffic cones and cardboard boxes** on the corners, in the yards and outside Meow-Mart (the buildings stay exactly the same). When you extract, the boss pays **$10 for every mess** you made on that trip: the extraction pop-up shows **CHAOS BONUS +$...** |
| **MEOW-MART CLEARANCE** | **Twice the fish** outside Meow-Mart's door (a second row) plus a **Golden Koi** right in front of the door, but the heat climbs **25% faster** while cats are up top. |
| **HIGH ALERT** | **50% more patrol bots**, but any regular bot (not a MEGA VAC-COP) has a **35% chance to drop SCRAP** when it blows up. |

**How players find out (all in the sewers, before going up):**
- When the new district is ready, your gang boss (Don Catleone or Pawnie) says what's up there,
  e.g. *"New district, kid. Power grid's blown up there - total BLACKOUT..."*. A normal district
  gets the old *"We're movin' to a new part of town..."* line.
- THE MAINFRAME's big CRT has an **INTEL line** under the screen, in both sewers: green
  `SECTOR: STANDARD PATROL` on a normal district, amber `INTEL: GRID BLACKOUT (DARK STREETS)` etc. on a twisted one.
- Picking **SEND ME UP TOP** gets a twist reminder from the boss instead of the usual send-off.
- There is **no pop-up** when you climb out up top (on purpose: the HUD stays clean).
- The **RAID REPORT** header names it: `DISTRICT 2 — BLACKOUT — CLEAN GETAWAY`.

### Tuning (no code)
Everything is on the **Twist** node: open `scenes/main.tscn`, click **Main > Twist**, and look in the
Inspector:
- **Rolling:** *Twist Chance* (0.6 = 60%) and a tick box per twist (untick one to take it out of the game).
- **Blackout:** *Blackout Sight Multiplier* (0.75), *Blackout Ambient Multiplier* (how dark the night
  gets), *Blackout Moonlight Multiplier*.
- **Bin Day:** *Bin Day Prop Multiplier* (2 = twice the props), *Bin Day Cash Per Mess* ($10).
- **Meow-Mart Clearance:** *Clearance Fish Multiplier* (2), *Clearance Prize Item* (`golden_koi`;
  empty = no prize), *Clearance Heat Multiplier* (1.25).
- **High Alert:** *High Alert Bot Multiplier* (1.5), *High Alert Scrap Chance* (0.35).
- **What the boss says** and **Mainframe CRT intel line**: every line players read, editable.

Keep the **Twist** node ABOVE **City** and **Items** in the scene tree (drag it if needed): the
twist is decided before the city, the loot and the patrol are built.

### How it works (for Claude / the curious)
`scripts/district_twist.gd` (`DistrictTwist`, node `Twist` under Main). The HOST rolls it in
`Game.new_district()` with a random number generator seeded by the new city's seed (`city_seed ^ 0x77157`),
so a given city number always rolls the same way (given the twist before it). The host sends the
twist and the district number WITH the city seed (`Game._receive_city_seed(seed, twist, district)`, also
to late joiners), so every computer builds the same twisted city. Other scripts ask
`DistrictTwist.is_blackout()` / `is_bin_day()` / `is_clearance()` / `is_high_alert()` or the multipliers
(`sight_multiplier`, `prop_multiplier`, `heat_multiplier`, `bot_multiplier`, `roll_scrap_drop`):
- `city_generator.gd`: lamps off (BLACKOUT); BIN DAY's extra props use their own random numbers
  (`_bin_rng`), so the rest of the city matches a normal day.
- `hub.gd`: darker ambient + moon (BLACKOUT), the CRT INTEL line. `npc.gd`: the send-off line.
- `roomba.gd` `_can_chase`: sight. `heat_meter.gd`: passive heat. `roomba_patrol.gd`: patrol size.
- `enemy.gd` `explode`: HIGH ALERT scrap. `item_manager.gd`: Meow-Mart fish rows + the koi.
- `mess_manager.gd` `player_messes_this_trip` + `fish_heist.gd`: the CHAOS BONUS.
- `raid_report.gd` / `raid_report_screen.gd`: the twist in the header.

### Testing
`--twist=blackout|bin_day|clearance|high_alert|none` forces that twist on EVERY district, the first
included. It prints `DevCapture twist` lines (lamps lit, ambient, bot sight, props, Meow-Mart loot,
bots, heat multiplier, CRT intel, the boss's lines).
- Blackout: `--solo --seed=42 --twist=blackout --deploy --capture=shots/x.png --frames=200`
- Bin day + chaos bonus: `--solo --twist=bin_day --deploy --mess=4 --heat=80 --heat_hold=600
  --goto_dropoff_after=60 --capture=shots/x.png --frames=900` (prints `DevCapture extracted ... bonus $40`)
- Clearance heat: `--solo --twist=clearance --deploy --twist_heat=600 --capture=shots/x.png --frames=2500`
- High alert scrap: `--solo --twist=high_alert --deploy --kill_roombas=20 --capture=shots/x.png --frames=900`
- What 1000 districts would roll: add `--twist_rolls` (about 60% twisted, no back-to-back repeats).
- The real roll on a district change: `--solo --raid_report --report_ready=0 --frames=3000` (look for `[Twist] District 2:`).


## 27. INSIDE MEOW-MART: the first real heist (ROADMAP §4 #8)

Meow-Mart's front is now a **glass storefront with sliding doors**. Walk up and they slide open
(pneumatic `door_slide`); walk through and you're **inside a neon-lit supermarket**. Walk back out
through the same doors (they're right behind you when you come in) and you're on the sidewalk in
front of the shop again.

### What's in there
```
 north +-------------------------------------------------------------+
       |  BACK ROOM:  [security monitor]   [GOLDEN KOI TANK]  [crates] |
       |---------------------------------------[EMPLOYEES ONLY door]---|
       | [SECURITY SCALE]   [AISLE 1]     [AISLE 2]       [FRESH CATCH] |
       |                                                    counter    |
       |  [HEAVY basket]  [CHECKOUT lanes]                              |
 south +--------------------[ sliding doors -> street ]---------------+
```
- **Loot:** Fresh Catch ($75) on the iced seafood counter, Gourmet Tuna ($60) and Catnip Treats
  ($80) on the shelves. `[E] PICKUP` as usual (loot always wins the E key).
- **AISLES:** stepped shelves you can hop up like stairs. **Can stacks** sit on the ledges: run
  into one (or `[E] SWAT`) and it clatters to the floor = **1 mess** (a little heat, counts on the
  RAID REPORT's MESS column and BIN DAY's chaos bonus). The high ones need a hop. **Run at an aisle's
  END with zoomies** (or press `[E] TOPPLE` while running) and the whole row falls like dominoes:
  **10 messes**, cans everywhere.
- **The SECURITY SCALE** (glowing red pad by the west wall): put weight on it and the **EMPLOYEES
  ONLY** roller door across the store opens (the pad turns green). Step off and it shuts
  **1.5 seconds** later — too fast to run over there yourself.
  - **Co-op:** one cat stands on the scale while the other runs into the back room.
  - **Solo:** shove the **HEAVY basket** onto it (walk into it to push it, or `[E] DRAG BASKET`
    to pull it behind you, `[E] LET GO OF BASKET` to drop it).
  - Inside the back room a green **PUSH TO EXIT** bar (`[E] OPEN DOOR`) opens the door for 4
    seconds, so nobody gets locked in.
- **THE GOLDEN KOI TANK** (back room): hit it 3 times (bolts, bat swings, blasts, or `[E] SCRATCH THE
  GLASS`) or **pounce into it with zoomies** and it **shatters**: glass and water everywhere, and
  the **Golden Koi** ($400) flops onto the floor for you to grab.
- **THE STORE ALARM** (the moment the glass breaks): red strobes and a klaxon inside (and a red light
  + klaxon over the street doors), OVERCLEAN on the speakers, **+25 heat at once** (a whole heat
  level), and **4 extra VAC-COPs** roll in while every bot within 90 m is called to Meow-Mart's front
  door for 45 seconds. **No bots come inside** — the gauntlet is the street: get the heavy, jingling
  koi to your car or the exit through the crowd.
- Inside the store the rain stops, the light turns fluorescent (and the moon goes off unless someone
  on your couch is still outdoors). Split screen works: one player shopping, the other driving.

### Tuning (no code)
Open `scenes/main.tscn`, click **Main > MeowMart**, and look in the Inspector:
- **Enabled** — off = the doors stay shut and the golden koi goes back to a random sidewalk.
- **Doors:** *Door Open Distance* (3.2 m), *Door Slide Speed*, *Door Cooldown*.
- **Look:** *Fog Color / Fog Albedo / Ambient Color / Ambient Energy* (the store's haze), *Ambience*
  (the hum), *Light Color / Light Energy / Light Range* (the tubes), *Flicker Chance*.
- **Mess:** *Swat Bump Speed*, *Swat Reach*, *Swat Heat*, *Topple Ram Speed* (6 = zoomies only),
  *Topple E Speed*, *Topple Mess* (10), *Topple Heat*, *Domino Delay*, *Topple Cans*.
- **Back Room Puzzle:** *Plate Close Delay* (1.5 s), *Exit Button Seconds*, *Crate Push Speed*,
  *Crate Drag Distance*.
- **Golden Koi Tank:** *Tank Item* (`golden_koi`), *Tank Hits To Break* (3), *Pounce Speed*, *Tank Mess*.
- **Store Alarm:** *Alarm Heat* (25), *Alarm Seconds* (60), *Ambush Bots* (4), *Ambush Call Range*
  (90 m), *Ambush Call Every* (6 s), *Ambush Seconds* (45), *Alarm Sound* and *Alarm Line*.
- **The storefront** (the glass front in the city) is on **Main > City**, group **Meow-Mart
  storefront**: *Storefront Doors* (off = the old solid box), *Recess*, *Width*, *Height*, *Glow Color*.
- **The new loot** cards: `items/fresh_catch.tres`, `items/gourmet_tuna.tres`, `items/catnip_treats.tres`
  (models `scenes/items/tuna_can.tscn`, `catnip_treats.tscn`; the Fresh Catch reuses the fish model).

### How it works (for Claude / the curious)
- The store is NOT behind the doors: it's built once from code, 50 m under the middle of the city
  (`Main/MeowMart`, `scenes/interiors/meow_mart_interior.tscn` -> `scripts/interiors/meow_mart_interior.gd`,
  class `MeowMartInterior`, at y = -50). Crossing the city's glass line or the store's front doorway
  moves the cat with `CatPlayer.teleport_to` (each computer moves its own cats). Above y = -100 still
  counts as "up top" (`UndergroundHub.is_in_hub` is false): heat ticks, guns fire, the DEEP CLEAN still
  gets you. `MeowMartInterior.contains(pos)` = "inside the store"; `hub.mood_at` returns `MART_MOOD` there.
- The city side: `CityGenerator._build_meow_mart_storefront` (no random numbers, so cities are unchanged)
  fills `city.meow_mart_doors` (the two leaves), `meow_mart_door_spot` and `meow_mart_door_width`; the
  interior script slides the leaves.
- Host-decided, everyone shown: `request_swat / request_topple / request_tank_hit / request_drag /
  request_push / request_exit_button` (first argument = player id, `PlayerId.sender_owns`) ->
  `_swat / _topple / _set_tank_hits / _shatter / _set_alarm / _set_doors / _set_crate` RPCs.
  Late joiners: `send_state_to` -> `_receive_state`. New district: `start_district` -> `_reset`.
- Messes go through `MessManager.count_mess(player_id, amount, heat)` (Events.mess_made). The alarm:
  `HeatMeter.add_heat(alarm_heat, true)` (instant, not trickled), `RoombaPatrol.ambush(spot, bots, reach)`,
  `Events.store_alarm_tripped`. Bots never chase a cat inside (`Roomba._can_chase`).
- Every wall/shelf in the store hands bullet hits to the interior node (`receive_hit`); the tank has
  its own `HitRelay` (`scripts/interiors/hit_relay.gd`) because bat swings and blasts aim at the
  target's own position.

### Testing
- `--host --deploy --test_meow_mart --hold=move_forward` walks you in (`[MeowMart] 1 went inside`).
- `--inside_meow_mart[=foyer|plate|aisle|tank|backroom|counter|door]` puts you inside.
- `--shatter_tank[=F]` (host) breaks the tank: prints `DevCapture mart shatter: ... heat 0.7 -> 26.3 ...`.
- `--mart_swat=N`, `--mart_topple=1|2`, `--mart_plate`, `--mart_drag`, `--mart_tank_hits=N`, `--mart_log[=N]`
  ("DevCapture mart" lines). Late joiner: host `--deploy --inside_meow_mart --mart_topple=1 --mart_drag
  --shatter_tank=5 --frames=1500`, client `--join --mart_log=60` 14 s later.
- Split screen: `--solo --join_pad=1 --deploy --hold_all --inside_meow_mart`.
