# 8. The extraction loop — The Mainframe, electronics & the Sewer Breach

[Back to the contents page](../SETUP_GUIDE.md) · [Start of §8](08-the-extraction-loop-the-sewers.md)

### The Mainframe & electronics
**ELECTRONICS** only come from a destroyed **MEGA VAC-COP** (a fried circuit board that glows
purple on the street; grab it with E). A MEGA VAC-COP drops **one per cat up top** (and one SCRAP per cat too).
Electronics take 1 backpack slot and the shop won't buy them: they come home in your backpack like
all loot. A knockout loses them, like any loot. Spares can go in your litterbox.

**SCRAP is not Mainframe food any more**: it only pays for SEWER UPGRADES at the Tinker Workbench (§25).

**THE MAINFRAME** is the rebels' home-made computer on the west wall of your sewer: a big old CRT on
a pallet, crates, car batteries, a desk fan and a wok for a satellite dish, with a **FEED ME
ELECTRONICS** chute at cat height. **Each gang has its own**. Its charge is **4 battery cells** of 25%
(0-100%); the rack on its right shows them glowing, and the desk fan spins faster the more cells are lit.
A new game starts both at **75%** (3 cells; charges are not saved between games).

It **drains**:
- **slowly**: -1% a minute while anyone is up top (each cell lasts 25 minutes of raiding),
- **and** -25% every time a district is sealed, for every gang with at least one player in the game.

The **tier** is how many cells still have juice: 63% = 3 cells = SYSTEM ONLINE. So 1 electronics always
buys a whole tier, and the slow drain only costs you a tier when a cell runs dry (a line in the feed
tells you: `MAINFRAME DRAINED: POWER LOW (EXIT AT 82 HEAT)`).

Walk up to it and press **E** (`[E] THE MAINFRAME (63%)`): its **window** opens, like the shop. It
explains what it does and shows the cells, your exit heat, the city's starting heat, the slow drain and
how long until the next cell runs dry, plus a tier table. Its button, with electronics in your pack:

- **FEED 1 ELECTRONICS (+25%)** when your Mainframe is under 90%.
- **HACK RIVAL MAINFRAME (-25%)** when yours is full (90%+) and a rival gang in the game is above
  0%. Everyone sees it in the HUD feed.
- **MAINFRAME FULL** at 90%+ with nobody to hack (solo, one gang, or the rival is at 0%): keep your
  electronics in the litterbox for when it drains.

Esc / Tab / B closes it; walking away closes it too.

Your gang's charge sets when **your** exit opens. The **lowest** charge of any gang in the game sets
how the shared city starts:

| Cells (charge) | CRT says | Your exit opens at | City start (lowest gang) |
|---|---|---|---|
| 4 (75.1-100%) | OVERCLOCK ACTIVE (cyan) | 60 heat | 0 heat, and heat rises 20% slower |
| 3 (50.1-75%) | SYSTEM ONLINE (green) | 75 heat | 0 heat |
| 2 (25.1-50%) | POWER LOW (yellow) | 82 heat | 15 heat |
| 1 (0.1-25%) | WARNING (orange) | 90 heat | 30 heat |
| 0 (empty) | CRITICAL (flashing red) | 95 heat | 50 heat, with 1 MEGA VAC-COP already up top |

- Exit timing follows your charge live, so feeding mid-district can open your exit sooner. Once an
  exit has opened it **stays open** for that district, even if a rival hacks you.
- Anything that changes the lowest charge **before anyone goes up** (feeding, hacking) changes the
  current district's start straight away.
- The seal drains just **before** the next district starts, so a district only starts OVERCLOCKED if you
  top up in the sewers before anyone goes up. Every gang in the game must have 4 cells for it.
- If everyone's home, heat only races to the DEEP CLEAN once **every** gang's exit has opened (or
  everyone has used their trip), so an early exit can't rob the other gang of its turn.
- The payphones ring for any gang with an open exit that hasn't called. If it's not your exit yet,
  your boss still says they're digging.

The top-right bar shows **your gang's Mainframe** in the sewers and the **HEAT** up in the city,
with a white **EXIT** tick where your gang's exit opens.

