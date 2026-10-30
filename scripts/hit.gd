class_name Hit
extends RefCounted
## THE HIT FRAMEWORK: one way for anything to get shot.
##
## A gun (weapon.gd) fires a ray, finds what it hit, fills in one of these and calls
##     target.receive_hit(hit)
## on the thing it hit. The gun doesn't know or care WHAT it hit: enemies, cats, the car, a
## breakable crate... Each target decides what a hit does to it.
##
## To make something shootable, give its script (on the node with the collision shape, or any
## parent of it) this function:
##
##     func receive_hit(hit: Hit) -> bool:
##         # ...react: send damage to the host, push yourself, play a sound...
##         return true   # true = show the shooter a damage number, false = no number
##
## receive_hit runs on the SHOOTER's computer, so it usually just sends an RPC to whoever is in
## charge of the target (the host for enemies, the owner for a cat, the driver for the car).
## Enemies (enemy.gd) already do this; a new enemy gets it for free.

## The cat that fired (null = nobody in particular, e.g. a test).
var shooter: CatPlayer
## The gun that fired, for its other numbers (e.g. weapon.cat_knockback, weapon.car_impulse).
var weapon: Weapon
## Health to take off, already rolled by the gun (crits included), so the number the shooter
## sees is the number taken off.
var damage: int = 0
## Was it a critical hit? (Bigger yellow damage number.)
var crit: bool = false
## Which way the bolt was flying (length 1).
var direction: Vector3
## Where exactly it hit (world position).
var position: Vector3
## Seconds this hit stuns an enemy (0 = no stun). Filled in from the gun's Stun Seconds.
var stun_seconds: float = 0.0
## Shove on an enemy (metres per second), already worked out by the gun.
var enemy_push: Vector3 = Vector3.ZERO
## How much of the usual "gunfire makes the city angry" heat this hit adds (1 = all of it).
var city_heat: float = 1.0


## The player ID of the shooter, or 0.
func shooter_id() -> int:
	return shooter.player_id if shooter != null else 0


## The shootable thing a ray hit: the collider itself, or the nearest parent that has
## receive_hit() (so a hitbox can sit on a child node). null = nothing shootable (a wall).
static func target_of(collider: Object) -> Node:
	var node := collider as Node
	for i in 4:  # a few levels up is plenty (and never wanders up to the whole scene)
		if node == null:
			return null
		if node.has_method("receive_hit"):
			return node
		node = node.get_parent()
	return null
