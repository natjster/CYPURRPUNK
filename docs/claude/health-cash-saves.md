# Health / downed / revive, Wallet, stash + profile saves

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- Health: `scripts/cat_health.gd` (`CatHealth.instance`, `Health` node, HUD label `Health`): host-only
  `damage(player_id, n, cause, instant=false)` (Roomba `bonk_damage`). 0 HP = DOWNED (`downed` {id: bleed secs left},
  `is_downed`; keeps loot, crawls at `crawl_speed`, no jump/drop/items/E) unless `instant` (DEEP CLEAN) or nobody else
  is on their feet (`_anyone_could_help`; solo = instant). Revive: a downed CatPlayer is an Interactable (priority 40,
  methods hand on to `downed_distance/downed_prompt/start_hold`); reviver holds interact -> `request_hold(helper, downed, on)`;
  host times it (`reviving` {downed: {by, left}}, bleed clock paused) -> `_revive` (`revive_health`). Bleed out /
  `request_give_up` (downed holds interact) -> `_knock_out` = `drop_everything` + `_knocked_out` RPC (owner flops via
  `CatPlayer.knocked_out`, then `hub.return_cat`). `is_down` = 0 HP (downed OR knocked out). Host heals cats in the hub.
  Events `player_downed`/`player_revived`/`player_knocked_out`. Downed bar uses health_bar_info `see_from`/`through_walls`.
  `Hud.key_for(action, seat)` = pad-aware button name. Roombas/extraction ignore `is_down` cats.
  Test: `--add_local=1 --deploy --down=1 [--revive=200 | --bleed_out=2]`; client `--join --deploy --revive=220`.
  Old: `--give=pistol --pos=-12,0,-6.5 --yaw=180 --bait_roomba=3 --frames=1500`.
  HP is 100 (Roomba 100, boss 600, bonk 34/67). Cyberpunk-style bars, all on the HUD: own bar = `HudHealthBar`
  (`Frame/Top/Health`, fed by cat_health `_process`); floating bars = `HudHealthBars` (`Frame/Bars`) for nodes in
  group `hud_health_bars` with `health_bar_info() -> {hp, max, position, show, name, boss}` (Roomba, other cats;
  boss = same floating bar, `boss_size` x bigger, out to `boss_distance`); damage numbers = `Hud.damage_number(pos, amount, crit, seat)` (`Frame/Damage`).
  Weapon rolls `damage`/`crit_chance` on the shooter and sends it in `roomba.take_hit(shooter_id, amount)`;
  Roomba `health` is synced (synchronizer, on change).
- CASH = `scripts/wallet.gd` (`Wallet.instance`, `Wallet` node): host `earn(id, n, why)` / `spend(id, n) -> bool` /
  `set_cash`; anyone `cash_of(id)`, signal `cash_changed`; draws the sewer `Scoreboard` (off: `@export show_scoreboard = false`, 12 Nov 2026). Never keep cash elsewhere.
- Stash + saves: inventories also hold `"stash"` (use `get_stash`; keep it when rewriting inventories).
  Players see it as THE LITTERBOX (code names stay "stash"; prompt `hub.stash_prompt` "STORE YOUR SHIT").
  Host `request_to_stash`/`request_from_stash` need `hub.near_stash(cat)` (litterbox on the east wall,
  `hub._build_stash`: model `models/litterbox.glb` from `tools/make_litterbox_spec.py`, groups Tray/Sand painted grey and
  tinted via `LevelKit.tint_part` with `litterbox_color`/`sand_color`; collision = invisible boxes in `LitterboxSolid`); the inventory screen (`InventoryScreen`) opens a LITTERBOX box there. ANY item is stashable (fish too).
  (`request_put_away` = paw -> backpack.) `scripts/player_profile.gd` (`Profile` node): each player saves
  their OWN cash + stash to `user://profiles/<name>.cfg`, sends it to the host on start/join
  (`_request_restore`, host validates), and saves only after `_restore_done`. Test runs use
  `user://test_profiles/` (`--fresh_profile`). Test: `--to_stash=hand:0`, `--from_stash=N`.
