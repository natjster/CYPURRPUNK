# 8. The extraction loop — The stash, NPCs & quests

[Back to the contents page](../SETUP_GUIDE.md) · [Start of §8](08-the-extraction-loop-the-sewers.md)

### The stash (THE LITTERBOX) & saved progress
**THE STASH is a giant glowing LITTERBOX** (a 3D model: purple plastic tray with a dip in the
front rim to hop in, sand mounds, a torn KITTY LITTER sack, buried loot poking out of the sand,
a glowing cyan scoop, and a cyan neon **LITTERBOX** sign) on the **east wall**, across from the Black Markitten (north of Lil' Mittens).
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
  neon strip and light) and **Sand Color** (the model's plastic and sand are painted grey, so these
  two colours still recolour them). The model is `models/litterbox.glb`: to repaint it, open
  `models/blockbench/litterbox.bbmodel` in Blockbench and export it over the .glb; to rebuild it from
  its recipe run `python tools/make_litterbox_spec.py` then
  `python tools/cypurr_models.py all tools/model_specs/litterbox.json` (this replaces Blockbench
  edits). The code that places it, plus its invisible solid walls/sand, is `_build_stash()` in
  `scripts/hub.gd`.

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
