extends SynapseParameter
class_name SynapseArrayParameter

signal value_set(new_value: Array)

@export var value: Array:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
