class_name Balloon extends AnimatableBody2D

## A balloon you can stand on. You can jump through it from below (one-way
## collision on its top). BalloonColumn moves it.

const WIDTH = 30.0
const HEIGHT = 34.0

var color := Color("#e74c3c")
var _collision: CollisionShape2D

func _init() -> void:
	collision_layer = 512
	collision_mask = 0
	_collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(WIDTH - 4.0, 6.0)
	_collision.shape = shape
	_collision.position = Vector2(0, 3)
	_collision.one_way_collision = true
	add_child(_collision)

func set_solid(solid: bool) -> void:
	_collision.set_deferred("disabled", not solid)

# The top of the balloon is at y = 0, where players stand
func _draw() -> void:
	var center = Vector2(0, HEIGHT / 2.0)
	var points = PackedVector2Array()
	for i in 24:
		var angle = i * TAU / 24.0
		points.append(center + Vector2(cos(angle) * WIDTH / 2.0, sin(angle) * HEIGHT / 2.0))
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), color.darkened(0.4), 1.0)
	# Shine and knot
	draw_circle(center + Vector2(-6, -7), 3.0, Color(1, 1, 1, 0.5))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, HEIGHT + 3), Vector2(3, HEIGHT + 3), Vector2(0, HEIGHT - 1)]), color.darkened(0.3))
	# String
	var string = PackedVector2Array()
	for i in 8:
		string.append(Vector2(sin(i * 1.3) * 2.0, HEIGHT + 3 + i * 3.0))
	draw_polyline(string, Color(1, 1, 1, 0.6), 1.0)
