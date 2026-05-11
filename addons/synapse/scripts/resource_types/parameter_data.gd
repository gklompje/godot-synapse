@tool
class_name SynapseParameterData
extends SynapseEntityData

enum Access {
	RO,
	RW,
}

@export_storage var parameter: SynapseParameter
@export_storage var exposed := false

func _to_string() -> String:
	return "{ %s (=%s) [%s]: exposed=%s, graph_pos=%v }" % [name, parameter.get(&"value"), parameter.get_class(), exposed, graph_pos]

@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
static func create(name: StringName, parameter: SynapseParameter, graph_pos: Vector2) -> SynapseParameterData:
	var parameter_data := SynapseParameterData.new()
	parameter_data.name = name
	parameter_data.parameter = parameter
	parameter_data.graph_pos = graph_pos
	return parameter_data

func get_callable_infos_for_signals(_state_machine: SynapseStateMachine) -> Array[Dictionary]:
	for method_def in parameter.get_method_list():
		if method_def["name"] == "@value_setter":
			var set_method_def := method_def.duplicate(true)
			# at runtime we'll connect signals to 'set_value', but we need the setter's signature to determine the argument type
			set_method_def["name"] = "set_value"
			set_method_def["args"][0]["name"] = "new_value"
			return [set_method_def]
	return []

func get_signal_infos_for_callables(_state_machine: SynapseStateMachine) -> Array[Dictionary]:
	for signal_def in parameter.get_signal_list():
		if signal_def["name"] == "value_set":
			return [signal_def]
	return []

func get_configuration_warnings(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	# TODO: re-enable, but allow user to disable it
	#if SynapseClassUtil.is_value_empty(parameter.get(&"value")):
		#warnings.append({ ConfigurationWarningKey.TEXT: "Empty 'value' property" })

	# we consider a parameter referenced if its value is read or written to by any entity, or when
	# both its setter and signal are connected
	var referenced := false
	var setter_connected := not connected_signals.is_empty()
	var signal_connected := false
	for entity_data in state_machine.data.get_all_entities():
		if entity_data.get_parameter_references(state_machine).any(func(ref: SynapseParameterReferenceData) -> bool: return ref.parameter_name == name):
			referenced = true
			break
		if entity_data is SynapseSignalBridgeData:
			var signal_bridge_data := entity_data as SynapseSignalBridgeData
			if signal_bridge_data.property_references.values().any(func(ref: SynapseEntityPropertyReferenceData) -> bool: return ref.entity_reference.references(self)):
				referenced = true
				break
			if signal_bridge_data.callable_target_data.target_entity_reference.references(self):
				setter_connected = true
		if not signal_connected:
			for signal_sources: Array in entity_data.connected_signals.values():
				for signal_source_data: SynapseSignalSourceData in signal_sources:
					if signal_source_data.source_entity_reference.references(self):
						signal_connected = true
						break
				if signal_connected:
					break
		if signal_connected and setter_connected:
			referenced = true
			break

	if not referenced:
		warnings.append({ ConfigurationWarningKey.TEXT: "Not referenced" })
	return warnings

static func access_to_string(access: Access) -> String:
	match access:
		Access.RO:
			return "Read Only"
		Access.RW:
			return "Read/Write"
	push_warning("Unknown access value: ", access)
	return "<unknown>"

func create_callable_data(_callable_name: StringName, _state_machine: SynapseStateMachine) -> SynapseCallableData:
	return SynapseParameterValueSetterCallableData.of(name)

func create_signal_data(signal_name: StringName, _state_machine: SynapseStateMachine) -> SynapseSignalData:
	return SynapseParameterMethodSignalData.of(name, signal_name)
