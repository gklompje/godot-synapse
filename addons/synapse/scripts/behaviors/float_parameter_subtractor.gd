@tool
class_name SynapseFloatParameterSubtractor
extends SynapseFloatParameterBinaryOperator

func _calculate_result(v1: float, v2: float) -> float:
	return v1 - v2
