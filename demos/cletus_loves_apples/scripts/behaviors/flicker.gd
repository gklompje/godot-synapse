@tool
class_name SynapseDemoFlickerBehavior
extends SynapseBehavior

@export_range(1.0, 10.0, 0.1) var frequency := 5.0

var _timer: Timer

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _unsuspend() -> void:
	_timer = Timer.new()
	add_child(_timer)
	_timer.one_shot = false
	_timer.timeout.connect(_flicker)

func start() -> void:
	if _timer:
		_timer.start(1.0 / frequency)

func _suspend() -> void:
	_timer.stop()
	_timer.queue_free()
	_timer = null
	(owner as CanvasItem).visible = true

func _flicker() -> void:
	(owner as CanvasItem).visible = not (owner as CanvasItem).visible
