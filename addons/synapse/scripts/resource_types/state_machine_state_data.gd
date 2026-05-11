@tool
class_name SynapseStateMachineStateData
extends SynapseStateData

@export_storage var state_machine_path: NodePath
@export_storage var linked_parameter_names: Dictionary[StringName, StringName] # inner state machine -> outer state machine

var _contained_state_machine_id := -1

static var KNOWN_STATE_MACHINES: Dictionary[int, WeakRef] = {} # object ID : WeakRef(SynapseStateMachine)
static var STATE_MACHINE_OWNERS: Dictionary[int, int] = {} # child object ID : parent object ID

static func _prune_stale_state_machine_ids() -> void:
	for object_id: int in SynapseStateMachineStateData.KNOWN_STATE_MACHINES.keys():
		if not is_instance_valid(SynapseStateMachineStateData.KNOWN_STATE_MACHINES[object_id].get_ref()):
			SynapseStateMachineStateData.KNOWN_STATE_MACHINES.erase(object_id)
	for child_object_id: int in SynapseStateMachineStateData.STATE_MACHINE_OWNERS.keys():
		var parent_object_id := SynapseStateMachineStateData.STATE_MACHINE_OWNERS[child_object_id]
		if not SynapseStateMachineStateData.KNOWN_STATE_MACHINES.has(child_object_id) or not SynapseStateMachineStateData.KNOWN_STATE_MACHINES.has(parent_object_id):
			SynapseStateMachineStateData.STATE_MACHINE_OWNERS.erase(child_object_id)
			continue
		var child_state_machine: SynapseStateMachine = KNOWN_STATE_MACHINES[child_object_id].get_ref()
		var parent_state_machine: SynapseStateMachine = KNOWN_STATE_MACHINES[parent_object_id].get_ref()
		if parent_state_machine.data:
			var found_child := false
			for state_data: SynapseStateData in parent_state_machine.data.states.values():
				if state_data is SynapseStateMachineStateData:
					var smsd := state_data as SynapseStateMachineStateData
					if parent_state_machine.has_node(smsd.state_machine_path) and is_same(parent_state_machine.get_node(smsd.state_machine_path), child_state_machine):
						found_child = true
						break
			if not found_child:
				SynapseStateMachineStateData.STATE_MACHINE_OWNERS.erase(child_object_id)
		else:
			SynapseStateMachineStateData.STATE_MACHINE_OWNERS.erase(child_object_id)

func get_type_name() -> StringName:
	return &"State Machine"

func get_type_icon() -> Texture2D:
	return SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.STATE_MACHINE)

