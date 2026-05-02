class_name SynapseNestedStateMachineExposedCallableData
extends SynapseCallableData

@export_storage var nested_state_machine_node_path: NodePath
@export_storage var callable_data: SynapseCallableData

func load_callable(state_machine: SynapseStateMachine) -> Callable:
	return callable_data.load_callable(state_machine.get_node(nested_state_machine_node_path) as SynapseStateMachine)

@warning_ignore("shadowed_variable")
static func of(nested_state_machine_node_path: NodePath, callable_data: SynapseCallableData) -> SynapseNestedStateMachineExposedCallableData:
	var data := SynapseNestedStateMachineExposedCallableData.new()
	data.nested_state_machine_node_path = nested_state_machine_node_path
	data.callable_data = callable_data
	return data
