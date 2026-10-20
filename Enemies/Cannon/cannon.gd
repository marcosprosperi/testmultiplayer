class_name Cannon extends Node2D


@export var fire_rate = 1.0
## Slower balls are easier to jump over when the cannon faces the players
@export var ball_speed := 600.0
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
	to_player_raycast.target_position.x *= face_dir
	# Mirror the muzzle around the sprite so the ball comes out of the barrel
	ball_mark_spawn.position.x = cannon.position.x + (ball_mark_spawn.position.x - cannon.position.x) * face_dir
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
	
	players_into_cannon_zone = players_into_cannon_zone.filter(is_instance_valid)
	if !players_into_cannon_zone.is_empty() and timer.is_stopped():
		timer.start(fire_rate)
		play_shoot.rpc()

# Every peer plays the animation locally so everyone sees the cannon fire
@rpc("authority", "call_local", "reliable")
func play_shoot() -> void:
	animation_player.stop()
	animation_player.play("shoot")

# Called from the "shoot" animation at the moment the barrel fires
func spawn_ball() -> void:
	if !is_multiplayer_authority():
		return
		
	var new_ball = BALL.instantiate() as Ball
	new_ball.direction = -1 if cannon_look_to == "Left" else 1
	new_ball.speed = ball_speed
	# The MultiplayerSpawner replicates the ball to the clients
	ball_mark_spawn.add_child(new_ball, true)
