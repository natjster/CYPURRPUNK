class_name CatLook
extends RefCounted
## CYPURRPUNK — THE CHARACTER CREATOR FRAMEWORK: what a cat looks like, and dressing a
## cat model in it. Used by player cats (cat_player.gd) and the MY CAT screen's preview
## (scripts/ui/cat_creator.gd). You never put this script on a node: call CatLook.apply(...).
##
## A LOOK is a plain Dictionary (easy to save and send over the network):
##   {"fur": Color, "markings": Color, "eyes": Color, "nose": Color,
##    "hat": "fedora", "face": "", "neck": "bell_collar",     ("" = nothing in that slot)
##    "voice": "female",                                         (how it sounds when it talks: VOICES)
##    "coat": "calico"}                                          (the fur PATTERN: a CatCoat card id)
## Anything missing just keeps the model's own colour / wears nothing.
##
## The OPTIONS are data, not code:
##   - colours: res://cat_parts/palette.tres (CatPalette)
##   - accessories: every CatPart card (.tres) in res://cat_parts/
##   - coat patterns (tabby, tiger, calico...): every CatCoat card (.tres) in res://cat_coats/
## So a new hat or colour needs no code at all (SETUP_GUIDE §11).
##
## Adding a whole new SLOT (e.g. "back" for capes) is a small code change: add it to SLOTS
## and SLOT_ANCHORS below, and to the Slot list in cat_part.gd. The MY CAT screen picks it up.

const PARTS_FOLDER: String = "res://cat_parts/"
const PALETTE_PATH: String = "res://cat_parts/palette.tres"
const COATS_FOLDER: String = "res://cat_coats/"
## The look key for the coat pattern (a CatCoat id). Missing = the first coat (the tabby).
const COAT_KEY: String = "coat"
## The fur meshes that wear the LIMB pattern (rings / socks / points); every other fur mesh
## wears the BODY pattern.
const LIMB_PARTS: Array[String] = ["LegL", "LegR", "Tail"]

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

## The talking voices a cat can have (MY CAT > VOICE). Each one is a set of voice blips,
## sounds/sfx/meow_blip_cat_<voice>_1..4.wav (made by tools/sound_specs/mess.json), played when
## the cat's MEOW taunt types out over its head (cat_player.gd). Add a voice = add its name here,
## its words in VOICE_NAMES, and its blip files.
const VOICE_KEY: String = "voice"
const VOICES: Array[String] = ["male", "female"]
const VOICE_NAMES: Dictionary = {"male": "MALE", "female": "FEMALE"}

static var _parts: Dictionary = {}  # part id -> CatPart (loaded once)
static var _palette: CatPalette
static var _coat_ids: Array[String] = []  # coat ids in menu order (loaded once)
static var _coats: Dictionary = {}  # coat id -> CatCoat


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


## Every coat pattern id, in MY CAT order (the first one is the default).
static func coat_ids() -> Array[String]:
	if _coat_ids.is_empty():
		var cards: Array[CatCoat] = []
		for file in DirAccess.get_files_at(COATS_FOLDER):
			file = file.trim_suffix(".remap")  # exported games rename resources
			if file.ends_with(".tres"):
				var coat := load(COATS_FOLDER + file) as CatCoat
				if coat != null and not coat.id.is_empty():
					cards.append(coat)
		cards.sort_custom(func(a, b): return a.order < b.order)
		for coat in cards:
			_coats[coat.id] = coat
			_coat_ids.append(coat.id)
	return _coat_ids


static func coat(id: String) -> CatCoat:
	coat_ids()
	return _coats.get(id)


## A look's coat id (cats saved before coats existed get the first one, the tabby).
static func coat_of(look: Dictionary) -> String:
	var id: Variant = look.get(COAT_KEY, "")
	if id is String and coat(id) != null:
		return id
	return coat_ids()[0] if not coat_ids().is_empty() else ""


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
	look[VOICE_KEY] = VOICES[0]
	look[COAT_KEY] = coat_of({})
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
	look[VOICE_KEY] = VOICES[rng.randi() % VOICES.size()]
	if not coat_ids().is_empty():
		look[COAT_KEY] = coat_ids()[rng.randi() % coat_ids().size()]
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
	result[VOICE_KEY] = voice_of(look)
	result[COAT_KEY] = coat_of(look)
	return result


