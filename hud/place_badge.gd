class_name PlaceBadge extends Control

## Bottom-left: your place in big chunky numbers (gold, silver, bronze for
## the podium), your championship points and the coins you carry

const OUTLINE = Color(0.17, 0.11, 0.23)
const PODIUM = [Color("#ffd23f"), Color("#dfe6ee"), Color("#e0975a")]
const TITLE_FONT = preload("res://ui/fonts/LilitaOne-Regular.ttf")

var place := 0
var total := 0
var points := 0
var coins := -1  # -1: coins are off
var slowdown := 0
var finished := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_state(new_place: int, new_total: int, new_points: int, new_coins: int, new_slowdown: int, done: bool) -> void:
	if [place, total, points, coins, slowdown, finished] == [new_place, new_total, new_points, new_coins, new_slowdown, done]:
		return
	# A little pop when you move up
	if new_place < place and place != 0:
		pivot_offset = Vector2(20, size.y - 20)
		scale = Vector2.ONE * 1.25
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	place = new_place
	total = new_total
	points = new_points
	coins = new_coins
	slowdown = new_slowdown
	finished = done
	queue_redraw()

func _draw() -> void:
	if place <= 0:
		return
	var font = get_theme_default_font()
	var color = PODIUM[place - 1] if place <= 3 else Color.WHITE
	var base = Vector2(0, size.y - 22)
	if finished:
		_text(TITLE_FONT, base + Vector2(0, -30), "¡META!", 12, Color("#55efc4"))
	var number = "%dº" % place
	_text(TITLE_FONT, base, number, 30, color)
	var width = TITLE_FONT.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_text(font, base + Vector2(width + 3, -2), "/%d" % total, 11, Color(1, 1, 1, 0.85))
	# Points and coins underneath
	var line = base + Vector2(1, 16)
	_text(font, line, "%d pts" % points, 9, Color.WHITE)
	if coins >= 0:
		var x = line.x + font.get_string_size("%d pts" % points, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 10
		draw_circle(Vector2(x + 4, line.y - 3), 4.5, OUTLINE)
		draw_circle(Vector2(x + 4, line.y - 3), 3.5, Color("#ffd23f"))
		draw_rect(Rect2(x + 3.5, line.y - 5, 1, 4), Color("#e8a317"))
		_text(font, Vector2(x + 11, line.y), "×%d" % coins, 9, Color.WHITE)
		if slowdown > 0:
			var after = x + 11 + font.get_string_size("×%d" % coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 5
			_text(font, Vector2(after, line.y), "-%d%% vel." % slowdown, 8, Color("#ff8f8f"))

func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(3, font_size / 5), OUTLINE)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
