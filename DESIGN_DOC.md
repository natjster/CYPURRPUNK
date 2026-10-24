# MEOW-CITY 1999 (or MEOW-PUNK) — Master Game Overview & Executive Design Document

> The long-term vision, as written by the owner (saved 2026-10-24). It differs from the Steam MVP
> in `PLAN.md` in several places. Until the owner decides otherwise, `PLAN.md` / `ROADMAP.md` are
> what gets built; this document is where the game could grow.

## 1. Executive Summary & Core Identity
- **High concept:** a free-to-play, retro-dystopian, 32-bit PvPvE extraction heist game where
  players control low-poly street cats navigating a neon-lit, rain-soaked cyberpunk metropolis.
- **Target audience:** streamers, content creators and their audiences on platforms like Twitch and
  Kick; fans of chaotic physics, social deduction and retro aesthetics (Old School RuneScape,
  Lethal Company, Fly Knight, Valheim, Helldivers 2 demakes).
- **Core philosophy:** low hardware barriers and high-variance emergent physics create continuous,
  unscripted comedic clips and community moments.

## 2. Pillars of Design
| Pillar | Design rule | Gameplay impact |
|---|---|---|
| 1. 3D spatial proximity chat | Positional voice with room occlusion & radio/8-bit modulation | Natural comedy, uneasy alliances, backstabs, echoey screaming from down dark alleys |
| 2. Frictionless onboarding | Instant 4–6 character room codes; universal cross-play | Streamers open a private lobby and pull in viewers within seconds from PC or mobile |
| 3. Crunchy "shitty" PS1 graphics | Sub-500-poly models, 256x224 to 320x240 internal render, affine texture warping | 60–120 FPS on budget PCs, integrated graphics and phones, maximising the player pool |
| 4. High-variance ragdoll physics | Loose suspension, bouncy collision boxes, lightweight character bodies | Crashes, explosions and high-speed turns send cats and scrap flying through neon billboards |
| 5. Community server overclocks | EverQuest THJ-style shared buff pool funded by player deposits or stream chat | Community-wide events (Double Catnip Drops, Low Gravity, Super Zoomies) for everyone online |

## 3. The Dual-Zone World Structure
```
 ┌──────────────────────────────────────────────────────────────┐
 │               UNDERGROUND HUB ("THE SEWERS")                 │
 │  * Safe zone (weapons/vehicles disabled)                     │
 │  * 3D Proximity Voice chat lounge & trade market             │
 │  * Faction Quest Givers & Custom Garages                     │
 │  * "The Mainframe" (Central deposit for Server-Wide Buffs)   │
 └──────────────────────────────┬───────────────────────────────┘
                                │ Surface Airlocks & Drainage Pipes
                                ▼
 ┌──────────────────────────────────────────────────────────────┐
 │                SURFACE METROPOLIS (PVPVE ZONE)               │
 │  * Full PvP combat & high-speed arcade driving               │
 │  * High-value scrap, Catnip, and battery looting             │
 │  * Environmental AI: VAC-COPS (Roombas, SWAT mechs, choppers)│
 │  * Extraction points back to the Underground safe zone       │
 └──────────────────────────────────────────────────────────────┘
```
- **The Underground Hub (the social core):** a zero-combat lobby where players spawn. Neon-lit
  drainage tunnels, cardboard-box shanties, black-market tuning shops, and "The Mainframe" — a
  massive CRT supercomputer where players deposit scrap to trigger server-wide buffs.
- **The Surface City (the lawless extraction ground):** a sprawling, multi-tiered cityscape drenched
  in green fog and rain. Players drive retro arcade getaway cars, raid tech depots, steal high-grade
  Catnip and fight rival crews while managing their heat level against automated police bots.

