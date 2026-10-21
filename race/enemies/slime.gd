@tool
class_name Slime extends Enemy

## Slow green blob. Land on it to squash it.

const COLOR = Color("#5fcf5a")
const DARK = Color("#2f7d3a")

func _init() -> void:
	stompable = true
	body_height = 10.0

func _draw() -> void:
	super()
	var state = draw_state()
	if state == "gone":
		return
	var t = Time.get_ticks_msec() / 1000.0
	var squash = 0.25 if state == "squashed" else 1.0 + sin(t * 8.0) * 0.08
	var h = 10.0 * squash
	var w = 16.0 / sqrt(squash)
	var points = PackedVector2Array()
	for i in 13:
		var a = PI + i * PI / 12.0
		points.append(Vector2(cos(a) * w / 2.0, sin(a) * h))
	draw_colored_polygon(points, COLOR)
	draw_polyline(points + PackedVector2Array([points[0]]), DARK, 1.0)
	if state == "alive":
		var eye = Vector2(facing * 3, -h * 0.55)
		draw_rect(Rect2(eye + Vector2(-3, -1), Vector2(2, 3)), Color.BLACK)
		draw_rect(Rect2(eye + Vector2(1, -1), Vector2(2, 3)), Color.BLACK)
		draw_rect(Rect2(Vector2(-w / 2.0 + 2, -h * 0.75), Vector2(2, 2)), Color(1, 1, 1, 0.6))
