@tool
class_name Torch extends Node2D

## Wall torch for the stone levels: a flickering flame with a warm glow
## (just decoration, it doesn't touch anything)

const WOOD = Color("#6b4a2f")
const IRON = Color("#3a3640")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var t = Time.get_ticks_msec() / 1000.0 + position.x * 0.01
	var flicker = sin(t * 13.0) * 0.5 + sin(t * 7.3) * 0.5
	# Glow behind
	for i in 3:
		draw_circle(Vector2(0, -10), 22.0 - i * 6.0 + flicker, Color(1.0, 0.65, 0.25, 0.05 + i * 0.04))
	# Bracket and stick
	draw_rect(Rect2(-3, -2, 6, 2), IRON)
	draw_rect(Rect2(-1.5, -8, 3, 8), WOOD)
	draw_rect(Rect2(-2.5, -9, 5, 2), IRON)
	# Flame: outer orange, inner yellow, tip sways
	var tip = Vector2(flicker * 1.5, -17 - flicker)
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -9), tip, Vector2(3, -9), Vector2(0, -7)]), Color("#ff8a1e"))
	draw_colored_polygon(PackedVector2Array([Vector2(-1.5, -9), tip * 0.7 + Vector2(0, -3), Vector2(1.5, -9)]), Color("#ffe14a"))
