@tool
class_name SynapseDemoAreaBodyDetectorBehavior
extends SynapseBehavior

@export var include_groups: Array[StringName]
@export var detector: Area2D
@export var detected_objects: SynapseNodePathArrayParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_optional_properties() -> PackedStringArray:
	return ["include_groups"]

func _unsuspend() -> void:
	_on_detected_bodies_updated(null)

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.of(detector.body_entered, _on_detected_bodies_updated),
		SignalRelay.of(detector.body_exited, _on_detected_bodies_updated),
	]

func _on_detected_bodies_updated(_body: Node2D) -> void:
	var detected: Array[NodePath] = []
	for body in detector.get_overlapping_bodies():
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			if include_groups.is_empty() or include_groups.any(func(g: StringName) -> bool: return body.is_in_group(g)):
				detected.append(state_machine.get_path_to(body))
	detected_objects.value = detected
