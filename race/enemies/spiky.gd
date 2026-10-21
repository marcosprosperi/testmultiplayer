@tool
class_name Spiky extends Enemy

## Spiked hedgehog. It can't be squashed: jump over it.

const BODY = Color("#8a5a3c")
const SPIKE = Color("#d8d8e0")

func _init() -> void:
	stompable = false
	body_height = 12.0

func _draw() -> void:
	super()
	if draw_state() == "gone":
		return
	var t = Time.get_ticks_msec() / 1000.0
	var step = sin(t * 12.0) * 1.5
	# Spikes on the back
	for i in 7:
		var a = PI + (i + 0.5) * PI / 7.0
		var base = Vector2(cos(a) * 7.0, -6.0 + sin(a) * 6.0)
		var tip = Vector2(cos(a) * 12.0, -6.0 + sin(a) * 11.0)
		var side = Vector2(-sin(a), cos(a)) * 2.0
		draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), SPIKE)
	draw_circle(Vector2(0, -6), 7.0, BODY)
	# Feet, face
	draw_rect(Rect2(Vector2(-5, -2 + step), Vector2(3, 2)), Color(0.3, 0.2, 0.15))
	draw_rect(Rect2(Vector2(2, -2 - step), Vector2(3, 2)), Color(0.3, 0.2, 0.15))
	draw_circle(Vector2(facing * 6, -5), 2.5, Color("#f0c8a0"))
	draw_rect(Rect2(Vector2(facing * 4 - 1, -8), Vector2(2, 2)), Color.BLACK)
	draw_rect(Rect2(Vector2(facing * 8 - 1, -6), Vector2(2, 2)), Color("#402020"))
