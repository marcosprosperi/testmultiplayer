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
## Width of your feet: what's under the outer pixel of each side doesn't hold you
const UNSNAG_WIDTH = 9.0
## The camera looks this far ahead of where you're running
const LOOK_AHEAD = 70.0
## Seconds you stay "gone" (a poof) after losing, before coming back
const DEATH_TIME = 0.45
## On ice you speed up and slow down slowly (pixels per second²)
const ICE_ACCEL = 650.0
const ICE_FRICTION = 260.0

@onready var camera_2d: Camera2D = $Camera2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

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
var _look_ahead := 0.0
var _was_on_floor := true
var _dying := false
# Only on your own screen: darkens it for a moment when you lose
var _fade: ColorRect
# Can't be hurt for a moment after a shield saved you
var _safe_left := 0.0
# Slipped on a peel: can't move for a moment
var _stun_left := 0.0
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
	camera_2d.position_smoothing_enabled = true
	camera_2d.position_smoothing_speed = 7.0
	_create_name_label()
	PlayersManager.players_changed.connect(_update_name_label)

	animated_sprite_2d.scale.x = 1
	if is_bot() and multiplayer.is_server():
		brain = BotBrain.new(self, PlayersManager.bot_skill(name.to_int()))
	if is_local():
		camera_2d.make_current()
		RaceManager.grid_changed.connect(_on_grid_changed)
		RaceManager.notify_local_ready()
		var layer = CanvasLayer.new()
		layer.layer = 4
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0.08, 0.04, 0.12, 0.0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_fade)
	else:
		camera_2d.enabled = false

func _physics_process(delta: float) -> void:
	# Only the player with authority processes input
	if not is_multiplayer_authority() or _dying:
		return
		
	if is_on_floor() && int(velocity.x) == 0:
		animated_sprite_2d.play("idle")
		
	if not is_on_floor():
		velocity += get_gravity() * delta
		animated_sprite_2d.play("jump")

	# Frozen until the countdown ends; after the finish line the controls
	# are used to switch spectator cameras
	var frozen := RaceManager.has_finished(name.to_int()) or not RaceManager.can_move() or _stun_left > 0.0
	_safe_left = maxf(_safe_left - delta, 0.0)
	_stun_left = maxf(_stun_left - delta, 0.0)

	var bot_input = brain.update(delta) if brain else {}
	# Your keys don't move you while a menu is open over the race
	var keys = brain == null and not Settings.menu_open
	if keys and Input.is_action_just_pressed("use_item") and RaceManager.item_of(name.to_int()) != "" \
			and not ItemSlot.rolling:
		RaceManager.request_use_item.rpc_id(1)
	if is_on_floor():
		_coyote_left = COYOTE_TIME
	else:
		_coyote_left -= delta
	if bot_input.get("jump", false) or (keys and Input.is_action_just_pressed("jump")):
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
		direction = bot_input.get("dir", 0.0) if brain else (Input.get_axis("left", "right") if keys else 0.0)
	if velocity.x > 0:
		animated_sprite_2d.scale.x = 1 
	elif velocity.x < 0:
		animated_sprite_2d.scale.x = -1 
	
	
		
	slipstream = not frozen and _is_in_slipstream(direction)
	# Coins make you heavier (slower); the slipstream helps
	var speed = SPEED * RaceManager.speed_factor(name.to_int())
	if slipstream:
		speed *= SLIPSTREAM_BOOST

	var on_ice = is_on_floor() and get_tree().get_nodes_in_group("ice").any(func(ice): return ice.overlaps_body(self))
	if direction:
		if on_ice:
			velocity.x = move_toward(velocity.x, direction * speed, ICE_ACCEL * delta)
		else:
			velocity.x = direction * speed
		animated_sprite_2d.play("run")
	else:
		velocity.x = move_toward(velocity.x, 0, ICE_FRICTION * delta if on_ice else SPEED)

	velocity.x += push.x
	push = Vector2.ZERO
	var rising = velocity.y < -100.0
	move_and_slide()
	# A puff of dust when jumping off the floor and when landing
	if _was_on_floor and not is_on_floor() and rising:
		_show_fx.rpc(Fx.DUST, global_position)
	elif not _was_on_floor and is_on_floor():
		_show_fx.rpc(Fx.DUST, global_position)
	_was_on_floor = is_on_floor()
	_unsnag()

