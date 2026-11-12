# 16. Building new things (the frameworks)

[Back to the contents page](../SETUP_GUIDE.md)


The game already has "add a card, no code" systems for items (§9), NPCs and quests (§8), cat
accessories (§11) and sounds (§12). This section covers the frameworks for the bigger pieces:
new game systems, game events, money, things you press E on, new enemies, new things you can shoot, and new places to build.

### Game systems (`scripts/game_systems.gd`, class **GameSystems**)
A **game system** is a node under **Main** that the host runs and that keeps something for every
player or for the whole game. Today these are: **GetawayCar** (who drives), **Items**, **Quests**,
**Heist** (the exit), **Wallet** (cash), **Health**, **Heat** and **Roombas** (the patrol).

Each one joins the group `game_systems` and answers any of three calls. game.gd just calls
"everyone in the group", so it never needs to know which systems exist:

| Call | When (host only) | Example |
|---|---|---|
| `start_district()` | a game starts, or the crew moves to a new district | Heat goes back to 0, a fresh patrol, the car is parked |
| `send_state_to(peer)` | a computer joins mid-game | send everyone's cash to the newcomer |
| `player_left(player_id, last_position)` | a player quits | forget their HP; drop their gear at `last_position` |

**Adding a new system** (e.g. the planned SCRAP or MAINFRAME):
1. In `main.tscn`, right-click **Main > Add Child Node > Node**, name it (e.g. `Mainframe`).
2. Attach a new script. In its `_ready()` write `add_to_group(GameSystems.GROUP)`.
3. Write only the calls from the table that it needs. That's it: late joiners, quitting players
   and new districts are handled without touching game.gd.

The calls go top to bottom in the scene tree order of `main.tscn`. **Items** must stay above the
systems that read items (it sends the items a late joiner needs first).

### Game events (`scripts/events.gd`, the autoload **Events**)
The big moments of a raid are announced in one place. The system where something happens just
says so; anything that cares listens. Nobody has to know who else is listening.

| Event | When | Heard on |
|---|---|---|
| `district_sealed()` | max heat: the hatch seals, the DEEP CLEAN starts | every computer |
| `player_extracted(player_id, loot_value, quest_bonus)` | a player climbed down the exit | every computer |
| `player_downed(player_id, cause)` | a cat hit 0 HP and waits for a revive | every computer |
| `player_revived(player_id, by)` | a teammate picked a downed cat back up | every computer |
| `player_robbed(player_id, by)` | a rival robbed the loot in a downed cat's backpack | every computer |
| `player_knocked_out(player_id, cause)` | a cat is out for good (bled out, gave up, solo, DEEP CLEAN): loot spills | every computer |
| `heat_level_changed(level)` | the heat went up (or down) a level | every computer |
| `item_picked_up(player_id, item_id)` | someone grabbed or bought an item | host only |
| `enemy_destroyed(enemy)` | a VAC-COP (or any enemy) blew up | host only |

**Listening** (e.g. the planned MAINFRAME losing a chunk when a district is sealed):
```
func _ready() -> void:
	Events.district_sealed.connect(_on_district_sealed)

func _on_district_sealed() -> void:
	if multiplayer.is_server():   # game rules: only the host changes them
		print("the MAINFRAME loses a chunk")
```
The Roomba patrol already works this way: it sends in the DEEP CLEAN swarm when it hears
`district_sealed`. **A new event:** add a `signal` line to `events.gd` (with a comment saying who
hears it) and call `Events.my_event.emit(...)` where it happens.
**Testing:** add `--event_log` to a test run to print every event as it fires (`[Events] ...`).

### Money (`scripts/wallet.gd`, class **Wallet**, the **Wallet** node)
Every player's cash lives in one place. The host is the only one who changes it; everyone has a
copy (for the shop page and the sewer scoreboard). Anything that pays or charges calls one line,
**on the host**:

| Line of code | What it does |
|---|---|
| `Wallet.instance.earn(player_id, 120, "sold scrap")` | give cash (the text is for the console log) |
| `Wallet.instance.spend(player_id, 50)` | take cash; returns `false` (and takes nothing) if they can't afford it |
| `Wallet.instance.cash_of(player_id)` | how much they have (works on every computer) |

The exit pays your loot this way, the Black Markitten charges this way, and your save file
(`player_profile.gd`) saves whatever the wallet says. A new way to earn or pay (selling scrap,
feeding the MAINFRAME) needs nothing else. Want to react when cash changes? Connect
`Wallet.instance.cash_changed` (it fires on every computer).

### Pressing E (`scripts/interactable.gd`, class **Interactable**)
Everything you can use with E goes through one system: street items, NPCs, payphones, the stash
lockers and the car. The cat just asks "what's the best thing in reach?" and uses it; the HUD
shows that thing's line ("[E] TALK", "[E] STORE YOUR SHIT", "[E] GET IN"). When two are
in reach, the higher **priority** wins (items 30, NPCs 20, stash 10, car 0), then the nearer one.

**Making something new usable, no code for the "where" part** (e.g. a MAINFRAME terminal):
1. Right-click the node it belongs to > **Add Child Node** > search **Interactable** > Create.
2. Move it to the spot. In the Inspector set **Prompt** (e.g. `FEED THE MAINFRAME`), **Radius**
   (how close you must be) and **Priority**.
3. Node dock (next to the Inspector) > **Signals** > double-click **used** > connect it to the
   script that should react. That function gets the cat that pressed E.

