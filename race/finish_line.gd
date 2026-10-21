@tool
class_name FinishLine extends Area2D

const HEIGHT = 48.0
const SQUARE = 6.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	RaceManager.player_finished.connect(_celebrate)

# Confetti for everyone who crosses (on every screen)
func _celebrate(_id: int, _place: int) -> void:
	Fx.spawn(Fx.CONFETTI, global_position + Vector2(0, -30))

func _on_body_entered(body: Node2D) -> void:
	if body is Player and body.is_multiplayer_authority() \
			and not RaceManager.has_finished(body.name.to_int()):
		if body.is_bot():
			RaceManager.report_bot_finish(body.name.to_int())
		else:
			Sfx.play("finish")
			RaceManager.report_finish.rpc_id(1)

# Checkered flag on a pole, drawn so it doesn't need a texture
func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(0, -HEIGHT), Color(0.35, 0.25, 0.15), 2.0)
	for row in 3:
		for col in 4:
			var color = Color.WHITE if (row + col) % 2 == 0 else Color.BLACK
			draw_rect(Rect2(1 + col * SQUARE, -HEIGHT + row * SQUARE, SQUARE, SQUARE), color)
