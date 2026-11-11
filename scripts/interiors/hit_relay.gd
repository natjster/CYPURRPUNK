class_name HitRelay
extends Node3D
## A tiny helper for the Hit framework (scripts/hit.gd): a node that hands every hit it gets to a
## function. Used by code-built things that want their OWN hit target (bat swings and blasts aim at
## the target node's position, so a big store-wide receiver would be "hit" in the wrong place).
##
##   var tank := HitRelay.new()
##   tank.on_hit = _on_tank_hit      # func _on_tank_hit(hit: Hit) -> bool
##   add_child(tank)                  # then put a StaticBody3D (with a shape) under it

## Called with the Hit; return true to show a damage number.
var on_hit: Callable


func receive_hit(hit: Hit) -> bool:
	return on_hit.call(hit) if on_hit.is_valid() else false
