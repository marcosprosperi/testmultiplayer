class_name Spectator extends Label

## Once the local player crosses the finish line, follow the players that are
## still racing. Left / right switch between them.

var watched: Player

func _process(_delta: float) -> void:
	if !Hud.is_connected_to_game(multiplayer):
		return
	var local = _local_player()
	if local == null or !RaceManager.has_finished(local.name.to_int()):
		_watch(local)
		text = ""
		return

	var racing = _racing_players()
	if racing.is_empty():
		_watch(local)
		_set_text("¡Llegaron todos! Próximo nivel...", Color.WHITE)
		return

	var index = max(racing.find(watched), 0)
	if Input.is_action_just_pressed("right"):
		index += 1
	elif Input.is_action_just_pressed("left"):
		index -= 1
	index = posmod(index, racing.size())
	_watch(racing[index])

	var id = watched.name.to_int()
	var missing = "falta 1" if racing.size() == 1 else "faltan %d" % racing.size()
	var arrows = "◀ A   D ▶  " if racing.size() > 1 else ""
	_set_text("%sViendo a %s (%s)" % [arrows, Hud.name_for(id), missing], Hud.color_for(id))

func _watch(player: Player) -> void:
	if player == watched:
		return
	# Remote players' cameras stay off unless someone is spectating them
	if is_instance_valid(watched) and !watched.is_multiplayer_authority():
		watched.camera_2d.enabled = false
	watched = player
	if is_instance_valid(watched):
		watched.camera_2d.enabled = true
		watched.camera_2d.make_current()

func _set_text(value: String, color: Color) -> void:
	text = value
	add_theme_color_override("font_color", color)

func _local_player() -> Player:
	for player in get_tree().get_nodes_in_group("player"):
		if player.is_multiplayer_authority():
			return player
	return null

func _racing_players() -> Array:
	var racing = get_tree().get_nodes_in_group("player").filter(
		func(p): return !RaceManager.has_finished(p.name.to_int()))
	racing.sort_custom(func(a, b): return a.name.to_int() < b.name.to_int())
	return racing
