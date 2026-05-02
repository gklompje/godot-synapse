class_name SynapseNodeMethodSignalData
extends SynapseSignalData

@export_storage var node_path: NodePath
@export_storage var signal_name: StringName

func load_signal(state_machine: SynapseStateMachine) -> Signal:
	return state_machine.get_node(node_path).get(signal_name)

@warning_ignore("shadowed_variable")
static func of(node_path: NodePath, signal_name: StringName) -> SynapseNodeMethodSignalData:
	var data := SynapseNodeMethodSignalData.new()
	data.node_path = node_path
	data.signal_name = signal_name
	return data
