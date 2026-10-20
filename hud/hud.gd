class_name Hud extends CanvasLayer

@onready var race_track: RaceTrack = $RaceTrack
@onready var position_label: Label = $PositionLabel

func _process(_delta: float) -> void:
	# Only shown while the local player is racing (not in the lobby)
	visible = is_connected_to_game(multiplayer) and get_tree().get_nodes_in_group("player").any(
		func(p): return p.is_multiplayer_authority())
	if !visible:
		return
	var ranking = get_ranking()
	race_track.entries = _track_entries()
	_update_position_label(ranking)

static func is_connected_to_game(api: MultiplayerAPI) -> bool:
	return api.has_multiplayer_peer() \
		and api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

static func color_for(id: int) -> Color:
	return PlayersManager.color_of(id)

static func name_for(id: int) -> String:
	return PlayersManager.name_of(id)

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
