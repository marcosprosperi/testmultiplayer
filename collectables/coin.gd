extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	pass # Replace with function body.

func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
		
	if body.name.is_valid_int():
		var player_id = body.name.to_int()
		NetworkManager.collect_coin.rpc(player_id, 10)
		queue_free()
	pass
