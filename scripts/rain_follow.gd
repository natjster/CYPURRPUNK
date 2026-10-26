extends GPUParticles3D
## Keeps the rain centred above whichever camera is active (cat or car),
## so it's always raining around you without filling the whole city with drops.

## How far above the camera the drops spawn.
@export var height_above_camera: float = 10.0
## Split screen: follow THIS camera instead (players 2-4 each get a copy of the rain that
## follows their screen's camera, made by scripts/ui/game_screen.gd).
var follow: Camera3D = null


func _process(_delta: float) -> void:
	var camera := follow if follow != null else get_viewport().get_camera_3d()
	if camera != null:
		global_position = camera.global_position + Vector3.UP * height_above_camera
