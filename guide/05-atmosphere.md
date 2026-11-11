# 5. Atmosphere (rainy neon night)

[Back to the contents page](../SETUP_GUIDE.md)


Built to match the references in your *Game Styling* folder: thick haze, glowing light pools in
the dark, flat-shaded low-poly, dithering and a CRT finish.

### Where each effect lives and its main knobs

| Effect | Where | Knobs (Inspector) |
|---|---|---|
| Fog + haze | `main.tscn` > **WorldEnvironment** > Environment > **Fog** / **Volumetric Fog** | Density (higher = thicker). Volumetric fog is what makes light beams visible in the air. (Players can switch volumetric fog off in Settings.) |
| Glow / bloom | WorldEnvironment > Environment > **Glow** | Intensity, Bloom (soft haze over everything), HDR Threshold (lower = more things glow) |
| Darkness level | WorldEnvironment > Environment > **Ambient Light** > Energy | Raise if the city is too dark to play |
| Glowing objects | any material using `psx_lit` > **Emission Color / Emission Energy** | 0 = off, 3-6 = neon |
| Wet street shine | Street material > **Specular / Roughness** | Specular 0 = dry. Roughness lower = sharper reflections |
| Flat shading | any `psx_lit` material > **Flat Shading** | Off = smooth shading |
| Street lamps | `scenes/props/street_lamp.tscn` > **LightCone** | Energy, Spot Range, Spot Angle, color |
| Headlights | `getaway_car.tscn` > Model > **HeadlightBeam** | Energy, Spot Range |
| Rain | `scenes/props/rain.tscn` | **Amount** (drop count), drop size on the mesh, speed in Process Material > Initial Velocity. Hide the Rain node in `main.tscn` to stop it. |
| CRT | `main.tscn` > PS1Overlay > ColorDepthDither > Material > Shader Parameters > **CRT** | Curvature, Chromatic Aberration, Scanline, Vignette, Noise (0 = off). These are the "full strength" values; the player's CRT TV LOOK setting scales them down. |

**About the CRT scanlines:** the whole game (including the CRT overlay) renders at 320x240, so the
scanlines are fat (one per game pixel row) rather than the thin lines of a real TV. That's a
deliberate trade-off to keep the setup simple. Real thin scanlines would mean restructuring the
scene so the CRT runs at full window size. Doable later if you want it.
