# 14. Backups and undo (git + GitHub Desktop)

[Back to the contents page](../SETUP_GUIDE.md)


The project is a **git repository**: every "commit" is a saved snapshot of the whole project that
you can look at or go back to. Claude commits after each finished piece of work.

**What's left out on purpose** (see `.gitignore`): Godot's `.godot/` cache (rebuilt automatically),
`shots/` screenshots, and finished game builds. Everything else is backed up, including the
small `.uid` and `.import` files Godot makes next to scripts and images. Keep those.

### One-time: put the backup online (private)
1. Make a free account at **github.com** (Sign up).
2. Open **GitHub Desktop** (Start menu). **File > Options > Accounts > Sign in** to GitHub.com.
3. **File > Add local repository...** > Choose `C:\Users\Nathaniel\Meow-City` > **Add repository**.
4. Click **Publish repository** (top bar). Keep **"Keep this code private"** ticked. Click
   **Publish repository**.

### After that
- When GitHub Desktop shows **Push origin** with a number, click it to send the newest snapshots
  online. Do it at the end of each session.
- **History** tab (left) = every snapshot and exactly what changed.
- **Undo a bad change you haven't committed:** Changes tab, right-click the file > **Discard changes**.
- **Go back to an old version:** History tab, right-click a commit > **Revert changes in commit**
  (this adds a new "undo" snapshot, so nothing is lost). Ask Claude if unsure.
- A plain zip copy also exists from before git: `C:\Users\Nathaniel\Meow-City-backup-2026-10-24.zip`.
