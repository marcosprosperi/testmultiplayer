extends Node

## The player's preferences (screen, sound, keys, last name and color),
## saved in user://settings.cfg so they're the same next time

signal changed

const PATH = "user://settings.cfg"
const WINDOW_SIZES = [Vector2i(960, 540), Vector2i(1440, 810), Vector2i(1920, 1080)]
## Audio buses (see default_bus_layout.tres) and their names in the menu
const VOLUMES = {"Master": "General", "Music": "Música", "SFX": "Efectos"}
## Actions whose main key can be changed, with their names in the menu.
## The arrows and the gamepad always work too
const KEY_ACTIONS = {"left": "Izquierda", "right": "Derecha", "jump": "Saltar", "use_item": "Usar poder"}
const KEY_NAMES = {"Space": "Espacio", "Left": "←", "Right": "→", "Up": "↑", "Down": "↓",
	"Enter": "Enter", "Shift": "Shift", "Ctrl": "Ctrl", "Alt": "Alt", "Tab": "Tab", "BackSpace": "Borrar"}

var fullscreen := false
var window_size := 1
var vsync := true
var show_fps := false
var volumes = {"Master": 0.2, "Music": 0.6, "SFX": 0.8}
var player_name := ""
var player_color := -1
## True while a menu is open over the race: your player ignores the keyboard
var menu_open := false

var _default_keys = {}
var _fps_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in KEY_ACTIONS:
		_default_keys[action] = key_of(action)
	_load()
	_apply_display()
	for bus in volumes:
		_apply_volume(bus)
	_create_fps_label()
	get_tree().node_added.connect(_on_node_added)

func _input(event: InputEvent) -> void:
	# F11 or Alt+Enter: switch between window and full screen anywhere
	var key = event as InputEventKey
	if key and key.pressed and not key.echo and (key.keycode == KEY_F11 \
			or (key.keycode == KEY_ENTER and key.alt_pressed)):
		set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_fps_label.visible = show_fps
	if show_fps:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()

# --- Screen ------------------------------------------------------------------

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_display()
	save()

func set_window_size(index: int) -> void:
	window_size = clampi(index, 0, WINDOW_SIZES.size() - 1)
	_apply_display()
	save()

func set_vsync(value: bool) -> void:
	vsync = value
	_apply_display()
	save()

func set_show_fps(value: bool) -> void:
	show_fps = value
	save()

func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var vsync_mode = DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode() != vsync_mode:
		DisplayServer.window_set_vsync_mode(vsync_mode)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Never bigger than the screen, and centered on it
	var screen = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var size = WINDOW_SIZES[window_size]
	if size.x > screen.size.x or size.y > screen.size.y:
		var fit = minf(screen.size.x / float(size.x), screen.size.y / float(size.y)) * 0.95
		size = Vector2i(Vector2(size) * fit)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)

# --- Sound -------------------------------------------------------------------

## value: 0..1
func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)
	save()

func _apply_volume(bus: String) -> void:
	var index = AudioServer.get_bus_index(bus)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus], 0.0001)))
	AudioServer.set_bus_mute(index, volumes[bus] <= 0.001)

# --- Keys --------------------------------------------------------------------

func key_of(action: String) -> Key:
	var event = _main_key_event(action)
	return event.physical_keycode if event else KEY_NONE

func key_name(action: String) -> String:
	var physical = key_of(action)
	if physical == KEY_NONE:
		return "-"
	# The name of the key on this keyboard's layout (no keyboard on a headless server)
	var keycode = KEY_NONE
	if DisplayServer.get_name() != "headless":
		keycode = DisplayServer.keyboard_get_keycode_from_physical(physical)
	var text = OS.get_keycode_string(keycode if keycode != KEY_NONE else physical)
	return KEY_NAMES.get(text, text)

## A key does one thing: if another action had it, that one gets the old key
func set_key(action: String, physical: Key) -> void:
	var old = key_of(action)
	for other in KEY_ACTIONS:
		if other != action and key_of(other) == physical:
			_set_main_key(other, old)
	_set_main_key(action, physical)
	save()

func reset_keys() -> void:
	for action in _default_keys:
		_set_main_key(action, _default_keys[action])
	save()

func _main_key_event(action: String) -> InputEventKey:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event
	return null

# Replaces the first key of the action, keeping the others (arrows, gamepad)
func _set_main_key(action: String, physical: Key) -> void:
	var events = InputMap.action_get_events(action)
	var key = InputEventKey.new()
	key.physical_keycode = physical
	var index = events.find_custom(func(e): return e is InputEventKey)
	if index == -1:
		events.push_front(key)
	else:
		events[index] = key
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)

# --- Profile -----------------------------------------------------------------

## Remembered for the next game
func set_profile(new_name: String, color: int) -> void:
	player_name = new_name
	player_color = color
	save()

# --- File --------------------------------------------------------------------

func save() -> void:
	var config = ConfigFile.new()
	config.set_value("screen", "fullscreen", fullscreen)
	config.set_value("screen", "window_size", window_size)
	config.set_value("screen", "vsync", vsync)
	config.set_value("screen", "show_fps", show_fps)
	for bus in volumes:
		config.set_value("sound", bus, volumes[bus])
	for action in KEY_ACTIONS:
		config.set_value("keys", action, key_of(action))
	config.set_value("player", "name", player_name)
	config.set_value("player", "color", player_color)
	config.save(PATH)
	changed.emit()

func _load() -> void:
	var config = ConfigFile.new()
	if config.load(PATH) != OK:
		return
	fullscreen = config.get_value("screen", "fullscreen", fullscreen)
	window_size = clampi(config.get_value("screen", "window_size", window_size), 0, WINDOW_SIZES.size() - 1)
	vsync = config.get_value("screen", "vsync", vsync)
	show_fps = config.get_value("screen", "show_fps", show_fps)
	for bus in volumes:
		volumes[bus] = clampf(config.get_value("sound", bus, volumes[bus]), 0.0, 1.0)
	for action in KEY_ACTIONS:
		var physical = config.get_value("keys", action, KEY_NONE)
		if physical != KEY_NONE:
			_set_main_key(action, physical)
	player_name = config.get_value("player", "name", player_name)
	player_color = config.get_value("player", "color", player_color)

# --- Little things -----------------------------------------------------------

func _create_fps_label() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.position += Vector2(-4, 2)
	_fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fps_label.add_theme_font_size_override("font_size", 8)
	_fps_label.add_theme_constant_override("outline_size", 3)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.visible = false
	layer.add_child(_fps_label)

# Every button in the game clicks
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(func(): Sfx.play_ui("ui_click"))
		node.mouse_entered.connect(func():
			if not node.disabled:
				Sfx.play_ui("ui_hover"))
