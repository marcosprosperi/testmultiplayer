@tool
class_name Bee extends Enemy

## Bee flying in circles around its spot (radius = travel.x). Land on it to
## squash it.

const BODY = Color("#ffd23f")
const STRIPE = Color("#3a2a1a")
const WING = Color(0.85, 0.95, 1.0, 0.75)

func _init() -> void:
	stompable = true
	body_height = 8.0

func patrol_offset(t: float) -> Vector2:
	var radius = maxf(travel.x, 1.0)
	var angle = t * speed / radius + phase * TAU
	facing = 1 if cos(angle) < 0 else -1
	# A flattened circle: wider than tall
	return Vector2(sin(angle) * radius, -cos(angle) * radius * 0.6)

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, travel.x, 0, TAU, 24, Color(1, 0.5, 0.3, 0.7), 1.0)
	var state = draw_state()
	if state == "gone":
		return
	if state == "squashed":
		draw_rect(Rect2(Vector2(-5, -2), Vector2(10, 2)), BODY)
		return
	var flap = absf(sin(Time.get_ticks_msec() / 1000.0 * 30.0)) * 3.0
	draw_circle(Vector2(-2, -9 - flap), 3.0, WING)
	draw_circle(Vector2(2, -9 - flap), 3.0, WING)
	draw_set_transform(Vector2(0, -4), 0.0, Vector2(1.4, 1.0))
	draw_circle(Vector2.ZERO, 4.0, BODY)
	draw_set_transform(Vector2.ZERO)
	for x in [-2.0, 1.0]:
		draw_rect(Rect2(Vector2(x * facing - 0.5, -8), Vector2(1.5, 8)), STRIPE)
	# Stinger at the back, eye at the front
	draw_colored_polygon(PackedVector2Array([Vector2(-facing * 5, -5), Vector2(-facing * 8, -4), Vector2(-facing * 5, -3)]), STRIPE)
	draw_rect(Rect2(Vector2(facing * 3 - 0.5, -6), Vector2(1, 1.5)), Color.BLACK)
