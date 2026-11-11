# 8. The extraction loop — Health, revives, health bars & damage numbers

[Back to the contents page](../SETUP_GUIDE.md) · [Start of §8](08-the-extraction-loop-the-sewers.md)

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
  (white, e.g. `27`), floating up and fading. **Critical hits** are bigger and yellow
  (`84`). Only the shooter sees their own numbers (on their own screen in split screen).
  When **you** lose health, a **red** number pops off your own cat's head the same way (Hurt Color /
  Hurt Font Size; how high it starts = `hurt_number_height` at the top of `scripts/feedback.gd`).
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
