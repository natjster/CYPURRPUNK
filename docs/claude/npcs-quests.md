# NPC framework, shops, loot table, quests

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

## NPC framework
Talking characters: `scripts/npcs/npc.gd` (`Npc`, StaticBody3D, group `npcs`), conversation data =
`pages: Array[NpcPage]` (first = greeting; empty choices reuse page 1's) of `NpcChoice` (text,
message, action, go_to). Built-in actions in `Npc._run_action`; custom ones via subclass
`_on_action` or the `action_chosen` signal. NPCs are Interactables (below): E -> `talk(cat)`. New NPCs start from
`scenes/npcs/npc_template.tscn`. Not networked (local per peer). Test: `--talk[=NodeName] --choose=N,M`.
Pages can gate the greeting on quest state (`only_if_quest`/`only_if_state`); action `quest:<id>` starts one.
Shops: `Shopkeeper` (`scripts/npcs/shopkeeper.gd`, extends Npc) — choice action `shop` opens BUY buttons for
its `stock`; prices = `ItemData.price` (0 = not for sale); host `ItemManager.request_buy` -> `Wallet.spend`.
Comrade Whiskers (`scenes/npcs/comrade_whiskers.tscn`) runs THE BLACK MARKITTEN on the hub's west wall
(decor in `hub._build_shop`). The loot table places only loot; gear (guns too) is scavenged from props (`MessManager` finds tables).
LOOT TABLE: `ItemManager.loot_table` = `res://loot/city.tres` (`LootTable` of `LootSpawn` lines: item_id, count, where
SIDEWALK/OUTSIDE_MEOW_MART/FIXED_SPOT, min_distance_from_meow_mart, respawn_seconds), placed first in `_on_city_generated`
(own rng, `LOOT_SEED_SALT`); then `item_placers` (the heist: manholes + payphones). Never hard-code loot spots in code.
Test: `--cash=N --talk=ComradeWhiskers --choose=0,K` (client: add `--wait=120`).


## Quest framework
`scripts/quests/quest_manager.gd` (`QuestManager.instance`, `Quests` node): cards = `QuestData` .tres in
`res://quests/` (auto-loaded). Host-authoritative `active`/`completed` per peer, synced via `_set_quests`;
progress is counted from the backpack (`count_in_bag`, not synced separately). `fish_heist.gd` calls
`complete_on_extract` at the exit (items stay in the backpack) and adds the bonus in `_extracted`. (No HUD quest line any more.)
ONE QUEST AT A TIME: `current_quest(id)`, `giver_of(id)` (`givers`, 5th arg of `_set_quests`), `progress_text(id)`;
host `_request_start` refuses while one is active; `Npc._choose` says `busy_lines` instead; inventory JOB box + ABANDON
(`abandon_quest`, hub only, two presses). Test: `--quest=X --abandon_quest`.
Five shared cards (table in SETUP_GUIDE §8), `QuestData.kind`: CARRY_ITEM (bag), DESTROY_ROOMBAS, EXTRACT_AT_HEAT
(`heat_needed`), DISRESPECT. Kill / disrespect counts = host `tallies` from Events (`enemy_destroyed` + `Enemy.killed_by`,
`player_robbed`, `player_slapped` from `request_shot`'s melee flag), synced in `_set_quests`, wiped by `player_knocked_out`.
Quest givers = 5 per sewer in matching spots (REBELLION recruits: only there once recruited at the workbench), both gangs use the same quest ids; pages ready/waiting/thanks/hello/ask/about/
blame/remind (Frankie and Jax have no "ready" page: their progress is live heat). Story: SETUP_GUIDE "Night of the Big Red Button".
Test: `--talk=PaulieNoBrooms --choose=0,0 --kill_roombas=5 --heat=80 --goto_dropoff_after=60 --talk_again_after=40`;
`--quest=ID` skips the NPC (use it with `--deploy`, `--talk` pulls the cat back to the hub).
