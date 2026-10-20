@tool
class_name Trap extends Node2D

## Base for traps that go off for a while: they warn (blink) first, stay
## active for active_time and go back to rest. A TrapButton can fire them,
## and with auto_period they also fire by themselves on the race clock, at
## the same moment on every screen.

enum Phase { IDLE, WARNING, ACTIVE }

@export var warning_time := 0.6
@export var active_time := 2.5
## If > 0 the trap also goes off by itself every this many seconds
@export var auto_period := 0.0
## Shifts the automatic cycle so traps of the same kind don't go off together
@export var auto_offset := 0.0

var phase := Phase.IDLE
var _phase_time := 0.0
var _last_cycle_time := -1.0

## Fire the trap (does nothing if it's already going)
func trigger() -> void:
	if phase == Phase.IDLE:
		_set_phase(Phase.WARNING)

func _physics_process(delta: float) -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		return
	if auto_period > 0.0 and RaceManager.state == RaceManager.State.RACING:
		var cycle_time = fposmod(RaceManager.race_time() - auto_offset, auto_period)
		if cycle_time < _last_cycle_time:
			trigger()
		_last_cycle_time = cycle_time
	_phase_time += delta
	match phase:
		Phase.WARNING:
			if _phase_time >= warning_time:
				_set_phase(Phase.ACTIVE)
		Phase.ACTIVE:
			if _phase_time >= active_time:
				_set_phase(Phase.IDLE)
	_trap_process(delta)

func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	_phase_time = 0.0
	_on_phase_changed(new_phase)

## Blinks during the warning
func is_warning_blink_on() -> bool:
	return phase == Phase.WARNING and int(_phase_time * 10) % 2 == 0

# For the traps to override
func _on_phase_changed(_new_phase: Phase) -> void:
	pass

func _trap_process(_delta: float) -> void:
	pass

# Turns a kill area on or off (on the next physics step)
static func set_deadly(area: Area2D, deadly: bool) -> void:
	area.set_deferred("monitoring", deadly)
