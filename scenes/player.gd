class_name Player extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
## Running right behind another player (slipstream) makes you faster,
## so the ones starting at the back can catch up
const SLIPSTREAM_RANGE = 140.0
const SLIPSTREAM_HEIGHT = 20.0
const SLIPSTREAM_BOOST = 1.2
## Coyote time: you can still jump this long after running off an edge
const COYOTE_TIME = 0.1
## Jump buffer: pressing jump this long before landing still jumps
const JUMP_BUFFER = 0.12
## Bounce after stomping an enemy
const STOMP_BOUNCE = -300.0

@onready var camera_2d: Camera2D = $Camera2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var name_label: Label
# Synced so everyone sees the speed lines
var slipstream := false
# Added to the velocity for one frame by things like fans
var push := Vector2.ZERO
# Last checkpoint flag touched in this level (if the host turned them on)
var checkpoint = null
# Bots (negative ids, run by the server) are driven by this instead of the keyboard
var brain: BotBrain = null
var _coyote_left := 0.0
var _jump_buffer_left := 0.0

func _enter_tree():
	# Set authority based on the node name (which is now just the ID); bots
	# have negative ids and belong to the server
	set_multiplayer_authority(1 if is_bot() else name.to_int())

## Bots fill the race up to 8 players; the server moves them
func is_bot() -> bool:
	return name.to_int() < 0

## The player this computer controls (not a bot, not someone else)
func is_local() -> bool:
	return is_multiplayer_authority() and not is_bot()

func _ready() -> void:
	if RaceManager.has_spawn():
		global_position = RaceManager.get_start_position(name.to_int())

	camera_2d.zoom = Vector2.ONE * RaceManager.get_camera_zoom()
	camera_2d.offset = RaceManager.get_camera_offset()
	_create_name_label()
	PlayersManager.players_changed.connect(_update_name_label)

	animated_sprite_2d.scale.x = 1
	if is_bot() and multiplayer.is_server():
		brain = BotBrain.new(self, PlayersManager.bot_skill(name.to_int()))
	if is_local():
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

	var bot_input = brain.update(delta) if brain else {}
	if is_on_floor():
		_coyote_left = COYOTE_TIME
	else:
		_coyote_left -= delta
	if bot_input.get("jump", false) if brain else Input.is_action_just_pressed("jump"):
		_jump_buffer_left = JUMP_BUFFER
	else:
		_jump_buffer_left -= delta

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0 and not frozen:
		velocity.y = JUMP_VELOCITY
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		if is_local():
			Sfx.play("jump", -6.0)

	var direction := 0.0
	if not frozen:
		direction = bot_input.get("dir", 0.0) if brain else Input.get_axis("left", "right")
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
	# Bots don't get it (or they'd all run as one pack); people behind a bot do
	if direction == 0 or is_bot():
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

## Called when you land on an enemy you can squash
func bounce() -> void:
	velocity.y = STOMP_BOUNCE
	_coyote_left = 0.0

## Losing sends the player back to the start of the level
func die() -> void:
	if not is_multiplayer_authority():
		return
	if is_local():
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
		if checkpoint != null and PlayersManager.checkpoints_enabled():
			global_position = checkpoint
		else:
			global_position = RaceManager.get_spawn_position()
	else:
		# A new level is starting
		checkpoint = null
		global_position = RaceManager.get_start_position(name.to_int())

# The grid can arrive after the level loads: move to your slot
func _on_grid_changed() -> void:
	if not RaceManager.can_move():
		respawn()