func get_options(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	SynapseStateMachineStateData._prune_stale_state_machine_ids()
	var options: Array[Dictionary] = []
	for other_state_machine: SynapseStateMachine in SynapseClassUtil.find_all_child_nodes_of(state_machine.owner, &"SynapseStateMachine"):
		if SynapseStateMachineStateData.STATE_MACHINE_OWNERS.has(other_state_machine.get_instance_id()):
			# already owned
			continue

		# prevent circular dependency
		var current_owner_state_machine := state_machine
		var invalid_state_machine := false
		while is_instance_valid(current_owner_state_machine):
			if is_same(current_owner_state_machine, other_state_machine):
				invalid_state_machine = true
				break
			if SynapseStateMachineStateData.STATE_MACHINE_OWNERS.has(current_owner_state_machine.get_instance_id()):
				current_owner_state_machine = SynapseStateMachineStateData.KNOWN_STATE_MACHINES[SynapseStateMachineStateData.STATE_MACHINE_OWNERS[current_owner_state_machine.get_instance_id()]].get_ref()
			else:
				current_owner_state_machine = null
		if invalid_state_machine:
			continue

		@warning_ignore("unsafe_cast")
		options.append({
			Option.NAME: other_state_machine.name,
			Option.ICON: SynapseClassUtil.get_script_icon(other_state_machine.get_script() as Script),
			Option.DATA: state_machine.get_path_to(other_state_machine),
		})

	@warning_ignore("unsafe_cast")
	options.sort_custom(func(o1: Dictionary, o2: Dictionary) -> bool: return (o1[Option.NAME] as String).naturalcasecmp_to(o2[Option.NAME] as String) < 0)
	return options

func init_from_option(option_data: Dictionary) -> void:
	state_machine_path = option_data[Option.DATA]

func prepare_in_editor(editor: SynapseStateMachineEditor) -> void:
	var contained_state_machine := get_contained_state_machine(editor.state_machine)
	_contained_state_machine_id = contained_state_machine.get_instance_id()
	SynapseStateMachineStateData.KNOWN_STATE_MACHINES[editor.state_machine.get_instance_id()] = weakref(editor.state_machine)
	SynapseStateMachineStateData.KNOWN_STATE_MACHINES[_contained_state_machine_id] = weakref(contained_state_machine)
	SynapseStateMachineStateData.STATE_MACHINE_OWNERS[_contained_state_machine_id] = editor.state_machine.get_instance_id()

	for behavior_name in contained_state_machine.data.behaviors:
		var behavior := contained_state_machine.get_node(contained_state_machine.data.behaviors[behavior_name].node_path) as SynapseBehavior
		if behavior:
			behavior.state_machine = contained_state_machine

func instantiate_state(state_machine: SynapseStateMachine, _child_states: Array[SynapseState], behaviors: Array[SynapseBehavior]) -> SynapseState:
	return SynapseStateMachineState.new(name, get_contained_state_machine(state_machine), behaviors)

func prepare_state_graph_node(state_machine: SynapseStateMachine, state_graph_node: SynapseStateGraphNode) -> void:
	var contained_state_machine := get_contained_state_machine(state_machine)
	state_graph_node.link_node(contained_state_machine, "Go to state machine node")

	for inner_parameter_name in contained_state_machine.data.parameters:
		var inner_parameter_data := contained_state_machine.data.parameters[inner_parameter_name]
		if inner_parameter_data.exposed:
			state_graph_node.add_parameter_slot(inner_parameter_name, SynapseGUIUtil.get_parameter_value_property_dict(inner_parameter_data.parameter), has_writers(contained_state_machine, inner_parameter_name))

func has_writers(contained_state_machine: SynapseStateMachine, inner_parameter_name: StringName) -> bool:
	for entity in contained_state_machine.data.get_all_entities():
		for ref in entity.get_parameter_references(contained_state_machine):
			if ref.parameter_name == inner_parameter_name and ref.access == SynapseParameterData.Access.RW:
				return true
	return false

func get_configuration_warnings(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	if not state_machine.has_node(state_machine_path):
		return [{ ConfigurationWarningKey.TEXT: "Unable to find state machine relative to '%s' at %s" % [state_machine.name, state_machine_path] }]

	var contained_state_machine := get_contained_state_machine(state_machine)
	for warning in contained_state_machine._get_configuration_warnings():
		warnings.append({ ConfigurationWarningKey.TEXT: "[State Machine '%s'] %s" % [contained_state_machine.name, warning] })

	for inner_parameter_name in linked_parameter_names:
		var outer_parameter_name := linked_parameter_names[inner_parameter_name]
		if not contained_state_machine.data.parameters[inner_parameter_name].exposed:
			warnings.append({ ConfigurationWarningKey.TEXT: "Parameter '%s' in %s (linked to '%s') is not visible" % [inner_parameter_name, contained_state_machine.name, outer_parameter_name] })

	return warnings

func notify_state_machine_pre_created(state_machine: SynapseStateMachine) -> void:
	var contained_state_machine := get_contained_state_machine(state_machine)
	if Engine.is_editor_hint():
		SynapseStateMachineStateData.STATE_MACHINE_OWNERS[contained_state_machine.get_instance_id()] = state_machine.get_instance_id()
	else:
		# at this point the parent state machine is ready, but we don't know if the contained state machine is
		# so we connect to the *child's* signal which is called during its "_deferred_ready()". At that point we
		# know both the parent and child have loaded their parameters, but have not yet initialized themselves
		# or their children
		contained_state_machine.pre_created.connect(_prepare_contained_state_machine.bind(state_machine), CONNECT_ONE_SHOT)

func _prepare_contained_state_machine(state_machine: SynapseStateMachine) -> void:
	var contained_state_machine := get_contained_state_machine(state_machine)
	contained_state_machine.activate_on_create = false
	for inner_parameter_name in linked_parameter_names:
		var outer_parameter_name := linked_parameter_names[inner_parameter_name]
		contained_state_machine.all_parameters[inner_parameter_name] = state_machine.all_parameters[outer_parameter_name]

func is_ready(state_machine: SynapseStateMachine) -> bool:
	return state_machine.has_node(state_machine_path) and (get_contained_state_machine(state_machine)).is_created

func attempt_connection_to_empty(editor: SynapseStateMachineEditor, connection_type: SynapseStateMachineEditor.ConnectionType, slot_name: StringName, graph_position: Vector2) -> void:
	var contained_state_machine := get_contained_state_machine(editor.state_machine)
	if connection_type == SynapseStateMachineEditor.ConnectionType.PARAMETER_RO or connection_type == SynapseStateMachineEditor.ConnectionType.PARAMETER_RW:
		var inner_parameter_data := contained_state_machine.data.parameters[slot_name]
		var parameter_data := SynapseParameterData.create(editor.validate_parameter_name(slot_name), inner_parameter_data.parameter.duplicate(true) as SynapseParameter, graph_position)
		editor.undo_redo.create_action("Link parameter '" + parameter_data.name + "'", UndoRedo.MERGE_DISABLE, editor.state_machine)
		if linked_parameter_names.has(slot_name):
			editor.undo_redo.add_do_method(self, "_unlink_parameter", slot_name, editor.state_machine)
		editor.undo_redo.add_do_method(editor.state_machine.data, "add_parameter", parameter_data)
		editor.undo_redo.add_do_method(self, "_link_parameter", slot_name, parameter_data.name, editor.state_machine)
		editor.undo_redo.add_undo_method(self, "_unlink_parameter", slot_name, editor.state_machine)
		editor.undo_redo.add_undo_method(editor.state_machine.data, "remove_entity", SynapseStateMachineData.EntityType.PARAMETER, parameter_data.name)
		if linked_parameter_names.has(slot_name):
			editor.undo_redo.add_undo_method(self, "_link_parameter", slot_name, linked_parameter_names[slot_name], editor.state_machine)
		editor.undo_redo.commit_action()

func get_contained_state_machine(state_machine: SynapseStateMachine) -> SynapseStateMachine:
	return state_machine.get_node(state_machine_path)

func notify_erase_undoable(_editor: SynapseStateMachineEditor, erased_state_names: Array[StringName], _erased_behavior_names: Array[StringName], _erased_parameter_names: Array[StringName], _erased_signal_bridge_names: Array[StringName]) -> void:
	if erased_state_names.has(name):
		SynapseStateMachineStateData.STATE_MACHINE_OWNERS.erase(_contained_state_machine_id)

func _get_parameter_access(contained_state_machine: SynapseStateMachine, inner_parameter_name: StringName) -> SynapseParameterData.Access:
	if has_writers(contained_state_machine, inner_parameter_name):
		return SynapseParameterData.Access.RW
	else:
		return SynapseParameterData.Access.RO

func _link_parameter(inner_parameter_name: StringName, outer_parameter_name: StringName, state_machine: SynapseStateMachine) -> void:
	linked_parameter_names[inner_parameter_name] = outer_parameter_name
	state_machine.data.notify_parameter_reference_added(self, inner_parameter_name, outer_parameter_name, _get_parameter_access(get_contained_state_machine(state_machine), inner_parameter_name))

func _unlink_parameter(inner_parameter_name: StringName, state_machine: SynapseStateMachine) -> void:
	var outer_parameter_name := linked_parameter_names[inner_parameter_name]
	linked_parameter_names.erase(inner_parameter_name)
	state_machine.data.notify_parameter_reference_removed(self, inner_parameter_name, outer_parameter_name, _get_parameter_access(get_contained_state_machine(state_machine), inner_parameter_name))

func can_reference_parameter(parameter_data: SynapseParameterData, property_name: StringName, state_machine: SynapseStateMachine) -> bool:
	if linked_parameter_names.get(property_name, &"") == parameter_data.name:
		# already linked
		return false
	var contained_state_machine := get_contained_state_machine(state_machine)
	@warning_ignore("unsafe_cast")
	var inner_parameter_data := contained_state_machine.data.parameters.get(property_name) as SynapseParameterData
	if not inner_parameter_data or not inner_parameter_data.exposed:
		return false
	@warning_ignore("unsafe_cast")
	return SynapseClassUtil.script_inherits_class_name(parameter_data.parameter.get_script() as Script, (inner_parameter_data.parameter.get_script() as Script).get_global_name())

func reference_parameter_undoable(parameter_data: SynapseParameterData, property_name: StringName, editor: SynapseStateMachineEditor) -> SynapseParameterData.Access:
	if linked_parameter_names.has(property_name):
		editor.undo_redo.add_do_method(self, "_unlink_parameter", property_name, editor.state_machine)
	editor.undo_redo.add_do_method(self, "_link_parameter", property_name, parameter_data.name, editor.state_machine)
	editor.undo_redo.add_undo_method(self, "_unlink_parameter", property_name, editor.state_machine)
	if linked_parameter_names.has(property_name):
		editor.undo_redo.add_undo_method(self, "_link_parameter", property_name, linked_parameter_names[property_name], editor.state_machine)
	return _get_parameter_access(get_contained_state_machine(editor.state_machine), property_name)

func release_parameter_undoable(parameter_data: SynapseParameterData, property_name: StringName, editor: SynapseStateMachineEditor) -> void:
	editor.undo_redo.add_do_method(self, "_unlink_parameter", property_name, editor.state_machine)
	editor.undo_redo.add_undo_method(self, "_link_parameter", property_name, parameter_data.name, editor.state_machine)

func get_parameter_references(state_machine: SynapseStateMachine) -> Array[SynapseParameterReferenceData]:
	if linked_parameter_names.is_empty():
		return []
	var contained_state_machine := get_contained_state_machine(state_machine)
	var rw_parameters: Dictionary[StringName, bool] = {}
	for entity in contained_state_machine.data.get_all_entities():
		for ref in entity.get_parameter_references(contained_state_machine):
			if ref.access == SynapseParameterData.Access.RW:
				rw_parameters[ref.parameter_name] = true
	var references: Array[SynapseParameterReferenceData] = []
	for inner_parameter_name in linked_parameter_names:
		if rw_parameters.has(inner_parameter_name):
			references.append(SynapseParameterReferenceData.create(inner_parameter_name, linked_parameter_names[inner_parameter_name], SynapseParameterData.Access.RW))
		else:
			references.append(SynapseParameterReferenceData.create(inner_parameter_name, linked_parameter_names[inner_parameter_name], SynapseParameterData.Access.RO))
	return references

func notify_entity_renamed(entity_data: SynapseEntityData, previous_name: StringName) -> void:
	super(entity_data, previous_name)
	if entity_data is SynapseParameterData:
		for inner_parameter_name in linked_parameter_names:
			var outer_parameter_name := linked_parameter_names[inner_parameter_name]
			if outer_parameter_name == previous_name:
				linked_parameter_names[inner_parameter_name] = entity_data.name
				return

func get_signal_infos_for_callables(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	var infos: Array[Dictionary] = []
	var contained_state_machine := get_contained_state_machine(state_machine)
	var ordered_signals: Array[StringName] = []
	ordered_signals.append_array(contained_state_machine.data.exposed_signals.keys())
	ordered_signals.sort_custom(func(s1: StringName, s2: StringName) -> bool: return s1.naturalcasecmp_to(s2) < 0)
	for public_name in ordered_signals:
		var ref := contained_state_machine.data.exposed_signals[public_name]
		var entity := contained_state_machine.data.get_entity_from(ref.entity_reference)
		for signal_def in entity.get_signal_infos_for_callables(contained_state_machine):
			if signal_def["name"] == ref.property_name:
				var duplicate_info := signal_def.duplicate(true)
				duplicate_info["name"] = public_name
				infos.append(duplicate_info)
	return infos

func create_callable_data(callable_name: StringName, state_machine: SynapseStateMachine) -> SynapseCallableData:
	var contained_state_machine := get_contained_state_machine(state_machine)
	for public_name in contained_state_machine.data.exposed_callables:
		if public_name == callable_name:
			var ref := contained_state_machine.data.exposed_callables[public_name]
			var entity := contained_state_machine.data.get_entity_from(ref.entity_reference)
			return SynapseNestedStateMachineExposedCallableData.of(state_machine_path, entity.create_callable_data(ref.property_name, contained_state_machine))
	push_warning("Failed to find exposed callable '", callable_name, "' in: ", contained_state_machine.data.exposed_callables.keys())
	return null

func get_callable_infos_for_signals(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	var infos: Array[Dictionary] = []
	var contained_state_machine := get_contained_state_machine(state_machine)
	var ordered_callables: Array[StringName] = []
	ordered_callables.append_array(contained_state_machine.data.exposed_callables.keys())
	ordered_callables.sort_custom(func(s1: StringName, s2: StringName) -> bool: return s1.naturalcasecmp_to(s2) < 0)
	for public_name in ordered_callables:
		var ref := contained_state_machine.data.exposed_callables[public_name]
		var entity := contained_state_machine.data.get_entity_from(ref.entity_reference)
		for callable_def in entity.get_callable_infos_for_signals(contained_state_machine):
			if callable_def["name"] == ref.property_name:
				var duplicate_info := callable_def.duplicate(true)
				duplicate_info["name"] = public_name
				infos.append(duplicate_info)
	return infos

func create_signal_data(signal_name: StringName, state_machine: SynapseStateMachine) -> SynapseSignalData:
	var contained_state_machine := get_contained_state_machine(state_machine)
	for public_name in contained_state_machine.data.exposed_signals:
		if public_name == signal_name:
			var ref := contained_state_machine.data.exposed_signals[public_name]
			var entity := contained_state_machine.data.get_entity_from(ref.entity_reference)
			return SynapseNestedStateMachineExposedSignalData.of(state_machine_path, entity.create_signal_data(ref.property_name, contained_state_machine))
	push_warning("Failed to find exposed signal '", signal_name, "' in: ", contained_state_machine.data.exposed_signals.keys())
	return null
