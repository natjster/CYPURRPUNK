# 10. Start menu, pause menu and Settings

[Back to the contents page](../SETUP_GUIDE.md)


### What the player sees
- **Start menu:** the big CYPURRPUNK logo (cat ears on a pink "PURR", glitchy neon shadows, HUD-style
  corner brackets; it flickers and glitches now and then) over the rainy city (the camera slowly pans),
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
  ("[E] TALK", "[E] PICKUP" by items, "TAB: close" in the inventory) always show the
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
| EFFECTS | CRT TV look (0-100%), screen shake (0-100%), PS1 wobble on/off, volumetric fog on/off |

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
├── Logo (Control)                <- script: ui/menu_logo.gd, the drawn CYPURRPUNK logo
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
- **`ui/menu_theme.tres`** — the menu look, matching the in-game HUD: translucent ocean-blue boxes,
  thin bright-blue edges with brighter corner brackets, chunky Consolas text, soft-pink titles. Used by
  the start menu, CHOOSE YOUR CAT / MY CAT, pause, settings and the on-screen keyboard. The boxes are
  **HudStyleBox** (`scripts/ui/hud_style_box.gd`): double-click the theme in the FileSystem dock, open
  **Button > Styles** (or **Panel**), click a style and change Fill / Border / Corner / Glow colours in
  the Inspector. Keep it in step with `ui/hud_style.tres` if you retune the HUD's blue.
- **The logo** — click **PS1Overlay > Lobby > Logo**: the Inspector has the three words (CY / PURR /
  PUNK), letter size, colours, ear size, glitch timing. It redraws live in the editor.
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
