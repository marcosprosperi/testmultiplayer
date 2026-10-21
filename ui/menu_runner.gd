class_name MenuRunner extends Node2D

## A little racer running across the start screen, hopping now and then

const GRAVITY = 900.0
const JUMP_SPEED = -260.0

var color := Color.WHITE
var speed := 80.0
var ground_y := 0.0

var _sprite: AnimatedSprite2D
var _velocity_y := 0.0
var _jump_in := 1.0

func setup(frames: SpriteFrames, runner_color: Color) -> void:
	color = runner_color
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.position = Vector2(0, -12)
	_sprite.modulate = Color.WHITE.lerp(color, 0.35)
	_sprite.play("run")
	add_child(_sprite)
	speed = randf_range(70.0, 115.0)
	_jump_in = randf_range(0.5, 3.0)

func _process(delta: float) -> void:
	position.x += speed * delta
	if position.x > get_viewport_rect().size.x + 30:
		position.x = -30 - randf() * 120
		speed = randf_range(70.0, 115.0)
	_jump_in -= delta
	if _jump_in <= 0.0 and position.y >= ground_y:
		_velocity_y = JUMP_SPEED * randf_range(0.7, 1.1)
		_jump_in = randf_range(1.0, 3.5)
	_velocity_y += GRAVITY * delta
	position.y = minf(position.y + _velocity_y * delta, ground_y)
	var in_air = position.y < ground_y
	_sprite.play("jump" if in_air else "run")
	queue_redraw()

# A dot in the racer's color over their head, like in the race
func _draw() -> void:
	draw_circle(Vector2(0, -30), 3.5, Color(0.17, 0.11, 0.23))
	draw_circle(Vector2(0, -30), 2.5, color)
