"""CYPURRPUNK icon kit: crisp 2D HUD / menu icons made straight from the game's own 3D models.

Used by tools/icon_mcp.py (the MCP server Claude talks to) and from the command line:

    python tools/cypurr_icons.py all                 (every icon below, into ui/icons/)
    python tools/cypurr_icons.py item pistol         (one item's side profile)
    python tools/cypurr_icons.py npc don_catleone    (one NPC portrait)
    python tools/cypurr_icons.py status              (the buff / debuff badges)

WHAT IT MAKES (all PNG with hard pixel edges, transparent background):
  ui/icons/items/<id>.png   a SIDE PROFILE of every item, rendered with an orthographic (flat,
                            no perspective) camera from the item's real scene (scenes/items/*.tscn,
                            which pulls in models/*.glb for the guns). WHITE / grey only, so Godot
                            can colour it with `modulate` (the HUD makes guns ocean-blue and heats
                            them to red). Darker lines inside = where two parts meet (barrel / grip /
                            coil / tank) and the painted texture's darker areas.
  ui/icons/status/<id>.png  white buff / debuff badges drawn in code (sticky_paws, catnip, catdip).
  ui/icons/npcs/<id>.png    COLOURED head-and-shoulders portraits of every sewer NPC, rendered from
                            their scenes (scenes/npcs/*.tscn: fur, eyes, hats, cigars...), plus
                            locked_mystery.png (a dark cat silhouette with a big "?").

HOW THE RENDERER WORKS (no Blender, no Godot needed): it reads the .tscn files the way Godot does
(sub-resources = BoxMesh / SphereMesh / CylinderMesh / CapsuleMesh / PrismMesh / TorusMesh with their
sizes, nodes = position / rotation / scale, `instance=` = another scene or a .glb), builds the same
triangles, and fills them into a tiny picture with a depth buffer, 4x4 samples per pixel. A pixel is
either fully solid or fully clear (no blurry edges), so the icon stays sharp when the HUD blows it
up with nearest filtering.

Only needs Python + numpy + Pillow (already in tools/requirements.txt).
"""
from __future__ import annotations

import json
import math
import os
import re
import struct
import sys
import io

import numpy as np
from PIL import Image, ImageDraw

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(PROJECT_ROOT, "ui", "icons")

# How each item is looked at. "source" = the scene (res:// path), "view" = which camera:
#   side      orthographic side view, the nose / barrel (-Z) pointing RIGHT (guns, fish)
#   high      the same side, from 35 degrees above (round tins and pouches read better)
#   melee     side view of a model that stands up along +Y, laid down pointing right
# "spin" = extra 2D turn in degrees (anticlockwise) after projecting. "yaw" = walk the camera round
# the item first (degrees round the up axis), for things that are thin from the side (a box).
ITEMS = {
    # Held items (weapons + quick-use)
    # Melee scenes tip their Model node back 0.7 rad (~40 deg) for the in-paw hold pose; that tilt
    # showed up as a diagonal icon, so spin -40.1 turns it back to lying flat, tip to the right.
    "neon_bat":          {"source": "res://scenes/items/neon_bat.tscn", "view": "melee", "spin": -40.1},
    "frozen_tuna":       {"source": "res://scenes/items/frozen_tuna.tscn", "view": "melee", "spin": -40.1},
    "pistol":            {"source": "res://scenes/items/pistol.tscn", "view": "side"},
    "hairball_blaster":  {"source": "res://scenes/items/hairball_blaster.tscn", "view": "side"},
    "red_dot":           {"source": "res://scenes/items/red_dot.tscn", "view": "side"},
    "tommy_gun":         {"source": "res://scenes/items/tommy_gun.tscn", "view": "side"},
    "yarn_zooka":        {"source": "res://scenes/items/yarn_zooka.tscn", "view": "side"},
    "cucumber_launcher": {"source": "res://scenes/items/cucumber_launcher.tscn", "view": "side"},
    "catnip":            {"source": "res://scenes/items/catnip.tscn", "view": "high"},
    "catdip":            {"source": "res://scenes/items/catdip.tscn", "view": "high"},
    # Loot
    "sardine":           {"source": "res://scenes/items/sardine.tscn", "view": "side"},
    "fish":              {"source": "res://scenes/items/fish.tscn", "view": "side"},
    "fresh_catch":       {"source": "res://scenes/items/fish.tscn", "view": "side", "badge": "sparkle"},
    "gourmet_tuna":      {"source": "res://scenes/items/tuna_can.tscn", "view": "high"},
    "catnip_treats":     {"source": "res://scenes/items/catnip_treats.tscn", "view": "high", "yaw": 55},
    "golden_koi":        {"source": "res://scenes/items/golden_koi.tscn", "view": "side", "badge": "crown"},
    "scrap":             {"source": "res://scenes/items/scrap.tscn", "view": "high"},
    "electronics":       {"source": "res://scenes/items/electronics.tscn", "view": "high"},
}

