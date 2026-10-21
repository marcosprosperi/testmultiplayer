class_name Peel extends Area2D

## Banana peel left behind with the Cáscara power-up. Whoever steps on it
## slips (stuck for a moment) and it's gone. The one who dropped it has a
## moment to get away from it first.

const GRACE_TIME = 1.0
## Peels nobody stepped on go away after this long
const LIFETIME = 20.0

var owner_id := 0
var _dropped_at := 0.0

func _ready() -> void:
	add_to_group("peel")
	collision_layer = 0
	_dropped_at = RaceManager.race_time()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(12, 6)
	var collision = CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -3)
	add_child(collision)
	body_entered.connect(_on_body_entered)
	_drop_to_floor.call_deferred()
	if multiplayer.is_server():
		get_tree().create_timer(LIFETIME).timeout.connect(func():
			if is_inside_tree():
				RaceManager.peel_hit(name))

# Dropped in the air it falls to the floor; over a pit it's lost
func _drop_to_floor() -> void:
	var query = PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), global_position + Vector2(0, 240), 512)
	var hit = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		queue_free()
	else:
		global_position = hit.position

func _on_body_entered(body: Node2D) -> void:
	# Whoever moves the player decides, like with enemies
	if not body is Player or not body.is_multiplayer_authority():
		return
	var id = body.name.to_int()
	if id == owner_id and RaceManager.race_time() - _dropped_at < GRACE_TIME:
		return
	if RaceManager.has_effect(id, "star"):
		return
	body.slip()
	set_deferred("monitoring", false)
	visible = false
	RaceManager.peel_hit(name)

func _draw() -> void:
	PowerUps.draw_icon(self, PowerUps.PEEL, Vector2(0, -3), 12.0)
