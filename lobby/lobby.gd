class_name Lobby extends CanvasLayer

## Waiting room: pick name and color, see who is in, and (host) share the IP
## and start the race. Also shown to late joiners while the race is running.

@onready var main: Main = get_parent()
@onready var title: Label = %Title
@onready var address_label: Label = %AddressLabel
@onready var copy_button: Button = %CopyButton
@onready var name_edit: LineEdit = %NameEdit
@onready var colors_box: HBoxContainer = %ColorsBox
@onready var confirm_button: Button = %ConfirmButton
@onready var status_label: Label = %StatusLabel
@onready var players_title: Label = %PlayersTitle
@onready var players_list: VBoxContainer = %PlayersList
@onready var leave_button: Button = %LeaveButton
@onready var start_button: Button = %StartButton
@onready var coins_check: CheckButton = %CoinsCheck
@onready var checkpoints_check: CheckButton = %CheckpointsCheck
@onready var bots_check: CheckButton = %BotsCheck
@onready var levels_button: Button = %LevelsButton
@onready var playlist_label: Label = %PlaylistLabel
@onready var levels_panel: PanelContainer = %LevelsPanel
@onready var level_rows: VBoxContainer = %LevelRows

const DIFFICULTY_TEXT = ["", "Fácil", "Medio", "Difícil"]
const DIFFICULTY_COLOR = [Color.WHITE, Color("#55efc4"), Color("#fdcb6e"), Color("#ff7675")]
@onready var game_name_edit: LineEdit = %GameNameEdit

const NAME_TAKEN_MESSAGE = "Ese nombre ya está en uso"

var selected_color := -1
var color_buttons: Array[Button] = []

func _ready() -> void:
	name_edit.max_length = PlayersManager.MAX_NAME_LENGTH
	game_name_edit.max_length = PlayersManager.MAX_GAME_NAME_LENGTH
	# Only the host names the game; the others see it as the title
	game_name_edit.visible = NetworkManager.is_hosting
	game_name_edit.text_changed.connect(func(text): PlayersManager.set_game_name(text))
	for i in PlayersManager.COLORS.size():
		var button = Button.new()
		button.custom_minimum_size = Vector2(18, 18)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_color_pressed.bind(i))
		colors_box.add_child(button)
		color_buttons.append(button)

	confirm_button.pressed.connect(_on_confirm_pressed)
	name_edit.text_submitted.connect(func(_text): _on_confirm_pressed())
	name_edit.text_changed.connect(func(_text): _refresh())
	leave_button.pressed.connect(func(): NetworkManager.leave())
	%OptionsButton.pressed.connect(func(): get_tree().call_group("pause_menu", "open_settings"))
	start_button.pressed.connect(func(): main.start_game())
	copy_button.pressed.connect(_on_copy_pressed)
	# Only the host can change the rules; everyone else sees them
	coins_check.toggled.connect(func(on): PlayersManager.set_coins_enabled(on))
	checkpoints_check.toggled.connect(func(on): PlayersManager.set_checkpoints_enabled(on))
	bots_check.toggled.connect(func(on): PlayersManager.set_bots_enabled(on))
	PlayersManager.settings_changed.connect(_refresh)
	PlayersManager.settings_changed.connect(_refresh_level_rows)
	levels_button.visible = NetworkManager.is_hosting
	levels_button.pressed.connect(func():
		levels_panel.visible = true
		%LevelsDim.visible = true
		_refresh_level_rows())
	%LevelsDoneButton.pressed.connect(func():
		levels_panel.visible = false
		%LevelsDim.visible = false)
	%SortButton.pressed.connect(func(): PlayersManager.set_playlist(_sorted_by_difficulty(_playlist())))
	if NetworkManager.is_hosting and PlayersManager.get_playlist().is_empty():
		PlayersManager.set_playlist(main.default_playlist())
	PlayersManager.players_changed.connect(_refresh)
	PlayersManager.profile_result.connect(_on_profile_result)
	multiplayer.connected_to_server.connect(_refresh)
	multiplayer.peer_connected.connect(func(_id): _refresh())
	multiplayer.peer_disconnected.connect(func(_id): _refresh())

	start_button.visible = NetworkManager.is_hosting
	copy_button.visible = NetworkManager.is_hosting
	# Same name and color as last time (if they're free)
	name_edit.text = Settings.player_name
	selected_color = Settings.player_color if Settings.player_color < PlayersManager.COLORS.size() else -1
	_refresh()

