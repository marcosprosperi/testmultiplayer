class_name Countdown extends Control

## F1-style start lights: one red light per second, then all green and "¡ARRANCA!"

const LIGHT_RADIUS = 9.0
const LIGHT_GAP = 26.0
const GO_DURATION = 1.2
const RED = Color("#ff3b30")
const GREEN = Color("#34c759")
const OFF = Color(0.15, 0.15, 0.17)

@onready var big_label: Label = $BigLabel

var _go_time_left := 0.0

func _ready() -> void:
	RaceManager.state_changed.connect(_on_state_changed)
	_on_state_changed()

func _process(delta: float) -> void:
	if _go_time_left > 0.0:
		_go_time_left -= delta
		modulate.a = clampf(_go_time_left / 0.4, 0.0, 1.0)
		if _go_time_left <= 0.0:
			visible = false

func _on_state_changed() -> void:
	modulate.a = 1.0
	match RaceManager.state:
		RaceManager.State.WAITING:
			visible = true
			big_label.text = "Esperando a los jugadores..."
			big_label.add_theme_font_size_override("font_size", 12)
			big_label.add_theme_color_override("font_color", Color.WHITE)
		RaceManager.State.COUNTDOWN:
			visible = true
			big_label.text = str(RaceManager.countdown_value)
			big_label.add_theme_font_size_override("font_size", 32)
			big_label.add_theme_color_override("font_color", RED)
		RaceManager.State.RACING:
			# Only celebrate the start if we saw the countdown (not late joiners)
			if visible:
				big_label.text = "¡ARRANCA!"
				big_label.add_theme_font_size_override("font_size", 32)
				big_label.add_theme_color_override("font_color", GREEN)
				_go_time_left = GO_DURATION
	queue_redraw()

func _draw() -> void:
	var count = RaceManager.COUNTDOWN_FROM
	var center = Vector2(size.x / 2.0, 14.0)
	var width = (count - 1) * LIGHT_GAP
	# Gantry behind the lights
	draw_rect(Rect2(center.x - width / 2.0 - 16, center.y - 13, width + 32, 26), Color(0.05, 0.05, 0.06, 0.9))
	for i in count:
		var color = OFF
		match RaceManager.state:
			RaceManager.State.COUNTDOWN:
				if i < count - RaceManager.countdown_value + 1:
					color = RED
			RaceManager.State.RACING:
				color = GREEN
		var pos = Vector2(center.x - width / 2.0 + i * LIGHT_GAP, center.y)
		draw_circle(pos, LIGHT_RADIUS + 1.5, Color.BLACK)
		draw_circle(pos, LIGHT_RADIUS, color)
