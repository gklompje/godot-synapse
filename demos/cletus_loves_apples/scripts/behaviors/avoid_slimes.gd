@tool
class_name SynapseDemoAvoidSlimesBehavior
extends SynapseBehavior

signal no_more_slimes

static func get_category() -> StringName:
	return CATEGORY_DEMOS

@export var cletus: CharacterBody2D
@export var detected_slimes: SynapseNodePathArrayParameter
@export var direction: SynapseVector2Parameter

var _slimes: Array[Node2D] = []
var _time_since_last_slime_seen := 0.0

func _get_read_only_parameters() -> PackedStringArray:
	return ["detected_slimes"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(detected_slimes, _on_detected_slimes_value_set),
	]

func _suspend() -> void:
	_slimes.clear()

func _physics_process(delta: float) -> void:
	if _slimes.is_empty():
		_time_since_last_slime_seen += delta
		if _time_since_last_slime_seen > 1.0:
			no_more_slimes.emit()
		return
	var new_dir := Vector2.ZERO
	for slime in _slimes:
		if not is_instance_valid(slime) or slime.is_queued_for_deletion():
			continue
		new_dir += cletus.global_position - slime.global_position
	direction.value = new_dir

func _on_detected_slimes_value_set(new_value: Array[NodePath]) -> void:
	var slimes_was_empty := _slimes.is_empty()
	_slimes.clear()
	for node_path in new_value:
		if not state_machine.has_node(node_path):
			continue
		var slime := state_machine.get_node(node_path)
		if is_instance_valid(slime) and not slime.is_queued_for_deletion():
			_slimes.append(slime)
	if _slimes.is_empty() and not slimes_was_empty:
		_time_since_last_slime_seen = 0.0
