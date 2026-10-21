class_name Fx extends Node2D

## Little one-shot effects drawn in pixel style: dust when jumping and
## landing, a poof when someone loses, sparkles, "+1"... Call Fx.spawn().

const POOF = "poof"        # losing: big white puff with stars
const DUST = "dust"        # jumping / landing
const STOMP = "stomp"      # squashing an enemy
const SPARKLE = "sparkle"  # coins, flags, coming back
const PLUS_ONE = "plus_one"

var _particles: Array = []
var _text := ""
var _text_color := Color.WHITE
var _life := 0.0
var _duration := 0.5

## Adds the effect to the level (or the current scene) at a world position
static func spawn(kind: String, at: Vector2, color := Color.WHITE) -> void:
	var parent = RaceManager.current_level if is_instance_valid(RaceManager.current_level) \
		else Engine.get_main_loop().current_scene
	if parent == null:
		return
	var fx = Fx.new()
	fx.z_index = 20
	fx._setup(kind, color)
	parent.add_child(fx)
	fx.global_position = at

func _setup(kind: String, color: Color) -> void:
	match kind:
		POOF:
			_duration = 0.55
			for i in 14:
				var a = i * TAU / 14.0 + randf() * 0.3
				_add(Vector2(cos(a), sin(a) * 0.7) * randf_range(50, 100), randf_range(4, 7), Color(1, 1, 1, 0.95), "puff")
			for i in 4:
				var a = randf() * TAU
				_add(Vector2(cos(a), sin(a)) * randf_range(60, 90), 4, color, "star")
		DUST:
			_duration = 0.35
			for i in 6:
				var side = -1.0 if i % 2 == 0 else 1.0
				_add(Vector2(side * randf_range(20, 50), randf_range(-15, -5)), randf_range(1.5, 3), Color(0.92, 0.88, 0.8, 0.85), "puff")
		STOMP:
			_duration = 0.4
			for i in 8:
				var a = PI + i * PI / 7.0
				_add(Vector2(cos(a), sin(a)) * randf_range(40, 70), randf_range(2, 3.5), Color(1, 1, 1, 0.9), "puff")
		SPARKLE:
			_duration = 0.45
			for i in 6:
				var a = i * TAU / 6.0
				_add(Vector2(cos(a), sin(a)) * randf_range(35, 55), 3.5, color, "star")
		PLUS_ONE:
			_duration = 0.7
			_text = "+1"
			_text_color = color

func _add(velocity: Vector2, size: float, color: Color, shape: String) -> void:
	_particles.append({"pos": Vector2.ZERO, "vel": velocity, "size": size, "color": color, "shape": shape})

func _process(delta: float) -> void:
	_life += delta
	if _life >= _duration:
		queue_free()
		return
	for p in _particles:
		p.pos += p.vel * delta
		p.vel *= 0.9
		p.vel.y += 30.0 * delta if p.shape == "puff" else 60.0 * delta
	queue_redraw()

func _draw() -> void:
	var t = _life / _duration
	for p in _particles:
		var c = Color(p.color, p.color.a * (1.0 - t))
		var size = p.size * (1.0 - t * 0.5)
		if p.shape == "star":
			# Four-pointed twinkle with a white heart
			var r = size * 1.6
			var w = size * 0.45
			var at = p.pos.round()
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(w, 0), at + Vector2(0, r),
				at + Vector2(-w, 0)]), c)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-r, 0), at + Vector2(0, -w), at + Vector2(r, 0),
				at + Vector2(0, w)]), c)
			draw_circle(at, w, Color(1, 1, 1, c.a))
		else:
			draw_circle(p.pos.round(), size, c)
	if _text != "":
		var font = ThemeDB.get_project_theme().default_font
		var at = Vector2(-6, -12 - t * 14)
		draw_string_outline(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.17, 0.11, 0.23, 1.0 - t))
		draw_string(font, at, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(_text_color, 1.0 - t))
