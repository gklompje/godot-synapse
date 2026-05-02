@tool
class_name SynapseStateGraphNode
extends SynapseStateMachineEditorGraphNode

const SLOT_PARENT := &"parent"
const SLOT_CHILDREN := &"children"
const SLOT_BEHAVIORS := &"behaviors"
const SLOT_TRANSITIONS := &"transitions"

signal state_child_order_changed(child_names: Array[StringName])
signal behavior_order_changed(behavior_names: Array[StringName])

var _child_list: SynapseEditorReorderableList
var _behavior_list: SynapseEditorReorderableList

@warning_ignore("shadowed_variable")
func setup_for(state_machine: SynapseStateMachine, data: SynapseStateData) -> void:
	title = data.get_type_name()
	@warning_ignore("unsafe_cast")
	set_icon(data.get_type_icon())
	add_name_manager(true, { "name": "name", "type": TYPE_STRING_NAME }).name_value = data.name
	add_named_slot(SLOT_PARENT, SynapseStateMachineEditor.ConnectionType.PARENT, SynapseStateMachineEditor.ConnectionType.NONE)

	var max_child_count := data.get_max_child_count()
	if max_child_count != 0:
		var child_control: Control
		if max_child_count == 1:
			child_control = create_slot_label("child", false, true)
		else:
			var foldable_container := FoldableContainer.new()
			foldable_container.title = "children"
			foldable_container.fold()
			foldable_container.folding_changed.connect(_on_foldable_container_folding_changed)
			_child_list = SynapseStateMachineEditorResourceManager.Scenes.instantiate_reorderable_list()
			_child_list.item_order_changed.connect(_on_child_list_item_order_changed)
			foldable_container.add_child(_child_list)
			child_control = foldable_container
		add_named_slot(SLOT_CHILDREN, SynapseStateMachineEditor.ConnectionType.NONE, SynapseStateMachineEditor.ConnectionType.CHILD, child_control)

	var behavior_container := FoldableContainer.new()
	behavior_container.title = "behaviors"
	behavior_container.fold()
	behavior_container.folding_changed.connect(_on_foldable_container_folding_changed)
	_behavior_list = SynapseStateMachineEditorResourceManager.Scenes.instantiate_reorderable_list()
	_behavior_list.item_order_changed.connect(_on_behavior_list_item_order_changed)
	behavior_container.add_child(_behavior_list)
	add_named_slot(SLOT_BEHAVIORS, SynapseStateMachineEditor.ConnectionType.NONE, SynapseStateMachineEditor.ConnectionType.BEHAVIOR_OUT, behavior_container)

	for signal_info in data.get_signal_infos_for_callables(state_machine):
		add_signal_emit_slot(signal_info)
	for callable_info in data.get_callable_infos_for_signals(state_machine):
		add_signal_receive_slot(callable_info)

	data.prepare_state_graph_node(state_machine, self)

	shrink_to_fit_contents()

func set_child_names(child_names: Array[StringName]) -> void:
	if _child_list:
		_child_list.clear()
		for child_name in child_names:
			_child_list.append_item(child_name)
		shrink_to_fit_contents()

func set_behavior_names(behavior_names: Array[StringName]) -> void:
	if _behavior_list:
		_behavior_list.clear()
		for behavior_name in behavior_names:
			_behavior_list.append_item(behavior_name)
		shrink_to_fit_contents()

func add_transitions_slot() -> void:
	if not has_named_slot(SLOT_TRANSITIONS):
		add_named_slot(SLOT_TRANSITIONS, SynapseStateMachineEditor.ConnectionType.TRANSITION_FROM, SynapseStateMachineEditor.ConnectionType.TRANSITION_TO)

func remove_transitions_slot() -> void:
	if has_named_slot(SLOT_TRANSITIONS):
		remove_named_slot(SLOT_TRANSITIONS)

func get_entity_type() -> SynapseStateMachineData.EntityType:
	return SynapseStateMachineData.EntityType.STATE

func _on_foldable_container_folding_changed(is_folded: bool) -> void:
	if is_folded:
		shrink_to_fit_contents()

func _on_child_list_item_order_changed(items: Array[StringName]) -> void:
	state_child_order_changed.emit(items)

func _on_behavior_list_item_order_changed(items: Array[StringName]) -> void:
	behavior_order_changed.emit(items)