## 4. Core Gameplay Loop (sessions of 8–12 minutes)
```
[01. Gear & Group] ──► [02. Breach Surface] ──► [03. Heist & Drive] ──► [04. The Climax] ──► [05. Return]
 Assemble crew in      Exit pipes into        Steal loot, fire       Cops escalate,         Bank scrap,
 Underground hub,      city; call down        drive-bys at rivals,   extraction points      mod vehicles,
 pick up bounties      getaway vehicles       dodge VAC-COPs         open under heavy fire  buff the server
```
1. **Deploy:** form a crew in the underground hub, accept a faction contract (e.g. "Steal 3 Mil-Spec
   Battery Cores") and exit via a drainage airlock.
2. **Drive & scavenge:** jump into an arcade vehicle. Drivers manoeuvre through alleyways and ramps
   while passengers lean out of windows with low-poly guns.
3. **Escalation (the "E" in PvPvE):** firing weapons or stealing crates generates police **Heat**.
   Low-level patrolling Roomba Bots call in SWAT Vacuum Walkers and aerial scanner drones.
4. **Extraction:** once inventory slots are packed with bulky physics props (CRT monitors, Catnip
   crates), crews race toward timed drainage gates before police lock down the perimeter.
5. **Deposit & overclock:** safely extracted scrap is sold for cosmetic mods, or deposited into the
   community pool to trigger global server buffs.

## 5. Factions & Lore
- **The Alley Scrappers:** mechanics and street racers — nitrous upgrades, reinforced bumpers,
  high-speed courier runs.
- **The Scratch-Paws:** covert roof-runners — vertical agility, zip-lines, cracking high-security
  rooftop tech vaults.
- **The Roomba Liberation Front (RLF):** rogue, re-programmed household utility bots fighting back
  against city-controlled law enforcement.

## 6. The "Mainframe Overclock" System (EverQuest THJ style)
- **The deposit pool:** players turn in excess extracted batteries, or viewers trigger chat
  milestones, to fill a global meter displayed in the Underground Hub.
- **Activation:** hitting 100% triggers a 45-minute server-wide event, announced by a siren on
  every player's screen:
  - **Zoomies Overclock:** sprint speed +30%; fall damage turns into bouncy ragdoll hops.
  - **Double Dip:** Catdip and rare cyberware drops double in surface zones.
  - **System Short-Circuit:** police bot reaction time and visual range are halved.

## 7. Streamer & Viewer Integration (Twitch / Kick)
- **Proximity voice modulation:** filters let streamers talk through walkie-talkie clipping,
  megaphone reverb, or muffled sound through closed car windows.
- **Audience hazard voting:** viewers vote every few minutes to spawn chaotic map modifiers:
  - **Zero-G Pulse:** lowers gravity for 60 seconds, sending cars into low-orbit flips.
  - **Laser Pointer Hazard:** a giant red laser dot in the streamer's camera view pulls the cat's
    ragdoll toward it.
- **1-click viewer queuing:** streamers show a 4-digit room code; viewers on PC or mobile enter it
  from the main menu and drop straight into the streamer's underground lobby.

## 8. Technical Architecture & Tech Stack
| Component | Selected technology | Why it fits |
|---|---|---|
| Game engine | Godot 4 | Lightweight, open-source, fast iteration, native retro viewport scaling, free exports for PC and mobile |
| Art pipeline | Blender (low-poly) + Aseprite | Fast asset turnaround (models under 500 triangles); low-res textures (64x64 to 256x256) |
| Shaders | PSX / PS1 screen shader | Vertex snapping, affine texture warping, dithering and distance fog |
| Physics | Godot 3D physics (RigidBody + RayCasts) | Lightweight arcade vehicles with spring suspension and comedic ragdoll collisions |
| Networking | Godot high-level multiplayer / Steamworks | Client-server with state sync for positions, health and physics impulses |
| Audio | Steam Audio / Godot WebRTC VOIP | Positional 3D audio, occlusion (walls/doors), real-time capture filters |

## 9. Minimum Viable Product (MVP) Scope
Before expanding into a multi-block city, a playable single-block vertical slice:
- **1 playable cat:** movement, jump, sprint ("Zoomies") and paw attack.
- **1 arcade car:** enter/exit, basic acceleration, steering and drift physics.
- **1 enemy unit:** a patrolling police Roomba bot that triggers ragdoll collisions on impact.
- **1 test block:** a small grayboxed alleyway with ramps, a dumpster and a low-res PS1 camera
  post-processing filter.
