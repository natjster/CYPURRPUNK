# MEOW-CITY 1999 — Setup & How-It-Works Guide

Everything below is **already built as files in this folder**. You don't have to paste code —
open the project and press Play. The sections explain what each piece is, so you can tweak it
(or rebuild it by hand) in the Godot editor.

```
Meow-City/
├── project.godot              <- project settings (low-res, crunchy pixels, autoloads, version)
├── scenes/
│   ├── main.tscn              <- THE game scene (press F5 to run this)
│   ├── player.tscn            <- the cat
│   ├── getaway_car.tscn       <- the car (with headlight beam + taillights)
│   ├── roomba.tscn            <- the VAC-COP police Roomba (the enemy)
│   ├── items/                 <- item models: tommy_gun, pistol, catnip, catdip, fish
│   ├── props/                 <- street_lamp (warm light cone), rain (follows the camera),
│   │                             don_catleone (the hub's boss cat)
│   └── ui/settings_menu.tscn  <- the Settings screen
├── items/                     <- ITEM CARDS (.tres), one per item, loaded automatically (§9)
├── scripts/
│   ├── game.gd                <- main scene: start a game, spawn cats, late joiners
│   ├── net.gd                 <- autoload "Net": host / join / leave (the only file that knows HOW we connect)
│   ├── settings.gd            <- autoload "Settings": every player setting, saved to disk
│   ├── input_setup.gd         <- autoload "InputSetup": registers all key bindings
│   ├── dev_capture.gd         <- autoload "DevCapture": test/screenshot tool (off in normal play)
│   ├── cat_player.gd          <- cat movement, camera, zoomies, getting in/out of the car
│   ├── getaway_car.gd         <- driving, drifting, who's driving
│   ├── city_generator.gd      <- builds the whole city from one number
│   ├── fish_heist.gd          <- fish spots, the extraction beam, cash, the heist HUD
│   ├── hub.gd                 <- THE SEWERS: the underground hub where cats start (§8)
│   ├── hub_npc.gd             <- a hub cat you can talk to (Don Catleone)
│   ├── roomba.gd              <- one VAC-COP: patrol, chase, bonk, vacuum loot, explode
│   ├── roomba_patrol.gd       <- puts VAC-COPs in the city and replaces destroyed ones
│   ├── rain_follow.gd         <- keeps the rain above the active camera
│   ├── items/                 <- the item system (§9)
│   └── ui/                    <- main_menu, pause_menu, settings_menu, inventory_ui, npc_dialog
├── shaders/
│   ├── psx_lit.gdshader       <- wobble, warpy textures, flat shading, glow (3D objects)
│   └── psx_post.gdshader      <- CRT + 15-bit color + dithering (full-screen overlay)
├── textures/                  <- tiny placeholder pixel textures
├── ui/menu_theme.tres         <- the look of every menu (colours, borders)
├── ROADMAP.md / PLAN.md       <- the Steam MVP checklist and the plan behind it
└── shots/                     <- screenshots from the capture tool (Godot ignores this folder)
```

**Opening it:** install **Godot 4.7.2** (standard edition, not .NET). In the Project Manager
click **Import**, pick `project.godot` in this folder, then **Import & Edit**. Press **F5** to play.

