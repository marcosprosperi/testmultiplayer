extends Node2D
@onready var playersSpawner: Node = $Players
@export var player_scene: PackedScene = preload("res://scenes/player.tscn")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if multiplayer.is_server():
		create_player(1)
		for id in NetworkManager.players:
			create_player(id)
	

func create_player(id: int) -> void:
	var new_player = player_scene.instantiate()
	new_player.name = str(id)
	playersSpawner.add_child(new_player)
	
	