func _local_id() -> int:
	return multiplayer.get_unique_id() if Hud.is_connected_to_game(multiplayer) else 0

func _refresh() -> void:
	var connected = Hud.is_connected_to_game(multiplayer)
	var my_id = _local_id()
	var confirmed = connected and PlayersManager.has_player(my_id)

	# Once you're in and the race is running, the lobby gets out of the way
	visible = not (confirmed and PlayersManager.game_started)

	if NetworkManager.is_hosting:
		title.text = "Nombre de la partida:"
		var my_name = name_edit.text.strip_edges()
		game_name_edit.placeholder_text = "Partida de %s" % my_name if my_name != "" else "Ej: Carrera de los viernes"
		var ips = NetworkManager.get_local_ips()
		var ip_text = ", ".join(ips) if not ips.is_empty() else "127.0.0.1"
		address_label.text = "Compartí tu IP: %s  (puerto %d)" % [ip_text, NetworkManager.PORT]
	elif connected:
		title.text = PlayersManager.game_display_name()
		var state = "Carrera en curso" if PlayersManager.game_started else "Sala de espera"
		address_label.text = "%s · conectado a %s" % [state, NetworkManager.join_address]
	else:
		title.text = "Conectando..."
		address_label.text = "Buscando la partida en " + NetworkManager.join_address

	# Colors already used by someone else can't be picked
	for i in color_buttons.size():
		var taken = PlayersManager.is_color_taken(i, my_id)
		var button = color_buttons[i]
		button.disabled = taken or not connected
		button.text = "x" if taken else ""
		_style_color_button(button, PlayersManager.COLORS[i], i == selected_color, taken)
	if selected_color != -1 and PlayersManager.is_color_taken(selected_color, my_id):
		selected_color = -1

	var name_taken = PlayersManager.is_name_taken(name_edit.text, my_id)
	confirm_button.disabled = not connected or name_edit.text.strip_edges().is_empty() \
		or name_taken or selected_color == -1
	confirm_button.text = "Actualizar" if confirmed else ("Entrar a la carrera" if PlayersManager.game_started else "Listo")
	if name_taken:
		_set_status(NAME_TAKEN_MESSAGE, Color("#ff7675"))
	elif status_label.text == NAME_TAKEN_MESSAGE:
		_set_status("", Color.WHITE)

	coins_check.disabled = not NetworkManager.is_hosting
	coins_check.set_pressed_no_signal(PlayersManager.coins_enabled())
	checkpoints_check.disabled = not NetworkManager.is_hosting
	checkpoints_check.set_pressed_no_signal(PlayersManager.checkpoints_enabled())
	bots_check.disabled = not NetworkManager.is_hosting
	bots_check.set_pressed_no_signal(PlayersManager.bots_enabled())

	_refresh_players(my_id)
	var names = _playlist().map(func(i): return main.levels[i].title)
	playlist_label.text = "Carreras (%d): %s" % [names.size(), " → ".join(names)]
	levels_button.text = "Niveles (%d)…" % names.size()
	start_button.disabled = not PlayersManager.has_player(1)
	start_button.tooltip_text = "" if PlayersManager.has_player(1) else "Primero elegí tu nombre y color"

func _refresh_players(my_id: int) -> void:
	for child in players_list.get_children():
		child.queue_free()
	var connected_count = multiplayer.get_peers().size() + 1 if Hud.is_connected_to_game(multiplayer) else 0
	players_title.text = "Jugadores (%d/%d)" % [connected_count, NetworkManager.MAX_PLAYERS]

	# People first, then the bots (if a race is on)
	var ids = PlayersManager.joined_players.keys()
	ids.sort_custom(func(a, b): return a < b if (a < 0) == (b < 0) else b < 0)
	for id in ids:
		var row = Label.new()
		row.text = "● %s%s%s" % [PlayersManager.name_of(id), " (host)" if id == 1 else "", " ← vos" if id == my_id else ""]
		row.add_theme_color_override("font_color", PlayersManager.color_of(id))
		players_list.add_child(row)
	var people = ids.filter(func(id): return id >= 0).size()
	var choosing = connected_count - people
	if choosing > 0:
		_add_faded_row("%d eligiendo nombre..." % choosing)
	if PlayersManager.bots_enabled() and not PlayersManager.game_started and connected_count < PlayersManager.MAX_PLAYERS:
		_add_faded_row("+ %d bots al empezar" % (PlayersManager.MAX_PLAYERS - connected_count))