NPCS = {
    # Hub (gang 0: CATLEONE)
    "don_catleone": "res://scenes/npcs/don_catleone.tscn",
    "comrade_whiskers": "res://scenes/npcs/comrade_whiskers.tscn",
    "lil_mittens": "res://scenes/npcs/lil_mittens.tscn",
    "paulie_no_brooms": "res://scenes/npcs/paulie_no_brooms.tscn",
    "sal_the_slapper": "res://scenes/npcs/sal_the_slapper.tscn",
    "nonna_catleone": "res://scenes/npcs/nonna_catleone.tscn",
    "frankie_espresso": "res://scenes/npcs/frankie_espresso.tscn",
    # GangHub (gang 1: BURROW)
    "pawnie": "res://scenes/npcs/pawnie.tscn",
    "clawd": "res://scenes/npcs/clawd.tscn",
    "billy_the_kitten": "res://scenes/npcs/billy_the_kitten.tscn",
    "bumper_car_benny": "res://scenes/npcs/bumper_car_benny.tscn",
    "calamity_clara": "res://scenes/npcs/calamity_clara.tscn",
    "gold_tooth_gus": "res://scenes/npcs/gold_tooth_gus.tscn",
    "jittery_jax": "res://scenes/npcs/jittery_jax.tscn",
}

ITEM_SIZE = 64        # item icons: 64x64 px
STATUS_SIZE = 32      # buff badges: 32x32 px
PORTRAIT_SIZE = 64    # NPC portraits: 64x64 px
SAMPLES = 4           # 4x4 samples per pixel (only to decide solid / clear and the average colour)


# =====================================================================================
# Small maths helpers
# =====================================================================================

def _rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]], float)


def _rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], float)


def _rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], float)


def _godot_euler(v):
    """Godot's default rotation order (YXZ): Z first, then X, then Y."""
    return _rot_y(v[1]) @ _rot_x(v[0]) @ _rot_z(v[2])


def _transform(position=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1)):
    m = np.eye(4)
    m[:3, :3] = _godot_euler(rotation) @ np.diag(scale)
    m[:3, 3] = position
    return m


def _quat_matrix(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])


def res_path(path: str) -> str:
    if path.startswith("res://"):
        return os.path.join(PROJECT_ROOT, path[len("res://"):])
    return path if os.path.isabs(path) else os.path.join(PROJECT_ROOT, path)


# =====================================================================================
# A "part" = one mesh piece: triangles in world space + its colour / texture
# =====================================================================================

class Part:
    def __init__(self, name, verts, tris, color=(1, 1, 1), uvs=None, texture=None, glow=0.0):
        self.name = name          # node name (Body, HeatCoil, Head...)
        self.verts = verts        # (N, 3) world positions
        self.tris = tris          # (M, 3) vertex indices
        self.color = np.array(color[:3], float)
        self.uvs = uvs            # (N, 2) or None
        self.texture = texture    # (H, W, 4) float 0..1 or None
        self.glow = glow          # emission energy: glowing parts stay bright in portraits


# --- Godot's primitive meshes (same shapes and default sizes as the engine) ---

def _ring(radius, y, n, phase=0.0):
    return [(radius * math.sin(2 * math.pi * i / n + phase), y, radius * math.cos(2 * math.pi * i / n + phase)) for i in range(n)]


def _lathe(profile, n):
    """profile = [(radius, y), ...] bottom to top -> closed-ish surface of revolution."""
    verts, tris = [], []
    for radius, y in profile:
        verts += _ring(radius, y, n)
    for k in range(len(profile) - 1):
        a0, b0 = k * n, (k + 1) * n
        for i in range(n):
            j = (i + 1) % n
            tris += [(a0 + i, a0 + j, b0 + j), (a0 + i, b0 + j, b0 + i)]
    # caps
    bottom = len(verts)
    verts.append((0, profile[0][1], 0))
    top = len(verts)
    verts.append((0, profile[-1][1], 0))
    last = (len(profile) - 1) * n
    for i in range(n):
        j = (i + 1) % n
        tris.append((bottom, j, i))
        tris.append((top, last + i, last + j))
    return np.array(verts, float), np.array(tris, int)


def mesh_box(p):
    sx, sy, sz = p.get("size", (1, 1, 1))
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    v = np.array([(x, y, z) for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)], float)
    quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    t = []
    for a, b, c, d in quads:
        t += [(a, b, c), (a, c, d)]
    return v, np.array(t, int)


def mesh_sphere(p):
    r = p.get("radius", 0.5)
    h = p.get("height", 1.0)
    n = max(3, int(p.get("radial_segments", 64)))
    rings = max(1, int(p.get("rings", 32)))
    hemi = p.get("is_hemisphere", False)
    profile = []
    for k in range(rings + 2):
        t = k / (rings + 1)
        ang = (t * 0.5 if hemi else t) * math.pi  # 0 = bottom
        if hemi:
            ang = math.pi / 2 + t * math.pi / 2
        profile.append((r * math.sin(ang), -math.cos(ang) * h / 2))
    return _lathe(profile, n)


def mesh_cylinder(p):
    h = p.get("height", 2.0)
    n = max(3, int(p.get("radial_segments", 64)))
    return _lathe([(p.get("bottom_radius", 0.5), -h / 2), (p.get("top_radius", 0.5), h / 2)], n)


