# 11. Character creator (CHOOSE YOUR CAT / MY CAT)

[Back to the contents page](../SETUP_GUIDE.md)


### What the player sees
**PLAY** on the start menu opens **CHOOSE YOUR CAT**: your cats along the top, the look rows on
the left, and the cat slowly turning on the right. (During a game, **MY CAT** in the pause menu
opens the same screen to restyle or rename the cat you're playing; no switching cats mid-game.
Couch players 2-4 get it for THEIR cat: A on their row of the landing page, or MY CAT in their
own pause menu.)
```
<  [ WHISKERS ]  >  2/3  [NEW] [DELETE]     your cats: < > switch, type to rename
FUR       <  [colour]  >        main coat
MARKINGS  <  [colour]  >        belly and muzzle
EYES      <  [colour]  >        bright colours glow a little in the dark
NOSE      <  [colour]  >
HAT       <  FEDORA    >        NONE / BEANIE / FEDORA / GREEN MOHAWK / MOHAWK / NEON HALO
FACE      <  SHADES    >        NONE / CIGAR / CYBER VISOR / HEADBAND / SHADES
NECK      <  NONE      >        NONE / BANDANA / BANDOLIER / BELL COLLAR
VOICE     <  MALE      >        MALE / FEMALE: how your cat sounds when it taunts (you hear it when you switch)
[ BACK ]     [ RANDOM ]     [ NEXT ]        (in a game: [ RANDOM ] [ DONE ])
```
- **Your cats:** you can have as many as you like. **NEW** starts a fresh one (type its name in the
  box), **<** / **>** switch between them, **DELETE** asks "SURE?" and a second click deletes that
  cat **with its cash and stash**. The cat showing when you press NEXT is the one you play.
- **Each cat has its own name, look, cash and stash** (§8 "The stash & saved progress").
- **NEXT needs a name** ("Name your cat first!").
- Everything is **saved straight away** (in `settings.cfg`). Changing your look in the middle of a
  game changes your cat right there, and everyone else sees it.
- **Upgrading from an older version:** your old cat name, look, cash and stash become your first cat.

### The cat model (the original, code-built cat)
Every cat in the game (yours, the MY CAT preview and all 14 sewer NPCs) is the ORIGINAL simple cat
made of Godot shapes (spheres, cylinders and prisms) with the PS1 material: `scenes/cat_model.tscn`
for players and the MY CAT preview; each NPC scene builds its own copy (with its own hat, cigar,
glasses...) under its **Model** node. It wears HAT / FACE / NECK accessories.
- (10 Nov 2026: a Blockbench "armless mascot" cat replaced it for a few hours and was reverted: the
  original was the better look. Its Blockbench file is kept in `models/blockbench/cat.bbmodel` and
  in git history, but nothing in the game uses it.)

### Add a new accessory (no code)
1. **Make its model.** In the FileSystem dock, right-click `scenes/cat_parts/beanie.tscn` >
   **Duplicate...** and name it (e.g. `cowboy_hat.tscn`). Double-click it and change the meshes:
   select a mesh > Inspector > **Mesh** for the shape, **Surface Material Override** > albedo_color
   for the colour. Build it around the **origin (0, 0, 0)**: that point is put on the cat at the
   slot's spot: **hat** = top of the head, **face** = just in front of the eyes, **neck** = round
   the neck.
2. **Make its card.** Right-click `cat_parts/beanie.tres` > **Duplicate...** (e.g.
   `cowboy_hat.tres`). Double-click it and set: **Id** (unique, no spaces, e.g. `cowboy_hat`),
   **Display Name** (what MY CAT shows), **Slot** (hat / face / neck), and drag your `.tscn` into
   **Scene**.
3. **Fit it** (optional): **Fit > Offset** nudges it (metres; -Z is towards the nose),
   **Rotation Degrees** tilts it, **Scale** resizes it. Open MY CAT to check how it sits.

That's it: it's in the MY CAT screen next time you press F5.

### Change the colours (no code)
Double-click `cat_parts/palette.tres`. It has four lists: **Fur Colors**, **Marking Colors**,
**Eye Colors**, **Nose Colors**. Click a colour to change it; **+ Add Element** adds one. The first
colour of each list is what a brand-new cat starts with in MY CAT.

### Where it lives
- `scripts/cat/cat_look.gd` (`CatLook`) — the framework. A cat's **look** is a small list of
  values: four colours plus which part is in each slot. `CatLook.apply(model, look)` paints a cat
  model and puts the parts on. It also loads the part cards and palette, makes random looks, and
  throws away anything broken (unknown parts, wrong types).
- `scripts/cat/cat_part.gd` (`CatPart`) — the accessory card. `scripts/cat/cat_palette.gd`
  (`CatPalette`) — the colour lists.
- `cat_parts/` — the cards and the palette. `scenes/cat_parts/` — the accessory models.
- `scenes/cat_model.tscn` — the cat's body, used by player cats and the MY CAT preview. The colour
  rows paint meshes **by name** (FUR = Body, legs, Head, ears, Tail; MARKINGS = Belly, Muzzle;
  EYES = EyeL/EyeR; NOSE = Nose), listed in `COLOR_PARTS` in `cat_look.gd`.
- `scripts/ui/cat_creator.gd` (`CatCreator`, on **PS1Overlay > CatCreator**) — the screen. It builds
  itself: the cat row, then one row per colour and per slot.
- `scripts/settings.gd` — your cats: `Settings.cats` (each `{"id", "name", "look"}`) and
  `Settings.current_cat_id`, with helpers `current_cat()`, `new_cat()`, `select_cat()`,
  `update_current_cat()`, `delete_cat()`. Each cat's cash + stash file is named after its id.
- **Multiplayer:** your look is the `look` property on your cat (`cat_player.gd`). The cat's
  MultiplayerSynchronizer shares it like the name tag, so everyone (late joiners too) sees it.
  Looks are only for show: they don't change anything about how you play.

### Add a new slot (a little code)
For a fourth kind of accessory (e.g. **back** for capes and jetpacks): in `cat_look.gd` add
`"back"` to **SLOTS** and a spot to **SLOT_ANCHORS** (e.g. `"back": Vector3(0, 0.5, 0.2)`); in
`cat_part.gd` add `"back"` to the Slot list (`@export_enum`); and add `"back": "BACK"` to
**LABELS** in `cat_creator.gd`. The new row then appears in MY CAT by itself.

### Testing shortcut
`--menu=cat` opens CHOOSE YOUR CAT (MY CAT with `--host`/`--solo`), `--menu=mode` the SOLO /
MULTIPLAYER screen, before the screenshot. `--solo` starts a solo game. `--look=N` wears a random look made from the
number N (both on the start menu and with `--host` / `--join`); test runs never save it.
`--wear=hat:mohawk,face:headband,neck:bandolier` wears exact parts (colours too: `fur:#808080`), and
`--portrait=me` (or an NPC's node name, e.g. `--portrait=DonCatleone`) takes a HUD-free close-up of
the face; nudge the camera with `--portrait_dist`, `--portrait_height`, `--portrait_side`. Every
cat's look is printed, e.g. `DevCapture look 1: fur=#383342 hat=neon_halo face=shades neck=-`.
