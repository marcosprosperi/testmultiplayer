@tool
class_name Fireball extends Enemy

## Ball of fire that jumps out of the lava every few seconds (up to travel.y
## above it) and falls back in. It can't be squashed; it can't hurt while
## it's under the lava.

const CORE = Color("#fff0a0")
const FLAME = Color("#ff9a2e")
const OUTER = Color("#e8401c")

## Seconds between jumps (the jump itself takes air_time)
@export var period := 2.6
@export var air_time := 1.2

func _init() -> void:
	stompable = false
	body_height = 10.0
	poll_overlaps = true

func _cycle(t: float) -> float:
	return fposmod(t + phase * period, period)

func patrol_offset(t: float) -> Vector2:
	var c = _cycle(t)
	if c >= air_time:
		return Vector2(0, 20)  # down in the lava
	var f = c / air_time
	facing = -1 if f > 0.5 else 1  # draw it flipped on the way down
	return Vector2(0, travel.y * 4.0 * f * (1.0 - f))

func harmful_at(t: float) -> bool:
	return _cycle(t) < air_time

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_dashed_line(Vector2.ZERO, Vector2(0, travel.y), Color(1, 0.5, 0.3, 0.7), 1.0, 4.0)
	if draw_state() == "gone" or position.y > _origin.y + 4:
		return
	var t = Time.get_ticks_msec() / 1000.0
	# Flames trail behind (below when going up, above when coming down)
	var trail = Vector2(0, 5 * facing)
	for i in 3:
		var r = 4.0 - i
		draw_circle(Vector2(sin(t * 20 + i) * 1.5, -6) + trail * (i + 1) * 0.8, r, Color(OUTER, 0.8 - i * 0.2))
	draw_circle(Vector2(0, -6), 6.0, OUTER)
	draw_circle(Vector2(0, -6), 4.5, FLAME)
	draw_circle(Vector2(0, -6 - facing), 2.5, CORE)
	draw_rect(Rect2(Vector2(-3, -8), Vector2(1, 2)), Color.BLACK)
	draw_rect(Rect2(Vector2(2, -8), Vector2(1, 2)), Color.BLACK)
