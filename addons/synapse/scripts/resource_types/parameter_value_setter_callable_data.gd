class_name SynapseParameterValueSetterCallableData
extends SynapseCallableData

@export_storage var parameter_name: StringName

@warning_ignore("shadowed_variable")
static func of(parameter_name: StringName) -> SynapseParameterValueSetterCallableData:
	var data := SynapseParameterValueSetterCallableData.new()
	data.parameter_name = parameter_name
	return data

func load_callable(state_machine: SynapseStateMachine) -> Callable:
	return state_machine.all_parameters[parameter_name].get(&"set_value")