def mesh_capsule(p):
    r = p.get("radius", 0.5)
    h = p.get("height", 2.0)
    n = max(3, int(p.get("radial_segments", 64)))
    rings = max(2, int(p.get("rings", 8)))
    profile = []
    for k in range(rings + 1):  # bottom half-sphere
        a = math.pi / 2 * k / rings
        profile.append((r * math.sin(a), -h / 2 + r - r * math.cos(a)))
    for k in range(rings + 1):  # top half-sphere
        a = math.pi / 2 + math.pi / 2 * k / rings
        profile.append((r * math.sin(a), h / 2 - r - r * math.cos(a)))
    return _lathe(profile, n)


def mesh_prism(p):
    sx, sy, sz = p.get("size", (1, 1, 1))
    ltr = p.get("left_to_right", 0.5)
    apex = -sx / 2 + ltr * sx
    pts = [(-sx / 2, -sy / 2), (sx / 2, -sy / 2), (apex, sy / 2)]
    v = np.array([(x, y, z) for z in (-sz / 2, sz / 2) for x, y in pts], float)
    t = [(0, 1, 2), (3, 5, 4), (0, 3, 4), (0, 4, 1), (1, 4, 5), (1, 5, 2), (2, 5, 3), (2, 3, 0)]
    return v, np.array(t, int)


def mesh_torus(p):
    inner = p.get("inner_radius", 0.5)
    outer = p.get("outer_radius", 1.0)
    rings = max(3, min(48, int(p.get("rings", 64))))
    segs = max(3, min(24, int(p.get("ring_segments", 32))))
    centre, tube = (outer + inner) / 2, (outer - inner) / 2
    v, t = [], []
    for i in range(rings):
        a = 2 * math.pi * i / rings
        for j in range(segs):
            b = 2 * math.pi * j / segs
            rr = centre + tube * math.cos(b)
            v.append((rr * math.cos(a), tube * math.sin(b), rr * math.sin(a)))
    for i in range(rings):
        for j in range(segs):
            a, b = i * segs + j, ((i + 1) % rings) * segs + j
            c, d = ((i + 1) % rings) * segs + (j + 1) % segs, i * segs + (j + 1) % segs
            t += [(a, b, c), (a, c, d)]
    return np.array(v, float), np.array(t, int)


PRIMITIVES = {"BoxMesh": mesh_box, "SphereMesh": mesh_sphere, "CylinderMesh": mesh_cylinder,
              "CapsuleMesh": mesh_capsule, "PrismMesh": mesh_prism, "TorusMesh": mesh_torus}


# =====================================================================================
# Reading .glb (our model kit's exports) and .tscn (hand-written scenes)
# =====================================================================================

def load_glb(path: str, world: np.ndarray) -> list:
    data = open(path, "rb").read()
    length = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + length])
    off = 20 + length
    blen = struct.unpack("<I", data[off:off + 4])[0]
    binary = data[off + 8:off + 8 + blen]

    def accessor(i):
        a = gltf["accessors"][i]
        view = gltf["bufferViews"][a["bufferView"]]
        kinds = {5126: ("<f4", 4), 5125: ("<u4", 4), 5123: ("<u2", 2), 5121: ("u1", 1)}
        dtype, size = kinds[a["componentType"]]
        comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
        start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = view.get("byteStride", size * comps)
        raw = np.frombuffer(binary, dtype=np.uint8, count=stride * (a["count"] - 1) + size * comps, offset=start)
        rows = [np.frombuffer(raw[k * stride:k * stride + size * comps].tobytes(), dtype=dtype) for k in range(a["count"])]
        return np.array(rows).astype(float) if comps > 1 else np.array(rows).reshape(-1)

    images = []
    for img in gltf.get("images", []):
        view = gltf["bufferViews"][img["bufferView"]]
        raw = binary[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]]
        images.append(np.asarray(Image.open(io.BytesIO(raw)).convert("RGBA"), float) / 255.0)

    def material(i):
        if i is None:
            return (1, 1, 1), None
        m = gltf["materials"][i].get("pbrMetallicRoughness", {})
        color = m.get("baseColorFactor", [1, 1, 1, 1])
        tex = m.get("baseColorTexture")
        image = None
        if tex is not None:
            image = images[gltf["textures"][tex["index"]]["source"]]
        return color, image

    parts = []

    def walk(index, parent):
        node = gltf["nodes"][index]
        m = np.eye(4)
        if "matrix" in node:
            m = np.array(node["matrix"], float).reshape(4, 4).T
        else:
            m[:3, :3] = _quat_matrix(node.get("rotation", [0, 0, 0, 1])) @ np.diag(node.get("scale", [1, 1, 1]))
            m[:3, 3] = node.get("translation", [0, 0, 0])
        here = parent @ m
        if "mesh" in node:
            for prim in gltf["meshes"][node["mesh"]]["primitives"]:
                pos = accessor(prim["attributes"]["POSITION"])
                idx = accessor(prim["indices"]).astype(int).reshape(-1, 3)
                uv = accessor(prim["attributes"]["TEXCOORD_0"]) if "TEXCOORD_0" in prim["attributes"] else None
                color, image = material(prim.get("material"))
                world_pos = (here[:3, :3] @ pos.T).T + here[:3, 3]
                parts.append(Part(node.get("name", "mesh"), world_pos, idx, color, uv, image))
        for child in node.get("children", []):
            walk(child, here)

    for root in gltf["scenes"][gltf.get("scene", 0)]["nodes"]:
        walk(root, world)
    return parts


