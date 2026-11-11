# 27. INSIDE MEOW-MART: the first real heist (ROADMAP §4 #8)

[Back to the contents page](../SETUP_GUIDE.md)


Meow-Mart's front is now a **glass storefront with sliding doors**. Walk up and they slide open
(pneumatic `door_slide`); walk through and you're **inside a neon-lit supermarket**. Walk back out
through the same doors (they're right behind you when you come in) and you're on the sidewalk in
front of the shop again.

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
- **Enabled** — off = the doors stay shut and the golden koi goes back to a random sidewalk.
- **Doors:** *Door Open Distance* (3.2 m), *Door Slide Speed*, *Door Cooldown*.
- **Look:** *Fog Color / Fog Albedo / Ambient Color / Ambient Energy* (the store's haze), *Ambience*
  (the hum), *Light Color / Light Energy / Light Range* (the tubes), *Flicker Chance*.
- **Mess:** *Swat Bump Speed*, *Swat Reach*, *Swat Heat*, *Topple Ram Speed* (6 = zoomies only),
  *Topple E Speed*, *Topple Mess* (10), *Topple Heat*, *Domino Delay*, *Topple Cans*.
- **Back Room Puzzle:** *Plate Close Delay* (1.5 s), *Exit Button Seconds*, *Crate Push Speed*,
  *Crate Drag Distance*.
- **Golden Koi Tank:** *Tank Item* (`golden_koi`), *Tank Hits To Break* (3), *Pounce Speed*, *Tank Mess*.
- **Store Alarm:** *Alarm Heat* (25), *Alarm Seconds* (60), *Ambush Bots* (4), *Ambush Call Range*
  (90 m), *Ambush Call Every* (6 s), *Ambush Seconds* (45), *Alarm Sound* and *Alarm Line*.
- **The storefront** (the glass front in the city) is on **Main > City**, group **Meow-Mart
  storefront**: *Storefront Doors* (off = the old solid box), *Recess*, *Width*, *Height*, *Glow Color*.
- **The new loot** cards: `items/fresh_catch.tres`, `items/gourmet_tuna.tres`, `items/catnip_treats.tres`
  (models `scenes/items/tuna_can.tscn`, `catnip_treats.tscn`; the Fresh Catch reuses the fish model).

### How it works (for Claude / the curious)
- The store is NOT behind the doors: it's built once from code, 50 m under the middle of the city
  (`Main/MeowMart`, `scenes/interiors/meow_mart_interior.tscn` -> `scripts/interiors/meow_mart_interior.gd`,
  class `MeowMartInterior`, at y = -50). Crossing the city's glass line or the store's front doorway
  moves the cat with `CatPlayer.teleport_to` (each computer moves its own cats). Above y = -100 still
  counts as "up top" (`UndergroundHub.is_in_hub` is false): heat ticks, guns fire, the DEEP CLEAN still
  gets you. `MeowMartInterior.contains(pos)` = "inside the store"; `hub.mood_at` returns `MART_MOOD` there.
- The city side: `CityGenerator._build_meow_mart_storefront` (no random numbers, so cities are unchanged)
  fills `city.meow_mart_doors` (the two leaves), `meow_mart_door_spot` and `meow_mart_door_width`; the
  interior script slides the leaves.
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
- `--host --deploy --test_meow_mart --hold=move_forward` walks you in (`[MeowMart] 1 went inside`).
- `--inside_meow_mart[=foyer|plate|aisle|tank|backroom|counter|door]` puts you inside.
- `--shatter_tank[=F]` (host) breaks the tank: prints `DevCapture mart shatter: ... heat 0.7 -> 26.3 ...`.
- `--mart_swat=N`, `--mart_topple=1|2`, `--mart_plate`, `--mart_drag`, `--mart_tank_hits=N`, `--mart_log[=N]`
  ("DevCapture mart" lines). Late joiner: host `--deploy --inside_meow_mart --mart_topple=1 --mart_drag
  --shatter_tank=5 --frames=1500`, client `--join --mart_log=60` 14 s later.
- Split screen: `--solo --join_pad=1 --deploy --hold_all --inside_meow_mart`.
