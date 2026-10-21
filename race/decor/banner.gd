@tool
class_name Banner extends Node2D

## Castle banner hanging from the ceiling, gently swaying (decoration)

@export var color := Color("#a8324a"):
	set(value):
		color = value
		queue_redraw()
@export var length := 34.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var t = Time.get_ticks_msec() / 1000.0 + position.x * 0.013
	var sway = sin(t * 1.6) * 1.5
	var w = 12.0
	# Pole and cloth with a pointed end
	draw_rect(Rect2(-w / 2.0 - 2, 0, w + 4, 2), Color("#3a3640"))
	var cloth = PackedVector2Array([Vector2(-w / 2.0, 2), Vector2(w / 2.0, 2),
		Vector2(w / 2.0 + sway, length), Vector2(sway, length - 6), Vector2(-w / 2.0 + sway, length)])
	draw_colored_polygon(cloth, color)
	draw_polyline(cloth + PackedVector2Array([cloth[0]]), color.darkened(0.45), 1.0)
	# Gold trim and a little emblem
	draw_line(Vector2(-w / 2.0, 4), Vector2(w / 2.0, 4), Color("#ffd23f"), 1.0)
	draw_circle(Vector2(sway * 0.5, length * 0.45), 3.0, Color("#ffd23f"))
	draw_circle(Vector2(sway * 0.5, length * 0.45), 1.5, color.darkened(0.3))
