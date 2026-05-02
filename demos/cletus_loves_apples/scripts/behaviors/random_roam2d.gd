@tool
class_name SynapseDemoRandomRoam2D
extends SynapseDemoCharacterBehavior2D

@export var radius := 100.0
@export var stop_radius := 10.0
@export var direction: SynapseVector2Parameter
@export var recalculate_interval_seconds := 5.0
@export var max_stop_time_seconds := 1.0

var _roam_origin := Vector2.ZERO
var _target_position := Vector2.ZERO
var _seconds_since_last_recalculate := 0.0
var _seconds_since_stop := 0.0

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_seconds_since_last_recalculate = recalculate_interval_seconds

func _unsuspend() -> void:
	_roam_origin = character.global_position
	_recalculate()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_seconds_since_last_recalculate += delta
	if _seconds_since_last_recalculate >= recalculate_interval_seconds or _seconds_since_stop >= max_stop_time_seconds:
		_recalculate()
	if character.global_position.distance_squared_to(_target_position) <= stop_radius * stop_radius:
		if direction.value == Vector2.ZERO:
			_seconds_since_stop += delta
		else:
			direction.value = Vector2.ZERO
	else:
		_seconds_since_stop = 0.0

func _recalculate() -> void:
	_seconds_since_last_recalculate = 0.0
	var angle := randf_range(0.0, TAU)
	var distance := randf() * radius
	_target_position = _roam_origin + Vector2(distance * cos(angle), distance * sin(angle))
	direction.value = _target_position - character.global_position
