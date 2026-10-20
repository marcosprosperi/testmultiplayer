class_name Player extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var camera_2d: Camera2D = $Camera2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var name_label: Label

func _enter_tree():
	# Set authority based on the node name (which is now just the ID)
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if RaceManager.has_spawn():
		global_position = RaceManager.get_spawn_position()

	_create_name_label()
	PlayersManager.players_changed.connect(_update_name_label)

	animated_sprite_2d.scale.x = 1
	if is_multiplayer_authority():
		camera_2d.make_current()
		RaceManager.notify_local_ready()
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

	# Frozen until the countdown ends; after the finish line the controls
	# are used to switch spectator cameras
	var frozen := RaceManager.has_finished(name.to_int()) or not RaceManager.can_move()

	if Input.is_action_just_pressed("jump") and is_on_floor() and not frozen:
		velocity.y = JUMP_VELOCITY

	var direction := 0.0 if frozen else Input.get_axis("left", "right")
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

# Name in the player's color floating over their head
func _create_name_label() -> void:
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(80, 12)
	name_label.position = Vector2(-40, -40)
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 3)
	add_child(name_label)
	_update_name_label()

func _update_name_label() -> void:
	var id = name.to_int()
	name_label.text = PlayersManager.name_of(id)
	name_label.add_theme_color_override("font_color", PlayersManager.color_of(id))

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
