# 22. The RAID REPORT (end of every district)

[Back to the contents page](../SETUP_GUIDE.md)


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
- **Colours (the HUD's ocean blue)**: it matches the HUD and the menus: same font and boxes (the
  node's **Theme** is `ui/menu_theme.tres`), one blue panel with corner brackets round the whole
  report, a faint strip behind each cat's row (your own cats' strips get a seat-coloured edge) and a
  line under the column names. Title / Value / Text / Dim Text / Cash colours, Panel Fill / Edge,
  Row Fill / Edge (alpha 0 = no strips), Header Line, Backdrop Color.
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
