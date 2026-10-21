class_name BotBrain extends RefCounted

## Drives a bot player (on the server): follows the level's Course, jumps over
## gaps, hazards and enemies, climbs, waits for crushers and elevators, and
## hops balloons. skill (0..1) makes it hesitate and jump late now and then,
## so bots can be beaten.

const STUCK_RESTART_MSEC = 15000

var player: Player
var skill := 0.9

var _level: Node
var _course: Path2D
var _cache = {}
var _target_x := INF
var _target_y := INF
var _target_body = null
var _last_dir := 1.0
var _best_progress := 0.0
var _last_pos := Vector2.ZERO
var _last_progress_msec := 0
var _hesitate_left := 0.0
var _late_jump_left := 0.0
# Jumping past a saw is timed to the frame: no late jumps then
var _careful_jump := false
var _pace := 1.0

func _init(bot_player: Player, bot_skill: float) -> void:
	player = bot_player
	skill = bot_skill
	_pace = remap(clampf(skill, 0.75, 0.95), 0.75, 0.95, 0.78, 0.95)

## Returns {"dir": -1..1, "jump": bool} for this physics frame
func update(delta: float) -> Dictionary:
	var level = RaceManager.current_level
	if not is_instance_valid(level):
		return {"dir": 0.0, "jump": false}
	if level != _level:
		_enter_level(level)
	if _course == null:
		return {"dir": 1.0, "jump": player.is_on_wall()}

	var pos = player.global_position
	var progress = RaceManager.get_progress(player)
	# A big jump in position means we died and started over (or from a checkpoint)
	var respawned = pos.distance_to(_last_pos) > 100
	_last_pos = pos
	if progress > _best_progress + 0.002 or respawned:
		_best_progress = progress
		_last_progress_msec = Time.get_ticks_msec()

	# Being a bit human: now and then hesitate for a moment
	if _hesitate_left > 0.0:
		_hesitate_left -= delta
		return {"dir": 0.0, "jump": false}
	if player.is_on_floor() and randf() < (1.0 - skill) * delta:
		_hesitate_left = randf_range(0.2, 0.6)

	# Hopelessly stuck somewhere: start over like a person would
	if Time.get_ticks_msec() - _last_progress_msec > STUCK_RESTART_MSEC:
		_last_progress_msec = Time.get_ticks_msec()
		player.die()
		return {"dir": 0.0, "jump": false}
	_careful_jump = false

	var target = _course_target(64.0)
	var dx = target.x - pos.x
	var dy = target.y - pos.y
	var dir = signf(dx) if absf(dx) > 6 else 0.0
	if dir == 0.0 and dy > 40 and player.is_on_floor():
		dir = _last_dir
	if dir != 0.0:
		_last_dir = dir
	var move = dir
	var jump = false

	if player.is_on_floor():
		_target_x = INF; _target_y = INF; _target_body = null
		var look = dir if dir != 0 else 1.0
		var stuck = Time.get_ticks_msec() - _last_progress_msec > 4000
		var riding = player.get_slide_collision_count() > 0 and player.get_last_slide_collision().get_collider() is AnimatableBody2D
		if _crusher_blocking(look):
			move = 0
		elif riding and dy < -16 and absf(dx) < 80:
			move = 0  # on an elevator going up: wait
		elif dir != 0 and not _floor_ahead(dir) and dy >= -16:
			if dy <= 40:
				var land = _landing(dir)
				if not land.is_empty() and _saw_in_gap_blocking(dir, land.x):
					move = 0
				elif not land.is_empty():
					jump = true; _target_x = land.x
					_target_body = land.body if land.body is AnimatableBody2D else null
				else:
					move = 0
		elif dy < -16:
			var balloon = _balloon_above()
			var ledge = _ledge_above(look) if balloon == null else {}
			if balloon == null and ledge.is_empty():
				ledge = _ledge_above(-look)
			if balloon == null and not _clear_above(pos.x):
				move = _step_out_dir()
			elif balloon:
				jump = true; _target_body = balloon
			elif not ledge.is_empty():
				jump = true; _target_x = ledge.x; _target_y = ledge.y
				_target_body = ledge.body if ledge.body is AnimatableBody2D else null
			elif dir != 0 and not _floor_ahead(dir):
				var land = _landing(dir)
				if not land.is_empty():
					jump = true; _target_x = land.x
					_target_body = land.body if land.body is AnimatableBody2D else null
				else:
					move = 0
			elif stuck:
				jump = true
		elif (dir != 0 and player.is_on_wall()) or _hazard_ahead(look) or stuck:
			jump = true
	else:
		if is_instance_valid(_target_body):
			var middle = _target_body.global_position.x + (_target_body.tiles * 8 if "tiles" in _target_body else 0)
			move = signf(middle - pos.x) if absf(middle - pos.x) > 4 else 0.0
		elif _target_x != INF:
			move = signf(_target_x - pos.x) if absf(_target_x - pos.x) > 4 else 0.0
			if _target_y != INF and pos.y > _target_y - 2 and player.velocity.y < 0 and not _clear_above(pos.x + move * 10, 30.0):
				move = 0.0

	# Being a bit human: sometimes jump a moment late
	if jump and not _careful_jump and randf() < (1.0 - skill) * 0.5 and _late_jump_left <= 0.0:
		_late_jump_left = randf_range(0.04, 0.1)
	if _late_jump_left > 0.0:
		_late_jump_left -= delta
		if _late_jump_left <= 0.0:
			jump = true
		else:
			jump = false

	# Slower bots run a bit slower (full speed in the air so jumps still reach)
	if player.is_on_floor():
		move *= _pace
	return {"dir": move, "jump": jump}

