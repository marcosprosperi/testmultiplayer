@tool
class_name TrapDoor extends Trap

## Wooden floor over a pit that opens for a while. Put it over a gap in the
## floor; the node's position is the gap's top-left corner.

const TILE = 16.0
const WOOD = Color("#a0703c")
const WOOD_DARK = Color("#6b4423")

@export_range(1, 16) var tiles := 4:
	set(value):
		tiles = value
		_update_shape()

@onready var floor_collision: CollisionShape2D = $Floor/CollisionShape2D

func _ready() -> void:
	_update_shape()

func _update_shape() -> void:
	if not is_inside_tree():
		return
	var shape = RectangleShape2D.new()
	shape.size = Vector2(tiles * TILE, TILE)
	$Floor/CollisionShape2D.shape = shape
	$Floor/CollisionShape2D.position = Vector2(tiles * TILE / 2.0, TILE / 2.0)

func _on_phase_changed(new_phase: Phase) -> void:
	floor_collision.set_deferred("disabled", new_phase == Phase.ACTIVE)
	if new_phase == Phase.ACTIVE:
		Sfx.play_at("crack", global_position)

func _draw() -> void:
	var width = tiles * TILE
	if phase == Phase.ACTIVE and not Engine.is_editor_hint():
		# Open: the two halves hang down from the sides
		draw_rect(Rect2(0, 0, 4, TILE * 1.5), WOOD)
		draw_rect(Rect2(width - 4, 0, 4, TILE * 1.5), WOOD)
		return
	var shake = Vector2(randf_range(-1, 1), 0) if phase == Phase.WARNING else Vector2.ZERO
	for i in tiles:
		var plank = Rect2(Vector2(i * TILE, 0) + shake, Vector2(TILE - 1, TILE - 4))
		draw_rect(plank, WOOD_DARK if is_warning_blink_on() else WOOD)
		draw_rect(plank, WOOD_DARK, false, 1.0)
	# Hinge line in the middle
	draw_line(Vector2(width / 2.0, 0) + shake, Vector2(width / 2.0, TILE - 4) + shake, WOOD_DARK, 1.0)
