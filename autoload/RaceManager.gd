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
## Once every person crossed the line, bots get this long to finish too
const BOT_GRACE_TIME = 25.0
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
# Power-ups: who holds what changed / someone used one (on every screen)
signal items_changed
# Someone crossed the finish line (place: 1 = first), on every screen
signal player_finished(id: int, place: int)
signal item_used(id: int, item: String)

var state := State.WAITING
# Power-up each player is holding (id -> PowerUps name), synced by the server
var items = {}
# Effects on each player: id -> {effect: race time it ends}. Effects are
# "turbo", "star", "slow" (lightning) and "shield" (until it saves you)
var effects = {}
var _peels := 0
# Coins picked up by each player in this race (synced by the server)
var race_coins = {}
# Which race of the championship this is (0-based) and how many there are
var round_index := 0
# Name and difficulty (1-3) of the level being raced
var level_title := ""
var level_difficulty := 0
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
# Who we already celebrated crossing the line this race (see player_finished)
var _announced_finishes: Array = []
var _changing_level := false

func _ready() -> void:
	PlayersManager.players_changed.connect(_check_everyone_finished)
	PlayersManager.players_changed.connect(_check_everyone_ready)

func register_level(level: Node2D) -> void:
	current_level = level
	Transition.pop_in()
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
		_sync_items.rpc({})
		_sync_effects.rpc({})
		_sync_state.rpc(State.WAITING, 0)
		_start_anyway_after_timeout(_race_token)

## Server only: the championship ended, clear the race state everywhere
func end_championship() -> void:
	if multiplayer.is_server():
		_end_championship.rpc()

@rpc("authority", "call_local", "reliable")
func _end_championship() -> void:
	reset()
	Transition.pop_in()

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
	_announced_finishes = []
	items = {}
	effects = {}
	finish_order_changed.emit()
	state_changed.emit()
	grid_changed.emit()

func send_state_to(id: int) -> void:
	_sync_finish_order.rpc_id(id, finish_order)
	_sync_state.rpc_id(id, state, countdown_value, race_time())
	_sync_grid.rpc_id(id, grid_order)
	_sync_round.rpc_id(id, round_index, rounds_total, level_title, level_difficulty)
	_sync_coins.rpc_id(id, race_coins)
	_sync_items.rpc_id(id, items)
	_sync_effects.rpc_id(id, effects)

func coins_of(id: int) -> int:
	return race_coins.get(id, 0)

## 1.0 = normal speed; each coin carried this race makes you slower, and
## power-ups make you faster (turbo, star) or slower (someone's lightning)
func speed_factor(id: int) -> float:
	var factor = 1.0
	if PlayersManager.coins_enabled():
		factor -= minf(coins_of(id) * COIN_SLOWDOWN, MAX_SLOWDOWN)
	if has_effect(id, "turbo"):
		factor *= PowerUps.TURBO_SPEED
	if has_effect(id, "star"):
		factor *= PowerUps.STAR_SPEED
	if has_effect(id, "slow"):
		factor *= PowerUps.LIGHTNING_SPEED
	return factor

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
func set_round(index: int, total: int, title := "", difficulty := 0) -> void:
	if multiplayer.is_server():
		_sync_round.rpc(index, total, title, difficulty)

func is_last_round() -> bool:
	return round_index >= rounds_total - 1

@rpc("authority", "call_local", "reliable")
func _sync_round(index: int, total: int, title := "", difficulty := 0) -> void:
	round_index = index
	rounds_total = total
	level_title = title
	level_difficulty = difficulty
	round_changed.emit()

## Players can only move once the countdown is over
func can_move() -> bool:
	return state == State.RACING

## Called by the level and the local player: once both exist, tell the server
func notify_local_ready() -> void:
	if not is_instance_valid(current_level):
		return
	if not get_tree().get_nodes_in_group("player").any(func(p): return p.is_local()):
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
	# Bots are always ready
	var players = PlayersManager.joined_players.keys()
	if not players.is_empty() and players.all(func(id): return id < 0 or _ready_players.has(id)):
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

## 0.0 at the start, 1.0 at the finish line. Measured along the level's
## "Course" (a Path2D following the route, for levels that go up and down),
## or else along the straight line from the spawn to the finish
func get_progress(player: Node2D) -> float:
	var path = current_level.get_node_or_null("Course") as Path2D if is_instance_valid(current_level) else null
	if path and path.curve and path.curve.point_count >= 2:
		var curve = path.curve
		var offset = curve.get_closest_offset(path.to_local(player.global_position))
		return clampf(offset / curve.get_baked_length(), 0.0, 1.0)
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

