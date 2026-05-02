@tool
class_name SynapseRootSentinelGraphNode
extends SynapseStateMachineEditorGraphNode

const SLOT_ROOT_STATE := &"root_state"
const SLOT_EXPOSE_SIGNAL_OR_CALLABLE := &"__expose_signal_or_callable"
const SIGNAL_SLOT_PREFIX := "s::"
const CALLABLE_SLOT_PREFIX := "c::"

signal exposed_callable_rename_requested(previous_public_name: StringName, new_public_name: StringName)
signal exposed_signal_rename_requested(previous_public_name: StringName, new_public_name: StringName)

var _expose_signal_or_callable_slot_control: Control

func setup_for(state_machine: SynapseStateMachine) -> void:
	set_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.STATE_ROOT))
	# can be called during teardown, when the state machine is already gone
	if not is_instance_valid(state_machine):
		title = "(No State Machine)"
		position_offset = Vector2.ZERO
		return

	title = state_machine.name
	if state_machine.data:
		position_offset = state_machine.data.root_pos
	state_machine.renamed.connect(_on_state_machine_renamed.bind(state_machine))

	recreate_slots(state_machine)

func recreate_slots(state_machine: SynapseStateMachine) -> void:
	clear_slots()
	add_named_slot(SLOT_ROOT_STATE, SynapseStateMachineEditor.ConnectionType.NONE, SynapseStateMachineEditor.ConnectionType.CHILD, create_slot_label("root state", false, true))
	var ordered_signals: Array[StringName] = []
	ordered_signals.append_array(state_machine.data.exposed_signals.keys())
	ordered_signals.sort_custom(func(s1: StringName, s2: StringName) -> bool: return s1.naturalcasecmp_to(s2) < 0)
	for public_name in ordered_signals:
		_add_exposed_signal_port_slot(public_name)
	var ordered_callables: Array[StringName] = []
	ordered_callables.append_array(state_machine.data.exposed_callables.keys())
	ordered_callables.sort_custom(func(s1: StringName, s2: StringName) -> bool: return s1.naturalcasecmp_to(s2) < 0)
	for public_name in ordered_callables:
		_add_exposed_callable_port_slot(public_name)
	_add_expose_slot()
	shrink_to_fit_contents()

func _add_expose_slot() -> void:
	_expose_signal_or_callable_slot_control = HBoxContainer.new()
	_expose_signal_or_callable_slot_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expose_signal_or_callable_slot_control.add_child(SynapseGUIUtil.get_texture_rect_for_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_SIGNAL)))
	var center_icon := SynapseGUIUtil.get_texture_rect_for_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_VISIBLE))
	center_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expose_signal_or_callable_slot_control.add_child(center_icon)
	_expose_signal_or_callable_slot_control.add_child(SynapseGUIUtil.get_texture_rect_for_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_METHOD)))
	add_named_slot(SLOT_EXPOSE_SIGNAL_OR_CALLABLE, SynapseStateMachineEditor.ConnectionType.EXPOSE_SIGNAL, SynapseStateMachineEditor.ConnectionType.EXPOSE_CALLABLE, _expose_signal_or_callable_slot_control)

func get_entity_type() -> SynapseStateMachineData.EntityType:
	return SynapseStateMachineData.EntityType.STATE

func _on_state_machine_renamed(state_machine: SynapseStateMachine) -> void:
	title = state_machine.name

func get_slot_name_for_exposed_callable(public_name: StringName) -> StringName:
	return CALLABLE_SLOT_PREFIX + public_name

func _add_exposed_callable_port_slot(public_name: StringName) -> void:
	var slot_name := get_slot_name_for_exposed_callable(public_name)
	var container := HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_manager := SynapseStateMachineEditorResourceManager.Scenes.instantiate_graph_node_name_manager()
	name_manager.editable = true
	name_manager.name_value = public_name
	container.add_child(SynapseGUIUtil.get_texture_rect_for_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_METHOD)))
	container.add_child(name_manager)
	add_named_slot(slot_name, SynapseStateMachineEditor.ConnectionType.NONE, SynapseStateMachineEditor.ConnectionType.EXPOSE_CALLABLE, container)
	name_manager.update_requested.connect(func(new_name: StringName) -> void: exposed_callable_rename_requested.emit(public_name, new_name))

func get_slot_name_for_exposed_signal(public_name: StringName) -> StringName:
	return SIGNAL_SLOT_PREFIX + public_name

func _add_exposed_signal_port_slot(public_name: StringName) -> void:
	var slot_name := get_slot_name_for_exposed_signal(public_name)
	var container := HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_manager := SynapseStateMachineEditorResourceManager.Scenes.instantiate_graph_node_name_manager()
	name_manager.editable = true
	name_manager.name_value = public_name
	name_manager.update_requested.connect(func(new_name: StringName) -> void: exposed_signal_rename_requested.emit(public_name, new_name))
	container.add_child(name_manager)
	container.add_child(SynapseGUIUtil.get_texture_rect_for_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_SIGNAL)))
	add_named_slot(slot_name, SynapseStateMachineEditor.ConnectionType.EXPOSE_SIGNAL, SynapseStateMachineEditor.ConnectionType.NONE, container)
