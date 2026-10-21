@tool
class_name Frog extends Enemy

## Frog that hops back and forth. Land on it to squash it, but watch out:
## it jumps up at you.

const BODY = Color("#58b947")
const BELLY = Color("#c9ec8a")
const DARK = Color("#2d6e2c")
## Seconds per hop (in the air + resting)
const HOP_TIME = 1.1
const AIR_TIME = 0.5
const HOP_LENGTH = 32.0

@export var hop_height := 22.0

func _init() -> void:
	stompable = true
	body_height = 10.0

func patrol_offset(t: float) -> Vector2:
	var length = travel.length()
	if length < 1.0:
		return Vector2.ZERO
	var hops = maxi(1, roundi(length / HOP_LENGTH))
	var leg = hops * HOP_TIME
	var d = fposmod(t + phase * leg * 2.0, leg * 2.0)
	var forward = d < leg
	var local = d if forward else d - leg
	var k = floorf(local / HOP_TIME)
	var f = clampf((local - k * HOP_TIME) / AIR_TIME, 0.0, 1.0)
	var along = (k + f) / hops * length
	if not forward:
		along = length - along
	var direction = signf(travel.x) if travel.x != 0 else 1.0
	facing = int(direction) if forward else -int(direction)
	var up = sin(PI * f) * hop_height if f < 1.0 else 0.0
	return travel.normalized() * along + Vector2(0, -up)

func _draw() -> void:
	super()
	var state = draw_state()
	if state == "gone":
		return
	if state == "squashed":
		draw_rect(Rect2(Vector2(-8, -2), Vector2(16, 2)), BODY)
		return
	var in_air = position.y < _origin.y - 1.0
	var stretch = 1.25 if in_air else 1.0
	# Legs
	for side in [-1, 1]:
		var foot = Vector2(side * 6, 0) if not in_air else Vector2(side * 4 - facing * 4, 2)
		draw_line(Vector2(side * 4, -3), foot, DARK, 2.0)
	# Body and belly
	draw_set_transform(Vector2(0, -5 * stretch), 0.0, Vector2(1.0, stretch))
	draw_circle(Vector2.ZERO, 6.0, BODY)
	draw_circle(Vector2(facing * 1, 2), 3.5, BELLY)
	draw_set_transform(Vector2.ZERO)
	# Eyes on top
	for side in [-1, 1]:
		var eye = Vector2(side * 3 + facing * 1.5, -10 * stretch)
		draw_circle(eye, 2.5, Color.WHITE)
		draw_rect(Rect2(eye + Vector2(facing * 0.5 - 0.5, -1), Vector2(1, 2)), Color.BLACK)