## A look's voice ("male" / "female"). Cats saved before voices existed get the first one.
static func voice_of(look: Dictionary) -> String:
	var voice: Variant = look.get(VOICE_KEY, "")
	return voice if voice is String and voice in VOICES else VOICES[0]


## The Sound name of a look's voice blips, e.g. "meow_blip_cat_female" (Sound picks one of _1.._4).
static func voice_sound(look: Dictionary) -> String:
	return "meow_blip_cat_" + voice_of(look)


# --- Dressing a cat ---

## Paint a cat model (scenes/cat_model.tscn, or anything with the same mesh names) and put on
## its accessories. Safe to call again whenever the look changes.
static func apply(model: Node3D, look: Dictionary) -> void:
	for key in COLOR_KEYS:
		if look.get(key) is Color:
			_paint(model, key, look[key])
	for slot in SLOTS:
		_wear(model, slot, look.get(slot, ""))
	_wear_coat(model, look)


## Put the look's coat pattern on the fur (after _paint made the model's own fur materials).
## Body/head/ears get the coat's body picture, legs/tail its limb picture; see-through pixels
## show the MARKINGS colour (calico patches, tuxedo socks).
static func _wear_coat(model: Node3D, look: Dictionary) -> void:
	var card := coat(coat_of(look))
	var copies: Dictionary = model.get_meta("look_materials_fur") if model.has_meta("look_materials_fur") else {}
	if card == null or copies.is_empty():
		return
	# Which of the scene's fur materials belong to the legs / tail.
	var limb_sources: Array = []
	for part_name in LIMB_PARTS:
		var mesh := model.get_node_or_null(part_name) as MeshInstance3D
		if mesh != null and mesh.has_meta("look_source"):
			limb_sources.append(mesh.get_meta("look_source"))
	var patch: Color = look.get("markings", Color.WHITE) if look.get("markings") is Color else Color.WHITE
	for source in copies:
		var material: ShaderMaterial = copies[source]
		var limb: bool = source in limb_sources
		material.set_shader_parameter("albedo_texture", card.limb_texture if limb else card.body_texture)
		material.set_shader_parameter("uv_scale", card.limb_uv_scale if limb else Vector2.ONE)
		material.set_shader_parameter("patch_color", patch)
		material.set_shader_parameter("patch_amount", 1.0)


## Recolour every mesh of one colour key. The first time, the model gets its OWN copy of each
## material involved (otherwise every cat would change colour together). A colour key can cover
## SEVERAL materials (the fur: Mat_fur with tabby stripes on the body and head, Mat_fur_rings with
## ringed stripes on the legs and tail): each keeps its own pattern and gets the same colour.
static func _paint(model: Node3D, key: String, color: Color) -> void:
	var meta := "look_materials_" + key
	var copies: Dictionary = model.get_meta(meta) if model.has_meta(meta) else {}  # scene material -> our copy
	# The named parts, plus any extra piece called "<Key>_something" anywhere in the model
	# (e.g. "Fur_TailTip" or "Nose_InnerEarL" in scenes/cat_model.tscn): those get this colour too.
	var meshes: Array[MeshInstance3D] = []
	for part_name in COLOR_PARTS[key]:
		var named := model.get_node_or_null(part_name) as MeshInstance3D
		if named != null:
			meshes.append(named)
	for extra in model.find_children(key.capitalize() + "_*", "MeshInstance3D", true, false):
		meshes.append(extra as MeshInstance3D)
	for mesh in meshes:
		# Remember the scene's own material the first time (later the mesh wears our copy).
		if not mesh.has_meta("look_source"):
			mesh.set_meta("look_source", mesh.get_surface_override_material(0))
		var source: ShaderMaterial = mesh.get_meta("look_source")
		if source == null:
			continue
		if not copies.has(source):
			copies[source] = source.duplicate()
		mesh.set_surface_override_material(0, copies[source])
	model.set_meta(meta, copies)
	for material: ShaderMaterial in copies.values():
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
