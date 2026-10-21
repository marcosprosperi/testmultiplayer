@tool
class_name Penguin extends Enemy

## Penguin sliding on its belly back and forth, fast. Land on it to squash it.

const BODY = Color("#2b2f45")
const BELLY = Color("#f4f6ff")
const BEAK = Color("#ffb02e")

func _init() -> void:
	stompable = true
	body_height = 8.0
	warning_distance = 80.0

func _draw() -> void:
	super()
	var state = draw_state()
	if state == "gone":
		return
	if state == "squashed":
		draw_rect(Rect2(Vector2(-8, -2), Vector2(16, 2)), BODY)
		return
	var t = Time.get_ticks_msec() / 1000.0
	# Lying down, head to the front, flippers back
	draw_set_transform(Vector2(0, -4), 0.0, Vector2(1.7, 1.0))
	draw_circle(Vector2.ZERO, 4.5, BODY)
	draw_circle(Vector2(0, 1.5), 3.0, BELLY)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(facing * 7, -5), 3.5, BODY)
	draw_rect(Rect2(Vector2(facing * 8 - 0.5, -7), Vector2(1, 1)), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([Vector2(facing * 10, -6), Vector2(facing * 13, -5), Vector2(facing * 10, -4)]), BEAK)
	draw_line(Vector2(-facing * 4, -6), Vector2(-facing * 9, -8 + sin(t * 16) * 1.5), BODY, 2.0)
	# Snow spray behind
	for i in 3:
		draw_rect(Rect2(Vector2(-facing * (10 + i * 3), -1 - fposmod(t * 10 + i, 3.0)), Vector2(1, 1)), Color(1, 1, 1, 0.7))
