# 23. MESS-MAKING ("Chaos versus Clean") and the MEOW taunt

[Back to the contents page](../SETUP_GUIDE.md)


You're a cat. OVERCLEAN is a neat freak. So: **make a mess.** Trash bins, traffic cones, cardboard
boxes and OVERCLEAN's "SHEDDING IS A CRIME" posters all over the city can be knocked over or
scratched. Every mess:
- tips the prop over with a clatter (bin lid flaps open, litter spills on the pavement),
- adds a little **HEAT** (0.4 each: ten messes = about 4 heat),
- counts on the **RAID REPORT** (the MESS number, and the AGENT OF CHAOS award, §22),
- and **distracts the VAC-COPs**: a patrolling bot within 14 m drives over, shows **TIDYING...**
  over its head, and vacuums for 3.5 seconds before the prop stands back up. While it's heading to
  a mess or tidying it, it only spots cats a third as far away as usual. So one cat trashes a
  corner while the other sneaks the Golden Koi past!
- When four messes happen within 20 seconds, OVERCLEAN complains over the speakers ("Shedding is
  a crime. Knocking things over is also a crime."), at most once every 75 seconds.

**How to make a mess:**
| Prop | Run into it | Drive into it | Shoot / bat it | E |
|---|---|---|---|---|
| Traffic cone | any walk | yes | yes | KNOCK OVER |
| Cardboard box | any walk | yes | yes | SHOVE |
| Trash bin (solid) | only with ZOOMIES (Shift) | yes | yes | TIP OVER |
| OVERCLEAN poster (on shop walls) | — | — | yes | SCRATCH |

| Fish vending machine (solid) | — | yes | yes | KICK |
| Fire hydrant (solid) | — | yes | yes | WRENCH OPEN |
| Shopping cart | any walk | yes | yes | SHOVE |
| Neon A-frame sign | any walk | yes | yes | KICK OVER |
| Dumpster (solid) | — | yes | yes | RUMMAGE |

Cones lying down when the district starts are old mess (scenery): only standing ones count.

### THE STREET PROPS PACK: props that DO things
Five chunky Blockbench props that each count as a mess (heat, RAID REPORT, bots come to tidy) AND do
something fun:
- **FISH VENDING MACHINE** ("FISH 2 GO", against shop walls, and one by Meow-Mart's door): kick it and
  it jolts back, the glowing screen fizzes out, the dispense flap swings open and sparks + snacks spill
  out. The FIRST bust of each machine per district drops a **sardine** (or, 1 in 5, a **fish**) on the
  pavement in front of it. A machine a VAC-COP repaired still sparks if you kick it again, but it
  won't pay out twice.
- **FIRE HYDRANT** (sidewalk corners, by the kerb): wrench it open and the cap pops off and a glowing
  **WATER GEYSER** sprays for 12 seconds. Step into it (within 1.3 m) and your cat is **launched ~9 m
  into the air** (a jump pad: reach rooftops, escape a chase). Drive through it and your car bounces.
  Any VAC-COP or drone within 2.4 m is **shorted out** (stunned 3.5 s, shoved away). No bot comes to
  tidy a hydrant while it's spraying.
- **MEOW-MART SHOPPING CART** (by Meow-Mart, in yard junk piles, sometimes dumped on a corner): shove
  it (E, or just walk into it) and it **rolls ~8.5 m** the way you pushed, stopping short of walls,
  then tips onto its side. Anything in its path is **bowled over**: bins, cones, boxes, other carts
  and neon signs get knocked down (counted as YOUR messes), and bots get stunned 3 s, flung and take
  25 damage. Line one up at a VAC-COP!
- **NEON A-FRAME SIGN** (sidewalk corners, outside Meow-Mart): a sandwich board with a glowing fish +
  noodle bowl. Knock it flat and the neon dies in a shower of sparks.
- **DUMPSTER** (empty yards, the side of Meow-Mart): rummage it and the lid flies open on its hinge,
  trash bags spill out, and the FIRST rummage of each dumpster per district has a **35% chance of a
  SCRAP**.

Lots more of them on **BIN DAY** (more carts, cones, boxes and bins by Meow-Mart and in the yards; more
hydrants, signs and carts on corners). In a **BLACKOUT** the vending screens and neon signs are dark.

Not counted: bosses, SEWER BREACH bots, SQUIRT-DRONES and LINT-TRAPPERS never stop to tidy.

### MEOW = the taunt
Press **M** (keyboard) or **B** (controller) — rebind it in SETTINGS > KEYS ("MEOW"). Your cat **SHOUTS
"GO LICK YOURSELF!"** on everyone's screen: the whole line slams up over its head at once in big white
outlined text (no box), shakes like a yell and fades out; your cat puffs up tall, screens near it get a
little shake, and it yells in a quick burst of its own voice.
Pick your cat's **VOICE** in MY CAT: **MALE** (low) or **FEMALE** (high). On top of that, every
cat's pitch is nudged by its fur, eye and marking colours, so two cats never sound quite the same. VAC-COPs within **22 m hear it**: they turn amber, a **?**
pops up over them and they drive over to look. Lure them away from a teammate, or into a trap.
(1.2 seconds between meows.)

### Tuning (Inspector)
- **Main > Mess** (`scripts/mess_manager.gd`): Heat Per Mess, Bin Knock Speed (6 m/s: zoomies only),
  Light Knock Speed, Bump Reach, Car Knock Speed / Reach, Interact Reach, the [E] prompts (one per
  kind of prop: Vending Prompt "KICK", Hydrant Prompt, Cart Prompt, Neon Sign Prompt, Dumpster Prompt),
  **Street props pack: loot** (Vending Fish Chance 0.2, Vending Common / Rare Item, Dumpster Scrap
  Chance 0.35), and
  the OVERCLEAN remark rules + their sounds and subtitles (keep the subtitles matching
  `tools/sound_specs/mess.json`).
- **Main > City** (`city_generator.gd`) > Street props: the models, Yard Boxes Min/Max,
  Poster Chance (0.35 per building), Corner Prop Chance, Bins Are Solid, and the STREET PROPS PACK:
  the five model files, **Vending Chance** (0.18 per building), **Yard Dumpster Chance** (0.6), **Yard
  Carts Min/Max** (0-1), **Heavy Props Are Solid** (vending machines, hydrants, dumpsters). Which
  corner prop is picked (bin / cone / box / bin+cone / hydrant / neon sign / cart) is the `roll`
  ladder in `_corner_prop`.
- **The props' own numbers** (geyser 12 s, launch 13.5 m/s, stun 2.4 m, cart roll 8.5 m in 0.7 s,
  bowling reach, damage, lid / tilt angles): the plain `var`s at the top of `scripts/mess_prop.gd`
  (props are built in code, so the Inspector can't reach them).
- **Every VAC-COP scene** (`scenes/roomba.tscn`, root) > Mess + Meows: Tidies Messes, Mess Notice
  Range, Tidy Seconds, Distracted Sight, Hears Meows, Investigate Seconds.
- **scenes/player.tscn** (root) > Meow Taunt: Taunt Lines (add more and one is picked at random),
  Taunt Shout Blips / Taunt Blip Gap / Blip Volume Db / Taunt Shout Pitch (the yell), Taunt Seconds
  (how long the line stays), Taunt Color (white), Taunt Puff (how tall the cat puffs up), Taunt Shake /
  Shake Radius, Meow Heard From. How the line slams in and shakes: **scenes/ui/hud.tscn** > HUD > Frame >
  **Names** > Shouts (Shout Pop, Shout Slam Seconds, Shout Shake, Shout Tremble, Shout Fade). Sounds > Meow Cooldown.
- **A new voice** (e.g. "robot"): add it to `VOICES` and `VOICE_NAMES` in `scripts/cat/cat_look.gd`
  and make its blips: a `"kind": "blips", "cat_id": "cat_robot"` line in `tools/sound_specs/mess.json`.

### The new models and sounds
- `models/blockbench/cardboard_box.bbmodel` (36 triangles, the Flaps group = the two top flaps) and
  `models/blockbench/overclean_poster.bbmodel` (24 triangles: the **Poster** group is the clean sheet,
  **Torn** is the shredded strips shown once scratched — keep those two group names if you repaint
  it). Recipes: `tools/model_specs/cardboard_box.json`, `overclean_poster.json`.
- Sounds: `python tools/cypurr_sound.py batch tools/sound_specs/mess.json` remakes them all (the
  three OVERCLEAN lines, box thump, poster scratch, vacuum tidy, stand-up tap, curious chirp and the
  MALE / FEMALE player voices). New Sound Lab presets `cardboard_thump` and `vacuum`, and a spare tool
  **generate_cat_taunt** (a meow + any line in a squeaky text-to-speech cat voice; not used in the game).

### How it works (for Claude / the curious)
The city builds every mess prop in a fixed order (`CityGenerator.mess_props`, `_add_mess_prop`), so
prop #17 is the same bin on every computer; only that number goes over the network. Whoever noticed
the knock (the cat's owner, the driver, the shooter, the presser) calls `MessManager.knock(player_id,
id, direction)` -> host `request_knock` (checks the player is theirs and up top) -> `_set_knocked`
RPC to everyone (`MessProp.show_knocked`) + heat + `Events.mess_made`. Bots: `roomba.gd` states
`TIDY_GO` / `TIDYING` (`MessManager.claim_nearest` so two bots don't take the same mess,
`MessManager.tidy`) and `INVESTIGATE` (`RoombaPatrol.hear_noise` from the cat's `_meow` RPC on the
host). Late joiners get the knocked list (`send_state_to`). A new district builds a new city, so
every mess is gone. Bins are on collision layer 4 (cats bump into them; cars and bots don't),
other props on layer 5 (only bullets).
SCAVENGING (finding items in the street): the first bust / rummage / knock of a VENDING MACHINE,
DUMPSTER, TRASH BIN or CARDBOARD BOX each district rolls ONE item from that prop's "finds" table and
drops it in front of it. Every item can turn up: food, snacks, the neon bat and every gun (dumpsters
are the gun stashes; the tommy gun, yarn-zooka, cucumber launcher and red dot are rare there).
To change the odds: scenes/main.tscn -> select **Main > Mess** -> Inspector -> **Street Props Pack:
Loot** -> Vending Finds / Dumpster Finds / Bin Finds / Box Finds. Each line is item id -> weight
(bigger = more likely; chance = weight / all weights added up). The empty id "" = "nothing in here".
Ids are the `id` on the item cards in `res://items/`. A typo prints "unknown item id" in the Output.
STREET PROPS PACK: the host pays out loot in `MessManager._drop_loot` (`finds_for(kind)` + `roll_find`,
`_looted_props`, cleared each district) and `host_knock` is the one place a knock happens (a rolling cart calls it directly for
what it bowls over). The geyser and the cart's roll run on every computer from the same `_set_knocked`
message; where a cart stops comes from a ray against the city's STATIC bodies only, so it's the same
spot everywhere. Each computer launches its OWN cats / driven car from the geyser; only the host
stuns bots.

### Testing
Every mess test prints `DevCapture mess (...)` lines: props by kind, which are knocked, made /
tidied counts, heat, and what every bot is doing.
- Knock the 3 nearest props + see them on the report:
  `--host --deploy --mess=3 --raid_report --raid_report_after=250 --frames=400 --capture=shots/x.png`
- Zoomies into a bin with real input: `--host --deploy --ram_prop=bin --frames=200 --capture=shots/x.png`
  (`=cone` / `=box` walk into one; `--ram_trace` prints speed and gap every few frames).
- Scratch a poster with E: `--scratch`. Shoot one: `--shoot_prop`.
- Watch a bot tidy (bots can't see you): `--host --deploy --ram_prop=bin --ghost --face_mess --bait_mess=4
  --mess_log=50 --frames=300 --capture=shots/x.png --scale=2`
- A bot hears a meow from out of sight: `--host --deploy --bait_roomba=18 --meow --frames=160 --capture=shots/x.png`
- Host + late-joining client (both print the same knocked list): host `--host --deploy --mess=2
  --frames=1100`, ~9 s later client `--join --wait=60 --deploy --mess=2 --frames=400`.
- STREET PROPS PACK (KIND = vending, hydrant, cart, neon_sign, dumpster; each prints `DevCapture prop`
  lines: knocked, geyser seconds, where a cart stopped, lid / cap / flap, glow, loot dropped):
  - Kick a machine, have a bot fix it, kick it again (one sardine only):
    `--solo --deploy --use_prop=vending --prop_twice --frames=700 --capture=shots/x.png`
  - Geyser jump pad + a bot shorted out: `--solo --deploy --use_prop=hydrant --geyser_jump --geyser_bot --frames=700 --capture=shots/x.png`
  - Cart bowling (a bot + a cone put in its path): `--solo --deploy --use_prop=cart --cart_bowl --frames=600 --capture=shots/x.png`
  - Run into a cart / sign: `--ram_prop=cart` / `--ram_prop=neon_sign`. Shoot one: `--shoot_prop=vending`.
  - Late joiner's view of each kind: `--instant_props`. Screenshot one: `--look_prop=KIND` (or the film
    camera: `--no_hud --cam_from=X,Y,Z --look_from=X,Y,Z`).
  - Same city everywhere: the `DevCapture mess` line's `layout=` hash must match for the same seed
    (also with `--twist=bin_day`).
