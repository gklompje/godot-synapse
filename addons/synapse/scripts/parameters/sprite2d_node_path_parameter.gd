class_name SynapseSprite2DNodePathParameter
extends SynapseParameter

signal value_set(new_value: NodePath)

@export_node_path("Sprite2D") var value: NodePath:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
