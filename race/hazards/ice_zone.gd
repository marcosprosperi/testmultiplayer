@tool
class_name IceZone extends Area2D

## Strip of ice on top of the floor: players on it slide (they speed up and
## stop slowly). Place it on the surface; it covers `tiles` tiles to the right.

@export var tiles := 8:
	set(value):
		tiles = value
		_update_shape()
		queue_redraw()

const ICE = Color(0.72, 0.9, 1.0, 0.9)
const SHINE = Color(1, 1, 1, 0.85)

func _ready() -> void:
	_update_shape()
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	add_to_group("ice")

func _update_shape() -> void:
	if not is_inside_tree():
		return
	var collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		add_child(collision)
	var shape = RectangleShape2D.new()
	shape.size = Vector2(tiles * 16, 8)
	collision.shape = shape
	collision.position = Vector2(tiles * 8, -2)

func _draw() -> void:
	var width = tiles * 16.0
	draw_rect(Rect2(0, -1, width, 4), ICE)
	draw_line(Vector2(0, -1), Vector2(width, -1), SHINE, 1.0)
	# Little glints
	for i in tiles:
		if i % 3 == 1:
			draw_line(Vector2(i * 16 + 4, 1), Vector2(i * 16 + 9, 1), SHINE, 1.0)
