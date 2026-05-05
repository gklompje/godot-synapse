class_name SynapseStateSignalData
extends SynapseSignalData

@export_storage var state_name: StringName
@export_storage var signal_name: StringName

@warning_ignore("shadowed_variable")
static func of(state_name: StringName, signal_name: StringName) -> SynapseStateSignalData:
	var data := SynapseStateSignalData.new()
	data.state_name = state_name
	data.signal_name = signal_name
	return data

func load_signal(state_machine: SynapseStateMachine) -> Signal:
	return state_machine.all_states[state_name].get(signal_name)
