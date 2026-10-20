extends Node

const MAX_NAME_LENGTH = 12
const COLORS = [
	Color("#e74c3c"), Color("#3498db"), Color("#2ecc71"), Color("#f1c40f"),
	Color("#9b59b6"), Color("#e67e22"), Color("#1abc9c"), Color("#ecf0f1"),
]

# Only players that confirmed a name and color: id -> {name, color, score}
var joined_players = {}
var game_started := false

signal finish_level
signal players_changed
# Server only: a new player confirmed their profile
signal player_added(id: int)
# Server only
signal player_removed(id: int)
# Local: answer to request_profile
signal profile_result(ok: bool, message: String)

func reset() -> void:
	joined_players = {}
	game_started = false
	players_changed.emit()

func has_player(id: int) -> bool:
	return joined_players.has(id)

func name_of(id: int) -> String:
	return joined_players[id]["name"] if joined_players.has(id) else "?"

func color_of(id: int) -> Color:
	return COLORS[joined_players[id]["color"]] if joined_players.has(id) else Color.GRAY

func is_name_taken(player_name: String, except_id := 0) -> bool:
	for id in joined_players:
		if id != except_id and joined_players[id]["name"].to_lower() == player_name.strip_edges().to_lower():
			return true
	return false

func is_color_taken(color_index: int, except_id := 0) -> bool:
	for id in joined_players:
		if id != except_id and joined_players[id]["color"] == color_index:
			return true
	return false

## Sent by each peer to the server (also to change name / color later)
@rpc("any_peer", "call_local", "reliable")
func request_profile(player_name: String, color_index: int) -> void:
	if not multiplayer.is_server():
		return
	var id = multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()

	player_name = player_name.strip_edges().left(MAX_NAME_LENGTH)
	var error = ""
	if player_name.is_empty():
		error = "Escribí un nombre"
	elif is_name_taken(player_name, id):
		error = "El nombre \"%s\" ya está en uso" % player_name
	elif color_index < 0 or color_index >= COLORS.size():
		error = "Elegí un color"
	elif is_color_taken(color_index, id):
		error = "Ese color ya lo eligió otro jugador"
	if error != "":
		_profile_result.rpc_id(id, false, error)
		return

	var is_new = not joined_players.has(id)
	var score = 0 if is_new else joined_players[id]["score"]
	joined_players[id] = {"name": player_name, "color": color_index, "score": score}
	_sync_player_list.rpc(joined_players, game_started)
	_profile_result.rpc_id(id, true, "")
	if is_new:
		player_added.emit(id)

func remove_player(id: int) -> void:
	if not joined_players.has(id):
		return
	joined_players.erase(id)
	player_removed.emit(id)
	if multiplayer.is_server():
		_sync_player_list.rpc(joined_players, game_started)

func start_game() -> void:
	if not multiplayer.is_server():
		return
	game_started = true
	_sync_player_list.rpc(joined_players, game_started)

func send_state_to(id: int) -> void:
	_sync_player_list.rpc_id(id, joined_players, game_started)

@rpc("any_peer", "call_local", "reliable")
func add_points_to_player(id: int, amount: int) -> void:
	if not multiplayer.is_server():
		return
		
	if joined_players.has(id):
		joined_players[id]["score"] += amount
		
		_sync_player_list.rpc(joined_players, game_started)
		print("El jugador ", id, " ahora tiene: ", joined_players[id]["score"])
		
		if joined_players[id]["score"] == 50:
			finish_level.emit()
			print("Meta alcanzada, cambiando nivel...")

@rpc("authority", "call_local", "reliable")
func _sync_player_list(server_data: Dictionary, started: bool) -> void:
	joined_players = server_data
	game_started = started
	players_changed.emit()

@rpc("authority", "call_local", "reliable")
func _profile_result(ok: bool, message: String) -> void:
	profile_result.emit(ok, message)
