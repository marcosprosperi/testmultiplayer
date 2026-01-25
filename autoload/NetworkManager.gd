extends Node

var peer = ENetMultiplayerPeer.new()
var lobby = "res://scenes/level_1.tscn"

func _ready() -> void:
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	

func host():
	peer.create_server(8080, 8)
	multiplayer.multiplayer_peer = peer
	PlayersManager.add_player(1)

func join():
	peer.create_client("127.0.0.1", 8080)
	multiplayer.multiplayer_peer = peer
	
func peer_connected(id: int) -> void:
	print("Connected....", id)
	PlayersManager.add_player(id)
	if multiplayer.get_peers().size() == 1 && is_multiplayer_authority():
		change_scene.rpc(lobby)
	pass
	
func peer_disconnected(id: int) -> void:
	print("Disonnected....", id)
	PlayersManager.remove_player(id)
	pass

@rpc("call_local", "reliable")
func change_scene(scene: String) -> void:
	get_tree().change_scene_to_file(scene)
	

	
