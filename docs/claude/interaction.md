# Interaction framework (E key)

(Moved out of CLAUDE.md on 11 Nov 2026 to keep every session cheaper. Keep this file up to date.)

- `scripts/interactable.gd` (`Interactable`): anything in group `interactables` answers `interact_distance(cat)`
  (-1 = not now), `interact_prompt(cat)` ("" = no HUD line), `interact(cat)`, optional `interact_priority()`
  (items 30, NPCs 20, stash 10, car 0).
- cat_player E -> `Interactable.try_use(cat)`; hud.gd `_update_prompt` shows `Interactable.prompt_for(cat)` in `Prompt`.
- `Interactable` is also a node (Prompt/Radius/Priority exports, `used(cat)` signal;
  `Interactable.make(parent, at, text, r, prio)`): the stash lockers are one.
- Members: ItemManager (nearest press-E street item), Npc (+ Payphone/Shopkeeper), GetawayCar (`nearby_car` door
  zone, "GET IN").
- Runs on the presser's computer; game changes go through host RPCs. Never add interact branches to cat_player.
- Test: `--press_key=E` (waits 10 physics frames after `--pos`), `--talk`, `--grab`.
