@tool
class_name CartoonButton extends Button

## Big round button with a thick outline in its own color that grows a bit
## when you point at it and squishes when you press it

const OUTLINE = Color(0.17, 0.11, 0.23)

@export var color := Color("#ffd23f"):
	set(value):
		color = value
		_make_styles()

var _tween: Tween

func _ready() -> void:
	_make_styles()
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	if Engine.is_editor_hint():
		return
	mouse_entered.connect(func(): _scale_to(1.07 if not disabled else 1.0))
	mouse_exited.connect(func(): _scale_to(1.0))
	button_down.connect(func(): _scale_to(0.95))
	button_up.connect(func(): _scale_to(1.07 if is_hovered() else 1.0))

func _scale_to(value: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * value, 0.15)

func _make_styles() -> void:
	var light = color.lightened(0.2)
	var dark = color.darkened(0.15)
	add_theme_stylebox_override("normal", _style(color, 2, 5))
	add_theme_stylebox_override("hover", _style(light, 2, 5))
	add_theme_stylebox_override("pressed", _style(dark, 5, 2))
	add_theme_stylebox_override("disabled", _style(color.lerp(Color(0.55, 0.5, 0.6), 0.7), 2, 5))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# Dark text on light colors, white with an outline on dark ones
	var text = OUTLINE if color.get_luminance() > 0.55 else Color.WHITE
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		add_theme_color_override(state, text)
	add_theme_color_override("font_outline_color", OUTLINE)
	add_theme_constant_override("outline_size", 0 if text == OUTLINE else 4)

# top/bottom: a thicker bottom edge looks like a 3D key; pressed swaps them
func _style(bg: Color, top: int, bottom: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = OUTLINE
	style.set_border_width_all(2)
	style.border_width_top = top
	style.border_width_bottom = bottom
	style.set_corner_radius_all(9)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 3 + top
	style.content_margin_bottom = 2 + bottom
	return style
