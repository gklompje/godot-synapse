@tool
class_name SynapseStateMachineData
extends Resource

signal root_state_set(root_state_name: StringName)
signal entity_renamed(entity_data: SynapseEntityData, previous_name: StringName)
signal entity_callable_exposed(entity_data: SynapseEntityData, callable_name: StringName, public_name: StringName)
signal entity_callable_unexposed(entity_data: SynapseEntityData, callable_name: StringName, public_name: StringName)
signal exposed_entity_callable_renamed(entity_data: SynapseEntityData, callable_name: StringName, previous_public_name: StringName, new_public_name: StringName)
signal entity_signal_exposed(entity_data: SynapseEntityData, signal_name: StringName, public_name: StringName)
signal entity_signal_unexposed(entity_data: SynapseEntityData, signal_name: StringName, public_name: StringName)
signal exposed_entity_signal_renamed(entity_data: SynapseEntityData, signal_name: StringName, previous_public_name: StringName, new_public_name: StringName)

signal state_added(state_data: SynapseStateData)
signal state_removed(state_data: SynapseStateData)
signal state_child_added(child_state_data: SynapseStateData, parent_state_data: SynapseStateData)
signal state_child_removed(child_state_data: SynapseStateData, parent_state_data: SynapseStateData)
signal state_child_order_changed(parent_state_data: SynapseStateData)
signal state_behavior_order_changed(state_data: SynapseStateData)
signal state_connected_to_signal(state_data: SynapseStateData, signal_id: StringName, signal_source_data: SynapseSignalSourceData)
signal state_disconnected_from_signal(state_data: SynapseStateData, signal_id: StringName, signal_source_data: SynapseSignalSourceData)

signal behavior_added(behavior_data: SynapseBehaviorData)
signal behavior_removed(behavior_data: SynapseBehaviorData)
signal behavior_added_to_state(behavior_data: SynapseBehaviorData, state_data: SynapseStateData)
signal behavior_removed_from_state(behavior_data: SynapseBehaviorData, state_data: SynapseStateData)
signal behavior_connected_to_signal(behavior_data: SynapseBehaviorData, signal_relay_connector_name: StringName, signal_source_data: SynapseSignalSourceData)
signal behavior_disconnected_from_signal(behavior_data: SynapseBehaviorData, signal_relay_connector_name: StringName, signal_source_data: SynapseSignalSourceData)

signal parameter_added(parameter_data: SynapseParameterData)
signal parameter_removed(parameter_data: SynapseParameterData)
signal parameter_reference_added(parameter_data: SynapseParameterData, entity_data: SynapseEntityData, property_name: StringName, access: SynapseParameterData.Access)
signal parameter_reference_removed(parameter_data: SynapseParameterData, entity_data: SynapseEntityData, property_name: StringName, access: SynapseParameterData.Access)
signal parameter_exposed_set(parameter_data: SynapseParameterData)
signal parameter_connected_to_signal(parameter_data: SynapseParameterData, method_name: StringName, signal_source_data: SynapseSignalSourceData)
signal parameter_disconnected_from_signal(parameter_data: SynapseParameterData, method_name: StringName, signal_source_data: SynapseSignalSourceData)

signal signal_bridge_added(signal_bridge_data: SynapseSignalBridgeData)
signal signal_bridge_removed(signal_bridge_data: SynapseSignalBridgeData)
signal signal_bridge_signal_property_wired(signal_bridge_data: SynapseSignalBridgeData, signal_argument_name: StringName, callable_argument_name: StringName)
signal signal_bridge_signal_property_unwired(signal_bridge_data: SynapseSignalBridgeData, callable_argument_name: StringName)
signal signal_bridge_property_reference_assigned(signal_bridge_data: SynapseSignalBridgeData, entity_property_reference_data: SynapseEntityPropertyReferenceData, callable_argument_name: StringName)
signal signal_bridge_property_reference_unassigned(signal_bridge_data: SynapseSignalBridgeData, entity_property_reference_data: SynapseEntityPropertyReferenceData, callable_argument_name: StringName)