_VALUE_RE = re.compile(r'^(\w+)\((.*)\)$')


def _parse_value(text: str):
    text = text.strip()
    if text in ("true", "false"):
        return text == "true"
    m = _VALUE_RE.match(text)
    if m:
        kind, inner = m.groups()
        if kind in ("SubResource", "ExtResource"):
            return (kind, inner.strip().strip('"'))
        if kind in ("Vector3", "Color", "Vector2"):
            return tuple(float(x) for x in inner.split(","))
        return (kind, inner)
    try:
        return float(text)
    except ValueError:
        return text.strip('"')


def parse_tscn(path: str) -> dict:
    """-> {"ext": {id: path}, "sub": {id: {"type", props}}, "nodes": [{name, type, parent, instance, props}]}"""
    ext, sub, nodes = {}, {}, []
    current = None
    for raw in open(path, encoding="utf-8").read().splitlines():
        line = raw.strip()
        if line.startswith("["):
            head = dict(re.findall(r'(\w+)="([^"]*)"', line))
            inst = re.search(r'instance=ExtResource\("([^"]+)"\)', line)
            if line.startswith("[ext_resource"):
                ext[head.get("id")] = head.get("path")
                current = None
            elif line.startswith("[sub_resource"):
                current = {"type": head.get("type"), "props": {}}
                sub[head.get("id")] = current
            elif line.startswith("[node"):
                current = {"name": head.get("name"), "type": head.get("type"), "parent": head.get("parent"),
                           "instance": inst.group(1) if inst else None, "props": {}}
                nodes.append(current)
            else:
                current = None
            continue
        if current is not None and " = " in line:
            key, value = line.split(" = ", 1)
            current["props"][key.strip()] = _parse_value(value)
    return {"ext": ext, "sub": sub, "nodes": nodes}


def load_tscn(path: str, world: np.ndarray, root_only: str = "") -> list:
    """Every visible mesh in a .tscn (and the scenes / .glb files it instances), in world space.
    root_only = only that node's subtree (e.g. "Model": the NPC's body, not its name tag)."""
    scene = parse_tscn(path)
    parts = []
    matrices = {}
    hidden = set()
    for node in scene["nodes"]:
        parent = node["parent"]
        key = "." if parent is None else (node["name"] if parent == "." else parent + "/" + node["name"])
        parent_key = None if parent is None else parent
        props = node["props"]
        local = _transform(props.get("position", (0, 0, 0)), props.get("rotation", (0, 0, 0)), props.get("scale", (1, 1, 1)))
        base = world if parent_key is None else matrices.get(parent_key, world)
        here = base @ local
        matrices[key] = here
        if props.get("visible") is False or (parent_key is not None and parent_key in hidden):
            hidden.add(key)
            continue
        if root_only and not (key == root_only or key.startswith(root_only + "/")):
            continue
        if node["instance"]:
            src = scene["ext"].get(node["instance"], "")
            if src.endswith(".glb"):
                parts += load_glb(res_path(src), here)
            elif src.endswith(".tscn"):
                parts += load_tscn(res_path(src), here)
            continue
        mesh_ref = props.get("mesh")
        if not (isinstance(mesh_ref, tuple) and mesh_ref[0] == "SubResource"):
            continue
        mesh = scene["sub"].get(mesh_ref[1])
        if mesh is None or mesh["type"] not in PRIMITIVES:
            continue
        verts, tris = PRIMITIVES[mesh["type"]](mesh["props"])
        mat_ref = props.get("surface_material_override/0") or mesh["props"].get("material")
        color, glow = (1, 1, 1), 0.0
        if isinstance(mat_ref, tuple) and mat_ref[0] == "SubResource" and mat_ref[1] in scene["sub"]:
            mp = scene["sub"][mat_ref[1]]["props"]
            color = mp.get("shader_parameter/albedo_color", mp.get("albedo_color", (1, 1, 1, 1)))
            glow = float(mp.get("shader_parameter/emission_energy", 0.0)) if "shader_parameter/emission_color" in mp else 0.0
        world_verts = (here[:3, :3] @ verts.T).T + here[:3, 3]
        parts.append(Part(node["name"], world_verts, tris, color, glow=glow))
    return parts


def load_parts(source: str, root_only: str = "") -> list:
    path = res_path(source)
    if path.endswith(".glb"):
        return load_glb(path, np.eye(4))
    return load_tscn(path, np.eye(4), root_only)


# =====================================================================================
# The rasteriser: parts + an orthographic camera -> a small picture
# =====================================================================================

def _camera(view: str):
    """-> (right, up) unit vectors of the camera. The camera looks along -(right x up)."""
    if view == "melee":  # model stands along +Y: lay it down, tip (+Y) to the right
        return np.array([0, 1.0, 0]), np.array([0, 0, 1.0])
    right, up = np.array([0, 0, -1.0]), np.array([0, 1.0, 0])
    if view == "high":  # 35 degrees from above
        tilt = math.radians(35)
        up = np.array([-math.sin(tilt), math.cos(tilt), 0])  # tipped so the camera sits above (+X, +Y)
    return right, up


