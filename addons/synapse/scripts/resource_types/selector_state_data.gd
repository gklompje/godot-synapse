@tool
class_name SynapseSelectorStateData
extends SynapseStateData

@export_storage var transitions: Array[Array] = [] # [ [ SynapseStateData(source), SynapseStateData(target) ] ]

var _bound_on_state_machine_data_state_child_added: Callable
var _bound_on_state_machine_data_state_child_removed: Callable

func instantiate_state(_state_machine: SynapseStateMachine, child_states: Array[SynapseState], behaviors: Array[SynapseBehavior]) -> SynapseState:
	var transitions_dict: Dictionary[StringName, SynapseSelectorState.Transitions] = {}
	for pair in transitions:
		var from_state_data: SynapseStateData = pair[0]
		var to_state_data: SynapseStateData = pair[1]
		var state_transitions: SynapseSelectorState.Transitions = transitions_dict.get_or_add(from_state_data.name, SynapseSelectorState.Transitions.new([]))
		state_transitions.transitions.append(to_state_data.name)
	return SynapseSelectorState.new(name, child_states, transitions_dict, behaviors)

func get_type_name() -> StringName:
	return &"Selector"

func get_type_icon() -> Texture2D:
	return SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.STATE_SELECTOR)

func prepare_in_editor(editor: SynapseStateMachineEditor) -> void:
	_bound_on_state_machine_data_state_child_added = _on_state_machine_data_state_child_added.bind(editor)
	_bound_on_state_machine_data_state_child_removed = _on_state_machine_data_state_child_removed.bind(editor)
	editor.state_machine.data.state_child_added.connect(_bound_on_state_machine_data_state_child_added)
	editor.state_machine.data.state_child_removed.connect(_bound_on_state_machine_data_state_child_removed)

	for child_state_name in child_names:
		editor.state_graph_nodes[child_state_name].add_transitions_slot()

	for pair in transitions:
		var from_state_data: SynapseStateData = pair[0]
		var to_state_data: SynapseStateData = pair[1]
		var from_node := editor.state_graph_nodes[from_state_data.name]
		var to_node := editor.state_graph_nodes[to_state_data.name]
		_add_transition_connection(from_node, to_node, editor)

func teardown_in_editor(_editor: SynapseStateMachineEditor, previous_data: SynapseStateMachineData) -> void:
	previous_data.state_child_added.disconnect(_bound_on_state_machine_data_state_child_added)
	previous_data.state_child_removed.disconnect(_bound_on_state_machine_data_state_child_removed)
	_bound_on_state_machine_data_state_child_added = Callable()
	_bound_on_state_machine_data_state_child_removed = Callable()

func get_max_child_count() -> int:
	return -1

func get_configuration_warnings(_state_machine: SynapseStateMachine) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	if len(child_names) < 2:
		warnings.append({ ConfigurationWarningKey.TEXT: "Selector state needs at least two children" })
	if len(child_names) > 0:
		# this will not flag states that are only reachable from other unreachable states, but
		# that's complicated to detect (and unnecessary)
		var reachable_child_names := { child_names[0]: true } # first state is always initially selected
		for pair in transitions:
			var to_state_data: SynapseStateData = pair[1]
			if not reachable_child_names.has(to_state_data.name):
				reachable_child_names[to_state_data.name] = true
		for child_name in child_names:
			if not reachable_child_names.has(child_name):
				warnings.append({ ConfigurationWarningKey.TEXT: "State '" + child_name + "' is not reachable (has no transitions to it)" })
	return warnings

func _on_state_machine_data_state_child_added(child_state_data: SynapseStateData, parent_state_data: SynapseStateData, editor: SynapseStateMachineEditor) -> void:
	if is_same(parent_state_data, self):
		editor.state_graph_nodes[child_state_data.name].add_transitions_slot()

func _on_state_machine_data_state_child_removed(child_state_data: SynapseStateData, parent_state_data: SynapseStateData, editor: SynapseStateMachineEditor) -> void:
	if is_same(parent_state_data, self):
		editor.state_graph_nodes[child_state_data.name].remove_transitions_slot()

func can_create_child_transition(from_state_data: SynapseStateData, to_state_data: SynapseStateData) -> bool:
	for pair in transitions:
		var pair_from_state_data: SynapseStateData = pair[0]
		var pair_to_state_data: SynapseStateData = pair[1]
		if pair_from_state_data == from_state_data and pair_to_state_data == to_state_data:
			return false
	return true

func delete_transition(editor: SynapseStateMachineEditor, from_state_name: StringName, to_state_name: StringName) -> void:
	for pair in transitions:
		var from_state_data: SynapseStateData = pair[0]
		var to_state_data: SynapseStateData = pair[1]
		if from_state_data.name == from_state_name and to_state_data.name == to_state_name:
			@warning_ignore("unsafe_cast")
			var from_node := editor.state_graph_nodes.get(from_state_name) as SynapseStateGraphNode
			@warning_ignore("unsafe_cast")
			var to_node := editor.state_graph_nodes.get(to_state_name) as SynapseStateGraphNode
			if not (from_node and to_node):
				return
			if not (from_node.has_named_slot(SynapseStateGraphNode.SLOT_TRANSITIONS) and to_node.has_named_slot(SynapseStateGraphNode.SLOT_TRANSITIONS)):
				return
			editor.remove_connection_between(from_node, SynapseStateGraphNode.SLOT_TRANSITIONS, to_node, SynapseStateGraphNode.SLOT_TRANSITIONS)
			transitions.erase(pair)
			break

