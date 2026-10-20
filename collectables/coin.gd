class_name Coin extends Area2D

## +1 championship point at the end of the race, but each coin makes you
## slower (see RaceManager). The host can turn coins off in the lobby, and
## then they don't show up at all.

var _taken := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	PlayersManager.settings_changed.connect(_apply_setting)
	_apply_setting()

func _apply_setting() -> void:
	visible = PlayersManager.coins_enabled()
	set_deferred("monitoring", visible)

# The server sees every player, so it decides who got the coin
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server() or _taken or not visible:
		return
	if not body is Player or RaceManager.state != RaceManager.State.RACING:
		return
	var id = body.name.to_int()
	if RaceManager.has_finished(id):
		return
	_taken = true
	RaceManager.collect_coin(id)
	_take.rpc(id)

@rpc("authority", "call_local", "reliable")
func _take(id: int) -> void:
	if id == multiplayer.get_unique_id():
		Sfx.play("coin")
	queue_free()
