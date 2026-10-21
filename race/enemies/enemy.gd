@tool
class_name Enemy extends Area2D

## Base for enemies. They walk (or fly) back and forth between their start and
## start + travel, driven by the race clock, so they're in the same place on
## every screen without syncing. Touching one sends you back; landing on top
## of a stompable one squashes it (you bounce) until it comes back.

@export var travel := Vector2(96, 0):
	set(value):
		travel = value
		queue_redraw()
## Pixels per second
@export var speed := 40.0
## 0..1: where along its patrol it starts
@export_range(0.0, 1.0) var phase := 0.0
## Seconds until a squashed enemy comes back
@export var respawn_time := 6.0

## Can be squashed by landing on it
var stompable := true
## Height of the body above the node's position (for stomp checks)
var body_height := 10.0
## 1 = facing right, -1 = left
var facing := 1

var _origin: Vector2
var _dead := false
var _dead_left := 0.0
# Blinks (harmless) for a moment when it comes back
var _reviving_left := 0.0

func _ready() -> void:
	_origin = position
	if Engine.is_editor_hint():
		return
	add_to_group("enemy")
	collision_layer = 0
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		return
	if _dead:
		_dead_left -= delta
		if _dead_left <= 0.0:
			_dead = false
			_reviving_left = 1.0
	elif _reviving_left > 0.0:
		_reviving_left -= delta
		if _reviving_left <= 0.0:
			set_deferred("monitoring", true)
	position = _origin + patrol_offset(RaceManager.race_time())

## Where it is along its patrol at race time t (also sets facing)
func patrol_offset(t: float) -> Vector2:
	var length = travel.length()
	if length < 1.0:
		return Vector2.ZERO
	var d = fposmod(t * speed + phase * length * 2.0, length * 2.0)
	var forward = d < length
	var along = d if forward else length * 2.0 - d
	var direction = signf(travel.x) if travel.x != 0 else 1.0
	facing = int(direction) if forward else -int(direction)
	return travel.normalized() * along

func is_alive() -> bool:
	return not _dead and _reviving_left <= 0.0

func _on_body_entered(body: Node2D) -> void:
	if not is_alive() or not body is Player or not body.is_multiplayer_authority():
		return
	# Each player's own screen decides: coming down on it squashes it (the
	# overlap is noticed a frame late, so only the feet being above its base
	# matters), anything else hurts
	var landing_on_top = body.velocity.y > 50.0 and body.global_position.y < global_position.y - 1.0
	if stompable and landing_on_top:
		body.bounce()
		Sfx.play("stomp")
		_squash()
		_request_stomp.rpc_id(1)
	else:
		body.die()

@rpc("any_peer", "call_local", "reliable")
func _request_stomp() -> void:
	if multiplayer.is_server():
		_squashed.rpc()

@rpc("authority", "call_local", "reliable")
func _squashed() -> void:
	if not _dead:
		_squash()

func _squash() -> void:
	_dead = true
	_dead_left = respawn_time
	_reviving_left = 0.0
	set_deferred("monitoring", false)

## How the subclasses know what to draw
func draw_state() -> String:
	if _dead:
		return "squashed" if _dead_left > respawn_time - 0.4 else "gone"
	if _reviving_left > 0.0 and int(_reviving_left * 10) % 2 == 0:
		return "gone"
	return "alive"

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_dashed_line(Vector2.ZERO, travel, Color(1, 0.5, 0.3, 0.7), 1.0, 4.0)
