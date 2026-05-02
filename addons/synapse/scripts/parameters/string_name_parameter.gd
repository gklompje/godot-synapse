extends SynapseParameter
class_name SynapseStringNameParameter

signal value_set(new_value: StringName)

@export var value: StringName:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