def rasterise(parts, right, up, size, bounds=None, pad=2, spin=0.0, light=None):
    """Draw the parts into a size x size picture. Returns a dict of per-pixel arrays:
    alpha (0/1), color (RGB, flat shaded), base (unlit colour), part (index), depth."""
    right = right / np.linalg.norm(right)
    up = up / np.linalg.norm(up)
    back = np.cross(right, up)
    if spin:
        c, s = math.cos(math.radians(spin)), math.sin(math.radians(spin))
        right, up = c * right + s * up, -s * right + c * up
    if light is None:
        light = 0.55 * back + 0.6 * up - 0.35 * right
    light = light / np.linalg.norm(light)

    projected = [np.stack([p.verts @ right, p.verts @ up, p.verts @ back], 1) for p in parts]
    if bounds is None:
        allp = np.concatenate(projected)
        x0, y0 = allp[:, 0].min(), allp[:, 1].min()
        x1, y1 = allp[:, 0].max(), allp[:, 1].max()
    else:
        x0, y0, x1, y1 = bounds
    span = max(x1 - x0, y1 - y0, 1e-6)
    inner = size - 2 * pad
    scale = inner / span
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

    n = size * SAMPLES
    depth = np.full((n, n), -1e9)
    part_id = np.full((n, n), -1, int)
    color = np.zeros((n, n, 3))
    base = np.zeros((n, n, 3))
    ss = scale * SAMPLES

    for pi, (part, pts) in enumerate(zip(parts, projected)):
        sx = (pts[:, 0] - cx) * ss + n / 2
        sy = n / 2 - (pts[:, 1] - cy) * ss
        for tri_index, (a, b, c) in enumerate(part.tris):
            va, vb, vc = part.verts[a], part.verts[b], part.verts[c]
            normal = np.cross(vb - va, vc - va)
            ln = np.linalg.norm(normal)
            if ln < 1e-12:
                continue
            normal /= ln
            ax, ay, bx, by, qx, qy = sx[a], sy[a], sx[b], sy[b], sx[c], sy[c]
            area = (bx - ax) * (qy - ay) - (by - ay) * (qx - ax)
            if abs(area) < 1e-9:
                continue
            minx, maxx = int(max(0, math.floor(min(ax, bx, qx)))), int(min(n - 1, math.ceil(max(ax, bx, qx))))
            miny, maxy = int(max(0, math.floor(min(ay, by, qy)))), int(min(n - 1, math.ceil(max(ay, by, qy))))
            if minx > maxx or miny > maxy:
                continue
            gx, gy = np.meshgrid(np.arange(minx, maxx + 1) + 0.5, np.arange(miny, maxy + 1) + 0.5)
            w0 = ((bx - gx) * (qy - gy) - (by - gy) * (qx - gx)) / area
            w1 = ((qx - gx) * (ay - gy) - (qy - gy) * (ax - gx)) / area
            w2 = 1 - w0 - w1
            inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
            if not inside.any():
                continue
            z = w0 * pts[a, 2] + w1 * pts[b, 2] + w2 * pts[c, 2]
            region = depth[miny:maxy + 1, minx:maxx + 1]
            win = inside & (z > region)
            if not win.any():
                continue
            facing = normal if normal @ back >= 0 else -normal  # two-sided
            shade = 0.5 + 0.5 * max(0.0, float(facing @ light))
            if part.glow > 0.5:
                shade = max(shade, 0.95)
            if part.texture is not None and part.uvs is not None:
                u = w0 * part.uvs[a, 0] + w1 * part.uvs[b, 0] + w2 * part.uvs[c, 0]
                v = w0 * part.uvs[a, 1] + w1 * part.uvs[b, 1] + w2 * part.uvs[c, 1]
                th, tw = part.texture.shape[:2]
                tx = np.clip((u * tw).astype(int), 0, tw - 1)
                ty = np.clip((v * th).astype(int), 0, th - 1)
                texel = part.texture[ty, tx, :3] * part.color[:3]
            else:
                texel = np.broadcast_to(part.color[:3], win.shape + (3,))
            region[win] = z[win]
            part_id[miny:maxy + 1, minx:maxx + 1][win] = pi
            base[miny:maxy + 1, minx:maxx + 1][win] = texel[win]
            color[miny:maxy + 1, minx:maxx + 1][win] = (texel * shade)[win]

    # Down to real pixels: solid where at least half the samples are covered.
    cov = (part_id >= 0).reshape(size, SAMPLES, size, SAMPLES).mean(axis=(1, 3))
    alpha = (cov >= 0.45).astype(float)

    def avg(arr):
        a = arr.reshape(size, SAMPLES, size, SAMPLES, -1)
        m = (part_id >= 0).reshape(size, SAMPLES, size, SAMPLES, 1)
        return (a * m).sum(axis=(1, 3)) / np.maximum(m.sum(axis=(1, 3)), 1)

    # Main part per pixel (the most common one among its samples) and its average depth.
    pid = part_id.reshape(size, SAMPLES, size, SAMPLES).transpose(0, 2, 1, 3).reshape(size, size, -1)
    main = np.full((size, size), -1, int)
    for yy in range(size):
        for xx in range(size):
            vals = pid[yy, xx][pid[yy, xx] >= 0]
            if vals.size:
                main[yy, xx] = np.bincount(vals).argmax()
    d = avg(depth.reshape(n, n, 1))[..., 0]
    return {"alpha": alpha, "color": avg(color), "base": avg(base), "part": main, "depth": d,
            "scale": scale, "centre": (cx, cy)}


