class_name CatRide
extends Node
## CYPURRPUNK — a cat riding in a car (driving it, or in a passenger seat as the GUNNER).
## Attach to the "Ride" node under Player in scenes/player.tscn (next to Moves). Its knobs: click
## Player > Ride in the scene and look at the Inspector.
##
## The car (scripts/getaway_car.gd) calls cat.enter_car(car) / cat.exit_car(where) on EVERY
## computer; those just pass on to enter() / exit() here.
##
## While in a car the cat is hidden and can't walk, but its BODY rides along inside the car
## (follow(), every physics frame on the owner's computer). That's what lets the VAC-COPs and the
## other bots keep chasing you when you jump in a car (roomba.gd _can_chase): they hunt the car.
##
## DRIVER: their camera moves onto the car's chase camera (CameraRig) - the normal driving view.
## PASSENGER = GUNNER: their camera stays their OWN, floating over the car's roof a bit further
## back, so they look around freely with the mouse / right stick and SHOOT with whatever is in
## their paws (item_manager.gd _use_held_items lets gunners fire). E hops out (getaway_car.gd).

## How high over the middle of the car the hidden cat's body rides (metres). Shots fired by a
## gunner come from about here (the gun's muzzle).
@export var ride_height: float = 0.9
## GUNNER camera: how far behind the cat it sits (metres; on foot it's the scene's Spring Length).
## Further = more of the car and the street in view.
@export var gunner_camera_distance: float = 4.5
## GUNNER camera: lifted this much higher than on foot (metres), so it looks over the car's roof.
@export var gunner_camera_lift: float = 0.6

@onready var cat: CatPlayer = get_parent()

## The on-foot camera distance, put back when the gunner hops out.
var _foot_spring_length: float = -1.0


## True while this cat rides in a car's PASSENGER seat (it may shoot).
func is_gunner() -> bool:
	return cat.riding_car != null and cat.riding_car.driver_id != cat.player_id


## Every computer: the cat gets in (driver or passenger).
func enter(car: GetawayCar) -> void:
	cat.riding_car = car
	cat.visible = false
	cat.collision_shape.set_deferred("disabled", true)
	if not cat.is_multiplayer_authority():
		return

	cat.is_controlled = false
	cat.velocity = Vector3.ZERO
	cat.cat_model.rotation.x = 0.0
	cat._lean_x = 0.0
	cat._flip_time_left = 0.0
	cat.camera.fov = cat._base_fov

	if is_gunner():
		# GUNNER: keep our own camera, just lift it over the roof and pull it back a bit. The
		# spring arm must ignore the car's body, or the camera would get squashed into the roof.
		cat.spring_arm.add_excluded_object(car.get_rid())
		if _foot_spring_length < 0.0:
			_foot_spring_length = cat.spring_arm.spring_length
		cat.spring_arm.spring_length = gunner_camera_distance
		cat.spring_arm.position = Vector3(0.0, gunner_camera_lift, 0.0)
		cat.camera_pivot.rotation.y = car.global_rotation.y  # start out looking where the car points
	else:
		# DRIVER: move the camera node under the car's camera arm (the chase view).
		cat.camera.reparent(car.camera_arm, false)
		cat.camera.transform = Transform3D.IDENTITY
	if cat.slot == 0:
		cat.camera.make_current()  # (players 2-4: game_screen.gd follows this camera wherever it is)
	follow()


## Every computer: the cat gets out at "exit_position".
func exit(exit_position: Vector3) -> void:
	var car := cat.riding_car
	cat.riding_car = null
	cat.visible = true
	cat.collision_shape.set_deferred("disabled", false)
	if not cat.is_multiplayer_authority():
		return  # the owner moves it; the new position arrives via the synchronizer

	cat.global_position = exit_position
	cat.velocity = Vector3.ZERO
	cat.sync_position = cat.position
	if car != null:
		cat.spring_arm.remove_excluded_object(car.get_rid())
	if _foot_spring_length >= 0.0:
		cat.spring_arm.spring_length = _foot_spring_length
		_foot_spring_length = -1.0
	cat.spring_arm.position = Vector3.ZERO
	# Take the camera back (a gunner's never left).
	if cat.camera.get_parent() != cat.spring_arm:
		cat.camera.reparent(cat.spring_arm, false)
	cat.camera.transform = Transform3D.IDENTITY
	if cat.slot == 0:
		cat.camera.make_current()
	cat.is_controlled = true


## Owner, every physics frame while in a car: keep the hidden body inside the car, so the bots
## chase the car and anything measuring "where is this cat" gets the car's spot.
func follow() -> void:
	var car := cat.riding_car
	if car == null or not is_instance_valid(car):
		return
	cat.global_position = car.global_position + Vector3.UP * ride_height
	cat.velocity = Vector3.ZERO
	cat.sync_position = cat.position
