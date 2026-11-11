@tool
class_name Spark extends Enemy

## Electric spark running around a diamond-shaped track (radius = travel.x,
## from the node to each corner), turning sharp at the corners. The track
## glows faintly so you can see where it goes. Can't be squashed.

const CORE = Color("#fff36b")
const GLOW = Color(1.0, 0.95, 0.4, 0.35)
const TRACK = Color(1.0, 0.95, 0.5, 0.22)
const OUTLINE = Color(0.17, 0.11, 0.23)
const CORNERS = [Vector2(1, 0), Vector2(0, -1), Vector2(-1, 0), Vector2(0, 1)]

func _init() -> void:
	stompable = false
	wait_for_it = true
	body_height = 10.0

func patrol_offset(t: float) -> Vector2:
	var r = maxf(travel.x, 1.0)
	var side = r * sqrt(2.0)
	var s = fposmod(t * speed + phase * side * 4.0, side * 4.0)
	var i = int(s / side)
	var from = CORNERS[i % 4] * r
	var to = CORNERS[(i + 1) % 4] * r
	facing = 1 if to.x >= from.x else -1
	# Offset so the spark's body (drawn above the node) runs on the track
	return from.lerp(to, (s - i * side) / side) + Vector2(0, 5)

func _draw() -> void:
	var r = maxf(travel.x, 1.0)
	# The track, around where the node started
	var center = (_origin - position) if not Engine.is_editor_hint() else Vector2.ZERO
	var points = PackedVector2Array()
	for corner in CORNERS + [CORNERS[0]]:
		points.append(center + corner * r)
	draw_polyline(points, TRACK, 1.0)
	if draw_state() == "gone":
		return
	var c = Vector2(0, -5)
	var buzz = Time.get_ticks_msec() / 1000.0 * 40.0
	draw_circle(c, 7.0 + sin(buzz) * 0.8, GLOW)
	# Little lightning bolts sticking out, jumping around
	for k in 5:
		var a = k * TAU / 5.0 + floorf(buzz / 3.0) * 1.3
		var p1 = c + Vector2(cos(a), sin(a)) * 4.0
		var p2 = c + Vector2(cos(a + 0.4), sin(a + 0.4)) * 6.5
		var p3 = c + Vector2(cos(a - 0.1), sin(a - 0.1)) * 9.0
		draw_polyline(PackedVector2Array([p1, p2, p3]), CORE, 1.0)
	draw_circle(c, 4.0, CORE)
	draw_circle(c, 2.0, Color.WHITE)
	draw_rect(Rect2(c + Vector2(-2, -1), Vector2(1, 1.5)), OUTLINE)
	draw_rect(Rect2(c + Vector2(1, -1), Vector2(1, 1.5)), OUTLINE)
