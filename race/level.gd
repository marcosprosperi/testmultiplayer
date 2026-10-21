class_name Level extends Node2D

## Below 1 shows more of the level, but shrinking pixel art drops pixels:
## prefer camera_offset to see more in one direction
@export var camera_zoom := 1.0
## Moves the view relative to the player, e.g. (0, -60) to see more above
@export var camera_offset := Vector2.ZERO
@export var background_color := Color(0.3, 0.3, 0.3)

# Runs on every peer when the level is spawned
func _ready() -> void:
	RaceManager.register_level(self)
	RenderingServer.set_default_clear_color(background_color)
	for player in get_tree().get_nodes_in_group("player"):
		player.camera_2d.zoom = Vector2.ONE * camera_zoom
		player.camera_2d.offset = camera_offset
		# Players already in the game (level change) go back to the new start
		if player.is_multiplayer_authority():
			player.respawn()
	RaceManager.notify_local_ready()
