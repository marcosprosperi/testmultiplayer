class_name Cannon extends Node2D


@export var fire_rate = 1.0
@export_enum("Left", "Right") var cannon_look_to: String = "Left"
const BALL = preload("uid://dvsy05ku6fb48")


@onready var to_player_raycast: RayCast2D = $ToPlayerRaycast
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var timer: Timer = $Timer
@onready var ball_mark_spawn: Marker2D = $BallMarkSpawn
@onready var cannon: Sprite2D = $Cannon
@onready var cannon_action: Sprite2D = $CannonAction
@onready var player_detection_area: Area2D = $PlayerDetectionArea

var players_into_cannon_zone = []

func _ready() -> void:
	timer.wait_time = fire_rate
	var face_dir = 1 if cannon_look_to == "Left" else -1
	
	cannon.scale.x = face_dir
	player_detection_area.scale.x = face_dir
	cannon_action.scale.x = face_dir
	player_detection_area.body_entered.connect(_on_body_entered)
	player_detection_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if !is_multiplayer_authority():
		return
	if body.is_in_group("player"):
		players_into_cannon_zone.append(body)
		
	
func _on_body_exited(body: Node2D) -> void:
	if !is_multiplayer_authority():
		return
	if body.is_in_group("player"):
		players_into_cannon_zone.erase(body)
	
func _physics_process(_delta: float) -> void:
	if !is_multiplayer_authority():
		return
	
	if !players_into_cannon_zone.is_empty():
		shoot.rpc()

@rpc("call_local", "reliable")
func shoot() -> void:
	if !is_multiplayer_authority():
		return
		
	if timer.is_stopped():
		animation_player.play("shoot")
		var new_ball = BALL.instantiate() as Ball
		new_ball.position = ball_mark_spawn.position
		new_ball.direction = -1 if cannon_look_to == "Left" else 1
		ball_mark_spawn.add_child(new_ball, true)
		timer.start(fire_rate)	
		pass
