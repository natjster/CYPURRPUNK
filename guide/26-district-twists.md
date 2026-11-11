# 26. DISTRICT TWISTS (a special rule for some districts)

[Back to the contents page](../SETUP_GUIDE.md)


From the **second district of a game** on, every new district has a **60% chance** of a twist: one
special rule for that district only. The first district of a game and the TUTORIAL never get one,
and the same twist never comes twice in a row.

| Twist | What changes |
|---|---|
| **BLACKOUT** | The power grid is down: every street lamp is off (dead grey bulbs), the night and the moon are darker. Only neon signs, bot sirens, payphones and car lights glow. The VAC-COPs see **25% less far**, so you can sneak much closer. |
| **BIN DAY** | **Twice the trash bins, traffic cones and cardboard boxes** on the corners, in the yards and outside Meow-Mart (the buildings stay exactly the same). When you extract, the boss pays **$10 for every mess** you made on that trip: the extraction pop-up shows **CHAOS BONUS +$...** |
| **MEOW-MART CLEARANCE** | **Twice the fish** outside Meow-Mart's door (a second row) plus a **Golden Koi** right in front of the door, but the heat climbs **25% faster** while cats are up top. |
| **HIGH ALERT** | **50% more patrol bots**, but any regular bot (not a MEGA VAC-COP) has a **35% chance to drop SCRAP** when it blows up. |

**How players find out (all in the sewers, before going up):**
- When the new district is ready, your gang boss (Don Catleone or Pawnie) says what's up there,
  e.g. *"New district, kid. Power grid's blown up there - total BLACKOUT..."*. A normal district
  gets the old *"We're movin' to a new part of town..."* line.
- THE MAINFRAME's big CRT has an **INTEL line** under the screen, in both sewers: green
  `SECTOR: STANDARD PATROL` on a normal district, amber `INTEL: GRID BLACKOUT (DARK STREETS)` etc. on a twisted one.
- Picking **SEND ME UP TOP** gets a twist reminder from the boss instead of the usual send-off.
- There is **no pop-up** when you climb out up top (on purpose: the HUD stays clean).
- The **RAID REPORT** header names it: `DISTRICT 2 — BLACKOUT — CLEAN GETAWAY`.

### Tuning (no code)
Everything is on the **Twist** node: open `scenes/main.tscn`, click **Main > Twist**, and look in the
Inspector:
- **Rolling:** *Twist Chance* (0.6 = 60%) and a tick box per twist (untick one to take it out of the game).
- **Blackout:** *Blackout Sight Multiplier* (0.75), *Blackout Ambient Multiplier* (how dark the night
  gets), *Blackout Moonlight Multiplier*.
- **Bin Day:** *Bin Day Prop Multiplier* (2 = twice the props), *Bin Day Cash Per Mess* ($10).
- **Meow-Mart Clearance:** *Clearance Fish Multiplier* (2), *Clearance Prize Item* (`golden_koi`;
  empty = no prize), *Clearance Heat Multiplier* (1.25).
- **High Alert:** *High Alert Bot Multiplier* (1.5), *High Alert Scrap Chance* (0.35).
- **What the boss says** and **Mainframe CRT intel line**: every line players read, editable.

Keep the **Twist** node ABOVE **City** and **Items** in the scene tree (drag it if needed): the
twist is decided before the city, the loot and the patrol are built.

### How it works (for Claude / the curious)
`scripts/district_twist.gd` (`DistrictTwist`, node `Twist` under Main). The HOST rolls it in
`Game.new_district()` with a random number generator seeded by the new city's seed (`city_seed ^ 0x77157`),
so a given city number always rolls the same way (given the twist before it). The host sends the
twist and the district number WITH the city seed (`Game._receive_city_seed(seed, twist, district)`, also
to late joiners), so every computer builds the same twisted city. Other scripts ask
`DistrictTwist.is_blackout()` / `is_bin_day()` / `is_clearance()` / `is_high_alert()` or the multipliers
(`sight_multiplier`, `prop_multiplier`, `heat_multiplier`, `bot_multiplier`, `roll_scrap_drop`):
- `city_generator.gd`: lamps off (BLACKOUT); BIN DAY's extra props use their own random numbers
  (`_bin_rng`), so the rest of the city matches a normal day.
- `hub.gd`: darker ambient + moon (BLACKOUT), the CRT INTEL line. `npc.gd`: the send-off line.
- `roomba.gd` `_can_chase`: sight. `heat_meter.gd`: passive heat. `roomba_patrol.gd`: patrol size.
- `enemy.gd` `explode`: HIGH ALERT scrap. `item_manager.gd`: Meow-Mart fish rows + the koi.
- `mess_manager.gd` `player_messes_this_trip` + `fish_heist.gd`: the CHAOS BONUS.
- `raid_report.gd` / `raid_report_screen.gd`: the twist in the header.

### Testing
`--twist=blackout|bin_day|clearance|high_alert|none` forces that twist on EVERY district, the first
included. It prints `DevCapture twist` lines (lamps lit, ambient, bot sight, props, Meow-Mart loot,
bots, heat multiplier, CRT intel, the boss's lines).
- Blackout: `--solo --seed=42 --twist=blackout --deploy --capture=shots/x.png --frames=200`
- Bin day + chaos bonus: `--solo --twist=bin_day --deploy --mess=4 --heat=80 --heat_hold=600
  --goto_dropoff_after=60 --capture=shots/x.png --frames=900` (prints `DevCapture extracted ... bonus $40`)
- Clearance heat: `--solo --twist=clearance --deploy --twist_heat=600 --capture=shots/x.png --frames=2500`
- High alert scrap: `--solo --twist=high_alert --deploy --kill_roombas=20 --capture=shots/x.png --frames=900`
- What 1000 districts would roll: add `--twist_rolls` (about 60% twisted, no back-to-back repeats).
- The real roll on a district change: `--solo --raid_report --report_ready=0 --frames=3000` (look for `[Twist] District 2:`).