func _enter_level(level: Node) -> void:
	_level = level
	_course = level.get_node_or_null("Course") as Path2D
	_cache.clear()
	_best_progress = 0.0
	_last_progress_msec = Time.get_ticks_msec()
	for kind in ["Spikes", "RetractableSpikes", "TrapButton", "Saw", "Crusher", "Balloon"]:
		_cache[kind] = level.find_children("*", kind, true, false)

# --- Sensing -----------------------------------------------------------------

func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var query = PhysicsRayQueryParameters2D.create(from, to, 512)
	return player.get_world_2d().direct_space_state.intersect_ray(query)

func _course_target(ahead: float) -> Vector2:
	var curve = _course.curve
	var offset = curve.get_closest_offset(_course.to_local(player.global_position))
	return _course.to_global(curve.sample_baked(minf(offset + ahead, curve.get_baked_length())))

func _floor_ahead(dir: float, dist := 12.0) -> bool:
	return not _ray(player.global_position + Vector2(dir * dist, -4), player.global_position + Vector2(dir * dist, 40)).is_empty()

# Somewhere to land going forward at about the same height or lower
func _landing(dir: float, max_dist := 190) -> Dictionary:
	for d in range(30, max_dist, 6):
		var hit = _ray(player.global_position + Vector2(dir * d, -60), player.global_position + Vector2(dir * d, 140))
		if hit.is_empty():
			continue
		# Never jump onto an elevator going up or down: wait until it's level
		if hit.collider is MovingPlatform and hit.collider.travel.y != 0:
			return {}
		return {"x": hit.position.x + dir * 14, "body": hit.collider}
	return {}

func _clear_above(x: float, height := 70.0) -> bool:
	for off in [-7.0, 0.0, 7.0]:
		if not _ray(Vector2(x + off, player.global_position.y - 16), Vector2(x + off, player.global_position.y - height)).is_empty():
			return false
	return true

func _step_out_dir() -> float:
	for d in range(8, 120, 8):
		if _clear_above(player.global_position.x + d): return 1.0
		if _clear_above(player.global_position.x - d): return -1.0
	return 0.0

