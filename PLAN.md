# MEOW-CITY 1999 — MVP Ship Plan

> **What this is:** the full plan for turning the current prototype into a small, *finished* game on
> Steam. [ROADMAP.md](ROADMAP.md) is the short tick-box checklist; this file explains the **what**,
> **why** and **in what order** behind it. [SETUP_GUIDE.md](SETUP_GUIDE.md) explains how the parts
> that already exist work.
>
> Written 2026-10-24. Dates are estimates. The milestone **gates** (the checks at the end of each
> milestone) matter more than the dates.

---

## 0. The short version

- **The game:** 1–4 alley cats pull fish heists in a rainy, procedurally generated, PS1-style
  cyberpunk city. Grab fish, load the getaway car, lose the Dog Patrol, deliver before the clock
  runs out.
- **"MVP" means:** the smallest version someone would happily pay a few dollars for, play with
  friends for an evening, and recommend. One mode, done well.
- **What's missing today:** the *game* part (goal, threat, score, rounds), sound, menus and settings,
  controller support, Steam online play, and the release paperwork. The engine side (the look, the
  cat, the car, LAN multiplayer, the city generator) is in good shape.
- **Order:** paperwork + safety net now → one fun heist (the "vertical slice") → the full game →
  polish → Steam online → release prep → launch.
- **Rough timeline:** ~14 working weeks plus a holiday break → release around **mid-February 2027**
  (calendar in §8).
- **Biggest risks:** (1) the loop isn't fun. We find out by week 3, not week 12. (2) The Steam
  add-on doesn't work with Godot 4.7.2. Tested in week 1 with Valve's free test app. (3) The
  project has no backup or undo history. Fixed this week.

**This week:**
1. **You:** answer the decisions in §1 (mainly: is Fish Heist the game?).
2. **Both:** put the project in version control with an online backup (§5.4). Right now there is no
   way to undo a bad change to the whole project.
3. **You:** create the Steamworks account and pay the $100 fee. That starts the 30-day clock.
4. **Claude:** foundations refactor + a Steam test with Valve's test app (M0, §7).
5. **Claude:** start the Fish Heist vertical slice (M1).

---

## 1. Decisions only you can make

These are my recommendations; change any of them. Until you say otherwise, I'll build to the
recommendation.

| # | Decision | Recommendation | Why | Needed by |
|---|---|---|---|---|
| D1 | Core loop | **Fish Heist**, as designed in §4 | Uses everything that already exists (Meow-Mart, car, city, co-op). Easy to explain in one GIF. | Now (blocks M1) |
| D2 | Max players | **4** (a driver + 3 passengers) | One car = 4 seats. Easier to balance and test. With 8 cats and one car, 4 are always walking. | M1 |
| D3 | Who can join | **Friends / invite-only** Steam lobbies, plus LAN "direct connect" | Avoids the "don't trust the host" anti-cheat problem. Public lobbies can come later. | M4 |
| D4 | The threat | **Dog Patrol**: police cars driven by dogs that chase the getaway car | A chase is the fun part. Their driving reuses the getaway car's code. | M2 |
| D5 | Screen shape | Keep **4:3**; add a **16:9 widescreen option**; you pick the default after seeing both | Most monitors and the Steam Deck are wide. Store screenshots and the trailer look better wide. | M3 |
| D6 | Platforms | **Windows** build. Steam Deck runs it via Proton. Native Linux optional. | One build to test, and the Deck is still covered. | M5 |
| D7 | Music | Royalty-free/CC0 tracks, or commission 2–4 tracks on a small budget | Music is half the mood | M3 |
| D8 | Price | Decide after playtesting. Compare 5 similar small co-op games on Steam. | | M6 |
| D9 | Steam Next Fest | Optional. If yes, a later edition (e.g. June 2027) fits better than February. | It needs a demo and an early store page | M3 |

---

## 2. Where we are today

*(Updated 2026-10-24.)* **Already done:** PS1 look (320x240, wobble, affine textures, flat
shading, dither, CRT) · atmosphere (fog, glow, lamps, neon, rain, headlights) · cat controller
(walk, jump, zoomies, camera) · arcade car (drive, drift, enter/exit) · LAN multiplayer (host/join,
names, shared car, smoothing, late join) · seeded city generator · Fish Heist basics (fish,
drop-off, per-player cash, HUD) · items framework (paws, backpack, loot bag, inventory screen;
tommy gun, pistols, catnip, catdip) · start menu, pause menu, settings · foundations tidy-up
(`Net`, `Settings`, menus split out, own save folder, test tool off in release) · test tooling.

| Area | Today | Needed for MVP |
|---|---|---|
| Goal / rules | Fish Heist with **no timer**: grab fish, deliver at the drop-off, cash per player | Round: objective, timer, score, heat, win/lose, restart |
| Threat | None (guns only shove other cats) | Dog Patrol chase AI + heat |
| Players | Up to 8, LAN/IP only, one car (driver only) | Up to 4, passenger seats, Steam online + invites |
| Menus | Start menu (play/settings/quit, host/join), pause menu, settings | + results, credits, round briefing |
| HUD | Cash, loot, drop-off arrow, scoreboard, item/heat bar, controls line | + timer, score, heat, button prompts |
| Sound | None at all (Music/SFX volume buses exist) | Ambience, music, engine, tyres, sirens, meows, UI |
| Input | Keyboard + mouse; mouse speed / invert Y settings | + controller (Steam Deck) |
| Settings | Display, sound, controls, effects — all saved | + fog quality, flashing lights, camera roll, FOV boost, key rebinding (Should) |
| Cat | Static model that leans; carries fish and items | Procedural walk/idle animation, meows |
| Network safety | No version check. Host quitting reloads the menu with no message. | Version check on join, clear disconnect messages |
| Build | Runs from the editor; test tool already off in release builds | Windows export, Steam depot |
| Safety net | **Not in version control.** One zip backup (`Meow-City-backup-2026-10-24.zip`) | Git + private online backup |
| Store / legal | Nothing yet | Steamworks account, store page, credits and licences |

