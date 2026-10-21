class_name Main extends Node

@onready var level_container: Node = $LevelContainer	
@onready var players: Node = $Players
# Make sure this Spawner points to the "Players" node in the editor!
@onready var players_spawner: MultiplayerSpawner = $PlayersSpawner
@onready var level_spawner: MultiplayerSpawner = $LevelMultiplayerSpawner

## Every level that can be played (LevelInfo: title, difficulty, scene).
## The host picks which ones and in what order in the lobby
@export var levels: Array[Resource] = []
@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

# Server only: indices into `levels` for this championship, and which one is on
var playlist: Array = []
var current_round := 0

func _ready() -> void:
	# Every level in the list can be replicated to the clients
	for info in levels:
		level_spawner.add_spawnable_scene(info.scene.resource_path)
	PlayersManager.player_added.connect(_on_player_added)
	PlayersManager.player_removed.connect(_on_player_removed)
	PlayersManager.finish_level.connect(_on_level_finished)
	PlayersManager.championship_over.connect(_return_to_lobby)
	# Host or join now that the spawners exist
	NetworkManager.start()

## Host only: called from the lobby
func start_game() -> void:
	if not multiplayer.is_server() or PlayersManager.game_started:
		return
	playlist = PlayersManager.get_playlist().filter(func(i): return i >= 0 and i < levels.size())
	if playlist.is_empty():
		playlist = default_playlist()
	PlayersManager.reset_points()
	PlayersManager.start_game()
	current_round = 0
	RaceManager.set_round(current_round, playlist.size())
	change_level(levels[playlist[current_round]].scene)
	for id in PlayersManager.joined_players:
		create_player(id)

## All levels, easiest first
func default_playlist() -> Array:
	var order = range(levels.size())
	order.sort_custom(func(a, b): return levels[a].difficulty < levels[b].difficulty \
		or (levels[a].difficulty == levels[b].difficulty and a < b))
	return order

# Server: the championship ended, everyone goes back to the lobby (still
# connected, with their name and color) to change things and play again
func _return_to_lobby() -> void:
	if not multiplayer.is_server():
		return
	for child in level_container.get_children():
		level_container.remove_child(child)
		child.queue_free()
	for player in players.get_children():
		player.queue_free()
	RaceManager.end_championship()
	PlayersManager.stop_game()

func create_player(id: int) -> void:
	if not multiplayer.is_server() or players.has_node(str(id)):
		return
		
	var new_player = player_scene.instantiate()
	if new_player:
		# CRITICAL FIX: Name must be exactly the ID for authority to work easily
		new_player.name = str(id) 
		players.add_child(new_player)
		# The Spawner will automatically replicate this to clients
		# because "players" is the spawn_path

# A player confirmed name and color; late joiners enter the race right away
func _on_player_added(id: int):
	if multiplayer.is_server() and PlayersManager.game_started:
		create_player(id)

func _on_player_removed(id: int):
	if multiplayer.is_server() and players.has_node(str(id)):
		players.get_node(str(id)).queue_free()

func change_level(level_scene: PackedScene):
	# Remove old level
	# (taken out of the tree right away so the new one can reuse its name)
	for child in level_container.get_children():
		if child.is_in_group("Level"):
			level_container.remove_child(child)
			child.queue_free()
	
	# Instantiate new level
	var new_level = level_scene.instantiate()
	if new_level:
		level_container.add_child(new_level, true)
		new_level.add_to_group("Level")
	
func _on_level_finished():
	if multiplayer.is_server():
		current_round = mini(current_round + 1, playlist.size() - 1)
		RaceManager.set_round(current_round, playlist.size())
		# Using call_deferred is safer for physics/scene tree changes
		call_deferred("change_level", levels[playlist[current_round]].scene)
