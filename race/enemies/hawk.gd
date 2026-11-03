@tool
class_name Hawk extends Enemy

## Hawk flying back and forth in a zigzag: sharp dives down to head height
## and straight back up, every `zig` pixels. Land on it to squash it.

const BODY = Color("#a0643c")
const BELLY = Color("#f1d3a1")
const WING = Color("#6b3f22")
const BEAK = Color("#ffb627")
const OUTLINE = Color(0.17, 0.11, 0.23)

## Pixels it rises above its lowest point
@export var dive := 40.0
## Pixels flown forward from the top of a dive to the bottom
@export var zig := 40.0

func _init() -> void:
	stompable = true
	wait_for_it = true
	body_height = 10.0

func patrol_offset(t: float) -> Vector2:
	var base = super(t)
	var along = base.length()
	var z = maxf(zig, 1.0)
	# Down to 0 and up to -dive in straight lines
	var height = (z - absf(fposmod(along, z * 2.0) - z)) / z * dive
	return base + Vector2(0, -height)

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_dashed_line(Vector2.ZERO, travel, Color(1, 0.5, 0.3, 0.7), 1.0, 4.0)
	var state = draw_state()
	if state == "gone":
		return
	if state == "squashed":
		draw_rect(Rect2(Vector2(-6, -2), Vector2(12, 2)), BODY)
		return
	var f = float(facing)
	var flap = sin(Time.get_ticks_msec() / 1000.0 * 18.0)
	# Body, belly and tail
	draw_colored_polygon(PackedVector2Array([Vector2(-f * 9, -7), Vector2(-f * 5, -5), Vector2(-f * 9, -3)]), WING)
	draw_set_transform(Vector2(0, -5), 0.0, Vector2(1.6, 1.0))
	draw_circle(Vector2.ZERO, 4.0, BODY)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(f * 1, -3.5), 2.5, BELLY)
	draw_circle(Vector2(f * 5, -7), 3.0, BODY)
	draw_colored_polygon(PackedVector2Array([Vector2(f * 7, -8), Vector2(f * 11, -6.5), Vector2(f * 7, -5.5)]), BEAK)
	draw_rect(Rect2(Vector2(f * 5.5 - 0.5, -8.5), Vector2(1.2, 1.2)), OUTLINE)
	# Wing on top: a sharp triangle beating up and down
	var wing = PackedVector2Array([Vector2(-f * 3, -6), Vector2(f * 3, -6), Vector2(-f * 5, -6 - 8 * flap)])
	draw_colored_polygon(wing, WING)
	draw_polyline(wing + PackedVector2Array([wing[0]]), OUTLINE, 1.0)
