extends SynapseParameter
class_name SynapseCharacterBody2DNodePathParameter

signal value_set(new_value: NodePath)

@export_node_path("CharacterBody2D") var value: NodePath:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
