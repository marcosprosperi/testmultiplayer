extends Node

## Background music: one loop for the menus and one per kind of level (see
## Level.music), fading from one to the other. Made by tools/gen_music.py

const TRACKS = {
	"menu": "res://sounds/music_menu.wav",
	"race": "res://sounds/music_race.wav",
	"dark": "res://sounds/music_dark.wav",
}
const FADE_TIME = 0.8
const SILENT_DB = -40.0

var _players: Array[AudioStreamPlayer] = []
var _current := ""
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player = AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)

func _process(_delta: float) -> void:
	var wanted = _wanted_track()
	if wanted != _current:
		_play(wanted)

func _wanted_track() -> String:
	var level = RaceManager.current_level
	if is_instance_valid(level) and level is Level and TRACKS.has(level.music):
		return level.music
	return "menu"

func _play(track: String) -> void:
	_current = track
	var old = _players[0]
	var new = _players[1]
	_players.reverse()
	new.stream = _load(track)
	new.volume_db = SILENT_DB
	new.play()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(new, "volume_db", 0.0, FADE_TIME)
	_tween.tween_property(old, "volume_db", SILENT_DB, FADE_TIME)
	_tween.chain().tween_callback(old.stop)

func _load(track: String) -> AudioStream:
	var stream = load(TRACKS[track])
	# The files carry a loop marker; just in case the import lost it
	if stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream
