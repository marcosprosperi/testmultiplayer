@tool
class_name Crusher extends Trap

## Stone block hanging over the floor that slams down, stays down for a
## moment (you can climb on it) and slowly goes back up. The node's
## position is the floor point under the block's center.

const SIZE = Vector2(32, 32)
const STONE = Color("#7d8494")

## How high the block hangs over the floor when resting
@export var height := 64.0
@export var slam_time := 0.15
@export var rise_time := 1.2
## Length of the chain above the block when resting (shorter under a ceiling)
@export var chain_length := 200.0

@onready var block: AnimatableBody2D = $Block
@onready var kill: KillZone = $Block/Kill
@onready var block_collision: CollisionShape2D = $Block/CollisionShape2D

func _ready() -> void:
	block.position = Vector2(0, -height - SIZE.y / 2.0)
	if not Engine.is_editor_hint():
		set_deadly(kill, false)

func _on_phase_changed(new_phase: Phase) -> void:
	if new_phase == Phase.ACTIVE:
		# While falling it doesn't push players aside: it squashes them
		set_deadly(kill, true)
		block_collision.set_deferred("disabled", true)
		var slam = create_tween()
		slam.tween_property(block, "position:y", -SIZE.y / 2.0, slam_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		slam.tween_interval(0.05)
		slam.tween_callback(func():
			set_deadly(kill, false)
			# Down on the floor it's solid again: you can climb on it
			block_collision.set_deferred("disabled", false)
			Sfx.play_at("slam", global_position))
	elif new_phase == Phase.IDLE:
		var rise = create_tween()
		rise.tween_property(block, "position:y", -height - SIZE.y / 2.0, rise_time)

func _draw() -> void:
	# Chain from the ceiling
	var top = -height - SIZE.y - chain_length
	draw_line(Vector2(0, top), block.position - Vector2(0, SIZE.y / 2.0), Color(0.3, 0.3, 0.35), 2.0)
	var rect = Rect2(block.position - SIZE / 2.0, SIZE)
	var color = Color("#c0392b") if is_warning_blink_on() else STONE
	draw_rect(rect, color)
	draw_rect(rect, Color(0.25, 0.27, 0.32), false, 2.0)
	# Teeth at the bottom
	for i in 4:
		var x = rect.position.x + i * 8.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, rect.end.y), Vector2(x + 4, rect.end.y + 4), Vector2(x + 8, rect.end.y)]), Color(0.25, 0.27, 0.32))
	# Angry eyes
	draw_rect(Rect2(rect.position + Vector2(7, 10), Vector2(6, 4)), Color.BLACK)
	draw_rect(Rect2(rect.position + Vector2(19, 10), Vector2(6, 4)), Color.BLACK)
