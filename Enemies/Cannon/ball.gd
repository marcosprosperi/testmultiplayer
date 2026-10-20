class_name Ball extends Area2D

const SPEED: int = 600

var direction: int
var damage: int = 1
@onready var life_timer: Timer = $LifeTimer
@onready var sprite_2d: Sprite2D = $Sprite2D

func _ready() -> void:
	life_timer.timeout.connect(_on_life_timer_timeout)
	body_entered.connect(_on_body_entered)
	life_timer.start()
	# The texture points left; mirror it when shooting right
	if direction > 0:
		sprite_2d.flip_h = true
		sprite_2d.position.x = -sprite_2d.position.x

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position.x += direction * SPEED * delta


func _on_life_timer_timeout():
	if is_multiplayer_authority():
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if !is_multiplayer_authority():
		return
	if body.is_in_group("player"):
		print("Ball hit ", body.name)
	# Despawning on the server also removes the ball on the clients
	queue_free()