func get_camera_offset() -> Vector2:
	return current_level.camera_offset if is_instance_valid(current_level) and "camera_offset" in current_level else Vector2.ZERO

func has_finished(id: int) -> bool:
	return finish_order.has(id)

## Server only: a bot crossed the finish line
func report_bot_finish(id: int) -> void:
	if multiplayer.is_server() and id < 0:
		_finish(id)

@rpc("any_peer", "call_local", "reliable")
func report_finish() -> void:
	if !multiplayer.is_server():
		return
	var id = multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()
	_finish(id)

func _finish(id: int) -> void:
	if finish_order.has(id) or !PlayersManager.joined_players.has(id):
		return
	if items.erase(id):
		_sync_items.rpc(items)

	finish_order.append(id)
	_sync_finish_order.rpc(finish_order)
	print("Jugador ", id, " llegó a la meta en posición ", finish_order.size())
	_check_everyone_finished()

# Also runs when someone leaves, so the race doesn't wait for them
func _check_everyone_finished() -> void:
	if not multiplayer.is_server() or _changing_level or not is_instance_valid(current_level):
		return
	var players = PlayersManager.joined_players.keys()
	if players.is_empty():
		return
	if not players.all(func(id): return finish_order.has(id)):
		# Only bots left on the course: give them a little time, then end
		if players.all(func(id): return id < 0 or finish_order.has(id)):
			_wait_for_bots(_race_token)
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
		PlayersManager.championship_over.emit()
	else:
		PlayersManager.finish_level.emit()

var _bots_wait_token := -1

func _wait_for_bots(token: int) -> void:
	if _bots_wait_token == token:
		return
	_bots_wait_token = token
	await get_tree().create_timer(BOT_GRACE_TIME).timeout
	if token != _race_token or _changing_level:
		return
	# Bots still running finish behind, in order of how far they got
	var left = PlayersManager.joined_players.keys().filter(func(id): return not finish_order.has(id))
	var nodes = {}
	for player in get_tree().get_nodes_in_group("player"):
		nodes[player.name.to_int()] = player
	left.sort_custom(func(a, b): return get_progress(nodes[a]) > get_progress(nodes[b]) if nodes.has(a) and nodes.has(b) else a < b)
	for id in left:
		finish_order.append(id)
	_sync_finish_order.rpc(finish_order)
	_check_everyone_finished()

@rpc("authority", "call_local", "reliable")
func _show_results(results: Array, final: bool) -> void:
	results_shown.emit(results, final)

@rpc("authority", "call_local", "reliable")
func _sync_finish_order(order: Array) -> void:
	finish_order = order
	for i in order.size():
		if not _announced_finishes.has(order[i]):
			_announced_finishes.append(order[i])
			player_finished.emit(order[i], i + 1)
	# A new race starts with an empty order
	if order.is_empty():
		_announced_finishes.clear()
	finish_order_changed.emit()

func _find_in_level(group: String) -> Node2D:
	if !is_instance_valid(current_level):
		return null
	for node in get_tree().get_nodes_in_group(group):
		if current_level.is_ancestor_of(node):
			return node
	return null

# --- Power-ups ---------------------------------------------------------------

func item_of(id: int) -> String:
	return items.get(id, "")

func has_effect(id: int, effect: String) -> bool:
	return effects.get(id, {}).get(effect, -1.0) > race_time()

## 0 = leading, 1 = last. Whoever already finished counts as ahead
func place_of(id: int) -> float:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() <= 1:
		return 0.5
	var score = func(player: Node2D) -> float:
		var pid = player.name.to_int()
		return 1000.0 - finish_order.find(pid) if has_finished(pid) else get_progress(player)
	players.sort_custom(func(a, b): return score.call(a) > score.call(b))
	var index = players.find_custom(func(p): return p.name.to_int() == id)
	return float(maxi(index, 0)) / (players.size() - 1)

## Server only: a player touched an item box. Returns whether they got
## something (one at a time: you have to use it before picking another)
func give_item(id: int) -> bool:
	if not multiplayer.is_server() or state != State.RACING or has_finished(id) or items.has(id):
		return false
	items[id] = PowerUps.pick(place_of(id))
	_sync_items.rpc(items)
	return true

## Sent by a player to the server to use what they're holding
@rpc("any_peer", "call_local", "reliable")
func request_use_item() -> void:
	if not multiplayer.is_server():
		return
	var id = multiplayer.get_remote_sender_id()
	use_item(id if id != 0 else multiplayer.get_unique_id())

