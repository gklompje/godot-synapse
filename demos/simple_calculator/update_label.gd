@tool
class_name SynapseDemoUpdateLabelWithFloatBehavior
extends SynapseBehavior

@export_node_path("Label") var label: NodePath
@export var parameter: SynapseFloatParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["parameter"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	@warning_ignore("unsafe_cast")
	return [
		SignalRelay.for_parameter(parameter, _on_parameter_value_set),
	]

func _on_parameter_value_set(new_value: float) -> void:
	(get_node(label) as Label).text = "%.2f" % new_value
