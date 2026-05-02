@tool
@abstract
class_name SynapseIntParameterBinaryOperator
extends SynapseBehavior

@export var a: SynapseIntParameter
@export var b: SynapseIntParameter
@export var result: SynapseIntParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_MATH

func _update_result(_new_value: int = 0) -> void:
	result.value = _calculate_result(a.value, b.value)

func _get_read_only_parameters() -> PackedStringArray:
	return ["a", "b"]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if is_same(a, result) and a != null:
		warnings.append("'a' and 'result' are linked to the same resource. This will cause an infinite update loop!")
	if is_same(b, result) and b != null:
		warnings.append("'b' and 'result' are linked to the same resource. This will cause an infinite update loop!")
	return warnings

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(a, _update_result),
		SignalRelay.for_parameter(b, _update_result),
	]

@abstract
func _calculate_result(v1: int, v2: int) -> int
