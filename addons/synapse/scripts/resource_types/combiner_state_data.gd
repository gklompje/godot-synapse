@tool
class_name SynapseCombinerStateData
extends SynapseStateData

func instantiate_state(_state_machine: SynapseStateMachine, child_states: Array[SynapseState], behaviors: Array[SynapseBehavior]) -> SynapseState:
	return SynapseCombinerState.new(name, child_states, behaviors)

func get_type_name() -> StringName:
	return &"Combiner"

func get_type_icon() -> Texture2D:
	return SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.STATE_COMBINER)

func get_callable_infos_for_signals(_state_machine: SynapseStateMachine) -> Array[Dictionary]:
	#{ "name": "select", "args": [{ "name": "state_name", "class_name": &"", "type": 0, "hint": 0, "hint_string": "", "usage": 0 }], "default_args": [], "flags": 1, "id": 0, "return": { "name": "", "class_name": &"", "type": 1, "hint": 0, "hint_string": "", "usage": 0 } }
	#{ "name": "deselect", "args": [{ "name": "state_name", "class_name": &"", "type": 0, "hint": 0, "hint_string": "", "usage": 0 }], "default_args": [], "flags": 1, "id": 0, "return": { "name": "", "class_name": &"", "type": 1, "hint": 0, "hint_string": "", "usage": 0 } }
	return [
		{ "name": "select", "args": [{ "name": "state_name", "type": TYPE_STRING_NAME }], "default_args": [] },
		{ "name": "deselect", "args": [{ "name": "state_name", "type": TYPE_STRING_NAME }], "default_args": [] },
	]

func get_max_child_count() -> int:
	return -1

func get_configuration_warnings(_state_machine: SynapseStateMachine) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	if len(child_names) < 1:
		warnings.append({ ConfigurationWarningKey.TEXT: "Combiner state needs at least one child" })
	return warnings
