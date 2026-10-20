extends Node

## Finds games on the local network: the host broadcasts a small UDP packet
## every second and the join screen listens for them.

const PORT = 8910
const BROADCAST_INTERVAL = 1.0
# A game disappears from the list if nothing was heard from it for this long
const GAME_TIMEOUT_MS = 3500

signal games_changed

# ip -> {name, players, max_players, started, last_seen}
var games = {}

var _broadcaster: PacketPeerUDP
var _listener: PacketPeerUDP
var _time_to_broadcast := 0.0

func start_broadcasting() -> void:
	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	_time_to_broadcast = 0.0

func stop_broadcasting() -> void:
	if _broadcaster:
		_broadcaster.close()
	_broadcaster = null

func start_listening() -> bool:
	stop_listening()
	_listener = PacketPeerUDP.new()
	if _listener.bind(PORT) != OK:
		_listener = null
		return false
	return true

func stop_listening() -> void:
	if _listener:
		_listener.close()
	_listener = null
	games.clear()

func _process(delta: float) -> void:
	if _broadcaster:
		_time_to_broadcast -= delta
		if _time_to_broadcast <= 0.0:
			_time_to_broadcast = BROADCAST_INTERVAL
			_broadcast()
	if _listener:
		_receive()

func _broadcast() -> void:
	var info = {
		"name": PlayersManager.game_display_name(),
		"host": PlayersManager.name_of(1) if PlayersManager.has_player(1) else "",
		"players": multiplayer.get_peers().size() + 1,
		"max_players": NetworkManager.MAX_PLAYERS,
		"started": PlayersManager.game_started,
	}
	var packet = JSON.stringify(info).to_utf8_buffer()
	# Broadcast for the LAN, plus localhost so two windows on the same PC find each other
	for address in ["255.255.255.255", "127.0.0.1"]:
		_broadcaster.set_dest_address(address, PORT)
		_broadcaster.put_packet(packet)

func _receive() -> void:
	var changed = false
	while _listener.get_available_packet_count() > 0:
		var packet = _listener.get_packet()
		var ip = _listener.get_packet_ip()
		var info = JSON.parse_string(packet.get_string_from_utf8())
		if not info is Dictionary:
			continue
		# A game on this same PC arrives twice (LAN + localhost): keep a single entry
		if NetworkManager.get_local_ips().has(ip):
			ip = "127.0.0.1"
		info["last_seen"] = Time.get_ticks_msec()
		games[ip] = info
		changed = true

	for ip in games.keys():
		if Time.get_ticks_msec() - games[ip]["last_seen"] > GAME_TIMEOUT_MS:
			games.erase(ip)
			changed = true
	if changed:
		games_changed.emit()
