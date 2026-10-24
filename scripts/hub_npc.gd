class_name HubNpc
extends StaticBody3D
## A cat you can talk to in the hub. Used by DON CATLEONE (scenes/props/don_catleone.tscn).
## Expected node tree:
##   DonCatleone (StaticBody3D)  <- this script
##   ├── CollisionShape3D        <- so players bump into him instead of walking through
##   ├── Model (Node3D)          <- his meshes; turns to look at the nearest player
##   │   └── Tail                <- swishes slowly
##   └── NameTag (Label3D)
##
## Walk up to him and press E (cat_player.gd asks UndergroundHub.try_talk). He opens the
## talk box (NpcDialog) with a few choices. Everything he says is in the Inspector below,
## so you can rewrite his lines without touching code.
##
## Multiplayer: he isn't networked at all. Every computer has its own Don, standing in the
## same place, and talking to him only changes things for YOUR cat. Nothing to sync.

@export var npc_name: String = "DON CATLEONE"
## How close (metres) you must be to talk.
@export var talk_radius: float = 3.0

@export_group("What he says")
## One of these is picked at random every time you start talking.
@export_multiline var greetings: PackedStringArray = [
	"Ayyy, look what crawled outta the litter box. You want work? I got work.",
	"Welcome to the Sewers, kid. Nobody shoots down here. Nobody. Capisce?",
	"The city up there is crawlin' with fish, and nobody's guardin' 'em. Well. Almost nobody.",
	"You come to me, on the day of my nap, and you ask for a JOB?",
]
## His answer to "WHO ARE YOU?"
@export_multiline var about_text: String = "Don Catleone. I run these pipes. Nine lives, kid - I spent eight of 'em gettin' here. Don't make me spend the ninth on you."
## His answer to "HOW DOES THIS WORK?"
@export_multiline var howto_text: String = "You go up the drain. You grab every fish that ain't nailed down. Then you find the green beam - EXTRACTION - and the pipes bring you back here with the cash. Watch out for them Roombas. They don't forgive. They vacuum."
## What he says as he sends you up.
@export_multiline var deploy_text: String = "Go. And if the vacuums get you... I never met you."

@onready var model: Node3D = $Model
@onready var tail: Node3D = $Model/Tail

var _clock: float = 0.0


func _process(delta: float) -> void:
	_clock += delta
	tail.rotation.z = sin(_clock * 1.6) * 0.35  # lazy tail swish
	# Turn to look at the nearest player who's close by (each computer does this by itself).
	var nearest: Node3D = null
	for cat in Game.instance.players.get_children():
		var d := global_position.distance_to((cat as Node3D).global_position)
		if (cat as Node3D).visible and d < 8.0 and (nearest == null or d < global_position.distance_to(nearest.global_position)):
			nearest = cat
	if nearest != null:
		var to_cat := nearest.global_position - global_position
		var target_yaw := atan2(-to_cat.x, -to_cat.z)  # same maths as the player cats (face -Z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-3.0 * delta))


func in_reach(cat: CatPlayer) -> bool:
	return global_position.distance_to(cat.global_position) < talk_radius


## E pressed next to him: say hello and show the choices.
func talk(cat: CatPlayer) -> void:
	_show_menu(cat, greetings[randi() % greetings.size()])


func _show_menu(cat: CatPlayer, line: String) -> void:
	NpcDialog.instance.open(npc_name, line, [
		["SEND ME UP TOP", func(): _deploy(cat)],
		["WHO ARE YOU?", func(): _show_menu(cat, about_text)],
		["HOW DOES THIS WORK?", func(): _show_menu(cat, howto_text)],
		["NEVER MIND", func(): NpcDialog.instance.close()],
	])


func _deploy(cat: CatPlayer) -> void:
	NpcDialog.instance.close()
	Game.instance.show_message("%s: %s" % [npc_name, deploy_text])
	UndergroundHub.instance.deploy(cat)
