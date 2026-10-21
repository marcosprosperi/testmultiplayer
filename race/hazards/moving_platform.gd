@tool
class_name MovingPlatform extends AnimatableBody2D

## Floating platform that goes back and forth between its start and
## start + travel. Its position comes from the race clock (like the
## balloons), so it's in the same place on every screen without syncing.

const TILE = 16
const TILESET = preload("res://resources/nature-paltformer-tileset-16x16.png")

@export_range(2, 16) var tiles := 4:
	set(value):
		tiles = value
		_update_shape()
		queue_redraw()
@export var travel := Vector2(128, 0):
	set(value):
		travel = value
		queue_redraw()
## Seconds for a full round trip
@export var period := 4.0
## 0..1: where in its trip it starts (so platforms side by side don't match)
@export_range(0.0, 1.0) var phase := 0.0

var _origin: Vector2

func _ready() -> void:
	_origin = position
	_update_shape()

func _update_shape() -> void:
	if not is_inside_tree():
		return
	var shape = RectangleShape2D.new()
	shape.size = Vector2(tiles * TILE, TILE)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = Vector2(tiles * TILE / 2.0, TILE / 2.0)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var t = RaceManager.race_time() / period + phase
	position = _origin + travel * (0.5 - 0.5 * cos(TAU * t))

func _draw() -> void:
	if Engine.is_editor_hint():
		# Path preview in the editor
		draw_dashed_line(Vector2(tiles * TILE / 2.0, TILE / 2.0), Vector2(tiles * TILE / 2.0, TILE / 2.0) + travel, Color(0.4, 0.8, 1, 0.7), 1.0, 4.0)
	for i in tiles:
		var column = 3 if i == 0 else (5 if i == tiles - 1 else 4)
		draw_texture_rect_region(TILESET, Rect2(i * TILE, 0, TILE, TILE), Rect2(column * TILE, 0, TILE, TILE))
