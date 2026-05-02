@tool
class_name SynapseBehaviorData
extends SynapseEntityData

@export_storage var owner_state_name: StringName
@export_storage var managed: bool
@export_storage var node_path: NodePath
@export_storage var parameters: Dictionary[StringName, StringName] # property name : parameter name

func _to_string() -> String:
	return "{ %s (%s): owner=%s, node_path=%s, parameters=%s, graph_pos=%v }" % [name, "managed" if managed else "linked", owner_state_name, node_path, parameters, graph_pos]

@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
static func create_from_script(name: StringName, script: Script, graph_pos: Vector2, state_machine: SynapseStateMachine) -> SynapseBehaviorData:
	if not script is GDScript:
		push_error("Unable to instantiate behavior from non-GDScript script")
		return null
	@warning_ignore("unsafe_cast")
	var behavior := (script as GDScript).new() as SynapseBehavior
	if not behavior:
		push_error("Script is not a behavior")
		return null
	behavior.name = name
	behavior.set_script(script)
	state_machine.add_child(behavior)
	behavior.owner = state_machine.owner
	var behavior_data := create_from_existing_node(name, behavior, graph_pos, state_machine)
	behavior_data.managed = true
	return behavior_data

@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
static func create_from_existing_node(name: StringName, behavior: SynapseBehavior, graph_pos: Vector2, state_machine: SynapseStateMachine) -> SynapseBehaviorData:
	if behavior.state_machine:
		push_error("SynapseBehavior already linked to state machine: ", behavior.state_machine)
	var behavior_data := SynapseBehaviorData.new()
	behavior_data.name = name
	behavior_data.graph_pos = graph_pos
	behavior_data.node_path = state_machine.get_path_to(behavior)
	return behavior_data