enum EntityType {
	STATE,
	BEHAVIOR,
	PARAMETER,
	SIGNAL_BRIDGE,
	UNKNOWN = 10_000,
}

@export_storage var godot_version: String
@export_storage var plugin_version: String
@export_storage var root_state: StringName:
	set(value):
		root_state = value
		root_state_set.emit(root_state)
@export_storage var root_pos: Vector2
@export_storage var editor_scroll_offset := Vector2.ZERO
@export_storage var editor_zoom := 1.0
@export_storage var states: Dictionary[StringName, SynapseStateData] = {}
@export_storage var behaviors: Dictionary[StringName, SynapseBehaviorData] = {}
@export_storage var parameters: Dictionary[StringName, SynapseParameterData] = {}
@export_storage var signal_bridges: Dictionary[StringName, SynapseSignalBridgeData] = {}
@export_storage var exposed_callables: Dictionary[StringName, SynapseEntityPropertyReferenceData] = {}
@export_storage var exposed_signals: Dictionary[StringName, SynapseEntityPropertyReferenceData] = {}

func _init() -> void:
	if Engine.is_editor_hint():
		if not godot_version:
			godot_version = Engine.get_version_info()["string"]
			emit_changed()
		if not plugin_version:
			plugin_version = SynapseStateMachineEditorPlugin.get_plugin_version_from_config()
			emit_changed()

func add_state(state_data: SynapseStateData) -> void:
	if states.has(state_data.name):
		push_error("Cannot add state with duplicate name '", state_data.name, "'")
		return
	if state_data.parent_name:
		push_error("Cannot add state with parent state already set ('", state_data.parent_name, "')")
		return
	if not state_data.child_names.is_empty():
		push_error("Cannot add state with child states already set: ", state_data.child_names)
		return
	states[state_data.name] = state_data
	state_added.emit(state_data)
	emit_changed()

func remove_state_from_parent(child_state_name: StringName) -> void:
	var child_data := states[child_state_name]
	if not child_data.parent_name:
		return
	var parent_data := states[child_data.parent_name]
	parent_data.child_names.erase(child_state_name)
	child_data.parent_name = &""
	state_child_removed.emit(child_data, parent_data)
	emit_changed()

func add_state_to(child_state_name: StringName, parent_state_name: StringName, index: int = -1) -> void:
	var child_data := states[child_state_name]
	var parent_data := states[parent_state_name]
	if child_data.parent_name:
		push_error("Cannot add state to another parent while parent state still set ('", child_data.parent_name, "')")
		return

	child_data.parent_name = parent_state_name
	if index < 0 or index > parent_data.child_names.size():
		parent_data.child_names.append(child_state_name)
	else:
		parent_data.child_names.insert(index, child_state_name)
	state_child_added.emit(child_data, parent_data)
	emit_changed()

func order_child_states(parent_state_name: StringName, ordered_child_names: Array[StringName]) -> void:
	var parent_state_data := states[parent_state_name]
	if parent_state_data.child_names == ordered_child_names:
		return
	var new_child_names: Array[StringName] = []
	for child_name in parent_state_data.child_names:
		if not ordered_child_names.has(child_name):
			new_child_names.append(child_name)
	for child_name in ordered_child_names:
		if parent_state_data.child_names.has(child_name):
			new_child_names.append(child_name)
		else:
			push_warning("Cannot order unknown child state '", child_name, "'")
	parent_state_data.child_names.clear()
	parent_state_data.child_names.append_array(new_child_names)
	state_child_order_changed.emit(parent_state_data)
	emit_changed()

func order_behaviors(state_name: StringName, ordered_behavior_names: Array[StringName]) -> void:
	var state_data := states[state_name]
	if state_data.behavior_names == ordered_behavior_names:
		return
	var new_behavior_names: Array[StringName] = []
	for behavior_name in state_data.behavior_names:
		if not ordered_behavior_names.has(behavior_name):
			new_behavior_names.append(behavior_name)
	for behavior_name in ordered_behavior_names:
		if state_data.behavior_names.has(behavior_name):
			new_behavior_names.append(behavior_name)
		else:
			push_warning("Cannot order unknown behavior '", behavior_name, "'")
	state_data.behavior_names.clear()
	state_data.behavior_names.append_array(new_behavior_names)
	state_behavior_order_changed.emit(state_data)
	emit_changed()

func remove_behavior_from_owner_state(behavior_name: StringName) -> void:
	var behavior_data := behaviors[behavior_name]
	if not behavior_data.owner_state_name:
		return
	var state_data := states[behavior_data.owner_state_name]
	state_data.behavior_names.erase(behavior_name)
	behavior_data.owner_state_name = &""
	behavior_removed_from_state.emit(behavior_data, state_data)
	emit_changed()

func add_behavior_to_owner_state(behavior_name: StringName, state_name: StringName, index: int = -1) -> void:
	var behavior_data := behaviors[behavior_name]
	if behavior_data.owner_state_name:
		push_error("Cannot add behavior to another state while still assigned to owner state ('", behavior_data.owner_state_name, "')")
		return
	var state_data := states[state_name]
	behavior_data.owner_state_name = state_name
	if index < 0 or index > state_data.behavior_names.size():
		state_data.behavior_names.append(behavior_name)
	else:
		state_data.behavior_names.insert(index, behavior_name)
	behavior_added_to_state.emit(behavior_data, state_data)
	emit_changed()

func add_behavior(behavior_data: SynapseBehaviorData) -> void:
	if behaviors.has(behavior_data.name):
		push_error("Cannot add behavior with duplicate name '", behavior_data.name, "'")
		return
	if not behavior_data.parameters.is_empty():
		push_error("Cannot add behavior with parameters already assigned: ", behavior_data.parameters)
		return
	if behavior_data.owner_state_name:
		push_error("Cannot add behavior with owner state already assigned ('", behavior_data.owner_state_name, "')")
		return
	behaviors[behavior_data.name] = behavior_data
	behavior_added.emit(behavior_data)
	emit_changed()

func add_parameter(parameter_data: SynapseParameterData) -> void:
	if parameters.has(parameter_data.name):
		push_error("Cannot add parameter with duplicate name '", parameter_data.name, "'")
		return
	parameters[parameter_data.name] = parameter_data
	parameter_added.emit(parameter_data)
	emit_changed()

func set_parameter_exposed(parameter_name: StringName, exposed: bool) -> void:
	if not parameters.has(parameter_name):
		push_error("Can't find parameter '", parameter_name, "' to set exposure")
		return
	var parameter_data := parameters[parameter_name]
	parameter_data.exposed = exposed
	parameter_exposed_set.emit(parameter_data)
	emit_changed()

func add_signal_bridge(signal_bridge: SynapseSignalBridgeData) -> void:
	if signal_bridges.has(signal_bridge.name):
		push_error("Cannot add signal bridge with duplicate name '", signal_bridge.name, "'")
		return
	signal_bridges[signal_bridge.name] = signal_bridge
	signal_bridge_added.emit(signal_bridge)
	emit_changed()

func wire_signal_bridge_signal_argument(signal_bridge_name: StringName, signal_argument_name: StringName, callable_argument_name: StringName) -> void:
	var signal_bridge_data := signal_bridges[signal_bridge_name]
	if signal_bridge_data.wired_parameters.has(callable_argument_name) or signal_bridge_data.property_references.has(callable_argument_name):
		push_error("Cannot assign argument '", callable_argument_name, "' of signal bridge - already assigned")
		return
	signal_bridge_data.wired_parameters[callable_argument_name] = signal_argument_name
	emit_changed()
	signal_bridge_signal_property_wired.emit(signal_bridge_data, signal_argument_name, callable_argument_name)

func unwire_signal_bridge_signal_argument(signal_bridge_name: StringName, callable_argument_name: StringName) -> void:
	var signal_bridge_data := signal_bridges[signal_bridge_name]
	if not signal_bridge_data.wired_parameters.has(callable_argument_name):
		push_warning("Cannot unwire argument '", callable_argument_name, "' of signal bridge - not wired")
		return
	signal_bridge_data.wired_parameters.erase(callable_argument_name)
	emit_changed()
	signal_bridge_signal_property_unwired.emit(signal_bridge_data, callable_argument_name)

func assign_signal_bridge_property_reference(signal_bridge_name: StringName, entity_property_reference_data: SynapseEntityPropertyReferenceData, argument_name: StringName) -> void:
	var signal_bridge_data := signal_bridges[signal_bridge_name]
	if not has_reference(entity_property_reference_data.entity_reference):
		push_error("Cannot assign unknown resource to signal bridge: ", entity_property_reference_data.entity_reference)
		return
	if signal_bridge_data.wired_parameters.has(argument_name) or signal_bridge_data.property_references.has(argument_name):
		push_error("Cannot assign argument '", argument_name, "' of signal bridge - already assigned")
		return
	signal_bridge_data.property_references[argument_name] = entity_property_reference_data
	emit_changed()
	signal_bridge_property_reference_assigned.emit(signal_bridge_data, entity_property_reference_data, argument_name)

func unassign_signal_bridge_property_reference(signal_bridge_name: StringName, argument_name: StringName) -> void:
	var signal_bridge_data := signal_bridges[signal_bridge_name]
	if not signal_bridge_data.property_references.has(argument_name):
		push_error("Cannot unassign argument '", argument_name, "' of signal bridge - not assigned")
		return
	var entity_property_reference_data := signal_bridge_data.property_references[argument_name]
	signal_bridge_data.property_references.erase(argument_name)
	emit_changed()
	signal_bridge_property_reference_unassigned.emit(signal_bridge_data, entity_property_reference_data, argument_name)

func has_resource(resource: SynapseEntityData) -> bool:
	if resource is SynapseStateData:
		return states.has(resource.name)
	elif resource is SynapseBehaviorData:
		return behaviors.has(resource.name)
	elif resource is SynapseParameterData:
		return parameters.has(resource.name)
	elif resource is SynapseSignalBridgeData:
		return signal_bridges.has(resource.name)
	push_warning("Cannot determine if this data has unknown resource: ", resource)
	return false

static func get_entity_type(resource: SynapseEntityData) -> EntityType:
	if resource is SynapseStateData:
		return EntityType.STATE
	elif resource is SynapseBehaviorData:
		return EntityType.BEHAVIOR
	elif resource is SynapseParameterData:
		return EntityType.PARAMETER
	elif resource is SynapseSignalBridgeData:
		return EntityType.SIGNAL_BRIDGE
	push_warning("Cannot determine entity type for resource: ", resource)
	return EntityType.UNKNOWN

static func get_entity_name(resource: SynapseEntityData) -> StringName:
	if resource is SynapseStateData:
		return (resource as SynapseStateData).name
	elif resource is SynapseBehaviorData:
		return (resource as SynapseBehaviorData).name
	elif resource is SynapseParameterData:
		return (resource as SynapseParameterData).name
	elif resource is SynapseSignalBridgeData:
		return (resource as SynapseSignalBridgeData).name
	push_warning("Cannot determine name of unknown resource: ", resource)
	return &""

func has_entity(entity_type: EntityType, entity_name: StringName) -> bool:
	match entity_type:
		EntityType.STATE:
			return states.has(entity_name)
		EntityType.BEHAVIOR:
			return behaviors.has(entity_name)
		EntityType.PARAMETER:
			return parameters.has(entity_name)
		EntityType.SIGNAL_BRIDGE:
			return signal_bridges.has(entity_name)
	push_error("Unknown entity type: ", entity_type)
	return false

func has_reference(ref: SynapseEntityReferenceData) -> bool:
	return has_entity(ref.entity_type, ref.entity_name)

func get_entity(entity_type: EntityType, entity_name: StringName) -> SynapseEntityData:
	match entity_type:
		EntityType.STATE:
			return states[entity_name]
		EntityType.BEHAVIOR:
			return behaviors[entity_name]
		EntityType.PARAMETER:
			return parameters[entity_name]
		EntityType.SIGNAL_BRIDGE:
			return signal_bridges[entity_name]
	push_error("Unknown entity type: ", entity_type)
	return null