func _process(delta: float) -> void:
	queue_redraw()
	_update_name_visibility()
	if is_local():
		# Look ahead the way you're running (smoothly, so turning isn't jumpy)
		var target = signf(velocity.x) * LOOK_AHEAD if absf(velocity.x) > 40.0 else _look_ahead
		_look_ahead = move_toward(_look_ahead, target, 120.0 * delta)
		camera_2d.offset = RaceManager.get_camera_offset() + Vector2(_look_ahead, 0)

## Effects everyone sees (sent by whoever moves this player)
@rpc("authority", "call_local", "unreliable")
func _show_fx(kind: String, at: Vector2) -> void:
	Fx.spawn(kind, at, PlayersManager.color_of(name.to_int()))

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
	_draw_effects()
	if not slipstream:
		return
	var back = -signf(animated_sprite_2d.scale.x)
	var flicker = (Time.get_ticks_msec() / 60) % 3
	for i in 3:
		var y = -6.0 - i * 6.0
		var start = 8.0 + ((i + flicker) % 3) * 3.0
		draw_line(Vector2(back * start, y), Vector2(back * (start + 12.0), y), Color(1, 1, 1, 0.7), 1.0)

# Name tag over the head, in the player's color on a dark pill. Yours is
# a "VOS" arrow instead, so you always find yourself
func _create_name_label() -> void:
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 7)
	var pill = StyleBoxFlat.new()
	pill.bg_color = Color(0.1, 0.06, 0.15, 0.6)
	pill.set_corner_radius_all(4)
	pill.content_margin_left = 3
	pill.content_margin_right = 3
	name_label.add_theme_stylebox_override("normal", pill)
	add_child(name_label)
	_update_name_label()

func _update_name_label() -> void:
	var id = name.to_int()
	if is_local():
		name_label.text = "▼ VOS"
		name_label.add_theme_color_override("font_color", Color("#ffd23f"))
		name_label.add_theme_color_override("font_outline_color", Color(0.17, 0.11, 0.23))
		name_label.add_theme_constant_override("outline_size", 3)
		name_label.get_theme_stylebox("normal").bg_color = Color(0, 0, 0, 0)
	else:
		name_label.text = PlayersManager.name_of(id)
		name_label.add_theme_color_override("font_color", PlayersManager.color_of(id).lightened(0.25))
	name_label.reset_size()
	name_label.position = Vector2(-name_label.size.x / 2.0, -36)
	PlayerLook.paint(animated_sprite_2d, PlayersManager.color_of(id))

# When players bunch up, only one name per bunch shows (yours always does)
func _update_name_visibility() -> void:
	if _dying or not animated_sprite_2d.visible:
		return
	if is_local():
		name_label.visible = true
		name_label.position.y = -38 + sin(Time.get_ticks_msec() / 200.0) * 1.5
		return
	var id = name.to_int()
	var crowded = false
	for other in get_tree().get_nodes_in_group("player"):
		if other == self or not other.animated_sprite_2d.visible:
			continue
		var close = absf(other.global_position.x - global_position.x) < 30 \
			and absf(other.global_position.y - global_position.y) < 12
		# The local player's tag or the lower id wins the spot
		if close and (other.is_local() or other.name.to_int() < id):
			crowded = true
			break
	name_label.visible = not crowded

## Stepped on a banana peel: spin in place for a moment
func slip() -> void:
	if RaceManager.has_effect(name.to_int(), "star"):
		return
	_stun_left = PowerUps.STUN_TIME
	velocity.x = 0.0
	Sfx.play_at("slip", global_position)

# Sliding down a wall, the box can catch on the corner where two blocks
# meet and take it for floor. With nothing really under your feet, step a
# little away from the wall and below the corner, and keep falling.
func _unsnag() -> void:
	if not is_on_floor():
		return
	var feet = RectangleShape2D.new()
	feet.size = Vector2(UNSNAG_WIDTH, 2)
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = feet
	query.transform = Transform2D(0, global_position + Vector2(collision_shape.position.x, 1))
	query.collision_mask = collision_mask
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return
	var corner = null
	for i in get_slide_collision_count():
		var hit = get_slide_collision(i)
		if hit.get_normal().y < -0.5:
			corner = hit.get_position()
	if corner == null:
		return
	var away = Vector2(signf(global_position.x + collision_shape.position.x - corner.x) * 1.5, 0)
	var moved = global_transform
	moved.origin += away
	if not test_move(moved, Vector2(0, 1)):
		global_position += away + Vector2(0, 1)

