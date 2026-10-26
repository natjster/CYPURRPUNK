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
│   ├── cat_model.tscn         <- the cat's body (used by player.tscn and the MY CAT preview, §11)
│   ├── cat_parts/             <- accessory models: fedora, beanie, neon_halo, shades... (§11)
│   ├── getaway_car.tscn       <- the car (with headlight beam + taillights)
│   ├── roomba.tscn            <- the VAC-COP police Roomba (the enemy)
│   ├── items/                 <- item models: tommy_gun, pistol, catnip, catdip, fish
│   ├── npcs/                  <- characters you talk to: don_catleone, lil_mittens, npc_template (§8)
│   ├── props/                 <- street_lamp (warm light cone), rain (follows the camera)
│   └── ui/settings_menu.tscn  <- the Settings screen
├── items/                     <- ITEM CARDS (.tres), one per item, loaded automatically (§9)
├── quests/                    <- QUEST CARDS (.tres), one per quest, loaded automatically (§8)
├── cat_parts/                 <- MY CAT: accessory cards (.tres) + palette.tres (colours) (§11)
├── sounds/                    <- SOUND FILES: sfx/, ambience/, music/ — drop files in, no code (§12)
├── scripts/
│   ├── game.gd                <- main scene: start a game, spawn cats, late joiners
│   ├── net.gd                 <- autoload "Net": host / join / leave (the only file that knows HOW we connect)
│   ├── settings.gd            <- autoload "Settings": every player setting, saved to disk
│   ├── controls.gd            <- autoload "Controls": every key, rebinding, saved to controls.cfg
│   ├── sound.gd               <- autoload "Sound": plays every sound and the music (§12)
│   ├── dev_capture.gd         <- autoload "DevCapture": test/screenshot tool (off in normal play)
│   ├── cat_player.gd          <- cat movement, camera, zoomies, getting in/out of the car
│   ├── getaway_car.gd         <- driving, drifting, who's driving
│   ├── city_generator.gd      <- builds the whole city from one number
│   ├── fish_heist.gd          <- fish spots, the extraction beam, cash, the heist HUD
│   ├── hub.gd                 <- THE SEWERS: the underground hub where cats start (§8)
│   ├── npcs/                  <- the NPC framework: npc.gd, npc_page.gd, npc_choice.gd (§8)
│   ├── quests/                <- the quest system: quest_data.gd, quest_manager.gd (§8)
│   ├── roomba.gd              <- one VAC-COP: patrol, chase, bonk, vacuum loot, explode
│   ├── roomba_patrol.gd       <- puts VAC-COPs in the city and replaces destroyed ones
│   ├── rain_follow.gd         <- keeps the rain above the active camera
│   ├── items/                 <- the item system (§9)
│   ├── cat/                   <- the character creator framework: cat_look, cat_part, cat_palette (§11)
│   ├── cat_health.gd          <- HP and knockouts (§8)
│   ├── player_profile.gd      <- saves your cash + stash between games (§8)
│   └── ui/                    <- main_menu, pause_menu, settings_menu, inventory_ui, npc_dialog, cat_creator
├── shaders/
│   ├── psx_lit.gdshader       <- wobble, warpy textures, flat shading, glow (3D objects)
│   └── psx_post.gdshader      <- CRT + 15-bit color + dithering (full-screen overlay)
├── textures/                  <- tiny placeholder pixel textures
├── ui/menu_theme.tres         <- the look of every menu (colours, borders)
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

