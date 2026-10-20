@tool
class_name TrapButton extends Area2D

## Plate on the floor that fires the traps in `targets`, further ahead in the
## course. Whoever is in front passes it first and can only hurt themselves,
## so it's a way for the players at the back to catch up. Everyone sees who
## pressed it, and the traps blink before they go off.

const WIDTH = 24.0

## Traps (Trap nodes) to fire
@export var targets: Array[NodePath] = []:
	set(value):
		targets = value
		queue_redraw()
## Seconds before it can be used again
@export var cooldown := 6.0

var _cooldown_left := 0.0

func _ready() -> void:
	var shape = RectangleShape2D.new()
	shape.size = Vector2(WIDTH - 4.0, 6.0)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = Vector2(0, -3)
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	queue_redraw()

# The server sees every player, so it decides when the plate is pressed
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server() or _cooldown_left > 0.0 or not body is Player:
		return
	if RaceManager.state != RaceManager.State.RACING:
		return
	_press.rpc(body.name.to_int())

@rpc("authority", "call_local", "reliable")
func _press(id: int) -> void:
	_cooldown_left = cooldown
	for path in targets:
		var trap = get_node_or_null(path)
		if trap and trap.has_method("trigger"):
			trap.trigger()
	RaceManager.trap_triggered.emit(id)
	Sfx.play_at("click", global_position)

func _draw() -> void:
	var ready = _cooldown_left <= 0.0 or Engine.is_editor_hint()
	# Base and button
	draw_rect(Rect2(-WIDTH / 2.0, -3, WIDTH, 3), Color(0.25, 0.25, 0.3))
	var button_height = 4.0 if ready else 1.5
	draw_rect(Rect2(-WIDTH / 2.0 + 3, -3 - button_height, WIDTH - 6, button_height), Color("#e74c3c") if ready else Color(0.5, 0.5, 0.5))
	if not ready:
		# Recharge bar
		var progress = 1.0 - _cooldown_left / cooldown
		draw_rect(Rect2(-WIDTH / 2.0, 2, WIDTH * progress, 2), Color("#f1c40f"))
	# Little warning sign on a post
	draw_line(Vector2(-WIDTH / 2.0 - 4, 0), Vector2(-WIDTH / 2.0 - 4, -18), Color(0.4, 0.3, 0.2), 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-WIDTH / 2.0 - 10, -17), Vector2(-WIDTH / 2.0 + 2, -17), Vector2(-WIDTH / 2.0 - 4, -27)]), Color("#f1c40f"))
	draw_line(Vector2(-WIDTH / 2.0 - 4, -24), Vector2(-WIDTH / 2.0 - 4, -20), Color.BLACK, 1.0)
	# In the editor, a line to each trap it fires
	if Engine.is_editor_hint():
		for path in targets:
			var trap = get_node_or_null(path)
			if trap:
				draw_dashed_line(Vector2.ZERO, to_local(trap.global_position), Color(1, 0.3, 0.3, 0.7), 1.0, 6.0)
