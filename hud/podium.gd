class_name Podium extends Control

## End of the championship: the top three on pedestals (the champion
## jumping for joy), everyone else underneath, and confetti

const OUTLINE = Color(0.17, 0.11, 0.23)
const TITLE_FONT = preload("res://ui/fonts/LilitaOne-Regular.ttf")
const PEDESTAL_COLORS = [Color("#ffd23f"), Color("#dfe6ee"), Color("#e0975a")]
## Pedestal heights for 1st, 2nd and 3rd, and where each one stands (x offset)
const HEIGHTS = [68.0, 52.0, 42.0]
const SPOTS = [0.0, -84.0, 84.0]
const WIDTH = 74.0

## Set by Standings every frame
var footer_text := ""

var _results: Array = []
var _knights: Array[AnimatedSprite2D] = []
var _time := 0.0
var _confetti_in := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## results: sorted by championship standing, each {name, color, total}
func show_results(results: Array) -> void:
	_results = results
	_time = 0.0
	for knight in _knights:
		knight.queue_free()
	_knights.clear()
	for i in mini(3, results.size()):
		var knight = PlayerLook.knight(results[i].color, "idle")
		knight.scale = Vector2(2, 2)
		add_child(knight)
		_knights.append(knight)
	visible = true

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var base = _base()
	for i in _knights.size():
		var top = base.y - HEIGHTS[i]
		var jump = absf(sin(_time * 5.0)) * 14.0 if i == 0 else 0.0
		_knights[i].position = Vector2(base.x + SPOTS[i], top - 22 - jump)
		_knights[i].play("jump" if i == 0 and jump > 2.0 else "idle")
	_confetti_in -= delta
	if _confetti_in <= 0.0:
		_confetti_in = 0.45
		Fx.spawn(Fx.CONFETTI, Vector2(randf_range(size.x * 0.2, size.x * 0.8), size.y * 0.55), Color.WHITE, self)
	queue_redraw()

func _base() -> Vector2:
	return Vector2(size.x / 2.0, size.y - 52)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.04, 0.12, 0.88))
	if _results.is_empty():
		return
	var font = get_theme_default_font()
	var champion = _results[0]
	var title_scale = 1.0 + maxf(0.0, 0.4 - _time) * 1.5
	draw_set_transform(Vector2(size.x / 2.0, 34), 0.0, Vector2.ONE * title_scale)
	_text(TITLE_FONT, "¡%s gana el campeonato!" % champion.name, Vector2(-240, 0), 480, 22, champion.color)
	draw_set_transform(Vector2.ZERO)
	_text(font, "Campeonato terminado", Vector2(0, 50), size.x, 9, Color(1, 1, 1, 0.75))
	var base = _base()
	for i in mini(3, _results.size()):
		var height = HEIGHTS[i]
		# The pedestals rise up one after the other
		var grow = clampf((_time - (2 - i) * 0.25) / 0.4, 0.0, 1.0)
		var rect = Rect2(base.x + SPOTS[i] - WIDTH / 2.0, base.y - height * grow, WIDTH, height * grow)
		var style = StyleBoxFlat.new()
		style.bg_color = PEDESTAL_COLORS[i]
		style.border_color = OUTLINE
		style.set_border_width_all(3)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		draw_style_box(style, rect)
		if grow < 1.0:
			continue
		_text(TITLE_FONT, "%dº" % (i + 1), Vector2(rect.position.x, rect.position.y + 24), WIDTH, 20, Color.WHITE)
		_text(font, "%d pts" % _results[i].total, Vector2(rect.position.x, rect.position.y + 38), WIDTH, 9, Color.WHITE)
		_text(font, _results[i].name, Vector2(rect.position.x - 20, rect.position.y - 52), WIDTH + 40, 9,
			_results[i].color.lightened(0.2))
	# Everyone else, in a line underneath
	var rest = []
	for i in range(3, _results.size()):
		rest.append("%dº %s (%d)" % [i + 1, _results[i].name, _results[i].total])
	if not rest.is_empty():
		_text(font, "   ·   ".join(rest), Vector2(0, base.y + 16), size.x, 8, Color(1, 1, 1, 0.8))
	_text(font, footer_text, Vector2(0, size.y - 10), size.x, 9, Color(1, 1, 1, 0.7))

func _text(font: Font, text: String, at: Vector2, width: float, font_size: int, color: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, maxi(3, font_size / 5), OUTLINE)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
