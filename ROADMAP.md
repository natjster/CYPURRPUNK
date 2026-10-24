# MEOW-CITY 1999 — Road to a Steam MVP

Tick a box by changing `[ ]` to `[x]`. **Owner** says who does it: **You** (only you can),
**Claude** (I can build it), or **Both**.

The full plan behind this checklist (game design, build order, milestone gates, calendar, risks)
is in **[PLAN.md](PLAN.md)**.

---

## Already done ✅
- [x] PS1 look: 320x240, vertex wobble, warpy textures, flat shading, dithering, CRT
- [x] Atmosphere: fog, glow, street lamps, neon signs, rain, headlights
- [x] Cat controller: walk, jump, zoomies, camera
- [x] Arcade getaway car: drive, brake/reverse, handbrake drift, enter/exit
- [x] Multiplayer (LAN / same PC): lobby, host/join, cat names, shared car, smoothing, late join
- [x] Test tooling: screenshot and multiplayer test commands (`scripts/dev_capture.gd`)
- [x] Procedurally generated city from a seed, identical for every player (`scripts/city_generator.gd`)

---

## Phase 0 — Paperwork (start now: it has waiting periods)
| | Task | Owner |
|---|---|---|
| [ ] | Search Steam + do a quick trademark search for the name "MEOW-CITY 1999" | You |
| [ ] | Create a Steamworks partner account (partner.steamgames.com) | You |
| [ ] | Fill in identity, bank and tax info | You |
| [ ] | Pay the $100 Steam Direct fee (**starts the 30-day wait before you can release**) | You |
| [ ] | Note the App ID Steam gives you (needed for Phase 2) | You |
| [ ] | Back up the project: git + a private GitHub repo (GitHub Desktop) | Both |
| [ ] | Answer the decisions in PLAN.md §1 (players, lobbies, screen shape, music) | You |
| [ ] | Early check: the GodotSteam add-on works with Godot 4.7.2 (Valve's free test app 480) | Claude |

## Phase 1 — Make it a game (the MVP itself)
| | Task | Owner |
|---|---|---|
| [x] | Decide the core loop: **Fish Heist**, no timer — auto-pickup fish, deliver to a drop-off, individual cash | You |
| [x] | Fish Heist basics: fish spots + respawn, auto-pickup (max 3), drop-off beam, per-player cash, HUD (`scripts/fish_heist.gd`) | Claude |
| [x] | Items & weapons framework: item cards, paws (1/2-paw, dual wield) + loot bag, shared Weapon script; tommy gun + fish moved onto it; catnip added (`scripts/items/`) | Claude |
| [x] | Paw-Pistol: 1-paw, one shot per click, dual-wieldable, 4 per city (`scenes/items/pistol.tscn`, `items/pistol.tres`) | Claude |
| [x] | Catdip: 1-paw tin, click for 20 s of double jump, 3 per city (`scripts/items/catdip.gd`) | Claude |
| [x] | Inventory screen (Tab / I): paws, 6-slot backpack, loot bag; equip, put away, drop; item descriptions (`scripts/ui/inventory_ui.gd`) | Claude |
| [ ] | More items: golden fish, ... (recipe in SETUP_GUIDE.md §9) | Both |
| [x] | Purr-Tommy 2099: futuristic tommy gun — E pick up, hold LMB fire, G drop, overheat, knockback (`scenes/items/tommy_gun.tscn` + `weapon.gd`) | Claude |
| [ ] | Decide what the tommy gun is *for* in the Fish Heist (e.g. knock fish loose, stun Dog Patrol), then add it to PLAN.md | You |
| [x] | Tidy-up: networking out of `game.gd` (`Net` autoload), menus in their own scripts, a settings system, car input separate from driving, shared cat lookup, test tool off in release, own save folder | Claude |
| [ ] | Build the core loop: objective, timer, score, win/lose, round restart | Claude |
| [ ] | Playtest gate: 3 rounds in a row and people want a 4th (PLAN.md M1) | Both |
| [ ] | Dog Patrol: police cars that chase the getaway car, plus the heat level | Claude |
| [ ] | Passenger seats (up to 4 cats in the car) | Claude |
| [ ] | HUD: timer, score, cargo, heat, arrow to the objective, button prompts | Claude |
| [ ] | Meow button | Claude |
| [ ] | Results screen, round briefing card (title menu done) | Claude |
| [ ] | Version check when joining + clear "host left" / "disconnected" messages | Claude |
| [ ] | City variety: more building types, alleys you can drive through, landmarks (the generator exists — this is about richness) | Both |
| [ ] | Content target: 15–30 minutes of fun, replayable | Both |
| [ ] | Procedural cat animation (legs, tail, head bob — no 3D modelling needed) | Claude |
| [ ] | Sound: rain ambience, music, engine, meows, UI clicks | Both |
| [x] | Pause menu: resume, settings, leave game, quit | Claude |
| [x] | Settings: fullscreen/window, window size, vsync, FOV, volumes, mouse speed, invert Y (`scripts/settings.gd`, `scenes/ui/settings_menu.tscn`) | Claude |
| [x] | Comfort/performance toggles: CRT strength, PS1 wobble, volumetric fog | Claude |
| [x] | New start menu: PLAY / SETTINGS / QUIT, lobby box, neon title, panning city, version shown | Claude |
| [ ] | Music + sounds use the **Music** / **SFX** buses so the volume settings affect them | Claude |
| [ ] | Controller support (needed for Steam Deck) | Claude |

## Phase 2 — Steam integration
| | Task | Owner |
|---|---|---|
| [ ] | Add the **GodotSteam** add-on | Claude |
| [ ] | Swap the network connection to Steam's relay (online play, no port forwarding) | Claude |
| [ ] | Steam lobbies + "Invite friend" (keep IP join for LAN) | Claude |
| [ ] | Use the Steam username as the default cat name | Claude |
| [ ] | Achievements (optional, cheap visibility) | Claude |
| [ ] | Test online with a friend in another house | You |

## Phase 3 — Build & upload
| | Task | Owner |
|---|---|---|
| [ ] | Download Godot 4.7.2 export templates (Editor > Manage Export Templates) | You |
| [ ] | Windows export preset (embed the game data in the .exe) | Claude |
| [ ] | SteamPipe upload script (steamcmd) | Claude |
| [ ] | Make sure `steam_appid.txt` is NOT in release builds | Claude |
| [x] | Test tool (DevCapture) switched off in release builds; game version shown in the menu | Claude |
| [x] | Saves and logs in their own folder (`%APPDATA%\MeowCity1999`) | Claude |
| [ ] | Test on a weak/older PC; check frame rate | You |
| [ ] | Optional: Linux build + Steam Deck check (1280x800, controller) | Both |

## Phase 4 — Store page & legal
| | Task | Owner |
|---|---|---|
| [ ] | Capsule images (main, header, small, vertical) — check exact sizes in Steamworks | You |
| [ ] | Library images (cover, hero, logo) | You |
| [ ] | 5+ screenshots at 1920x1080 | Both |
| [ ] | Trailer, 30–60 s (neon rain + car chases) | You |
| [ ] | Short + long description, tags, system requirements | Both |
| [ ] | Content survey / age rating questionnaire in Steamworks | You |
| [ ] | Credits screen with Godot's MIT licence + all font/sound/music credits | Claude |
| [ ] | Check the licence of every third-party asset (keep `ASSET_LICENSES.md` from day one) | Both |
| [ ] | Simple privacy statement (if you collect no data) | Both |

## Phase 5 — Launch
| | Task | Owner |
|---|---|---|
| [ ] | Publish the **"Coming Soon"** page early (wishlists!) — must be live **2+ weeks** before release | You |
| [ ] | Closed test via **Steam Playtest** or keys; fix what breaks | Both |
| [ ] | Optional: demo in a **Steam Next Fest** | Both |
| [ ] | Submit store page + build for Steam review (allow ~1 week) | You |
| [ ] | Set the price and release date | You |
| [ ] | 🚀 Release | You |

---

## Later (not needed for MVP)
- [ ] Physics interpolation for your own camera (smoother on 120 Hz+ monitors)
- [ ] Anti-cheat / don't fully trust the host (only matters for public lobbies with strangers)
- [ ] More cars, more cat colours/cosmetics
- [ ] Mac build
