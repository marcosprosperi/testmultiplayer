class_name InkSplats extends Control

## The Tinta power-up: blots of ink over your screen while someone's ink is
## on you. They drip a little and fade at the end

const INK = Color(0.1, 0.07, 0.16)
const FADE_TIME = 0.8

var _blots: Array = []
var _was_on := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	var on = _time_left() > 0.0
	if on and not _was_on:
		_splat()
	_was_on = on
	visible = on
	queue_redraw()

func _time_left() -> float:
	var until = RaceManager.effects.get(multiplayer.get_unique_id(), {}).get("ink", -1.0)
	return until - RaceManager.race_time()

# Big blots around the middle of the screen, each with smaller ones around it
func _splat() -> void:
	_blots.clear()
	for i in 6:
		var center = Vector2(randf_range(0.15, 0.85) * size.x, randf_range(0.2, 0.75) * size.y)
		var radius = randf_range(22.0, 38.0)
		_blots.append([center, radius])
		for k in randi_range(4, 7):
			var a = randf() * TAU
			_blots.append([center + Vector2(cos(a), sin(a)) * radius * randf_range(0.8, 1.4), radius * randf_range(0.15, 0.4)])

func _draw() -> void:
	var left = _time_left()
	var alpha = clampf(left / FADE_TIME, 0.0, 1.0) * 0.93
	var drip = (PowerUps.INK_TIME - left) * 4.0
	for blot in _blots:
		draw_circle(blot[0] + Vector2(0, drip), blot[1], Color(INK, alpha))
