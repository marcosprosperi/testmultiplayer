class_name Coin extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	pass # Replace with function body.

func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	if is_multiplayer_authority():
		if body.name.is_valid_int():
			var player_id = body.name.to_int()
			if PlayersManager.has_method("add_points_to_player"):
				PlayersManager.add_points_to_player.rpc(player_id, 1)
				_remove_coin.rpc()

@rpc("authority", "call_local", "reliable")
func _remove_coin() -> void:
	queue_free()
