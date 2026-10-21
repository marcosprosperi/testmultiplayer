extends CanvasLayer

## Iris wipe between screens: the circle closes, the screen changes behind
## it, and it opens again on the new one

const TIME = 0.35
const OPEN = 1.2

var _rect: ColorRect
var _tween: Tween

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = ShaderMaterial.new()
	_rect.material.shader = preload("res://ui/iris.gdshader")
	add_child(_rect)
	_set_radius(OPEN)

func _process(_delta: float) -> void:
	var size = get_viewport().get_visible_rect().size
	_rect.material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_rect.visible = _radius() < OPEN

## Closes the circle, changes to the scene, and opens it again
func change_scene(path: String) -> void:
	await cover()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	reveal()

func cover() -> void:
	await _animate(OPEN, 0.0)

func reveal() -> void:
	await _animate(0.0, OPEN)

## Something changed under the player's feet (a new level, back to the
## lobby): start closed and open up
func pop_in() -> void:
	_set_radius(0.0)
	reveal()

func _animate(from: float, to: float) -> void:
	if _tween:
		_tween.kill()
	_set_radius(from)
	_tween = create_tween()
	_tween.tween_method(_set_radius, from, to, TIME).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN if to < from else Tween.EASE_OUT)
	await _tween.finished

func _set_radius(value: float) -> void:
	_rect.material.set_shader_parameter("radius", value)

func _radius() -> float:
	return _rect.material.get_shader_parameter("radius")
