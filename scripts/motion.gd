class_name Motion
## Small maths helpers every moving thing uses (static: call them as Motion.flat(v) etc.).
##
##   Motion.flat(v)                     - v with the height (y) removed: "along the ground"
##   Motion.flat_distance(a, b)         - distance between two points along the ground
##   Motion.glide_weight(smoothing, dt) - how far to glide this frame (0..1), see below
##   Motion.glide(from, to, weight, snap_distance)
##
## GLIDING (network smoothing): other players' cats, the car and enemies are moved by another
## computer. Updates arrive in bursts, so instead of jumping to each one, our copy glides a bit
## of the way there every frame. "smoothing" = how tightly it follows (higher = tighter);
## beyond "snap_distance" it just jumps (e.g. a teleport down to the sewers).


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The fraction of the remaining gap to close this frame. Frame-rate independent: the same
## smoothing feels the same at 30 or 144 fps.
static func glide_weight(smoothing: float, delta: float) -> float:
	return 1.0 - exp(-smoothing * delta)


## Where to be this frame: part of the way from "from" to "to", or straight there if the gap
## is bigger than snap_distance.
static func glide(from: Vector3, to: Vector3, weight: float, snap_distance: float) -> Vector3:
	if from.distance_to(to) > snap_distance:
		return to
	return from.lerp(to, weight)
