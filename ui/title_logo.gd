@tool
class_name TitleLogo extends Control

## Big cartoon title: one chunky letter per color, bouncing in a wave

const COLORS = [Color("#ff5e5b"), Color("#ff9f1c"), Color("#ffd23f"), Color("#3bceac"),
	Color("#41a6f6"), Color("#a86cf5"), Color("#ff6fb5")]
const OUTLINE = Color(0.17, 0.11, 0.23)

@export var text := "CARRERA":
	set(value):
		text = value
		_build()
@export var font: Font:
	set(value):
		font = value
		_build()
@export var font_size := 54:
	set(value):
		font_size = value
		_build()
@export var bounce_height := 4.0

var _letters: Array[Label] = []
var _time := 0.0

func _ready() -> void:
	_build()
	resized.connect(_layout)

func _build() -> void:
	if not is_inside_tree():
		return
	for letter in _letters:
		letter.queue_free()
	_letters.clear()
	for i in text.length():
		var letter = Label.new()
		letter.text = text[i]
		if font:
			letter.add_theme_font_override("font", font)
		letter.add_theme_font_size_override("font_size", font_size)
		letter.add_theme_color_override("font_color", COLORS[i % COLORS.size()])
		letter.add_theme_color_override("font_outline_color", OUTLINE)
		letter.add_theme_constant_override("outline_size", maxi(4, font_size / 6))
		letter.add_theme_color_override("font_shadow_color", OUTLINE)
		letter.add_theme_constant_override("shadow_offset_x", 0)
		letter.add_theme_constant_override("shadow_offset_y", maxi(2, font_size / 12))
		letter.add_theme_constant_override("shadow_outline_size", maxi(4, font_size / 6))
		add_child(letter, false, Node.INTERNAL_MODE_FRONT)
		_letters.append(letter)
	_layout()

func _layout() -> void:
	var total = 0.0
	for letter in _letters:
		letter.reset_size()
		total += letter.size.x - font_size * 0.04
	var x = (size.x - total) / 2.0
	for letter in _letters:
		letter.position.x = x
		letter.pivot_offset = letter.size / 2.0
		x += letter.size.x - font_size * 0.04

func _process(delta: float) -> void:
	_time += delta
	for i in _letters.size():
		var wave = _time * 3.0 - i * 0.55
		_letters[i].position.y = (size.y - _letters[i].size.y) / 2.0 - absf(sin(wave)) * bounce_height
		_letters[i].rotation = sin(wave * 0.5) * 0.06
