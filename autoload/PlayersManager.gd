extends Node

var joined_players = {}
signal finish_level
signal player_added(id: int)

func add_player(id: int) -> void:
	joined_players[id] = {"score": 0}
	player_added.emit(id)
	if is_multiplayer_authority():
		_sync_player_list.rpc(joined_players)

func remove_player(id: int) -> void:
	joined_players.erase(id)

@rpc("any_peer", "call_local", "reliable")
func add_points_to_player(id: int, amount: int) -> void:
	if not multiplayer.is_server():
		return
		
	if joined_players.has(id):
		joined_players[id]["score"] += amount
		
		_sync_player_list.rpc(joined_players)
		print("El jugador ", id, " ahora tiene: ", joined_players[id]["score"])
		
		if joined_players[id]["score"] == 50:
			finish_level.emit()
			print("Meta alcanzada, cambiando nivel...")

@rpc("authority", "call_local", "reliable")
func _sync_player_list(server_data) -> void:
	joined_players = server_data
	print("Diccionario sincronizado en el cliente")
