extends SceneTree
## A race of one level with 7 bots (the host stays at the start): do they all
## make it to the finish line, how long does it take, how often (and where)
## do they lose? Gives up after 200 s.
##
##   godot --headless --path . -s tools/tests/bots_race.gd -- <level index> [--port=N]
##
## (level index: 0 = the first level in Main.levels). Prints one RESULT line.
## No class names here: this script is compiled before the game's autoloads

const TIME_LIMIT_MSEC = 200000

func say(message) -> void:
	print("[t %.1f] " % (Time.get_ticks_msec() / 1000.0), message)

func _initialize() -> void:
	var index = int(OS.get_cmdline_user_args()[0])
	var players_manager = root.get_node("PlayersManager")
	var race = root.get_node("RaceManager")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await create_timer(0.8).timeout
	current_scene.host_button.pressed.emit()
	await create_timer(0.6).timeout
	var lobby = current_scene.get_node("Lobby")
	lobby.name_edit.text = "Host"
	lobby._on_color_pressed(0)
	lobby._on_confirm_pressed()
	await create_timer(0.4).timeout
	players_manager.set_bots_enabled(true)
	players_manager.set_playlist([index])
	current_scene.start_game()
	while not race.can_move():
		await process_frame
	var level = current_scene.get_node("LevelContainer").get_child(0)
	var title = race.level_title
	var start = Time.get_ticks_msec()
	var times = {}
	var last_position = {}
	var deaths := 0
	# The host never moves, so the race has no time limit: whoever is in the
	# finish order crossed the line by themselves
	while times.size() < 7 and Time.get_ticks_msec() - start < TIME_LIMIT_MSEC:
		await physics_frame
		var elapsed = (Time.get_ticks_msec() - start) / 1000.0
		for id in race.finish_order:
			if not times.has(id):
				times[id] = elapsed
				say("finished: %d at %.1fs" % [id, elapsed])
		# A bot that suddenly is far from where it was lost and went back
		for player in get_nodes_in_group("player"):
			if not player.is_bot():
				continue
			var before = last_position.get(player.name, player.global_position)
			if player.global_position.distance_to(before) > 100 and not race.has_finished(player.name.to_int()):
				deaths += 1
				var near = []
				for node in level.find_children("*", "", true, false):
					if node is Node2D and (node is Area2D or node is AnimatableBody2D) and node.global_position.distance_to(before) < 60:
						near.append(node.name)
				say("%s died at %s near %s" % [player.name, before.round(), ", ".join(near.slice(0, 4))])
			last_position[player.name] = player.global_position
	var bot_times = times.values()
	print("RESULT level %d (%s): %d/7 bots finished, %d deaths, best %.1fs, worst %.1fs" % [index + 1, title,
		bot_times.size(), deaths, bot_times.min() if not bot_times.is_empty() else -1.0,
		bot_times.max() if not bot_times.is_empty() else -1.0])
	quit()
