extends SynapseParameter
class_name SynapseNodePathArrayParameter

signal value_set(new_value: Array[NodePath])

@export var value: Array[NodePath]:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
