@tool
class_name SynapseDemoConsumeAppleBehavior
extends SynapseBehavior

signal apple_consumed

@export var detector: Area2D
@export var target_apple: SynapseNodePathParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.of(detector.body_entered, _on_detector_body_entered),
	]

func _on_detector_body_entered(body: Node2D) -> void:
	if is_same(body, state_machine.get_node(target_apple.value)):
		body.queue_free()
		target_apple.value = NodePath()
		apple_consumed.emit()

func _get_read_only_parameters() -> PackedStringArray:
	return ["detected_apples"]
