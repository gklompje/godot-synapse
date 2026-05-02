extends SynapseParameter
class_name SynapseIntParameter

signal value_set(new_value: int)

@export var value: int:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
