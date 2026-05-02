class_name SynapseStateMethodCallableData
extends SynapseCallableData

@export_storage var state_name: StringName
@export_storage var method_name: StringName

@warning_ignore("shadowed_variable")
static func of(state_name: StringName, method_name: StringName) -> SynapseStateMethodCallableData:
	var data := SynapseStateMethodCallableData.new()
	data.state_name = state_name
	data.method_name = method_name
	return data

func load_callable(state_machine: SynapseStateMachine) -> Callable:
	return state_machine.all_states[state_name].get(method_name)
