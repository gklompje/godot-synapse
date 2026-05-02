extends SynapseParameter
class_name SynapseFloatParameter

signal value_set(new_value: float)

@export var value: float:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
