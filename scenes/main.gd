class_name Main extends Node

@onready var level_container: Node = $LevelContainer	
@onready var players: Node = $Players
# Make sure this Spawner points to the "Players" node in the editor!
@onready var players_spawner: MultiplayerSpawner = $PlayersSpawner
@onready var level_spawner: MultiplayerSpawner = $LevelMultiplayerSpawner

## Levels in play order; after the last one it goes back to the first
@export var levels: Array[PackedScene] = []
@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

var current_level_index := 0

func _ready() -> void:
	# Every level in the list can be replicated to the clients
	for level in levels:
		level_spawner.add_spawnable_scene(level.resource_path)
	PlayersManager.player_added.connect(_on_player_added)
	PlayersManager.player_removed.connect(_on_player_removed)
	PlayersManager.finish_level.connect(_on_level_finished)
	# Host or join now that the spawners exist
	NetworkManager.start()

## Host only: called from the lobby
func start_game() -> void:
	if not multiplayer.is_server() or PlayersManager.game_started:
		return
	PlayersManager.start_game()
	current_level_index = 0
	change_level(levels[current_level_index])
	for id in PlayersManager.joined_players:
		create_player(id)

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
		current_level_index = (current_level_index + 1) % levels.size()
		# Using call_deferred is safer for physics/scene tree changes
		call_deferred("change_level", levels[current_level_index])
