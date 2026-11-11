# 19. The TUTORIAL (PLAY > TUTORIAL)

[Back to the contents page](../SETUP_GUIDE.md)


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
