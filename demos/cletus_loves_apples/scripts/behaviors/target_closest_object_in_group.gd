@tool
class_name SynapseDemoTargetClosestObjectInGroupBehavior
extends SynapseBehavior

@export var reference_node: Node2D
@export var target_group: StringName
@export var detected_objects: SynapseNodePathArrayParameter
@export var target_object: SynapseNodePathParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _on_detected_objects_value_set(new_value: Array[NodePath]) -> void:
	var closest_obj_path: NodePath
	var reference_position_global := reference_node.global_position
	var distance_to_closest_obj_squared := -1.0
	for node_path in new_value:
		if not state_machine.has_node(node_path):
			continue
		var obj := state_machine.get_node(node_path) as Node2D
		if not obj.is_in_group(target_group):
			continue
		var distance_to_obj_squared := reference_position_global.distance_squared_to(obj.global_position)
		if distance_to_closest_obj_squared < 0.0 or distance_to_obj_squared < distance_to_closest_obj_squared:
			distance_to_closest_obj_squared = distance_to_obj_squared
			closest_obj_path = node_path
	target_object.value = closest_obj_path

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(detected_objects, _on_detected_objects_value_set),
	]

func _get_read_only_parameters() -> PackedStringArray:
	return ["detected_objects"]
