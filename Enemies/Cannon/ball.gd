class_name Ball extends Area2D

var speed := 600.0
var direction: int
var damage: int = 1
@onready var life_timer: Timer = $LifeTimer
@onready var sprite_2d: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("ball")
	life_timer.timeout.connect(_on_life_timer_timeout)
	body_entered.connect(_on_body_entered)
	life_timer.start()
	# The texture points left; mirror it when shooting right
	if direction > 0:
		sprite_2d.flip_h = true
		sprite_2d.position.x = -sprite_2d.position.x

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position.x += direction * speed * delta


func _on_life_timer_timeout():
	if is_multiplayer_authority():
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# The hit player's own peer sends it back to the start
	if body is Player and body.is_multiplayer_authority():
		body.die()
	if !is_multiplayer_authority():
		return
	# Despawning on the server also removes the ball on the clients
	queue_free()
