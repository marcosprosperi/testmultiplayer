@tool
class_name Ghost extends Enemy

## Ghost floating back and forth. It can't be squashed, but every few seconds
## it fades away and you can go right through it.

const BODY = Color("#eef2ff")
const SHADE = Color("#b9c3e8")
## Seconds solid, then fading out, invisible and fading back in
const SOLID_TIME = 2.6
const FADE_TIME = 0.3
const GONE_TIME = 1.6

@export var bob := 6.0

func _init() -> void:
	stompable = false
	body_height = 14.0
	poll_overlaps = true

func patrol_offset(t: float) -> Vector2:
	return super(t) + Vector2(0, sin(t * 2.0 + phase * TAU) * bob)

func _cycle(t: float) -> float:
	var period = SOLID_TIME + GONE_TIME + FADE_TIME * 2.0
	return fposmod(t + phase * period, period)

## How visible (0..1) at race time t
func opacity_at(t: float) -> float:
	var c = _cycle(t)
	if c < SOLID_TIME:
		return 1.0
	c -= SOLID_TIME
	if c < FADE_TIME:
		return 1.0 - c / FADE_TIME
	c -= FADE_TIME
	if c < GONE_TIME:
		return 0.0
	return (c - GONE_TIME) / FADE_TIME

func harmful_at(t: float) -> bool:
	return opacity_at(t) > 0.5

func _draw() -> void:
	super()
	if Engine.is_editor_hint():
		_draw_ghost(1.0)
		return
	var alpha = opacity_at(RaceManager.race_time())
	_draw_ghost(maxf(alpha, 0.12))

func _draw_ghost(alpha: float) -> void:
	var body = Color(BODY, 0.9 * alpha)
	var shade = Color(SHADE, 0.9 * alpha)
	var t = Time.get_ticks_msec() / 1000.0
	# Round head and a wavy skirt
	draw_circle(Vector2(0, -12), 7.0, body)
	var skirt = PackedVector2Array([Vector2(-7, -12), Vector2(7, -12)])
	for i in 7:
		var x = 7 - i * 14.0 / 6.0
		skirt.append(Vector2(x, -2 + (2.0 if i % 2 == 0 else 0.0) + sin(t * 6 + i) * 1.0))
	draw_colored_polygon(skirt, body)
	draw_line(Vector2(-6, -6), Vector2(6, -6), shade, 1.0)
	# Eyes and an "o" mouth
	var eye_color = Color(0.2, 0.2, 0.35, alpha)
	draw_rect(Rect2(Vector2(facing * 2 - 4, -15), Vector2(2, 3)), eye_color)
	draw_rect(Rect2(Vector2(facing * 2 + 1, -15), Vector2(2, 3)), eye_color)
	draw_circle(Vector2(facing * 2 - 0.5, -9.5), 1.3, eye_color)