# A surface 16..76 px above us within reach
func _ledge_above(dir: float) -> Dictionary:
	for d in range(0, 130, 6):
		var x = player.global_position.x + dir * d
		var hit = _ray(Vector2(x, player.global_position.y - 78), Vector2(x, player.global_position.y - 16))
		if hit.is_empty() or hit.normal.y > -0.5:
			continue
		if hit.collider is MovingPlatform and hit.collider.travel.y != 0:
			continue
		if _ray(Vector2(x, hit.position.y - 2), Vector2(x, hit.position.y - 14)).is_empty():
			return {"x": x + dir * 10, "y": hit.position.y, "body": hit.collider}
	return {}

func _balloon_above() -> Node:
	var best = null
	for b in _cache.get("Balloon", []):
		if not is_instance_valid(b) or b.modulate.a < 0.6: continue
		var dy = player.global_position.y - b.global_position.y
		var dx = absf(b.global_position.x - player.global_position.x)
		if dy > 5 and dy < 45 and dx < 100 and (best == null or b.global_position.y < best.global_position.y):
			best = b
	return best

func _hazard_ahead(dir: float) -> bool:
	var pos = player.global_position
	for s in _cache.get("Spikes", []) + _cache.get("RetractableSpikes", []) + _cache.get("TrapButton", []):
		var d = (s.global_position.x - pos.x) * dir
		if d > -4 and d < 30 and absf(s.global_position.y - pos.y) < 20: return true
	for h in _cache.get("Saw", []):
		var d = (h.global_position.x - pos.x) * dir
		if d > 0 and d < 60 and absf(h.global_position.y - pos.y) < 40: return true
	for b in player.get_tree().get_nodes_in_group("ball"):
		var d = (b.global_position.x - pos.x) * dir
		if d > 0 and d < 110 and absf(b.global_position.y - pos.y) < 40: return true
	for e in player.get_tree().get_nodes_in_group("enemy"):
		if not e.is_alive(): continue
		if e is Bat and pos.y - e.global_position.y > 30: continue
		var d = (e.global_position.x - pos.x) * dir
		if d > 0 and d < (60 if not e.stompable else 44) and absf(e.global_position.y - pos.y) < 36: return true
	return false

# A saw going up and down in the gap ahead: follow the jump through time and
# only go if the saw won't be where we'll be
func _saw_in_gap_blocking(dir: float, landing_x: float) -> bool:
	var pos = player.global_position
	var saws = _cache.get("Saw", []).filter(func(h): return h.travel.y != 0 \
		and (h.global_position.x - pos.x) * dir > -20 and (landing_x - h.global_position.x) * dir > -20)
	if saws.is_empty():
		return false
	_careful_jump = true
	var speed = Player.SPEED * RaceManager.speed_factor(player.name.to_int())
	var gravity = player.get_gravity().y
	var t := 0.0
	while t < 1.0:
		var x = pos.x + dir * speed * t
		if (x - landing_x) * dir > 0:
			break
		var y = pos.y + Player.JUMP_VELOCITY * t + 0.5 * gravity * t * t
		for h in saws:
			var at = h.global_position_in(t)
			for body_y in [y - 3.0, y - 12.0]:
				if Vector2(x, body_y).distance_to(at) < h.radius + 8.0:
					return true
		t += 1.0 / 60.0
	return false

func _crusher_blocking(dir: float) -> bool:
	for c in _cache.get("Crusher", []):
		var d = (c.global_position.x - player.global_position.x) * dir
		# Already under it: keep going. Not there yet: wait if it's not resting
		if d > 20 and d < 56 and absf(c.global_position.y - player.global_position.y) < 40:
			var resting = c.phase == Trap.Phase.IDLE and c.block.position.y <= -c.height - c.SIZE.y / 2.0 + 1
			if not resting: return true
	return false
