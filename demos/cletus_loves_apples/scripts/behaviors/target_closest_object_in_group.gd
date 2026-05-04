@tool

## Selects the closest object to some reference node, from an array of detected objects.[br][br]
## Used by Cletus to track apples, and by slimes to track Cletus.
class_name SynapseDemoTargetClosestObjectInGroupBehavior
extends SynapseBehavior

@export var reference_node: Node2D # the reference node to gauge distance from (usually the character)
@export var target_group: StringName # filters objects by group membership
@export var detected_objects: SynapseNodePathArrayParameter # objects currently in sight
@export var target_object: SynapseNodePathParameter # output to set to the closest object

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _on_detected_objects_value_set(new_value: Array[NodePath]) -> void:
	var closest_obj_path: NodePath
	var reference_position_global := reference_node.global_position
	var distance_to_closest_obj_squared := -1.0
	for node_path in new_value:
		# skip invalid reference (can happen transiently when loading)
		if not state_machine.has_node(node_path):
			continue

		# check if it's in the target group
		var obj := state_machine.get_node(node_path) as Node2D
		if not obj.is_in_group(target_group):
			continue

		# check distance, and choose this object if it's closest (or it's the first/only)
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
