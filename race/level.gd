class_name Level extends Node2D

# Runs on every peer when the level is spawned
func _ready() -> void:
	RaceManager.register_level(self)
	# Players already in the game (level change) go back to the new start
	for player in get_tree().get_nodes_in_group("player"):
		if player.is_multiplayer_authority():
			player.respawn()
	RaceManager.notify_local_ready()
