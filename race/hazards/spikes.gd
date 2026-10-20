@tool
class_name Spikes extends KillZone

## Row of spikes sitting on the floor (the node's position is the floor's
## left edge). Touching them sends the player back to the start.

const TILE = 16.0

@export_range(1, 32) var tiles := 3:
	set(value):
		tiles = value
		_update_shape()
		queue_redraw()

func _ready() -> void:
	_update_shape()
	super()

func _update_shape() -> void:
	if not is_inside_tree():
		return
	var collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return
	var shape = RectangleShape2D.new()
	# A bit smaller than the drawing so grazing the tips is forgiven
	shape.size = Vector2(tiles * TILE - 4.0, 6.0)
	collision.shape = shape
	collision.position = Vector2(tiles * TILE / 2.0, -3.0)

func _draw() -> void:
	for i in tiles:
		for half in 2:
			var x = i * TILE + half * TILE / 2.0
			var points = PackedVector2Array([Vector2(x, 0), Vector2(x + TILE / 4.0, -9), Vector2(x + TILE / 2.0, 0)])
			draw_colored_polygon(points, Color("#c8ccd4"))
			draw_polyline(points, Color("#5b6170"), 1.0)
