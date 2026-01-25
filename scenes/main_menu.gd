class_name MainMenu extends Control


@onready var host: Button = $VBoxContainer/Host
@onready var join: Button = $VBoxContainer/Join

func _ready() -> void:
	host.pressed.connect(host_game)
	join.pressed.connect(join_game)

func host_game():
	NetworkManager.host()
	
func join_game():
	NetworkManager.join()
