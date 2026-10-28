class_name HeldItem
extends Node3D
## Base script for any HELD item that DOES something (weapons, catnip, future tools).
## Put a script that "extends HeldItem" (or extends Weapon) on the root of the item's scene.
##
## The item manager creates the scene in two places:
##   - lying on the street: holder is null, so nothing happens (it's just a model)
##   - in a cat's paw: holder/hand/data are filled in on EVERY computer
##
## Only the cat's OWNER calls use_tick() each physics frame. If the item does something
## other players must see, send it with an RPC from here. The scene sits at the same
## path on every computer (Players/<id>/CatModel/HeldR or HeldL), so RPCs on it work.

## This item's card.
var data: ItemData
## The cat holding it, or null when it's lying on the street.
var holder: CatPlayer = null
## 0 = right paw (Left Mouse), 1 = left paw (Right Mouse).
var hand: int = 0


## Owner only, every physics frame while held.
## trigger_down = the use button is held; trigger_pressed = it was pressed this frame.
func use_tick(_trigger_down: bool, _trigger_pressed: bool, _delta: float) -> void:
	pass


## Text for the bottom of the screen while you hold it ("" = nothing).
func hud_text() -> String:
	return ""


## Show the aiming crosshair while you hold it?
func wants_crosshair() -> bool:
	return false


## Owner only: use the item up (catnip). The host removes it from the paw.
func consume() -> void:
	ItemManager.instance.request_consume.rpc_id(1, holder.player_id, hand)
