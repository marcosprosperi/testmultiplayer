extends Node

const PORT = 8080
const MAX_PLAYERS = 8

var game_scene_path = "res://scenes/main.tscn"
var menu_scene_path = "res://scenes/main_menu.tscn"

var is_hosting := false
var join_address := ""
# Shown by the main menu after going back to it (connection failed, host left...)
var last_error := ""

func _ready() -> void:
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	multiplayer.server_disconnected.connect(server_disconnected)

## Called from the menu: the connection starts once the game scene is loaded,
## so the spawners can replicate everything to the new peer
func host_game() -> void:
	is_hosting = true
	get_tree().change_scene_to_file(game_scene_path)

func join_game(address: String) -> void:
	is_hosting = false
	join_address = address
	get_tree().change_scene_to_file(game_scene_path)

## Called by Main when the game scene is ready
func start() -> void:
	var peer = ENetMultiplayerPeer.new()
	if is_hosting:
		var error = peer.create_server(PORT, MAX_PLAYERS - 1)
		if error != OK:
			leave("No se pudo crear la partida (¿el puerto %d está en uso?)" % PORT)
			return
		multiplayer.multiplayer_peer = peer
		DisplayServer.window_set_title("Host")
		LanDiscovery.start_broadcasting()
		print("Hosting...")
	else:
		var error = peer.create_client(join_address, PORT)
		if error != OK:
			leave("Dirección inválida: " + join_address)
			return
		multiplayer.multiplayer_peer = peer
		DisplayServer.window_set_title("Client")

## Closes the connection and goes back to the main menu
func leave(error_message := "") -> void:
	last_error = error_message
	LanDiscovery.stop_broadcasting()
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	PlayersManager.reset()
	RaceManager.reset()
	get_tree().change_scene_to_file.call_deferred(menu_scene_path)

## IPv4 addresses of this machine that other players can use to join
func get_local_ips() -> Array:
	var ips = []
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		ips.append(address)
	return ips

func connected_to_server():
	print("Successfully connected to server!")

func connection_failed():
	print("Connection failed!")
	leave("No se pudo conectar a %s (¿la partida existe o está llena?)" % join_address)

func server_disconnected():
	leave("El host cerró la partida")

func peer_connected(id: int) -> void:
	print("Player Connected: ", id)
	if multiplayer.is_server():
		PlayersManager.send_state_to(id)
		RaceManager.send_state_to(id)

func peer_disconnected(id: int) -> void:
	print("Player Disconnected: ", id)
	if multiplayer.is_server():
		PlayersManager.remove_player(id)
