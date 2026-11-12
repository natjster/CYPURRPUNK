# 8. The extraction loop: the Sewers hub + Fish Heist

[Back to the contents page](../SETUP_GUIDE.md)

**§8 is split into parts** (one file each, so each stays small):
- [The Mainframe, scrap & the Sewer Breach](08b-mainframe-and-sewer-breach.md)
- [The stash, NPCs & quests](08c-stash-npcs-quests.md)
- [Fish Heist: districts, manholes and payphones](08d-fish-heist-districts.md)
- [VAC-COPs, their backup & HEAT](08e-vac-cops-and-heat.md)
- [Health, revives, health bars & damage numbers](08f-health-and-damage.md)



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
  does to VAC-COPs). The feed (top-left: downs, knockouts, robberies; each line fades after 4 s): **Feed Seconds** /
  **Feed Lines** / **Feed Fade Seconds** on the HUD root in `hud.tscn`.
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
middle, two bridges, work lights, cardboard-box shanties, **The Mainframe** (a scrounged-together
computer on the west wall: press E for its window and feed it ELECTRONICS, see **The Mainframe** in §8) and, at the north end of the west
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
Press **E** to talk to him (ask who he is, what this place is...), then pick **SHOW ME THE GOODS** and
**THE BLACK MARKITTEN shop screen** opens. It's in
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
| SCRAP | - | never (badge says SCRAP): pays for upgrades at the Tinker Workbench |
| ELECTRONICS | - | never (badge says POWER): feed THE MAINFRAME |

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
- **Move the shop:** drag ComradeWhiskers under **Hub**. The stall and its lights are placed around
  him by `_build_shop()` in `scripts/hub.gd`, so they follow. The stall is ONE 3D model,
  `models/black_markitten.glb` (counter with a till + NO BOTS sign, wall shelves of glowing goods,
  crates, a tin awning, the BLACK MARKITTEN banner). It's made for him standing **2 m out from the
  west wall**, facing east, so move him along that wall (change Z), not away from it.
  **Banner colour:** select **Hub** > Inspector > **Banner Color**.
  **Repaint / reshape it:** open `models/blockbench/black_markitten.bbmodel` in Blockbench, then
  File > Export > Export glTF Model over `models/black_markitten.glb` (or edit the recipe
  `tools/model_specs/black_markitten.json` and run `python tools/cypurr_models.py all tools/model_specs/black_markitten.json`).
- **The cardboard-box homes** on the east wall are the model `models/box_shanty.glb` (doorway,
  blanket curtain, lit window, tin-can chimney; recipe `tools/model_specs/box_shanty.json`), placed by
  `_build_shanties()` in `scripts/hub.gd`. Add or move homes: edit `SHANTY_SPOTS` there (metres along the wall).
- **How it works:** he runs `scripts/npcs/shopkeeper.gd` (an NPC: E opens his talk box, and SHOW ME THE GOODS opens
  `scripts/ui/shop_screen.gd`, `ShopScreen`, at **HUD > Frame > Shop**). BUY asks the host
  (`ItemManager.request_buy`: price, crate unlock, room, cash); SELL asks `request_sell(player, where,
  index)` / `request_sell_all_loot(player)` (in the sewers only). Messages ("Bought ...", "Sold ...")
  show in the shop's bottom box. Make another shopkeeper: set an NPC's script to `shopkeeper.gd`.
- **Test:** `--cash=500 --give=pistol,fish --talk=ComradeWhiskers --shop_tab=2 --shop_buy=neon_bat
  --shop_sell=hand:0,pack:0 --shop_sell_all --shop_pad=down,left --shop_close=Tab` ("DevCapture shop" lines).
