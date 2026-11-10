"""CYPURRPUNK MODEL SHOP: an MCP server that lets Claude make and edit Blockbench models.

Claude Code starts it by itself (it's listed in .mcp.json at the top of the project). You never
run it by hand. What it gives Claude:

  create_or_edit_bbmodel   write / change a Blockbench project in models/blockbench/<name>.bbmodel
                           (boxes, n-sided cans and cones, free-form "poly" wedges / slopes / fins,
                           groups = bones, markers, and a painted
                           64x64 or 128x128 pixel-art texture). Double-click the file to open it in
                           Blockbench and tweak it yourself.
  export_bbmodel_to_glb    turn a .bbmodel into models/<name>.glb for Godot (no Blockbench needed)
  inspect_model            triangle count, texture size and group names, checked against the
                           ROADMAP.md style rules (props < 150 triangles, characters < 600,
                           vehicles < 500)
  list_models              what's in models/ and models/blockbench/

All the real work is in tools/cypurr_models.py (which also runs from the command line).
Needs: pip install mcp pillow
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cypurr_models as models  # noqa: E402

try:  # mcp 2.x
    from mcp.server.mcpserver import MCPServer as _Server
except ImportError:  # mcp 1.x
    from mcp.server.fastmcp import FastMCP as _Server

server = _Server("cypurrpunk-models")


def _resolve(path: str, folder: str, ext: str) -> str:
    """'trash_bin' / 'trash_bin.bbmodel' / 'models/blockbench/trash_bin.bbmodel' / res://... -> full path."""
    if path.startswith("res://"):
        path = os.path.join(models.PROJECT_ROOT, path[len("res://"):])
    if not os.path.isabs(path) and not os.path.dirname(path):
        path = os.path.join(folder, path if path.endswith(ext) else path + ext)
    elif not os.path.isabs(path):
        path = os.path.join(models.PROJECT_ROOT, path)
    return os.path.normpath(path)


@server.tool()
def create_or_edit_bbmodel(name: str, spec: str, replace: bool = True) -> str:
    """Create or edit the Blockbench project models/blockbench/<name>.bbmodel.

    spec = JSON text with any of:
      kind          "prop" (default), "character" or "vehicle" (for the triangle check)
      texture_size  64 (props) or 128 (characters, vehicles)
      background    starting colour of a new texture, e.g. "#5d6b66"
      paint         list of paint ops on the texture, in order. Each has "op":
                    fill{rect,color} noise{rect,amount,spread[,color]} stripes{rect,colors,width,direction}
                    gradient{rect,top,bottom} spots{rect,color,count,size} text{pos,text,color,scale,spacing,worn}
                    line{from,to,color} pixels{list:[[x,y,color]]} edge{rect,color} comment{note}
                    rect = [x1,y1,x2,y2] (x2/y2 exclusive); colours "#rrggbb" or "#rrggbbaa".
      seed          random seed for noise/spots
      groups        [{name, origin:[x,y,z], rotation, parent}]  (bones; Godot gets a node per group)
      elements      [{type, name, group, ...}] where type is
                      cube:    from, to, [origin, rotation], UVs: faces{north..down: rect} or all / sides / top / bottom
                      prism:   sides, center (bottom middle), height, radius | radius_bottom+radius_top,
                               [twist, origin, rotation], side_uv (wraps round), top_uv, bottom_uv
                      poly:    vertices {name: [x,y,z]}, faces [{v: [3 or 4 names], uv: rect}], [uv (default
                               rect), outward_from [x,y,z] (only for a lone flat piece), origin, rotation].
                               Any shape from corner points (a car's wedge nose, a sloped roof, a fin).
                               Corner order doesn't matter: faces are turned outward by themselves, and
                               the rect is laid flat on each face from the side it faces most.
                      locator: position (an invisible marker, e.g. "hat")
      remove        [names] of elements/groups to delete (when editing)
    Units: 16 px = 1 metre, Y up, the front faces north (-Z).
    replace = true starts a fresh file; false edits the existing one (same-name elements are
    replaced, paint ops are painted on top of the current texture).
    Returns the inspection report. Then call export_bbmodel_to_glb to update the game's .glb."""
    data = json.loads(spec) if isinstance(spec, str) else dict(spec)
    data["name"] = name
    path = models.build_bbmodel(data, _resolve(name, models.BLOCKBENCH_DIR, ".bbmodel"), replace=replace)
    report = models.inspect_model(path, data.get("kind", "prop"))
    return "Saved %s\n%s" % (os.path.relpath(path, models.PROJECT_ROOT), models.format_report(report))


@server.tool()
def export_bbmodel_to_glb(bbmodel: str, glb_name: str = "", kind: str = "prop") -> str:
    """Export a .bbmodel (name or path) to models/<glb_name or same name>.glb for Godot.
    Groups become nodes with the same names, locators become empty marker nodes, textures are
    embedded with nearest (crisp pixel) filtering. kind = "prop", "character" or "vehicle" (for the check).
    In Godot, load it with LevelKit.instantiate_model("res://models/<name>.glb") to get the PS1 look."""
    src = _resolve(bbmodel, models.BLOCKBENCH_DIR, ".bbmodel")
    out = _resolve(glb_name, models.GLB_DIR, ".glb") if glb_name else None
    glb = models.export_glb(src, out)
    return "Exported %s\n%s" % (os.path.relpath(glb, models.PROJECT_ROOT), models.format_report(models.inspect_model(glb, kind)))


@server.tool()
def inspect_model(path: str, kind: str = "prop") -> str:
    """Report a .bbmodel or .glb: triangle count (props must be under 150, characters under 600),
    texture sizes (64x64 or 128x128) and the group/bone + marker tree."""
    if path.endswith(".glb") or path.startswith("res://"):
        full = _resolve(path, models.GLB_DIR, ".glb")
    else:
        full = _resolve(path, models.BLOCKBENCH_DIR, ".bbmodel")
    return models.format_report(models.inspect_model(full, kind))


@server.tool()
def list_models() -> str:
    """List the Blockbench projects (models/blockbench/) and game models (models/*.glb)."""
    lines = ["Blockbench projects (models/blockbench/):"]
    if os.path.isdir(models.BLOCKBENCH_DIR):
        lines += ["  " + f for f in sorted(os.listdir(models.BLOCKBENCH_DIR)) if f.endswith(".bbmodel")]
    lines.append("Game models (res://models/):")
    if os.path.isdir(models.GLB_DIR):
        lines += ["  " + f for f in sorted(os.listdir(models.GLB_DIR)) if f.endswith(".glb")]
    specs = os.path.join(os.path.dirname(os.path.abspath(__file__)), "model_specs")
    lines.append("Recipes (tools/model_specs/, rebuild with: python tools/cypurr_models.py all <file>):")
    if os.path.isdir(specs):
        lines += ["  " + f for f in sorted(os.listdir(specs)) if f.endswith(".json")]
    return "\n".join(lines)


if __name__ == "__main__":
    server.run()
