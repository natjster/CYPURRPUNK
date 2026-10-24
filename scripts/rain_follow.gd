extends GPUParticles3D
## Keeps the rain centred above whichever camera is active (cat or car),
## so it's always raining around you without filling the whole city with drops.

## How far above the camera the drops spawn.
@export var height_above_camera: float = 10.0


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_position = camera.global_position + Vector3.UP * height_above_camera
