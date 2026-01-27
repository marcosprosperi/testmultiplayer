class_name MainMenu extends Control

@onready var main_menu: MainMenu = $"."
@onready var v_box_container: VBoxContainer = $VBoxContainer
@onready var v_box_container_2: VBoxContainer = $VBoxContainer2

@onready var host: Button = $VBoxContainer/Host
@onready var join: Button = $VBoxContainer/Join
@onready var ready_button: Button = $ReadyBox/ReadyButton


func _ready() -> void:
	host.pressed.connect(host_game)
	join.pressed.connect(join_game)

func host_game():
	NetworkManager.host()
	_remove_containers()
	
func join_game():
	NetworkManager.join()
	_remove_containers()


func _server_is_full():
	if multiplayer.is_server():
		ready_button.visible = true

func _remove_containers():
	v_box_container.visible = false
	v_box_container_2.visible = true