def _seams(r, depth_jump=0.0):
    """Pixels on the FAR side of an edge between two parts (or a depth step): the detail lines."""
    alpha, part, depth = r["alpha"], r["part"], r["depth"]
    size = alpha.shape[0]
    seam = np.zeros_like(alpha, bool)
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        nb_part = np.roll(np.roll(part, -dy, 0), -dx, 1)
        nb_depth = np.roll(np.roll(depth, -dy, 0), -dx, 1)
        nb_alpha = np.roll(np.roll(alpha, -dy, 0), -dx, 1)
        edge = (alpha > 0) & (nb_alpha > 0) & (nb_part != part) & (nb_depth > depth + 1e-4)
        if depth_jump > 0:
            edge |= (alpha > 0) & (nb_alpha > 0) & (nb_depth > depth + depth_jump)
        seam |= edge
    seam[[0, -1], :] = False
    seam[:, [0, -1]] = False
    return seam


def _save(rgba: np.ndarray, path: str) -> str:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(np.clip(rgba * 255 + 0.5, 0, 255).astype(np.uint8), "RGBA").save(path)
    return path


# =====================================================================================
# 1. Item side profiles (white, for tinting)
# =====================================================================================

def make_item_icon(item_id: str, out_dir: str = "", size: int = ITEM_SIZE) -> str:
    spec = ITEMS[item_id]
    parts = load_parts(spec["source"])
    right, up = _camera(spec.get("view", "side"))
    if spec.get("yaw"):
        turn = _rot_y(math.radians(spec["yaw"]))
        right, up = turn @ right, turn @ up
    r = rasterise(parts, right, up, size, pad=3, spin=spec.get("spin", 0.0))
    alpha = r["alpha"]
    # Brightness from the painted colour (so a dark grip reads darker than a bright barrel) plus a
    # little of the light, normalised so the brightest part of every icon is pure white.
    lum = (r["color"] @ np.array([0.3, 0.55, 0.15]))
    solid = alpha > 0
    top = np.percentile(lum[solid], 92) if solid.any() else 1.0
    bright = 0.62 + 0.38 * np.clip(lum / max(top, 1e-3), 0, 1)
    bright = np.round(bright * 8) / 8  # a few flat steps: pixel-art shading, not gradients
    seam = _seams(r, depth_jump=0.06)
    bright[seam] = 0.32
    out_alpha = alpha.copy()
    out_alpha[seam] = 0.6  # cut-out lines: partly see-through so the tint's dark shows
    rgba = np.dstack([bright, bright, bright, out_alpha])
    rgba[~solid] = 0
    badge = spec.get("badge")
    if badge:
        _draw_badge(rgba, badge)
    return _save(rgba, os.path.join(out_dir or os.path.join(ICON_DIR, "items"), item_id + ".png"))


def _draw_badge(rgba, kind):
    """A tiny extra mark so two items made from the same model don't look identical."""
    size = rgba.shape[0]
    if kind == "sparkle":  # fresh catch: a little 4-point sparkle top-left
        cx, cy = 9, 9
        for d in range(-4, 5):
            for x, y in ((cx + d, cy), (cx, cy + d)):
                rgba[y, x] = (1, 1, 1, 1)
        for x, y in ((cx - 1, cy - 1), (cx + 1, cy - 1), (cx - 1, cy + 1), (cx + 1, cy + 1)):
            rgba[y, x] = (1, 1, 1, 1)
    elif kind == "crown":  # golden koi: a crown over the fish
        cx, y0 = size // 2, 4
        rows = ["1001001", "1101011", "1111111", "1111111"]
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch == "1":
                    rgba[y0 + j * 1, cx - 3 + i] = (1, 1, 1, 1)


# =====================================================================================
# 2. Status badges (white, drawn in code: paw in glue, catnip leaf, catdip tin)
# =====================================================================================

def _canvas(size, k=8):
    big = Image.new("L", (size * k, size * k), 0)
    return big, ImageDraw.Draw(big), k


def _finish(big, size, detail=None):
    """Big mask (+ optional darker detail mask) -> crisp white RGBA."""
    a = np.asarray(big.resize((size, size), Image.BOX), float) / 255.0
    alpha = (a >= 0.5).astype(float)
    bright = np.ones_like(alpha)
    if detail is not None:
        d = np.asarray(detail.resize((size, size), Image.BOX), float) / 255.0
        cut = (d >= 0.5) & (alpha > 0)
        bright[cut] = 0.35
        alpha[cut] = 0.55
    return np.dstack([bright, bright, bright, alpha])


