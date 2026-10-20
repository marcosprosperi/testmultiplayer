class_name Player extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var camera_2d: Camera2D = $Camera2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _enter_tree():
	# Set authority based on the node name (which is now just the ID)
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if RaceManager.has_spawn():
		global_position = RaceManager.get_spawn_position()

	animated_sprite_2d.scale.x = 1
	if is_multiplayer_authority():
		camera_2d.make_current()
	else:
		camera_2d.enabled = false

func _physics_process(delta: float) -> void:
	# Only the player with authority processes input
	if not is_multiplayer_authority():
		return
		
	if is_on_floor() && int(velocity.x) == 0:
		animated_sprite_2d.play("idle")
		
	if not is_on_floor():
		velocity += get_gravity() * delta
		animated_sprite_2d.play("jump")

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("left", "right")
	if velocity.x > 0:
		animated_sprite_2d.scale.x = 1 
	elif velocity.x < 0:
		animated_sprite_2d.scale.x = -1 
	
	
		
	if direction:
		velocity.x = direction * SPEED
		animated_sprite_2d.play("run")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

## Losing sends the player back to the start of the level
func die() -> void:
	if not is_multiplayer_authority():
		return
	respawn()

func respawn() -> void:
	if not is_multiplayer_authority():
		return
	velocity = Vector2.ZERO
	if RaceManager.has_spawn():
		global_position = RaceManager.get_spawn_position()
