@tool
class_name FallingPlatform extends AnimatableBody2D

## Floating platform that shakes and falls a moment after a player steps on
## it, then comes back. The server notices the player and tells everyone.

const TILE = 16
const TILESET = preload("res://resources/nature-paltformer-tileset-16x16.png")

@export_range(2, 16) var tiles := 3:
	set(value):
		tiles = value
		_update_shape()
		queue_redraw()
@export var shake_time := 0.8
@export var fall_distance := 400.0
@export var fall_time := 0.8
@export var respawn_time := 3.0

enum State { IDLE, SHAKING, FALLING }

var _state := State.IDLE
var _origin: Vector2

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var trigger: Area2D = $Trigger

func _ready() -> void:
	_origin = position
	_update_shape()
	if Engine.is_editor_hint():
		return
	trigger.body_entered.connect(_on_trigger_body_entered)

func _update_shape() -> void:
	if not is_inside_tree():
		return
	var width = tiles * TILE
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, TILE)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = Vector2(width / 2.0, TILE / 2.0)
	var trigger_shape = RectangleShape2D.new()
	trigger_shape.size = Vector2(width - 4, 6)
	$Trigger/CollisionShape2D.shape = trigger_shape
	$Trigger/CollisionShape2D.position = Vector2(width / 2.0, -3)

func _on_trigger_body_entered(body: Node2D) -> void:
	# The server sees every player, so it decides when the platform falls
	if multiplayer.is_server() and body is Player and _state == State.IDLE:
		_fall.rpc()

@rpc("authority", "call_local", "reliable")
func _fall() -> void:
	if _state != State.IDLE:
		return
	_state = State.SHAKING
	var shake = create_tween()
	for i in int(shake_time / 0.05):
		shake.tween_property(self, "position", _origin + Vector2(randf_range(-1.5, 1.5), 0), 0.05)
	await shake.finished

	_state = State.FALLING
	var drop = create_tween()
	drop.tween_property(self, "position", _origin + Vector2(0, fall_distance), fall_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.parallel().tween_property(self, "modulate:a", 0.0, fall_time)
	await drop.finished
	collision.set_deferred("disabled", true)

	await get_tree().create_timer(respawn_time).timeout
	position = _origin
	collision.set_deferred("disabled", false)
	var appear = create_tween()
	appear.tween_property(self, "modulate:a", 1.0, 0.3)
	_state = State.IDLE

# Drawn from the tileset's floating platform tiles: left, middle, right
func _draw() -> void:
	for i in tiles:
		var column = 3 if i == 0 else (5 if i == tiles - 1 else 4)
		draw_texture_rect_region(TILESET, Rect2(i * TILE, 0, TILE, TILE), Rect2(column * TILE, 0, TILE, TILE))
