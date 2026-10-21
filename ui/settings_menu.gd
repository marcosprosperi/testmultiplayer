class_name SettingsMenu extends Control

## Options screen (screen, sound, keys) used from the main menu and the pause
## menu. Everything is applied and saved right away (see the Settings autoload)

signal closed

@onready var screen_tab: Button = %ScreenTab
@onready var sound_tab: Button = %SoundTab
@onready var keys_tab: Button = %KeysTab
@onready var screen_page: Control = %ScreenPage
@onready var sound_page: Control = %SoundPage
@onready var keys_page: Control = %KeysPage
@onready var mode_option: OptionButton = %ModeOption
@onready var size_option: OptionButton = %SizeOption
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var fps_check: CheckButton = %FpsCheck
@onready var keys_hint: Label = %KeysHint
@onready var reset_keys_button: Button = %ResetKeysButton
@onready var back_button: Button = %BackButton

var _sliders = {}
var _value_labels = {}
var _key_buttons = {}
# Action waiting for its new key ("" when not)
var _waiting_for := ""
var _hint_text := ""

func _ready() -> void:
	visible = false
	for size in Settings.WINDOW_SIZES:
		size_option.add_item("%d × %d" % [size.x, size.y])
	screen_tab.pressed.connect(_show_page.bind(screen_page))
	sound_tab.pressed.connect(_show_page.bind(sound_page))
	keys_tab.pressed.connect(_show_page.bind(keys_page))
	mode_option.item_selected.connect(func(index): Settings.set_fullscreen(index == 1))
	size_option.item_selected.connect(Settings.set_window_size)
	vsync_check.toggled.connect(Settings.set_vsync)
	fps_check.toggled.connect(Settings.set_show_fps)
	for bus in Settings.VOLUMES:
		var slider: HSlider = sound_page.get_node("%sSlider" % bus)
		_sliders[bus] = slider
		_value_labels[bus] = sound_page.get_node("%sValue" % bus)
		slider.value_changed.connect(_on_volume_changed.bind(bus))
		# Let go of the effects slider: hear how loud they are now
		if bus == "SFX":
			slider.drag_ended.connect(func(_changed): Sfx.play("coin"))
	for action in Settings.KEY_ACTIONS:
		var button: Button = keys_page.get_node("Grid/%sKey" % action)
		_key_buttons[action] = button
		button.pressed.connect(_wait_for_key.bind(action))
	reset_keys_button.pressed.connect(func():
		_waiting_for = ""
		Settings.reset_keys())
	back_button.pressed.connect(close)
	Settings.changed.connect(_refresh)
	_hint_text = keys_hint.text

func open() -> void:
	visible = true
	screen_tab.button_pressed = true
	_show_page(screen_page)
	_refresh()

func close() -> void:
	_waiting_for = ""
	visible = false
	closed.emit()

func _show_page(page: Control) -> void:
	_waiting_for = ""
	for other in [screen_page, sound_page, keys_page]:
		other.visible = other == page
	# The other tabs fade a bit so it's clear which one you're on
	for tab in [screen_tab, sound_tab, keys_tab]:
		var selected = (tab == screen_tab and page == screen_page) or (tab == sound_tab and page == sound_page) \
			or (tab == keys_tab and page == keys_page)
		tab.set_pressed_no_signal(selected)
		tab.modulate = Color.WHITE if selected else Color(1, 1, 1, 0.6)
	_refresh()

func _refresh() -> void:
	mode_option.select(1 if Settings.fullscreen else 0)
	size_option.select(Settings.window_size)
	size_option.disabled = Settings.fullscreen
	vsync_check.set_pressed_no_signal(Settings.vsync)
	fps_check.set_pressed_no_signal(Settings.show_fps)
	for bus in _sliders:
		_sliders[bus].set_value_no_signal(Settings.volumes[bus])
		_value_labels[bus].text = "%d%%" % roundi(Settings.volumes[bus] * 100)
	for action in _key_buttons:
		_key_buttons[action].text = "..." if action == _waiting_for else Settings.key_name(action)
	keys_hint.text = "Apretá la tecla para \"%s\" (Esc cancela)" % Settings.KEY_ACTIONS[_waiting_for] \
		if _waiting_for != "" else _hint_text

func _on_volume_changed(value: float, bus: String) -> void:
	Settings.set_volume(bus, value)

func _wait_for_key(action: String) -> void:
	_waiting_for = action
	_refresh()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _waiting_for != "":
		get_viewport().set_input_as_handled()
		var action = _waiting_for
		_waiting_for = ""
		if key.keycode not in [KEY_ESCAPE, KEY_F11] and key.physical_keycode != KEY_NONE:
			Settings.set_key(action, key.physical_keycode)
		_refresh()
	elif key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
