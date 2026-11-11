# 4. Testing and fixing errors

[Back to the contents page](../SETUP_GUIDE.md)


**Quick check after any change** (press F5):
1. **Start menu** — the neon title over the rainy city; PLAY / SETTINGS / QUIT work, and PLAY
   leads to CHOOSE YOUR CAT, then SOLO / MULTIPLAYER.
2. **PLAY > HOST** — your cat appears down in **THE SEWERS** (the hub). Walk to Don Catleone
   (north end, under the pink sign), press E, pick **SEND ME UP TOP** — you're in the city.
3. **Walk, jump, zoomies** (WASD, Space, Shift) — W always goes where the camera faces.
4. **Car** — walk to the car, E to get in, drive, hold Space while turning to drift, E to get out.
5. **Items** — extract some fish for cash, then buy gear from Comrade Whiskers at the **Black Markitten**
   (west wall of the sewers). Hold Left Mouse to fire, G to drop, Tab for the inventory.
6. **Esc** — pause menu; SETTINGS changes apply immediately; RESUME grabs the mouse again.

**When you see red errors** (bottom panel, **Debugger > Errors** tab, or red text in **Output**):
1. **Read the first one only.** Later errors are usually caused by the first.
2. Note the **file name and line number** (e.g. `cat_player.gd:84`). Double-click the error to jump there.
3. The most common causes in this project:
   - `Node not found: "CameraPivot/SpringArm3D"` → a node was renamed or moved. Names are case-sensitive and must match the trees in this guide exactly.
   - `Invalid action name "sprint"` → the `Controls` autoload is missing; re-add `scripts/controls.gd` in Project Settings > Globals > Autoload with the name `Controls` (keep it at the top of the list).
   - `Identifier "Settings"` / `"Net"` `not declared` → that autoload is missing; re-add it the same way (`scripts/settings.gd` as `Settings`, `scripts/net.gd` as `Net`).
   - `Parse Error` / `Mixed use of tabs and spaces` → copy-paste damage. Godot scripts must indent with **tabs**. Use **Edit > Convert Indent to Tabs** in the script editor.
   - Shader errors (red text in the shader editor, objects turn pink/missing) → the error names the line; send it to me.
   - `Identifier "CatPlayer" not declared` → the editor hasn't scanned scripts yet. Close and reopen the project.
4. **Yellow warnings** are not errors — the game still runs. Ignore them for now.
5. Still stuck? Copy the **full** error text (right-click > Copy Error) plus the file/line it points to and send it to me.

### The test tool (`scripts/dev_capture.gd`)
Lets Claude (or you) run the game from a terminal, do something, print what happened and save a
screenshot, then quit. Run from inside the `Meow-City` folder:

```bash
C:\GoDot\Godot_v4.7.2-stable_win64_console.exe --path . -- --host --capture=shots/test.png --pos=0,0,6 --yaw=0 --pitch=-12
```

- Useful extras: `--deploy` (go up to the city first — without it you're in the hub),
  `--talk` (open Don's talk box), `--drive` (car view), `--grab=fish`, `--hold=shoot`,
  `--cash=500 --talk=ComradeWhiskers --shop_buy=pistol` (the shop screen), `--wait=N`,
  `--goto_dropoff_after=N` (extract), `--menu=settings`, `--scale=2` (smaller image),
  `--mouse_test` (checks mouse-look still reaches the game through the HUD screen),
  `--click_choice=N` (a real mouse click on a talk-box button), `--press_key=Tab` (a real key),
  `--heat=100` (max HEAT: the DEEP CLEAN), `--kill_roombas=3` (destroys 3 VAC-COPs: the MEGA
  VAC-COP is called in; add `--kill_bosses` to destroy bosses too), `--grab=golden_koi`,
  `--roomba=boss --bait_roomba=7` (put the boss 7 m in front of you) or `--zap_roomba=18` (kill it).
  The full list is at the top of `dev_capture.gd`.
- Test runs **use the default settings and never save**, so they can't change your settings or
  cat name. The tool switches itself off in release (exported) builds.
