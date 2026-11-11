# CYPURRPUNK — Setup & How-It-Works Guide

Everything below is **already built as files in this folder**. You don't have to paste code —
open the project and press Play. The sections explain what each piece is, so you can tweak it
(or rebuild it by hand) in the Godot editor.

```
Meow-City/
├── project.godot              <- project settings (low-res, crunchy pixels, autoloads, version)
├── export_presets.cfg         <- how to build the game for other devices: the Android phone build (§17)
├── scenes/
│   ├── game_screen.tscn       <- the top scene F5 runs: the low-res game + the HUD over it (§13)
│   ├── main.tscn              <- THE game (city, cats, menus), shown inside game_screen.tscn
│   ├── player.tscn            <- the cat
│   ├── cat_model.tscn         <- the cat's body (used by player.tscn and the MY CAT preview, §11)
│   ├── cat_parts/             <- accessory models: fedora, beanie, neon_halo, shades... (§11)
│   ├── getaway_car.tscn       <- the car (the Blockbench model models/getaway_car.glb + headlight beam)
│   ├── roomba.tscn            <- the VAC-COP police Roomba (the enemy)
│   ├── items/                 <- item models: tommy_gun, pistol, catnip, catdip, fish
│   ├── npcs/                  <- characters you talk to: don_catleone, lil_mittens, npc_template (§8)
│   ├── props/                 <- street_lamp (warm light cone), rain (follows the camera)
│   └── ui/                    <- settings_menu.tscn (the Settings screen), hud.tscn (the HUD, §13)
├── items/                     <- ITEM CARDS (.tres), one per item, loaded automatically (§9)
├── loot/city.tres             <- THE LOOT TABLE: what lies where in every district (§9)
├── quests/                    <- QUEST CARDS (.tres), one per quest, loaded automatically (§8)
├── cat_parts/                 <- MY CAT: accessory cards (.tres) + palette.tres (colours) (§11)
├── sounds/                    <- SOUND FILES: sfx/, ambience/, music/ — drop files in, no code (§12)
├── models/                    <- REAL 3D MODELS (.glb): trash_bin, traffic_cone, cardboard_box, overclean_poster, loudspeaker, workbench, cyber_bike, fish_van (§20, §21, §23, §25)
│   └── blockbench/            <- their Blockbench projects (.bbmodel): double-click to edit (§20)
├── tools/                     <- Claude's helpers: the Model Shop + Sound Lab (Python, §20)
├── .mcp.json                  <- tells Claude Code to start those helpers in this project (§20)
├── scripts/
│   ├── game.gd                <- main scene: start a game, spawn cats, late joiners
│   ├── game_systems.gd        <- GameSystems: the list of host-run systems (§16)
│   ├── net.gd                 <- autoload "Net": host / join / leave (the only file that knows HOW we connect)
│   ├── settings.gd            <- autoload "Settings": every player setting, saved to disk
│   ├── controls.gd            <- autoload "Controls": every key + controller button, rebinding, rumble, saved to controls.cfg
│   ├── sound.gd               <- autoload "Sound": plays every sound and the music (§12)
│   ├── events.gd              <- autoload "Events": the big moments (sealed, extracted, knocked out...) (§16)
│   ├── overclean_announcer.gd <- OVERCLEAN's voice over the city loudspeaker poles (§21)
│   ├── loudspeaker.gd         <- one OVERCLEAN loudspeaker pole: its words + blinking light (§21)
│   ├── mess_manager.gd        <- MESS-MAKING rules: knocking props over, heat, the bots tidying (§23)
│   ├── spectator.gd           <- THE CAT-CAM: watching your crew after a knockout, the radio HECKLE (§24)
│   ├── mess_prop.gd           <- one knock-over-able bin / cone / box / poster (§23)
│   ├── district_twist.gd      <- DISTRICT TWISTS: blackout, bin day, clearance, high alert (§26)
│   ├── interiors/             <- places you can go INSIDE: meow_mart_interior.gd (the Meow-Mart heist, §27), hit_relay.gd
│   ├── dev_capture.gd         <- autoload "DevCapture": test/screenshot tool (off in normal play)
│   ├── cat_player.gd          <- cat movement, camera, zoomies, getting in/out of the car
│   ├── getaway_car.gd         <- driving, drifting, who's driving
│   ├── city_generator.gd      <- builds the whole city from one number
│   ├── fish_heist.gd          <- fish spots, manholes, payphones, the DEEP CLEAN, the exit arrow
│   ├── wallet.gd              <- Wallet: every player's cash + the sewer scoreboard (§16)
│   ├── hub.gd                 <- THE SEWERS: the underground hub where cats start, one per gang (§8)
│   ├── teams.gd               <- the two gangs: Catleone Family / Burrow Gang (§8)
│   ├── npcs/                  <- the NPC framework: npc.gd, npc_page.gd, npc_choice.gd (§8)
│   ├── quests/                <- the quest system: quest_data.gd, quest_manager.gd (§8)
│   ├── enemy.gd               <- Enemy: what every enemy shares (health, shot, explode, network) (§16)
│   ├── roomba.gd              <- one VAC-COP (extends Enemy): patrol, chase, bonk, vacuum loot
│   ├── hit.gd                 <- Hit: one way for anything to get shot (§16)
│   ├── interactable.gd        <- Interactable: one way for anything to be used with E (§16)
│   ├── motion.gd              <- Motion: small helpers (distance along the ground, network gliding)
│   ├── level_kit.gd           <- LevelKit: boxes, lights, signs, PS1 materials for code-built places (§16)
│   ├── roomba_patrol.gd       <- puts VAC-COPs in the city and replaces destroyed ones
│   ├── rain_follow.gd         <- keeps the rain above the active camera
│   ├── items/                 <- the item system (§9)
│   ├── cat/                   <- the character creator framework: cat_look, cat_part, cat_palette (§11)
│   ├── cat_health.gd          <- HP, downed cats, revives and knockouts (§8)
│   ├── player_profile.gd      <- saves your cash + stash between games (§8)
│   ├── player_id.gd           <- PlayerId: player numbers vs computer numbers, for split screen (§6)
│   ├── seats.gd               <- autoload "Seats": which controller belongs to which couch player (§10)
│   └── ui/                    <- game_screen + hud (§13), main_menu, pause_menu, settings_menu, inventory_ui, npc_dialog, cat_creator
├── shaders/
│   ├── psx_lit.gdshader       <- wobble, warpy textures, flat shading, glow (3D objects)
│   └── psx_post.gdshader      <- CRT + 15-bit color + dithering (full-screen overlay)
├── trailer/                   <- TRAILER MAKER: shot list, music, captions, editing (Python, §15)
├── textures/                  <- tiny placeholder pixel textures
├── ui/menu_theme.tres         <- the look of every menu (colours, borders)
├── ui/hud_theme.tres          <- the look of the HUD text (font, outline, shadow) (§13)
└── shots/                     <- screenshots from the capture tool (Godot ignores this folder)
```

