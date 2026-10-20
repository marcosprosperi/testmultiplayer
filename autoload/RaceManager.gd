extends Node

## Seconds to wait after everyone crosses the finish line before changing level
const NEXT_LEVEL_DELAY = 3.0

signal finish_order_changed

var current_level: Node2D
# Peer ids in the order they crossed the finish line (synced by the server)
var finish_order: Array = []

func register_level(level: Node2D) -> void:
	current_level = level
	finish_order.clear()
	finish_order_changed.emit()

func get_spawn_position() -> Vector2:
	var spawn = _find_in_level("spawn")
	return spawn.global_position if spawn else Vector2.ZERO

func has_spawn() -> bool:
	return _find_in_level("spawn") != null

func get_finish() -> Node2D:
	return _find_in_level("finish")

## 0.0 at the start, 1.0 at the finish line (the course runs left to right)
func get_progress(player: Node2D) -> float:
	var finish = get_finish()
	if finish == null or !has_spawn():
		return 0.0
	var start_x = get_spawn_position().x
	var length = finish.global_position.x - start_x
	if is_zero_approx(length):
		return 0.0
	return clampf((player.global_position.x - start_x) / length, 0.0, 1.0)

func has_finished(id: int) -> bool:
	return finish_order.has(id)

@rpc("any_peer", "call_local", "reliable")
func report_finish() -> void:
	if !multiplayer.is_server():
		return
	var id = multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()
	if finish_order.has(id) or !PlayersManager.joined_players.has(id):
		return

	finish_order.append(id)
	_sync_finish_order.rpc(finish_order)
	print("Jugador ", id, " llegó a la meta en posición ", finish_order.size())

	if finish_order.size() >= PlayersManager.joined_players.size():
		await get_tree().create_timer(NEXT_LEVEL_DELAY).timeout
		PlayersManager.finish_level.emit()

@rpc("authority", "call_local", "reliable")
func _sync_finish_order(order: Array) -> void:
	finish_order = order
	finish_order_changed.emit()

func _find_in_level(group: String) -> Node2D:
	if !is_instance_valid(current_level):
		return null
	for node in get_tree().get_nodes_in_group(group):
		if current_level.is_ancestor_of(node):
			return node
	return null
