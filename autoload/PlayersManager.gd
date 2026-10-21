extends Node

const MAX_NAME_LENGTH = 12
const MAX_GAME_NAME_LENGTH = 24
const MAX_PLAYERS = 8
const BOT_NAMES = ["Bot Turbo", "Bot Chispa", "Bot Tuerca", "Bot Pixel", "Bot Rayo", "Bot Byte", "Bot Cohete", "Bot Rulo"]
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
# levels: indices into Main.levels in play order ([] = all, easiest first)
var settings = {"coins": true, "game_name": "", "checkpoints": false, "levels": [], "bots": false, "items": true}
# Server only: how good each bot is (0..1)
var _bot_skills = {}

signal finish_level
# Server only: the last race of the championship ended
signal championship_over
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
	settings = {"coins": true, "game_name": "", "checkpoints": false, "levels": [], "bots": false, "items": true}
	_bot_skills.clear()
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

func get_playlist() -> Array:
	return settings.get("levels", [])

## Host only
func set_playlist(level_indices: Array) -> void:
	if multiplayer.is_server():
		settings["levels"] = level_indices
		_sync_settings.rpc(settings)

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

# Bots never block a person: if someone picks a bot's name or color, the bot
# leaves to make room (see request_profile)
func is_name_taken(player_name: String, except_id := 0) -> bool:
	for id in joined_players:
		if id >= 0 and id != except_id and joined_players[id]["name"].to_lower() == player_name.strip_edges().to_lower():
			return true
	return false

func is_color_taken(color_index: int, except_id := 0) -> bool:
	for id in joined_players:
		if id >= 0 and id != except_id and joined_players[id]["color"] == color_index:
			return true
	return false

func is_bot(id: int) -> bool:
	return id < 0

func items_enabled() -> bool:
	return settings.get("items", true)

## Host only: power-up boxes on or off
func set_items_enabled(enabled: bool) -> void:
	if multiplayer.is_server():
		settings["items"] = enabled
		_sync_settings.rpc(settings)

func bots_enabled() -> bool:
	return settings.get("bots", false)

## Host only
func set_bots_enabled(enabled: bool) -> void:
	if multiplayer.is_server():
		settings["bots"] = enabled
		_sync_settings.rpc(settings)

func bot_skill(id: int) -> float:
	return _bot_skills.get(id, 0.85)

## Server only: fill the race up to MAX_PLAYERS with bots
func add_bots() -> void:
	if not multiplayer.is_server():
		return
	var free_colors = range(COLORS.size()).filter(func(c): return not is_color_taken(c))
	var free_names = BOT_NAMES.filter(func(n): return not is_name_taken(n))
	var count = mini(MAX_PLAYERS - joined_players.size(), mini(free_colors.size(), free_names.size()))
	for i in count:
		var id = -(i + 1)
		joined_players[id] = {"name": free_names[i], "color": free_colors[i], "points": 0, "finishes": []}
		_bot_skills[id] = randf_range(0.75, 0.95)
	_sync_player_list.rpc(joined_players, game_started)

## Server only
func remove_bots() -> void:
	if not multiplayer.is_server():
		return
	for id in joined_players.keys().filter(func(i): return i < 0):
		remove_player(id)
	_bot_skills.clear()

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

	# A bot using that name or color leaves to make room (and one leaves if
	# the race is full)
	var bots = joined_players.keys().filter(func(i): return i < 0)
	for bot in bots:
		if joined_players[bot]["color"] == color_index or joined_players[bot]["name"].to_lower() == player_name.to_lower():
			remove_player(bot)
	bots = joined_players.keys().filter(func(i): return i < 0)
	if not joined_players.has(id) and not bots.is_empty() and joined_players.size() >= MAX_PLAYERS:
		bots.sort()
		remove_player(bots[0])

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

## Server only: back to the lobby
func stop_game() -> void:
	if not multiplayer.is_server():
		return
	game_started = false
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
