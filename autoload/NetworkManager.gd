extends Node

var players = {}
var peer = ENetMultiplayerPeer.new()
var lobby = "res://scenes/level_1.tscn"

func _ready() -> void:
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	

func host():
	peer.create_server(8080, 8)
	multiplayer.multiplayer_peer = peer

func join():
	peer.create_client("127.0.0.1", 8080)
	multiplayer.multiplayer_peer = peer
	
func peer_connected(id: int) -> void:
	print("Connected....", id)
	players[id] = {"score": 0}
	if multiplayer.get_peers().size() == 1 && is_multiplayer_authority():
		change_scene.rpc(lobby)
	pass
	
func peer_disconnected(id: int) -> void:
	print("Disonnected....", id)
	players.erase(id)
	pass

@rpc("call_local", "reliable")
func change_scene(scene: String) -> void:
	get_tree().change_scene_to_file(scene)
	
@rpc("any_peer", "call_local", "reliable")
func collect_coin(id, points):
	if players.has(id):
		players[id]["score"] += points
		print("El jugador ", id, " ahora tiene: ", players[id]["score"])
		# Aquí podrías emitir una señal para actualizar tu interfaz (HUD)
	
