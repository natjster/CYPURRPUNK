class_name CatAim
extends Node
## CYPURRPUNK — AIM DOWN SIGHTS (ADS) and GUN RECOIL for one cat. Helldivers-style: hold RIGHT
## MOUSE (pad LT) while holding a gun with your LEFT PAW EMPTY and the camera snaps in tight over
## the cat's shoulder, the view zooms, the cat walks slower and the shots get much tighter.
## (Holding something in the left paw? Then right mouse fires THAT paw, like before.)
##
## Attach to the "Aim" node under Player in scenes/player.tscn (next to Moves and Ride). Its knobs:
## click Player > Aim in the scene and look at the Inspector.
##
## Who does what:
##   - item_manager.gd (_use_held_items) sets "wants_aim" every frame on the cat's owner.
##   - cat_player.gd reads amount() for the camera (_update_zoomies_juice), walking speed and
##     mouse speed, and roll()/fov_punch() for the shot kicks.
##   - weapon.gd calls kick() on every shot (recoil climb + bloom) and spread_scale() for spread.
## Everything here only matters on the cat owner's computer (it's that player's camera).

@export_group("Aim Down Sights")
## How close the camera comes while aiming (metres; normal play is 3.5).
@export var ads_camera_distance: float = 1.55
## How far right the camera slides while aiming (metres), so the crosshair sits past the cat's ear.
@export var ads_camera_side: float = 0.85
## How far up it lifts while aiming (metres).
@export var ads_camera_lift: float = 0.12
## Zoom while aiming: the field of view is multiplied by this (0.7 = 30% zoomed in).
@export_range(0.3, 1.0) var ads_fov_scale: float = 0.68
## How fast the camera snaps in and out (higher = snappier).
@export var ads_speed: float = 14.0
## Walking speed while aiming (0.55 = a bit over half). No zoomies while aiming.
@export_range(0.1, 1.0) var ads_move_speed: float = 0.55
## Mouse / stick speed while aiming (lower = finer aim when zoomed in).
@export_range(0.2, 1.0) var ads_look_speed: float = 0.65
## Sound when you snap to aim (res://sounds/sfx/, no .wav; "" = none).
@export var ads_sound: String = "click"

@export_group("Recoil")
## How fast the camera's recoil climb settles back (higher = the gun comes back down quicker).
## Only Recoil Return of each kick comes back by itself: the rest you pull down yourself.
@export var recoil_settle_speed: float = 9.0
## How fast the shot's camera roll and zoom punch fade (higher = shorter).
@export var punch_fade_speed: float = 14.0
## How fast the spread BLOOM (shots spreading more as you hold the trigger) shrinks back.
@export var bloom_fade_speed: float = 4.0

@onready var cat: CatPlayer = get_parent()

## Set by the item system every frame: does this player want to aim right now?
var wants_aim: bool = false
## Extra spread from firing fast (degrees). Weapons add to it; it shrinks by itself.
var bloom_degrees: float = 0.0

var _amount: float = 0.0          # 0 = hip, 1 = fully aimed (eased)
var _was_aiming := false
var _recoil_left := Vector2.ZERO  # recoil (pitch, yaw radians) still to give back by itself
var _roll: float = 0.0            # camera roll punch (radians)
var _fov_punch: float = 0.0       # extra field of view for one punchy frame (degrees)


## Is the cat aiming down sights right now (button held, on foot, gun in paw)?
func is_aiming() -> bool:
	return wants_aim and cat.is_controlled and not cat.inventory_open()


## 0..1: how far into the aim view the camera is.
func amount() -> float:
	return _amount


## Spread multiplier for weapons: 1 at the hip, the gun's ADS Spread Scale when aimed.
func spread_scale(ads_scale: float) -> float:
	return lerpf(1.0, ads_scale, _amount)


## Camera roll punch to add on top of the normal tilt (radians).
func roll() -> float:
	return _roll


## Field-of-view punch to add on top of the normal FOV (degrees).
func fov_punch() -> float:
	return _fov_punch


## A shot was fired: kick the camera up (pitch) and a little sideways (yaw), roll it, punch the
## zoom and bloom the spread. "settle" (0..1) = how much of the climb comes back by itself.
func kick(pitch_degrees: float, yaw_degrees: float, settle: float, roll_degrees: float, fov_degrees: float, bloom: float, max_bloom: float) -> void:
	var pitch := deg_to_rad(pitch_degrees)
	var yaw := deg_to_rad(randf_range(-yaw_degrees, yaw_degrees))
	cat.spring_arm.rotation.x = clampf(cat.spring_arm.rotation.x + pitch,
		deg_to_rad(cat.min_pitch_degrees), deg_to_rad(cat.max_pitch_degrees))
	cat.camera_pivot.rotate_y(yaw)
	_recoil_left += Vector2(pitch, yaw) * settle
	_roll += deg_to_rad(randf_range(-roll_degrees, roll_degrees))
	_fov_punch += fov_degrees
	bloom_degrees = minf(bloom_degrees + bloom, max_bloom)


func _process(delta: float) -> void:
	if not is_instance_valid(cat) or not cat.is_multiplayer_authority():
		return
	# Ease into / out of the aim view.
	var aiming := is_aiming()
	_amount = lerpf(_amount, 1.0 if aiming else 0.0, 1.0 - exp(-ads_speed * delta))
	if aiming and not _was_aiming and ads_sound != "":
		Sound.play(ads_sound, -14.0)
	_was_aiming = aiming

	# Recoil comes back down by itself (only the share each gun lets settle).
	var give := _recoil_left * (1.0 - exp(-recoil_settle_speed * delta))
	_recoil_left -= give
	cat.spring_arm.rotation.x = clampf(cat.spring_arm.rotation.x - give.x,
		deg_to_rad(cat.min_pitch_degrees), deg_to_rad(cat.max_pitch_degrees))
	cat.camera_pivot.rotate_y(-give.y)

	var fade := exp(-punch_fade_speed * delta)
	_roll *= fade
	_fov_punch *= fade
	bloom_degrees *= exp(-bloom_fade_speed * delta)

	# The crosshair tightens while aiming and opens up with bloom.
	if cat.reads_input():
		var crosshair := Hud.element("Crosshair", cat.slot) as HudCrosshair
		if crosshair != null:
			crosshair.set_aim(_amount, bloom_degrees)
