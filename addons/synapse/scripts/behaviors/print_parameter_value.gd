@tool
class_name SynapsePrintParameterValueBehavior
extends SynapseBehavior

@export var prefix: String
@export var parameter: SynapseParameter

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_UTILITY

func _get_read_only_parameters() -> PackedStringArray:
	return ["parameter"]

func _get_optional_properties() -> PackedStringArray:
	return ["prefix"]

func _get_signal_relays() -> Array[RuntimeSignalRelay]:
	return [
		SignalRelay.for_parameter(parameter, _on_parameter_value_set),
	]

func _on_parameter_value_set(new_value: Variant) -> void:
	print(prefix, new_value)
