extends Node

## Championship points by finishing position (1st, 2nd, ...)
const POINTS = [10, 8, 6, 5, 4, 3, 2, 1]
## Each coin is +1 point but makes you this much slower, up to MAX_SLOWDOWN
const COIN_SLOWDOWN = 0.04
const MAX_SLOWDOWN = 0.3
## Seconds the results table stays up before the next race
const RESULTS_TIME = 6.0
## Seconds the champion is shown before a new championship starts
const FINAL_RESULTS_TIME = 10.0
const COUNTDOWN_FROM = 3
## Start anyway if someone takes longer than this to load the level
const MAX_WAIT_FOR_PLAYERS = 10.0
## Distance between starting grid slots
const GRID_GAP = 22.0

enum State { WAITING, COUNTDOWN, RACING }

signal finish_order_changed
signal state_changed
signal grid_changed
signal round_changed
signal coins_changed
# Someone stepped on a TrapButton (emitted on every screen)
signal trap_triggered(id: int)
# Everyone finished: results is [{id, name, color, position, gained, total}]
signal results_shown(results: Array, final: bool)

var state := State.WAITING
# Coins picked up by each player in this race (synced by the server)
var race_coins = {}
# Which race of the championship this is (0-based) and how many there are
var round_index := 0
var rounds_total := 1
# 3, 2, 1 during the countdown
var countdown_value := 0
# Server only: players that have the level and their character loaded
var _ready_players := {}
# Bumped on every level so timers from a previous one stop
var _race_token := 0
var _racing_since_msec := 0
# Starting grid, pole position first (synced by the server)
var grid_order: Array = []
# Server only: result of the previous level, used to build the next grid
var _last_finish_order: Array = []

var current_level: Node2D
# Peer ids in the order they crossed the finish line (synced by the server)
var finish_order: Array = []
var _changing_level := false

func _ready() -> void:
	PlayersManager.players_changed.connect(_check_everyone_finished)
	PlayersManager.players_changed.connect(_check_everyone_ready)

func register_level(level: Node2D) -> void:
	current_level = level
	if multiplayer.is_server():
		if not finish_order.is_empty():
			_last_finish_order = finish_order.duplicate()
		grid_order = _build_grid()
		_sync_grid.rpc(grid_order)
		finish_order.clear()
		_changing_level = false
		_ready_players.clear()
		_race_token += 1
		_sync_finish_order.rpc(finish_order)
		_sync_coins.rpc({})
		_sync_state.rpc(State.WAITING, 0)
		_start_anyway_after_timeout(_race_token)

func reset() -> void:
	current_level = null
	finish_order = []
	_changing_level = false
	_ready_players.clear()
	_race_token += 1
	state = State.WAITING
	grid_order = []
	_last_finish_order = []
	race_coins = {}
	finish_order_changed.emit()
	state_changed.emit()
	grid_changed.emit()

func send_state_to(id: int) -> void:
	_sync_finish_order.rpc_id(id, finish_order)
	_sync_state.rpc_id(id, state, countdown_value, race_time())
	_sync_grid.rpc_id(id, grid_order)
	_sync_round.rpc_id(id, round_index, rounds_total)
	_sync_coins.rpc_id(id, race_coins)

func coins_of(id: int) -> int:
	return race_coins.get(id, 0)

## 1.0 = normal speed; each coin carried this race makes you slower
func speed_factor(id: int) -> float:
	if not PlayersManager.coins_enabled():
		return 1.0
	return 1.0 - minf(coins_of(id) * COIN_SLOWDOWN, MAX_SLOWDOWN)

## Server only: called by a coin when a player touches it
func collect_coin(id: int) -> void:
	if multiplayer.is_server():
		race_coins[id] = coins_of(id) + 1
		_sync_coins.rpc(race_coins)

@rpc("authority", "call_local", "reliable")
func _sync_coins(coins: Dictionary) -> void:
	race_coins = coins
	coins_changed.emit()

## Server only: called by Main before loading each level
func set_round(index: int, total: int) -> void:
	if multiplayer.is_server():
		_sync_round.rpc(index, total)

func is_last_round() -> bool:
	return round_index >= rounds_total - 1

@rpc("authority", "call_local", "reliable")
func _sync_round(index: int, total: int) -> void:
	round_index = index
	rounds_total = total
	round_changed.emit()

## Players can only move once the countdown is over
func can_move() -> bool:
	return state == State.RACING

## Called by the level and the local player: once both exist, tell the server
func notify_local_ready() -> void:
	if not is_instance_valid(current_level):
		return
	if not get_tree().get_nodes_in_group("player").any(func(p): return p.is_multiplayer_authority()):
		return
	report_ready.rpc_id(1, current_level.name)

@rpc("any_peer", "call_local", "reliable")
func report_ready(level_name: String) -> void:
	if not multiplayer.is_server() or not is_instance_valid(current_level):
		return
	if level_name != current_level.name or state != State.WAITING:
		return
	var id = multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()
	_ready_players[id] = true
	_check_everyone_ready()

# Also runs when someone leaves, so the countdown doesn't wait for them
func _check_everyone_ready() -> void:
	if not multiplayer.is_server() or state != State.WAITING or not is_instance_valid(current_level):
		return
	var players = PlayersManager.joined_players.keys()
	if not players.is_empty() and players.all(func(id): return _ready_players.has(id)):
		_run_countdown()

