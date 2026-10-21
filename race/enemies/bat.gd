@tool
class_name Bat extends Enemy

## Bat that flies back and forth bobbing up and down. Land on it to squash it.

const BODY = Color("#6c4a9e")
const WING = Color("#4a2f74")

## How far it bobs up and down
@export var bob := 14.0

func _init() -> void:
	stompable = true
	body_height = 8.0

func patrol_offset(t: float) -> Vector2:
	return super(t) + Vector2(0, sin(t * 3.0 + phase * TAU) * bob)

func _draw() -> void:
	super()
	var state = draw_state()
	if state == "gone":
		return
	var y = -4.0
	if state == "squashed":
		draw_rect(Rect2(Vector2(-6, -2), Vector2(12, 2)), BODY)
		return
	var flap = sin(Time.get_ticks_msec() / 1000.0 * 18.0) * 5.0
	for side in [-1, 1]:
		draw_colored_polygon(PackedVector2Array([Vector2(side * 3, y - 1), Vector2(side * 11, y - 3 + flap), Vector2(side * 8, y + 2), Vector2(side * 5, y + 1)]), WING)
	draw_circle(Vector2(0, y), 4.0, BODY)
	draw_colored_polygon(PackedVector2Array([Vector2(-3, y - 3), Vector2(-2, y - 7), Vector2(-1, y - 3)]), BODY)
	draw_colored_polygon(PackedVector2Array([Vector2(1, y - 3), Vector2(2, y - 7), Vector2(3, y - 3)]), BODY)
	draw_rect(Rect2(Vector2(facing - 2, y - 1), Vector2(1, 1)), Color.RED)
	draw_rect(Rect2(Vector2(facing + 1, y - 1), Vector2(1, 1)), Color.RED)