func get_entity_from(entity_reference: SynapseEntityReferenceData) -> SynapseEntityData:
	return get_entity(entity_reference.entity_type, entity_reference.entity_name)

func rename_entity(entity_type: EntityType, current_name: StringName, new_name: StringName) -> void:
	if not has_entity(entity_type, current_name):
		push_error("Cannot rename unknown ", get_entity_type_name(entity_type), " '", current_name, "'")
		return
	var entity := get_entity(entity_type, current_name)

	var state_parent_name := &""
	var state_parent_pos := -1
	var state_child_names: Array[StringName] = []
	var state_behaviors: Array[StringName] = []
	var behavior_owner_state_name := &""
	var behavior_owner_state_pos := -1
	var entity_map: Dictionary
	if entity is SynapseStateData:
		entity_map = states
		var state_data := entity as SynapseStateData
		if state_data.parent_name:
			state_parent_name = state_data.parent_name
			state_parent_pos = states[state_data.parent_name].child_names.find(current_name)
			remove_state_from_parent(current_name)
		for child_state_name: StringName in state_data.child_names.duplicate():
			state_child_names.append(child_state_name)
			remove_state_from_parent(child_state_name)
		for behavior_name: StringName in state_data.behavior_names.duplicate():
			state_behaviors.append(behavior_name)
			remove_behavior_from_owner_state(behavior_name)
	elif entity is SynapseBehaviorData:
		entity_map = behaviors
		var behavior_data := entity as SynapseBehaviorData
		if behavior_data.owner_state_name:
			behavior_owner_state_name = behavior_data.owner_state_name
			behavior_owner_state_pos = states[behavior_data.owner_state_name].behavior_names.find(current_name)
			remove_behavior_from_owner_state(current_name)
	elif entity is SynapseParameterData:
		entity_map = parameters
	elif entity is SynapseSignalBridgeData:
		entity_map = signal_bridges

	entity_map.erase(current_name)
	entity.name = new_name
	entity_map[new_name] = entity

	emit_changed()
	for referencing_entity in get_all_entities():
		referencing_entity.notify_entity_renamed(entity, current_name)
	entity_renamed.emit(entity, current_name)

	if entity is SynapseStateData:
		var state_data := entity as SynapseStateData
		if state_parent_name:
			add_state_to(state_data.name, state_parent_name, state_parent_pos)
		for child_state_name in state_child_names:
			add_state_to(child_state_name, state_data.name)
		for behavior_name in state_behaviors:
			add_behavior_to_owner_state(behavior_name, state_data.name)
		if root_state == current_name:
			root_state = new_name
	elif entity is SynapseBehaviorData:
		var behavior_data := entity as SynapseBehaviorData
		if behavior_owner_state_name:
			add_behavior_to_owner_state(behavior_data.name, behavior_owner_state_name, behavior_owner_state_pos)

