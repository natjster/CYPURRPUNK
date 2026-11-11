# Android, CI, icon / model / sound tool servers, trailers

(Split out of CLAUDE.md. Keep this file up to date when this system changes.)

- ANDROID (SETUP_GUIDE §17): `export_presets.cfg` preset "Android" (arm64, immersive, net + multicast permissions,
  -> `build/android/cypurrpunk.apk`); `rendering_method.mobile="forward_plus"` on purpose (Mobile renderer has no
  volumetric fog = no light pools); settings.gd skips window sizing on `OS.has_feature("mobile")`. Controller only,
  no touch controls. Export from CLI: `--headless --path . --export-debug "Android" build/android/cypurrpunk.apk`.

- CI (SETUP_GUIDE §18): `.github/workflows/build.yml` builds on every push to `main` and refreshes the rolling `latest`
  release (`CYPURRPUNK-Windows.zip`, `-Linux.zip`, `-Android.apk`; README links). Android = debug export, key from secret
  `ANDROID_DEBUG_KEYSTORE_BASE64` (throwaway key + warning if unset). A Godot upgrade must also change `GODOT_VERSION` there.
  `editor/export/convert_text_resources_to_binary=false` in project.godot is ON PURPOSE: the binary conversion dropped every
  scene's `PackedStringArray` values (NPC `lines` came out empty) in exports only. Editor runs never show this: test
  data-driven text in an export too (`--export-debug` build accepts the `-- --host --talk=` test args; add `--capture` or it never quits).

## Models + tool servers + OVERCLEAN (Phase 0, SETUP_GUIDE §20-21)
- ICONS: `tools/cypurr_icons.py` + MCP `tools/icon_mcp.py` ("cypurrpunk-icons"): a numpy rasteriser that reads .tscn primitives +
  .glb -> `ui/icons/items/<id>.png` (64px WHITE orthographic side profiles, seams/texture = darker lines; `ITEMS` table = source +
  view side/high/melee + yaw), `status/<id>.png` (32px, drawn in code), `npcs/<id>.png` (64px coloured 3/4 portraits from the
  NPC scene's `Model`, + `locked_mystery`). `python tools/cypurr_icons.py all`, then `--headless --import`.
- `.mcp.json` = two local stdio MCP servers (Python, mcp 2.x `MCPServer` with 1.x `FastMCP` fallback): `tools/model_mcp.py`
  (logic `tools/cypurr_models.py`: spec JSON -> `.bbmodel` (Blockbench 4.10 "free" format, groups inline in outliner, cubes +
  "prism" meshes + locators, embedded PNG painted by ops) -> `.glb` (group = node, locator = empty node, 16 px = 1 m, NEAREST,
  writes a minimal `.glb.import`: embedded uncompressed image, no LODs) + `inspect` (props <150 tris, chars <600, 64/128 tex))
  and `tools/sound_mcp.py` (`tools/cypurr_sound.py`: edge-tts + ffmpeg decode + numpy robot/PA/chime; cat blips; modal PS1 sfx).
  Recipes: `tools/model_specs/*.json` (`python tools/cypurr_models.py all <spec>`), `tools/sound_specs/overclean.json` (`batch`).
  `tools/` has a .gdignore. Building a model = edit the spec, rerun `all` (or user edits the .bbmodel, then `export`).
- Trailers (`trailer/`, gdignored, SETUP_GUIDE §15): `record.py` = shot list run through Movie Maker
  (`--write-movie`, temp `override.cfg` for 16:9, music muted, `--seed=1999`) using DevCapture's film camera
  (`--no_hud --cam_from/to --look_from/to --cam_follow --cam_orbit --near_beam --hold_all`); `music.py` = numpy
  synthwave (bars of 2 s); `edit.py` = ffmpeg edits -> `shots/trailer/out/`; `contact.py` = contact sheets.

TOOL SERVERS ARE OFF BY DEFAULT (usage, 11 Nov 2026): `.claude/settings.local.json` `disabledMcpjsonServers` lists all three.
For an art / sound / icon job, take that server's name out of the list (or turn it on in the app's MCP / connectors menu)
and start a new session; put it back afterwards. The Python scripts also run without the servers:
`python tools/cypurr_models.py all <spec>`, `python tools/cypurr_icons.py all`, `python tools/cypurr_sound.py ...`.
