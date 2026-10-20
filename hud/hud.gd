class_name Hud extends CanvasLayer

const PLAYER_COLORS = [
	Color("#e74c3c"), Color("#3498db"), Color("#2ecc71"), Color("#f1c40f"),
	Color("#9b59b6"), Color("#e67e22"), Color("#1abc9c"), Color("#ecf0f1"),
]

@onready var race_track: RaceTrack = $RaceTrack
@onready var position_label: Label = $PositionLabel

func _process(_delta: float) -> void:
	if !is_connected_to_game(multiplayer):
		return
	var ranking = get_ranking()
	race_track.entries = _track_entries()
	_update_position_label(ranking)

static func is_connected_to_game(api: MultiplayerAPI) -> bool:
	return api.has_multiplayer_peer() \
		and api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

static func color_for(id: int) -> Color:
	return PLAYER_COLORS[_player_index(id) % PLAYER_COLORS.size()]

static func name_for(id: int) -> String:
	return "Jugador %d" % (_player_index(id) + 1)

# Stable number for each player, by join order (peer ids sorted)
static func _player_index(id: int) -> int:
	var ids = PlayersManager.joined_players.keys()
	ids.sort()
	return max(ids.find(id), 0)

## Players that finished keep their arrival order, the rest go by progress
func get_ranking() -> Array:
	var players = get_tree().get_nodes_in_group("player")
	players.sort_custom(func(a, b):
		var a_id = a.name.to_int()
		var b_id = b.name.to_int()
		var a_done = RaceManager.has_finished(a_id)
		var b_done = RaceManager.has_finished(b_id)
		if a_done and b_done:
			return RaceManager.finish_order.find(a_id) < RaceManager.finish_order.find(b_id)
		if a_done != b_done:
			return a_done
		return RaceManager.get_progress(a) > RaceManager.get_progress(b))
	return players

func _track_entries() -> Array:
	var entries = []
	for player in get_tree().get_nodes_in_group("player"):
		var id = player.name.to_int()
		entries.append({
			"progress": 1.0 if RaceManager.has_finished(id) else RaceManager.get_progress(player),
			"color": color_for(id),
			"is_local": player.is_multiplayer_authority(),
		})
	# Draw the local player last so it stays on top
	entries.sort_custom(func(a, b): return !a.is_local and b.is_local)
	return entries

func _update_position_label(ranking: Array) -> void:
	var local_index = ranking.find_custom(func(p): return p.is_multiplayer_authority())
	if local_index == -1:
		position_label.text = ""
		return
	var place = "%dº / %d" % [local_index + 1, ranking.size()]
	var local_id = ranking[local_index].name.to_int()
	if RaceManager.has_finished(local_id):
		position_label.text = "¡Meta! " + place
	else:
		position_label.text = place
