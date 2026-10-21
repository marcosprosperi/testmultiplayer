class_name PauseMenu extends CanvasLayer

## Esc (or Start on a gamepad) during the game: keep playing, options or
## leave. The race doesn't stop for the others, so your player just stands still

@onready var main: Control = %Main
@onready var note: Label = %Note
@onready var resume_button: Button = %ResumeButton
@onready var options_button: Button = %OptionsButton
@onready var leave_button: Button = %LeaveButton
@onready var settings_menu: SettingsMenu = %SettingsMenu

# Options opened from the pause menu go back to it; from the lobby, they don't
var _back_to_pause := false

func _ready() -> void:
	resume_button.pressed.connect(close)
	options_button.pressed.connect(func():
		main.visible = false
		_back_to_pause = true
		settings_menu.open())
	leave_button.pressed.connect(func():
		close()
		NetworkManager.leave())
	settings_menu.closed.connect(func():
		main.visible = _back_to_pause
		_update_menu_open())

func _unhandled_input(event: InputEvent) -> void:
	var key = event as InputEventKey
	var pad = event as InputEventJoypadButton
	var toggle = (key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE) \
		or (pad and pad.pressed and pad.button_index == JOY_BUTTON_START)
	if not toggle or settings_menu.visible:
		return
	get_viewport().set_input_as_handled()
	if main.visible:
		close()
	else:
		open()

func open() -> void:
	var racing = is_instance_valid(RaceManager.current_level)
	note.visible = racing
	leave_button.text = "Terminar la partida" if NetworkManager.is_hosting else "Salir de la partida"
	leave_button.tooltip_text = "Se termina para todos" if NetworkManager.is_hosting else ""
	main.visible = true
	_update_menu_open()

func close() -> void:
	main.visible = false
	settings_menu.visible = false
	_update_menu_open()

## Straight to the options (the lobby's button)
func open_settings() -> void:
	_back_to_pause = false
	settings_menu.open()
	_update_menu_open()

func _update_menu_open() -> void:
	Settings.menu_open = main.visible or settings_menu.visible

func _exit_tree() -> void:
	Settings.menu_open = false
