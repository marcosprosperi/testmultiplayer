class_name RaceTrack extends Control

## Horizontal line from start (left) to finish (right) with a dot per player

const LINE_COLOR = Color(1, 1, 1, 0.85)
const DOT_RADIUS = 3.0
const LOCAL_DOT_RADIUS = 4.5

# [{progress: float, color: Color, is_local: bool}], set by the HUD every frame
var entries: Array = []:
	set(value):
		entries = value
		queue_redraw()

func _draw() -> void:
	var y = size.y / 2.0
	var left = LOCAL_DOT_RADIUS + 1
	var right = size.x - LOCAL_DOT_RADIUS - 1

	# Shadow + track
	draw_line(Vector2(left, y + 1), Vector2(right, y + 1), Color(0, 0, 0, 0.5), 2.0)
	draw_line(Vector2(left, y), Vector2(right, y), LINE_COLOR, 2.0)
	# Start marker
	draw_line(Vector2(left, y - 4), Vector2(left, y + 4), LINE_COLOR, 2.0)
	# Checkered finish marker
	for row in 3:
		for col in 2:
			var color = Color.WHITE if (row + col) % 2 == 0 else Color.BLACK
			draw_rect(Rect2(right - 1 + col * 3, y - 4.5 + row * 3, 3, 3), color)

	for entry in entries:
		var pos = Vector2(lerpf(left, right, entry.progress), y)
		if entry.is_local:
			draw_circle(pos, LOCAL_DOT_RADIUS + 1, Color.WHITE)
			draw_circle(pos, LOCAL_DOT_RADIUS, entry.color)
		else:
			draw_circle(pos, DOT_RADIUS + 1, Color(0, 0, 0, 0.6))
			draw_circle(pos, DOT_RADIUS, entry.color)
