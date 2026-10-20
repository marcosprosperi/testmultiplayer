class_name Player extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
## Running right behind another player (slipstream) makes you faster,
## so the ones starting at the back can catch up
const SLIPSTREAM_RANGE = 140.0
const SLIPSTREAM_HEIGHT = 20.0
const SLIPSTREAM_BOOST = 1.2

@onready var camera_2d: Camera2D = $Camera2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var name_label: Label
# Synced so everyone sees the speed lines
var slipstream := false
# Added to the velocity for one frame by things like fans
var push := Vector2.ZERO

func _enter_tree():
	# Set authority based on the node name (which is now just the ID)
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if RaceManager.has_spawn():
		global_position = RaceManager.get_start_position(name.to_int())

	camera_2d.zoom = Vector2.ONE * RaceManager.get_camera_zoom()
	_create_name_label()
	PlayersManager.players_changed.connect(_update_name_label)

	animated_sprite_2d.scale.x = 1
	if is_multiplayer_authority():
		camera_2d.make_current()
		RaceManager.grid_changed.connect(_on_grid_changed)
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
		Sfx.play("jump", -6.0)

	var direction := 0.0 if frozen else Input.get_axis("left", "right")
	if velocity.x > 0:
		animated_sprite_2d.scale.x = 1 
	elif velocity.x < 0:
		animated_sprite_2d.scale.x = -1 
	
	
		
	slipstream = not frozen and _is_in_slipstream(direction)
	# Coins make you heavier (slower); the slipstream helps
	var speed = SPEED * RaceManager.speed_factor(name.to_int())
	if slipstream:
		speed *= SLIPSTREAM_BOOST

	if direction:
		velocity.x = direction * speed
		animated_sprite_2d.play("run")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	velocity.x += push.x
	push = Vector2.ZERO
	move_and_slide()

func _process(_delta: float) -> void:
	queue_redraw()

func _is_in_slipstream(direction: float) -> bool:
	if direction == 0:
		return false
	for other in get_tree().get_nodes_in_group("player"):
		if other == self:
			continue
		var distance_ahead = (other.global_position.x - global_position.x) * signf(direction)
		if distance_ahead > 8 and distance_ahead < SLIPSTREAM_RANGE \
				and absf(other.global_position.y - global_position.y) < SLIPSTREAM_HEIGHT:
			return true
	return false

# Speed lines behind the player while in the slipstream
func _draw() -> void:
	if not slipstream:
		return
	var back = -signf(animated_sprite_2d.scale.x)
	var flicker = (Time.get_ticks_msec() / 60) % 3
	for i in 3:
		var y = -6.0 - i * 6.0
		var start = 8.0 + ((i + flicker) % 3) * 3.0
		draw_line(Vector2(back * start, y), Vector2(back * (start + 12.0), y), Color(1, 1, 1, 0.7), 1.0)

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
	Sfx.play("death")
	respawn()

## Before the start: your grid slot. During the race: the back of the grid.
func respawn() -> void:
	if not is_multiplayer_authority():
		return
	velocity = Vector2.ZERO
	if not RaceManager.has_spawn():
		return
	if RaceManager.can_move():
		global_position = RaceManager.get_spawn_position()
	else:
		global_position = RaceManager.get_start_position(name.to_int())

# The grid can arrive after the level loads: move to your slot
func _on_grid_changed() -> void:
	if not RaceManager.can_move():
		respawn()
