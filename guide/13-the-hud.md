# 13. The HUD (overlay)

[Back to the contents page](../SETUP_GUIDE.md)


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
