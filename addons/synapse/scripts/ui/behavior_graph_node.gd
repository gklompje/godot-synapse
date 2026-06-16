@tool
class_name SynapseBehaviorGraphNode
extends SynapseStateMachineEditorGraphNode

const SLOT_OWNER_STATE := &"owner state"

var _execution_mode_button: OptionButton
var _link_button: Button
var _parameter_value_defs: Dictionary[StringName, Dictionary] = {}

func setup_for(behavior_data: SynapseBehaviorData, state_machine: SynapseStateMachine) -> void:
	var behavior := state_machine.get_node(behavior_data.node_path) as SynapseBehavior
	if not behavior:
		push_error("Unable to locate behavior at ", behavior_data.node_path)
		return

	@warning_ignore("unsafe_cast")
	var script := behavior.get_script() as Script
	if behavior.scene_file_path.is_empty():
		_link_button = link_script(script)
	else:
		_link_button = link_scene(load(behavior.scene_file_path) as PackedScene)

	state_machine.property_list_changed.connect(_sync_execution_mode_button.bind(state_machine, behavior))
	_sync_execution_mode_button(state_machine, behavior)
	EditorInterface.get_inspector().property_edited.connect(_on_inspector_property_edited.bind(behavior))

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

func _on_execution_mode_selected(mode: SynapseBehavior.MultiplayerExecutionMode, behavior: SynapseBehavior) -> void:
	# TODO: undo/redo
	behavior.multiplayer_execution_mode = mode
	if is_same(EditorInterface.get_inspector().get_edited_object(), behavior):
		behavior.notify_property_list_changed()
		EditorInterface.inspect_object(behavior)

func _on_inspector_property_edited(property_name: String, behavior: SynapseBehavior) -> void:
	if property_name != "multiplayer_execution_mode":
		return

	if not is_same(EditorInterface.get_inspector().get_edited_object(), behavior):
		return

	if _execution_mode_button:
		_execution_mode_button.selected = _execution_mode_button.get_item_index(behavior.multiplayer_execution_mode)

func _sync_execution_mode_button(state_machine: SynapseStateMachine, behavior: SynapseBehavior) -> void:
	if state_machine.multiplayer_mode == SynapseStateMachine.MultiplayerMode.DISABLED:
		if _execution_mode_button:
			remove_title_button(_execution_mode_button)
			_execution_mode_button.queue_free()
			_execution_mode_button = null
	elif not _execution_mode_button:
		_execution_mode_button = OptionButton.new()
		_execution_mode_button.text = "Execution mode"
		_execution_mode_button.tooltip_text = "Determines if/how this behavior is enabled across network peers."
		_execution_mode_button.add_icon_item(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.BEHAVIOR_EXECUTION_EVERYONE), "", SynapseBehavior.MultiplayerExecutionMode.EVERYONE)
		_execution_mode_button.set_item_tooltip(_execution_mode_button.get_item_index(SynapseBehavior.MultiplayerExecutionMode.EVERYONE), "Executes on all peers.")
		_execution_mode_button.add_icon_item(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.BEHAVIOR_EXECUTION_AUTHORITY_ONLY), "", SynapseBehavior.MultiplayerExecutionMode.AUTHORITY_ONLY)
		_execution_mode_button.set_item_tooltip(_execution_mode_button.get_item_index(SynapseBehavior.MultiplayerExecutionMode.AUTHORITY_ONLY), "Executes only on the peer that is the multiplayer authority for the owning state machine.")
		_execution_mode_button.add_icon_item(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.BEHAVIOR_EXECUTION_NON_AUTH_ONLY), "", SynapseBehavior.MultiplayerExecutionMode.NON_AUTH_ONLY)
		_execution_mode_button.set_item_tooltip(_execution_mode_button.get_item_index(SynapseBehavior.MultiplayerExecutionMode.NON_AUTH_ONLY), "Executes only on peers that are *not* the multiplayer authority for the owning state machine.")
		_execution_mode_button.add_icon_item(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.BEHAVIOR_EXECUTION_SERVER_ONLY), "", SynapseBehavior.MultiplayerExecutionMode.SERVER_ONLY)
		_execution_mode_button.set_item_tooltip(_execution_mode_button.get_item_index(SynapseBehavior.MultiplayerExecutionMode.SERVER_ONLY), "Executes only on the server.")
		_execution_mode_button.add_icon_item(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.BEHAVIOR_EXECUTION_CLIENTS_ONLY), "", SynapseBehavior.MultiplayerExecutionMode.CLIENTS_ONLY)
		_execution_mode_button.set_item_tooltip(_execution_mode_button.get_item_index(SynapseBehavior.MultiplayerExecutionMode.CLIENTS_ONLY), "Executes only on clients (non-server peers).")
		_execution_mode_button.add_icon_item(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.BEHAVIOR_EXECUTION_PROXIES_ONLY), "", SynapseBehavior.MultiplayerExecutionMode.PROXIES_ONLY)
		_execution_mode_button.set_item_tooltip(_execution_mode_button.get_item_index(SynapseBehavior.MultiplayerExecutionMode.PROXIES_ONLY), "Executes only on clients (non-server peers) that are *not* the multiplayer authority for the owning state machine.")
		add_title_button(_execution_mode_button)
		_execution_mode_button.selected = _execution_mode_button.get_item_index(behavior.multiplayer_execution_mode)
		_execution_mode_button.item_selected.connect(_on_execution_mode_selected.bind(behavior))
