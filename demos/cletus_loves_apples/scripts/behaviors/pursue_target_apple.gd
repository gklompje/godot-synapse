@tool
class_name SynapseDemoTargetClosestAppleBehavior
extends SynapseBehavior

signal apple_targeted

@export var closest_apple: SynapseNodePathParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["closest_apple"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(closest_apple, _on_closest_apple_set),
	]

func _on_closest_apple_set(node_path: NodePath) -> void:
	if not node_path.is_empty() and state_machine.has_node(node_path) and not state_machine.get_node(node_path).is_queued_for_deletion():
		apple_targeted.emit()
