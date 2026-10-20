class_name MainMenu extends Control

@onready var start_screen: Control = %StartScreen
@onready var join_screen: Control = %JoinScreen
@onready var error_label: Label = %ErrorLabel
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var quit_button: Button = %QuitButton
@onready var games_list: ItemList = %GamesList
@onready var discovery_label: Label = %DiscoveryLabel
@onready var join_selected_button: Button = %JoinSelectedButton
@onready var ip_edit: LineEdit = %IpEdit
@onready var connect_button: Button = %ConnectButton
@onready var back_button: Button = %BackButton

# ip of each row in games_list
var _list_ips: Array = []

func _ready() -> void:
	host_button.pressed.connect(NetworkManager.host_game)
	join_button.pressed.connect(_show_join_screen)
	quit_button.pressed.connect(get_tree().quit)
	back_button.pressed.connect(_show_start_screen)
	connect_button.pressed.connect(_connect_to_typed_ip)
	ip_edit.text_submitted.connect(func(_text): _connect_to_typed_ip())
	ip_edit.text_changed.connect(func(_text): _refresh_buttons())
	join_selected_button.pressed.connect(_join_selected)
	games_list.item_selected.connect(func(_index): _refresh_buttons())
	games_list.item_activated.connect(func(_index): _join_selected())
	LanDiscovery.games_changed.connect(_refresh_games)

	ip_edit.text = NetworkManager.join_address
	error_label.text = NetworkManager.last_error
	NetworkManager.last_error = ""
	_show_start_screen()

func _show_start_screen() -> void:
	LanDiscovery.stop_listening()
	start_screen.visible = true
	join_screen.visible = false

func _show_join_screen() -> void:
	start_screen.visible = false
	join_screen.visible = true
	error_label.text = ""
	if LanDiscovery.start_listening():
		discovery_label.text = "Buscando partidas en tu red..."
	else:
		discovery_label.text = "No se pueden buscar partidas (puerto %d ocupado). Ingresá la IP." % LanDiscovery.PORT
	_refresh_games()

func _refresh_games() -> void:
	var selected_ip = _selected_ip()
	games_list.clear()
	_list_ips.clear()
	for ip in LanDiscovery.games:
		var game = LanDiscovery.games[ip]
		var full = game.players >= game.max_players
		var state = "llena" if full else ("en carrera" if game.started else "esperando")
		var text = "%s  —  %s  (%d/%d, %s)" % [game.name, ip, game.players, game.max_players, state]
		var index = games_list.add_item(text)
		games_list.set_item_disabled(index, full)
		_list_ips.append(ip)
		if ip == selected_ip and not full:
			games_list.select(index)
	if not _list_ips.is_empty():
		discovery_label.text = "Partidas encontradas en tu red:"
	elif LanDiscovery._listener:
		discovery_label.text = "Buscando partidas en tu red..."
	_refresh_buttons()

func _selected_ip() -> String:
	var selected = games_list.get_selected_items()
	return _list_ips[selected[0]] if not selected.is_empty() and selected[0] < _list_ips.size() else ""

func _refresh_buttons() -> void:
	join_selected_button.disabled = _selected_ip() == ""
	connect_button.disabled = not ip_edit.text.strip_edges().is_valid_ip_address()

func _join_selected() -> void:
	var ip = _selected_ip()
	if ip != "":
		_join(ip)

func _connect_to_typed_ip() -> void:
	var ip = ip_edit.text.strip_edges()
	if ip.is_valid_ip_address():
		_join(ip)

func _join(ip: String) -> void:
	LanDiscovery.stop_listening()
	NetworkManager.join_game(ip)
