extends SynapseParameter
class_name SynapseVector3ArrayParameter

signal value_set(new_value: PackedVector3Array)

@export var value: PackedVector3Array:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
