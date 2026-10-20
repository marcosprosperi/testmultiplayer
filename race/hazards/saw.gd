@tool
class_name Saw extends KillZone

## Spinning saw that goes back and forth between its start and start + travel.
## The server moves it and the MultiplayerSynchronizer copies the position.

@export var travel := Vector2(128, 0):
	set(value):
		travel = value
		queue_redraw()
## Seconds for a full round trip
@export var period := 2.5
@export var radius := 10.0:
	set(value):
		radius = value
		queue_redraw()

var _origin: Vector2
var _time := 0.0

func _ready() -> void:
	_origin = position
	var collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		var shape = CircleShape2D.new()
		shape.radius = radius - 2.0
		collision.shape = shape
	super()

func _physics_process(delta: float) -> void:
	queue_redraw()
	if Engine.is_editor_hint() or not is_multiplayer_authority():
		return
	_time += delta
	var t = 0.5 - 0.5 * cos(TAU * _time / period)
	position = _origin + travel * t

func _draw() -> void:
	if Engine.is_editor_hint():
		# Path preview in the editor
		draw_line(Vector2.ZERO, travel, Color(1, 0.3, 0.3, 0.6), 1.0)
	var spin = Time.get_ticks_msec() / 1000.0 * TAU * 2.0
	var teeth = PackedVector2Array()
	for i in 16:
		var angle = spin + i * TAU / 16.0
		teeth.append(Vector2.from_angle(angle) * (radius if i % 2 == 0 else radius - 3.0))
	draw_colored_polygon(teeth, Color("#b9bec8"))
	draw_circle(Vector2.ZERO, radius - 4.0, Color("#7d8494"))
	draw_circle(Vector2.ZERO, 2.0, Color("#3a3f4b"))