**Possible change of direction:** the owner's `DESIGN_DOC.md` (free-to-play PvPvE extraction,
underground hub, proximity voice, room codes + mobile cross-play, ragdoll physics, VAC-COP
Roombas, streamer integration) differs from this plan in several of the §1 decisions. Until the
owner picks, this plan stands.

---

## 3. The MVP

### 3.1 Pitch and pillars

Store short description (draft, under Steam's 300-character limit):

> Rain-slicked neon, a stolen getaway car and a city full of fish. Team up with up to 3 friends as
> alley cats pulling heists through a procedurally generated PS1-style cyberpunk city. Grab the fish,
> floor it, and lose the Dog Patrol before the clock runs out.

**Pillars.** Every feature must serve at least one of these. If it doesn't, it waits until after launch.
1. **Cat chaos with friends.** Funny, physical, low-stakes co-op. Meowing is a feature.
2. **Neon-rain PS1 mood.** Fog, glow, dither, wobble. Never traded away for detail.
3. **Short, replayable heists.** 5–7 minute rounds, with a new city every time (or the same city
   again, to beat your score).

### 3.2 Definition of done

The MVP ships when **all** of these are true:
- [ ] Bought on Steam, it installs and reaches the title screen in about 10 s on a min-spec PC.
- [ ] A new player starts a solo heist in under a minute and understands the goal without help.
- [ ] A round lasts ~5–7 minutes and ends with a result (medal or fail) and "play again".
- [ ] Two players in different houses can play through a Steam invite: no port forwarding, no IP typing.
- [ ] 4 players can finish an online round, and the car, fish and score agree on every screen.
- [ ] The whole game, menus included, is playable with only a controller (Steam Deck).
- [ ] Settings (volume, sensitivity, fullscreen, comfort toggles) work and are remembered.
- [ ] 60 fps at default settings on the min-spec PC and on Steam Deck.
- [ ] A one-hour session runs without a crash. Joining, leaving and the host quitting all show clear messages.
- [ ] Every action that should make a sound makes one.
- [ ] Credits include Godot's licence and every third-party asset's licence.
- [ ] Store page approved, build approved, and the 2-week "Coming Soon" period is over.
- [ ] Zero known **blocker** bugs (§9.5).

### 3.3 Scope: Must / Should / Won't

**Must** (the MVP isn't done without these)
- Fish Heist round: fish sources, carrying, loading the car, the delivery spot, timer, score,
  medals/quota, results screen, restart.
- Dog Patrol chase AI + heat level + "busted".
- Passenger seats: up to 4 cats in the car.
- HUD: timer, score, cargo, heat, objective arrow, interaction prompts.
- Meow button.
- Procedural cat animation: walk, run, idle, jump, carrying.
- Title menu, pause menu, settings, results, credits.
- Sound: rain, music, engine, tyres, sirens, meows, pickups, UI.
- Controller support, including menu navigation and button prompts.
- Steam: online play via Steam's relay, invite-only lobbies, invite/join from the friends list, Steam
  name as the default cat name.
- Version check on join; disconnect messages.
- Windows release build on Steam with the dev tools switched off.
- Comfort and performance settings: CRT, wobble, fog quality, flashing lights, camera roll, speed FOV boost.

**Should** (do them if we're on schedule; these are cut first)
- Passenger **hiss**: lean out and stun a nearby patrol car. It gives passengers a job.
- 3 difficulties: Kitten / Alley Cat / Night Terror.
- **Daily City**: the seed is today's date, so everyone plays the same city that day.
- Best score per city and difficulty, saved on your PC.
- Steam achievements (about 10, see §4.5).
- Key rebinding.
- 16:9 widescreen and "fill screen" options.
- Physics interpolation, for a smooth camera on 120 Hz+ monitors (currently in ROADMAP "Later";
  promote it if testers notice stutter).
- Steam Cloud for settings/scores (Steam's Auto-Cloud needs no code).
- City variety: 3–5 landmark types, drivable alleys.

**Won't** (not in the MVP; parked in §13)
- Public lobbies with strangers / anti-cheat.
- More vehicles, or more than one getaway car.
- Cosmetics, unlocks, progression, levels.
- Story, cutscenes, voice acting.
- Mac build; native Linux unless it turns out to be trivial.
- Ramps, flipping cars, damage.
- Dedicated servers, host migration.
- Translations (English only at launch, but all text stays in one place so it's possible later).
- Built-in voice chat (Steam's own voice chat works fine).

---

## 4. Game design: Fish Heist

### 4.1 One round

```
LOBBY ─> BRIEFING (10 s: goal shown, 3-2-1) ─> HEIST (6:00) ─> RESULTS ─> play again?
                                                  │
        grab fish ─> carry to car ─> load trunk ─> drive to THE FENCE ─> deliver = score
            ▲                                                  │
            └──────────────────── go back for more ───────────┘
        each stolen fish raises HEAT; heat sends the DOG PATROL after the car
```

### 4.2 Rules

- **Fish sources.** Meow-Mart (always on the same corner) has the most fish. Each city also has 2–4
  smaller sources, placed by the seed on lots beside a street: a fish stall, a delivery van, a sushi
  bar's back door. Each source has a fixed stock.
- **Carrying.** Press interact at a source and your cat takes one fish in its mouth (you can see it).
  A cat carrying fish can't do zoomies and walks a bit slower. Press interact again to drop the fish.
- **Loading.** Press interact at the car's trunk while carrying, and the fish goes in. The trunk
  holds 8 (tunable). The HUD shows the cargo.
- **Delivering.** Drive into **The Fence**: a seed-picked spot far from Meow-Mart, marked by a tall
  coloured light beam that shines through the fog. All cargo scores at once. Cats on foot can
  deliver the fish they're carrying too.
- **Heat (0–5).** Every stolen fish raises heat. Heat decides how many Dog Patrol cars are hunting
  (0 heat = none). Heat slowly cools while no patrol can see the getaway car.
- **Dog Patrol.** Police cars that drive along the street grid toward the getaway car and ram or
  box it in. They appear out of sight, hidden in the fog.
- **Busted.** If the getaway car is nearly stopped with a patrol car right next to it for 3 s, it's
  busted: the cargo is lost, the car reappears at its parking spot, and heat drops to 1. That
  hurts, but the round goes on.
- **Knocked silly.** A cat on foot hit by a patrol car spins around comically, drops its fish, and
  is back up after 3 s. Nobody gets hurt, which keeps the age rating mild.
- **End of round.** When the clock hits zero, the score is compared with the quota: below Bronze =
  "The heist failed". Otherwise you get a Bronze, Silver or Gold paw.
- **Score.** Each fish scores `100 × (1 + 0.25 × heat at delivery)`. More heat = more risk = more points.

### 4.3 Co-op roles (nobody is forced into one; they appear naturally)

- **Driver:** drives and outruns patrols.
- **Passengers:** ride along with a free-look camera. *(Should)* They can lean out and **hiss** to
  stun a nearby patrol car for 2 s (10 s cooldown).
- **Runners:** on foot, they ferry fish from sources to wherever the car waits. Cats are quick in
  alleys; the car is quick on streets.
- **One button does the obvious thing.** Carrying a fish at the car → load it. At a source → grab a
  fish. At the car door with no fish → get in. In the car → get out.

### 4.4 Solo play

Same rules. Quotas scale with player count (table below). Heat rises a little more slowly when solo.

### 4.5 Replayability: the "15–30 minutes", and a reason to come back

- A new city every round, or replay a city by typing its number.
- *(Should)* Difficulties: **Kitten** (8 min, heat cools fast), **Alley Cat** (6 min),
  **Night Terror** (5 min, patrols from the start).
- *(Should)* **Daily City:** one city for everyone each day, so you can compare scores with friends.
- *(Should)* Best score per city + difficulty, shown on the results screen.
- *(Should)* Achievements: *Cat Burglar* (first delivery) · *Purr-fect Heist* (gold paw) ·
  *Full Trunk* (8 fish in one trip) · *Five-Alarm Fish* (deliver at heat 5) · *Clean Getaway* (a
  round with no bust) · *Nine Lives* (knocked silly 9 times) · *Drift Kitty* (a 5-second drift) ·
  *Hiss-teria* (stun 10 patrols) · *Chatty Cat* (meow 100 times) · *Daily Catch* (finish a Daily City).

### 4.6 Starting numbers

These are first guesses. Every one of them becomes an `@export` knob you can change in the Inspector.

| Knob | Start value |
|---|---|
| Round length | 6:00 |
| Trunk size | 8 fish |
| Fish per source | Meow-Mart 10, others 3–5 |
| Heat per stolen fish | +0.5 |
| Heat cooling | −1 per 20 s while no patrol sees the car |
| Patrol cars | one per heat level, max 5 |
| Busted | 3 s below 3 m/s with a patrol within 5 m |
| Knocked silly | 3 s |
| Quotas, 1 player (Bronze / Silver / Gold) | 6 / 10 / 14 fish |
| Quotas, 4 players | 12 / 18 / 24 fish |

### 4.7 HUD and feedback

Everything is drawn at 320x240 and gets dithered along with the game:

```
+------------------------------------------+
| FISH 3/8      <  FENCE 140m  >     4:12  |
| SCORE 1250                  HEAT ###..   |
|                                          |
|                 (game)                   |
|                                          |
|              [E] LOAD FISH               |
+------------------------------------------+
```

Feedback to build: siren sound + red/blue light flicker when a patrol is near (respects the
"flashing" setting) · trunk "thunk" · delivery jingle + score pop-up · a sting when heat goes up ·
faster music and a ticking clock in the last 30 s · results screen with medal, fish, time and best score.

### 4.8 Teaching the player

- A briefing card at the start of every round, 3 lines at most: *"Steal fish from MEOW-MART" /
  "Load them into the car" / "Deliver to THE FENCE before time runs out"*.
- Prompts in context ("[E] GRAB FISH") that show the right button for keyboard or controller.
- A "How to play" page in the pause menu. No separate tutorial level.

### 4.9 If Fish Heist isn't fun (decided at the M1 gate)

Cheap pivots that reuse the same parts:
- **Catnip Courier:** no stealing. Timed deliveries between random spots, chained into combos.
- **Cat & Mouse:** one player drives as the Dog Patrol; everyone else is a cat.
- **Style heist:** Fish Heist with no patrols, where points come from drifts and near misses.

---

## 5. Technical plan

This section is written as much for Claude in future sessions as for you. Each part starts with the
plain-language version.

### 5.1 What the project will look like

```
Autoloads (Project > Project Settings > Globals > Autoload)
  InputSetup    all controls; gains controller buttons                    (exists)
  Settings      loads, saves and applies every setting                   (new)
  Net           host / join / leave; hides ENet-vs-Steam from the game   (new)
  SteamService  wraps GodotSteam; does nothing if Steam isn't running     (new, M4)
  DevCapture    test tool; switches itself off in release builds          (exists)

Main (Node3D)                 game.gd: spawning + round reset (menu UI moves out)
├── WorldEnvironment, Moonlight, Rain
├── City                      city_generator.gd; also records streets/lots for the heist and AI
├── Players + PlayerSpawner   (exists)
├── GetawayCar                getaway_car.gd, now built on arcade_car.gd; 4 seats
├── Patrols + PatrolSpawner   Dog Patrol cars (the host spawns them)
├── Heist (Node)              heist_director.gd: round phase, timer, score, heat, fish
│   ├── FishSources           placed per city
│   ├── TheFence              Area3D + light beam
│   └── MultiplayerSynchronizer   phase, time_left, score, heat, cargo
├── LobbyCamera
├── Music, Ambience           AudioStreamPlayers
└── PS1Overlay (CanvasLayer)
    ├── HUD, MainMenu, PauseMenu, SettingsMenu, Results, Credits, MessageBox
    └── ColorDepthDither      stays LAST so all UI gets dithered too
```

New files (planned): `scripts/settings.gd`, `scripts/net.gd`, `scripts/steam_service.gd`,
`scripts/arcade_car.gd`, `scripts/patrol_car.gd`, `scripts/street_graph.gd`,
`scripts/heist_director.gd`, `scripts/fish_source.gd`, `scripts/cat_animator.gd`, `scripts/ui/*.gd`,
`scenes/patrol_car.tscn`, `scenes/props/fish_source.tscn`, `scenes/props/the_fence.tscn`,
`scenes/ui/*.tscn`, `audio/`, `fonts/`, `default_bus_layout.tres`, `ASSET_LICENSES.md`, `tools/`.

### 5.2 Networking rules

Keep the pattern that already works for the car.
- **The host decides anything shared:** round phase, timer, score, heat, fish stock, who is
  carrying what, and the patrol cars. Clients *ask* with an RPC (`request_grab_fish`,
  `request_load_fish`, `request_deliver`...). The host checks distance and state, then tells everyone
  the result. This is the same pattern as `GetawayCar.request_enter`.
- **Unchanged:** owners move their own cat; the driver simulates the getaway car. The host
  simulates the Dog Patrol cars, and everyone else's copies glide to them with the existing smoothing code.
- **Synced continuously** (MultiplayerSynchronizer): positions, each cat's `carrying_fish`, heist
  state. **One-off events** (reliable RPC): delivered, busted, knocked silly, round start and end.
- **Animation** is worked out locally on each computer from how a cat moves. It costs no network traffic.
- **Late joiners** get the round state from the synchronizer automatically and the city seed from
  the existing `_receive_city_seed` RPC.
- **Version check:** the first thing a client sends is its game version + generator version. The
  host turns away a mismatch with a clear message ("The host is on version 1.0.2. Update through Steam.").
- **Leaving:** if the host quits, everyone goes back to the menu with "The host ended the game". If
  a player quits, their fish drops and, if they were driving, the car empties (the car part exists).
- **Seats:** `driver_id` becomes a 4-slot seat list, with the host still refereeing who sits where.

### 5.3 Determinism rules (keeping everyone's city identical)

- The city layout uses only `CityGenerator._rng`, in a fixed order (see CLAUDE.md). New city
  features either add their RNG calls **after** the existing ones or use their own RNG, so existing
  city numbers don't change by accident.
- Heist placement (fish sources, The Fence, patrol spawn points) uses a **separate** RNG seeded from
  the city seed. That way the same city number always gives the same heist, and tweaking heist
  rules never moves buildings. It runs on the host, and the results are sent to everyone.
- The city generator needs to tell the heist about its streets and lots (crossroads list, street-facing
  lots, edge spots). That's pure geometry, so it uses **no** `_rng` calls and changes no layouts.
- **Freeze the generator at launch.** Add a `GENERATOR_VERSION` number and raise it whenever a
  change alters layouts. It goes into the version check and into saved best scores, so shared city
  numbers and Daily City scores stay fair after updates.
- The DevCapture `fingerprint` check stays the test: host and client must match.

### 5.4 Fix first (foundations, before new features)

1. **Version control.** Git with a private GitHub repo. GitHub Desktop is the click-friendly way and
   installs git for you. A `.gitignore` leaves out `.godot/` and `shots/`. Claude sets up the local
   part; you create the GitHub account/repo.
2. ✅ **Split up `game.gd`.** Networking → the `Net` autoload (`scripts/net.gd`, so switching to
   Steam later touches one file), start menu → `MainMenu` (`scripts/ui/main_menu.gd`), pause menu →
   `PauseMenu` (`scripts/ui/pause_menu.gd`). `game.gd` keeps starting games, spawning, late-joiner
   catch-up, and will get round reset. Shared lookup: `Game.instance.cat_for(peer_id)`.
3. ✅ (first half) **Separate car input from car driving.** `GetawayCar` now has a "drive input"
   (`throttle` / `steer` / `handbrake`) that the keyboard fills in and the physics only reads.
   Still to do with the Dog Patrol: move the physics into an `ArcadeCar` base script that
   `GetawayCar` and `PatrolCar` both extend.
4. ✅ **A `Settings` autoload** (`scripts/settings.gd`) replaces the name-only `settings.cfg` code in `game.gd`.
5. ✅ **Esc opens the pause menu.** The cat, car and inventory ignore keys while `PauseMenu.is_open`.
6. ✅ **DevCapture off in release builds** (`OS.is_debug_build()`). Test runs also use default
   settings and never save, so they can't overwrite the player's settings.
7. ✅ **Own save folder:** *Project Settings > Application > Config > Use Custom User Dir* ON, name
   `MeowCity1999`. Saves and logs land in `%APPDATA%\MeowCity1999\`, which is easy to tell testers.
8. ✅ **Game version number:** *Project Settings > Application > Config > Version* (0.1), shown in
   the start menu corner.

### 5.5 Steam integration

- **The add-on:** GodotSteam (MIT licence), the GDExtension build that matches Godot 4.7.2, plus its
  Steam MultiplayerPeer. **Checked early (M0)** with Valve's public test app ID **480
  ("Spacewar")**, so we don't need our own App ID yet.
- **Online play:** inside `Net`, swap `ENetMultiplayerPeer` for the Steam peer. RPCs, spawners and
  synchronizers keep working as they are. Traffic goes through Steam's relay: no port forwarding,
  and players' IP addresses stay hidden.
- **Lobbies:** the host creates a friends-only Steam lobby with 4 slots. "Invite friends" opens the
  Steam overlay. Friends join from the overlay or friends list (Steam's "join game" request), or
  from a launch command (`+connect_lobby`).
- **Keep LAN "Direct connect"** by IP, for testing and for playing without Steam.
- **Steam name** becomes the default cat name. Rich presence shows "Pulling a heist in City #4821".
- *(Should)* **Achievements** are set up in Steamworks and unlocked through `SteamService`.
- **Release builds** started outside Steam relaunch through Steam (`restartAppIfNecessary`). Dev
  builds use `steam_appid.txt`, which is **never** shipped.
- `steam_api64.dll` must sit next to the `.exe` in the Steam depot.
- **If GodotSteam won't run on 4.7.2:** (a) use a newer GodotSteam build if one exists, (b) move the
  project to the newest Godot version GodotSteam supports, or (c) as a last resort ship LAN/IP only
  for the MVP (weak, because internet play would need port forwarding).

### 5.6 Performance budget and settings

- **Target:** 60 fps at 1080p on the min-spec PC (we find the exact spec by testing; aim for a
  roughly 2016 mid-range graphics card) and on Steam Deck.
- At 320x240, pixels are cheap. The real costs are **volumetric fog**, **number of lights**,
  **number of objects (draw calls)** and rain particles.
- **Levers:** a fog quality setting (Off / Low / High) · light fade distance (already ~45 m) ·
  MultiMesh for repeated props (crates, trash bags, lamps) if object count is the problem · rain amount.
- Godot's Forward+ renderer needs a Vulkan or DirectX 12 graphics card. That goes in the system requirements.

| Settings group | Settings |
|---|---|
| Video | Fullscreen/windowed · pixel-perfect vs. fill screen · widescreen *(Should)* · V-sync · frame cap · fog quality · rain amount |
| Audio | Master · Music · Effects · Ambience |
| Controls | Mouse sensitivity · controller sensitivity · invert Y · rebind keys *(Should)* |
| Comfort | CRT effect · vertex wobble · flashing lights · camera roll · speed FOV boost |
| Game | Cat name · show name tags |

**Built so far** (Settings menu, SETUP_GUIDE.md §10): fullscreen/window · window size · V-sync · FOV ·
Master/Music/SFX volume · mouse speed · invert Y · CRT strength · vertex wobble (+ texture warp,
via the `psx_wobble` shader global) · volumetric fog on/off. Still to add from the table above:
frame cap, fog quality levels, rain amount, ambience volume, controller settings, key rebinding,
flashing lights, camera roll, speed FOV boost, name tags.

### 5.7 Saved data

- `user://settings.cfg`: settings + cat name (the file already exists).
- `user://scores.cfg`: best score per city, difficulty and generator version.
- *(Should)* Steam Auto-Cloud syncs the save folder. It's set up in Steamworks, with no code.
- The game collects no personal data and has no analytics. It sends nothing except normal Steam
  multiplayer traffic.

### 5.8 Build and release pipeline

1. **You:** download the Godot 4.7.2 export templates (*Editor > Manage Export Templates > Download*).
2. **Claude:** a Windows export preset (`export_presets.cfg`) that embeds the game data in the
   `.exe`, sets the icon, product name and version, and leaves out `shots/`.
3. **Claude:** `tools/build_release.ps1`, which exports from the command line, copies
   `steam_api64.dll`, refuses to continue if `steam_appid.txt` would be shipped, and keeps a zipped copy.
4. **Claude writes, you run:** SteamPipe scripts (`tools/steam/app_build.vdf`, `depot_build.vdf`)
   and a `steamcmd` upload. It asks for *your* Steamworks login, so only you run the upload.
5. **Branches on Steam:** `beta` (testing) → `default` (public). A separate **Steam Playtest** app
   is used for outside testers.
6. **Version numbers:** `0.x` during development, `0.9.x` for playtests, `1.0.0` at launch, `1.0.1+` for patches.

---

## 6. Art, audio and UI assets

**Rule from day one:** every file we didn't make ourselves gets a line in `ASSET_LICENSES.md`:
file · author · where it came from (URL) · licence · credit text. The credits screen is built from
that list. Credit CC0 assets too, even though it isn't required.

| Asset | Approach | Owner |
|---|---|---|
| Cat animation | Procedural, in code: legs, tail, head bob, ears, "loaf" idle, squash on landing | Claude |
| Dog Patrol car + dog drivers | A boxier variant of the getaway car with a light bar; low-poly dog heads in the windows | Claude |
| Fish, fish sources, The Fence beam | Low-poly shapes + tiny textures | Claude |
| Textures | 32–64 px pixel textures. Claude makes placeholders; you can paint replacements | Both |
| Pixel font | A free font under the OFL licence | Both |
| Button prompt icons | A CC0 input-prompt icon pack (keyboard / Xbox / PlayStation / Deck) | Claude |
| Sound effects | CC0 / royalty-free libraries (e.g. Kenney, Freesound with the CC0 filter, Sonniss GDC bundles), processed to sound lo-fi | Both |
| Meows | Record a real cat if you can; CC0 otherwise | You |
| Music | 2–4 tracks: menu, heist, high heat, results | You |
| Logo, store art, trailer | See §10 | You |

**Audio setup (Claude):** buses Master → Music / Effects / Ambience / UI. A lo-fi chain on Effects
(low-pass + light bit-crush) for PS1 flavour. Engine pitch follows speed. Sirens, engines and meows
are 3D sounds positioned in the world. Rain ambience swells when you're outside the car.

---

## 7. Milestones (the build order)

Each milestone ends with a **gate**: a short check we must pass before moving on. Roadmap phases map
to milestones like this: Phase 0 → M0 · Phase 1 → M1–M3 · Phase 2 → M0 (early check) + M4 ·
Phase 3 → M5 · Phase 4 → M3 + M5 · Phase 5 → M3 (Coming Soon) + M5–M6.

### M0: Foundations and paperwork (week 1)
*Goal: nothing can be lost, the Steam clock is ticking, and the riskiest unknown is checked.*

| Task | Owner |
|---|---|
| Version control + private online backup | Both |
| Steamworks account, identity/bank/tax, pay the $100 fee, note the App ID | You |
| Steam + trademark search for the name | You |
| Answer the §1 decisions | You |
| Foundations from §5.4: `Net` autoload, `Settings` autoload, car input split, version number, save folder, DevCapture off in release | Claude |
| Steam check: GodotSteam on Godot 4.7.2 with app 480 (start up, create a lobby, then connect two PCs, which needs two Steam accounts) | Claude + You |

**Gate:** project backed up · fee paid · GodotSteam runs in Godot 4.7.2 (or a fallback from §5.5 is chosen).

### M1: Vertical slice, one fun heist (weeks 2–3)
*Goal: the whole loop end to end, ugly but playable, solo and with 2 players.*

| Task | Owner |
|---|---|
| `HeistDirector`: briefing → heist → results → restart (same city / new city) | Claude |
| Fish sources (Meow-Mart + 2 more), carrying, loading, delivering, The Fence + light beam | Claude |
| Timer, score, quota, basic results screen | Claude |
| Basic HUD + arrow to the current objective | Claude |
| Meow button | Claude |
| Passenger seats (4 cats in one car) | Claude |
| One simple patrol car that just chases, to try out the feel | Claude |
| Test tool: a headless "round smoke test" (§9.1) | Claude |
| Playtest with at least one other person | You |

**Gate (the most important one in this plan):** play 3 rounds in a row. Does everyone want a 4th?
Did everyone understand the goal without being told? If not, tune the §4.6 numbers or pivot (§4.9)
*before* building anything else.

### M2: The full game (weeks 4–6)
*Goal: all the rules and enough variety to fill 15–30 minutes.*

| Task | Owner |
|---|---|
| Street graph from the city + proper Dog Patrol AI: follow streets, chase, ram, get unstuck, appear in the fog | Claude |
| Heat system, busted, knocked silly | Claude |
| Procedural cat animation + visible carried fish | Claude |
| Quotas by player count; difficulties *(Should)* | Claude |
| City variety: distinct-looking fish sources, landmarks, drivable alleys | Both |
| City check across 500 seeds (§9.1) | Claude |
| Best scores; Daily City *(Should)*; hiss *(Should)* | Claude |
| Max players → 4 | Claude |
| Weekly playtest + tuning | You |

**Gate:** a 4-player LAN round with every rule working · no blocker bugs · one tuning pass done.

### M3: Feel and polish (weeks 6–8, overlapping M2)
*Goal: it feels like a real game from the first click.*

| Task | Owner |
|---|---|
| All audio (§6) | Both |
| Title menu, pause, settings, credits | Claude |
| Controller support, menu navigation, keyboard/controller button prompts | Claude |
| Comfort and performance toggles (§5.6) | Claude |
| HUD juice: score pop-ups, siren lights, last-30-seconds tension | Claude |
| Briefing card + how-to-play page | Claude |
| Version check + disconnect messages | Claude |
| Widescreen/fill options *(Should)*, physics interpolation *(Should)* | Claude |
| Capsule art + 5 screenshots → submit the store page for review → **Coming Soon page live** | You (Claude helps with screenshots) |

**Gate:** someone new picks up a controller and plays a full round with zero help · Coming Soon page live.

### M4: Steam online (weeks 9–10)
*Goal: friends in different houses play together through Steam.*

| Task | Owner |
|---|---|
| Steam peer inside `Net`; friends-only lobbies; invites; join from the friends list | Claude |
| Steam name as the cat name; rich presence | Claude |
| Achievements *(Should)*; Auto-Cloud *(Should)* | Claude + You (set up in Steamworks) |
| Lag test with the simulated slow connection (`--net_interval`) | Claude |
| Online test with friends in other houses | You |

**Gate:** 4 players in at least 2 houses finish a round through an invite, with no IP typing.

### M5: Release candidate (week 11)
*Goal: a build you'd be happy for strangers to buy.*

| Task | Owner |
|---|---|
| Export preset, build script, SteamPipe scripts | Claude |
| Performance test on a weak PC + Steam Deck if you can borrow one | You |
| Steam Playtest (or keys) with 5–20 outside players | Both |
| Credits + licence check, privacy statement, system requirements, store text | Both |
| Trailer; content survey (age rating) | You |

**Gate:** the release checklist (§9.6) passes · zero blockers.

### M6: Launch (weeks 12–14)

| Task | Owner |
|---|---|
| Fix what the playtest found; submit the build for review | Both |
| Set price, launch discount (optional) and date | You |
| Launch-day checklist (§10.4) | You |
| Patch window: be ready to fix crashes for a week | Both |

---

## 8. Sample calendar

Week 1 starts **Monday 2026-10-26**. The dates will slide; that's fine. What matters is not skipping gates.

| Week | Dates | Build work | Steam / store (in parallel) |
|---|---|---|---|
| 1 | Oct 26 – Nov 1 | **M0** foundations | Account + fee paid → the 30-day wait ends around late Nov (not the bottleneck) |
| 2–3 | Nov 2 – Nov 15 | **M1** vertical slice → **gate** | Name/trademark check done; start the logo + capsule art |
| 4–6 | Nov 16 – Dec 6 | **M2** full game | Screenshots once the city looks final; store text |
| 6–8 | Nov 30 – Dec 20 | **M3** polish (overlaps M2) | Store page submitted ~Dec 7 → **Coming Soon live ~Dec 14** |
| — | Dec 21 – Jan 3 | Holiday buffer / catch-up | Wishlists build up |
| 9–10 | Jan 4 – Jan 17 | **M4** Steam online | Trailer |
| 11 | Jan 18 – Jan 24 | **M5** release candidate | Steam Playtest |
| 12–13 | Jan 25 – Feb 7 | Playtest fixes | Build review; price + date |
| 14 | Feb 8 – Feb 14 | **M6 launch** 🚀 | Pick a quiet week. Check the Steamworks events calendar so you don't launch into a big festival or sale. |

A Coming Soon page that's live longer collects more wishlists. Put it up as soon as the art and
screenshots are presentable (screenshots can be swapped later).

---

## 9. Testing and quality

### 9.1 Automated checks (Claude, on every change)
- Script check: `--headless --path . --import`.
- DevCapture screenshots and state printouts (CLAUDE.md lists the commands).
- 2-process multiplayer test, including the city `fingerprint` match between host and client.
- **New: seed sweep.** Build N cities headless and check that Meow-Mart, every fish source and The
  Fence can be reached by street, and that the car and cat spawn points are clear.
- **New: round smoke test.** `--autoplay` runs a full round headless (grab → load → deliver by
  teleport) and checks score, timer and results.
- **New: soak test.** Host + client for 30 minutes, watching for errors and memory growth.

### 9.2 Network cases to test every milestone
Slow connection (`--net_interval`) · real Wi-Fi · real internet (M4) · joining mid-round · leaving
mid-drive · host quitting mid-round · a client force-quitting (Alt+F4) · two cats grabbing the last
fish at the same time · two cats trying to take the driver's seat at once.

### 9.3 Playtests with people
- A regular "heist night" from M1 onward.
- Watch quietly; don't explain. Afterwards ask: *What confused you? When was it most fun? Would you
  play again?*
- Write findings in the bug list (§9.5).

### 9.4 Hardware to try
Your PC (RTX 4060) · an older PC or a laptop with built-in graphics · Steam Deck if you can borrow
one · 1080p, 1440p and ultrawide screens · 60 Hz and 144 Hz monitors · Xbox and PlayStation controllers.

### 9.5 Bug severity
| Level | Examples | Rule |
|---|---|---|
| **Blocker** | Crash; can't finish a round; can't join; lost saves; stuck with no way out | Must be fixed before release |
| **Major** | Wrong but there's a workaround (car stuck → busted resets it) | Fix, or note it in the store's known issues |
| **Minor / polish** | Visual glitches, odd sounds | Fine to fix after launch |

Track bugs in `BUGS.md`, or in GitHub Issues once the project is on GitHub.

### 9.6 Release checklist (every build uploaded to Steam)
- [ ] A fresh install from the Steam `beta` branch launches.
- [ ] No `steam_appid.txt` in the depot; `steam_api64.dll` is present.
- [ ] The version number in the menu is right.
- [ ] Settings are still there after a restart.
- [ ] Invite → join → full round → results → play again works.
- [ ] A round can be played with only a controller.
- [ ] Alt-Tab and switching fullscreen/windowed work.
- [ ] Quitting from the menu and from the window's X both work.
- [ ] The log in `%APPDATA%\MeowCity1999\logs` has no errors.
- [ ] The Steam overlay opens (Shift+Tab); achievements unlock (if added).

---

## 10. Steam store and launch

### 10.1 Store graphics
Sizes as of late 2024. **Check them** in *Steamworks > Store Presence > Graphical Assets*, because
Valve changes them now and then.

| Asset | Size (px) | Notes |
|---|---|---|
| Header capsule | 920 x 430 | The logo must be readable |
| Small capsule | 462 x 174 | Mostly just the logo |
| Main capsule | 1232 x 706 | Used in front-page features |
| Vertical capsule | 748 x 896 | |
| Library capsule | 600 x 900 | |
| Library hero | 3840 x 1240 | Art only, no logo or text |
| Library logo | up to 1280 x 720 | Transparent PNG |
| Screenshots | at least 5, 1920 x 1080 | Real gameplay only |
| Trailer | 30–60 s | The first 5 s is the hook: a drift through neon rain, cats meowing |

Valve rejects capsules that are mostly text, don't show the game's name, or are misleading.
**Claude:** add a DevCapture "photo mode" for clean 1920x1080 store screenshots.

### 10.2 Store text
- **Short description:** the draft in §3.1.
- **Long description:** a hook line, a GIF, then feature bullets: 1–4 player online co-op ·
  procedural cities (with a Daily City) · arcade drifting · authentic PS1 look · made with Godot.
- **Tags** (pick from Steam's own list): Co-op, Online Co-Op, Multiplayer, Cats, Driving, Heist,
  Procedural Generation, Retro, PSX, Cyberpunk, Low-poly, Funny, Casual, Indie.
- **System requirements** (fill in after the weak-PC test): Windows 10/11 64-bit · a graphics card
  with Vulkan or DirectX 12 support · RAM / disk to be measured · broadband internet for online play.

### 10.3 Getting wishlists (light touch, ~1–2 hours a week)
Short clips and GIFs (PS1 cats drifting in neon rain are very shareable) · Reddit (r/IndieDev,
r/godot, PS1-style communities) · Bluesky/X · TikTok/Shorts · a small Discord for playtesters · a
simple press-kit page.

### 10.4 Launch day
- [ ] The approved build is live on the `default` branch.
- [ ] Price and optional launch discount are set (Steamworks shows the allowed range).
- [ ] Press **Release** in Steamworks (releasing is a manual button press).
- [ ] Post the announcement on Steam and your socials.
- [ ] Be around for 48 hours to fix crashes; read reviews and the discussion forum.
- [ ] Plan patch 1.0.1 within the first week.

### 10.5 The first month after launch
Fix crashes first · reply to reviews · request a **Steam Deck compatibility review** in Steamworks ·
pick the first update from §13.

---

## 11. Legal and business

*(This is general guidance, not legal or tax advice. Ask a professional if you're unsure.)*
- **Name:** search Steam and trademark databases (USPTO, EUIPO/TMview, WIPO Global Brand Database)
  for "MEOW-CITY 1999" and "Meow City". Rename **before** the store art exists if there's a conflict.
- **Godot's licence:** the credits must include Godot's MIT licence and the third-party notices it
  bundles. Godot can produce these itself (`Engine.get_license_text()`,
  `Engine.get_copyright_info()`), so the credits screen fills them in automatically. Add GodotSteam
  (MIT), the font (OFL), and every sound and music licence from `ASSET_LICENSES.md`.
- **Privacy statement:** "MEOW-CITY 1999 doesn't collect personal data. Online play uses Steam
  networking; your Steam name is shown to the people you play with."
- **Taxes / bank:** the Steamworks tax interview (a W-9 if you're US-based, a W-8BEN otherwise).
  Decide whether you sell as an individual or a company.
- **Content survey:** cartoon theft, cartoon slapstick, no blood. Expect the mildest age ratings.

| Cost | Amount |
|---|---|
| Steam Direct fee | $100 (Valve pays it back after the game earns $1,000) |
| Godot, export templates, GodotSteam | $0 |
| Art / sound / music | $0 with CC0, or whatever music/art budget you choose |
| Trademark *search* | $0 (registering a trademark is optional and costs extra) |

---

## 12. Risk register

| Risk | Likelihood | Impact | What we do about it |
|---|---|---|---|
| The loop isn't fun | Medium | High | M1 gate by week 3; tuning knobs; pivots (§4.9) |
| GodotSteam doesn't support 4.7.2 | Low–Med | High | Test it in M0 with app 480; fallbacks in §5.5 |
| Work gets lost (no backup today) | Medium | High | Git + online backup in week 1 |
| Scope creep | High | High | Must/Should/Won't list; cut Should items first; new ideas go to §13 |
| Online bugs under real lag | Medium | Medium | Host-decides pattern; lag simulation; real-internet test as soon as the Steam check works |
| Patrol AI gets stuck in odd city layouts | Medium | Medium | The city is a grid, so use a street graph; unstick + respawn-in-fog logic; seed sweep |
| Slow on weak PCs | Medium | Medium | Fog/lights/rain settings; test before M5 |
| A third-party asset's licence is a problem | Low | High | Licence log from day one |
| Steam rejects the store page or build | Low | Medium | Follow the §10.1 rules; submit the store page early |
| Name or trademark conflict | Low | Medium | Search in M0, before any art |
| Burnout / life gets busy | Medium | High | Flexible dates, firm gates, holiday buffer built in |
| A generator change breaks shared city numbers after launch | Medium | Low | `GENERATOR_VERSION` + the version check (§5.3) |

---

## 13. After the MVP (the parking lot)

New ideas go here, not into the current milestone.
- Public lobbies with strangers + host validation / anti-cheat.
- More vehicles, more cars, cat cosmetics and fur colours.
- More modes (the §4.9 ideas make good free updates).
- Mac and native Linux builds.
- Ramps, rooftops, multi-level streets.
- Thin "real TV" CRT scanlines (would need a full-resolution overlay).
- Translations.
- Steam leaderboards for the Daily City.

---

## 14. How we work

- **One feature at a time:** Claude builds it → runs the automated checks → updates SETUP_GUIDE.md →
  ticks ROADMAP.md → you playtest it.
- **Reporting a problem:** what you did, what you expected, what happened, and the *first* red
  error if there is one (SETUP_GUIDE.md §4 explains how to copy it).
- **Save a version** (a git commit) after every feature that works, so we can always go back.
- **New ideas** go to §13, not into the current milestone.
- **Review this plan at every gate.** Update the dates honestly; never skip a gate.