The stash (the litterbox) uses exactly that, in code (`_build_stash()` in `scripts/hub.gd`).
**A thing with its own idea of "in reach"** (like the car's door zone or the street items) can
instead join the group `interactables` and write the answers itself:
`interact_distance(cat)` (metres, or -1 = not now), `interact_prompt(cat)` (the line, "" = none),
`interact(cat)`, and optionally `interact_priority()`. See the bottom of `scripts/getaway_car.gd`.
**Multiplayer:** this runs on the computer of the player who pressed E. Anything everyone must
see, or that changes items or cash, asks the host with an `@rpc` (like buying or picking up).

### Getting shot (`scripts/hit.gd`, class **Hit**)
When a gun fires, it finds what the bolt hit and hands it a **Hit**: who shot, which gun, the
damage (already rolled, crits included), which way the bolt flew and where it landed. The gun
doesn't care WHAT it hit. Each shootable thing has one function, `receive_hit(hit)`, that decides:

| Thing | What a hit does | Damage number? |
|---|---|---|
| Any enemy (VAC-COP, MEGA VAC-COP) | loses health (the host keeps score); explodes at 0 | yes |
| Another cat | gets shoved (the gun's **Cat Knockback** / **Cat Hop**) | no |
| The getaway car | gets pushed (the gun's **Car Impulse**) | no |

**Making something new shootable** (a breakable crate, a security camera...): give its script
```
func receive_hit(hit: Hit) -> bool:
	# e.g. ask the host to break it: break_me.rpc_id(1)
	return true   # true = the shooter sees a damage number
```
The function can sit on the node with the collision shape or on its parent (a few levels up is
fine), so a hitbox can be a child node. This runs on the **shooter's** computer, so anything
everyone must see goes through an `@rpc`.

### Enemies (`scripts/enemy.gd`, class **Enemy**)
Everything every enemy needs, in one place: **health** (synced, with the floating health bar once
shot), **getting shot** (`receive_hit` above), **getting run over** by the car, **exploding**
(drops what's inside it + **Drop On Destroy**, heats up the city, or cools it for a boss), and
**network gliding** for the other players. The VAC-COP (`roomba.gd`) is built on it, and only
says how a VAC-COP drives, chases and bonks.

**Making a new enemy** (e.g. a security drone):
1. Duplicate `scenes/roomba.tscn` as `drone.tscn` and give it a new **Model**: build one in
   Blockbench (§20) and drop the `.glb` in as the Model node, like `roomba.tscn` does. Keep a part
   called **Body** (it flashes when shot, or point **Flash Mesh** at another one) and one called
   **Eye** (the crit weak spot: **Eye Weak Spot** in the Inspector). The model gets the PS1 material
   by itself; list the parts that should glow, and their colour, in **Look > Glow Parts** (white =
   your script tints it while playing).
2. Make a new script that starts with `extends Enemy` and put it on the root (replacing
   roomba.gd). Its numbers (Max Health, Display Name, Drop On Destroy, sounds...) are already in
   the Inspector.
3. Write its brain in `_physics_process(delta)` (runs on the host only): move it, set
   `sync_position = global_position` and `sync_yaw = model.rotation.y` at the end, and call
   `if run_over_by_car(delta): explode()` if the car may squash it. Optional: `_on_hurt(shooter)`
   (got shot, still alive), and `_ready` / `_process` (start them with `super()` /
   `super(delta)` so the shared part still runs).
4. Spawn it on the host under a node a **MultiplayerSpawner** watches (like **Roombas** +
   **RoombaSpawner**), and connect its `destroyed` signal if the spawner should react (replace
   it, count kills...). Ask Claude to wire up the spawning.

Copy `scripts/roomba.gd` for a full working example.

### Building places in code (`scripts/level_kit.gd`, class **LevelKit**)
The city, THE SEWERS and the manholes are built by code, not by hand in the editor. They all use
the same kit of building blocks, so a new place (the MAINFRAME room, a new district type...) gets
the PS1 look and the rules below for free:

| Line of code | What it makes |
|---|---|
| `LevelKit.psx_material({"albedo_color": Color(0.3, 0.3, 0.3)})` | a material with the PS1 look (any `psx_lit` shader setting) |
| `LevelKit.add_box(self, center, size, material, true)` | a box; `true` = solid (cats and cars bump into it) |
| `LevelKit.add_cylinder(self, center, radius, length, material)` | a six-sided pipe or pillar |
| `LevelKit.add_light(self, at, color, energy, range)` | a pool of coloured light glowing into the fog |
| `LevelKit.add_sign(self, "TEXT", at, color, font_size, facing)` | glowing neon letters |
| `LevelKit.subdivided_plane(Vector2(w, d))` | a flat floor piece |
| `LevelKit.instantiate_model("trash_bin", self, at, yaw)` | a copy of `res://models/trash_bin.glb` with the PS1 look (§20) |
| `LevelKit.psx_ify(node)` | gives every mesh under a node the PS1 look, keeping its painted texture (§20) |

**The rules it keeps for you:** big surfaces are cut into ~2.5 m pieces (on big triangles the PS1
textures shear and "swim"), and boxes of the same shape share one mesh (a city has hundreds).
Give one box its own colour with `box.set_instance_shader_parameter("instance_tint", Color(...))`
instead of making a new material.
**The rule you keep:** never put two visible surfaces a few cm apart (a floor on a floor): they
flicker. Example: `_build_shop()` in `scripts/hub.gd`.
