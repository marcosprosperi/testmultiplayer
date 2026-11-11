@tool
class_name Diamond extends Enemy

## Spiky crystal bouncing diagonally inside a box (travel.x wide, travel.y
## tall, going up from the floor), like a ball in a pinball machine: always at
## 45 degrees, turning sharp at the walls. Can't be squashed.

const BODY = Color("#7ee8fa")
const SHINE = Color("#e8fbff")
const SHADE = Color("#3aa7c9")
const OUTLINE = Color(0.17, 0.11, 0.23)

func _init() -> void:
	stompable = false
	wait_for_it = true
	body_height = 14.0

# 0..length..0, at a steady speed
static func _bounce(d: float, length: float) -> float:
	return length - absf(fposmod(d, length * 2.0) - length)

func patrol_offset(t: float) -> Vector2:
	var w = maxf(absf(travel.x), 1.0)
	var h = maxf(absf(travel.y), 1.0)
	# The same speed on both axes: 45 degree bounces
	var d = t * speed / sqrt(2.0) + phase * (w + h) * 2.0
	facing = 1 if fposmod(d, w * 2.0) < w else -1
	return Vector2(_bounce(d, w) * (signf(travel.x) if travel.x != 0 else 1.0), -_bounce(d + h * 0.5, h))

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2(0, -absf(travel.y)), Vector2(travel.x, absf(travel.y))), Color(1, 0.5, 0.3, 0.7), false, 1.0)
	if draw_state() == "gone":
		return
	var spin = RaceManager.race_time() * 4.0 * facing if not Engine.is_editor_hint() else 0.0
	var c = Vector2(0, -7)
	# Four spikes turning around it, then the gem
	for i in 4:
		var a = spin + i * PI / 2.0
		var tip = c + Vector2(cos(a), sin(a)) * 10.0
		var side = Vector2(-sin(a), cos(a)) * 2.5
		draw_colored_polygon(PackedVector2Array([c + side, tip, c - side]), OUTLINE)
		draw_colored_polygon(PackedVector2Array([c + side * 0.5, tip - Vector2(cos(a), sin(a)), c - side * 0.5]), SHINE)
	var gem = PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)])
	draw_colored_polygon(gem, BODY)
	draw_colored_polygon(PackedVector2Array([gem[0], gem[1], c]), SHINE)
	draw_colored_polygon(PackedVector2Array([gem[2], gem[3], c]), SHADE)
	draw_polyline(gem + PackedVector2Array([gem[0]]), OUTLINE, 1.0)
	# Angry eyes
	draw_rect(Rect2(c + Vector2(-3, -1), Vector2(1.5, 2)), OUTLINE)
	draw_rect(Rect2(c + Vector2(1.5, -1), Vector2(1.5, 2)), OUTLINE)
