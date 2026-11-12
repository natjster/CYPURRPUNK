# 27. INSIDE MEOW-MART: the first real heist (ROADMAP §4 #8)

[Back to the contents page](../SETUP_GUIDE.md)


Meow-Mart is a **real walk-in store**: it takes the whole south half of a city block, and the
supermarket is right there behind its glass front. Walk up, the sliding doors open (pneumatic
`door_slide`), and you just **walk in** — no teleport, no loading. You can see the street through the
glass from inside, and the shop's glow from the street.

### The outside (the BADASS part)
- **Corrugated plum-metal walls** with a roof parapet, and a tall **sign facade** with MEOW-MART in giant
  pink neon letters and a cyan "24/7 * FISH * CATNIP * NO DOGS" strap line.
- A **pink neon frame** round the glass, a steel **awning** over the doors with a cyan neon lip.
- On the roof: a **GIANT NEON CAT HEAD** (glowing green eyes that blink), and **AC units** with spinning fans.
- **OVERCLEAN security cameras** sweeping the street from the front corners (and three more inside,
  one watching the koi tank), red lenses glowing.
- Inside: a row of glowing **FROZEN freezer cases** on the back wall and a nest of shopping carts by the door.
- The old line of fish in front of the door is gone (it blocked the entrance).

### What's in there
```
 north +-------------------------------------------------------------+
       |  BACK ROOM:  [security monitor]   [GOLDEN KOI TANK]  [crates] |
       |---------------------------------------[EMPLOYEES ONLY door]---|
       | [SECURITY SCALE]   [AISLE 1]     [AISLE 2]       [FRESH CATCH] |
       |                                                    counter    |
       |  [HEAVY basket]  [CHECKOUT lanes]                              |
 south +--------------------[ sliding doors -> street ]---------------+
```
- **Loot:** Fresh Catch ($75) on the iced seafood counter, Gourmet Tuna ($60) and Catnip Treats
  ($80) on the shelves. `[E] PICKUP` as usual (loot always wins the E key).
- **AISLES:** stepped shelves you can hop up like stairs. **Can stacks** sit on the ledges: run
  into one (or `[E] SWAT`) and it clatters to the floor = **1 mess** (a little heat, counts on the
  RAID REPORT's MESS column and BIN DAY's chaos bonus). The high ones need a hop. **Run at an aisle's
  END with zoomies** (or press `[E] TOPPLE` while running) and the whole row falls like dominoes:
  **10 messes**, cans everywhere.
- **The SECURITY SCALE** (glowing red pad by the west wall): put weight on it and the **EMPLOYEES
  ONLY** roller door across the store opens (the pad turns green). Step off and it shuts
  **1.5 seconds** later — too fast to run over there yourself.
  - **Co-op:** one cat stands on the scale while the other runs into the back room.
  - **Solo:** shove the **HEAVY basket** onto it (walk into it to push it, or `[E] DRAG BASKET`
    to pull it behind you, `[E] LET GO OF BASKET` to drop it).
  - Inside the back room a green **PUSH TO EXIT** bar (`[E] OPEN DOOR`) opens the door for 4
    seconds, so nobody gets locked in.
- **THE GOLDEN KOI TANK** (back room): hit it 3 times (bolts, bat swings, blasts, or `[E] SCRATCH THE
  GLASS`) or **pounce into it with zoomies** and it **shatters**: glass and water everywhere, and
  the **Golden Koi** ($400) flops onto the floor for you to grab.
- **THE STORE ALARM** (the moment the glass breaks): red strobes and a klaxon inside (and a red light
  + klaxon over the street doors), OVERCLEAN on the speakers, **+25 heat at once** (a whole heat
  level), and **4 extra VAC-COPs** roll in while every bot within 90 m is called to Meow-Mart's front
  door for 45 seconds. **No bots come inside** — the gauntlet is the street: get the heavy, jingling
  koi to your car or the exit through the crowd.
- Inside the store the rain stops, the light turns fluorescent (and the moon goes off unless someone
  on your couch is still outdoors). Split screen works: one player shopping, the other driving.

### Tuning (no code)
Open `scenes/main.tscn`, click **Main > MeowMart**, and look in the Inspector:
- **Enabled** — off = Meow-Mart is a solid pink box nobody can go in, and the golden koi goes back to a random sidewalk.
- **Doors:** *Door Open Distance* (3.2 m), *Door Slide Speed*.
- **Outside:** *Cladding Tint* (the wall metal), *Sign Color* (pink neon), *Trim Color* (cyan neon),
  *Cat Sign Scale* (the rooftop cat head, 1.25), *Camera Sweep* (how far the cameras swing).
