# 1. Godot project settings for PS1 graphics

[Back to the contents page](../SETUP_GUIDE.md)


### Resolution and pixel scaling
Already set in `project.godot`. To see/change by hand: **Project > Project Settings**, turn on
**Advanced Settings** (top-right toggle), then:

| Setting path | Value | Why |
|---|---|---|
| Display > Window > Size > Viewport Width | `960` | Size the HUD is designed at (HUD units) |
| Display > Window > Size > Viewport Height | `720` | The screen is always 720 HUD units tall |
| Display > Window > Size > Window Width Override | `1280` | Window opens at 1280x960 (4x the game) |
| Display > Window > Size > Window Height Override | `960` | |
| Display > Window > Stretch > Mode | `canvas_items` | With UI STYLE = MODERN the HUD is drawn sharp at the real resolution |
| Display > Window > Stretch > Aspect | `keep_height` | HUD units: always 720 tall, wider on wide screens |
| Rendering > Textures > Canvas Textures > Default Texture Filter | `Nearest` | No blur |

**The 320x240 game picture is NOT a project setting any more:** the game (`main.tscn`) is drawn
into a 320x240 **SubViewport** inside `scenes/game_screen.tscn`, which blows it up with chunky
pixels, and the HUD is drawn sharp on top (§13). `scripts/ui/game_screen.gd` does the sizing.

(Players can change the resolution, fullscreen and scaling in the in-game Settings, §10. The game
is still *drawn* at 320x240 whatever the resolution; a bigger resolution just shows it bigger.
**SCALING > SHARP** zooms by whole numbers only (square pixels, maybe a black border);
**SCALING > FILL** zooms as big as fits. The resolution list lives in `scripts/settings.gd`
→ `COMMON_RESOLUTIONS`; your monitor's own size is always added as the biggest option.)

**Widescreen / ultrawide (ASPECT = WIDE, the default):** the game stays **240 pixels tall** but
gets wider to match the monitor (16:9 → ~427x240, 21:9 ultrawide → ~573x240), so the city fills
the whole screen and you see more to the sides. Same chunky pixels, no black bars. ASPECT = 4:3
puts back exact 320x240 with side bars. How it works:
- `scripts/ui/game_screen.gd` makes the game picture wider (WIDE) or keeps it 320 wide (4:3).
- `PS1Overlay` has the script `scripts/ui/ps1_overlay.gd`: it keeps every menu in a 320-wide
  column in the middle of the screen (they were designed for 320x240), and stretches their dark
  background ColorRects edge to edge. Children named in its **Full Width Children** list (Inspector)
  are skipped: `ColorDepthDither`.
- **The menus get their own layer** (like the HUD): you still edit them in `main.tscn` under
  `PS1Overlay`, laid out for 320x240, but when the game starts `game_screen.gd` moves the whole
  `PS1Overlay` out of the game picture into a layer on top (`MenuView` > `MenuViewport`). Same
  layout and sizes in both UI STYLEs (§13): PS1 = chunky pixels with the CRT over them, MODERN =
  crisp text at your monitor's real resolution, no CRT over them. (The MY CAT
  preview cat is still drawn at PS1 resolution, so it stays blocky.) While the game runs, look for
  them in the Remote tree under `GameScreen/MenuView/MenuViewport/PS1Overlay`.
- The HUD (§13) covers the game picture, whatever its shape; its labels are anchored (select one
  in `scenes/ui/hud.tscn` > Inspector > **Layout > Anchors Preset**). **When you add a HUD label,
  give it an anchor** (top-left, centre-top, etc.) or it will sit at the left on wide screens.
- The PS1 wobble grid in `psx_lit.gdshader` widens with the screen, so the wobble is the same size
  on every monitor.
- Test without an ultrawide: add `--window=1720x720` to a DevCapture run.

### Vertex jitter + affine textures — `shaders/psx_lit.gdshader`
This replaces the normal material on 3D objects. Every mesh in the game already uses it.

To put it on a **new** object:
1. Select the `MeshInstance3D` > Inspector > **Surface Material Override > 0** > **New ShaderMaterial**.
2. Click the new material > **Shader** > Load > `shaders/psx_lit.gdshader`.
3. Expand **Shader Parameters**: set **Albedo Color**, drag a texture into **Albedo Texture**,
   adjust **Uv Scale** (texture repeats).

Knobs: **Snap Resolution** — lower = more wobble (`160x120` default, `80x60` = drunk mode).
**Affine Mapping** — on/off for the texture warp. The player's **PS1 WOBBLE** setting switches
both off for every material at once (via the `psx_wobble` shader global, §10).
**Affine Fade Start / End** (metres) - the warp fades out near the camera (none closer than
Start, full strength past End), so ground right under the camera doesn't bend and slide as you
move. Defaults 3 / 9; raise both to calm it more.

> Tip: affine warping gets extreme on big flat surfaces. PS1 games fixed that by cutting floors
> into many small triangles — the city generator does the same (§7).

### Color-depth + dither overlay — `shaders/psx_post.gdshader`
A **ColorRect overlay** at the end of `PS1Overlay` in `main.tscn`. Everything drawn before it
(the 3D world) gets the PS1 colours and CRT look. The menus and the HUD do NOT: they're drawn
sharp on top of the finished picture (§13). When the game starts, `game_screen.gd` moves
`ColorDepthDither` into a new CanvasLayer called `CRT` inside the game picture (and the menus out
to the sharp layer), so it only covers the city. You still edit it here.

```
PS1Overlay (CanvasLayer)
├── Lobby, PauseMenu, SettingsMenu, CatCreator   <- moved to the sharp menu layer at start
└── ColorDepthDither (ColorRect)  <- Anchors: Full Rect, Mouse > Filter: Ignore
                                     Material: ShaderMaterial with psx_post.gdshader
```

Knobs: **Color Levels** (32 = PS1, 8 = gritty), **Dither Strength** (0 = off), plus the **CRT**
group. To see the game without it, click the eye icon next to `ColorDepthDither`.
