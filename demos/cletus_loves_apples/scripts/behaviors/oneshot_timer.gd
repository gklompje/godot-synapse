@tool

## Starts a one-shot timer when unsuspended, and emits a signal when it times out.
class_name SynapseDemoOneShotTimerBehavior
extends SynapseBehavior

signal timeout

@export var auto_restart := false # if true, restarts the timer every time this behavior unsuspends (but not if it was already active)
@export_range(0.1, 60.0, 0.1, "suffix:s") var delay_seconds := 1.0

var _timer: Timer

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _state_machine_created() -> void:
	# create the timer and set it to autostart (it won't actually tick while this state is suspended)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = delay_seconds
	_timer.autostart = true
	_timer.timeout.connect(timeout.emit)
	add_child(_timer)

func _unsuspend() -> void:
	# restart the timer if it previously timed out, and we're set to auto-restart
	if _timer.is_stopped() and auto_restart:
		_timer.start(delay_seconds)

func _get_custom_save_data() -> Dictionary:
	# when saving, we keep track of the timer's remaining time
	return { &"remaining_time": _timer.time_left }

func _load_custom_save_data(custom_save_data: Dictionary) -> void:
	# sets the timer's timeout to the previously saved remaining time
	var remaining_time: float = custom_save_data[&"remaining_time"]
	if remaining_time > 0.0:
		_timer.wait_time = remaining_time
	else:
		# already timed out previously, just stop it (if auto_restart is true, _unsuspend() will restart it after loading is complete)
		_timer.stop()
