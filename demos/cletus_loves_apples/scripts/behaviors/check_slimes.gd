@tool

## Used by Cletus' state machine to detect when slimes are in range, and transition to the avoiding
## state.
class_name SynapseDemoCheckSlimesBehavior
extends SynapseBehavior

static func get_category() -> StringName:
	return CATEGORY_DEMOS

signal panic # signal emitted when slimes are within the detection radius

@export var detected_slimes: SynapseNodePathArrayParameter # parameter containing paths to all slimes in Cletus' sight range

func _get_read_only_parameters() -> PackedStringArray:
	return ["detected_slimes"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(detected_slimes, _on_detected_slimes_value_set),
	]

func _on_detected_slimes_value_set(new_value: Array[NodePath]) -> void:
	var slimes: Array[Node] = []
	# check the slimes array and whether the slime nodes are still valid (slimes can time out and die)
	for node_path in new_value:
		if not state_machine.has_node(node_path):
			continue
		var slime := state_machine.get_node(node_path)
		if is_instance_valid(slime) and not slime.is_queued_for_deletion():
			slimes.append(slime)

	# run!
	if slimes.size() > 0:
		panic.emit()
