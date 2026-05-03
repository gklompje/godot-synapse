@tool

## Detects bodies overlapping an [Area2D] and stores their paths in a parameter.
class_name SynapseDemoAreaBodyDetectorBehavior
extends SynapseBehavior

@export var include_groups: Array[StringName] # (optional) groups to detect- if empty, any bodies are detected
@export var detector: Area2D # Area2D to use for detection
@export var detected_objects: SynapseNodePathArrayParameter # parameter holding node paths to detected bodies

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_optional_properties() -> PackedStringArray:
	return ["include_groups"]

func _unsuspend() -> void:
	# update the detected bodies when we unsuspend, in case they changed while we were suspended
	_on_detected_bodies_updated(null)

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	# update the parameter when bodies enter and exit the Area2D
	return [
		SignalRelay.of(detector.body_entered, _on_detected_bodies_updated),
		SignalRelay.of(detector.body_exited, _on_detected_bodies_updated),
	]

func _on_detected_bodies_updated(_body: Node2D) -> void:
	# check the Area2D for any overlapping bodies and set the parameter
	var detected: Array[NodePath] = []
	for body in detector.get_overlapping_bodies():
		# ignore bodies that are being freed
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			# check group membership (if applicable)
			if include_groups.is_empty() or include_groups.any(func(g: StringName) -> bool: return body.is_in_group(g)):
				# track node paths (relative to state machine, per convention)
				detected.append(state_machine.get_path_to(body))
	# update the parameter
	detected_objects.value = detected
