@tool
class_name SynapseSignalBridgeGraphNode
extends SynapseStateMachineEditorGraphNode

const SLOT_BRIDGE := &"bridge"

const _UNBOUND := &"(unbound)"

signal signal_argument_wired(signal_argument_name: StringName, callable_argument_name: StringName)
signal signal_argument_unwired(callable_argument_name: StringName)

var _arg_slot_infos: Dictionary[StringName, Dictionary] = {} # slot_name : property_info

func get_entity_type() -> SynapseStateMachineData.EntityType:
	return SynapseStateMachineData.EntityType.SIGNAL_BRIDGE

func can_receive_signals() -> bool:
	# signal connections are hard-wired 1:1 based on the source and target
	return false

func setup_for(signal_bridge_data: SynapseSignalBridgeData, source_signal_info: Dictionary, target_callable_info: Dictionary) -> void:
	title = "Signal Bridge"
	set_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.SIGNAL_BRIDGE))
	set_entity_name(signal_bridge_data.name)
	var container := HBoxContainer.new()
	container.add_child(SynapseGUIUtil.get_texture_rect_for_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_METHOD)))
	var label := Label.new()
	label.text = "→"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(label)
	container.add_child(SynapseGUIUtil.get_texture_rect_for_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_SIGNAL)))
	add_named_slot(SLOT_BRIDGE, SynapseStateMachineEditor.ConnectionType.SIGNAL_IN, SynapseStateMachineEditor.ConnectionType.SIGNAL_OUT, container)

	@warning_ignore("unsafe_cast")
	var args := target_callable_info["args"] as Array
	@warning_ignore("unsafe_cast")
	var default_args := target_callable_info["default_args"] as Array
	var required_args := args.slice(0, args.size() - default_args.size())
	for arg: Dictionary in required_args:
		_add_arg_slot(arg, source_signal_info)
	for i in range(required_args.size(), args.size()):
		@warning_ignore("unsafe_cast")
		_add_arg_slot(args[i] as Dictionary, source_signal_info, true, default_args[i - required_args.size()])

	shrink_to_fit_contents()

func get_argument_info(slot_name: StringName) -> Dictionary:
	return _arg_slot_infos[slot_name]

func get_slot_name_for_callable_argument_name(callable_argument_name: StringName) -> StringName:
	for slot_name in _arg_slot_infos:
		if _arg_slot_infos[slot_name]["name"] == callable_argument_name:
			return slot_name
	push_warning("Can't find slot matching callable argument named '", callable_argument_name, "'")
	return &""

func notify_property_reference_assigned(slot_name: StringName) -> void:
	(get_child(get_slot_number(slot_name)) as SynapseSignalBridgeArgument).hide_argument_options()
	shrink_to_fit_contents()

func notify_property_reference_unassigned(slot_name: StringName) -> void:
	(get_child(get_slot_number(slot_name)) as SynapseSignalBridgeArgument).show_argument_options()

func notify_signal_argument_wired(slot_name: StringName, signal_arg_name: StringName) -> void:
	var slot_number := get_slot_number(slot_name)
	(get_child(slot_number) as SynapseSignalBridgeArgument).select_argument(signal_arg_name)
	set_slot_enabled_left(slot_number, false)

func notify_signal_argument_unwired(slot_name: StringName) -> void:
	var slot_number := get_slot_number(slot_name)
	(get_child(slot_number) as SynapseSignalBridgeArgument).select_argument(_UNBOUND)
	set_slot_enabled_left(slot_number, true)

func _add_arg_slot(arg_info: Dictionary, source_signal_info: Dictionary, has_default: bool = false, default_value: Variant = null) -> void:
	@warning_ignore("unsafe_cast")
	var arg_name := arg_info["name"] as String
	var control := SynapseStateMachineEditorResourceManager.Scenes.instantiate_signal_bridge_argument()
	add_named_slot(arg_name, SynapseStateMachineEditor.ConnectionType.PROPERTY_REFERENCE_IN, SynapseStateMachineEditor.ConnectionType.NONE, control)
	control.set_property_def(arg_info, has_default, default_value)
	var compatible_signal_args: Array[StringName] = [_UNBOUND]
	for signal_arg: Dictionary in source_signal_info["args"]:
		if SynapseClassUtil.is_argument_compatible(signal_arg, arg_info):
			compatible_signal_args.append(signal_arg["name"])
	if compatible_signal_args.size() > 1:
		control.set_argument_options(compatible_signal_args)
		control.argument_selected.connect(_on_argument_selected.bind(arg_name))
	else:
		control.hide_argument_options()
	_arg_slot_infos[arg_name] = arg_info

func _on_argument_selected(signal_arg_name: StringName, callable_arg_name: StringName) -> void:
	if signal_arg_name == _UNBOUND:
		signal_argument_unwired.emit(callable_arg_name)
	else:
		signal_argument_wired.emit(signal_arg_name, callable_arg_name)
