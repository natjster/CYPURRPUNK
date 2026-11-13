extends Node
## Shared by DevCapture (scripts/dev_capture.gd) and every test module in this folder:
## the command line options (`_args`) and the small helpers more than one test uses.
## Debug-only test tool: never runs in normal play.

## The command line options (filled in by DevCapture).
var _args: Dictionary = {}


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## The car the --drive / --ride_along / --exit_after tests use: the one this cat is in, else its
## own gang's car (getaway_car.gd team), else the nearest.
func _car_for(player: CatPlayer) -> GetawayCar:
	var inside := Game.instance.car_of(player.player_id)
	if inside != null:
		return inside
	var best: GetawayCar = null
	for car in Game.instance.cars():
		if car.team == player.team:
			return car
		if best == null or car.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
			best = car
	return best


## The Roomba --bait_roomba / --zap_roomba act on: the nearest one, or the MEGA VAC-COP
## with --roomba=boss (waits for it to appear).
func _pick_roomba(scene: Node, near: Vector3, args: Dictionary) -> Roomba:
	if args.get("roomba", "") == "boss":
		for wait in 300:
			for roomba in scene.get_node("Roombas").get_children():
				if roomba is Roomba and (roomba as Roomba).is_boss:
					return roomba
			await get_tree().physics_frame
	if args.get("roomba", "") in ["drone", "trapper", "vac"]:
		# --roomba=drone / trapper / vac: the nearest of that kind (waits for one to appear;
		# vac = a plain VAC-COP, not a boss, drone or trapper).
		while true:
			var best: Roomba = null
			for node in scene.get_node("Roombas").get_children():
				var kind_ok: bool = node is SquirtDrone if args["roomba"] == "drone" else (node is LintTrapper if args["roomba"] == "trapper" \
					else (node is Roomba and not node is SquirtDrone and not node is LintTrapper and not (node as Roomba).is_boss))
				if kind_ok \
						and (best == null or near.distance_to(node.global_position) < near.distance_to(best.global_position)):
					best = node
			if best != null:
				return best
			await get_tree().physics_frame
	return _nearest_roomba(scene, near)


func _nearest_roomba(scene: Node, from: Vector3) -> Roomba:
	var best: Roomba = null
	for roomba in scene.get_node("Roombas").get_children():
		if best == null or from.distance_to(roomba.global_position) < from.distance_to(best.global_position):
			best = roomba
	return best


## How many of this item lie on the street / sewer floors right now.
func _count_world_items(item_id: String) -> int:
	var count := 0
	for id in ItemManager.instance.world:
		count += 1 if ItemManager.instance.world[id].item == item_id else 0
	return count


## A fake controller event: "A" / "Start" press or release, or a stick / trigger pushed all
## the way (pressed) or let go (not pressed). Same names as Controls.PAD_BUTTONS / PAD_AXES.
func _pad_event(pad_name: String, pressed: bool) -> InputEvent:
	var event := Controls._event_from_name("Pad " + pad_name)
	assert(event != null, "unknown controller name: " + pad_name)
	event.device = int(_args.get("pad_device", "0"))
	if event is InputEventJoypadButton:
		event.pressed = pressed
	elif not pressed:
		event.axis_value = 0.0
	return event


## "Button 'RESUME'" for the focus printout (or "-" when nothing is highlighted).
func _describe_focus(control: Control) -> String:
	if control == null:
		return "-"
	var text: String = control.get("text") if control.get("text") != null else ""
	return "%s '%s'" % [control.get_class(), text]
