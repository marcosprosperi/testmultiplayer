class_name KillZone extends Area2D

## Any player touching this area loses and starts again from the beginning.
## Give it a CollisionShape2D child with the shape of the trap / pit.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Each player's own peer moves it, so that peer handles the death
	if body is Player and body.is_multiplayer_authority():
		body.die()
