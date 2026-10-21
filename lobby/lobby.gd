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
@onready var level_cards: GridContainer = %LevelCards

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
	%AllButton.pressed.connect(func(): PlayersManager.set_playlist(main.default_playlist()))
	%ShuffleButton.pressed.connect(func():
		var shuffled = _playlist().duplicate()
		shuffled.shuffle()
		PlayersManager.set_playlist(shuffled))
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
	# Long lists: the first few and how many more
	var shown = names.slice(0, 4) + (["+%d más" % (names.size() - 4)] if names.size() > 5 else names.slice(4))
	playlist_label.text = "Carreras (%d): %s" % [names.size(), " → ".join(shown)]
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
	if level_cards.get_child_count() != main.levels.size():
		for child in level_cards.get_children():
			child.queue_free()
		for i in main.levels.size():
			level_cards.add_child(_make_level_card(i))
	var chosen = _playlist()
	for i in level_cards.get_child_count():
		_update_level_card(level_cards.get_child(i), chosen.find(i))

# A card: tiny map of the level, its name and difficulty, and its number in
# the play order (if it's chosen)
func _make_level_card(index: int) -> Button:
	var info = main.levels[index]
	var card = Button.new()
	card.custom_minimum_size = Vector2(134, 54)
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = "%s · %s" % [info.title, DIFFICULTY_TEXT[info.difficulty]]
	card.pressed.connect(_on_level_card_pressed.bind(index))
	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var preview = LevelPreview.new()
	preview.custom_minimum_size = Vector2(0, 24)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.show_level(info.scene)
	box.add_child(preview)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var title = Label.new()
	title.text = info.title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(title)
	var difficulty = Label.new()
	difficulty.text = DIFFICULTY_TEXT[info.difficulty]
	difficulty.add_theme_font_size_override("font_size", 8)
	difficulty.add_theme_color_override("font_color", DIFFICULTY_COLOR[info.difficulty])
	row.add_child(difficulty)
	var badge = Label.new()
	badge.name = "Badge"
	badge.position = Vector2(-5, -6)
	badge.custom_minimum_size = Vector2(15, 15)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", Color(0.17, 0.11, 0.23))
	var circle = StyleBoxFlat.new()
	circle.bg_color = Color("#ffd23f")
	circle.border_color = Color(0.17, 0.11, 0.23)
	circle.set_border_width_all(2)
	circle.set_corner_radius_all(8)
	badge.add_theme_stylebox_override("normal", circle)
	card.add_child(badge)
	return card

func _update_level_card(card: Button, order: int) -> void:
	var chosen = order != -1
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.33, 0.24, 0.5) if chosen else Color(0.15, 0.1, 0.24)
	style.border_color = Color("#ffd23f") if chosen else Color(0.17, 0.11, 0.23)
	style.set_border_width_all(3 if chosen else 2)
	style.set_corner_radius_all(7)
	var hover = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.12)
	for state in ["normal", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(state, style)
	card.add_theme_stylebox_override("hover", hover)
	card.modulate = Color.WHITE if chosen else Color(1, 1, 1, 0.55)
	var badge: Label = card.get_node("Badge")
	badge.visible = chosen
	badge.text = str(order + 1)

func _on_level_card_pressed(index: int) -> void:
	var chosen = _playlist().duplicate()
	if not chosen.has(index):
		chosen.append(index)
	elif chosen.size() > 1:
		chosen.erase(index)
	PlayersManager.set_playlist(chosen)
	_refresh_level_rows()

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
