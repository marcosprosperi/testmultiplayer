@tool
class_name Mace extends Enemy

## Spiked ball on a chain swinging like a pendulum from where the node is
## (hang it from a ceiling). travel.x is the chain's length. Can't be squashed.

const IRON = Color("#6d7381")
const IRON_LIGHT = Color("#a9b0bf")
const CHAIN = Color("#4a4f5c")
const OUTLINE = Color(0.17, 0.11, 0.23)
const BALL = 8.0

## Widest swing each way, in radians
@export var swing := 1.0
## Seconds for a full swing there and back
@export var period := 2.4

func _init() -> void:
	stompable = false
	wait_for_it = true
	body_height = BALL * 2.0

func patrol_offset(t: float) -> Vector2:
	var a = swing * sin(TAU * (t / period + phase))
	facing = 1 if cos(TAU * (t / period + phase)) > 0 else -1
	# The node sits under the ball, whose center hangs at the chain's end
	return Vector2(sin(a), cos(a)) * travel.x + Vector2(0, BALL)

func _draw() -> void:
	var anchor = (_origin - position) if not Engine.is_editor_hint() else Vector2.ZERO
	var ball = Vector2(0, -BALL) if not Engine.is_editor_hint() else Vector2(0, travel.x)
	if Engine.is_editor_hint():
		draw_arc(anchor, travel.x, PI / 2.0 - swing, PI / 2.0 + swing, 16, Color(1, 0.5, 0.3, 0.7), 1.0)
	# Bracket on the ceiling, then the chain links
	draw_rect(Rect2(anchor + Vector2(-5, -3), Vector2(10, 4)), IRON)
	draw_rect(Rect2(anchor + Vector2(-5, -3), Vector2(10, 4)), OUTLINE, false, 1.0)
	var links = int(travel.x / 6.0)
	for i in range(1, links):
		var p = anchor.lerp(ball, float(i) / links)
		draw_circle(p, 1.6, CHAIN)
		draw_circle(p, 0.7, IRON_LIGHT)
	# The ball and its spikes, turning with the swing
	var turn = (ball - anchor).angle()
	for k in 8:
		var a = turn + k * TAU / 8.0
		var d = Vector2(cos(a), sin(a))
		var side = Vector2(-d.y, d.x) * 2.4
		var spike = PackedVector2Array([ball + d * 6 + side, ball + d * (BALL + 5), ball + d * 6 - side])
		draw_colored_polygon(spike, IRON_LIGHT)
		draw_polyline(spike, OUTLINE, 1.0)
	draw_circle(ball, BALL, IRON)
	draw_circle(ball + Vector2(-2.5, -2.5), 2.5, IRON_LIGHT)
	draw_arc(ball, BALL, 0, TAU, 20, OUTLINE, 1.0)
