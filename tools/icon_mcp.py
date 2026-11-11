"""CYPURRPUNK ICON STUDIO: an MCP server that lets Claude make the game's 2D icons from its 3D models.

Claude Code starts it by itself (it's listed in .mcp.json at the top of the project). You never
run it by hand. What it gives Claude:

  make_item_icon      ui/icons/items/<id>.png: an orthographic SIDE PROFILE of an item (gun, bat,
                      fish, catnip...), rendered from its real scene / .glb. White, for tinting.
  make_status_icon    ui/icons/status/<id>.png: a buff / debuff badge (sticky_paws, catnip, catdip).
  make_npc_portrait   ui/icons/npcs/<id>.png: a coloured head-and-shoulders portrait of a sewer NPC
                      (or "locked_mystery": the dark "?" silhouette).
  make_all_icons      every icon above in one go (+ an optional contact sheet to look at).
  list_icons          what can be made and what's already in ui/icons/.

All the real work is in tools/cypurr_icons.py (which also runs from the command line:
`python tools/cypurr_icons.py all`). After making icons, run Godot's import once
(`--headless --path . --import`) so the game sees the new PNGs.
Needs: pip install mcp pillow numpy
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cypurr_icons as icons  # noqa: E402

try:  # mcp 2.x
    from mcp.server.mcpserver import MCPServer as _Server
except ImportError:  # mcp 1.x
    from mcp.server.fastmcp import FastMCP as _Server

server = _Server("cypurrpunk-icons")


def _rel(path: str) -> str:
    return os.path.relpath(path, icons.PROJECT_ROOT).replace("\\", "/")


@server.tool()
def make_item_icon(item_id: str, size: int = 64) -> str:
    """Render ui/icons/items/<item_id>.png: the item's side profile (white + grey detail lines on
    a clear background, crisp pixel edges). item_id = one of the ids in list_icons (pistol,
    tommy_gun, neon_bat, sardine, golden_koi, catdip...). The camera for each item (side view,
    from above, laid-down melee) is in ITEMS at the top of tools/cypurr_icons.py."""
    if item_id not in icons.ITEMS:
        return "Unknown item %r. Known: %s" % (item_id, ", ".join(icons.ITEMS))
    return "Saved " + _rel(icons.make_item_icon(item_id, size=size))


@server.tool()
def make_status_icon(status_id: str, size: int = 32) -> str:
    """Draw ui/icons/status/<status_id>.png (white badge art): sticky_paws, catnip or catdip."""
    if status_id not in icons.STATUS:
        return "Unknown status %r. Known: %s" % (status_id, ", ".join(icons.STATUS))
    return "Saved " + _rel(icons.make_status_icon(status_id, size=size))


@server.tool()
def make_npc_portrait(npc_id: str, size: int = 64) -> str:
    """Render ui/icons/npcs/<npc_id>.png: a coloured three-quarter head-and-shoulders portrait from
    the NPC's scene (scenes/npcs/<npc_id>.tscn). npc_id = "locked_mystery" makes the dark "?" one."""
    if npc_id == "locked_mystery":
        return "Saved " + _rel(icons.make_locked_mystery(size=size))
    if npc_id not in icons.NPCS:
        return "Unknown NPC %r. Known: %s, locked_mystery" % (npc_id, ", ".join(icons.NPCS))
    return "Saved " + _rel(icons.make_npc_portrait(npc_id, size=size))


@server.tool()
def make_all_icons(contact_sheet: str = "") -> str:
    """Make every item, status and NPC icon. contact_sheet = optional PNG path for a sheet of all
    of them blown up on an ocean-blue background (handy to look at)."""
    made = icons.make_all()
    lines = ["Made %d icons:" % len(made)] + ["  " + _rel(p) for p in made]
    if contact_sheet:
        lines.append("Sheet: " + icons.contact_sheet(made, contact_sheet))
    lines.append("Now run Godot's import (--headless --path . --import) so the game picks them up.")
    return "\n".join(lines)


@server.tool()
def list_icons() -> str:
    """What can be made (items / status / NPCs) and what already exists in ui/icons/."""
    lines = ["Items: " + ", ".join(icons.ITEMS), "Status: " + ", ".join(icons.STATUS),
             "NPCs: " + ", ".join(icons.NPCS) + ", locked_mystery", "Existing:"]
    for sub in ("items", "status", "npcs"):
        folder = os.path.join(icons.ICON_DIR, sub)
        if os.path.isdir(folder):
            lines.append("  %s/: %s" % (sub, ", ".join(sorted(f for f in os.listdir(folder) if f.endswith(".png")))))
    return "\n".join(lines)


if __name__ == "__main__":
    server.run()
