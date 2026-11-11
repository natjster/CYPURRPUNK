# 8. The extraction loop: the Sewers hub + Fish Heist

[Back to the contents page](../SETUP_GUIDE.md)


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
