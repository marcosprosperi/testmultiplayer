extends SceneTree
## A host and a guest on the same PC playing over the network: joining, how
## the other player moves on each screen, losing and coming back, the time
## limit, the next race, the host going back to the lobby and racing again.
## Run one of each at the same time and read what both print:
##
##   godot --headless --path . -s tools/tests/two_players.gd -- host &
##   godot --headless --path . -s tools/tests/two_players.gd -- client
##
## No class names here: this script is compiled before the game's autoloads

var role := ""

func say(message) -> void:
	print("[", role, " %.1f] " % (Time.get_ticks_msec() / 1000.0), message)

func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	var network = root.get_node("NetworkManager")
	var race = root.get_node("RaceManager")
	var players_manager = root.get_node("PlayersManager")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await create_timer(1.0).timeout
	if role == "host":
		current_scene.host_button.pressed.emit()
	else:
		await create_timer(0.7).timeout
		network.join_game("127.0.0.1")
	await create_timer(1.8).timeout
	if not current_scene.has_node("Lobby"):
		say("NOT IN THE GAME: %s" % (current_scene.error_label.text if "error_label" in current_scene else current_scene.name))
		quit()
		return
	var lobby = current_scene.get_node("Lobby")
	lobby.name_edit.text = "Ana" if role == "host" else "Beto"
	lobby._on_color_pressed(0 if role == "host" else 1)
	lobby._on_confirm_pressed()
	await create_timer(1.0).timeout
	if role == "host":
		players_manager.set_playlist([1, 0])
		current_scene.start_game()
	while not race.can_move():
		await process_frame
	var my_id = root.multiplayer.get_unique_id()
	var me = current_scene.players.get_node(str(my_id))
	var other = get_nodes_in_group("player").filter(func(p): return p != me)[0]
	say("racing with %s" % [root.multiplayer.get_peers()])

	# The guest runs for 2 s; the host watches its copy glide after it
	if role == "client":
		Input.action_press("right")
		await create_timer(2.0).timeout
		Input.action_release("right")
		say("ran to x=%d" % me.global_position.x)
	else:
		var worst_gap := 0.0
		var biggest_step := 0.0
		var last = other.position
		for i in 120:
			await physics_frame
			worst_gap = maxf(worst_gap, other.position.distance_to(other.net_position))
			biggest_step = maxf(biggest_step, other.position.distance_to(last))
			last = other.position
		say("the guest's copy: worst gap %.1f px (expect < 48), biggest step %.1f px (expect < 10)" % [worst_gap, biggest_step])
	await create_timer(0.5).timeout

	# The guest loses and comes back at the start: its copy appears there
	if role == "client":
		me.die(true)
	await create_timer(1.0).timeout
	say("the guest is at x=%d (expect the start)" % (me if role == "client" else other).position.x)

	# Still connected after the "which version are you" wait
	await create_timer(3.0).timeout
	say("still with %s" % [root.multiplayer.get_peers()])

	# The host crosses the line: the guest gets a time limit (cut short here)
	if role == "host":
		me.global_position = race.get_finish().global_position + Vector2(0, -6)
		await create_timer(0.6).timeout
		say("finished: %s, time left %.0f s (expect 119)" % [race.has_finished(my_id), race.time_left()])
		race._set_deadline(3.0)
	else:
		await create_timer(1.2).timeout
		say("time left %.1f s (expect under 3)" % race.time_left())
	await create_timer(4.0).timeout
	say("finish order %s (expect both)" % [race.finish_order])

	# The next race starts by itself; then the host takes everyone to the lobby
	await create_timer(9.0).timeout
	say("race %d: %s, moving: %s" % [race.round_index + 1, race.level_title, race.can_move()])
	if role == "host":
		current_scene.return_to_lobby()
	await create_timer(2.0).timeout
	say("in the lobby: %s, level: %s, players: %d, still with %s" % [current_scene.get_node("Lobby").visible,
		is_instance_valid(race.current_level), get_nodes_in_group("player").size(), root.multiplayer.get_peers()])

	# And a new championship works
	await create_timer(1.5).timeout
	if role == "host":
		current_scene.start_game()
	await create_timer(6.0).timeout
	say("racing again: %s, players: %d (expect 2)" % [race.can_move(), get_nodes_in_group("player").size()])
	# Nobody leaves before the other one has looked
	await create_timer(1.5).timeout
	quit()