# First race: random order. Then a reversed grid: whoever won starts last,
# so the same player doesn't always lead. New players start at the back.
func _build_grid() -> Array:
	var ids = PlayersManager.joined_players.keys()
	if _last_finish_order.is_empty():
		ids.shuffle()
		return ids
	var order = _last_finish_order.filter(func(id): return ids.has(id))
	order.reverse()
	for id in ids:
		if not order.has(id):
			order.append(id)
	return order

@rpc("authority", "call_local", "reliable")
func _sync_grid(order: Array) -> void:
	grid_order = order
	grid_changed.emit()

func _start_anyway_after_timeout(token: int) -> void:
	await get_tree().create_timer(MAX_WAIT_FOR_PLAYERS).timeout
	if token == _race_token and state == State.WAITING and not PlayersManager.joined_players.is_empty():
		_run_countdown()

func _run_countdown() -> void:
	var token = _race_token
	state = State.COUNTDOWN
	for value in range(COUNTDOWN_FROM, 0, -1):
		_sync_state.rpc(State.COUNTDOWN, value)
		await get_tree().create_timer(1.0).timeout
		if token != _race_token:
			return
	_sync_state.rpc(State.RACING, 0)

@rpc("authority", "call_local", "reliable")
func _sync_state(new_state: State, value: int, elapsed := 0.0) -> void:
	if new_state == State.RACING and (state != State.RACING or elapsed > 0.0):
		_racing_since_msec = Time.get_ticks_msec() - int(elapsed * 1000.0)
	state = new_state
	countdown_value = value
	state_changed.emit()

func get_spawn_position() -> Vector2:
	var spawn = _find_in_level("spawn")
	return spawn.global_position if spawn else Vector2.ZERO

## Grid slot for the start of the race. The Spawn marker is the back of the
## grid (where players go after losing) and the pole is ahead of it.
## Players not in the grid (joined late) start at the back.
func get_start_position(id: int) -> Vector2:
	var spawn = get_spawn_position()
	var index = grid_order.find(id)
	if index == -1:
		return spawn
	var slots_from_back = grid_order.size() - 1 - index
	return spawn + Vector2(slots_from_back * GRID_GAP, 0)

func has_spawn() -> bool:
	return _find_in_level("spawn") != null

func get_finish() -> Node2D:
	return _find_in_level("finish")

## 0.0 at the start, 1.0 at the finish line, measured along the straight
## line from the spawn to the finish (works for sideways and vertical levels)
func get_progress(player: Node2D) -> float:
	var finish = get_finish()
	if finish == null or !has_spawn():
		return 0.0
	var start = get_spawn_position()
	var course = finish.global_position - start
	if course.is_zero_approx():
		return 0.0
	return clampf((player.global_position - start).dot(course) / course.length_squared(), 0.0, 1.0)

## Seconds since "¡ARRANCA!" (0 before). Moving parts that must look the same
## on every screen (like the balloons) are driven by this clock.
func race_time() -> float:
	if state != State.RACING:
		return 0.0
	return (Time.get_ticks_msec() - _racing_since_msec) / 1000.0

func get_camera_zoom() -> float:
	return current_level.camera_zoom if is_instance_valid(current_level) and "camera_zoom" in current_level else 1.0

func has_finished(id: int) -> bool:
	return finish_order.has(id)

@rpc("any_peer", "call_local", "reliable")
func report_finish() -> void:
	if !multiplayer.is_server():
		return
	var id = multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()
	if finish_order.has(id) or !PlayersManager.joined_players.has(id):
		return

	finish_order.append(id)
	_sync_finish_order.rpc(finish_order)
	print("Jugador ", id, " llegó a la meta en posición ", finish_order.size())
	_check_everyone_finished()

# Also runs when someone leaves, so the race doesn't wait for them
func _check_everyone_finished() -> void:
	if not multiplayer.is_server() or _changing_level or not is_instance_valid(current_level):
		return
	var players = PlayersManager.joined_players.keys()
	if players.is_empty() or not players.all(func(id): return finish_order.has(id)):
		return
	_changing_level = true

	# Hand out the points (players who left don't take a position)
	var results = []
	for id in finish_order:
		if not PlayersManager.has_player(id):
			continue
		var gained = POINTS[results.size()] if results.size() < POINTS.size() else 0
		var coins = coins_of(id) if PlayersManager.coins_enabled() else 0
		PlayersManager.add_race_result(id, results.size() + 1, gained + coins)
		results.append({"id": id, "position": results.size() + 1, "gained": gained, "coins": coins})
	for result in results:
		result["name"] = PlayersManager.name_of(result.id)
		result["color"] = PlayersManager.color_of(result.id)
		result["total"] = PlayersManager.points_of(result.id)
		result["finishes"] = PlayersManager.joined_players[result.id]["finishes"].duplicate()
	var final = is_last_round()
	_show_results.rpc(results, final)

	await get_tree().create_timer(FINAL_RESULTS_TIME if final else RESULTS_TIME).timeout
	if final:
		PlayersManager.reset_points()
	PlayersManager.finish_level.emit()

@rpc("authority", "call_local", "reliable")
func _show_results(results: Array, final: bool) -> void:
	results_shown.emit(results, final)

@rpc("authority", "call_local", "reliable")
func _sync_finish_order(order: Array) -> void:
	finish_order = order
	finish_order_changed.emit()

func _find_in_level(group: String) -> Node2D:
	if !is_instance_valid(current_level):
		return null
	for node in get_tree().get_nodes_in_group(group):
		if current_level.is_ancestor_of(node):
			return node
	return null
