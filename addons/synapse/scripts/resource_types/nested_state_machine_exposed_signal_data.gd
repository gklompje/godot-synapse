class_name SynapseNestedStateMachineExposedSignalData
extends SynapseSignalData

@export_storage var nested_state_machine_node_path: NodePath
@export_storage var signal_data: SynapseSignalData

func load_signal(state_machine: SynapseStateMachine) -> Signal:
	return signal_data.load_signal(state_machine.get_node(nested_state_machine_node_path) as SynapseStateMachine)

@warning_ignore("shadowed_variable")
static func of(nested_state_machine_node_path: NodePath, signal_data: SynapseSignalData) -> SynapseNestedStateMachineExposedSignalData:
	var data := SynapseNestedStateMachineExposedSignalData.new()
	data.nested_state_machine_node_path = nested_state_machine_node_path
	data.signal_data = signal_data
	return data
