extends Node

# CRITICAL: This must point to your GAME scene (the one with LevelContainer),
# NOT your Main Menu.
var game_scene_path = "res://scenes/main.tscn" 
var peer = ENetMultiplayerPeer.new()

func _ready() -> void:
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)

func host():
	var error = peer.create_server(8080, 8)
	if error != OK:
		print("Cannot host: " + str(error))
		return
		
	multiplayer.multiplayer_peer = peer
	DisplayServer.window_set_title("Host")
	
	# Host adds themselves immediately
	PlayersManager.add_player(1) 
	print("Hosting...")

func join():
	peer.create_client("127.0.0.1", 8080)
	multiplayer.multiplayer_peer = peer
	DisplayServer.window_set_title("Client")

func connected_to_server():
	print("Successfully connected to server!")
	# Note: We don't add ourselves here. We wait for the server
	# to tell us we are added via the peer_connected signal or Sync.

func connection_failed():
	print("Connection failed!")

func peer_connected(id: int) -> void:
	print("Player Connected: ", id)
	PlayersManager.add_player(id)
	
	# Only the server controls scene switching
	if multiplayer.is_server():
		# Logic: If we are not already in the game scene, start the game for everyone
		# when the first client joins.
		var current_scene = get_tree().current_scene.scene_file_path
		
		if current_scene != game_scene_path:
			# If we are still in the menu, start game for everyone
			change_scene.rpc(game_scene_path)
		else:
			# If the game is ALREADY running (late joiner), 
			# send only the new player to the game scene.
			change_scene.rpc_id(id, game_scene_path)

func peer_disconnected(id: int) -> void:
	print("Player Disconnected: ", id)
	PlayersManager.remove_player(id)

@rpc("call_local", "reliable")
func change_scene(scene_path: String) -> void:
	# This forces the scene change on all clients who receive the RPC
	get_tree().change_scene_to_file(scene_path)
	
