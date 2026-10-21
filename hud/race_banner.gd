class_name RaceBanner extends Control

## Big moments on screen: a card with the race number and the level's name
## before the start, and your place in huge letters when you cross the line

const OUTLINE = Color(0.17, 0.11, 0.23)
const TITLE_FONT = preload("res://ui/fonts/LilitaOne-Regular.ttf")
const PODIUM = [Color("#ffd23f"), Color("#dfe6ee"), Color("#e0975a")]
const DIFFICULTY = ["", "Fácil", "Medio", "Difícil"]
const DIFFICULTY_COLOR = [Color.WHITE, Color("#55efc4"), Color("#fdcb6e"), Color("#ff7675")]

# Intro card: how far it has slid in (0 = off screen, 1 = in place)
var _card := 0.0
var _card_target := 0.0
# Finish: seconds left showing your place, and which place
var _place_left := 0.0
var _place := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	RaceManager.state_changed.connect(_on_state_changed)
	RaceManager.round_changed.connect(_on_state_changed)
	RaceManager.player_finished.connect(_on_player_finished)

func _on_state_changed() -> void:
	match RaceManager.state:
		RaceManager.State.WAITING, RaceManager.State.COUNTDOWN:
			_card_target = 1.0 if RaceManager.level_title != "" else 0.0
		RaceManager.State.RACING:
			# Stays a moment after the start, then slides away
			get_tree().create_timer(1.0).timeout.connect(func(): _card_target = 0.0)

func _on_player_finished(id: int, place: int) -> void:
	if id == multiplayer.get_unique_id():
		_place = place
		_place_left = 2.2

func _process(delta: float) -> void:
	_card = move_toward(_card, _card_target, delta * 4.0)
	_place_left = maxf(_place_left - delta, 0.0)
	visible = _card > 0.0 or _place_left > 0.0
	queue_redraw()

func _draw() -> void:
	if _card > 0.0:
		_draw_card()
	if _place_left > 0.0:
		_draw_place()

func _draw_card() -> void:
	var font = get_theme_default_font()
	var race = "CARRERA %d DE %d" % [RaceManager.round_index + 1, RaceManager.rounds_total]
	var title = RaceManager.level_title.to_upper()
	var difficulty = DIFFICULTY[clampi(RaceManager.level_difficulty, 0, 3)]
	var width = maxf(TITLE_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x, 120) + 40
	# Slides in from the left with a little overshoot
	var t = ease(_card, -2.2)
	var center = Vector2(lerpf(-width, size.x / 2.0, t), size.y * 0.62)
	var rect = Rect2(center - Vector2(width / 2.0, 30), Vector2(width, 60))
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.17, 0.37, 0.95)
	style.border_color = OUTLINE
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	draw_style_box(style, rect)
	_text(font, race, Vector2(rect.position.x, rect.position.y + 14), rect.size.x, 9, Color(1, 1, 1, 0.75))
	_text(TITLE_FONT, title, Vector2(rect.position.x, rect.position.y + 41), rect.size.x, 26, Color("#ffd23f"))
	if difficulty != "":
		_text(font, difficulty, Vector2(rect.position.x, rect.position.y + 54), rect.size.x, 9,
			DIFFICULTY_COLOR[RaceManager.level_difficulty])

func _draw_place() -> void:
	var age = 2.2 - _place_left
	# Pops in big, settles, and fades at the end
	var scale_now = 1.0 + maxf(0.0, 0.5 - age) * 1.2
	var alpha = clampf(_place_left / 0.4, 0.0, 1.0)
	var color = PODIUM[_place - 1] if _place <= 3 else Color.WHITE
	var center = Vector2(size.x / 2.0, size.y * 0.42)
	draw_set_transform(center, 0.0, Vector2.ONE * scale_now)
	_text(TITLE_FONT, "¡%dº!" % _place, Vector2(-200, 0), 400, 48, Color(color, alpha), alpha)
	var line = "¡Ganaste la carrera!" if _place == 1 else "Llegaste en el puesto %d" % _place
	_text(get_theme_default_font(), line, Vector2(-200, 22), 400, 11, Color(1, 1, 1, alpha), alpha)
	draw_set_transform(Vector2.ZERO)

func _text(font: Font, text: String, at: Vector2, width: float, font_size: int, color: Color, alpha := 1.0) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, maxi(4, font_size / 5),
		Color(OUTLINE, alpha))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
