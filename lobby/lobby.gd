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
	start_button.pressed.connect(func(): main.start_game())
	copy_button.pressed.connect(_on_copy_pressed)
	# Only the host can change the rules; everyone else sees them
	coins_check.toggled.connect(func(on): PlayersManager.set_coins_enabled(on))
	PlayersManager.settings_changed.connect(_refresh)
	PlayersManager.players_changed.connect(_refresh)
	PlayersManager.profile_result.connect(_on_profile_result)
	multiplayer.connected_to_server.connect(_refresh)
	multiplayer.peer_connected.connect(func(_id): _refresh())
	multiplayer.peer_disconnected.connect(func(_id): _refresh())

	start_button.visible = NetworkManager.is_hosting
	copy_button.visible = NetworkManager.is_hosting
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

	_refresh_players(my_id)
	start_button.disabled = not PlayersManager.has_player(1)
	start_button.tooltip_text = "" if PlayersManager.has_player(1) else "Primero elegí tu nombre y color"

func _refresh_players(my_id: int) -> void:
	for child in players_list.get_children():
		child.queue_free()
	var connected_count = multiplayer.get_peers().size() + 1 if Hud.is_connected_to_game(multiplayer) else 0
	players_title.text = "Jugadores (%d/%d)" % [connected_count, NetworkManager.MAX_PLAYERS]

	var ids = PlayersManager.joined_players.keys()
	ids.sort()
	for id in ids:
		var row = Label.new()
		row.text = "● %s%s%s" % [PlayersManager.name_of(id), " (host)" if id == 1 else "", " ← vos" if id == my_id else ""]
		row.add_theme_color_override("font_color", PlayersManager.color_of(id))
		players_list.add_child(row)
	var choosing = connected_count - ids.size()
	if choosing > 0:
		var row = Label.new()
		row.text = "%d eligiendo nombre..." % choosing
		row.modulate = Color(1, 1, 1, 0.6)
		players_list.add_child(row)

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
