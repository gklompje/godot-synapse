extends SynapseParameter
class_name SynapseVector3Parameter

signal value_set(new_value: Vector3)

@export var value: Vector3:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
