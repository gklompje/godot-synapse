@tool
class_name SynapseParameterGraphNode
extends SynapseStateMachineEditorGraphNode

signal parameter_value_set

const SLOT_ACCESS := &"access"
const SLOT_SIGNALS := &"signals"

class ParameterValueProxy:
	var state_machine: SynapseStateMachine
	var property_dict: Dictionary
	var parameter_data: SynapseParameterData

	func _init(sm: SynapseStateMachine, prop: Dictionary, data: SynapseParameterData) -> void:
		state_machine = sm
		property_dict = prop
		parameter_data = data

	func _get_property_list() -> Array[Dictionary]:
		return [property_dict]

	func _get(property: StringName) -> Variant:
		if property == &"value":
			return parameter_data.parameter.get(&"value")
		push_error("Trying to get non-value property '", property, "' from SynapseParameter '", parameter_data.name, "'")
		return null

	func _set(property: StringName, value: Variant) -> bool:
		if property == &"value":
			parameter_data.parameter.set(&"value", value)
			parameter_data.parameter.emit_changed()
			return true
		push_error("Trying to set non-value property '", property, "' on SynapseParameter '", parameter_data.name, "'")
		return false

var value_editor: EditorProperty

var _proxy: ParameterValueProxy
var _export_button: Button

func get_entity_type() -> SynapseStateMachineData.EntityType:
	return SynapseStateMachineData.EntityType.PARAMETER

func setup_for(parameter_data: SynapseParameterData, undo_redo: EditorUndoRedoManager, state_machine: SynapseStateMachine) -> void:
	@warning_ignore("unsafe_cast")
	link_script(parameter_data.parameter.get_script() as Script)

	_export_button = Button.new()
	_export_button.tooltip_text = "Toggle visibility in inspector and other state machines"
	add_title_button(_export_button)
	_export_button.pressed.connect(_on_export_button_pressed.bind(state_machine.data))
	_update_visibility_icon(parameter_data.exposed)
	state_machine.data.parameter_exposed_set.connect(_on_state_machine_data_parameter_exposed_set)

	add_name_manager().name_value = parameter_data.name

	add_signal_receive_and_emit_slot(SLOT_SIGNALS, parameter_data.get_callable_infos_for_signals(state_machine)[0], parameter_data.get_signal_infos_for_callables(state_machine)[0], "value")

	var value_property_def :=  {}
	for prop in parameter_data.parameter.get_property_list():
		if prop["name"] == &"value":
			if prop["usage"] & PROPERTY_USAGE_EDITOR:
				value_property_def = prop
			else:
				push_warning("Found property 'value' on parameter '", parameter_data.name, "', but it is not annotated with @export")
			break
	if value_property_def.is_empty():
		push_warning("No property named 'value' on parameter '", parameter_data.name, "'")
		@warning_ignore("unsafe_cast")
		title = SynapseClassUtil.get_script_class_name(parameter_data.parameter.get_script() as Script)
		add_named_slot(SLOT_ACCESS, SynapseStateMachineEditor.ConnectionType.PARAMETER_WRITER, SynapseStateMachineEditor.ConnectionType.PARAMETER_READER)
	else:
		title = SynapseClassUtil.get_property_type_string(value_property_def)
		_proxy = ParameterValueProxy.new(state_machine, value_property_def, parameter_data)
		var container := HBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var type_icon := SynapseClassUtil.get_type_icon(value_property_def)
		container.add_child(SynapseGUIUtil.get_texture_rect_for_icon(type_icon))
		value_editor = SynapseGUIUtil.get_property_editor_for(_proxy, value_property_def, false)
		value_editor.draw_label = false
		value_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(value_editor)
		container.add_child(SynapseGUIUtil.get_texture_rect_for_icon(type_icon))
		add_named_slot(SLOT_ACCESS, SynapseStateMachineEditor.ConnectionType.PARAMETER_WRITER, SynapseStateMachineEditor.ConnectionType.PARAMETER_READER, container)
		set_runtime_property_info(SLOT_ACCESS, value_property_def)
		value_editor.set_object_and_property(_proxy, &"value")
		value_editor.property_changed.connect(_on_value_changed_in_editor.bind(_proxy.get(&"value"), undo_redo, state_machine))
		value_editor.update_property()

	shrink_to_fit_contents()

func _on_value_changed_in_editor(property_name: String, new_value: Variant, _field: String, changing: bool, old_value: Variant, undo_redo: EditorUndoRedoManager, state_machine: SynapseStateMachine) -> void:
	undo_redo.create_action("Set " + get_entity_name(), UndoRedo.MERGE_ENDS if changing else UndoRedo.MERGE_DISABLE, state_machine.data)
	undo_redo.add_do_method(self, "_set_parameter_value", property_name, new_value)
	undo_redo.add_undo_method(self, "_set_parameter_value", property_name, old_value)
	undo_redo.commit_action()

func _set_parameter_value(property_name: String, value: Variant) -> void:
	_proxy.set(property_name, value)
	parameter_value_set.emit()
	value_editor.update_property()

func _on_export_button_pressed(state_machine_data: SynapseStateMachineData) -> void:
	var parameter_data := state_machine_data.parameters[get_entity_name()]
	state_machine_data.set_parameter_exposed(get_entity_name(), not parameter_data.exposed)

func _on_state_machine_data_parameter_exposed_set(parameter_data: SynapseParameterData) -> void:
	if parameter_data.name != get_entity_name():
		# not ours
		return
	_update_visibility_icon(parameter_data.exposed)

func _update_visibility_icon(exposed: bool) -> void:
	if exposed:
		_export_button.icon = SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_VISIBLE)
	else:
		_export_button.icon = SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_HIDDEN)
