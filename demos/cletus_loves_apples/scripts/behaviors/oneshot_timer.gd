@tool
class_name SynapseDemoOneShotTimerBehavior
extends SynapseBehavior

signal timeout

@export var auto_restart := false
@export_range(0.1, 60.0, 0.1, "suffix:s") var delay_seconds := 1.0

var _timer: Timer

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _state_machine_created() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = delay_seconds
	_timer.autostart = true
	_timer.timeout.connect(timeout.emit)
	add_child(_timer)

func _unsuspend() -> void:
	if _timer.is_stopped() and auto_restart:
		_timer.start(delay_seconds)

func _get_custom_save_data() -> Dictionary:
	return { &"remaining_time": _timer.time_left }

func _load_custom_save_data(custom_save_data: Dictionary) -> void:
	var remaining_time: float = custom_save_data[&"remaining_time"]
	if remaining_time > 0.0:
		_timer.wait_time = remaining_time
	else:
		_timer.stop()
