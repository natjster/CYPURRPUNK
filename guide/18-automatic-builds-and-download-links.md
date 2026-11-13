# 18. Automatic builds and download links (Windows, Linux, Android)

[Back to the contents page](../SETUP_GUIDE.md)


Every time you push to `main` with GitHub Desktop, GitHub builds all three versions by itself and
puts them on the download page. You don't need Godot open, and your PC can be off.

### Where the downloads are
- **Front page of the project:** https://github.com/natjster/CYPURRPUNK has one-click download links.
  They always give the newest build, so send players that page.
- **Direct links:**
  - https://github.com/natjster/CYPURRPUNK/releases/latest/download/CYPURRPUNK-Windows.zip
  - https://github.com/natjster/CYPURRPUNK/releases/latest/download/CYPURRPUNK-Linux.zip
  - https://github.com/natjster/CYPURRPUNK/releases/latest/download/CYPURRPUNK-Android.apk
- **What changed:** the release page shows the date and your commit message for the newest build.

### Watching a build
- The badge at the top of the front page shows if the last build worked.
- For the details, open the **Actions** tab on GitHub. A yellow dot means building, a green tick
  means done, and a red cross means something failed. Click a run to read why.
- If you push again during a build, the old build stops and the new one starts.
- A failed build changes nothing: players keep the last good version.
- To rebuild without a new push: **Actions > Build > Run workflow**.

### One-time step: keep Android updates working
A phone only installs an update if it's signed with the same key as the version already on it. The
key is kept in a private GitHub secret so every build uses the same one. To add it:
1. Open `build/ci/keystore-base64.txt` in Notepad and copy everything in it.
2. On GitHub: **Settings > Secrets and variables > Actions > New repository secret**.
3. Name = `ANDROID_DEBUG_KEYSTORE_BASE64`, Secret = paste, then **Add secret**.
4. Keep a backup of `build/ci/cypurrpunk-debug.keystore` somewhere safe. Git doesn't back it up.

Until the secret is there, each build gets a new throwaway key. Those APKs install fine, but players
must uninstall the old version first, which also wipes their phone saves. The Actions page shows a
yellow warning when this happens.

### When you update Godot
Open `.github/workflows/build.yml` and change `GODOT_VERSION` (and `GODOT_EDITOR_SERIES`) near the
top to match. If you don't, GitHub keeps building with the old version.

### What runs where
- `.github/workflows/build.yml` is the build recipe GitHub follows.
- `export_presets.cfg` has the **Windows Desktop**, **Linux** and **Android** presets. Windows and
  Linux are packed into one file each, with no separate `.pck`.
- The Android file is a debug build, the same as "Export With Debug" in Godot.
- **Leave this setting alone:** `project.godot` has `export/convert_text_resources_to_binary=false`
  (**Project Settings > Editor > Export > Convert Text Resources to Binary** = off). With it on,
  exported games lost what NPCs say and they only said "...", even though it looked fine in the editor.

### Making a Windows build yourself
**Project > Export... > Windows Desktop > Export Project...**, or from PowerShell:
```powershell
& "C:\GoDot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" build/windows/CYPURRPUNK.exe
```

### Making a Linux build yourself

**Project > Export...** has a **Linux** preset (`export_presets.cfg`) set up to pack the whole game into a single file (`build/linux/cypurrpunk.x86_64`, with `Embed PCK` switched on so there is no extra `.pck` file to lose).

- **In Godot:** **Project > Export... > Linux > Export Project...**, untick **Export With Debug**, and click **Save**.
- **Or from PowerShell:**
  ```powershell
  & "C:\GoDot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Linux" "build/linux/cypurrpunk.x86_64"
  ```
- **Running on Linux:** unzip/download `cypurrpunk.x86_64`. If double-clicking doesn't launch it right away, right-click the file > **Properties > Permissions > Allow executing file as program** (or run `chmod +x cypurrpunk.x86_64 && ./cypurrpunk.x86_64` in a terminal).