func remove_entity(entity_type: EntityType, entity_name: StringName) -> void:
	if not has_entity(entity_type, entity_name):
		push_error("Cannot remove unknown ", get_entity_type_name(entity_type), " '", entity_name, "'")
		return

	var entity := get_entity(entity_type, entity_name)
	for signal_bridge_data: SynapseSignalBridgeData in signal_bridges.values():
		@warning_ignore("unsafe_cast")
		var source_signal_data := signal_bridge_data.connected_signals[SynapseSignalBridgeData.CALLABLE_NAME][0] as SynapseSignalSourceData
		if source_signal_data.source_entity_reference.references(entity) or signal_bridge_data.callable_target_data.target_entity_reference.references(entity):
			push_error("Cannot remove entity with signal bridge still attached")
			return

	for ref: SynapseEntityPropertyReferenceData in exposed_callables.values():
		if ref.entity_reference.references(entity):
			push_error("Cannot remove entity with exposed callable '", ref.property_name, "'")
			return
	for ref: SynapseEntityPropertyReferenceData in exposed_signals.values():
		if ref.entity_reference.references(entity):
			push_error("Cannot remove entity with exposed signal '", ref.property_name, "'")
			return

	# now delete the entity
	match entity_type:
		EntityType.STATE:
			var state_data := states[entity_name]
			if root_state == entity_name:
				push_error("Cannot remove root state")
				return
			if state_data.parent_name:
				push_error("Cannot remove state with parent state still set ('", state_data.parent_name, "')")
				return
			for child_state_name in state_data.child_names:
				push_error("Cannot remove state with child states still set ('", state_data.child_names, "')")
				return
			for behavior_name in state_data.behavior_names:
				push_error("Cannot remove state with behavior(s) still owned ('", state_data.behavior_names, "')")
				return
			states.erase(entity_name)
			state_removed.emit(state_data)
		EntityType.BEHAVIOR:
			var behavior_data := behaviors[entity_name]
			if behavior_data.owner_state_name:
				push_error("Cannot remove behavior while it still belongs to owner state ('", behavior_data.owner_state_name, "')")
				return
			if not behavior_data.parameters.is_empty():
				push_error("Cannot remove behavior with parameters still assigned: ", behavior_data.parameters)
				return
			behaviors.erase(entity_name)
			behavior_removed.emit(behavior_data)
		EntityType.PARAMETER:
			var parameter_data := parameters[entity_name]
			parameters.erase(entity_name)
			parameter_removed.emit(parameter_data)
		EntityType.SIGNAL_BRIDGE:
			var signal_bridge_data := signal_bridges[entity_name]
			signal_bridges.erase(entity_name)
			signal_bridge_removed.emit(signal_bridge_data)

	emit_changed()

func create_callable_target_data_for(state_machine: SynapseStateMachine, to_entity_type: EntityType, to_entity_name: StringName, to_callable_id: StringName) -> SynapseCallableTargetData:
	var entity := get_entity(to_entity_type, to_entity_name)
	var callable_data := entity.create_callable_data(to_callable_id, state_machine)
	if callable_data:
		return SynapseCallableTargetData.of(SynapseEntityReferenceData.of(to_entity_type, to_entity_name), to_callable_id, callable_data)
	else:
		push_warning("No callable data for ", get_entity_type_name(to_entity_type), " '", to_entity_name, "': ", to_callable_id)
		return null

func create_signal_source_data_for(state_machine: SynapseStateMachine, from_entity_type: EntityType, from_entity_name: StringName, from_signal_id: StringName) -> SynapseSignalSourceData:
	var entity := get_entity(from_entity_type, from_entity_name)
	var signal_data := entity.create_signal_data(from_signal_id, state_machine)
	if signal_data:
		return SynapseSignalSourceData.of(SynapseEntityReferenceData.of(from_entity_type, from_entity_name), from_signal_id, signal_data)
	else:
		push_warning("No signal data for ", get_entity_type_name(from_entity_type), " '", from_entity_name, "': ", from_signal_id)
		return null

func connect_signal(signal_source_data: SynapseSignalSourceData, to_entity_type: EntityType, to_entity_name: StringName, to_callable_id: StringName) -> void:
	match to_entity_type:
		EntityType.STATE:
			var state_data := states[to_entity_name]
			@warning_ignore("unsafe_cast")
			(state_data.connected_signals.get_or_add(to_callable_id, []) as Array).append(signal_source_data)
			state_connected_to_signal.emit(state_data, to_callable_id, signal_source_data)
		EntityType.BEHAVIOR:
			var behavior_data := behaviors[to_entity_name]
			@warning_ignore("unsafe_cast")
			(behavior_data.connected_signals.get_or_add(to_callable_id, []) as Array).append(signal_source_data)
			behavior_connected_to_signal.emit(behavior_data, to_callable_id, signal_source_data)
		EntityType.PARAMETER:
			var parameter_data := parameters[to_entity_name]
			@warning_ignore("unsafe_cast")
			(parameter_data.connected_signals.get_or_add(to_callable_id, []) as Array).append(signal_source_data)
			parameter_connected_to_signal.emit(parameter_data, to_callable_id, signal_source_data)
		_:
			push_error("Don't know how to connect signal to ", get_entity_type_name(to_entity_type))
			return
	emit_changed()

