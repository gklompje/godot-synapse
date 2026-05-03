@tool

## Frees the behavior's scene owner node after a set timeout.[br][br]
## Used to clean up slimes after they've entered their dying state. Poor slimes.
class_name SynapseDemoFreeOnDeathBehavior
extends SynapseBehavior

@export_range(0.1, 60.0, 0.1, "suffix:s") var delay_seconds := 1.0

var _timer: Timer

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _state_machine_created() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = delay_seconds
	_timer.autostart = true
	_timer.timeout.connect(owner.queue_free)
	add_child(_timer)

func _get_custom_save_data() -> Dictionary:
	# track the timer's remaining time so when the game is loaded we can resume it
	return { &"remaining_time": _timer.time_left }

func _load_custom_save_data(custom_save_data: Dictionary) -> void:
	# resume the timer from where it was when the game was saved
	var remaining_time: float = custom_save_data[&"remaining_time"]
	if remaining_time > 0.0:
		_timer.wait_time = remaining_time
	else:
		_timer.stop()