**Opening it:** install **Godot 4.7.2** (standard edition, not .NET). In the Project Manager
click **Import**, pick `project.godot` in this folder, then **Import & Edit**. Press **F5** to play.

**Where your saves go:** `%APPDATA%\MeowCity1999\` (paste that into the Explorer address bar).
The folder keeps its old name on purpose: the game used to be called MEOW-CITY 1999, and renaming the
folder would lose everyone's saves. It's set in **Project > Project Settings > Application > Config >
Custom User Dir Name**; leave it alone.
Set in Project Settings > Application > Config > **Use Custom User Dir** / **Custom User Dir Name**.

---

## Contents (each section is its own file in the `guide/` folder)

Click a section to open it. "§9" anywhere in the guide, the code comments or the notes means section 9 below.

- [§1. Godot project settings for PS1 graphics](guide/01-godot-project-settings-for-ps1.md)
- [§2. The third-person cat controller](guide/02-the-third-person-cat-controller.md)
- [§3. The arcade getaway car](guide/03-the-arcade-getaway-car.md)
- [§4. Testing and fixing errors](guide/04-testing-and-fixing-errors.md)
- [§5. Atmosphere (rainy neon night)](guide/05-atmosphere.md)
- [§6. Multiplayer](guide/06-multiplayer.md)
- [§7. Procedurally generated city](guide/07-procedurally-generated-city.md)
- [§8. The extraction loop: the Sewers hub + Fish Heist](guide/08-the-extraction-loop-the-sewers.md)
- [§9. Items & weapons](guide/09-items-weapons.md)
- [§10. Start menu, pause menu and Settings](guide/10-start-menu-pause-menu-and.md)
- [§11. Character creator (CHOOSE YOUR CAT / MY CAT)](guide/11-character-creator.md)
- [§12. Sound & music](guide/12-sound-music.md)
- [§13. The HUD (overlay)](guide/13-the-hud.md)
- [§14. Backups and undo (git + GitHub Desktop)](guide/14-backups-and-undo.md)
- [§15. Making trailers (the `trailer/` folder)](guide/15-making-trailers.md)
- [§16. Building new things (the frameworks)](guide/16-building-new-things.md)
- [§17. Playing on an Android phone (with a controller)](guide/17-playing-on-an-android-phone.md)
- [§18. Automatic builds and download links (Windows, Linux, Android)](guide/18-automatic-builds-and-download-links.md)
- [§19. The TUTORIAL (PLAY > TUTORIAL)](guide/19-the-tutorial.md)
- [§20. Real models from Blockbench + Claude's tool servers (Model Shop, Sound Lab, Icon Studio)](guide/20-real-models-from-blockbench-claude.md)
- [§21. OVERCLEAN, the announcer (`scripts/overclean_announcer.gd`)](guide/21-overclean-the-announcer.md)
- [§22. The RAID REPORT (end of every district)](guide/22-the-raid-report.md)
- [§23. MESS-MAKING ("Chaos versus Clean") and the MEOW taunt](guide/23-mess-making-and-the-meow.md)
- [§24. The CAT-CAM: watching your crew after a knockout or an early extract](guide/24-the-cat-cam-watching-your.md)
- [§25. SEWER UPGRADES, THE TINKER WORKBENCH and THE SEWER REBELLION](guide/25-sewer-upgrades-the-tinker-workbench.md)
- [§26. DISTRICT TWISTS (a special rule for some districts)](guide/26-district-twists.md)
- [§27. INSIDE MEOW-MART: the first real heist (ROADMAP §4 #8)](guide/27-inside-meow-mart-the-first.md)
