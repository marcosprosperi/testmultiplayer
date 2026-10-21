extends Node

const MAX_NAME_LENGTH = 12
const MAX_GAME_NAME_LENGTH = 24
const COLORS = [
	Color("#e74c3c"), Color("#3498db"), Color("#2ecc71"), Color("#f1c40f"),
	Color("#9b59b6"), Color("#e67e22"), Color("#1abc9c"), Color("#ecf0f1"),
]

# Only players that confirmed a name and color:
# id -> {name, color, points, finishes}
# (points: championship, finishes: position in each race)
var joined_players = {}
var game_started := false
# Chosen by the host in the lobby
var settings = {"coins": true, "game_name": "", "checkpoints": false}

signal finish_level
signal players_changed
signal settings_changed
# Server only: a new player confirmed their profile
signal player_added(id: int)
# Server only
signal player_removed(id: int)
# Local: answer to request_profile
signal profile_result(ok: bool, message: String)

func reset() -> void:
	joined_players = {}
	game_started = false
	settings = {"coins": true, "game_name": "", "checkpoints": false}
	players_changed.emit()
	settings_changed.emit()

## Coins give extra points but slow you down (host option)
func coins_enabled() -> bool:
	return settings.get("coins", true)

## The name the host gave the game, or "Partida de <host>" if they left it empty
func game_display_name() -> String:
	var game_name = settings.get("game_name", "").strip_edges()
	if game_name != "":
		return game_name
	return "Partida de %s" % name_of(1) if has_player(1) else "Partida nueva"

## Host only
func set_game_name(game_name: String) -> void:
	if multiplayer.is_server():
		settings["game_name"] = game_name.strip_edges().left(MAX_GAME_NAME_LENGTH)
		_sync_settings.rpc(settings)

## Losing sends you back to the last flag you touched instead of the start
func checkpoints_enabled() -> bool:
	return settings.get("checkpoints", false)

## Host only
func set_checkpoints_enabled(enabled: bool) -> void:
	if multiplayer.is_server():
		settings["checkpoints"] = enabled
		_sync_settings.rpc(settings)

## Host only
func set_coins_enabled(enabled: bool) -> void:
	if multiplayer.is_server():
		settings["coins"] = enabled
		_sync_settings.rpc(settings)

@rpc("authority", "call_local", "reliable")
func _sync_settings(server_settings: Dictionary) -> void:
	settings = server_settings
	settings_changed.emit()

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
	var points = 0 if is_new else joined_players[id]["points"]
	var finishes = [] if is_new else joined_players[id]["finishes"]
	joined_players[id] = {"name": player_name, "color": color_index,
		"points": points, "finishes": finishes}
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

func points_of(id: int) -> int:
	return joined_players[id]["points"] if joined_players.has(id) else 0

## Server only: championship points for finishing a race in `position`
func add_race_result(id: int, position: int, amount: int) -> void:
	if multiplayer.is_server() and joined_players.has(id):
		joined_players[id]["points"] += amount
		joined_players[id]["finishes"].append(position)
		_sync_player_list.rpc(joined_players, game_started)

## Server only: a new championship starts
func reset_points() -> void:
	if not multiplayer.is_server():
		return
	for id in joined_players:
		joined_players[id]["points"] = 0
		joined_players[id]["finishes"] = []
	_sync_player_list.rpc(joined_players, game_started)

## Ids in championship order (see is_ahead)
func standings() -> Array:
	var ids = joined_players.keys()
	ids.sort_custom(func(a, b): return is_ahead(joined_players[a], joined_players[b]))
	return ids

## Championship order between two players ({points, finishes}): more points;
## tied on points, more wins, then more 2nd places, and so on (like F1);
## still tied, whoever did better in the last race
static func is_ahead(a: Dictionary, b: Dictionary) -> bool:
	if a.points != b.points:
		return a.points > b.points
	for position in range(1, NetworkManager.MAX_PLAYERS + 1):
		var a_count = a.finishes.count(position)
		var b_count = b.finishes.count(position)
		if a_count != b_count:
			return a_count > b_count
	if not a.finishes.is_empty() and not b.finishes.is_empty():
		return a.finishes[-1] < b.finishes[-1]
	return false

func send_state_to(id: int) -> void:
	_sync_player_list.rpc_id(id, joined_players, game_started)
	_sync_settings.rpc_id(id, settings)

@rpc("authority", "call_local", "reliable")
func _sync_player_list(server_data: Dictionary, started: bool) -> void:
	joined_players = server_data
	game_started = started
	players_changed.emit()

@rpc("authority", "call_local", "reliable")
func _profile_result(ok: bool, message: String) -> void:
	profile_result.emit(ok, message)