**Where it lives:** `scripts/mainframe.gd` on the **Mainframe** node in `main.tscn` (one node, all
gangs' charges).

**Tuning:** select **Mainframe** in `main.tscn`: **Charge** (Starting Charge, Drain Per District,
**Drain Per Minute** (the slow drain, 0 = off), **Drain Only While Raiding** (off = it drains in the
hub too), **Full At** (90), Charge Per Electronics, Hack Per Electronics), **Exit Opens At Heat**,
**Starting Heat Per Tier**, **Overclock** (Overclock Heat Multiplier). The item card is
`items/electronics.tres` (model `scenes/items/electronics.tscn`); the MEGA VAC-COP's drops are on
`scenes/roomba_boss.tscn` (Drop On Destroy = electronics, Drop Also = scrap). The spot you stand on:
**Hub** and **GangHub** > **Mainframe** > Mainframe Spot (the model follows its Z, always on the west wall).
The window's words and sizes: `hud.tscn` > **Frame** > **Mainframe** (About Text, Default Info...).
The model: `models/mainframe.glb`, made by `python tools/make_mainframe_spec.py` then
`python tools/cypurr_models.py all tools/model_specs/mainframe.json` (or open
`models/blockbench/mainframe.bbmodel` in Blockbench, repaint, and export over the .glb).
The EXIT tag's size: `hud.tscn` > **Heat** > Exit Tag Size.

**Test it without playing:** `--mainframe=N` sets every gang's charge, `--mainframe=100,50` sets them
per gang (Catleone, Burrow), and the district restarts on it.
`--give=electronics,electronics --mainframe_window=2` walks to it, opens the window and presses FEED twice.
`--teams=0,1 --add_local=1 --mainframe=100,75 --give=electronics --mainframe_window=1` hacks.
`--deploy --mainframe_drain=600` drains 10% a second (watch the cells run dry).
`--mainframe=0 --deploy --kill_roombas=40 --kill_bosses` counts the electronics + scrap the bosses drop.
`--teams=0,1 --add_local=1 --mainframe=100,75 --deploy --heat=70` shows one exit open and one shut.
`--to_stash=pack:0` stashes electronics. On a client, add `--wait=120` first.

### The Sewer Breach (a Mainframe at 0%)
When a gang's Mainframe hits **0%** (hacked from 25%, or drained by a sealed district), it gets a
warning and two chances before OVERCLEAN comes for that gang's sewer:

1. **One last raid:** the next district runs at **0% CRITICAL** (50 heat, a MEGA VAC-COP already up
   top to hunt for electronics, exit at 95 heat), and the gang's cats get a `LAST CHANCE` banner.
2. **The siren:** if that district is sealed with the gang still at 0%, then once no cat is left up top
   and knocked-out cats are home, a siren counts down **15 seconds**
   (`FEED THE MAINFRAME! BREACH IN 12s`). The next district waits for it. Run to the stash and the
   Mainframe: feeding electronics in time stops it.
3. **Otherwise, the breach starts:**

- **The tunnel:** the iron **Blast Gate** at the north end of the west walkway slides up, the tunnel
  pulses red, and a horde pours out: **35 bots + 2 MEGA VAC-COPs**. They hunt every cat in that sewer.
- **No safe zone** in that sewer: guns and melee work, nobody heals, and a cat at 0 HP stays where it
  fell. Gang-mates can still revive you. A knockout here **keeps your gear**.
- **Your loot is safe from the horde:** breach bots hit you but don't vacuum your bag, and nothing
  a breach bot does adds to the city's heat. Anything dropped on a sewer floor (a boss's electronics too)
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
  electronics and scrap, and only a bot you finish yourself counts for quests: the self-destruct pays nothing.)

**Test it without playing:** `--mainframe=25 --heat=100 --heat_hold=30` drains to 0% (a last raid, no
breach). `--mainframe=0 --heat=100 --heat_hold=30 --breach_warning=2 --breach_seconds=3 --breach_log=60`
runs the siren, the breach and the Miracle. Add `--wait=120 --give=electronics --mainframe_window=1`
to feed electronics in time.

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