**Where your saves go:** `%APPDATA%\MeowCity1999\` (paste that into the Explorer address bar).
Set in Project Settings > Application > Config > **Use Custom User Dir** / **Custom User Dir Name**.

---

## 1. Godot project settings for PS1 graphics

### Resolution and pixel scaling
Already set in `project.godot`. To see/change by hand: **Project > Project Settings**, turn on
**Advanced Settings** (top-right toggle), then:

| Setting path | Value | Why |
|---|---|---|
| Display > Window > Size > Viewport Width | `320` | Internal render width |
| Display > Window > Size > Viewport Height | `240` | Internal render height |
| Display > Window > Size > Window Width Override | `1280` | Window opens 4x bigger |
| Display > Window > Size > Window Height Override | `960` | |
| Display > Window > Stretch > Mode | `viewport` | Render 3D at 320x240, then upscale |
| Display > Window > Stretch > Scale Mode | `integer` | Whole-number scaling = square pixels |
| Rendering > Textures > Canvas Textures > Default Texture Filter | `Nearest` | No blur |

(Players can change the window size and fullscreen in the in-game Settings, §10.)

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

> Tip: affine warping gets extreme on big flat surfaces. PS1 games fixed that by cutting floors
> into many small triangles — the city generator does the same (§7).

### Color-depth + dither overlay — `shaders/psx_post.gdshader`
A **ColorRect overlay** at the end of `PS1Overlay` in `main.tscn`. Everything drawn before it
(the 3D world, HUD and menus) gets the PS1 colours and CRT look:

```
PS1Overlay (CanvasLayer)
├── HUD, Lobby, PauseMenu, SettingsMenu, Inventory   <- drawn first, so they get dithered too
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
├── CatModel (Node3D)                <- turns to face movement; leans during zoomies
│   ├── Body, Belly, LegL, LegR, Head, EarL, EarR, Muzzle, Nose, EyeL, EyeR, Tail
│   │   (upright "villager" style: big round head, no arms; low-poly spheres/cylinders.
│   │    Parts using the fur material get each player's fur colour automatically.)
├── CameraPivot (Node3D)             position y=0.6 — mouse left/right turns this
│   └── SpringArm3D                  rotation x=-0.35 rad, Spring Length 3.5 — mouse up/down tilts this
│       └── Camera3D                 (its FOV comes from the FIELD OF VIEW setting)
├── NameTag (Label3D)                the player's name, shown to everyone else
└── MultiplayerSynchronizer          shares sync_position, sync_model_rotation, player_name
```

**Key design choice:** only `CatModel` rotates, never the `Player` body. If the body rotated, the
camera (its child) would whip around every time the cat turned.

### What `scripts/cat_player.gd` does
- **WASD relative to camera** — reads input, converts it using `CameraPivot`'s facing, flattens it to the ground.
- **Smooth turning** — `lerp_angle` eases `CatModel` toward the run direction.
- **Gravity + jump** — Space, only when on the floor (catdip adds mid-air jumps, §9).
- **Zoomies (Shift)** — higher top speed, cat leans nose-forward, camera rolls when strafing, FOV widens.
- **Mouse look** — speed and invert-Y come from the Settings menu (§10). Esc opens the pause menu
  (which frees the mouse); if the mouse gets freed another way, click the game to grab it again.
- **Items** — E grabs the nearest item, G drops what's in your paws, Left/Right Mouse use them
  (§9). With a gun, the cat turns to face where the camera looks, and the camera slides over the
  right shoulder (**Gun Shoulder Offset**, in the Camera group).
- **Car** — E while standing by the car asks to get in (§3).
- **While the pause menu is open** the cat ignores the keyboard (`PauseMenu.is_open`).

Every number is an `@export`, so select the Player node and tweak speeds in the **Inspector**
(groups: Movement / Camera / Zoomies Juice / Network Smoothing) — no code editing needed.

Key bindings live in `scripts/input_setup.gd` (an Autoload: **Project Settings > Globals > Autoload**).
Change a key there, e.g. `KEY_E` → `KEY_F`.

---

## 3. The arcade getaway car

### Node tree (`scenes/getaway_car.tscn`)
```
GetawayCar (RigidBody3D)            script: getaway_car.gd
│   Mass 800, Can Sleep OFF, Axis Lock > Angular X + Z ON, Physics Material: friction 0
├── CollisionShape3D                 BoxShape3D 1.8 x 0.8 x 3.6
├── Model (Node3D)                   Body, Cabin, 4 wheels, 2 headlights (MeshInstance3D)
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

### What `scripts/getaway_car.gd` does
Arcade-style: each physics step it nudges velocity directly instead of simulating tyres.
- **W** accelerate · **S** brake, then reverse · **A/D** steer (weaker at low speed, flips in reverse)
- **Space = handbrake** — sideways grip drops from 10 to 1.2 and turning gets 1.5x stronger → drift.
- `is_drifting` turns true during slides (hook tyre smoke/sounds to it later).
- **Drive input is separate from the physics:** the keyboard fills in three variables
  (`throttle`, `steer`, `handbrake`) in `_read_driver_keys()`, and the physics only reads those.
  A future AI driver (the Dog Patrol) can fill in the same three and drive with the same physics.

### The interaction (E to enter/exit)
1. `DoorZone` notices a cat walking in → sets that cat's `nearby_car`.
2. The cat presses E → it asks the **host** (`request_enter`). The host checks that the car is
   empty and the cat is within 5 m, then tells everyone who the driver is (`set_driver`).
3. Every computer hides that cat (`enter_car`); the driver's computer moves its Camera3D onto the
   car's `CameraRig/SpringArm3D` and starts simulating the car.
4. While driving, E → `request_exit` → the host sets the driver to nobody → `exit_car` puts the
   cat 2.2 m to the car's left (**Exit Offset**) and gives it its camera back.

The E press is marked "handled" so the same key press can't enter and exit in one frame.

---

## 4. Testing and fixing errors

**Quick check after any change** (press F5):
1. **Start menu** — the neon title over the rainy city; PLAY / SETTINGS / QUIT work.
2. **PLAY > HOST** — your cat appears down in **THE SEWERS** (the hub). Walk to Don Catleone
   (north end, under the pink sign), press E, pick **SEND ME UP TOP** — you're in the city.
3. **Walk, jump, zoomies** (WASD, Space, Shift) — W always goes where the camera faces.
4. **Car** — walk to the car, E to get in, drive, hold Space while turning to drift, E to get out.
5. **Items** — E next to the floating tommy gun, hold Left Mouse to fire, G to drop, Tab for the inventory.
6. **Esc** — pause menu; SETTINGS changes apply immediately; RESUME grabs the mouse again.

**When you see red errors** (bottom panel, **Debugger > Errors** tab, or red text in **Output**):
1. **Read the first one only.** Later errors are usually caused by the first.
2. Note the **file name and line number** (e.g. `cat_player.gd:84`). Double-click the error to jump there.
3. The most common causes in this project:
   - `Node not found: "CameraPivot/SpringArm3D"` → a node was renamed or moved. Names are case-sensitive and must match the trees in this guide exactly.
   - `Invalid action name "sprint"` → the `InputSetup` autoload is missing; re-add `scripts/input_setup.gd` in Project Settings > Globals > Autoload with the name `InputSetup`.
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
  `--talk` (open Don's talk box), `--drive` (car view), `--grab=tommy_gun`, `--hold=shoot`,
  `--goto_dropoff_after=N` (extract), `--menu=settings`, `--scale=2` (smaller image).
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

The game starts on the **start menu** (PLAY / SETTINGS / QUIT, see §10). **PLAY** shows the
lobby: your cat name, **HOST** (with an optional city #) and **JOIN** (with the host's address).
Hosting alone = single player.

### Play two cats on one PC
1. In Godot, open the **Debug** menu > **Customize Run Instances...**
2. Tick **Enable Multiple Instances**, set the count to **2**, click OK.
3. Press **F5**. Two game windows open (drag one aside; they start on top of each other).
4. Window 1: click **PLAY** then **HOST**. Window 2: click **PLAY**, leave the address as
   `127.0.0.1` and click **JOIN**.
5. Click into a window to control that cat. Esc opens the pause menu and frees the mouse, so you
   can switch windows.

Each cat gets its own fur colour (host is always ginger) and a name tag over its head.

**Your cat name:** type it in the CAT NAME box before clicking HOST or JOIN (up to 12
characters). Everyone else sees it floating over your cat. It's remembered for next time.
Leave it empty and you'll show up as "HOST" or "CAT 123".
Either player can drive the car; the other sees it move. Only one cat fits in the car.

*Shortcut:* in the same Customize Run Instances dialog, you can give instance 1 the launch
argument `--host` and instance 2 `--join` to skip the menu (`--name=Whiskers` and `--seed=42`
fill in those boxes).

### Play with a second computer on the same Wi-Fi/network
1. On the host PC, open a terminal and run `ipconfig`. Note the **IPv4 Address** (e.g. `192.168.1.23`).
2. Host clicks **PLAY > HOST**. If Windows asks about the firewall, allow **Private networks**.
3. On the other PC, click **PLAY**, type that address into the JOIN box and click **JOIN**.

Playing over the internet needs port forwarding (UDP port 7777) or Steam's relay. Steam is planned
(ROADMAP Phase 2) and will only change `scripts/net.gd`.

### How it works
```
Net (autoload, scripts/net.gd)    <- host(), join(address), leave(); signals joined / join_failed / host_left
Main (Node3D)                     script: game.gd  <- starts games, spawns cats, catches up late joiners
├── Players (Node3D)               <- every cat lives here, named by network ID ("1" = host)
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
- **Finding a player's cat in code:** `Game.instance.cat_for(peer_id)`, or `Game.instance.my_cat()`
  for your own.
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

### Joining mid-game
A player who joins late gets, in order: the city number, every item (on the street and in
everyone's paws/bags), everyone's cash, their cat, and who is driving the car.

### Known limitations (planned for later)
1. **The host is trusted.** Fine for friends; a public game would need anti-cheat checks.
2. **Your own cat's camera** moves at the physics rate (60/sec). On a 120 Hz+ monitor this can
   look slightly stuttery; Godot's built-in "physics interpolation" setting can fix that later.

---

## 7. Procedurally generated city

`scripts/city_generator.gd` (on the **City** node in `main.tscn`) builds the city from a single
number, the **city seed**. Same number = exact same city.

- **In the lobby:** type a number in the blue **city #** box before HOST to pick a city, or leave
  it blank for a random one. The number is shown at the bottom of the screen while playing
  ("CITY #4821") — share it to replay a city you liked. Players who JOIN get the host's city.
- **Multiplayer:** the host only sends the number; every computer builds the identical city
  itself (the test tool prints a city "fingerprint"; host and joined player always match).
- **What it builds:** a 6x6 grid of blocks with streets between. Each block has 4 lots: a building
  (taller towards downtown, glowing windows, sometimes a rooftop box and a neon sign with coloured
  light) or an empty yard with crates, dumpsters and trash bags. Street lamps sit at every
  crossroads and halfway along each block. Invisible walls stop you driving off the edge.
- **Always in the same place, whatever the seed:** cats spawn at the centre crossroads, the
  car parks just north of it, and **Meow-Mart** is the shop on the nearest corner.

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
THE SEWERS (hub, safe)  --talk to Don Catleone-->  THE CITY (grab fish)
        ^                                               |
        +------ step into the green EXTRACTION beam ----+
```

### The underground hub ("THE SEWERS")
Every cat starts here when you HOST or JOIN. It's a sewer tunnel with a murky channel down the
middle, two bridges, work lights, cardboard-box shanties, **The Mainframe** (a giant CRT on the
west wall; decoration for now — later it's where scrap buys server-wide buffs) and a ladder up
to the surface. It's a **safe zone**: guns don't fire down here (catnip and catdip still work).

**Don Catleone** — the boss cat in the fedora with the cigar, at the north end under the pink
sign. Walk up to him and press **E**. The talk box (bottom of the screen) gives four choices:
**SEND ME UP TOP** (you pop out at the city's centre crossroads), **WHO ARE YOU?**, **HOW DOES
THIS WORK?** and **NEVER MIND** (or Esc).

**Where it lives:**
- The tunnel: `scripts/hub.gd` on the **Hub** node in `main.tscn`. It's built from code when the
  game starts (like the city), but it's always the same — no seed, no randomness. The Hub node sits
  at **position (0, -200, 0)**: 200 m *under* the city. Everything below -100 m counts as "in the
  hub". Going up or down is just moving your cat between the two.
- Don: `scenes/props/don_catleone.tscn` (script `scripts/hub_npc.gd`), placed under **Hub** in
  `main.tscn`. Drag him in the editor to move him (his sign and crates follow next time you play).
- The talk box: **NpcDialog** under PS1Overlay (`scripts/ui/npc_dialog.gd`).

**Change what Don says:** open `main.tscn`, select **Hub > DonCatleone**, and in the Inspector
under **What He Says** edit **Greetings** (one is picked at random), **About Text**, **Howto
Text** and **Deploy Text**. **Npc Name** and **Talk Radius** are there too.

**Tuning the hub** (select **Hub**): **Size** (Half Width, Half Length, Height, Channel Width),
**Spawning** (Spawn Spot = where cats appear, Surface Spot = where Don sends you in the city),
**Mood** (the sewer fog colour, fog glow and ambient light).

**The mood switch:** while *your* camera is in the hub, the moon and rain switch off and the fog
turns green — on your screen only. Go back up and the rainy night city returns.

### Fish Heist (no timer)

**How to play:** glowing fish lie outside **Meow-Mart** and on sidewalks around the city. Walk
into a fish to pick it up automatically (up to 3: one in your mouth, two stacked on your head).
Reach the **EXTRACTION** point — the tall green light beam you can see through the fog — on foot
or by car. Each fish pays **$50** into **your own** cash, and you're sent **back down to the
hub** (with or without fish). If you drove in, the getaway car goes back to its parking spot,
ready for the next trip up. Taken fish grow back after 20 seconds.

**HUD:** top-left = your cash and loot carried; top-middle = distance and direction to the
extraction beam (`^` ahead, `<` `>` turn, `v` behind), or `THE SEWERS - SAFE ZONE` in the hub;
top-right = everyone's cash, richest first.

**Where it lives:** `scripts/fish_heist.gd` on the **Heist** node in `main.tscn`. Fish are a
normal loot item (§9): card `items/fish.tres`, model `scenes/items/fish.tscn`.

**Tuning:**
- Select **Heist** in `main.tscn`: Loot Item, Meow Mart Fish, Street Fish, Respawn Seconds,
  Dropoff Radius, Min Dropoff Distance, Beam Color.
- How much a fish pays: **Cash Value** on `items/fish.tres`.
- How many you can carry: **Bag Size** on the **Items** node.

### VAC-COPs (police Roombas — the enemy)
Eight police Roombas patrol the city's sidewalks. When one spots a cat **on foot** within 14 m,
its red/blue siren flashes, its eye turns red, and it charges. It's faster than a walking cat but
slower than **zoomies** (Shift) — so run! If it touches you it **bonks** you flying and
**vacuums up one fish** from your loot bag ("A VAC-COP VACUUMED YOUR FISH!"). Then it backs off
for a couple of seconds.

**Getting your fish back:** destroy it. **3 shots** from any gun, or **run it over** with the
car at speed. It explodes and spits out everything it vacuumed — walk over the fish to grab them.
A new Roomba rolls out somewhere else 25 seconds later. Cats in the car and cats in the hub are
safe. Shoot a Roomba and it gets angry and chases *you*.

**Where it lives:** `scenes/roomba.tscn` (script `scripts/roomba.gd`). The **Roombas** node in
`main.tscn` (script `scripts/roomba_patrol.gd`) puts them out when a game is hosted, and its
sibling **RoombaSpawner** (a MultiplayerSpawner) copies them to every player.

```
Roomba (CharacterBody3D, collision Layer 2)   script: roomba.gd
├── CollisionShape3D
├── Model > Body, Cap, Bumper, Eye, SirenRed, SirenBlue, Brush (Bristle1-3)
├── SirenLight (OmniLight3D)       <- red/blue on the street while chasing
└── MultiplayerSynchronizer        <- sync_position, sync_yaw, state
```

**Tuning:**
- Select **Roombas** in `main.tscn`: **Roomba Count**, **Respawn Seconds**, **Min Spawn Distance**
  (never appears this close to a cat or the centre crossroads).
- Open `scenes/roomba.tscn`, select the root **Roomba**: **Driving** (Patrol Speed, Chase Speed,
  Turn Speed), **Hunting** (Sight Range, Lose Range, Bump Range, Bump Push, Bump Hop, Stun Seconds,
  Steals Loot), **Toughness** (Max Health, Car Smash Speed).
- Roombas are on collision **Layer 2**, so cats and the car pass over them instead of getting
  stuck (Inspector > Collision > Layer). Guns still hit them.

**Multiplayer:** the host runs every Roomba's brain; everyone else's copy glides to where the
host says it is. Bonks, stolen fish and explosions are all decided by the host.

**Multiplayer:** the host referees every pickup and extraction. Fish spots and the beam come from
the city number, so the same city always has the same heist. The hub and Don aren't networked at
all — everyone's computer builds the same tunnel, and talking to Don only moves *your* cat. A
player who leaves takes their cash with them (their carried fish drop where they stood).

---

## 9. Items & weapons

Every item — fish, the tommy gun, pistols, catnip, catdip, anything you add — goes through one
system, so new items need no new networking or pickup code.

### How players use items
- **Paws:** a cat has a right and left paw. A **1-paw** item (pistol, catnip, catdip) uses one,
  so you can hold two at once (dual wield). A **2-paw** item (the tommy gun) takes both.
  **Left Mouse** uses the right-paw item (or the 2-paw item), **Right Mouse** the left-paw item.
- **Backpack:** held items you carry but aren't using (see the inventory screen below).
- **Loot bag:** loot (fish) goes in a bag, not your paws. It shows on your cat (mouth, then head)
  and pays out at the drop-off.
- **E** grabs the nearest item that says "E  NAME" above it. Items marked auto-pickup (fish) are
  grabbed just by walking into them. **G** drops what's in your paws (right paw first).

### What's in every city
| Item | Paws | Where | What it does |
|---|---|---|---|
| **Purr-Tommy 2099** | 2 | 1, floating at the centre crossroads | Hold Left Mouse: plasma bolts; overheats (below) |
| **Paw-Pistol** | 1 | 4, scattered | One shot per click; grab two to dual wield |
| **Catnip** | 1 | 4, scattered | Click: 8 s of super zoomies (used up) |
| **Catdip** | 1 | 3, scattered | Click: 20 s of double jump (used up) |
| **Fish** | loot | Meow-Mart + sidewalks | $50 each at the drop-off (§8) |

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
scenes/items/                <- the item models (the same scene lies on the street and sits in a paw)
scripts/items/
  item_data.gd               <- what an item card can say (name, paws, loot value, model...)
  item_manager.gd            <- the system ("Items" node in main.tscn): pickup, drop, paws,
                                backpack, bag, placing items in the city, multiplayer, late joiners
  held_item.gd               <- base for held items that DO something (use_tick, hud_text)
  weapon.gd                  <- base for every gun: fire rate, spread, range, knockback,
                                overheat, bolt colours — all Inspector numbers
  catnip.gd, catdip.gd       <- examples of use-it-once items
scripts/ui/inventory_ui.gd   <- the inventory screen
```
The HUD pieces for items are **PS1Overlay > HUD > Crosshair** and **HUD > GunHud**; they only
show while you hold something that wants them.

### Adding a new weapon — no code needed
The **Paw-Pistol** was made exactly this way (`scenes/items/pistol.tscn` + `items/pistol.tres`).
Steps for your next one (e.g. a shotgun):
1. In the FileSystem panel, right-click `scenes/items/pistol.tscn` (or `tommy_gun.tscn`) >
   **Duplicate** > `shotgun.tscn`. Open it and reshape the meshes under **Model** (keep
   **Model/Muzzle** at the barrel tip). Delete `HeatCoil` if it shouldn't overheat.
2. Select the root node. In the Inspector set e.g. **Automatic** off (one shot per click),
   **Fire Rate** 2, **Heat Per Shot** 0, **Cat Knockback** 14, **Bolt Color**, **Hud Name** "SHOTGUN".
3. Right-click the `items` folder > **Create New > Resource...** > **ItemData** > save as
   `shotgun.tres`. Set **Id** `shotgun`, **Display Name** `SHOTGUN`, **Kind** Held, **Hands** 1 or 2,
   **Scene** = `shotgun.tscn`, **Glow Color** (alpha above 0 to glow on the street).
4. Make it appear: select **Items** in `main.tscn` and add `shotgun` to **Scattered Items**
   (how many) or **Fixed Items** (an exact spot). Done.

### Adding new loot (example: a golden fish worth $250)
Duplicate `items/fish.tres` as `golden_fish.tres`, change **Id**, **Cash Value** 250 and the
**Scene** (e.g. a gold-tinted copy of `scenes/items/fish.tscn`), then add it to **Scattered Items**.

### Adding an item with a new behaviour (a shield, a bomb...)
Copy **catnip** (`scripts/items/catnip.gd`: click for 8 s of speed) or **catdip**
(`scripts/items/catdip.gd`: click for 20 s of double jump; Extra Jumps and Duration are Inspector
settings on `scenes/items/catdip.tscn`). Make a script that starts with `extends HeldItem`, put
it on the root of the item's scene, and write what happens in `use_tick()`. Call `consume()` to
use it up. Anything other players must see goes through an `@rpc` function on that script.

### Tuning the system (select **Items** in `main.tscn`)
Bag Size, Pack Size (backpack), Pickup Radius (walk-into), Interact Radius (E), Fixed Items,
Scattered Items, Scatter Respawn Seconds. Fish placement stays on the **Heist** node (§8).

### Inventory screen (Tab or I)
Press **Tab** or **I** to open it (Esc or Tab again closes it; the mouse is freed while open).
```
          INVENTORY
   LEFT PAW      RIGHT PAW        <- what you're holding (a 2-paw item shows BOTH PAWS)
   BACKPACK 4/6  [ ][ ][ ]        <- held items you carry but aren't using
                 [ ][ ][ ]
   LOOT BAG 1/3  [ ][ ][ ]        <- fish etc., paid out at the drop-off
```
- **Click a paw** = put that item in the backpack. **Click a backpack item** = take it into your
  paws (whatever was in the way goes into the backpack). **Right-click anything** = drop it.
- **Hover** an item to read its description (the **Description** line on its item card).
- **Picking things up:** a held item goes into a free paw first; if your paws are busy it goes
  into the backpack; only if the backpack is full too does it swap with what's in your paw.
- The screen builds its own buttons; the scene just has an empty `Inventory` node under PS1Overlay.

---

## 10. Start menu, pause menu and Settings

### What the player sees
- **Start menu:** big flickering MEOW-CITY 1999 title over the rainy city (the camera slowly pans),
  then **PLAY / SETTINGS / QUIT**. **PLAY** opens the lobby box (cat name, HOST + city #,
  JOIN + address, BACK). **Esc** = back. The game version shows bottom-left.
- **Pause menu (Esc in a game):** RESUME / SETTINGS / LEAVE GAME / QUIT TO DESKTOP. The game does
  **not** stop (it's online) — your cat just stands still and the car rolls to a stop while it's
  open. LEAVE GAME goes back to the start menu; if the host leaves, everyone does.
- **Settings:** four tabs. Click **<** / **>** to change a value; hover a row for a one-line
  explanation at the bottom. Changes apply instantly and are saved. **RESET** = defaults.
  **Esc** = back.

| Tab | Settings |
|---|---|
| DISPLAY | Screen (window/fullscreen), window size (1x-6x of 320x240), VSync, field of view |
| SOUND | Master, music, sound FX volume |
| CONTROLS | Mouse speed, invert mouse Y |
| EFFECTS | CRT TV look (0-100%), PS1 wobble on/off, volumetric fog on/off |

Saved to `%APPDATA%\MeowCity1999\settings.cfg` (with your cat name). Delete that file to get a
fresh start.

### Node tree (in `main.tscn`, under PS1Overlay)
```
HUD (Control)                     <- shown during a game: Cash, Carrying, DropOff, Scoreboard,
                                     Popup, Crosshair, GunHud, Message (what Don says),
                                     Prompt ("[E] TALK TO..."), Controls
Lobby (Control)                   script: ui/main_menu.gd   theme: ui/menu_theme.tres
├── Shade (ColorRect)             <- darkens the city a little so the text reads
├── Title / Subtitle / Tagline (Label)
├── MainScreen (VBoxContainer)    <- PlayButton, SettingsButton, QuitButton
├── PlayScreen (PanelContainer) > VBox
│   ├── NameRow > NameLabel, NameInput
│   ├── Columns > HostColumn (HostLabel, SeedInput, HostButton)
│   │           > JoinColumn (JoinLabel, AddressInput, JoinButton)
│   └── BackButton
├── Status (Label)                <- "Connecting..." / errors
└── Version (Label)
PauseMenu (Control)               script: ui/pause_menu.gd
└── Dim, Panel > VBox > Title, ResumeButton, SettingsButton, LeaveButton, QuitButton, Note
SettingsMenu                      <- an instance of scenes/ui/settings_menu.tscn
Inventory (Control)               script: ui/inventory_ui.gd
NpcDialog (Control)               script: ui/npc_dialog.gd  (the hub talk box)
└── Panel > VBox > Speaker, Line, Choices   <- choice buttons are made by the script
ColorDepthDither (ColorRect)      <- keep this LAST so it covers everything
```
`scenes/ui/settings_menu.tscn`: SettingsMenu (Control, `scripts/ui/settings_menu.gd`) > Dim,
Panel > VBox > Title, Tabs, Rows, Hint, Buttons (ResetButton, BackButton). The tab buttons and
the setting rows are made by the script from its **TABS** list.

### The pieces
- **`scripts/ui/main_menu.gd`** (on **Lobby**) — the start menu screens. It doesn't connect
  anything itself: it sends `host_pressed` / `join_pressed` / `settings_pressed` signals, and
  `game.gd` does the work. Inspector knobs on **Lobby** > **Start Menu**: Menu Camera, Camera
  Sway Degrees / Seconds, Title Flicker.
- **`scripts/ui/pause_menu.gd`** (on **PauseMenu**) — Esc opens/closes it once a game has
  started. While it (or Settings opened from it) is up, `PauseMenu.is_open` is true and the cat,
  car and inventory ignore the keyboard.
- **`scripts/settings.gd`** — Autoload named **Settings**. Holds every setting with its default,
  loads/saves the file, and applies the screen, sound and wobble settings. Other scripts read e.g.
  `Settings.mouse_speed`. `game.gd` applies the two that live in the scene (CRT look and fog).
- **Esc order:** the topmost open thing handles Esc first — inventory, then settings, then the
  pause menu, then the start menu. (Godot sends keys to the node lowest in the scene tree first,
  so keep that order under PS1Overlay.)
- **`ui/menu_theme.tres`** — the menu look (dark purple boxes, pink edges, cyan hover).
  Double-click it in the FileSystem dock to change colours in the Theme editor.
- **PS1 wobble** is a *global shader parameter*: Project Settings > **Shader Globals** >
  `psx_wobble` (1 = on). Every `psx_lit` material reads it.
- **Sound buses:** the game creates **Music** and **SFX** buses (under Master). When you add a
  sound, set its AudioStreamPlayer's **Bus** in the Inspector to Music or SFX so the sliders work.

### Adding a new setting
1. `scripts/settings.gd`: add `var my_setting: bool = true`, add `["effects", "my_setting"]` to
   **SAVED**, and use it in `apply()` (or anywhere: `Settings.my_setting`).
2. `scripts/ui/settings_menu.gd`: add a row to a tab in **TABS**, e.g.
   `{"setting": "my_setting", "label": "MY THING", "choices": [[true, "ON"], [false, "OFF"]], "hint": "What it does."}`

### Testing shortcut
`--menu=play`, `--menu=settings` (plus `--settings_tab=0..3`) or `--menu=pause` (with `--host`)
open that menu before a DevCapture screenshot.

---

## 11. Backups and undo (git + GitHub Desktop)

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
