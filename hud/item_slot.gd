class_name ItemSlot extends Control

## Bottom-right box with the power-up you're holding and the key to use it

const BOX = 30.0
const OUTLINE = Color(0.17, 0.11, 0.23)
## The slot spins through power-ups this long before showing yours
const ROLL_TIME = 0.9

## While spinning you can't use it yet (the player checks this)
static var rolling := false

var _held := ""
var _roll_left := 0.0
var _roll_shown := ""
var _roll_tick := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	size = Vector2(BOX + 4, BOX + 14)
	position = get_parent().get_viewport().get_visible_rect().size - size - Vector2(8, 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	RaceManager.items_changed.connect(queue_redraw)

func _process(delta: float) -> void:
	position = get_viewport_rect().size - size - Vector2(8, 6)
	var item = RaceManager.item_of(multiplayer.get_unique_id())
	if item != _held:
		if _held == "" and item != "":
			_roll_left = ROLL_TIME
		_held = item
	if _roll_left > 0.0:
		_roll_left -= delta
		_roll_tick -= delta
		if _roll_tick <= 0.0:
			# Slows down as it's about to stop
			_roll_tick = lerpf(0.05, 0.16, 1.0 - _roll_left / ROLL_TIME)
			_roll_shown = PowerUps.NAMES.keys().pick_random()
			Sfx.play_ui("ui_hover")
		if _roll_left <= 0.0:
			Sfx.play("item_box")
			_pop()
	rolling = _roll_left > 0.0
	visible = PlayersManager.items_enabled() and not RaceManager.has_finished(multiplayer.get_unique_id())
	queue_redraw()

func _draw() -> void:
	var item = RaceManager.item_of(multiplayer.get_unique_id())
	var rect = Rect2(Vector2(2, 0), Vector2(BOX, BOX))
	var t = Time.get_ticks_msec() / 1000.0
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.17, 0.37, 0.92)
	style.border_color = Color("#ffd23f") if item != "" else OUTLINE
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	draw_style_box(style, rect)
	var font = get_theme_default_font()
	if item == "":
		draw_string(font, rect.position + Vector2(0, BOX / 2.0 + 4), "?", HORIZONTAL_ALIGNMENT_CENTER,
			BOX, 12, Color(1, 1, 1, 0.25))
		return
	if rolling:
		PowerUps.draw_icon(self, _roll_shown, rect.get_center(), 20.0)
		return
	var bounce = absf(sin(t * 4.0)) * 1.5
	PowerUps.draw_icon(self, item, rect.get_center() + Vector2(0, -bounce), 22.0)
	var hint = Settings.key_name("use_item")
	draw_string_outline(font, Vector2(0, BOX + 11), hint, HORIZONTAL_ALIGNMENT_CENTER, BOX + 4, 9, 3, OUTLINE)
	draw_string(font, Vector2(0, BOX + 11), hint, HORIZONTAL_ALIGNMENT_CENTER, BOX + 4, 9, Color.WHITE)

# The slot jumps when the spinning stops on your power-up
func _pop() -> void:
	pivot_offset = size / 2.0
	scale = Vector2.ONE * 1.3
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