def status_sticky_paws(size=STATUS_SIZE):
    big, d, k = _canvas(size)
    s = size * k
    detail = Image.new("L", big.size, 0)
    dd = ImageDraw.Draw(detail)
    u = s / 32.0
    # glue puddle along the bottom, with drips hanging off the paw
    d.ellipse([3 * u, 23 * u, 29 * u, 30 * u], fill=255)
    # paw pad (big) + 4 toes
    d.ellipse([9 * u, 11 * u, 23 * u, 23 * u], fill=255)
    for tx, ty in ((6, 6), (11, 2.5), (17.5, 2.5), (22.5, 6)):
        d.ellipse([tx * u, ty * u, (tx + 5.5) * u, (ty + 6.5) * u], fill=255)
    # drips: dark gaps that separate the paw from the glue + glue strings
    dd.line([8 * u, 23.5 * u, 24 * u, 23.5 * u], fill=255, width=int(1.6 * u))
    for x in (11, 16, 21):
        d.rounded_rectangle([(x - 1.2) * u, 18 * u, (x + 1.2) * u, 26 * u], radius=1.2 * u, fill=255)
        d.ellipse([(x - 1.9) * u, 25 * u, (x + 1.9) * u, 29 * u], fill=255)
    # a highlight line on the pad
    dd.arc([11 * u, 13 * u, 21 * u, 21 * u], 200, 300, fill=255, width=int(1.5 * u))
    return _finish(big, size, detail)


def status_catnip(size=STATUS_SIZE):
    big, d, k = _canvas(size)
    s = size * k
    u = s / 32.0
    detail = Image.new("L", big.size, 0)
    dd = ImageDraw.Draw(detail)
    # jagged leaf, tilted, pointing up-right
    leaf = [(9, 27), (8, 19), (5, 17), (9, 15), (8, 10), (12, 10), (13, 5), (16, 8), (20, 3),
            (21, 8), (26, 6), (24, 12), (28, 14), (23, 17), (24, 22), (18, 21), (15, 25)]
    d.polygon([(x * u, y * u) for x, y in leaf], fill=255)
    # stem + midrib + veins as cut lines
    dd.line([8 * u, 28 * u, 22 * u, 9 * u], fill=255, width=int(1.6 * u))
    for a, b in (((12, 22), (8, 17)), ((15, 18), (11, 12)), ((18, 14), (16, 8)), ((14, 20), (21, 20)), ((17, 16), (24, 15))):
        dd.line([a[0] * u, a[1] * u, b[0] * u, b[1] * u], fill=255, width=int(1.2 * u))
    # speed lines on the left
    for y, x0, x1 in ((7, 0.5, 6), (12, 0.5, 4.5), (22, 0.5, 4)):
        d.rounded_rectangle([x0 * u, (y - 0.9) * u, x1 * u, (y + 0.9) * u], radius=0.9 * u, fill=255)
    d.line([4 * u, 30 * u, 9 * u, 27 * u], fill=255, width=int(2 * u))
    return _finish(big, size, detail)


def status_catdip(size=STATUS_SIZE):
    big, d, k = _canvas(size)
    s = size * k
    u = s / 32.0
    detail = Image.new("L", big.size, 0)
    dd = ImageDraw.Draw(detail)
    # double chevron (two jumps) on top
    for y in (2, 8):
        d.polygon([(16 * u, y * u), (26 * u, (y + 7) * u), (22 * u, (y + 7) * u), (16 * u, (y + 3) * u),
                   (10 * u, (y + 7) * u), (6 * u, (y + 7) * u)], fill=255)
    # the tin: a short wide can seen slightly from above
    d.rectangle([6 * u, 21 * u, 26 * u, 28 * u], fill=255)
    d.ellipse([6 * u, 25 * u, 26 * u, 31 * u], fill=255)
    d.ellipse([6 * u, 18 * u, 26 * u, 24 * u], fill=255)
    # lid rim + a paw stamp on the label
    dd.arc([6.5 * u, 18.5 * u, 25.5 * u, 23.5 * u], 0, 180, fill=255, width=int(1.3 * u))
    dd.ellipse([14 * u, 25 * u, 18 * u, 28.5 * u], fill=255)
    for tx in (12.5, 15, 17.5):
        dd.ellipse([(tx - 0.2) * u, 23.6 * u, (tx + 1.5) * u, 25.2 * u], fill=255)
    return _finish(big, size, detail)


STATUS = {"sticky_paws": status_sticky_paws, "catnip": status_catnip, "catdip": status_catdip}


def make_status_icon(status_id: str, out_dir: str = "", size: int = STATUS_SIZE) -> str:
    rgba = STATUS[status_id](size)
    return _save(rgba, os.path.join(out_dir or os.path.join(ICON_DIR, "status"), status_id + ".png"))


# =====================================================================================
# 3. NPC portraits (coloured, head + shoulders, three-quarter view)
# =====================================================================================

def _find(parts, *names):
    for name in names:
        for p in parts:
            if p.name == name:
                return p
    return None


