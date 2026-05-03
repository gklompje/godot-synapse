@tool

## "Eats" (frees) an apple when Cletus reaches it.
class_name SynapseDemoConsumeAppleBehavior
extends SynapseBehavior

signal apple_consumed # connected by the game state machine to update the score

@export var detector: Area2D # detection area for when the apple is close enough to eat
@export var target_apple: SynapseNodePathParameter # the apple Cletus currently has his eyes on

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["detected_apples"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.of(detector.body_entered, _on_detector_body_entered),
	]

func _on_detector_body_entered(body: Node2D) -> void:
	# check whether the in-range apple is the same one Cletus is tracking, and if so "eat" (free) it
	if is_same(body, state_machine.get_node(target_apple.value)):
		# yummy!
		body.queue_free()
		target_apple.value = NodePath()
		apple_consumed.emit()
