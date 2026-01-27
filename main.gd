extends Node

@onready var level_container: Node = $LevelContainer	
@onready var players: Node = $Players
# Make sure this Spawner points to the "Players" node in the editor!
@onready var players_spawner: MultiplayerSpawner = $PlayersSpawner
@onready var level_spawner: MultiplayerSpawner = $LevelMultiplayerSpawner

const LEVEL_1 = preload("uid://bxwdv7rjp1mf5")
const LEVEL_2 = preload("uid://cibp8iksdlty") # Ensure this UID is correct or use res:// path

@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

func _ready() -> void:
	# Only the server should spawn the initial level to ensure sync via Spawner
	if multiplayer.is_server():
		change_level(LEVEL_1)
		
		PlayersManager.player_added.connect(_on_player_added)
		# Spawn existing players (like the host)
		for id in PlayersManager.joined_players:
			create_player(id)
	
	PlayersManager.finish_level.connect(_on_level_finished)

func create_player(id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var new_player = player_scene.instantiate()
	if new_player:
		# CRITICAL FIX: Name must be exactly the ID for authority to work easily
		new_player.name = str(id) 
		players.add_child(new_player)
		# The Spawner will automatically replicate this to clients
		# because "players" is the spawn_path

func _on_player_added(id: int):
	if multiplayer.is_server():
		create_player(id)

func change_level(level_scene: PackedScene):
	# Remove old level
	for child in level_container.get_children():
		if child.is_in_group("Level"):
			child.queue_free()
	
	# Instantiate new level
	var new_level = level_scene.instantiate()
	if new_level:
		level_container.add_child(new_level)
		new_level.add_to_group("Level")
	
func _on_level_finished():
	if multiplayer.is_server():
		# Using call_deferred is safer for physics/scene tree changes
		call_deferred("change_level", LEVEL_2)