func disconnect_signal(signal_source_data: SynapseSignalSourceData, to_entity_type: EntityType, to_entity_name: StringName, to_callable_id: StringName) -> void:
	match to_entity_type:
		EntityType.STATE:
			var state_data := states[to_entity_name]
			@warning_ignore("unsafe_cast")
			(state_data.connected_signals.get(to_callable_id, []) as Array).erase(signal_source_data)
			if not state_data.connected_signals.get(to_callable_id):
				state_data.connected_signals.erase(to_callable_id)
			state_disconnected_from_signal.emit(state_data, to_callable_id, signal_source_data)
		EntityType.BEHAVIOR:
			var behavior_data := behaviors[to_entity_name]
			@warning_ignore("unsafe_cast")
			(behavior_data.connected_signals.get(to_callable_id, []) as Array).erase(signal_source_data)
			if not behavior_data.connected_signals.get(to_callable_id):
				behavior_data.connected_signals.erase(to_callable_id)
			behavior_disconnected_from_signal.emit(behavior_data, to_callable_id, signal_source_data)
		EntityType.PARAMETER:
			var parameter_data := parameters[to_entity_name]
			@warning_ignore("unsafe_cast")
			(parameter_data.connected_signals.get(to_callable_id, []) as Array).erase(signal_source_data)
			if not parameter_data.connected_signals.get(to_callable_id):
				parameter_data.connected_signals.erase(to_callable_id)
			parameter_disconnected_from_signal.emit(parameter_data, to_callable_id, signal_source_data)
		_:
			push_error("Don't know how to connect signal to ", get_entity_type_name(to_entity_type))
			return
	emit_changed()

func expose_callable(entity_type: EntityType, entity_name: StringName, callable_name: StringName, public_name: StringName, state_machine: SynapseStateMachine) -> void:
	if exposed_callables.has(public_name):
		push_warning("State machine already has an exposed callable called '", public_name, "'")
		return
	if not has_entity(entity_type, entity_name):
		push_warning("State machine has no ", get_entity_type_name(entity_type), " called '", entity_name, "'")
		return
	var entity := get_entity(entity_type, entity_name)
	if not entity.get_callable_infos_for_signals(state_machine).any(func(d: Dictionary) -> bool: return d["name"] == callable_name):
		push_warning(get_entity_type_name(entity_type), " '", entity_name, "' has no callable called '", callable_name, "'")
		return
	exposed_callables[public_name] = SynapseEntityPropertyReferenceData.create(SynapseEntityReferenceData.from(entity), callable_name)
	entity_callable_exposed.emit(entity, callable_name, public_name)

func unexpose_callable(public_name: StringName) -> void:
	if not exposed_callables.has(public_name):
		push_warning("State machine has no exposed callable called '", public_name, "'")
		return
	var entity_property_reference_data := exposed_callables[public_name]
	exposed_callables.erase(public_name)
	entity_callable_unexposed.emit(get_entity_from(entity_property_reference_data.entity_reference), entity_property_reference_data.property_name, public_name)

func rename_exposed_callable(current_public_name: StringName, new_public_name: StringName) -> void:
	if not exposed_callables.has(current_public_name):
		push_warning("State machine has no exposed callable called '", current_public_name, "'")
		return
	var entity_property_reference_data := exposed_callables[current_public_name]
	exposed_callables.erase(current_public_name)
	exposed_callables[new_public_name] = entity_property_reference_data
	exposed_entity_callable_renamed.emit(get_entity_from(entity_property_reference_data.entity_reference), entity_property_reference_data.property_name, current_public_name, new_public_name)

