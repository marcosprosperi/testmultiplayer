@tool
class_name Checkpoint extends Area2D

## Flag: if the host turned checkpoints on, losing after touching it sends you
## back here instead of to the start. It shows your color once you touched it.
## The node's position is the floor under the pole.

var _reached := false

func _ready() -> void:
	var shape = RectangleShape2D.new()
	shape.size = Vector2(16, 40)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = Vector2(0, -20)
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	body_entered.connect(_on_body_entered)
	PlayersManager.settings_changed.connect(_apply_setting)
	_apply_setting()

func _apply_setting() -> void:
	visible = PlayersManager.checkpoints_enabled()
	set_deferred("monitoring", visible)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and body.is_multiplayer_authority():
		body.checkpoint = global_position + Vector2(0, -2)
		if body.is_local() and not _reached:
			_reached = true
			Fx.spawn(Fx.SPARKLE, global_position + Vector2(0, -30), PlayersManager.color_of(body.name.to_int()))
			Sfx.play("coin", -4.0)
			queue_redraw()

func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(0, -36), Color(0.75, 0.75, 0.8), 2.0)
	var color = Color(0.5, 0.5, 0.55)
	if _reached:
		color = PlayersManager.color_of(multiplayer.get_unique_id())
	draw_colored_polygon(PackedVector2Array([Vector2(1, -36), Vector2(16, -31), Vector2(1, -26)]), color)
	draw_circle(Vector2(0, -37), 2.0, Color(0.9, 0.85, 0.4))
