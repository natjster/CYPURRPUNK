# 17. Playing on an Android phone (with a controller)

[Back to the contents page](../SETUP_GUIDE.md)


The game runs on an Android phone with a **Bluetooth controller** (Xbox, PlayStation...). There are
no touch controls yet. Touching the screen only clicks menu buttons, like a mouse would.

### What's already set up in the project
- **Project > Export...** has an **Android** preset (`export_presets.cfg`): 64-bit phones only,
  full screen ("immersive mode"), app name CYPURRPUNK, package `com.cypurrpunk.game`, and the
  network permissions online play needs (Internet, Wi-Fi state, and "Wi-Fi multicast", which lets the
  MULTIPLAYER screen find games on your Wi-Fi). Builds go to `build/android/` (not backed up by git).
- **Project Settings > Rendering > Renderer > Rendering Method (Mobile)** = **forward_plus**, the
  same renderer as on PC. The usual phone renderer ("mobile") has **no volumetric fog**, so the
  glowing light pools around lamps, signs and Roombas would vanish. Newer phones (Galaxy S25 and
  similar) handle forward_plus easily because the game only draws 320x240 pixels. If an older phone
  crashes or shows a black screen, change it back to **mobile** (the game still runs, just without fog).
- **Project Settings > Display > Window > Handheld > Orientation** = **Sensor Landscape** (sideways, either way up).
- **Project Settings > Rendering > Textures > VRAM Compression > Import ETC2 ASTC** = on (phones need it).
- On a phone the game skips the window size / fullscreen settings (`scripts/settings.gd` `apply()`).

### One-time setup on your PC
**Already done on this PC** (2026-10-27): the templates, the Android SDK (command-line tools +
platform-tools, build-tools 36.1.0, Android 36) and Java 17. Only needed again on a new computer.
The game has no icon yet, so the phone shows Godot's robot icon: set one in
**Project Settings > Application > Config > Icon** (a square PNG, 192x192 or bigger).

1. **Export templates** (the ready-made Godot engine for phones, about 1 GB): in Godot,
   **Editor > Manage Export Templates... > Download and Install**.
2. **Android SDK** (Google's tools that pack and install apps): the easiest way is to install
   **Android Studio** from developer.android.com/studio. Open it once and let the setup wizard
   install the SDK. It goes to `C:\Users\Nathaniel\AppData\Local\Android\Sdk`, which Godot is already
   pointed at. (You never need to open Android Studio again after that.)
3. **Java 17**: in Godot, **Editor > Editor Settings > Export > Android > Java SDK Path** =
   `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.8-hotspot` (it was set to Java 11, which is too old).
   While you're there, check **Android SDK Path** = the folder from step 2.

### One-time setup on your phone
1. **Settings > About phone > Software information**, tap **Build number** 7 times (it says
   "Developer mode has been turned on").
2. **Settings > Developer options > USB debugging** = on.
3. Plug the phone into the PC with a USB cable and tap **Allow** on the phone's "Allow USB debugging?" popup.
4. Pair the controller: **Settings > Connections > Bluetooth**, then put the controller in pairing mode.

### Putting the game on the phone
- **Quickest (phone plugged in):** a small **Android icon** appears at the top right of the Godot
  editor (next to the play buttons). Click it: Godot builds the game, installs it and starts it on the phone.
- **As a file:** **Project > Export... > Android > Export Project** (untick "Export With Debug" for
  a smaller, faster build) and save `build/android/cypurrpunk.apk`. Copy it to the phone and tap it
  to install (the phone asks once to allow installing apps from that place).

### Playing
- Press a button on the controller in the start menu: the controller becomes player 1's, exactly like on PC.
- **Online co-op with your PC:** both on the same Wi-Fi, host on the PC and join from the phone
  (or the other way round) on the MULTIPLAYER screen. If the game doesn't show up in the list, type the
  host's address instead.
- The first minute can stutter a little while the phone prepares the graphics for the first time.
- Your phone keeps its own saves (cats, cash, stash). They don't move between PC and phone.

### Known limitations (later work)
- No touch controls (on-screen stick and buttons). This is the big one if you want to play without a controller.
- Not tested on slower phones. If one struggles: turn **VOLUMETRIC FOG** off in **SETTINGS**, or
  use the **mobile** renderer (above).