func expose_signal(entity_type: EntityType, entity_name: StringName, signal_name: StringName, public_name: StringName, state_machine: SynapseStateMachine) -> void:
	if exposed_signals.has(public_name):
		push_warning("State machine already has an exposed signal called '", public_name, "'")
		return
	if not has_entity(entity_type, entity_name):
		push_warning("State machine has no ", get_entity_type_name(entity_type), " called '", entity_name, "'")
		return
	var entity := get_entity(entity_type, entity_name)
	if not entity.get_signal_infos_for_callables(state_machine).any(func(d: Dictionary) -> bool: return d["name"] == signal_name):
		push_warning(get_entity_type_name(entity_type), " '", entity_name, "' has no signal called '", signal_name, "'")
		return
	exposed_signals[public_name] = SynapseEntityPropertyReferenceData.create(SynapseEntityReferenceData.from(entity), signal_name)
	entity_signal_exposed.emit(entity, signal_name, public_name)

func unexpose_signal(public_name: StringName) -> void:
	if not exposed_signals.has(public_name):
		push_warning("State machine has no exposed signal called '", public_name, "'")
		return
	var entity_property_reference_data := exposed_signals[public_name]
	exposed_signals.erase(public_name)
	entity_signal_unexposed.emit(get_entity_from(entity_property_reference_data.entity_reference), entity_property_reference_data.property_name, public_name)

func rename_exposed_signal(current_public_name: StringName, new_public_name: StringName) -> void:
	if not exposed_signals.has(current_public_name):
		push_warning("State machine has no exposed signal called '", current_public_name, "'")
		return
	var entity_property_reference_data := exposed_signals[current_public_name]
	exposed_signals.erase(current_public_name)
	exposed_signals[new_public_name] = entity_property_reference_data
	exposed_entity_signal_renamed.emit(get_entity_from(entity_property_reference_data.entity_reference), entity_property_reference_data.property_name, current_public_name, new_public_name)

func has_existing_signal_connection(from_entity_type: EntityType, from_entity_name: StringName, from_signal_id: StringName, to_entity_type: EntityType, to_entity_name: StringName, to_callable_id: StringName) -> bool:
	var from_resource: SynapseEntityData
	match from_entity_type:
		EntityType.STATE:
			from_resource = states[from_entity_name]
		EntityType.BEHAVIOR:
			from_resource = behaviors[from_entity_name]
		EntityType.PARAMETER:
			from_resource = parameters[from_entity_name]

	match to_entity_type:
		EntityType.STATE:
			for signal_source_data: SynapseSignalSourceData in states[to_entity_name].connected_signals.get(to_callable_id, []):
				if signal_source_data.is_from(from_resource, from_signal_id):
					return true
		EntityType.BEHAVIOR:
			for signal_source_data: SynapseSignalSourceData in behaviors[to_entity_name].connected_signals.get(to_callable_id, []):
				if signal_source_data.is_from(from_resource, from_signal_id):
					return true
		EntityType.PARAMETER:
			for signal_source_data: SynapseSignalSourceData in parameters[to_entity_name].connected_signals.get(to_callable_id, []):
				if signal_source_data.is_from(from_resource, from_signal_id):
					return true
		_:
			push_error("Entity type cannot receive signals: ", get_entity_type_name(to_entity_type))
	return false

func get_all_entities() -> Array[SynapseEntityData]:
	var entities: Array[SynapseEntityData] = []
	entities.append_array(parameters.values())
	entities.append_array(behaviors.values())
	entities.append_array(states.values())
	entities.append_array(signal_bridges.values())
	return entities

func notify_parameter_reference_added(entity_data: SynapseEntityData, property_name: StringName, parameter_name: StringName, access: SynapseParameterData.Access) -> void:
	emit_changed()
	parameter_reference_added.emit(parameters[parameter_name], entity_data, property_name, access)

func notify_parameter_reference_removed(entity_data: SynapseEntityData, property_name: StringName, parameter_name: StringName, access: SynapseParameterData.Access) -> void:
	emit_changed()
	parameter_reference_removed.emit(parameters[parameter_name], entity_data, property_name, access)

static func get_entity_type_name(entity_type: EntityType) -> String:
	@warning_ignore("unsafe_cast")
	return (EntityType.find_key(entity_type) as String).to_lower()
