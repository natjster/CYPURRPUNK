# 7. Procedurally generated city

[Back to the contents page](../SETUP_GUIDE.md)


`scripts/city_generator.gd` (on the **City** node in `main.tscn`) builds the city from a single
number, the **city seed**. Same number = exact same city.

- **In the lobby:** type a number in the blue **city #** box before HOST to pick a city, or leave
  it blank for a random one. Players who JOIN get the host's city. (The number is no longer
  shown during a game.)
- **Multiplayer:** the host only sends the number; every computer builds the identical city
  itself (the test tool prints a city "fingerprint"; host and joined player always match).
- **What it builds:** a 6x6 grid of blocks with streets between. Each block has 4 lots: a building
  (taller towards downtown, glowing windows, sometimes a rooftop box and a neon sign with coloured
  light) or an empty yard with a dumpster and a junk pile of traffic cones, boxes and carts
  (real Blockbench models, §20; more stand on some sidewalk corners and by Meow-Mart's door). Small
  trash bins and the plain crate blocks are switched OFF (City > Inspector: **Place Trash Bins**,
  **Yard Crates**; ticking them brings them back in the same spots): the big DUMPSTER is the only trash. Street lamps sit at every
  crossroads and halfway along each block. Invisible walls stop you driving off the edge.
- **Always in the same place, whatever the seed:** each gang's **entry manhole** (Catleone
  Family: the south-west corner crossroads, Burrow Gang: the north-east one) and the car, which
  parks near the centre crossroads.
- **The start menu's city** (city #1999, `generate(seed, true)` in `game.gd`) is a showcase:
  Meow-Mart sits on the lot by the centre crossroads and the Catleone car waits outside it, right
  in the menu camera's view. Nothing runs behind the menu (no heat, no VAC-COPs): only the city
  music and the rain play.
- **Points of interest, somewhere different every district:** **Meow-Mart** (a random lot), the
  **exit manhole** and the **payphones** (placed by `fish_heist.gd`, see §8).

**Tuning** (select **City** in `main.tscn`, Inspector): Blocks Per Side (keep it even), Block
Size, Street Width, Min/Max Height, Empty Lot Chance, Neon Chance, Rooftop Chance, plus the
materials. Building looks: the `Mat_building` material's **Texture Glow** controls how bright the
windows are.

**Why walls are cut into pieces:** every generated box is split into ~2.5 m squares
(`WALL_PIECE_SIZE` in `city_generator.gd`). The PS1 texture warp gets extreme on big triangles,
so without this, windows slanted and "swam" when you looked up at buildings. Textures also use
mipmaps (`filter_nearest_mipmap` in `psx_lit.gdshader`), so distant windows don't sparkle.

**Why the ground is a chessboard of tiles:** streets and sidewalks are separate tiles that never
overlap. An earlier version laid sidewalk slabs 2 cm above the street, and the two surfaces
flickered and streaked against each other, especially with the camera low.

**Performance:** lamps and neon lights fade out beyond ~45 m so only nearby ones cost anything.
Tested at a steady 60 fps on an RTX 4060.