- **Look:** *Fog Color / Fog Albedo / Ambient Color / Ambient Energy* (the store's haze), *Ambience*
  (the hum), *Light Color / Light Energy / Light Range* (the tubes), *Flicker Chance*.
- **Mess:** *Swat Bump Speed*, *Swat Reach*, *Swat Heat*, *Topple Ram Speed* (6 = zoomies only),
  *Topple E Speed*, *Topple Mess* (10), *Topple Heat*, *Domino Delay*, *Topple Cans*.
- **Back Room Puzzle:** *Plate Close Delay* (1.5 s), *Exit Button Seconds*, *Crate Push Speed*,
  *Crate Drag Distance*.
- **Golden Koi Tank:** *Tank Item* (`golden_koi`), *Tank Hits To Break* (3), *Pounce Speed*, *Tank Mess*.
- **Store Alarm:** *Alarm Heat* (25), *Alarm Seconds* (60), *Ambush Bots* (4), *Ambush Call Range*
  (90 m), *Ambush Call Every* (6 s), *Ambush Seconds* (45), *Alarm Sound* and *Alarm Line*.
- **The pavement props** outside (vending machine, A-frame, carts, dumpster) are on **Main > City**:
  *Props At Meow Mart*.
- **The 3D models** (`models/mart_cat_sign.glb`, `security_cam.glb`, `rooftop_ac.glb`, `freezer_case.glb`)
  come from recipes in `tools/make_meow_mart_specs.py`; open `models/blockbench/<name>.bbmodel` in
  Blockbench to repaint one, then ask Claude to re-export it.
- **The new loot** cards: `items/fresh_catch.tres`, `items/gourmet_tuna.tres`, `items/catnip_treats.tres`
  (models `scenes/items/tuna_can.tscn`, `catnip_treats.tscn`; the Fresh Catch reuses the fish model).

### How it works (for Claude / the curious)
- The store is built once from code (`Main/MeowMart`, `scenes/interiors/meow_mart_interior.tscn` ->
  `scripts/interiors/meow_mart_interior.gd`, class `MeowMartInterior`; the outside dressing is
  `scripts/interiors/meow_mart_exterior.gd`) and **moved onto its block** every district:
  `CityGenerator._build_meow_mart(block_center)` calls `place_in_city(...)` (the store always faces
  south, +z; it waits hidden at y = -50 until then). Its floor is 6 cm above the street (`FLOOR_LIFT`)
  so it never flickers with the pavement. `MeowMartInterior.contains(pos)` = "inside the walls";
  `hub.mood_at` returns `MART_MOOD` there.
- The city side: `city.meow_mart_door_spot` (the doorway), `meow_mart_position` (1 m out in the
  street). The store's footprint is `MeowMartInterior.outer_size()`; the lamp that would stand in
  front of the doors is moved 7 m along.
- Host-decided, everyone shown: `request_swat / request_topple / request_tank_hit / request_drag /
  request_push / request_exit_button` (first argument = player id, `PlayerId.sender_owns`) ->
  `_swat / _topple / _set_tank_hits / _shatter / _set_alarm / _set_doors / _set_crate` RPCs.
  Late joiners: `send_state_to` -> `_receive_state`. New district: `start_district` -> `_reset`.
- Messes go through `MessManager.count_mess(player_id, amount, heat)` (Events.mess_made). The alarm:
  `HeatMeter.add_heat(alarm_heat, true)` (instant, not trickled), `RoombaPatrol.ambush(spot, bots, reach)`,
  `Events.store_alarm_tripped`. Bots never chase a cat inside (`Roomba._can_chase`).
- Every wall/shelf in the store hands bullet hits to the interior node (`receive_hit`); the tank has
  its own `HitRelay` (`scripts/interiors/hit_relay.gd`) because bat swings and blasts aim at the
  target's own position.

### Testing
- `--host --seed=1999 --test_meow_mart=4 --hold=move_forward --hold_frames=110 --mart_log=30` walks you
  in (the log's `in=true`). Film shots: `--seed=1999 --no_hud --cam_from=-7,4,8 --look_from=-18,5,-10`.
- `--inside_meow_mart[=foyer|plate|aisle|tank|backroom|counter|door]` puts you inside.
- `--shatter_tank[=F]` (host) breaks the tank: prints `DevCapture mart shatter: ... heat 0.7 -> 26.3 ...`.
- `--mart_swat=N`, `--mart_topple=1|2`, `--mart_plate`, `--mart_drag`, `--mart_tank_hits=N`, `--mart_log[=N]`
  ("DevCapture mart" lines). Late joiner: host `--deploy --inside_meow_mart --mart_topple=1 --mart_drag
  --shatter_tank=5 --frames=1500`, client `--join --mart_log=60` 14 s later.
- Split screen: `--solo --join_pad=1 --deploy --hold_all --inside_meow_mart`.
