extends Node

const PORT = 8080
const MAX_PLAYERS = 8
## Bump it when a change makes this build unable to play with older ones
## (rules, power-ups, network messages...). Changed levels are noticed by
## themselves (LevelsVersion). Host and guests must have the same version()
const GAME_VERSION = 2
## Guests that never say which version they have (older builds) are let go
const HELLO_TIMEOUT = 5.0

var game_scene_path = "res://scenes/main.tscn"
var menu_scene_path = "res://scenes/main_menu.tscn"

var is_hosting := false
var join_address := ""
# Shown by the main menu after going back to it (connection failed, host left...)
var last_error := ""
## The port games use: PORT, unless the game was started with "-- --port=N"
## (host and guests the same; the tests use it to run several games at once)
var port := PORT
# Server only: guests that said hello with the right version
var _greeted := {}

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port=") and argument.trim_prefix("--port=").is_valid_int():
			port = argument.trim_prefix("--port=").to_int()
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	multiplayer.server_disconnected.connect(server_disconnected)

## Called from the menu: the connection starts once the game scene is loaded,
## so the spawners can replicate everything to the new peer
func host_game() -> void:
	is_hosting = true
	Transition.change_scene(game_scene_path)

func join_game(address: String) -> void:
	is_hosting = false
	join_address = address
	Transition.change_scene(game_scene_path)

## Called by Main when the game scene is ready
func start() -> void:
	var peer = ENetMultiplayerPeer.new()
	if is_hosting:
		var error = peer.create_server(port, MAX_PLAYERS - 1)
		if error != OK:
			leave("No se pudo crear la partida (¿el puerto %d está en uso?)" % port)
			return
		multiplayer.multiplayer_peer = peer
		Settings.set_window_title("host")
		LanDiscovery.start_broadcasting()
		print("Hosting...")
	else:
		var error = peer.create_client(join_address, port)
		if error != OK:
			leave("Dirección inválida: " + join_address)
			return
		multiplayer.multiplayer_peer = peer

## What this build is, e.g. "2.3fa9c1d2": the game's version and its levels'
static func version() -> String:
	return "%d.%s" % [GAME_VERSION, LevelsVersion.HASH]

## Closes the connection and goes back to the main menu
func leave(error_message := "") -> void:
	last_error = error_message
	_greeted.clear()
	Settings.set_window_title()
	LanDiscovery.stop_broadcasting()
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	PlayersManager.reset()
	RaceManager.reset()
	Transition.change_scene.call_deferred(menu_scene_path)

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
	Settings.set_last_address(join_address)
	_hello.rpc_id(1, version())

# Guest -> host, right after connecting: which build I am. Keep these two
# messages as they are in every version, or builds that differ couldn't even
# tell each other so
@rpc("any_peer", "call_remote", "reliable")
func _hello(guest_version: String) -> void:
	if not multiplayer.is_server():
		return
	var id = multiplayer.get_remote_sender_id()
	if guest_version == version():
		_greeted[id] = true
		return
	print("Player ", id, " has another version: ", guest_version)
	_refused.rpc_id(id, "Versiones distintas del juego: el host tiene la %s y vos la %s" % [version(), guest_version])
	_drop_later(id, 1.0)

# Host -> guest: you can't play here (and why)
@rpc("authority", "call_remote", "reliable")
func _refused(message: String) -> void:
	leave(message)

# Server: closes that guest's connection in a moment (so the message before gets there)
func _drop_later(id: int, seconds: float, only_if_silent := false) -> void:
	await get_tree().create_timer(seconds).timeout
	if not multiplayer.is_server() or not multiplayer.get_peers().has(id):
		return
	if only_if_silent and _greeted.has(id):
		return
	multiplayer.multiplayer_peer.disconnect_peer(id)

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
		_drop_later(id, HELLO_TIMEOUT, true)

func peer_disconnected(id: int) -> void:
	print("Player Disconnected: ", id)
	if multiplayer.is_server():
		_greeted.erase(id)
		PlayersManager.remove_player(id)
