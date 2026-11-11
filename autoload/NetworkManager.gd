extends Node

const PORT = 8080
const MAX_PLAYERS = 8
## Bump it when a change makes this build unable to play with older ones
## (rules, power-ups, network messages...). Changed levels are noticed by
## themselves (LevelsVersion). Host and guests must have the same version()
const GAME_VERSION = 3
## Guests that never say which version they have (older builds) are let go
const HELLO_TIMEOUT = 5.0

## Asking the router to open the game's port (UPnP), so people outside the
## house can join with the public IP. Only when the host asks for it
enum Internet { OFF, TRYING, OPEN, FAILED }
## How long the router keeps the port open if the game can't close it (a crash)
const PORT_LEASE_SECONDS = 4 * 60 * 60

signal internet_changed

var internet := Internet.OFF
## The address people outside the house use (once internet is OPEN)
var public_ip := ""
## Why it didn't work (when internet is FAILED), or a warning when it did
var internet_note := ""
var _upnp: UPNP
var _upnp_thread: Thread
# Bumped on every try, so the answer to an old one isn't taken for the new one's
var _upnp_attempt := 0

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
	close_to_internet()
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

# --- Internet (UPnP) -----------------------------------------------------------

## Host only: ask the router to send the game's port to this PC. It takes a
## couple of seconds, so it runs apart; internet_changed says how it went
func open_to_internet() -> void:
	if not is_hosting or internet == Internet.TRYING or internet == Internet.OPEN:
		return
	_set_internet(Internet.TRYING)
	_join_upnp_thread()
	_upnp_attempt += 1
	_upnp_thread = Thread.new()
	_upnp_thread.start(_open_port.bind(port, _upnp_attempt))

## Gives the port back to the router (leaving the game, or closing it)
func close_to_internet() -> void:
	# Still trying: its answer will find the game gone and close the port itself
	_upnp_attempt += 1
	if internet == Internet.OPEN and _upnp:
		_join_upnp_thread()
		_upnp_thread = Thread.new()
		_upnp_thread.start(_close_port.bind(_upnp, port))
	_upnp = null
	_set_internet(Internet.OFF)

# In a thread: finding the router and talking to it blocks
func _open_port(game_port: int, attempt: int) -> void:
	var upnp = UPNP.new()
	var note = ""
	var ip = ""
	if upnp.discover(2000, 2, "InternetGatewayDevice") != UPNP.UPNP_RESULT_SUCCESS \
			or upnp.get_gateway() == null or not upnp.get_gateway().is_valid_gateway():
		note = "No encontré un router que deje abrir puertos (UPnP apagado)"
	else:
		# Some routers only take mappings that never expire
		var result = upnp.add_port_mapping(game_port, game_port, Settings.GAME_TITLE, "UDP", PORT_LEASE_SECONDS)
		if result != UPNP.UPNP_RESULT_SUCCESS:
			result = upnp.add_port_mapping(game_port, game_port, Settings.GAME_TITLE, "UDP", 0)
		if result != UPNP.UPNP_RESULT_SUCCESS:
			note = "El router no dejó abrir el puerto %d" % game_port
		else:
			ip = upnp.query_external_address()
			if not ip.is_valid_ip_address():
				ip = ""
				note = "El puerto se abrió, pero el router no dice tu IP pública: buscá \"cuál es mi IP\""
			elif is_private_ip(ip):
				note = "Tu proveedor comparte la IP entre clientes: desde afuera no van a poder entrar (usá Tailscale)"
	_port_opened.call_deferred(upnp, ip, note, game_port, attempt)

func _port_opened(upnp: UPNP, ip: String, note: String, game_port: int, attempt: int) -> void:
	_join_upnp_thread()
	var opened = ip != "" or note.begins_with("El puerto se abrió")
	# Left the game (or stopped hosting) while it was trying
	if attempt != _upnp_attempt or internet != Internet.TRYING:
		if opened:
			_upnp_thread = Thread.new()
			_upnp_thread.start(_close_port.bind(upnp, game_port))
		return
	_upnp = upnp if opened else null
	public_ip = ip
	internet_note = note
	_set_internet(Internet.OPEN if opened else Internet.FAILED)

func _close_port(upnp: UPNP, game_port: int) -> void:
	upnp.delete_port_mapping(game_port, "UDP")

func _set_internet(value: Internet) -> void:
	if value != Internet.OPEN:
		public_ip = ""
	if value == Internet.OFF or value == Internet.TRYING:
		internet_note = ""
	if value != internet:
		internet = value
		internet_changed.emit()

func _join_upnp_thread() -> void:
	if _upnp_thread and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()
	_upnp_thread = null

func _exit_tree() -> void:
	close_to_internet()
	_join_upnp_thread()

## Addresses that only work inside a network (home, or the provider's own)
static func is_private_ip(ip: String) -> bool:
	var parts = ip.split(".")
	if parts.size() != 4:
		return false
	var a = parts[0].to_int()
	var b = parts[1].to_int()
	return a == 10 or a == 127 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31) \
		or (a == 100 and b >= 64 and b <= 127) or (a == 169 and b == 254)
