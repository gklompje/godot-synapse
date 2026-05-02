extends SynapseParameter
class_name SynapseBoolParameter

signal value_set(new_value: bool)

@export var value: bool:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
