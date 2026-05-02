@tool
class_name SynapseDemoCheckSlimesBehavior
extends SynapseBehavior

static func get_category() -> StringName:
	return CATEGORY_DEMOS

signal panic

@export var detected_slimes: SynapseNodePathArrayParameter

func _get_read_only_parameters() -> PackedStringArray:
	return ["detected_slimes"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(detected_slimes, _on_detected_slimes_value_set),
	]

func _on_detected_slimes_value_set(new_value: Array[NodePath]) -> void:
	var slimes: Array[Node] = []
	for node_path in new_value:
		if not state_machine.has_node(node_path):
			continue
		var slime := state_machine.get_node(node_path)
		if is_instance_valid(slime) and not slime.is_queued_for_deletion():
			slimes.append(slime)
	if slimes.size() > 0:
		panic.emit()