def _portrait(parts, size):
    head = _find(parts, "Head")
    if head is None:
        raise ValueError("no Head mesh")
    centre = head.verts.mean(0)
    radius = float(np.max(np.linalg.norm(head.verts - centre, axis=1)))
    nose = _find(parts, "Nose", "Muzzle")
    face = (nose.verts.mean(0) - centre) if nose is not None else np.array([0, 0, -1.0])
    face[1] = 0
    face = face / (np.linalg.norm(face) or 1)
    # camera: three-quarter view (turned 28 degrees), a touch above the eyes
    back = _rot_y(math.radians(28)) @ face
    back = back + np.array([0, 0.12, 0])
    back /= np.linalg.norm(back)
    right = np.cross(np.array([0, 1.0, 0]), back)
    right /= np.linalg.norm(right)
    up = np.cross(back, right)
    # framing: from the shoulders up to the hat, centred on the head
    cx, cy = float(centre @ right), float(centre @ up)
    top = max(float((p.verts @ up).max()) for p in parts if (p.verts @ up).min() > cy - 2.5 * radius)
    top = min(top, cy + 2.6 * radius)
    bottom = cy - 1.55 * radius
    half = max((top - bottom) / 2, 1.25 * radius)
    mid = bottom + half
    bounds = (cx - half, mid - half, cx + half, mid + half)
    light = 0.7 * back + 0.55 * up - 0.4 * right
    return rasterise(parts, right, up, size, bounds=bounds, pad=1, light=light)


def make_npc_portrait(npc_id: str, out_dir: str = "", size: int = PORTRAIT_SIZE) -> str:
    source = NPCS[npc_id]
    parts = load_parts(source, root_only="Model")
    r = _portrait(parts, size)
    alpha = r["alpha"]
    col = np.clip(r["color"] * 1.15, 0, 1)
    col = np.round(col * 12) / 12  # flat PS1 colour steps
    seam = _seams(r, depth_jump=0.0)
    col[seam] *= 0.55
    rgba = np.dstack([col, alpha])
    rgba = _outline(rgba, (0.02, 0.05, 0.09, 1.0))
    return _save(rgba, os.path.join(out_dir or os.path.join(ICON_DIR, "npcs"), npc_id + ".png"))


def _outline(rgba, color):
    """1 px dark outline round the silhouette (only where the picture is clear)."""
    alpha = rgba[..., 3] > 0
    grown = alpha.copy()
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        grown |= np.roll(np.roll(alpha, dy, 0), dx, 1)
    ring = grown & ~alpha
    out = rgba.copy()
    out[ring] = color
    return out


def make_locked_mystery(out_dir: str = "", size: int = PORTRAIT_SIZE) -> str:
    """A dark cat silhouette (the template NPC) with a bold '?' over it."""
    parts = load_parts("res://scenes/npcs/npc_template.tscn", root_only="Model")
    r = _portrait(parts, size)
    alpha = r["alpha"]
    dark = np.array([0.06, 0.09, 0.14])
    rgba = np.dstack([np.broadcast_to(dark, alpha.shape + (3,)), alpha]).copy()
    rgba = _outline(rgba, (0.22, 0.72, 0.98, 1.0))
    big, d, k = _canvas(size)
    u = size * k / 64.0
    d.arc([22 * u, 14 * u, 42 * u, 34 * u], 180, 405, fill=255, width=int(6 * u))
    d.rectangle([29 * u, 30 * u, 35 * u, 40 * u], fill=255)
    d.rectangle([29 * u, 44 * u, 35 * u, 50 * u], fill=255)
    q = np.asarray(big.resize((size, size), Image.BOX), float) / 255.0 >= 0.5
    rgba[q] = (0.85, 0.96, 1.0, 1.0)
    return _save(rgba, os.path.join(out_dir or os.path.join(ICON_DIR, "npcs"), "locked_mystery.png"))


# =====================================================================================
# Everything + the command line
# =====================================================================================

def make_all() -> list:
    made = []
    for item_id in ITEMS:
        made.append(make_item_icon(item_id))
    for status_id in STATUS:
        made.append(make_status_icon(status_id))
    for npc_id in NPCS:
        made.append(make_npc_portrait(npc_id))
    made.append(make_locked_mystery())
    return made


def contact_sheet(paths: list, out: str, cell: int = 128) -> str:
    """All icons side by side, blown up 2x on a dark ocean background (for checking by eye)."""
    cols = 8
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (8, 36, 61, 255))
    for i, p in enumerate(paths):
        img = Image.open(p).convert("RGBA")
        f = (cell - 8) // max(img.size)
        img = img.resize((img.width * f, img.height * f), Image.NEAREST)
        sheet.alpha_composite(img, ((i % cols) * cell + (cell - img.width) // 2, (i // cols) * cell + (cell - img.height) // 2))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    return out


def main(argv):
    if not argv or argv[0] == "all":
        made = make_all()
        print("\n".join(os.path.relpath(p, PROJECT_ROOT) for p in made))
        if len(argv) > 1:
            print("sheet:", contact_sheet(made, argv[1]))
        return
    cmd = argv[0]
    if cmd == "item":
        for item_id in argv[1:] or ITEMS:
            print(make_item_icon(item_id))
    elif cmd == "npc":
        for npc_id in argv[1:] or NPCS:
            print(make_npc_portrait(npc_id))
        print(make_locked_mystery())
    elif cmd == "status":
        for status_id in argv[1:] or STATUS:
            print(make_status_icon(status_id))
    else:
        print(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
