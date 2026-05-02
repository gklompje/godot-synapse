@tool
class_name SynapseBehaviorGraphNode
extends SynapseStateMachineEditorGraphNode

const SLOT_OWNER_STATE := &"owner state"

var _parameter_value_defs: Dictionary[StringName, Dictionary] = {}

func setup_for(behavior_data: SynapseBehaviorData, state_machine: SynapseStateMachine) -> void:
	var behavior := state_machine.get_node(behavior_data.node_path) as SynapseBehavior
	if not behavior:
		push_error("Unable to locate behavior at ", behavior_data.node_path)
		return
	@warning_ignore("unsafe_cast")
	var script := behavior.get_script() as Script
	if behavior.scene_file_path.is_empty():
		link_script(script)
	else:
		link_scene(load(behavior.scene_file_path) as PackedScene)
	link_node(behavior, "Go to behavior node")
	title = SynapseClassUtil.call_static_method_on_script_or_base_classes(script, &"get_type_name", script)

	var name_manager := add_name_manager()
	name_manager.name_value = behavior_data.name

	for signal_def in behavior_data.get_signal_infos_for_callables(state_machine):
		add_signal_emit_slot(signal_def)
	for method_def in behavior_data.get_callable_infos_for_signals(state_machine):
		add_signal_receive_slot(method_def)

	add_named_slot(SLOT_OWNER_STATE, SynapseStateMachineEditor.ConnectionType.BEHAVIOR_IN, SynapseStateMachineEditor.ConnectionType.NONE)

	var writable_params := behavior.get_writable_parameters()
	var usage := PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_SCRIPT_VARIABLE
	var inheritance_map := SynapseClassUtil.build_inheritance_map()
	for script_property_dict: Dictionary in script.get_script_property_list():
		if script_property_dict["usage"] & usage != usage:
			continue
		@warning_ignore("unsafe_cast")
		var parameter_class_name := script_property_dict["class_name"] as StringName
		if script_property_dict["type"] == TYPE_OBJECT and SynapseClassUtil.is_assignable_from(parameter_class_name, &"SynapseParameter", inheritance_map):
			@warning_ignore("unsafe_cast")
			var variable_name := script_property_dict["name"] as StringName
			var parameter_script := SynapseClassUtil.get_script_for(parameter_class_name)
			var value_property_dict: Dictionary
			for parameter_property_dict in parameter_script.get_script_property_list():
				if parameter_property_dict["name"] == &"value":
					value_property_dict = parameter_property_dict
					add_parameter_slot(variable_name, value_property_dict, writable_params.has(variable_name))
					_parameter_value_defs[variable_name] = value_property_dict
					break

	shrink_to_fit_contents()

func get_parameter_value_info(slot_name: StringName) -> Dictionary:
	return _parameter_value_defs.get(slot_name, {})

func get_entity_type() -> SynapseStateMachineData.EntityType:
	return SynapseStateMachineData.EntityType.BEHAVIOR
