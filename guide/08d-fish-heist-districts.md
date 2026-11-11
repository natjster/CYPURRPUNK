# 8. The extraction loop — Fish Heist: districts, manholes and payphones

[Back to the contents page](../SETUP_GUIDE.md) · [Start of §8](08-the-extraction-loop-the-sewers.md)

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
   text right above the phone** (in their voice, coming out of the phone), and the **blue HUD
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

**HUD (kept simple on purpose):** top-left = your **health bar**; top-middle = the **big blue 3D
arrow** (below), or `THE SEWERS - SAFE ZONE` in the hub; top-right = everyone's cash,
**only while you're in the sewers**.

**THE BLUE ARROW ("Crazy Taxi" style, `scripts/ui/hud_compass_arrow.gd`):** a chunky bevelled 3D
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
  It uses the shared ocean-blue HUD colours (`ui/hud_style.tres`, same as the weapon box and talk
  box) and its words sit in a matching little box. Select it for the knobs: **Use Hud Style** (untick
  to use your own **Arrow Color**, **Edge Color**, **Label Color**), **Arrow Size**,
  **Tilt Degrees** (how much of its top you see), **Thickness**, **Bevel**, **Snap** (PS1 wobble;
  0 = smooth), **Label Font Size**, **Turn Speed**, **Bob Height/Speed**, **Pulse Amount**,
  **Urgent Speed**, **Urgent Pulse**.
- **When it hurries:** **Heist** node in `main.tscn` > Inspector > **The blue arrow (HUD)** >
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
