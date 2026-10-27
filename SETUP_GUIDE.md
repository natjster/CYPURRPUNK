# CYPURRPUNK â€” Setup & How-It-Works Guide

Everything below is **already built as files in this folder**. You don't have to paste code â€”
open the project and press Play. The sections explain what each piece is, so you can tweak it
(or rebuild it by hand) in the Godot editor.

```
Meow-City/
â”œâ”€â”€ project.godot              <- project settings (low-res, crunchy pixels, autoloads, version)
â”œâ”€â”€ scenes/
â”‚   â”œâ”€â”€ game_screen.tscn       <- the top scene F5 runs: the low-res game + the sharp HUD over it (Â§13)
â”‚   â”œâ”€â”€ main.tscn              <- THE game (city, cats, menus), shown inside game_screen.tscn
â”‚   â”œâ”€â”€ player.tscn            <- the cat
â”‚   â”œâ”€â”€ cat_model.tscn         <- the cat's body (used by player.tscn and the MY CAT preview, Â§11)
â”‚   â”œâ”€â”€ cat_parts/             <- accessory models: fedora, beanie, neon_halo, shades... (Â§11)
â”‚   â”œâ”€â”€ getaway_car.tscn       <- the car (with headlight beam + taillights)
â”‚   â”œâ”€â”€ roomba.tscn            <- the VAC-COP police Roomba (the enemy)
â”‚   â”œâ”€â”€ items/                 <- item models: tommy_gun, pistol, catnip, catdip, fish
â”‚   â”œâ”€â”€ npcs/                  <- characters you talk to: don_catleone, lil_mittens, npc_template (Â§8)
â”‚   â”œâ”€â”€ props/                 <- street_lamp (warm light cone), rain (follows the camera)
â”‚   â””â”€â”€ ui/                    <- settings_menu.tscn (the Settings screen), hud.tscn (the HUD, Â§13)
â”œâ”€â”€ items/                     <- ITEM CARDS (.tres), one per item, loaded automatically (Â§9)
â”œâ”€â”€ quests/                    <- QUEST CARDS (.tres), one per quest, loaded automatically (Â§8)
â”œâ”€â”€ cat_parts/                 <- MY CAT: accessory cards (.tres) + palette.tres (colours) (Â§11)
â”œâ”€â”€ sounds/                    <- SOUND FILES: sfx/, ambience/, music/ â€” drop files in, no code (Â§12)
â”œâ”€â”€ scripts/
â”‚   â”œâ”€â”€ game.gd                <- main scene: start a game, spawn cats, late joiners
â”‚   â”œâ”€â”€ net.gd                 <- autoload "Net": host / join / leave (the only file that knows HOW we connect)
â”‚   â”œâ”€â”€ settings.gd            <- autoload "Settings": every player setting, saved to disk
â”‚   â”œâ”€â”€ controls.gd            <- autoload "Controls": every key + controller button, rebinding, rumble, saved to controls.cfg
â”‚   â”œâ”€â”€ sound.gd               <- autoload "Sound": plays every sound and the music (Â§12)
â”‚   â”œâ”€â”€ dev_capture.gd         <- autoload "DevCapture": test/screenshot tool (off in normal play)
â”‚   â”œâ”€â”€ cat_player.gd          <- cat movement, camera, zoomies, getting in/out of the car
â”‚   â”œâ”€â”€ getaway_car.gd         <- driving, drifting, who's driving
â”‚   â”œâ”€â”€ city_generator.gd      <- builds the whole city from one number
â”‚   â”œâ”€â”€ fish_heist.gd          <- fish spots, manholes, payphones, the DEEP CLEAN, cash, the heist HUD
â”‚   â”œâ”€â”€ hub.gd                 <- THE SEWERS: the underground hub where cats start (Â§8)
â”‚   â”œâ”€â”€ npcs/                  <- the NPC framework: npc.gd, npc_page.gd, npc_choice.gd (Â§8)
â”‚   â”œâ”€â”€ quests/                <- the quest system: quest_data.gd, quest_manager.gd (Â§8)
â”‚   â”œâ”€â”€ roomba.gd              <- one VAC-COP: patrol, chase, bonk, vacuum loot, explode
â”‚   â”œâ”€â”€ roomba_patrol.gd       <- puts VAC-COPs in the city and replaces destroyed ones
â”‚   â”œâ”€â”€ rain_follow.gd         <- keeps the rain above the active camera
â”‚   â”œâ”€â”€ items/                 <- the item system (Â§9)
â”‚   â”œâ”€â”€ cat/                   <- the character creator framework: cat_look, cat_part, cat_palette (Â§11)
â”‚   â”œâ”€â”€ cat_health.gd          <- HP and knockouts (Â§8)
â”‚   â”œâ”€â”€ player_profile.gd      <- saves your cash + stash between games (Â§8)
â”‚   â”œâ”€â”€ player_id.gd           <- PlayerId: player numbers vs computer numbers, for split screen (Â§6)
â”‚   â”œâ”€â”€ seats.gd               <- autoload "Seats": which controller belongs to which couch player (Â§10)
â”‚   â””â”€â”€ ui/                    <- game_screen + hud (Â§13), main_menu, pause_menu, settings_menu, inventory_ui, npc_dialog, cat_creator
â”œâ”€â”€ shaders/
â”‚   â”œâ”€â”€ psx_lit.gdshader       <- wobble, warpy textures, flat shading, glow (3D objects)
â”‚   â””â”€â”€ psx_post.gdshader      <- CRT + 15-bit color + dithering (full-screen overlay)
â”œâ”€â”€ trailer/                   <- TRAILER MAKER: shot list, music, captions, editing (Python, Â§15)
â”œâ”€â”€ textures/                  <- tiny placeholder pixel textures
â”œâ”€â”€ ui/menu_theme.tres         <- the look of every menu (colours, borders)
â”œâ”€â”€ ui/hud_theme.tres          <- the look of the HUD text (font, outline, shadow) (Â§13)
â””â”€â”€ shots/                     <- screenshots from the capture tool (Godot ignores this folder)
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
| Display > Window > Stretch > Mode | `canvas_items` | The HUD is drawn sharp at the real resolution |
| Display > Window > Stretch > Aspect | `keep_height` | HUD units: always 720 tall, wider on wide screens |
| Rendering > Textures > Canvas Textures > Default Texture Filter | `Nearest` | No blur |

**The 320x240 game picture is NOT a project setting any more:** the game (`main.tscn`) is drawn
into a 320x240 **SubViewport** inside `scenes/game_screen.tscn`, which blows it up with chunky
pixels, and the HUD is drawn sharp on top (Â§13). `scripts/ui/game_screen.gd` does the sizing.

(Players can change the resolution, fullscreen and scaling in the in-game Settings, Â§10. The game
is still *drawn* at 320x240 whatever the resolution; a bigger resolution just shows it bigger.
**SCALING > SHARP** zooms by whole numbers only (square pixels, maybe a black border);
**SCALING > FILL** zooms as big as fits. The resolution list lives in `scripts/settings.gd`
â†’ `COMMON_RESOLUTIONS`; your monitor's own size is always added as the biggest option.)

**Widescreen / ultrawide (ASPECT = WIDE, the default):** the game stays **240 pixels tall** but
gets wider to match the monitor (16:9 â†’ ~427x240, 21:9 ultrawide â†’ ~573x240), so the city fills
the whole screen and you see more to the sides. Same chunky pixels, no black bars. ASPECT = 4:3
puts back exact 320x240 with side bars. How it works:
- `scripts/ui/game_screen.gd` makes the game picture wider (WIDE) or keeps it 320 wide (4:3).
- `PS1Overlay` has the script `scripts/ui/ps1_overlay.gd`: it keeps every menu in a 320-wide
  column in the middle of the screen (they were designed for 320x240), and stretches their dark
  background ColorRects edge to edge. Children named in its **Full Width Children** list (Inspector)
  are skipped: `ColorDepthDither`.
- The HUD (Â§13) covers the game picture, whatever its shape; its labels are anchored (select one
  in `scenes/ui/hud.tscn` > Inspector > **Layout > Anchors Preset**). **When you add a HUD label,
  give it an anchor** (top-left, centre-top, etc.) or it will sit at the left on wide screens.
- The PS1 wobble grid in `psx_lit.gdshader` widens with the screen, so the wobble is the same size
  on every monitor.
- Test without an ultrawide: add `--window=1720x720` to a DevCapture run.

### Vertex jitter + affine textures â€” `shaders/psx_lit.gdshader`
This replaces the normal material on 3D objects. Every mesh in the game already uses it.

To put it on a **new** object:
1. Select the `MeshInstance3D` > Inspector > **Surface Material Override > 0** > **New ShaderMaterial**.
2. Click the new material > **Shader** > Load > `shaders/psx_lit.gdshader`.
3. Expand **Shader Parameters**: set **Albedo Color**, drag a texture into **Albedo Texture**,
   adjust **Uv Scale** (texture repeats).

Knobs: **Snap Resolution** â€” lower = more wobble (`160x120` default, `80x60` = drunk mode).
**Affine Mapping** â€” on/off for the texture warp. The player's **PS1 WOBBLE** setting switches
both off for every material at once (via the `psx_wobble` shader global, Â§10).
**Affine Fade Start / End** (metres) - the warp fades out near the camera (none closer than
Start, full strength past End), so ground right under the camera doesn't bend and slide as you
move. Defaults 3 / 9; raise both to calm it more.

> Tip: affine warping gets extreme on big flat surfaces. PS1 games fixed that by cutting floors
> into many small triangles â€” the city generator does the same (Â§7).

### Color-depth + dither overlay â€” `shaders/psx_post.gdshader`
A **ColorRect overlay** at the end of `PS1Overlay` in `main.tscn`. Everything drawn before it
(the 3D world and the menus) gets the PS1 colours and CRT look. The HUD does NOT: it's drawn
sharp on top of the finished picture (Â§13).

```
PS1Overlay (CanvasLayer)
â”œâ”€â”€ Lobby, PauseMenu, SettingsMenu, Inventory...   <- drawn first, so they get dithered too
â””â”€â”€ ColorDepthDither (ColorRect)  <- Anchors: Full Rect, Mouse > Filter: Ignore
                                     Material: ShaderMaterial with psx_post.gdshader
