extends SynapseParameter
class_name SynapseNodePathParameter

signal value_set(new_value: NodePath)

@export var value: NodePath:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
