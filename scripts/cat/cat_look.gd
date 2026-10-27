class_name CatLook
extends RefCounted
## CYPURRPUNK — THE CHARACTER CREATOR FRAMEWORK: what a cat looks like, and dressing a
## cat model in it. Used by player cats (cat_player.gd) and the MY CAT screen's preview
## (scripts/ui/cat_creator.gd). You never put this script on a node: call CatLook.apply(...).
##
## A LOOK is a plain Dictionary (easy to save and send over the network):
##   {"fur": Color, "markings": Color, "eyes": Color, "nose": Color,
##    "hat": "fedora", "face": "", "neck": "bell_collar"}      ("" = nothing in that slot)
## Anything missing just keeps the model's own colour / wears nothing.
##
## The OPTIONS are data, not code:
##   - colours: res://cat_parts/palette.tres (CatPalette)
##   - accessories: every CatPart card (.tres) in res://cat_parts/
## So a new hat or colour needs no code at all (SETUP_GUIDE §11).
##
## Adding a whole new SLOT (e.g. "back" for capes) is a small code change: add it to SLOTS
## and SLOT_ANCHORS below, and to the Slot list in cat_part.gd. The MY CAT screen picks it up.

const PARTS_FOLDER: String = "res://cat_parts/"
const PALETTE_PATH: String = "res://cat_parts/palette.tres"

## The colour keys, in MY CAT screen order, and which meshes of the cat model each one paints
## (node names in scenes/cat_model.tscn).
const COLOR_KEYS: Array[String] = ["fur", "markings", "eyes", "nose"]
const COLOR_PARTS: Dictionary = {
	"fur": ["Body", "LegL", "LegR", "Head", "EarL", "EarR", "Tail"],
	"markings": ["Belly", "Muzzle"],
	"eyes": ["EyeL", "EyeR"],
	"nose": ["Nose"],
}
## Accessory slots, in MY CAT screen order.
const SLOTS: Array[String] = ["hat", "face", "neck"]
## Where each slot's (0, 0, 0) sits on the cat model (top of the head, in front of the eyes,
## round the neck). A part's own Offset is added on top.
const SLOT_ANCHORS: Dictionary = {
	"hat": Vector3(0, 1.02, 0.02),
	"face": Vector3(0, 0.83, -0.33),
	"neck": Vector3(0, 0.56, 0),
}

static var _parts: Dictionary = {}  # part id -> CatPart (loaded once)
static var _palette: CatPalette


# --- The options (loaded from res://cat_parts/ the first time they're asked for) ---

## Every accessory card: part id -> CatPart.
static func parts() -> Dictionary:
	if _parts.is_empty():
		for file in DirAccess.get_files_at(PARTS_FOLDER):
			file = file.trim_suffix(".remap")  # exported games rename resources
			if file.ends_with(".tres"):
				var part := load(PARTS_FOLDER + file) as CatPart
				if part != null and not part.id.is_empty():
					_parts[part.id] = part
	return _parts


## The accessory ids for one slot, sorted by name, with "" (= nothing) first.
static func part_ids_for(slot: String) -> Array[String]:
	var ids: Array[String] = []
	for id in parts():
		if (parts()[id] as CatPart).slot == slot:
			ids.append(id)
	ids.sort_custom(func(a, b): return parts()[a].display_name < parts()[b].display_name)
	ids.push_front("")
	return ids


static func palette() -> CatPalette:
	if _palette == null:
		_palette = load(PALETTE_PATH) as CatPalette
	return _palette


# --- Looks ---

## A look with the first colour of every list and no accessories.
static func default_look() -> Dictionary:
	var look := {}
	for key in COLOR_KEYS:
		var colors := palette().colors_for(key)
		if not colors.is_empty():
			look[key] = colors[0]
	for slot in SLOTS:
		look[slot] = ""
	return look


## A random look from the palette and parts (rng = your own random generator).
static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var look := {}
	for key in COLOR_KEYS:
		var colors := palette().colors_for(key)
		if not colors.is_empty():
			look[key] = colors[rng.randi() % colors.size()]
	for slot in SLOTS:
		var ids := part_ids_for(slot)
		look[slot] = ids[rng.randi() % ids.size()]
	return look


## Keeps only sensible values (colours that are Colors, parts that exist), so a broken save
## file or a strange network message can't break a cat.
static func clean(look: Variant) -> Dictionary:
	var result := {}
	if not look is Dictionary:
		return result
	for key in COLOR_KEYS:
		if look.get(key) is Color:
			result[key] = look[key]
	for slot in SLOTS:
		var id: Variant = look.get(slot, "")
		result[slot] = id if id is String and (id == "" or parts().has(id)) else ""
	return result


# --- Dressing a cat ---

## Paint a cat model (scenes/cat_model.tscn, or anything with the same mesh names) and put on
## its accessories. Safe to call again whenever the look changes.
static func apply(model: Node3D, look: Dictionary) -> void:
	for key in COLOR_KEYS:
		if look.get(key) is Color:
			_paint(model, key, look[key])
	for slot in SLOTS:
		_wear(model, slot, look.get(slot, ""))


## Recolour every mesh of one colour key. The first time, the model gets its OWN copy of the
## material (otherwise every cat would change colour together).
static func _paint(model: Node3D, key: String, color: Color) -> void:
	var meta := "look_material_" + key
	var material: ShaderMaterial = model.get_meta(meta) if model.has_meta(meta) else null
	for part_name in COLOR_PARTS[key]:
		var mesh := model.get_node_or_null(part_name) as MeshInstance3D
		if mesh == null:
			continue
		if material == null:
			material = (mesh.get_surface_override_material(0) as ShaderMaterial).duplicate()
			model.set_meta(meta, material)
		mesh.set_surface_override_material(0, material)
	if material == null:
		return
	material.set_shader_parameter("albedo_color", color)
	if key == "eyes":
		# Cat eyes catch the light: a soft glow in the eye colour (none for black eyes).
		material.set_shader_parameter("emission_color", color)
		material.set_shader_parameter("emission_energy", 0.0 if color.get_luminance() < 0.1 else 1.2)


## Swap the accessory in one slot (removes the old one; "" = nothing).
static func _wear(model: Node3D, slot: String, part_id: String) -> void:
	var node_name := "Look_" + slot.capitalize()
	var old := model.get_node_or_null(node_name)
	if old != null:
		if old.get_meta("part_id", "") == part_id:
			return  # already wearing it
		model.remove_child(old)
		old.queue_free()
	var part: CatPart = parts().get(part_id)
	if part == null or part.scene == null:
		return
	var node := part.scene.instantiate() as Node3D
	node.name = node_name
	node.set_meta("part_id", part_id)
	node.position = SLOT_ANCHORS.get(slot, Vector3.ZERO) + part.offset
	node.rotation_degrees = part.rotation_degrees
	node.scale = Vector3.ONE * part.scale
	model.add_child(node)
