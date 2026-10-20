@tool
class_name Fan extends Trap

## Fan that blows players while it's on. It doesn't kill, but it holds you
## back or pushes you into something that does. The node's position is the
## fan itself; the wind goes `reach` pixels in `direction`.

@export_enum("Left:-1", "Right:1") var direction := -1:
	set(value):
		direction = value
		_update_shape()
@export var reach := 160.0:
	set(value):
		reach = value
		_update_shape()
@export var wind_height := 48.0:
	set(value):
		wind_height = value
		_update_shape()
## Pixels per second added to players in the wind
@export var strength := 260.0

@onready var wind: Area2D = $Wind

func _ready() -> void:
	_update_shape()

func _update_shape() -> void:
	if not is_inside_tree():
		return
	var shape = RectangleShape2D.new()
	shape.size = Vector2(reach, wind_height)
	$Wind/CollisionShape2D.shape = shape
	$Wind/CollisionShape2D.position = Vector2(direction * reach / 2.0, 0)

func _on_phase_changed(new_phase: Phase) -> void:
	if new_phase == Phase.ACTIVE:
		Sfx.play_at("wind", global_position)

func _trap_process(_delta: float) -> void:
	if phase != Phase.ACTIVE:
		return
	for body in wind.get_overlapping_bodies():
		# Each player's own screen moves them
		if body is Player and body.is_multiplayer_authority():
			body.push.x += direction * strength

func _draw() -> void:
	var box = Rect2(Vector2(-8, -wind_height / 2.0 - 4), Vector2(16, wind_height + 8))
	draw_rect(box, Color("#c0392b") if is_warning_blink_on() else Color(0.35, 0.37, 0.42))
	draw_rect(box, Color(0.2, 0.2, 0.25), false, 2.0)
	# Spinning blades
	var spin = Time.get_ticks_msec() / 1000.0 * (25.0 if phase == Phase.ACTIVE else 2.0)
	for i in 3:
		var tip = Vector2(0, 1).rotated(spin + i * TAU / 3.0) * 7.0
		draw_line(Vector2.ZERO, Vector2(tip.x * 0.3, tip.y), Color(0.85, 0.85, 0.9), 2.0)
	if phase == Phase.ACTIVE or Engine.is_editor_hint():
		# Wind lines moving along
		var t = fposmod(Time.get_ticks_msec() / 1000.0 * 2.0, 1.0)
		for i in 5:
			var y = -wind_height / 2.0 + (i + 0.5) * wind_height / 5.0
			var along = fposmod(t + i * 0.37, 1.0) * reach
			draw_line(Vector2(direction * along, y), Vector2(direction * (along + 18.0), y), Color(1, 1, 1, 0.5), 1.0)