## Server only (bots call it directly)
func use_item(id: int) -> void:
	var item = item_of(id)
	if not multiplayer.is_server() or item == "" or state != State.RACING or has_finished(id):
		return
	items.erase(id)
	_sync_items.rpc(items)
	var now = race_time()
	var player = _player_node(id)
	match item:
		PowerUps.TURBO:
			_set_effect(id, "turbo", now + PowerUps.TURBO_TIME)
		PowerUps.STAR:
			_set_effect(id, "star", now + PowerUps.STAR_TIME)
		PowerUps.SHIELD:
			_set_effect(id, "shield", now + 100000.0)
		PowerUps.LIGHTNING:
			# Everyone ahead slows down for a while (a star protects you)
			var my_place = place_of(id)
			for other in get_tree().get_nodes_in_group("player"):
				var other_id = other.name.to_int()
				if other_id != id and not has_finished(other_id) and place_of(other_id) < my_place \
						and not has_effect(other_id, "star"):
					_set_effect(other_id, "slow", now + PowerUps.LIGHTNING_TIME)
		PowerUps.PEEL:
			if player:
				var back = -signf(player.animated_sprite_2d.scale.x)
				_peels += 1
				_spawn_peel.rpc("Peel%d" % _peels, player.global_position + Vector2(back * 22, 0), id)
		PowerUps.PORTAL:
			var target = _next_checkpoint(player)
			if target != Vector2.INF:
				_teleport.rpc(id, target)
			else:
				_set_effect(id, "turbo", now + PowerUps.TURBO_TIME)
	_sync_effects.rpc(effects)
	_item_used.rpc(id, item)

func _set_effect(id: int, effect: String, until: float) -> void:
	if not effects.has(id):
		effects[id] = {}
	effects[id][effect] = until

func _player_node(id: int) -> Node2D:
	for player in get_tree().get_nodes_in_group("player"):
		if player.name.to_int() == id:
			return player
	return null

# The first flag further along the course than the player (INF if none)
func _next_checkpoint(player: Node2D) -> Vector2:
	if player == null or not is_instance_valid(current_level):
		return Vector2.INF
	var mine = get_progress(player)
	var best = Vector2.INF
	var best_progress = INF
	for flag in current_level.find_children("*", "Checkpoint", true, false):
		var progress = get_progress(flag)
		if progress > mine + 0.01 and progress < best_progress:
			best_progress = progress
			best = flag.global_position + Vector2(0, -2)
	return best

## A shield saved this player (sent by whoever moves them)
func break_shield(id: int) -> void:
	if effects.has(id):
		effects[id].erase("shield")
	if multiplayer.is_server():
		_sync_effects.rpc(effects)
	else:
		_request_break_shield.rpc_id(1, id)

@rpc("any_peer", "reliable")
func _request_break_shield(id: int) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == id:
		break_shield(id)

## Someone slipped on a peel: it's gone for everyone
func peel_hit(peel_name: String) -> void:
	_request_remove_peel.rpc_id(1, peel_name)

@rpc("any_peer", "call_local", "reliable")
func _request_remove_peel(peel_name: String) -> void:
	if multiplayer.is_server():
		_remove_peel.rpc(peel_name)

@rpc("authority", "call_local", "reliable")
func _remove_peel(peel_name: String) -> void:
	if is_instance_valid(current_level) and current_level.has_node(peel_name):
		current_level.get_node(peel_name).queue_free()

@rpc("authority", "call_local", "reliable")
func _spawn_peel(peel_name: String, at: Vector2, owner_id: int) -> void:
	if not is_instance_valid(current_level):
		return
	var peel = preload("res://race/powerups/peel.tscn").instantiate()
	peel.name = peel_name
	peel.owner_id = owner_id
	current_level.add_child(peel)
	peel.global_position = at

@rpc("authority", "call_local", "reliable")
func _teleport(id: int, at: Vector2) -> void:
	var player = _player_node(id)
	if player and player.is_multiplayer_authority():
		Fx.spawn(Fx.SPARKLE, player.global_position + Vector2(0, -8), PlayersManager.color_of(id))
		player.global_position = at
		player.velocity = Vector2.ZERO
		player.snap_camera()

@rpc("authority", "call_local", "reliable")
func _sync_items(server_items: Dictionary) -> void:
	items = server_items
	items_changed.emit()

@rpc("authority", "call_local", "reliable")
func _sync_effects(server_effects: Dictionary) -> void:
	effects = server_effects

@rpc("authority", "call_local", "reliable")
func _item_used(id: int, item: String) -> void:
	item_used.emit(id, item)
