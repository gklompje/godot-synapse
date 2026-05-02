extends SynapseParameter
class_name SynapseIntArrayParameter

signal value_set(new_value: Array[int])

@export var value: Array[int]:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
