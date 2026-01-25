class_name Player extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var health = 0

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if is_multiplayer_authority():
		$Sprite2D.modulate = Color.BLUE
	else:
		$Sprite2D.modulate = Color.RED

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
 	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
