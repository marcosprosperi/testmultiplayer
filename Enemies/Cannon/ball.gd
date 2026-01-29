class_name Ball extends Area2D

const SPEED: int = 600

var direction: int
var damage: int = 1
@onready var life_timer: Timer = $LifeTimer

func _ready() -> void:
	life_timer.timeout.connect(_on_life_timer_timeout)
	body_entered.connect(_test_on_body_entered)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position.x += direction * SPEED * delta
	


func _on_life_timer_timeout():
	#if is_multiplayer_authority():
		#queue_free()
	pass

func _test_on_body_entered(body: Node2D) -> void:
	print(body)
	pass # Replace with function body.
