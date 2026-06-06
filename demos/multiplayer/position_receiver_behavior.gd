@tool
class_name SynapseDemoPositionReceiver2DBehavior
extends SynapseBehavior

@export var node2d: Node2D
@export var position: SynapseVector2Parameter

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(position, _on_position_value_set)
	]

func _get_read_only_parameters() -> PackedStringArray:
	return ["position"]

func _on_position_value_set(new_value: Vector2) -> void:
	node2d.global_position = new_value
