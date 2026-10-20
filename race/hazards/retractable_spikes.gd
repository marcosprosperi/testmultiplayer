@tool
class_name RetractableSpikes extends Trap

## Spikes hidden in the floor that come out for a while. The node's position
## is the floor's left edge.

const TILE = 16.0

@export_range(1, 16) var tiles := 3:
	set(value):
		tiles = value
		_update_shape()

@onready var kill: KillZone = $Kill

func _ready() -> void:
	_update_shape()
	if not Engine.is_editor_hint():
		set_deadly(kill, false)

func _update_shape() -> void:
	if not is_inside_tree():
		return
	var shape = RectangleShape2D.new()
	shape.size = Vector2(tiles * TILE - 4.0, 6.0)
	$Kill/CollisionShape2D.shape = shape
	$Kill/CollisionShape2D.position = Vector2(tiles * TILE / 2.0, -3.0)

func _on_phase_changed(new_phase: Phase) -> void:
	set_deadly(kill, new_phase == Phase.ACTIVE)
	if new_phase == Phase.ACTIVE:
		Sfx.play_at("spikes", global_position)

func _draw() -> void:
	var height = 0.0
	if phase == Phase.ACTIVE or Engine.is_editor_hint():
		height = 9.0
	elif is_warning_blink_on():
		height = 3.0
	for i in tiles:
		# Slots in the floor
		draw_rect(Rect2(i * TILE + 2, -2, TILE - 4, 2), Color(0.15, 0.15, 0.18))
		if height <= 0.0:
			continue
		for half in 2:
			var x = i * TILE + half * TILE / 2.0
			var points = PackedVector2Array([Vector2(x, 0), Vector2(x + TILE / 4.0, -height), Vector2(x + TILE / 2.0, 0)])
			draw_colored_polygon(points, Color("#e08080") if phase == Phase.WARNING else Color("#c8ccd4"))
			draw_polyline(points, Color("#5b6170"), 1.0)
