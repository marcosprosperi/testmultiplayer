extends Node

## Sound effects. play() is for things that happen to you (your jump, your
## coin...), play_at() for things in the world you hear when you're near.

const SOUNDS = ["beep", "go", "jump", "death", "coin", "finish", "results", "champion", "cannon", "crack",
	"click", "spikes", "slam", "wind"]
## Positional sounds fade out over this distance
const HEARING_DISTANCE = 600.0

var _streams = {}

func _ready() -> void:
	for sound in SOUNDS:
		_streams[sound] = load("res://sounds/%s.wav" % sound)

func play(sound: String, volume_db := 0.0) -> void:
	var player = AudioStreamPlayer.new()
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func play_at(sound: String, global_position: Vector2, volume_db := 0.0) -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return
	var player = AudioStreamPlayer2D.new()
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.max_distance = HEARING_DISTANCE
	player.finished.connect(player.queue_free)
	scene.add_child(player)
	player.global_position = global_position
	player.play()
