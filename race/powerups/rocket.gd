class_name Rocket extends Node2D

## The Cohete power-up on its way: flies to its target (it can't miss) and
## pops. Only for show on every screen; the target's own screen decides what
## the hit does (see Player.rocket_hit)

const SPEED = 900.0
const OUTLINE = Color(0.17, 0.11, 0.23)

var target: Node2D

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var to = target.global_position + Vector2(0, -8)
	if global_position.distance_to(to) <= SPEED * delta:
		Fx.spawn(Fx.POOF, to, Color("#ff9f1c"))
		Sfx.play_at("cannon", to, -6.0)
		target.rocket_hit()
		queue_free()
		return
	rotation = (to - global_position).angle()
	global_position = global_position.move_toward(to, SPEED * delta)
	queue_redraw()

func _draw() -> void:
	PowerUps.draw_icon(self, PowerUps.ROCKET, Vector2.ZERO, 14.0)
