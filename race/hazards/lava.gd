@tool
class_name Lava extends KillZone

## Lava filling a pit, `tiles` wide (to the right of the node) and `depth`
## pixels deep. Touching it loses, like falling.

@export var tiles := 6:
	set(value):
		tiles = value
		_update_shape()
		queue_redraw()
@export var depth := 48.0

const TOP = Color("#ffcf4a")
const HOT = Color("#ff8a1e")
const DEEP = Color("#c8361a")

func _ready() -> void:
	pit = true
	_update_shape()
	super()

func _update_shape() -> void:
	if not is_inside_tree():
		return
	var collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		add_child(collision)
	var shape = RectangleShape2D.new()
	shape.size = Vector2(tiles * 16, depth)
	collision.shape = shape
	collision.position = Vector2(tiles * 8, depth / 2.0 + 2)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var width = tiles * 16.0
	var t = Time.get_ticks_msec() / 1000.0
	draw_rect(Rect2(0, 6, width, depth - 6), DEEP)
	draw_rect(Rect2(0, 2, width, 6), HOT)
	# Wavy bright surface and a few bubbles
	var wave = PackedVector2Array()
	for x in range(0, int(width) + 1, 4):
		wave.append(Vector2(x, 1 + sin(t * 3 + x * 0.25) * 1.2))
	wave.append(Vector2(width, 4))
	wave.append(Vector2(0, 4))
	draw_colored_polygon(wave, TOP)
	for i in tiles:
		var phase = fposmod(t * 0.8 + i * 0.37, 1.0)
		draw_circle(Vector2(i * 16 + 8, 10 + (1.0 - phase) * 12), 1.5 * (1.0 - phase) + 0.5, Color(TOP, 0.8))
