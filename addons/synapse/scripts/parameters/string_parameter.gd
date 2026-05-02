extends SynapseParameter
class_name SynapseStringParameter

signal value_set(new_value: String)

@export var value: String:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