func _add_faded_row(text: String) -> void:
	var row = Label.new()
	row.text = text
	row.modulate = Color(1, 1, 1, 0.6)
	players_list.add_child(row)

# --- Levels ------------------------------------------------------------------

func _playlist() -> Array:
	var chosen = PlayersManager.get_playlist().filter(func(i): return i >= 0 and i < main.levels.size())
	return chosen if not chosen.is_empty() else main.default_playlist()

func _sorted_by_difficulty(order: Array) -> Array:
	var sorted = order.duplicate()
	sorted.sort_custom(func(a, b): return main.levels[a].difficulty < main.levels[b].difficulty \
		or (main.levels[a].difficulty == main.levels[b].difficulty and order.find(a) < order.find(b)))
	return sorted

func _refresh_level_rows() -> void:
	if not levels_panel.visible:
		return
	for child in level_rows.get_children():
		level_rows.remove_child(child)
		child.queue_free()
	var chosen = _playlist()
	# Chosen ones in play order first, then the rest
	var rows = chosen + range(main.levels.size()).filter(func(i): return not chosen.has(i))
	for i in rows:
		var info = main.levels[i]
		var row = HBoxContainer.new()
		var check = CheckBox.new()
		check.text = info.title
		check.button_pressed = chosen.has(i)
		check.focus_mode = Control.FOCUS_NONE
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.toggled.connect(_on_level_toggled.bind(i))
		row.add_child(check)
		var difficulty = Label.new()
		difficulty.text = DIFFICULTY_TEXT[info.difficulty]
		difficulty.add_theme_color_override("font_color", DIFFICULTY_COLOR[info.difficulty])
		difficulty.custom_minimum_size = Vector2(50, 0)
		row.add_child(difficulty)
		for step in [-1, 1]:
			var arrow = Button.new()
			arrow.text = "↑" if step < 0 else "↓"
			arrow.focus_mode = Control.FOCUS_NONE
			arrow.disabled = not chosen.has(i)
			arrow.pressed.connect(_on_level_moved.bind(i, step))
			row.add_child(arrow)
		level_rows.add_child(row)

func _on_level_toggled(on: bool, index: int) -> void:
	var chosen = _playlist()
	if on and not chosen.has(index):
		chosen.append(index)
	elif not on and chosen.size() > 1:
		chosen.erase(index)
	PlayersManager.set_playlist(chosen)
	_refresh_level_rows()

func _on_level_moved(index: int, step: int) -> void:
	var chosen = _playlist()
	var at = chosen.find(index)
	var to = at + step
	if at == -1 or to < 0 or to >= chosen.size():
		return
	chosen[at] = chosen[to]
	chosen[to] = index
	PlayersManager.set_playlist(chosen)

func _style_color_button(button: Button, color: Color, selected: bool, taken: bool) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.6) if taken else color
	style.set_corner_radius_all(3)
	style.set_border_width_all(2 if selected else 0)
	style.border_color = Color.WHITE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)

func _on_color_pressed(index: int) -> void:
	selected_color = index
	_refresh()

func _on_confirm_pressed() -> void:
	if confirm_button.disabled:
		return
	_set_status("Enviando...", Color.WHITE)
	PlayersManager.request_profile.rpc_id(1, name_edit.text, selected_color)

func _on_profile_result(ok: bool, message: String) -> void:
	if ok:
		Settings.set_profile(name_edit.text.strip_edges(), selected_color)
		var waiting = not PlayersManager.game_started and not NetworkManager.is_hosting
		_set_status("¡Listo! Esperando a que el host empiece..." if waiting else "¡Listo!", Color("#55efc4"))
	else:
		_set_status(message, Color("#ff7675"))

func _on_copy_pressed() -> void:
	var ips = NetworkManager.get_local_ips()
	DisplayServer.clipboard_set(ips[0] if not ips.is_empty() else "127.0.0.1")
	_set_status("IP copiada", Color.WHITE)

func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)