```

Knobs: **Color Levels** (32 = PS1, 8 = gritty), **Dither Strength** (0 = off), plus the **CRT**
group. To see the game without it, click the eye icon next to `ColorDepthDither`.

---

## 2. The third-person cat controller

### Node tree (`scenes/player.tscn`)
```
Player (CharacterBody3D)            script: cat_player.gd
â”œâ”€â”€ CollisionShape3D                 CapsuleShape3D r=0.3 h=0.9, position y=0.45
â”œâ”€â”€ CatModel                         <- an instance of scenes/cat_model.tscn (the cat's body);
â”‚   â”‚                                   turns to face movement; leans during zoomies
â”‚   â”œâ”€â”€ Body, Belly, LegL, LegR, Head, EarL, EarR, Muzzle, Nose, EyeL, EyeR, Tail
â”‚   â”‚   (upright "villager" style: big round head, no arms; low-poly spheres/cylinders.
â”‚   â”‚    Colours and hats/shades/collars come from the player's MY CAT look, Â§11.)
â”œâ”€â”€ CameraPivot (Node3D)             position y=0.6 â€” mouse left/right turns this
â”‚   â””â”€â”€ SpringArm3D                  rotation x=-0.35 rad, Spring Length 3.5 â€” mouse up/down tilts this
â”‚       â””â”€â”€ Camera3D                 (its FOV comes from the FIELD OF VIEW setting)
â”œâ”€â”€ NameTag (Label3D)                the player's name, shown to everyone else. Group "hud_name_tags":
â”‚                                    the HUD draws it sharp (Â§13); this Label3D is just the marker
â””â”€â”€ MultiplayerSynchronizer          shares sync_position, sync_model_rotation, player_name, look
```
To change the cat's body shape, open `scenes/cat_model.tscn` (every player cat and the MY CAT
preview use it). Keep the mesh names: the colour options paint meshes by name (Â§11).

**Key design choice:** only `CatModel` rotates, never the `Player` body. If the body rotated, the
camera (its child) would whip around every time the cat turned.

### What `scripts/cat_player.gd` does
- **WASD relative to camera** â€” reads input, converts it using `CameraPivot`'s facing, flattens it to the ground.
- **Smooth turning** â€” `lerp_angle` eases `CatModel` toward the run direction.
- **Gravity + jump** â€” Space, only when on the floor (catdip adds mid-air jumps, Â§9).
- **Zoomies (Shift)** â€” higher top speed, cat leans nose-forward, camera rolls when strafing, FOV widens.
- **Mouse look** â€” speed and invert-Y come from the Settings menu (Â§10). Esc opens the pause menu
  (which frees the mouse); if the mouse gets freed another way, click the game to grab it again.
- **Controller** â€” right stick turns the camera (`_stick_look`, knobs **Stick Turn Speed** /
  **Stick Pitch Ratio**), the left stick is analog (half push = walk at half speed). See Â§10,
  "Playing with a controller".
- **Items** â€” E grabs the nearest item, G drops what's in your paws, Left/Right Mouse use them
  (Â§9). With a gun, the cat turns to face where the camera looks, and the camera slides over the
  right shoulder (**Gun Shoulder Offset**, in the Camera group).
- **Car** â€” E while standing by the car asks to get in (Â§3).
- **While the pause menu is open** the cat ignores the keyboard (`PauseMenu.is_open`).

Every number is an `@export`, so select the Player node and tweak speeds in the **Inspector**
(groups: Movement / Camera / Zoomies Juice / Running Animation / Network Smoothing) â€” no code editing needed.

**Running Animation**: the cat's `LegL`/`LegR` (in `scenes/cat_model.tscn`) swing back and forth
while it runs, and its `Tail` sways side to side all the time, faster the faster it runs.
Knobs: Leg Swing (how far), Leg Swing Speed (steps per second at walking speed), Tail Swish
(how far), Tail Idle Speed (sway speed standing still), Tail Speed Per Mps (extra sway speed per
unit of running speed). Other players' cats animate the same way on your screen automatically.

Keys are handled by the **Controls** framework (`scripts/controls.gd`) â€” players rebind them in
**SETTINGS > KEYS**. See section 10, "Controls & key binding".

---

## 3. The arcade getaway car

### Node tree (`scenes/getaway_car.tscn`)
```
GetawayCar (RigidBody3D)            script: getaway_car.gd
â”‚   Mass 800, Can Sleep OFF, Axis Lock > Angular X + Z ON, Physics Material: friction 0
â”œâ”€â”€ CollisionShape3D                 BoxShape3D 1.8 x 0.8 x 3.6
â”œâ”€â”€ Model (Node3D)                   Body, Cabin, 4 wheels, 2 headlights (MeshInstance3D)
â”œâ”€â”€ GroundRay (RayCast3D)            Target Position (0, -0.8, 0)
â”œâ”€â”€ DoorZone (Area3D)                "press E" range
â”‚   â””â”€â”€ CollisionShape3D             BoxShape3D 5 x 2 x 6
â”œâ”€â”€ CameraRig (Node3D)               Top Level ON  <- follows the car with lag
â”‚   â””â”€â”€ SpringArm3D                  position y=1.2, rotation x=-0.3, Spring Length 7
â”‚                                    (the cat's Camera3D gets moved here while driving)
â””â”€â”€ MultiplayerSynchronizer          shares sync_position, sync_rotation
```

Why those settings:
- **Can Sleep OFF** â€” a sleeping body ignores our driving code.
- **Angular X/Z locked** â€” the car can only turn left/right, so it can never flip. (Ramps will come later.)
- **Friction 0** â€” our script handles grip; real friction would fight it.

### What `scripts/getaway_car.gd` does
Arcade-style: each physics step it nudges velocity directly instead of simulating tyres.
- **W** accelerate Â· **S** brake, then reverse Â· **A/D** steer (weaker at low speed, flips in reverse)
- **Space = handbrake** â€” sideways grip drops from 10 to 1.2 and turning gets 1.5x stronger â†’ drift.
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
1. `DoorZone` notices a cat walking in â†’ sets that cat's `nearby_car`.
2. The cat presses E â†’ it asks the **host** (`request_enter`). The host checks that the car is
   empty and the cat is within 5 m, then tells everyone who the driver is (`set_driver`).
3. Every computer hides that cat (`enter_car`); the driver's computer moves its Camera3D onto the
   car's `CameraRig/SpringArm3D` and starts simulating the car.
4. While driving, E â†’ `request_exit` â†’ the host sets the driver to nobody â†’ `exit_car` puts the
   cat 2.2 m to the car's left (**Exit Offset**) and gives it its camera back.

The E press is marked "handled" so the same key press can't enter and exit in one frame.

---

## 4. Testing and fixing errors

**Quick check after any change** (press F5):
1. **Start menu** â€” the neon title over the rainy city; PLAY / SETTINGS / QUIT work, and PLAY
   leads to CHOOSE YOUR CAT, then SOLO / MULTIPLAYER.
2. **PLAY > HOST** â€” your cat appears down in **THE SEWERS** (the hub). Walk to Don Catleone
   (north end, under the pink sign), press E, pick **SEND ME UP TOP** â€” you're in the city.
3. **Walk, jump, zoomies** (WASD, Space, Shift) â€” W always goes where the camera faces.
4. **Car** â€” walk to the car, E to get in, drive, hold Space while turning to drift, E to get out.
5. **Items** â€” extract some fish for cash, then buy gear from Comrade Whiskers at the **Black Markitten**
   (west wall of the sewers). Hold Left Mouse to fire, G to drop, Tab for the inventory.
6. **Esc** â€” pause menu; SETTINGS changes apply immediately; RESUME grabs the mouse again.

**When you see red errors** (bottom panel, **Debugger > Errors** tab, or red text in **Output**):
1. **Read the first one only.** Later errors are usually caused by the first.
2. Note the **file name and line number** (e.g. `cat_player.gd:84`). Double-click the error to jump there.
3. The most common causes in this project:
   - `Node not found: "CameraPivot/SpringArm3D"` â†’ a node was renamed or moved. Names are case-sensitive and must match the trees in this guide exactly.
   - `Invalid action name "sprint"` â†’ the `Controls` autoload is missing; re-add `scripts/controls.gd` in Project Settings > Globals > Autoload with the name `Controls` (keep it at the top of the list).
   - `Identifier "Settings"` / `"Net"` `not declared` â†’ that autoload is missing; re-add it the same way (`scripts/settings.gd` as `Settings`, `scripts/net.gd` as `Net`).
   - `Parse Error` / `Mixed use of tabs and spaces` â†’ copy-paste damage. Godot scripts must indent with **tabs**. Use **Edit > Convert Indent to Tabs** in the script editor.
   - Shader errors (red text in the shader editor, objects turn pink/missing) â†’ the error names the line; send it to me.
   - `Identifier "CatPlayer" not declared` â†’ the editor hasn't scanned scripts yet. Close and reopen the project.
4. **Yellow warnings** are not errors â€” the game still runs. Ignore them for now.
5. Still stuck? Copy the **full** error text (right-click > Copy Error) plus the file/line it points to and send it to me.

### The test tool (`scripts/dev_capture.gd`)
Lets Claude (or you) run the game from a terminal, do something, print what happened and save a
screenshot, then quit. Run from inside the `Meow-City` folder:

```bash
C:\GoDot\Godot_v4.7.2-stable_win64_console.exe --path . -- --host --capture=shots/test.png --pos=0,0,6 --yaw=0 --pitch=-12
```

- Useful extras: `--deploy` (go up to the city first â€” without it you're in the hub),
  `--talk` (open Don's talk box), `--drive` (car view), `--grab=fish`, `--hold=shoot`,
  `--cash=500 --talk=ComradeWhiskers --choose=0,3` (buy the tommy gun), `--wait=N`,
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

The game starts on the **start menu** (PLAY / SETTINGS / QUIT, see Â§10). **PLAY** goes to
**CHOOSE YOUR CAT** (Â§11), then **NEXT** to **SOLO / MULTIPLAYER**. **SOLO** starts a game just
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

### Play with other computers on the same Wi-Fi/network (up to 8 players)
1. Host clicks **PLAY > (cat) NEXT > MULTIPLAYER > HOST**. If Windows asks about the firewall,
   allow **Private networks** (the game uses UDP ports **7777** for playing and **7778** for
   finding games).
2. On the other PCs, click **PLAY > (cat) NEXT > MULTIPLAYER**. Under JOIN, **ON YOUR NETWORK**
   lists every game being hosted nearby, e.g. `WHISKERS  #4242  3/8` (host's cat, city number,
   players). Click it (or pick it with the d-pad + A). A full game says FULL and can't be picked.
3. Not listed (a picky router or firewall)? On the host PC run `ipconfig`, note the **IPv4
   Address** (e.g. `192.168.1.23`), type it into the JOIN box and click **JOIN**.

Up to 8 players in total: e.g. 8 computers, or 2 computers with 4 couch players each (Â§10).
Playing over the internet needs port forwarding (UDP port 7777) or Steam's relay. Steam is planned
and will only change `scripts/net.gd`.

### Bigger games get more of everything (balance knobs)
The more players, the busier the city (counted on the host, players on every computer):

| What | Where (select the node in `main.tscn`, Inspector) | Default |
|---|---|---|
| Extra VAC-COPs for every player beyond the 2nd | **Roombas** > Extra Roombas Per Player | 2 (8 players = +12) |
| Heat rises faster per extra cat up top | **Heat** > Heat Per Extra Cat | 0.1 (+10% each) |
| Loot grows back faster per extra player | **Items** > Regrow Faster Per Player | 0.15 (8 players = about 2x) |

The script side: `Game.instance.player_count()` is how many players the game has right now.

### Network traffic (how often positions are sent)
Cats and the car send where they are **30 times a second**, VAC-COPs **20 times** (everyone's
copies glide smoothly in between). To change it: open `scenes/player.tscn` (or
`getaway_car.tscn`, `roomba.tscn`) > select **MultiplayerSynchronizer** > Inspector >
**Replication Interval** (seconds between updates: 0.033 = 30/sec, 0 = every frame).
Measured: a full 8-player game (2 computers x 4) = the host sends about **12 KB/s**; with 8
separate computers about 85 KB/s. Easy for any home network or Wi-Fi.
Test: `--net_stats=600` prints KB/s sent / received; `--track=150` shows how smoothly other
players' cats move on screen.

### How it works
```
Net (autoload, scripts/net.gd)    <- host(), join(address), leave(); signals joined / join_failed / host_left
Main (Node3D)                     script: game.gd  <- starts games, spawns cats, catches up late joiners
â”œâ”€â”€ Players (Node3D)               <- every cat lives here, named by PLAYER ID ("1" = host's first player)
â”œâ”€â”€ PlayerSpawner (MultiplayerSpawner)   Spawn Path: ../Players, spawnable: player.tscn
â”œâ”€â”€ LobbyCamera (Camera3D)         <- shows the city behind the start menu
â””â”€â”€ PS1Overlay > Lobby (Control)   <- the start menu (Â§10)
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
- **Each couch player plays their own saved cat**, with its own cash and stash file (Â§8, "The stash
  & saved progress"). A couch player can drop out on their own; the computer stays in the game
  until it quits, which removes all of its players.
- **In code:** `PlayerId.make(network_id, seat)`, `PlayerId.peer_of(id)` (which computer),
  `PlayerId.slot_of(id)` (which seat, 0-3), `PlayerId.is_local(id)` (on this computer?),
  `PlayerId.first_local()`. A cat knows its own: `cat.player_id`, `cat.slot`.
  `Game.instance.add_local_player(seat, {"name", "look", "cat_id"})` /
  `remove_local_player(seat)` add or drop a couch player.
- **Controllers:** couch players join with START on their own controller (Â§10, "Couch co-op"),
  and each gets their own part of the screen (Â§13).
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

### Joining mid-game
A player who joins late gets, in order: the city number, every item (on the street and in
everyone's paws/bags), everyone's cash, quests and HP, their cat, and who is driving the car.

### Known limitations (planned for later)
1. **The host is trusted.** Fine for friends; a public game would need anti-cheat checks.
2. **One getaway car** for up to 8 players: first come, first served (no passengers yet).
3. **Your own cat's camera** moves at the physics rate (60/sec). On a 120 Hz+ monitor this can
   look slightly stuttery; Godot's built-in "physics interpolation" setting can fix that later.

---

## 7. Procedurally generated city

`scripts/city_generator.gd` (on the **City** node in `main.tscn`) builds the city from a single
number, the **city seed**. Same number = exact same city.

- **In the lobby:** type a number in the blue **city #** box before HOST to pick a city, or leave
  it blank for a random one. The number is shown at the bottom of the screen while playing
  ("CITY #4821") â€” share it to replay a city you liked. Players who JOIN get the host's city.
- **Multiplayer:** the host only sends the number; every computer builds the identical city
  itself (the test tool prints a city "fingerprint"; host and joined player always match).
- **What it builds:** a 6x6 grid of blocks with streets between. Each block has 4 lots: a building
  (taller towards downtown, glowing windows, sometimes a rooftop box and a neon sign with coloured
  light) or an empty yard with crates, dumpsters and trash bags. Street lamps sit at every
  crossroads and halfway along each block. Invisible walls stop you driving off the edge.
- **Always in the same place, whatever the seed:** cats come up the **entry manhole** in the
  centre crossroads and the car parks just north of it.
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
        +--- climb down the EXIT manhole (opens at 75 heat; a payphone ---+
             call to Don tells you where it is)

  HEAT hits 100: the hatch is SEALED, the DEEP CLEAN swarm wipes out anyone still up top,
  and the rebellion moves to a NEW DISTRICT (a new city seed).
```

### The underground hub ("THE SEWERS")
Every cat starts here when you HOST or JOIN. It's a sewer tunnel with a murky channel down the
middle, two bridges, work lights, cardboard-box shanties, **The Mainframe** (a giant CRT on the
west wall; decoration for now â€” later it's where scrap buys server-wide buffs) and a ladder up
to the surface. The walls are kept clean: the only writing is on The Mainframe and Lil' Mittens'
sign (every NPC still has its name floating over its head). It's a **safe zone**: guns don't fire down here (catnip and catdip still work).

**Don Catleone** â€” the boss cat in the fedora with the cigar, at the north end under a pink
glow. Walk up to him and press **E**. The talk box (bottom of the screen) gives four choices:
**SEND ME UP TOP** (you pop out at the city's centre crossroads), **WHO ARE YOU?**, **HOW DOES
THIS WORK?** and **NEVER MIND** (or Esc).

**Lil' Mittens** â€” a scrawny grey kitten with huge blue eyes and a "WILL PURR FOR FISH" sign,
by the cardboard shanties on the east wall. Extremely needy. She gives you the **MITTENS' FISH**
quest (see **Quests** below): bring 3 fish down at once for a **$100 bonus**.

**Comrade Whiskers** â€” a one-eyed ginger rebel in a red beret with a bullet bandolier, behind the
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
- Only gear goes in the stash (no fish: fish are for cashing in at the exit manhole).

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
  game starts (like the city), but it's always the same â€” no seed, no randomness. The Hub node sits
  at **position (0, -200, 0)**: 200 m *under* the city. Everything below -100 m counts as "in the
  hub". Going up or down is just moving your cat between the two.
- Don: `scenes/npcs/don_catleone.tscn`, an NPC (see **NPCs** below), placed under **Hub** in
  `main.tscn`. Drag him in the editor to move him (his sign and crates follow next time you play).
- The talk box: **NpcDialog** in the HUD, `scenes/ui/hud.tscn` (`scripts/ui/npc_dialog.gd`, Â§13),
  drawn sharp at full resolution. It also shows the "[E] TALK TO ..." prompt whenever your cat
  is near any NPC.
- NPC names over their heads: each NPC's **NameTag** (Label3D) sets where the name floats and
  its colour (**Modulate**); the HUD draws it sharp (Â§13). Its text comes from **Npc Name**.

**Change what Don says:** open `scenes/npcs/don_catleone.tscn`, click the root **DonCatleone**,
and in the Inspector open **Pages** (how pages work is just below).

### NPCs: characters you can talk to
Every talking character uses one script, `scripts/npcs/npc.gd`. Their whole conversation is
data in the Inspector â€” no code needed:

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
   **New NpcPage** / **New NpcChoice**. (Tip: right-click an existing page > **Duplicate** â€”
   or **Make Unique** after copying â€” so edits don't change the original.)
4. Change the look: recolour the meshes under **Model** (select a mesh > Surface Material
   Override > albedo_color), or swap in your own meshes. Keep anything that should face the
   player under **Model**; a node called **Tail** under Model swishes by itself.
5. Place it: open `main.tscn`, drag your .tscn from the FileSystem onto **Hub** (in the sewers)
   or onto the root **Main** node (in the city, then move it to a fixed spot â€” the city is
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
2. Go get the fish. (There's no quest tracker on the HUD any more: the HUD was simplified. Check
   your loot bag with the inventory screen.)
3. Climb down the exit manhole with **all 3 fish in your bag at once**: you get the fish's
   normal $150 **plus a $100 bonus** (the popup says `QUEST DONE +$100`). Extract with fewer
   and you just get the fish money â€” the quest stays active for your next trip.
4. Talk to her again afterwards: she thanks you and offers it again (it's repeatable).
Her lines change with the quest (offer / waiting / "you HAVE them, go extract!" / thank you) using
each page's **Only If Quest** settings â€” open `scenes/npcs/lil_mittens.tscn` to see how.

**Where it lives:** quest cards are `.tres` files in the `quests/` folder (like item cards, loaded
automatically). `scripts/quests/quest_data.gd` is the card; `scripts/quests/quest_manager.gd` on
the **Quests** node in `main.tscn` keeps track of who has which quest. In multiplayer the host
decides (like cash), and every player has their own quests.

**Change the Mittens quest:** double-click `quests/mittens_fish.tres`: **Title** (HUD name),
**Item** + **Count** (what to bring â€” any item card's id), **Reward Cash**, **Repeatable**.

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
`quest bonus $100`) and talks to her again. (Add `--heat=80` so the exit is open.)

**Tuning the hub** (select **Hub**): **Size** (Half Width, Half Length, Height, Channel Width),
**Spawning** (Spawn Spot = where cats appear, Surface Spot = where Don sends you in the city),
**Mood** (the sewer fog colour, fog glow and ambient light).

**The mood switch:** while *your* camera is in the hub, the moon and rain switch off and the fog
turns green â€” on your screen only. Go back up and the rainy night city returns.

### Fish Heist: districts, manholes and payphones

**The story:** OVERCLEAN, the AI, runs the city with its VAC-COP Roombas. The cat rebellion hides
in the sewers (eating rats - nobody likes rats). Each raid is on one **district**. When the heat
maxes out, Don Catleone seals that district's hatch and the rebellion moves to a new one. In the
code that just means a new city seed: the whole city is generated again.

**How a district plays:**
1. Talk to Don > **SEND ME UP TOP**: you climb out of the **entry manhole** in the centre
   crossroads. It's **one-way**: there's no going back down it.
2. Grab loot. The **HEAT** creeps up the whole time anyone is up top (about **10 minutes** from a
   fresh district to max if you cause no trouble; the golden koi and gunfights speed it up).
3. At **75 heat** the **exit manhole** opens somewhere random in the city: the lid slides off and
   a green glow comes out of the hole. At the same moment every **payphone** in the district
   starts **ringing** (bell sound, blinking light).
4. Find a payphone (they're scattered on sidewalks; follow the ringing) and press **E** to call
   Don. He tells you which side of town the exit is on, and the **HUD arrow to the exit switches
   on for the whole crew**. (Call before 75 and he only says "not yet" and which side it's on.)
5. Walk (or drive) onto the open manhole: your loot pays out and you're back in the hub. You can
   go up again into the **same district at the same heat** as many times as you like.
6. Watch the **HEAT bar** (top-right): a MEGA VAC-COP rolls out at every heat level (start, 25, 50, 75).
   **Everyone home?** Once the exit is open and every cat is back in the hub (extracted or knocked
   out), the heat races to 100 (**Heat Per Second When All Home** on the Heat node, 5/s) and the
   DEEP CLEAN skips its 30-second wait, so the next district comes in a few seconds.
7. At **100 heat** the hatch is **SEALED** and the **DEEP CLEAN** starts: the MEGA VAC-COP plus a
   swarm of **40 extra VAC-COPs** pour in near anyone still up top and hunt them from 6x further
   away. You can fight, but after **30 seconds** anyone still up there is knocked out no matter
   what (everything they carry is lost). Don won't send anyone up while it's sealed.
8. A few seconds later a **new district** is built (new city, heat back to 0, fresh patrol) and
   Don can send you up again.

**Loot** (walk into it to pick it up; your loot bag holds 3 spaces):

| Loot | Worth | Bag space | Where | Catch |
|---|---|---|---|---|
| **Sardine** | $20 | 1 | 8 on random sidewalks | none: small fry |
| **Fish** | $50 | 1 | 5 outside **Meow-Mart** + 5 on sidewalks | none |
| **Golden Koi** | **$400** | 2 | ONE, far from Meow-Mart, glowing gold | **HEAVY** (20% slower), **NOISY** (VAC-COPs spot you from 60% further), grabbing it adds **+20 HEAT** and plays a sound for everyone |

Fish and sardines grow back after 20 seconds, the koi after 2 minutes. If you drove onto the exit,
the getaway car goes back to its parking spot.

**HUD (kept simple on purpose):** top-left = your **health bar**; top-middle = `EXIT ^ 120m`
(direction and distance to the exit) **only after someone
called Don on a payphone**, or `THE SEWERS - SAFE ZONE` in the hub; top-right = everyone's cash,
**only while you're in the sewers**.

**Where it lives:**
- `scripts/fish_heist.gd` on the **Heist** node in `main.tscn`: places loot, manholes and
  payphones for each district, referees extraction, runs the seal and the DEEP CLEAN.
- `scripts/manhole.gd`: the manhole itself (built in code). Its two pictures are
  `textures/manhole_closed.png` and `textures/manhole_open.png` - repaint them in any paint
  program (keep them square, round art in the middle).
- `scenes/props/payphone.tscn` + `scripts/npcs/payphone.gd`: the payphone, an NPC you **USE**.
  Select its root to edit what Don says (**Line Too Early**, **Line Exit Open**, **Line Sealed**;
  `{where}` becomes e.g. "north-east"). The ring is `sounds/sfx/phone_ring.wav`.
- `Game.new_district()` in `scripts/game.gd`: builds the next district.
- Loot items (§9): `items/sardine.tres`, `items/fish.tres`, `items/golden_koi.tres`.

**Tuning:**
- Select **Heist** in `main.tscn`:
  - **Loot**: Loot Item (what sits outside Meow-Mart), Meow Mart Fish, Street Fish, Street
    Sardines, Golden Koi (how many), Respawn Seconds, Koi Respawn Seconds, Koi Min Distance.
  - **Manholes**: Exit Opens At Heat (75), Seal Warning At Heat (90), Exit Radius (how close you
    must get), Exit Min Distance (from the centre).
  - **Payphones**: Payphones (how many), Payphone Spacing, Payphone Min Distance.
  - **The DEEP CLEAN**: Deep Clean Seconds (30), Deep Clean Roombas (40), New District Delay.
- Select **Roombas** > **DEEP CLEAN swarm**: Swarm Min/Max Distance (how close to you they
  appear), Swarm Sight Multiplier.
- How long a district lasts: **Heat** > Heat Per Second (see **HEAT** below).
- What loot pays, how heavy / noisy it is: open its card in `items/` (see §9, **Loot settings**).
- How much you can carry: **Bag Size** on the **Items** node.

**Test it without playing:**
- `--deploy --heat=80 --heat_hold=400 --talk=Payphone0` calls Don on the first payphone (the line
  is printed, and `DevCapture heist: ... revealed=true`).
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

### VAC-COPs (police Roombas â€” the enemy)
Eight police Roombas patrol the city's sidewalks (more as the HEAT rises, see below). When one spots a cat **on foot** within 14 m,
its red/blue siren flashes, its eye turns red, and it charges. It's faster than a walking cat but
slower than **zoomies** (Shift) â€” so run! If it touches you it **bonks** you flying,
**vacuums up one fish** from your loot bag and takes **34 HP**.
Then it backs off for a couple of seconds. Three bonks and you're **knocked out** (see
**Health & knockouts** below).

**Getting your fish back:** destroy it. It has **100 health**: about **3 pistol shots** (40 each)
or **4 tommy-gun bolts** (25 each), or **run it over** with the car at speed. Once you (or any
other player) have **shot** it, a red **health bar** floats over it, and every hit pops a **damage number** off it
(see **Health bars & damage numbers** below). It explodes and spits out everything it vacuumed â€” walk over the fish to grab them.
A new Roomba rolls out somewhere else 15 seconds later. Cats in the car and cats in the hub are
safe. Shoot a Roomba and it gets angry and chases *you*.

**Where it lives:** `scenes/roomba.tscn` (script `scripts/roomba.gd`). The **Roombas** node in
`main.tscn` (script `scripts/roomba_patrol.gd`) puts them out when a game is hosted, and its
sibling **RoombaSpawner** (a MultiplayerSpawner) copies them to every player.

```
Roomba (CharacterBody3D, collision Layer 2)   script: roomba.gd
â”œâ”€â”€ CollisionShape3D
â”œâ”€â”€ Model > Body, Cap, Bumper, Eye, SirenRed, SirenBlue, Brush (Bristle1-3)
â”œâ”€â”€ SirenLight (OmniLight3D)       <- red/blue on the street while chasing
â””â”€â”€ MultiplayerSynchronizer        <- sync_position, sync_yaw, state, health
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
  Steals Loot, **Bonk Damage** = HP a bonk takes off a cat, 0 = harmless), **Toughness** (**Max
  Health**, **Display Name** = the name over its health bar, **Health Bar Height**, Car Smash Speed).
- **Boss** group (Is Boss, Drop On Destroy, Heat Scaling): see **HEAT and the MEGA VAC-COP**.
  Normal Roombas get faster and sharper-eyed with heat (Heat Scaling on).
- Roombas are on collision **Layer 2**, so cats and the car pass over them instead of getting
  stuck (Inspector > Collision > Layer). Guns still hit them.

**Multiplayer:** the host runs every Roomba's brain; everyone else's copy glides to where the
host says it is. Bonks, stolen fish and explosions are all decided by the host.

### HEAT and the MEGA VAC-COP (the pressure)
The longer you stay up top, the angrier the city gets. The **HEAT** bar (top-right, flashing
red and blue) is **shared by every player**:

- It's the **district's clock**: it creeps up **0.167 per second** while any cat is in the city
  (about **10 minutes** from 0 to 100 if you cause no trouble; the exit opens at about 7.5).
- Trouble adds more: **+20** for grabbing the golden koi, **+0.5** per gun hit on a Roomba, **+3**
  per Roomba destroyed.
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

**A MEGA VAC-COP rolls out at every HEAT LEVEL 1-4**: one as the district starts, then one more
at heat 25, 50 and 75 (even if another is still out; they stay until destroyed or the district
ends). On top of that, **one is called in every time the crew destroys 3 VAC-COPs**, up to **4 times
per district** (only when no boss is out), and one always comes out for the DEEP CLEAN at 100 heat
(level bosses and the DEEP CLEAN one don't count toward the 4). The car can't run it over: driving into
it is a crash, like hitting a wall (the car stops dead and bounces back a little; tune
**Boss Crash Bounce** on the GetawayCar). That works because `roomba_boss.tscn` is also on
collision **layer 3** and the car's **Mask** includes layer 3 (Inspector > CollisionObject3D >
Collision). Everyone hears its
siren. A giant Roomba (`scenes/roomba_boss.tscn`) drives in from across town, following the streets around buildings until it can see you (every Roomba
does this while chasing). It **always knows where you are** (sight 400 m), bonks for **67 HP** (two
bonks = knocked out), can't be run over, and has **600 health** (once it's been shot, a big health bar
floats over it, like the little ones' but twice the size). Destroy it and it spits out a **golden koi**
(so 4 bosses = 4 koi... if you survive). In the DEEP CLEAN, destroying it doesn't stop the swarm.

**Where it lives:** `scripts/heat_meter.gd` on the **Heat** node in `main.tscn` (the number, the
levels, the HUD bar); `scripts/roomba_patrol.gd` on **Roombas** (extra Roombas and the boss).

**Tuning:**
- Select **Heat** in `main.tscn`: **Heating Up** (Heat Per Second, Heat Per Roomba Hit, Heat Per
  Roomba Destroyed), **Cooling Down** (Cool Per Extraction, Cool Per Second When Empty, Cool When
  Boss Destroyed), **What Each Level Does** (Extra Roombas Per Level, Speed Per Level, Sight Per
  Level).
- Select **Roombas**: **Reinforce Seconds**, and under **MEGA VAC-COP**: Boss Spawn Distance,
  **Boss Every Kills** (3), **Bosses Per District** (4), **Boss On Levels** ([1, 2, 3, 4]: remove a
  number to skip that level's boss); under **DEEP CLEAN swarm**: Swarm Min/Max
  Distance, Swarm Sight Multiplier, Swarm Spawns Per Frame.
- The boss itself: open `scenes/roomba_boss.tscn` and select the root. It's the normal Roomba
  with bigger numbers, so it has the same settings, plus the **Boss** group: Is Boss, **Drop On
  Destroy** (`golden_koi`), Heat Scaling (off: the boss doesn't get faster with heat).
- How much heat an item adds when grabbed: **Heat On Pickup** on its card.

### Health & knockouts (the risk in "extraction")
Every cat has **100 HP**, shown as the **health bar** top-left under your cash and loot (see
**Health bars & damage numbers** below). Each VAC-COP bonk takes 34, the MEGA VAC-COP's 67.

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

**Where it lives:** `scripts/cat_health.gd` on the **Health** node in `main.tscn`; the health bar
is **Frame > Top > Health** in `scenes/ui/hud.tscn` (script `scripts/ui/hud_health_bar.gd`, Â§13). The fall-over is `knocked_out` in `cat_player.gd`.

**Tuning** (select **Health** in `main.tscn`): **Max Health**, **Knockout Seconds** (how long
you lie there). How much a bonk hurts: **Bonk Damage** on the Roomba (above).

**Something new that hurts cats** (a trap, a guard dog...): on the host, call
`CatHealth.instance.damage(player_id, 20, "A GUARD DOG")`. The last part is shown on the
knocked-out screen. Guns don't hurt cats (no player-vs-player damage yet).

**Multiplayer:** the host decides all damage and knockouts and tells everyone, like cash.

**Test it without playing:** `--give=pistol,catnip --pos=-12,0,-6.5 --yaw=180 --bait_roomba=3
--frames=1500` gives you gear, grabs the fish at Meow-Mart, lets a VAC-COP beat you up and
prints `[Health] Player 1 was knocked out`; afterwards the pistol and catnip are on the street
and your cat is back in the hub with `hp=100`.

### Health bars & damage numbers (Cyberpunk-style, all drawn on the HUD)
Everything here is drawn by the HUD layer (sharp at your real resolution, not pixelated or CRT'd).

- **Your health bar** (top-left corner): a number box (`87`) and a thin, plain red bar. When you're hurt the bit you lost turns **white-yellow** and drains away after a
  moment, so you can see how big the hit was; healing fills back in **cyan**. Under 30% the bar
  pulses; at 0 it says **KNOCKED OUT**.
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
- **Give something new a health bar** (e.g. a guard dog): add its root node to the group
  `hud_health_bars` (**Node** dock > **Groups**) and give its script a `health_bar_info()`
  function: copy the one in `scripts/roomba.gd` and change the numbers. The talking NPCs in the
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

Every item â€” fish, the tommy gun, pistols, catnip, catdip, anything you add â€” goes through one
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
Markitten in the sewers (Â§8).

| Item | Paws | Where | What it does |
|---|---|---|---|
| **Purr-Tommy 2099** | 2 | shop, $200 | Hold Left Mouse: plasma bolts; overheats (below) |
| **Paw-Pistol** | 1 | shop, $60 | One shot per click; buy two to dual wield |
| **Catnip** | 1 | shop, $25 | Click: 8 s of super zoomies (used up) |
| **Catdip** | 1 | shop, $35 | Click: 20 s of double jump (used up) |
| **Sardine** | loot | sidewalks | $20 at the drop-off (Â§8) |
| **Fish** | loot | Meow-Mart + sidewalks | $50 each at the drop-off (Â§8) |
| **Golden Koi** | loot (2 spaces) | one hidden far away; the MEGA VAC-COP drops one | $400, but heavy, noisy and raises the HEAT (Â§8) |

**The Purr-Tommy:** the drum coil goes from cyan to red as you fire, and the bar bottom-left shows
it (`HEAT [####------]`). About 3 s of non-stop fire overheats it: it blinks and won't fire until
it has cooled all the way down. Bolts shove other cats back with a little hop and nudge the car.
Nobody gets hurt â€” there is no health yet. Its scene (`scenes/items/tommy_gun.tscn`):
```
TommyGun (Node3D)                    script: weapon.gd (all the numbers are set in the Inspector)
â””â”€â”€ Model (Node3D)                   all the meshes
    â”œâ”€â”€ Receiver, Barrel, Stock, Grip, ForeGrip, SightRail, Drum   (plain MeshInstance3Ds)
    â”œâ”€â”€ Fin1 / Fin2 / Fin3           glowing pink cooling rings on the barrel
    â”œâ”€â”€ HeatCoil                     glowing drum core â€” changes colour with heat
    â””â”€â”€ Muzzle (Marker3D)            barrel tip; bolts start here
        â””â”€â”€ MuzzleFlash (OmniLight3D)
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
                                damage + crits, overheat, bolt colours â€” all Inspector numbers
  catnip.gd, catdip.gd       <- examples of use-it-once items
scripts/ui/inventory_ui.gd   <- the inventory screen
```
The HUD pieces for items are **Crosshair** and **Held** in `scenes/ui/hud.tscn` (Â§13); they only
show while you hold something that wants them.

### Adding a new weapon â€” no code needed
The **Paw-Pistol** was made exactly this way (`scenes/items/pistol.tscn` + `items/pistol.tres`).
Steps for your next one (e.g. a shotgun):
1. In the FileSystem panel, right-click `scenes/items/pistol.tscn` (or `tommy_gun.tscn`) >
   **Duplicate** > `shotgun.tscn`. Open it and reshape the meshes under **Model** (keep
   **Model/Muzzle** at the barrel tip). Delete `HeatCoil` if it shouldn't overheat.
2. Select the root node. In the Inspector set e.g. **Automatic** off (one shot per click),
   **Fire Rate** 2, **Damage** 60, **Crit Chance** 0.1, **Heat Per Shot** 0, **Cat Knockback** 14,
   **Bolt Color**, **Hud Name** "SHOTGUN".
3. Right-click the `items` folder > **Create New > Resource...** > **ItemData** > save as
   `shotgun.tres`. Set **Id** `shotgun`, **Display Name** `SHOTGUN`, **Kind** Held, **Hands** 1 or 2,
   **Scene** = `shotgun.tscn`, **Glow Color** (alpha above 0 to glow on the street).
4. Sell it: on `shotgun.tres` set **Shop > Price** (e.g. 120), then select **Hub >
   ComradeWhiskers** in `main.tscn` and add `shotgun` to his **Stock**. Done.
   (Or make it lie in the city instead: select **Items** and add it to **Scattered Items** or
   **Fixed Items** â€” both are empty on purpose right now.)

### Adding new loot (example: a silver tuna worth $150)
Duplicate `items/fish.tres` as `silver_tuna.tres`, change **Id**, **Cash Value** 150 and the
**Scene** (e.g. a tinted copy of `scenes/items/fish.tscn`), then add it to **Scattered Items** on
the **Items** node (or ask Claude to place it from the heist like the koi).

**Loot settings** (on any loot card, Inspector > **Loot**):
- **Cash Value**: what it pays when you climb down the exit manhole.
- **Bag Space**: how many of the 3 bag spaces it fills (the koi takes 2).
- **Carry Speed**: 1 = normal, 0.8 = your cat moves 20% slower while carrying it.
- **Noise**: 1 = normal, 1.6 = VAC-COPs spot you from 60% further away.
- **Heat On Pickup**: HEAT added when someone grabs it (Â§8).
- **Pickup Announcement**: shown to everyone when it's grabbed; `%s` = the cat's name.

### Adding an item with a new behaviour (a shield, a bomb...)
Copy **catnip** (`scripts/items/catnip.gd`: click for 8 s of speed) or **catdip**
(`scripts/items/catdip.gd`: click for 20 s of double jump; Extra Jumps and Duration are Inspector
settings on `scenes/items/catdip.tscn`). Make a script that starts with `extends HeldItem`, put
it on the root of the item's scene, and write what happens in `use_tick()`. Call `consume()` to
use it up. Anything other players must see goes through an `@rpc` function on that script.

### Tuning the system (select **Items** in `main.tscn`)
Bag Size, Pack Size (backpack), Pickup Radius (walk-into), Interact Radius (E), Fixed Items,
Scattered Items (both empty: gear comes from the shop), Scatter Respawn Seconds. Fish placement stays on the **Heist** node (Â§8).

### Inventory screen (Tab or I)
Press **Tab** or **I** to open it (Esc or Tab again closes it; the mouse is freed while open).
On a controller: **Y** opens it, the d-pad moves the highlight, **A** = left-click, **X** = drop,
**B** / **Y** close (the cat stands still while a controller player has it open).
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
  saved progress** in Â§8).
- The screen builds its own buttons; the HUD scene (`scenes/ui/hud.tscn`, Â§13) just has an empty
  `Inventory` node (script `scripts/ui/inventory_ui.gd`, `InventoryScreen`). It's drawn sharp at
  full resolution. Select **Inventory** in `hud.tscn` to change **Slot Size**, **Slot Font Size**,
  **Title Font Size** and **Columns**; colours and borders: `ui/hud_theme.tres`.

---

## 10. Start menu, pause menu and Settings

### What the player sees
- **Start menu:** big flickering CYPURRPUNK title over the rainy city (the camera slowly pans),
  then **PLAY / SETTINGS / QUIT**. The way through:
  ```
  PLAY  ->  SOLO / MULTIPLAYER
              SOLO  ->  CHOOSE YOUR CAT (pick / make / name / dress a cat, Â§11) -- NEXT --> a game just for you
              MULTIPLAYER  ->  LOCAL CO-OP / ONLINE CO-OP
                                 -> the LANDING PAGE: everyone on this computer joins and picks a cat
                                      LOCAL:  START GAME = everyone into the sewers together
                                      ONLINE: NEXT -> HOST (+ city #) or JOIN (a game on your network)
  ```
  The landing page:
  ```
  P1   < WHISKERS >          <- player 1: left / right = pick your cat, A (Enter) = make / edit cats
  P2   < MITTENS >           <- a friend pressed START on their controller; left / right = their cat,
                                A = edit it (MY CAT), B = leave
  P3   PRESS START TO JOIN
  P4   PRESS START TO JOIN
  [START GAME]  [BACK]       (ONLINE CO-OP: [NEXT])
  ```
  **BACK** (or **Esc**) always goes one step back. The game version shows bottom-left.
- **Pause menu (Esc, or START on a controller, in a game):** RESUME / MY CAT (restyle or rename the cat you're playing) /
  SETTINGS / LEAVE GAME / QUIT TO DESKTOP. The game does
  **not** stop (it's online) â€” your cat just stands still and the car rolls to a stop while it's
  open. LEAVE GAME goes back to the start menu; if the host leaves, everyone does.
- **Settings:** five tabs. Click **<** / **>** to change a value; hover a row for a one-line
  explanation at the bottom. Changes apply instantly and are saved. **RESET** = defaults.
  **Esc** = back.
- **No key list on screen during play** â€” the keys live in **SETTINGS > KEYS**, and prompts
  ("[E] TALK TO...", "E PURR-TOMMY" over items, "TAB: close" in the inventory) always show the
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
**START** = pause / unpause. In SETTINGS, **left/right** on a row changes its value and
**LB / RB** switch tabs. In the inventory, **A** = what a left-click does, **X** = drop,
**B** or **Y** = close. CHOOSE YOUR CAT: a controller can't type, so pressing NEXT without a
name gives the cat a random one (rename it with a keyboard any time). On a look row, **left /
right** changes it (up / down picks the row).

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
  their controller drives that screen, DONE or B comes back. **B** = stand up again. Player 1 picks their own cat on the P1 row (left /
  right), or presses A on it to make / edit cats. Their controllers don't move player 1's menu.
  LOCAL CO-OP: **START GAME** puts everyone in the sewers. ONLINE CO-OP: **NEXT** goes to HOST /
  JOIN, and everyone comes along into that game. Leaving the landing page (BACK) stands everyone
  up. Two players never play the same cat: each cat has its own cash and stash.
- **Joining mid-game (LOCAL / ONLINE CO-OP games only):** press **START** on a controller
  nobody is using: a new player drops in (in the sewers) with your next saved cat nobody is
  using (or a new "PLAYER 2"). In a SOLO game nobody can join: every controller is player 1's.
- **Full games:** a game holds 8 players. A couch player who doesn't fit is told "THE GAME IS
  FULL"; a whole computer that doesn't fit goes back to the start menu with "That game is full."
- **Pausing (each player their own):** with 2+ players, **START** (Esc for player 1) opens a small
  pause menu on YOUR screen only: your cat stops, everyone else keeps playing.
  Everyone's has **MY CAT**: restyle (colours, hat, shades...) the cat THEY play. It takes the
  whole screen while open and only that player's controller drives it; DONE (or B) goes back to
  their pause menu. Player 1's also has SETTINGS (the big pause menu: settings are shared) /
  LEAVE GAME / QUIT TO DESKTOP. Players 2-4's: **DROP OUT** (only they leave: what they carry
  drops where they stand, their stash is safe).
  Player 1's LEAVE GAME ends the game for this whole computer. Alone, START opens the normal
  big pause menu as always. (`scripts/ui/player_pause.gd`, in every player's HUD.)
- **Each player's own controller settings:** in their pause menu, **STICK SPEED**, **INVERT
  STICK Y** and **RUMBLE** (left / right changes them). A couch player's are saved with the cat
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
- **Split screen:** every player gets their own part of the screen (Â§13, "How the screen is put
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
  clash when their **context** overlaps: `foot` (walking), `car` (driving), `any` (both) â€” so
  JUMP (foot) and HANDBRAKE (car) can both be Space.
- **Esc and START can't be rebound** â€” they always open/close menus. The other menu buttons
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
(The in-game HUD is NOT here: it's the sharp overlay in scenes/ui/hud.tscn, Â§13.)
Lobby (Control)                   script: ui/main_menu.gd   theme: ui/menu_theme.tres
â”œâ”€â”€ Shade (ColorRect)             <- darkens the city a little so the text reads
â”œâ”€â”€ Title / Subtitle / Tagline (Label)
â”œâ”€â”€ MainScreen (VBoxContainer)    <- PlayButton, SettingsButton, QuitButton
â”œâ”€â”€ ModeScreen (VBoxContainer)    <- PlayingAs (Label), SoloButton, MultiplayerButton, BackButton
â”œâ”€â”€ PlayScreen (PanelContainer) > VBox      <- the MULTIPLAYER screen
â”‚   â”œâ”€â”€ Columns > HostColumn (HostLabel, SeedInput, HostButton)
â”‚   â”‚           > JoinColumn (JoinLabel, AddressInput, JoinButton)
â”‚   â””â”€â”€ BackButton
â”œâ”€â”€ Status (Label)                <- "Connecting..." / errors
â””â”€â”€ Version (Label)
PauseMenu (Control)               script: ui/pause_menu.gd
â””â”€â”€ Dim, Panel > VBox > Title, ResumeButton, CatButton, SettingsButton, LeaveButton, QuitButton, Note
SettingsMenu                      <- an instance of scenes/ui/settings_menu.tscn
CatCreator (Control)              script: ui/cat_creator.gd  (CHOOSE YOUR CAT / MY CAT; builds itself, Â§11)
ColorDepthDither (ColorRect)      <- keep this LAST so it covers everything
(The inventory screen and the NPC talk box are in the sharp HUD instead: scenes/ui/hud.tscn, Â§13.)
```
`scenes/ui/settings_menu.tscn`: SettingsMenu (Control, `scripts/ui/settings_menu.gd`) > Dim,
Panel > VBox > Title, Tabs, Scroll (ScrollContainer) > Rows, Hint, Buttons (ResetButton,
BackButton). The tab buttons and the setting rows are made by the script from its **TABS** list;
the KEYS tab's rows come from `Controls.ACTIONS`. Make the list taller/shorter with
**Scroll > Inspector > Layout > Custom Minimum Size > y** (now 104).

### The pieces
- **`scripts/ui/main_menu.gd`** (on **Lobby**) â€” the start menu screens. It doesn't connect
  anything itself: it sends `play_pressed` / `solo_pressed` / `host_pressed` / `join_pressed` /
  `settings_pressed` signals, and `game.gd` does the work (e.g. `play_pressed` opens CHOOSE YOUR
  CAT, whose NEXT shows the SOLO / MULTIPLAYER screen again). Inspector knobs on **Lobby** > **Start Menu**: Menu Camera, Camera
  Sway Degrees / Seconds, Title Flicker.
- **`scripts/ui/pause_menu.gd`** (on **PauseMenu**) â€” Esc / START opens/closes it (B closes) once a game has
  started. While it (or Settings opened from it) is up, `PauseMenu.is_open` is true and the cat,
  car and inventory ignore the keyboard.
- **`scripts/settings.gd`** â€” Autoload named **Settings**. Holds every setting with its default,
  loads/saves the file, and applies the screen, sound and wobble settings. Other scripts read e.g.
  `Settings.mouse_speed`. `game.gd` applies the two that live in the scene (CRT look and fog).
- **Esc order:** the topmost open thing handles Esc first â€” the talk box / inventory (in the
  HUD, which always hears keys before the game), then settings, then the pause menu, then the
  start menu. (Godot sends keys to the node lowest in the scene tree first, so keep that order
  under PS1Overlay.)
- **`ui/menu_theme.tres`** â€” the menu look (dark purple boxes, pink edges, cyan hover).
  Double-click it in the FileSystem dock to change colours in the Theme editor.
- **PS1 wobble** is a *global shader parameter*: Project Settings > **Shader Globals** >
  `psx_wobble` (1 = on). Every `psx_lit` material reads it.
- **Sound buses:** the game creates **Music** and **SFX** buses (under Master). Sounds played by
  the **Sound** autoload (Â§12) pick the right one themselves. Only if you place an
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
[ BACK ]     [ RANDOM ]     [ NEXT ]        (in a game: [ RANDOM ] [ DONE ])
```
- **Your cats:** you can have as many as you like. **NEW** starts a fresh one (type its name in the
  box), **<** / **>** switch between them, **DELETE** asks "SURE?" and a second click deletes that
  cat **with its cash and stash**. The cat showing when you press NEXT is the one you play.
- **Each cat has its own name, look, cash and stash** (Â§8 "The stash & saved progress").
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
- `scripts/cat/cat_look.gd` (`CatLook`) â€” the framework. A cat's **look** is a small list of
  values: four colours plus which part is in each slot. `CatLook.apply(model, look)` paints a cat
  model and puts the parts on. It also loads the part cards and palette, makes random looks, and
  throws away anything broken (unknown parts, wrong types).
- `scripts/cat/cat_part.gd` (`CatPart`) â€” the accessory card. `scripts/cat/cat_palette.gd`
  (`CatPalette`) â€” the colour lists.
- `cat_parts/` â€” the cards and the palette. `scenes/cat_parts/` â€” the accessory models.
- `scenes/cat_model.tscn` â€” the cat's body, used by player cats and the MY CAT preview. The colour
  rows paint meshes **by name** (FUR = Body, legs, Head, ears, Tail; MARKINGS = Belly, Muzzle;
  EYES = EyeL/EyeR; NOSE = Nose), listed in `COLOR_PARTS` in `cat_look.gd`.
- `scripts/ui/cat_creator.gd` (`CatCreator`, on **PS1Overlay > CatCreator**) â€” the screen. It builds
  itself: the cat row, then one row per colour and per slot.
- `scripts/settings.gd` â€” your cats: `Settings.cats` (each `{"id", "name", "look"}`) and
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
are just files in the `sounds/` folder â€” **adding or replacing a sound needs no code.**

```
sounds/
â”œâ”€â”€ sfx/          <- one-off effects        (SOUND FX slider)
â”œâ”€â”€ ambience/     <- background loops        (SOUND FX slider)
â””â”€â”€ music/        <- music loops, one per area (MUSIC slider)
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
| `extract` | you climb down the exit manhole | just you |
| `phone_ring` (loops) | payphones while the exit is open and nobody has called Don yet | everyone nearby |
| `koi_grab` | someone grabs a golden koi | everyone (2D) |
| `heat_up` | the HEAT goes up a level | everyone (2D) |
| `boss_siren` | the MEGA VAC-COP comes out | everyone (2D) |
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
- `Sound.play("buy")` â€” plain sound, only you hear it (menus, "you got hurt").
- `Sound.play_at("shoot", where)` â€” from a spot in the world, on this computer. Use it where
  **every** computer already runs the code (like a shot that's drawn on every screen).
- `Sound.play_everywhere("bonk", where)` â€” from a spot, sent to **every** player's computer.
  Use it where only one computer knows it happened (usually the host).
- `Sound.attach_loop("engine_loop", self)` â€” a looping sound that rides along on a node; keep the
  returned player to change its `pitch_scale` / `volume_db`.
- `Sound.play_music("city")` / `Sound.play_ambience("rain")` â€” fade over to another track.

### Testing shortcut
Add `--sound_log` to a test run: every sound that plays is printed (`[Sound] footstep at (...)`).

---

## 13. The HUD (sharp overlay)

The HUD is everything on screen during a game that isn't the world or a menu: cash, loot / quest
line, HP, the extraction arrow, the scoreboard, the "[E] TALK TO..." prompt, the crosshair, what
you're holding, messages and the big EXTRACTED popup.

**It is drawn at your monitor's real resolution, on top of the game.** The game itself (3D city,
menus, CRT + dither) is still drawn at PS1 size (240 pixels tall) and blown up with chunky pixels;
the HUD is not part of that picture, so its text is crisp at any resolution and the CRT effect
doesn't bend or dither it.

### How the screen is put together (`scenes/game_screen.tscn`, the scene F5 runs)
```
GameScreen (Control)        script: ui/game_screen.gd  <- sizes everything when the window changes
â”œâ”€â”€ HUD (CanvasLayer)       <- an instance of scenes/ui/hud.tscn, Layer 10 = always on top
â”œâ”€â”€ Bars (ColorRect)        <- black, behind everything (the border in 4:3 / SHARP mode)
â”œâ”€â”€ GameView (TextureRect)  <- shows player 1's game picture, blown up (Texture Filter: Nearest)
â”‚   â””â”€â”€ GameViewport (SubViewport)   <- the "PS1 screen", 320x240 (wider on wide monitors)
â”‚       â””â”€â”€ Main            <- scenes/main.tscn, the actual game
â”œâ”€â”€ GameView2..4            <- made by the script when couch players join (split screen, below)
â”‚   â”œâ”€â”€ GameViewport > Camera3D      <- their 3D view (same world, their camera)
â”‚   â””â”€â”€ Post > Dither                <- the CRT + dither look on their picture
â””â”€â”€ JoinHint (Label)        <- "PRESS START TO JOIN" in the empty corner with 3 players
```
`game_screen.gd` works out the game picture's size from **SCALING** and **ASPECT** (Â§1, Â§10), and
passes your mouse and keyboard through to the game. Its Inspector knobs: **Game Height** (240),
**Design Width** (320), **Divider** (the black line between split screens, game pixels) and
**Split Full Detail** (see below).

**Split screen:** with 2-4 players on this computer (couch co-op, Â§10) the picture is cut up:
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
â””â”€â”€ Frame (Control)          <- resized to cover exactly the game picture; theme: ui/hud_theme.tres
    â”œâ”€â”€ Names (Control)      <- names over cats' and NPCs' heads (script ui/hud_name_tags.gd)
    â”œâ”€â”€ Bars (Control)       <- health bars over VAC-COPs / hurt cats, boss bar (ui/hud_health_bars.gd)
    â”œâ”€â”€ Damage (Control)     <- damage numbers off things you shoot (ui/hud_damage_numbers.gd)
    â”œâ”€â”€ Top (Control)        <- stays up while you talk / shop
    â”‚   â”œâ”€â”€ Cash             <- top-left, big green "$120"
    â”‚   â”œâ”€â”€ Carrying         <- "LOOT 2/6" or "QUEST: MITTENS' FISH 2/3"
    â”‚   â”œâ”€â”€ Health           <- your health bar, drawn in code (script ui/hud_health_bar.gd)
    â”‚   â”œâ”€â”€ DropOff          <- top-middle: "EXTRACT ^ 40m" / "THE SEWERS - SAFE ZONE"
    â”‚   â”œâ”€â”€ Heat             <- top-right: flashing red/blue heat bar (script ui/hud_heat_bar.gd)
    â”‚   â””â”€â”€ Scoreboard       <- top-right, under Heat: everyone's cash (sewers only)
    â”œâ”€â”€ Middle (Control)     <- hidden while the talk box or inventory is open
    â”‚   â”œâ”€â”€ Popup            <- big "EXTRACTED +$150" that fades out
    â”‚   â”œâ”€â”€ Crosshair        <- drawn lines (script ui/hud_crosshair.gd), only with a gun
    â”‚   â”œâ”€â”€ Message          <- what Don says, "KNOCKED OUT BY...", etc.
    â”‚   â”œâ”€â”€ Prompt           <- "[E] TALK TO DON CATLEONE" / "[E] OPEN STASH"
    â”‚   â””â”€â”€ Held             <- bottom-left: "R: PAW-PISTOL [###-------]"
    â”œâ”€â”€ Inventory (Control)  <- the Tab screen, builds its own boxes (script ui/inventory_ui.gd, Â§9)
    â””â”€â”€ NpcDialog (Control)  <- the talk box (script ui/npc_dialog.gd, Â§8)
        â””â”€â”€ Panel > VBox > Speaker, Scroll > Body > Line, Choices   <- choice buttons made by the script
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
(`Game.instance.show_message(...)` still works too: it calls `Hud.show_message`.)

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
- `cypurrpunk_long.mp4` â€” the 92-second trailer, 1920x1080 (YouTube, Steam, itch.io)
- `cypurrpunk_short_*.mp4` â€” 20-26-second vertical (1080x1920) cuts for TikTok, Instagram Reels and
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
(Steam / itch.io) in the post text; the trailers end on "COMING SOON" â€” change that card in `edit.py`
once there's a wishlist page.