func get_configuration_warnings(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	if not owner_state_name:
		warnings.append({ ConfigurationWarningKey.TEXT: "No owner state" })

	var behavior := state_machine.get_node_or_null(node_path) as SynapseBehavior
	if behavior:
		if not behavior.state_machine:
			warnings.append({ ConfigurationWarningKey.TEXT: "Not linked to a state machine" })
		elif not is_same(state_machine, behavior.state_machine):
			warnings.append({ ConfigurationWarningKey.TEXT: "Behavior node owned by different state machine" })
		elif not Engine.is_editor_hint() and not behavior.owner_state:
			warnings.append({ ConfigurationWarningKey.TEXT: "Not owned by any state in state machine '" + state_machine.name + "'" })
		var parameter_names := behavior.get_parameters()
		for property_name in behavior.get_required_properties():
			if parameter_names.has(property_name):
				# parameter
				if not parameters.has(property_name):
					warnings.append({ ConfigurationWarningKey.TEXT: "Parameter '" + property_name + "' is required" })
			else:
				# property
				if SynapseClassUtil.is_value_empty(behavior.get(property_name)):
					warnings.append({ ConfigurationWarningKey.TEXT: "Property '" + property_name + "' is required" })

		var injected_warnings: Array[String] = []
		for warning in warnings:
			@warning_ignore("unsafe_cast")
			injected_warnings.append(warning[ConfigurationWarningKey.TEXT] as String)

		# get any custom configuration warnings, but first clear our previously injected ones
		behavior.set_data_configuration_warnings([])
		for warning in behavior._get_configuration_warnings():
			warnings.append({ ConfigurationWarningKey.TEXT: warning })
		behavior.set_data_configuration_warnings(injected_warnings)
	else:
		warnings.append({ ConfigurationWarningKey.TEXT: "No behavior found at path: " + str(node_path) })

	return warnings

func get_callable_infos_for_signals(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	var infos: Array[Dictionary] = []
	var behavior := state_machine.get_node(node_path) as SynapseBehavior
	for signal_relay in behavior.get_signal_relays():
		if signal_relay is SynapseBehavior.SignalRelayConnector:
			var signal_relay_name := (signal_relay as SynapseBehavior.SignalRelayConnector).get_name()
			var method_def: Dictionary = {}
			for m in signal_relay._callable.get_object().get_method_list():
				if m["name"] == signal_relay._callable.get_method():
					method_def.merge(m)
					break
			if method_def.is_empty():
				push_error("Unable to find definition of callable for signal relay connector '", signal_relay_name, "': ", signal_relay._callable)
				continue
			method_def["name"] = signal_relay_name # the callable method name is just whatever method it's referencing, but at runtime we need to look up the signal relay
			infos.append(method_def)
	return infos

func get_signal_infos_for_callables(state_machine: SynapseStateMachine) -> Array[Dictionary]:
	var behavior := state_machine.get_node(node_path) as SynapseBehavior
	var infos: Array[Dictionary]
	var visible_signals := behavior._get_visible_signals()
	if visible_signals.size() > 0:
		for s in behavior.get_signal_list():
			if visible_signals.any(func(sig: Signal) -> bool: return sig.get_name() == s["name"]):
				infos.append(s)
	return infos

func _get_parameter_access(property_name: StringName, state_machine: SynapseStateMachine) -> SynapseParameterData.Access:
	var behavior := state_machine.get_node(node_path) as SynapseBehavior
	if behavior._get_read_only_parameters().has(property_name):
		return SynapseParameterData.Access.RO
	else:
		return SynapseParameterData.Access.RW

func _assign_parameter(property_name: StringName, parameter_name: StringName, state_machine: SynapseStateMachine) -> void:
	parameters[property_name] = parameter_name
	state_machine.data.notify_parameter_reference_added(self, property_name, parameter_name, _get_parameter_access(property_name, state_machine))

func _release_parameter(property_name: StringName, state_machine: SynapseStateMachine) -> void:
	var parameter_name := parameters[property_name]
	parameters.erase(property_name)
	state_machine.data.notify_parameter_reference_removed(self, property_name, parameter_name, _get_parameter_access(property_name, state_machine))

func can_reference_parameter(parameter_data: SynapseParameterData, property_name: StringName, state_machine: SynapseStateMachine) -> bool:
	if parameters.get(property_name, &"") == parameter_data.name:
		# already assigned
		return false
	var behavior := state_machine.get_node(node_path) as SynapseBehavior
	if not behavior.get_parameters().has(property_name):
		return false
	@warning_ignore("unsafe_cast")
	var property_type := SynapseClassUtil.get_script_property_class_name(behavior.get_script() as Script, property_name)
	@warning_ignore("unsafe_cast")
	return SynapseClassUtil.script_inherits_class_name(parameter_data.parameter.get_script() as Script, property_type)

func reference_parameter_undoable(parameter_data: SynapseParameterData, property_name: StringName, editor: SynapseStateMachineEditor) -> SynapseParameterData.Access:
	if parameters.has(property_name):
		editor.undo_redo.add_do_method(self, "_release_parameter", property_name, editor.state_machine)
	editor.undo_redo.add_do_method(self, "_assign_parameter", property_name, parameter_data.name, editor.state_machine)
	editor.undo_redo.add_undo_method(self, "_release_parameter", property_name, editor.state_machine)
	if parameters.has(property_name):
		editor.undo_redo.add_undo_method(self, "_assign_parameter", property_name, parameters[property_name], editor.state_machine)
	return _get_parameter_access(property_name, editor.state_machine)

func release_parameter_undoable(parameter_data: SynapseParameterData, property_name: StringName, editor: SynapseStateMachineEditor) -> void:
	editor.undo_redo.add_do_method(self, "_release_parameter", property_name, editor.state_machine)
	editor.undo_redo.add_undo_method(self, "_assign_parameter", property_name, parameter_data.name, editor.state_machine)

func get_parameter_references(state_machine: SynapseStateMachine) -> Array[SynapseParameterReferenceData]:
	var references: Array[SynapseParameterReferenceData] = []
	var behavior := state_machine.get_node(node_path) as SynapseBehavior
	var ro_property_names := behavior._get_read_only_parameters()
	for property_name in parameters:
		if ro_property_names.has(property_name):
			references.append(SynapseParameterReferenceData.create(property_name, parameters[property_name], SynapseParameterData.Access.RO))
		else:
			references.append(SynapseParameterReferenceData.create(property_name, parameters[property_name], SynapseParameterData.Access.RW))
	return references

func notify_entity_renamed(entity_data: SynapseEntityData, previous_name: StringName) -> void:
	if entity_data is SynapseParameterData:
		for property_name: StringName in parameters.keys():
			if parameters[property_name] == previous_name:
				parameters[property_name] = entity_data.name

func create_signal_data(signal_name: StringName, state_machine: SynapseStateMachine) -> SynapseSignalData:
	var behavior := state_machine.get_node(node_path) as SynapseBehavior
	for sig in behavior._get_visible_signals():
		if sig.get_name() == signal_name and is_same(sig.get_object(), behavior):
			return SynapseNodeMethodSignalData.of(node_path, sig.get_name())
	return null

func create_callable_data(callable_name: StringName, _state_machine: SynapseStateMachine) -> SynapseCallableData:
	return SynapseBehaviorSignalRelayConnectorCallableData.of(name, callable_name)
