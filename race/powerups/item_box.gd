@tool
class_name ItemBox extends Area2D

## "?" box: run into it to get a power-up (if you aren't holding one). What
## you get depends on your place: the further back, the better. It comes
## back a few seconds after someone takes it. The host can turn power-ups
## off in the lobby, and then boxes don't show up.

const SIZE = 12.0
const BACK_AFTER = 4.0
const OUTLINE = Color(0.17, 0.11, 0.23)

# Race time when it shows up again after being taken
var _back_at := -1.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("item_box")
	collision_layer = 0
	var shape = RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE)
	var collision = CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)

func is_available() -> bool:
	return PlayersManager.items_enabled() and RaceManager.race_time() >= _back_at

# The server sees every player, so it decides who got it
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server() or not body is Player or not is_available():
		return
	if RaceManager.give_item(body.name.to_int()):
		_taken.rpc(body.name.to_int())

@rpc("authority", "call_local", "reliable")
func _taken(id: int) -> void:
	_back_at = RaceManager.race_time() + BACK_AFTER
	# The box bursts (the sound comes when your slot stops spinning)
	Fx.spawn(Fx.SPARKLE, global_position, Color.from_hsv(randf(), 0.6, 1.0))
	Fx.spawn(Fx.STOMP, global_position + Vector2(0, 6))

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() and not is_available():
		return
	var t = Time.get_ticks_msec() / 1000.0
	var bob = Vector2(0, sin(t * 3.0 + position.x * 0.05) * 1.5)
	var rect = Rect2(Vector2(-SIZE, -SIZE) / 2.0 + bob, Vector2(SIZE, SIZE))
	# Rainbow edge that keeps changing color
	var edge = Color.from_hsv(fposmod(t * 0.4 + position.x * 0.002, 1.0), 0.7, 1.0)
	draw_rect(rect.grow(1.5), OUTLINE)
	draw_rect(rect, edge)
	draw_rect(rect.grow(-2.0), Color(1, 0.98, 0.9, 0.9))
	var theme = ThemeDB.get_project_theme()
	var font = theme.default_font if theme and theme.default_font else ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(3.0, 10.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, OUTLINE)
