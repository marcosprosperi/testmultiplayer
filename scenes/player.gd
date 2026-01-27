class_name Player extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var camera_2d: Camera2D = $Camera2D
@onready var sprite_2d: Sprite2D = $Sprite2D # Best practice to @onready children

func _enter_tree():
	# Set authority based on the node name (which is now just the ID)
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	# Only the local player controls their own camera
	if is_multiplayer_authority():
		camera_2d.make_current()
		sprite_2d.modulate = Color.BLUE
	else:
		camera_2d.enabled = false
		sprite_2d.modulate = Color.RED

func _physics_process(delta: float) -> void:
	# Only the player with authority processes input
	if not is_multiplayer_authority():
		return
		
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
