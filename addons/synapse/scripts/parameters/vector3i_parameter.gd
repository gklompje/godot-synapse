extends SynapseParameter
class_name SynapseVector3iParameter

signal value_set(new_value: Vector3i)

@export var value: Vector3i:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
