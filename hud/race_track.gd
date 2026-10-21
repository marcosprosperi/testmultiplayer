class_name RaceTrack extends Control

## Progress bar from start (left) to finish (right): a pin per player in its
## color, yours bigger with an arrow, ticks where the flags are, and the part
## you've already run filled in your color

const OUTLINE = Color(0.17, 0.11, 0.23)
const BAR_HEIGHT = 6.0
const PIN = 3.5
const LOCAL_PIN = 5.0

# [{progress: float, color: Color, is_local: bool}], set by the HUD every frame
var entries: Array = []:
	set(value):
		entries = value
		queue_redraw()
## Where the checkpoint flags are (0..1)
var flags: Array = []

func _draw() -> void:
	var y = size.y / 2.0
	var left = LOCAL_PIN + 2
	var right = size.x - 10
	var bar = Rect2(left, y - BAR_HEIGHT / 2.0, right - left, BAR_HEIGHT)
	# Dark rounded bar with an outline, filled up to where you are
	var back = StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.06, 0.15, 0.7)
	back.border_color = OUTLINE
	back.set_border_width_all(1)
	back.set_corner_radius_all(3)
	draw_style_box(back, bar.grow(1))
	var mine = entries.filter(func(e): return e.is_local)
	if not mine.is_empty():
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(mine[0].color, 0.55)
		fill.set_corner_radius_all(3)
		draw_style_box(fill, Rect2(bar.position, Vector2(bar.size.x * clampf(mine[0].progress, 0.0, 1.0), bar.size.y)))
	for flag in flags:
		var x = lerpf(left, right, flag)
		draw_line(Vector2(x, y - 2), Vector2(x, y + 2), Color(1, 1, 1, 0.6), 1.0)
	_draw_finish_flag(Vector2(right + 2, y))
	for entry in entries:
		var at = Vector2(lerpf(left, right, clampf(entry.progress, 0.0, 1.0)), y)
		if entry.is_local:
			draw_circle(at, LOCAL_PIN + 1.5, OUTLINE)
			draw_circle(at, LOCAL_PIN, Color.WHITE)
			draw_circle(at, LOCAL_PIN - 1.5, entry.color)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-3, -10), at + Vector2(3, -10), at + Vector2(0, -7)]),
				Color("#ffd23f"))
		else:
			draw_circle(at, PIN + 1, OUTLINE)
			draw_circle(at, PIN, entry.color)

# Checkered flag on a little pole
func _draw_finish_flag(at: Vector2) -> void:
	draw_line(at + Vector2(0, 6), at + Vector2(0, -7), OUTLINE, 2.0)
	draw_line(at + Vector2(0, 6), at + Vector2(0, -7), Color.WHITE, 1.0)
	for row in 3:
		for col in 3:
			var color = Color.WHITE if (row + col) % 2 == 0 else Color.BLACK
			draw_rect(Rect2(at + Vector2(1 + col * 2.5, -7 + row * 2.5), Vector2(2.5, 2.5)), color)