## Called when you land on an enemy you can squash
func bounce() -> void:
	velocity.y = STOMP_BOUNCE
	_coyote_left = 0.0

## Losing sends the player back to the start of the level. A star or a
## shield saves you from traps and enemies, but not from falling (pit)
func die(pit := false) -> void:
	if not is_multiplayer_authority():
		return
	var id = name.to_int()
	if not pit:
		if _safe_left > 0.0 or RaceManager.has_effect(id, "star"):
			return
		if RaceManager.has_effect(id, "shield"):
			RaceManager.break_shield(id)
			_safe_left = 1.2
			bounce()
			Sfx.play_at("shield_break", global_position)
			return
	if _dying:
		return
	if is_local():
		Sfx.play("death")
	# Poof! Gone for a moment, then back at the flag (or the start)
	_dying = true
	velocity = Vector2.ZERO
	_set_gone.rpc(true)
	_show_fx.rpc(Fx.POOF, global_position + Vector2(0, -8))
	if _fade:
		create_tween().tween_property(_fade, "color:a", 0.55, DEATH_TIME)
	await get_tree().create_timer(DEATH_TIME).timeout
	if not is_inside_tree():
		return
	respawn()
	_dying = false
	_set_gone.rpc(false)
	_show_fx.rpc(Fx.SPARKLE, global_position + Vector2(0, -8))
	if _fade:
		create_tween().tween_property(_fade, "color:a", 0.0, 0.25)

@rpc("authority", "call_local", "reliable")
func _set_gone(gone: bool) -> void:
	animated_sprite_2d.visible = not gone
	name_label.visible = not gone

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
	snap_camera()

## After a teleport: the camera jumps there instead of gliding across the level
func snap_camera() -> void:
	_look_ahead = 0.0
	camera_2d.force_update_scroll()
	camera_2d.reset_smoothing()

# The grid can arrive after the level loads: move to your slot
func _on_grid_changed() -> void:
	if not RaceManager.can_move():
		respawn()

# Power-up effects everyone sees: shield bubble, star colors, turbo flames,
# the lightning's little storm cloud, and stars spinning after a slip
func _draw_effects() -> void:
	var id = name.to_int()
	var t = Time.get_ticks_msec() / 1000.0
	var tint = Color.WHITE
	if RaceManager.has_effect(id, "star"):
		tint = Color.from_hsv(fposmod(t * 2.0, 1.0), 0.5, 1.0)
	elif RaceManager.has_effect(id, "slow"):
		tint = Color(0.6, 0.7, 1.0)
	if _safe_left > 0.0 and int(_safe_left * 12) % 2 == 0:
		tint.a = 0.35
	animated_sprite_2d.modulate = tint
	if RaceManager.has_effect(id, "shield"):
		draw_circle(Vector2(0, -8), 13.0, Color(0.45, 0.8, 1.0, 0.18))
		draw_arc(Vector2(0, -8), 13.0, 0, TAU, 24, Color(0.5, 0.85, 1.0, 0.8), 1.0)
	if RaceManager.has_effect(id, "turbo"):
		var back = -signf(animated_sprite_2d.scale.x)
		for i in 3:
			var length = 6.0 + fposmod(t * 30.0 + i * 3.0, 6.0)
			draw_line(Vector2(back * 7, -4 - i * 3), Vector2(back * (7 + length), -4 - i * 3),
				[Color("#ffd23f"), Color("#ff9f1c"), Color("#ff5e5b")][i], 2.0)
	if RaceManager.has_effect(id, "slow"):
		var cloud = Vector2(0, -34)
		for x in [-5.0, 0.0, 5.0]:
			draw_circle(cloud + Vector2(x, absf(x) * 0.3), 4.0, Color(0.45, 0.47, 0.55))
		if fposmod(t, 0.5) < 0.12:
			draw_polyline(PackedVector2Array([cloud + Vector2(1, 3), cloud + Vector2(-2, 8), cloud + Vector2(1, 8),
				cloud + Vector2(-1, 13)]), Color("#fff36b"), 1.0)
	if _stun_left > 0.0:
		for i in 3:
			var a = t * 8.0 + i * TAU / 3.0
			PowerUps.draw_icon(self, PowerUps.STAR, Vector2(cos(a) * 8, -30 + sin(a) * 3), 5.0)
