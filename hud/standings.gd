class_name Standings extends CanvasLayer

## Championship table: shown after every race (with that race's results),
## as the champion screen after the last one, and while holding Tab.

@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var table: GridContainer = %Table
@onready var footer: Label = %Footer

var _time_left := 0.0
var _final := false

func _ready() -> void:
	visible = false
	RaceManager.results_shown.connect(_on_results_shown)

func _process(delta: float) -> void:
	if _time_left > 0.0:
		_time_left -= delta
		var next = "Nuevo campeonato en %d..." if _final else "Próxima carrera en %d..."
		footer.text = next % ceili(maxf(_time_left, 0.0))
		visible = _time_left > 0.0
		return
	# Hold Tab during the race to peek at the championship
	var peek = Input.is_key_pressed(KEY_TAB) and PlayersManager.game_started \
		and Hud.is_connected_to_game(multiplayer)
	if peek and not visible:
		_show_current()
	visible = peek

func _on_results_shown(results: Array, final: bool) -> void:
	_final = final
	Sfx.play("champion" if final else "results")
	_time_left = RaceManager.FINAL_RESULTS_TIME if final else RaceManager.RESULTS_TIME
	var race = "Carrera %d de %d" % [RaceManager.round_index + 1, RaceManager.rounds_total]
	results.sort_custom(func(a, b): return PlayersManager.is_ahead(
		{"points": a.total, "finishes": a.finishes}, {"points": b.total, "finishes": b.finishes}))
	if final and not results.is_empty():
		title.text = "¡%s gana el campeonato!" % results[0].name
		title.add_theme_color_override("font_color", results[0].color)
		subtitle.text = "Campeonato terminado · " + race
	else:
		title.text = "Resultados"
		title.remove_theme_color_override("font_color")
		subtitle.text = race
	var rows = []
	for result in results:
		var race_text = "%dº  +%d" % [result.position, result.gained]
		if PlayersManager.coins_enabled():
			race_text += "   +%d mon." % result.coins
		rows.append([result.name, result.color, race_text, result.total])
	_fill(rows)
	visible = true

func _show_current() -> void:
	title.text = "Campeonato"
	title.remove_theme_color_override("font_color")
	subtitle.text = "Carrera %d de %d" % [RaceManager.round_index + 1, RaceManager.rounds_total]
	footer.text = "Soltá Tab para volver"
	var rows = []
	for id in PlayersManager.standings():
		rows.append([PlayersManager.name_of(id), PlayersManager.color_of(id), "", PlayersManager.points_of(id)])
	_fill(rows)

# rows: [name, color, race column, total points], already in standing order
func _fill(rows: Array) -> void:
	for child in table.get_children():
		table.remove_child(child)
		child.queue_free()
	for header in ["", "Jugador", "Esta carrera", "Puntos"]:
		_add_cell(header, Color(1, 1, 1, 0.6))
	for i in rows.size():
		var row = rows[i]
		var color = Color.WHITE
		_add_cell("%dº" % (i + 1), color)
		_add_cell("● " + row[0], row[1])
		_add_cell(row[2], color)
		_add_cell(str(row[3]), color, true)

func _add_cell(text: String, color: Color, align_right := false) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if text.begins_with("●") else Control.SIZE_FILL
	if align_right:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	table.add_child(label)
