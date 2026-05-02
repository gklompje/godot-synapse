@tool
class_name SynapseSequenceStateData
extends SynapseStateData

var _bound_on_state_machine_data_state_child_added: Callable
var _bound_on_state_machine_data_state_child_removed: Callable
var _bound_on_state_machine_data_state_child_order_changed: Callable

func instantiate_state(_state_machine: SynapseStateMachine, child_states: Array[SynapseState], behaviors: Array[SynapseBehavior]) -> SynapseState:
	return SynapseSequenceState.new(name, child_states, behaviors)

func get_type_name() -> StringName:
	return &"Sequence"

func get_type_icon() -> Texture2D:
	return SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.STATE_SEQUENCE)

func prepare_in_editor(editor: SynapseStateMachineEditor) -> void:
	_bound_on_state_machine_data_state_child_added = _on_state_machine_data_state_child_added.bind(editor)
	_bound_on_state_machine_data_state_child_removed = _on_state_machine_data_state_child_removed.bind(editor)
	_bound_on_state_machine_data_state_child_order_changed = _on_state_machine_data_state_child_order_changed.bind(editor)
	editor.state_machine.data.state_child_added.connect(_bound_on_state_machine_data_state_child_added)
	editor.state_machine.data.state_child_removed.connect(_bound_on_state_machine_data_state_child_removed)
	editor.state_machine.data.state_child_order_changed.connect(_bound_on_state_machine_data_state_child_order_changed)
	update_transition_connections(editor)

func teardown_in_editor(editor: SynapseStateMachineEditor, previous_data: SynapseStateMachineData) -> void:
	delete_transition_connections(editor)
	for child_state_name in child_names:
		editor.state_graph_nodes[child_state_name].remove_transitions_slot()
	previous_data.state_child_added.disconnect(_bound_on_state_machine_data_state_child_added)
	previous_data.state_child_removed.disconnect(_bound_on_state_machine_data_state_child_removed)
	previous_data.state_child_order_changed.disconnect(_bound_on_state_machine_data_state_child_order_changed)
	_bound_on_state_machine_data_state_child_added = Callable()
	_bound_on_state_machine_data_state_child_removed = Callable()
	_bound_on_state_machine_data_state_child_order_changed = Callable()

func get_callable_infos_for_signals(_state_machine: SynapseStateMachine) -> Array[Dictionary]:
	#{ "name": "advance", "args": [], "default_args": [], "flags": METHOD_FLAG_NORMAL, "id": 0, "return": { "name": "", "class_name": &"", "type": TYPE_BOOL, "hint": PROPERTY_HINT_NONE, "hint_string": "", "usage": PROPERTY_USAGE_NONE } }
	#{ "name": "reset", "args": [], "default_args": [], "flags": METHOD_FLAG_NORMAL, "id": 0, "return": { "name": "", "class_name": &"", "type": TYPE_BOOL, "hint": PROPERTY_HINT_NONE, "hint_string": "", "usage": PROPERTY_USAGE_NONE } }
	return [
		{ "name": "advance", "args": [], "default_args": [] },
		{ "name": "reset", "args": [], "default_args": [] },
	]

func get_max_child_count() -> int:
	return -1

func get_configuration_warnings(_state_machine: SynapseStateMachine) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	if len(child_names) < 2:
		warnings.append({ ConfigurationWarningKey.TEXT: "Sequence state needs at least two children" })
	return warnings

func _on_state_machine_data_state_child_added(_child_state_data: SynapseStateData, parent_state_data: SynapseStateData, editor: SynapseStateMachineEditor) -> void:
	if parent_state_data.name == name:
		update_transition_connections(editor)

func _on_state_machine_data_state_child_removed(child_state_data: SynapseStateData, parent_state_data: SynapseStateData, editor: SynapseStateMachineEditor) -> void:
	if parent_state_data.name == name:
		update_transition_connections(editor)
		editor.state_graph_nodes[child_state_data.name].remove_transitions_slot()

func _on_state_machine_data_state_child_order_changed(parent_state_data: SynapseStateData, editor: SynapseStateMachineEditor) -> void:
	if parent_state_data.name == name:
		update_transition_connections(editor)

func delete_transition_connections(editor: SynapseStateMachineEditor) -> void:
	# delete all transitions between children
	for c in editor.find_connections_matching(_is_child_transition):
		editor.remove_connection(c)

func _is_child_transition(c: SynapseStateMachineEditor.ConnectionProxy) -> bool:
	return (c.from_graph_node is SynapseStateGraphNode\
				and c.from_slot == SynapseStateGraphNode.SLOT_TRANSITIONS\
				and child_names.has(c.from_graph_node.get_entity_name()))\
				or (c.to_graph_node is SynapseStateGraphNode\
						and c.to_slot == SynapseStateGraphNode.SLOT_TRANSITIONS\
						and child_names.has(c.to_graph_node.get_entity_name()))

func update_transition_connections(editor: SynapseStateMachineEditor) -> void:
	delete_transition_connections(editor)

	# add sequence transitions
	var child_graph_nodes: Array[SynapseStateGraphNode] = []
	for child_state_name in child_names:
		var child_graph_node := editor.state_graph_nodes[child_state_name]
		child_graph_node.add_transitions_slot()
		child_graph_nodes.append(child_graph_node)
	if len(child_graph_nodes) >= 2:
		for i in len(child_graph_nodes):
			var from_node := child_graph_nodes[i]
			var to_node := child_graph_nodes[(i + 1) % len(child_graph_nodes)]
			editor.add_connection(SynapseStateMachineEditor.ConnectionProxy.of(from_node, SynapseStateGraphNode.SLOT_TRANSITIONS, to_node, SynapseStateGraphNode.SLOT_TRANSITIONS))
