class_name SynapseParameterMethodSignalData
extends SynapseSignalData

@export_storage var parameter_name: StringName
@export_storage var signal_name: StringName

func load_signal(state_machine: SynapseStateMachine) -> Signal:
	return state_machine.all_parameters[parameter_name].get(signal_name)

@warning_ignore("shadowed_variable")
static func of(parameter_name: StringName, signal_name: StringName) -> SynapseParameterMethodSignalData:
	var data := SynapseParameterMethodSignalData.new()
	data.parameter_name = parameter_name
	data.signal_name = signal_name
	return data
