@tool
class_name BalloonColumn extends Node2D

## Balloons rising in a column from this node's position up to top_height,
## then coming back from the bottom. Their height comes from the race clock,
## so they are in the same place on every screen without sending anything.

## How high the balloons go above this node before starting over
@export var top_height := 1600.0:
	set(value):
		top_height = value
		queue_redraw()
## Vertical distance between balloons of this column
@export var spacing := 160.0:
	set(value):
		spacing = value
		queue_redraw()
## Pixels per second
@export var speed := 45.0
## Shifts the whole column up (0..spacing) so columns don't line up
@export var phase := 0.0:
	set(value):
		phase = value
		queue_redraw()
@export var color := Color("#e74c3c")

# Fade in/out over this distance at the bottom and the top
const FADE = 40.0

var _balloons: Array[Balloon] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for i in _count():
		var balloon = Balloon.new()
		balloon.color = color
		add_child(balloon)
		_balloons.append(balloon)
	_place(0.0)

func _physics_process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_place(RaceManager.race_time())

func _count() -> int:
	return int(ceil(top_height / spacing))

func _height_of(index: int, time: float) -> float:
	var span = _count() * spacing
	return fposmod(phase + index * spacing + speed * time, span)

func _place(time: float) -> void:
	for i in _balloons.size():
		var balloon = _balloons[i]
		var height = _height_of(i, time)
		balloon.position = Vector2(0, -height)
		# Fade in at the bottom, fade out (and stop being solid) at the top
		var alpha = clampf(height / FADE, 0.0, 1.0) * clampf((top_height - height) / FADE, 0.0, 1.0)
		balloon.modulate.a = alpha
		balloon.set_solid(alpha > 0.5)
		balloon.visible = height <= top_height

# Preview in the editor: the path and where the balloons start
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_line(Vector2.ZERO, Vector2(0, -top_height), Color(color, 0.4), 1.0)
	for i in _count():
		var height = _height_of(i, 0.0)
		if height <= top_height:
			draw_rect(Rect2(-15, -height, 30, 34), Color(color, 0.6))
