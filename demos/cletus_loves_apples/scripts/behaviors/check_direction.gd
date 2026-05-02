@tool
class_name SynapseDemoCheckDirectionBehavior
extends SynapseBehavior

static func get_category() -> StringName:
	return CATEGORY_DEMOS

signal direction_set
signal direction_not_set

@export var direction: SynapseVector2Parameter

func _get_read_only_parameters() -> PackedStringArray:
	return ["direction"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(direction, _on_direction_value_set),
	]

func _on_direction_value_set(new_value: Vector2) -> void:
	if new_value == Vector2.ZERO:
		direction_not_set.emit()
	else:
		direction_set.emit()