func create_transition(editor: SynapseStateMachineEditor, from_state_name: StringName, to_state_name: StringName) -> void:
	for pair in transitions:
		var from_state_data: SynapseStateData = pair[0]
		var to_state_data: SynapseStateData = pair[1]
		if from_state_data.name == from_state_name and to_state_data.name == to_state_name:
			return
	transitions.append([editor.state_machine.data.states[from_state_name], editor.state_machine.data.states[to_state_name]])

	var from_node := editor.state_graph_nodes[from_state_name]
	from_node.add_transitions_slot()
	var to_node := editor.state_graph_nodes[to_state_name]
	to_node.add_transitions_slot()
	_add_transition_connection(from_node, to_node, editor)

func _add_transition_connection(from_node: SynapseStateGraphNode, to_node: SynapseStateGraphNode, editor: SynapseStateMachineEditor) -> void:
	var connection_proxy := SynapseStateMachineEditor.ConnectionProxy.of(from_node, SynapseStateGraphNode.SLOT_TRANSITIONS, to_node, SynapseStateGraphNode.SLOT_TRANSITIONS)
	connection_proxy.remove_requested.connect(_on_connection_proxy_remove_requested.bind(editor, from_node, to_node))
	editor.add_connection(connection_proxy)

func create_child_transition(editor: SynapseStateMachineEditor, from_state_data: SynapseStateData, to_state_data: SynapseStateData) -> void:
	editor.undo_redo.create_action("Connect " + from_state_data.name + " to " + to_state_data.name, UndoRedo.MERGE_DISABLE, editor.state_machine)
	editor.undo_redo.add_do_method(self, "create_transition", editor, from_state_data.name, to_state_data.name)
	editor.undo_redo.add_undo_method(self, "delete_transition", editor, from_state_data.name, to_state_data.name)
	editor.undo_redo.commit_action()

func remove_child_state_undoable(editor: SynapseStateMachineEditor, child_state_data: SynapseStateData) -> void:
	var child_state_graph_node := editor.state_graph_nodes[child_state_data.name]
	editor.undo_redo.add_undo_method(child_state_graph_node, "add_transitions_slot")

	for pair in transitions:
		var from_state_data: SynapseStateData = pair[0]
		var to_state_data: SynapseStateData = pair[1]
		if from_state_data == child_state_data or to_state_data == child_state_data:
			editor.undo_redo.add_do_method(self, "delete_transition", editor, from_state_data.name, to_state_data.name)
			editor.undo_redo.add_undo_method(self, "create_transition", editor, from_state_data.name, to_state_data.name)

	editor.undo_redo.add_do_method(child_state_graph_node, "remove_transitions_slot")

func notify_erase_undoable(editor: SynapseStateMachineEditor, erased_state_names: Array[StringName], _erased_behavior_names: Array[StringName], _erased_parameter_names: Array[StringName], _erased_signal_bridge_names: Array[StringName]) -> void:
	if erased_state_names.has(name):
		# we're being erased - disconnect all children (the children are removed separately, which will deal with their transitions slots)
		for pair in transitions:
			var from_state_data: SynapseStateData = pair[0]
			var to_state_data: SynapseStateData = pair[1]
			editor.undo_redo.add_do_method(self, "delete_transition", editor, from_state_data.name, to_state_data.name)
			editor.undo_redo.add_undo_method(self, "create_transition", editor, from_state_data.name, to_state_data.name)
	else:
		# disconnect children being erased (both sides)
		for pair in transitions:
			var from_state_data: SynapseStateData = pair[0]
			var to_state_data: SynapseStateData = pair[1]
			if erased_state_names.has(from_state_data.name) or erased_state_names.has(to_state_data.name):
				editor.undo_redo.add_do_method(self, "delete_transition", editor, from_state_data.name, to_state_data.name)
				editor.undo_redo.add_undo_method(self, "create_transition", editor, from_state_data.name, to_state_data.name)

func get_callable_infos_for_signals(_state_machine: SynapseStateMachine) -> Array[Dictionary]:
	#{ "name": "select", "args": [{ "name": "state_name", "class_name": &"", "type": 0, "hint": 0, "hint_string": "", "usage": 0 }], "default_args": [], "flags": 1, "id": 0, "return": { "name": "", "class_name": &"", "type": 1, "hint": 0, "hint_string": "", "usage": 0 } }
	return [{ "name": "select", "args": [{ "name": "state_name", "type": TYPE_STRING_NAME }], "default_args": [] }]

func _on_connection_proxy_remove_requested(editor: SynapseStateMachineEditor, from_node: SynapseStateGraphNode, to_node: SynapseStateGraphNode) -> void:
	editor.undo_redo.create_action("Remove transition " + from_node.get_entity_name() + " → " + to_node.get_entity_name(), UndoRedo.MERGE_DISABLE, editor.state_machine)
	editor.undo_redo.add_do_method(self, "delete_transition", editor, from_node.get_entity_name(), to_node.get_entity_name())
	editor.undo_redo.add_undo_method(self, "create_transition", editor, from_node.get_entity_name(), to_node.get_entity_name())
	editor.undo_redo.commit_action()