(Players can change the resolution, fullscreen and scaling in the in-game Settings, §10. The game
is still *drawn* at 320x240 whatever the resolution; a bigger resolution just shows it bigger.
In-game **SCALING > FILL** switches Scale Mode to fractional so fullscreen fills the full screen
height instead of leaving a black border. The resolution list lives in `scripts/settings.gd`
→ `COMMON_RESOLUTIONS`; your monitor's own size is always added as the biggest option.)

**Widescreen / ultrawide (ASPECT = WIDE, the default):** the game stays **240 pixels tall** but
gets wider to match the monitor (16:9 → ~427x240, 21:9 ultrawide → ~573x240), so the city fills
the whole screen and you see more to the sides. Same chunky pixels, no black bars. ASPECT = 4:3
puts back exact 320x240 with side bars. How it works:
- `scripts/settings.gd` sets the window's **Stretch Aspect** to *keep_height* (WIDE) or *keep* (4:3).
- `PS1Overlay` has the script `scripts/ui/ps1_overlay.gd`: it keeps every menu in a 320-wide
  column in the middle of the screen (they were designed for 320x240), and stretches their dark
  background ColorRects edge to edge. Children named in its **Full Width Children** list (Inspector)
  are skipped: `HUD` and `ColorDepthDither`.
- HUD labels are anchored instead (select one in `main.tscn` > Inspector > **Layout > Anchors
  Preset**): money/loot/HP top-left, scoreboard top-right, extract arrow / crosshair / messages /
  prompts centred. **When you add a HUD label, give it an anchor** (top-left, centre-top, etc.) or
  it will sit at the left on wide screens.
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
├── CatModel                         <- an instance of scenes/cat_model.tscn (the cat's body);
│   │                                   turns to face movement; leans during zoomies
│   ├── Body, Belly, LegL, LegR, Head, EarL, EarR, Muzzle, Nose, EyeL, EyeR, Tail
│   │   (upright "villager" style: big round head, no arms; low-poly spheres/cylinders.
│   │    Colours and hats/shades/collars come from the player's MY CAT look, §11.)
├── CameraPivot (Node3D)             position y=0.6 — mouse left/right turns this
│   └── SpringArm3D                  rotation x=-0.35 rad, Spring Length 3.5 — mouse up/down tilts this
│       └── Camera3D                 (its FOV comes from the FIELD OF VIEW setting)
├── NameTag (Label3D)                the player's name, shown to everyone else
└── MultiplayerSynchronizer          shares sync_position, sync_model_rotation, player_name, look
```
To change the cat's body shape, open `scenes/cat_model.tscn` (every player cat and the MY CAT
preview use it). Keep the mesh names: the colour options paint meshes by name (§11).

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

Keys are handled by the **Controls** framework (`scripts/controls.gd`) — players rebind them in
**SETTINGS > KEYS**. See section 10, "Controls & key binding".

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
  `--cash=500 --talk=ComradeWhiskers --choose=0,3` (buy the tommy gun), `--wait=N`,
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

The game starts on the **start menu** (PLAY / SETTINGS / QUIT, see §10). **PLAY** goes to
**CHOOSE YOUR CAT** (§11), then **NEXT** to **SOLO / MULTIPLAYER**. **SOLO** starts a game just
for you (no network, nobody can join). **MULTIPLAYER** shows **HOST** (with an optional city #)
and **JOIN** (with the host's address).

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

### Play with a second computer on the same Wi-Fi/network
1. On the host PC, open a terminal and run `ipconfig`. Note the **IPv4 Address** (e.g. `192.168.1.23`).
2. Host clicks **PLAY > (cat) NEXT > MULTIPLAYER > HOST**. If Windows asks about the firewall,
   allow **Private networks**.
3. On the other PC, click **PLAY > (cat) NEXT > MULTIPLAYER**, type that address into the JOIN
   box and click **JOIN**.

Playing over the internet needs port forwarding (UDP port 7777) or Steam's relay. Steam is planned
and will only change `scripts/net.gd`.

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
everyone's paws/bags), everyone's cash, quests and HP, their cat, and who is driving the car.

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
to the surface. The walls are kept clean: the only writing is on The Mainframe and Lil' Mittens'
sign (every NPC still has its name floating over its head). It's a **safe zone**: guns don't fire down here (catnip and catdip still work).

**Don Catleone** — the boss cat in the fedora with the cigar, at the north end under a pink
glow. Walk up to him and press **E**. The talk box (bottom of the screen) gives four choices:
**SEND ME UP TOP** (you pop out at the city's centre crossroads), **WHO ARE YOU?**, **HOW DOES
THIS WORK?** and **NEVER MIND** (or Esc).

**Lil' Mittens** — a scrawny grey kitten with huge blue eyes and a "WILL PURR FOR FISH" sign,
by the cardboard shanties on the east wall. Extremely needy. She gives you the **MITTENS' FISH**
quest (see **Quests** below): bring 3 fish down at once for a **$100 bonus**.

**Comrade Whiskers** — a one-eyed ginger rebel in a red beret with a bullet bandolier, behind the
counter of **THE BLACK MARKITTEN** ("Purr-oletariat Liberation Front") on the west wall, south of
the ladder. It's **the only place to get gear**: nothing but fish lies around the city any more.
Talk to him > **SHOW ME THE GOODS** opens the shop: one **BUY ... - $price** button per item, and
**BACK**. You pay with the cash you earn extracting fish; the shop stays open so you can keep buying.

| Item | Price |
|---|---|
| Catnip | $25 |
| Catdip | $35 |
| Paw-Pistol | $60 |
| Purr-Tommy 2099 | $200 |

- **Change a price:** double-click the item card (e.g. `items/pistol.tres`) > **Shop > Price**.
  Price 0 = not for sale.
- **Change what he sells / the order:** select **Hub > ComradeWhiskers** in `main.tscn` (or open
  `scenes/npcs/comrade_whiskers.tscn`) > Inspector > **Stock** (item ids, top to bottom).
  **Shop Lines** is what he says on the shop page (`%d` = your cash).
- **Move the shop:** drag ComradeWhiskers under **Hub**. The counter, shelves, banner and
  lights are built around him by `_build_shop()` in `scripts/hub.gd`, so they follow (he faces
  his root's blue Z arrow; the counter goes on that side).
- **How buying works:** he runs `scripts/npcs/shopkeeper.gd` (an NPC with a shop). Any NPC choice
  whose **Action** is `shop` opens the shop page. Clicking BUY asks the host, which checks the
  price on the item card and your cash, takes the money and puts the item in your paws (or the
  backpack). Make another shopkeeper the same way: set an NPC's script to `shopkeeper.gd`.

### The stash & saved progress
**THE STASH** is a row of lockers under a blue light on the **east wall**, across from the Black
Markitten (north of Lil' Mittens). Walk up to it: the prompt says **[E] OPEN STASH**. Press E
(or open the inventory with Tab while standing there) and the inventory shows your **STASH**
(9 slots) where the loot bag usually is:
- **Click** something in your paws or backpack = put it in the stash.
- **Click** something in the stash = take it into your backpack (equip it from there as usual).
- Only gear goes in the stash (no fish: fish are for cashing in at the beam).

Gear in the stash is **safe**: a knockout never touches it. Everyone has their own stash.

**Saved between games:** each of your cats has its own **cash** and **stash**, saved on your own
computer. They come back whenever you play that cat again (CHOOSE YOUR CAT), solo or in anyone's
game.
What you're **carrying is not saved**: anything in your paws, backpack or loot bag is lost when
you quit (it drops on the floor in that game). So stash your gear before you leave!

- Save files: `%APPDATA%\MeowCity1999\profiles\<cat id>.cfg`, one per cat (the id is a code like
  `cat_1761400000_42`, made when you create the cat; it's in `settings.cfg` next to the name).
  Deleting a cat in CHOOSE YOUR CAT deletes its file too. Two copies of the game on one PC should
  play different cats, or they share one save.
- It saves by itself whenever your cash or stash changes (`scripts/player_profile.gd` on the
  **Profile** node in `main.tscn`).
- In multiplayer, your computer sends your save to the host when you join; the host checks it
  (only real gear, at most 9 items, cash between $0 and $10,000,000) and uses it. Like the rest of
  the game this trusts players, so it's fine between friends but easy to cheat by editing the file.
- **Tuning:** **Stash Size** on the **Items** node. Move the lockers: select **Hub** > Inspector >
  **Stash** > **Stash Spot** (where you stand; the lockers are built against the east wall next
  to it) and **Stash Radius** (how close you must be).

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
- The talk box: **NpcDialog** under PS1Overlay (`scripts/ui/npc_dialog.gd`). It also shows the
  "[E] TALK TO ..." prompt whenever your cat is near any NPC.

**Change what Don says:** open `scenes/npcs/don_catleone.tscn`, click the root **DonCatleone**,
and in the Inspector open **Pages** (how pages work is just below).

### NPCs: characters you can talk to
Every talking character uses one script, `scripts/npcs/npc.gd`. Their whole conversation is
data in the Inspector — no code needed:

```
Npc Name        "DON CATLEONE"  (also used for the floating name tag and the [E] prompt)
Talk Radius     how close you must be to press E
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
A quest is a job an NPC gives you, with a cash reward. The first one is **MITTENS' FISH**:
1. Talk to **Lil' Mittens** > **WHAT DO YOU NEED?** > **FINE. THREE FISH.**
2. The top-left HUD line (under your cash) turns into the quest tracker:
   `QUEST: MITTENS' FISH 1/3`, then `3/3 - EXTRACT!` when you have them all. (With no quest it
   shows your loot bag, `LOOT 1/3`, as before.)
3. Step into the extraction beam with **all 3 fish in your bag at once**: you get the fish's
   normal $150 **plus a $100 bonus** (the popup says `QUEST DONE +$100`). Extract with fewer
   and you just get the fish money — the quest stays active for your next trip.
4. Talk to her again afterwards: she thanks you and offers it again (it's repeatable).
Her lines change with the quest (offer / waiting / "you HAVE them, go extract!" / thank you) using
each page's **Only If Quest** settings — open `scenes/npcs/lil_mittens.tscn` to see how.

**Where it lives:** quest cards are `.tres` files in the `quests/` folder (like item cards, loaded
automatically). `scripts/quests/quest_data.gd` is the card; `scripts/quests/quest_manager.gd` on
the **Quests** node in `main.tscn` keeps track of who has which quest. In multiplayer the host
decides (like cash), and every player has their own quests.

**Change the Mittens quest:** double-click `quests/mittens_fish.tres`: **Title** (HUD name),
**Item** + **Count** (what to bring — any item card's id), **Reward Cash**, **Repeatable**.

**Add a new quest:**
1. In the FileSystem, right-click `quests/mittens_fish.tres` > **Duplicate...**, name it
   (e.g. `don_guns.tres`), and give it a new **Id** (no spaces), Title, Item, Count and Reward.
2. In an NPC's Pages, add a choice whose **Action** is `quest:` + that id, e.g. `quest:don_guns`.
3. Optional: give that NPC pages with **Only If Quest** = your id, so they say different things
   while you're on the quest and after you've done it.

For now every quest is "carry Count of Item when you extract". Other kinds of objectives (kill
Roombas, visit a place...) would be added in `quest_manager.gd` (`progress()`).

**Test it without playing:** `--talk=LilMittens --choose=0,0 --grab=fish,fish,fish
--goto_dropoff_after=20 --talk_again_after=40` takes the quest, grabs 3 fish, extracts (prints
`quest bonus $100`) and talks to her again.

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

**HUD:** top-left = your cash, loot carried (or your quest's progress, see **Quests**) and your HP
(see **Health & knockouts**); top-middle = distance and direction to the
extraction beam (`^` ahead, `<` `>` turn, `v` behind), or `THE SEWERS - SAFE ZONE` in the hub;
top-right = everyone's cash, richest first.

**Where it lives:** `scripts/fish_heist.gd` on the **Heist** node in `main.tscn`. Fish are a
normal loot item (§9): card `items/fish.tres`, model `scenes/items/fish.tscn`.

**Tuning:**
- Select **Heist** in `main.tscn`: Loot Item, Meow Mart Fish, Street Fish, Respawn Seconds,
  Dropoff Radius, Min Dropoff Distance, Beam Color.
- How much a fish pays: **Cash Value** on `items/fish.tres`.
- How many you can carry: **Bag Size** on the **Items** node.

**Multiplayer:** the host referees every pickup and extraction. Fish spots and the beam come from
the city number, so the same city always has the same heist. The hub and Don aren't networked at
all — everyone's computer builds the same tunnel, and talking to Don only moves *your* cat. A
player who leaves takes their cash with them (their carried fish drop where they stood).

**Items stay on their own level:** a cat can only grab things within 3 m above or below it
(`MAX_REACH_HEIGHT` in `item_manager.gd`), and something dropped in the sewers stays in the
sewers. (Before, a cat standing in the hub could pick up fish lying in the city right above it.)

### VAC-COPs (police Roombas — the enemy)
Eight police Roombas patrol the city's sidewalks. When one spots a cat **on foot** within 14 m,
its red/blue siren flashes, its eye turns red, and it charges. It's faster than a walking cat but
slower than **zoomies** (Shift) — so run! If it touches you it **bonks** you flying,
**vacuums up one fish** from your loot bag ("A VAC-COP VACUUMED YOUR FISH!") and takes **1 HP**.
Then it backs off for a couple of seconds. Three bonks and you're **knocked out** (see
**Health & knockouts** below).

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
  Steals Loot, **Bonk Damage** = HP a bonk takes, 0 = harmless), **Toughness** (Max Health, Car
  Smash Speed).
- Roombas are on collision **Layer 2**, so cats and the car pass over them instead of getting
  stuck (Inspector > Collision > Layer). Guns still hit them.

**Multiplayer:** the host runs every Roomba's brain; everyone else's copy glides to where the
host says it is. Bonks, stolen fish and explosions are all decided by the host.

### Health & knockouts (the risk in "extraction")
Every cat has **3 HP**, shown top-left under your cash and loot: `HP ###` (it flashes when
you're hurt). Each VAC-COP bonk takes one.

At **0 HP you're KNOCKED OUT**:
1. **Everything you carry drops on the street where you fell**: the gear in your paws, your
   backpack, and the fish in your loot bag. Anyone can grab it: you on your next trip up, a
   friend, or a rival.
2. Your cat flops over on its side for 3 seconds ("KNOCKED OUT BY A VAC-COP!"). You can look
   around but not move. Roombas leave knocked-out cats alone, and you can't extract while down.
3. You wake up back in **the sewers**, with empty paws.

**Healing:** back in the sewers you're healed to full straight away (after extracting or after
a knockout). Cats in the car and in the hub can't be hurt. Your cash and quests are never lost.

So gear you take up top is at risk every time. Gear left in **the stash** (below) is safe.

**Where it lives:** `scripts/cat_health.gd` on the **Health** node in `main.tscn`; the HP line
is **PS1Overlay > HUD > Health**. The fall-over is `knocked_out` in `cat_player.gd`.

**Tuning** (select **Health** in `main.tscn`): **Max Health**, **Knockout Seconds** (how long
you lie there), **Hud Color**. How much a bonk hurts: **Bonk Damage** on the Roomba (above).

**Something new that hurts cats** (a trap, a guard dog...): on the host, call
`CatHealth.instance.damage(peer_id, 1, "A GUARD DOG")`. The last part is shown on the
knocked-out screen. Guns don't hurt cats (no player-vs-player damage yet).

**Multiplayer:** the host decides all damage and knockouts and tells everyone, like cash.

**Test it without playing:** `--give=pistol,catnip --pos=-12,0,-6.5 --yaw=180 --bait_roomba=3
--frames=1500` gives you gear, grabs the fish at Meow-Mart, lets a VAC-COP beat you up and
prints `[Health] Player 1 was knocked out`; afterwards the pistol and catnip are on the street
and your cat is back in the hub with `hp=3`.

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

### The items
Only **fish** lie around the city. All gear is **bought** from Comrade Whiskers at the Black
Markitten in the sewers (§8).

| Item | Paws | Where | What it does |
|---|---|---|---|
| **Purr-Tommy 2099** | 2 | shop, $200 | Hold Left Mouse: plasma bolts; overheats (below) |
| **Paw-Pistol** | 1 | shop, $60 | One shot per click; buy two to dual wield |
| **Catnip** | 1 | shop, $25 | Click: 8 s of super zoomies (used up) |
| **Catdip** | 1 | shop, $35 | Click: 20 s of double jump (used up) |
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
  item_data.gd               <- what an item card can say (name, paws, loot value, shop price, model...)
  item_manager.gd            <- the system ("Items" node in main.tscn): pickup, drop, paws,
                                backpack, bag, placing items in the city, buying, multiplayer, late joiners
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
4. Sell it: on `shotgun.tres` set **Shop > Price** (e.g. 120), then select **Hub >
   ComradeWhiskers** in `main.tscn` and add `shotgun` to his **Stock**. Done.
   (Or make it lie in the city instead: select **Items** and add it to **Scattered Items** or
   **Fixed Items** — both are empty on purpose right now.)

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
Scattered Items (both empty: gear comes from the shop), Scatter Respawn Seconds. Fish placement stays on the **Heist** node (§8).

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
- **At the stash lockers** in the sewers the LOOT BAG rows are replaced by your **STASH**
  (9 slots), and clicking moves items between you and the stash instead (see **The stash &
  saved progress** in §8).
- The screen builds its own buttons; the scene just has an empty `Inventory` node under PS1Overlay
  (script `scripts/ui/inventory_ui.gd`, `InventoryScreen`).

---

## 10. Start menu, pause menu and Settings

### What the player sees
- **Start menu:** big flickering MEOW-CITY 1999 title over the rainy city (the camera slowly pans),
  then **PLAY / SETTINGS / QUIT**. The way through:
  ```
  PLAY  ->  CHOOSE YOUR CAT (pick / make / name / dress a cat, §11)  -- NEXT -->
            SOLO / MULTIPLAYER  --SOLO-->  a game just for you
                                --MULTIPLAYER-->  HOST (+ city #)  or  JOIN (+ address)
  ```
  **BACK** (or **Esc**) always goes one step back. The game version shows bottom-left.
- **Pause menu (Esc in a game):** RESUME / MY CAT (restyle or rename the cat you're playing) /
  SETTINGS / LEAVE GAME / QUIT TO DESKTOP. The game does
  **not** stop (it's online) — your cat just stands still and the car rolls to a stop while it's
  open. LEAVE GAME goes back to the start menu; if the host leaves, everyone does.
- **Settings:** five tabs. Click **<** / **>** to change a value; hover a row for a one-line
  explanation at the bottom. Changes apply instantly and are saved. **RESET** = defaults.
  **Esc** = back.
- **No key list on screen during play** — the keys live in **SETTINGS > KEYS**, and prompts
  ("[E] TALK TO...", "E PURR-TOMMY" over items, "TAB: close" in the inventory) always show the
  player's *current* key. The city number is shown in the pause menu.

| Tab | Settings |
|---|---|
| DISPLAY | Screen (window/fullscreen = monitor's max resolution), resolution (window sizes that fit your monitor, biggest = its max), scaling (SHARP = even pixels / FILL = as big as fits), aspect (WIDE = fill wide/ultrawide monitors, still 240 tall / 4:3), VSync, field of view |
| SOUND | Master, music, sound FX volume |
| CONTROLS | Mouse speed, invert mouse Y |
| KEYS | Every control with two key boxes (scrolls). **RESET KEYS** = default keys |
| EFFECTS | CRT TV look (0-100%), PS1 wobble on/off, volumetric fog on/off |

Saved to `%APPDATA%\MeowCity1999\settings.cfg` (with your cats: names and looks) and
`controls.cfg` (keys). RESET in Settings never touches your cats.
Delete those files to get a fresh start.

### Controls & key binding (`scripts/controls.gd`, Autoload **Controls**)
- **Rebinding (player):** SETTINGS > KEYS, click a box (it shows `...`), press the new key or
  mouse button (Left/Right/Middle click, wheel, side buttons all work). **Esc** cancels,
  **Delete/Backspace** empties the box. Each control has two boxes (e.g. W *and* Up).
- **Clashes:** if the key was already used by a control needed at the same time, that control
  loses it and the hint says "SPACE was taken from JUMP - give it a new key!". Controls only
  clash when their **context** overlaps: `foot` (walking), `car` (driving), `any` (both) — so
  JUMP (foot) and HANDBRAKE (car) can both be Space.
- **Esc can't be rebound** — it always opens/closes menus.
- **Adding a control:** add one line to **ACTIONS** in `scripts/controls.gd`, e.g.
  `{"action": "wave", "label": "WAVE", "context": "foot", "keys": ["V"]},`
  It appears in the KEYS menu by itself. In your script use `Input.is_action_pressed("wave")`
  (or `event.is_action_pressed("wave")` in `_unhandled_input`, like MEOW in `cat_player.gd`).
- **Changing a default key:** edit `"keys"` on that line (names like `"F"`, `"Space"`, `"Shift"`,
  `"Up"`, `"Mouse Left"`, `"Wheel Up"`, `"Mouse 4"`). Players who already rebound keep theirs
  until they press RESET KEYS.
- **Showing a key on a prompt:** `Controls.key_text("interact")` gives `"E"` (or whatever the
  player picked). Connect `Controls.changed` if the text is made once and needs updating.

### Node tree (in `main.tscn`, under PS1Overlay)
```
HUD (Control)                     <- shown during a game: Cash, Carrying, DropOff, Scoreboard,
                                     Popup, Crosshair, GunHud, Message (what Don says),
                                     Prompt ("[E] TALK TO...")
Lobby (Control)                   script: ui/main_menu.gd   theme: ui/menu_theme.tres
├── Shade (ColorRect)             <- darkens the city a little so the text reads
├── Title / Subtitle / Tagline (Label)
├── MainScreen (VBoxContainer)    <- PlayButton, SettingsButton, QuitButton
├── ModeScreen (VBoxContainer)    <- PlayingAs (Label), SoloButton, MultiplayerButton, BackButton
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
Inventory (Control)               script: ui/inventory_ui.gd
NpcDialog (Control)               script: ui/npc_dialog.gd  (the hub talk box)
└── Panel > VBox > Speaker, Scroll > Body > Line, Choices   <- choice buttons are made by the script
    (Panel is a fixed size; long pages scroll inside it. Resize it in Panel > Inspector > Layout > Transform)
ColorDepthDither (ColorRect)      <- keep this LAST so it covers everything
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
`--menu=settings`) rebinds a key like a player would and prints every key.

---

## 11. Character creator (CHOOSE YOUR CAT / MY CAT)

### What the player sees
**PLAY** on the start menu opens **CHOOSE YOUR CAT**: your cats along the top, the look rows on
the left, and the cat slowly turning on the right. (During a game, **MY CAT** in the pause menu
opens the same screen to restyle or rename the cat you're playing; no switching cats mid-game.)
```
<  [ WHISKERS ]  >  2/3  [NEW] [DELETE]     your cats: < > switch, type to rename
FUR       <  [colour]  >        main coat
MARKINGS  <  [colour]  >        belly and muzzle
EYES      <  [colour]  >        bright colours glow a little in the dark
NOSE      <  [colour]  >
HAT       <  FEDORA    >        NONE / BEANIE / FEDORA / NEON HALO
FACE      <  SHADES    >        NONE / CYBER VISOR / SHADES
NECK      <  NONE      >        NONE / BANDANA / BELL COLLAR
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
number N (both on the start menu and with `--host` / `--join`); test runs never save it. Every
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
| `meow` (`_1`, `_2`) | pressing **M** (MEOW, rebindable in SETTINGS > KEYS) | everyone nearby |
| `shoot` | each gun shot (per gun: **Shot Sound** on the gun scene's root) | everyone nearby |
| `pickup` | grabbing an item / fish | everyone nearby |
| `roomba_hum` (loops) | every VAC-COP, revs up while chasing | everyone nearby |
| `alert` | a VAC-COP starts chasing | everyone nearby |
| `bonk` | a VAC-COP bonks a cat | everyone nearby |
| `roomba_hit` | a bolt hits a VAC-COP | everyone nearby |
| `explode` | a VAC-COP explodes | everyone nearby |
| `engine_loop` (loops) | the getaway car; pitch follows the speed | everyone nearby |
| `car_door` | getting in / out of the car | everyone nearby |
| `hurt` / `knockout` | you lose HP / hit 0 HP | just you |
| `extract` | you reach the extraction beam | just you |
| `buy` / `error` | the Black Markitten sells you something / says no | just you |
| `click` | any menu button | just you |

Music and background loops change by area (they fade into each other): in the sewers
`music/hub` + `ambience/sewer`, up top (and on the start menu) `music/city` + `ambience/rain`.
To use other files, select **Hub** in `main.tscn` > Inspector > **Music** group (Hub Music,
City Music, Hub Ambience, City Ambience: file names without `.wav`; empty = silence).

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

---

## 13. Backups and undo (git + GitHub Desktop)

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
