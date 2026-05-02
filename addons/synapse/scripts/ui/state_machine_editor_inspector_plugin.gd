@tool
class_name SynapseStateMachineEditorInspectorPlugin
extends EditorInspectorPlugin

const PARAMETER_GROUP := &"Parameters"
const PARAMETER_GROUP_SENTINEL := &"_behavior_parameter_sentinel_for_state_machine_inspector_plugin"

signal parameter_value_set(parameter_name: StringName)

var undo_redo: EditorUndoRedoManager

@warning_ignore("shadowed_variable")
func _init(undo_redo: EditorUndoRedoManager) -> void:
	self.undo_redo = undo_redo

func _can_handle(object: Object) -> bool:
	return object is SynapseStateMachine or object is SynapseBehavior

func _parse_begin(object: Object) -> void:
	var inspector := EditorInterface.get_inspector()
	if object is SynapseBehavior:
		var behavior := object as SynapseBehavior
		if behavior.state_machine:
			if not inspector.property_edited.is_connected(_on_behavior_property_edited):
				inspector.property_edited.connect(_on_behavior_property_edited)

func _on_behavior_property_edited(_property: String) -> void:
	var inspector := EditorInterface.get_inspector()
	var object := inspector.get_edited_object()
	if object is SynapseBehavior:
		var behavior := object as SynapseBehavior
		if behavior.state_machine:
			behavior.state_machine.update_configuration_warnings()
			return
	# if we got here, we couldn't update the state machine warnings- no point triggering again
	inspector.property_edited.disconnect(_on_behavior_property_edited)

func _parse_group(object: Object, group: String) -> void:
	if group != PARAMETER_GROUP:
		return

	if object is SynapseStateMachine:
		var state_machine := object as SynapseStateMachine
		if not state_machine.data:
			return
		parse_state_machine(state_machine)

func parse_state_machine(state_machine: SynapseStateMachine) -> void:
	var container := VBoxContainer.new()
	for parameter_name in state_machine.data.parameters:
		var parameter_data := state_machine.data.parameters[parameter_name]
		if parameter_data.exposed:
			parse_parameter(parameter_data, state_machine, container)
	if container.get_child_count() > 0:
		add_custom_control(container)
	else:
		var no_parameters_label := Label.new()
		no_parameters_label.text = "No visible parameters (toggle in graph)"
		add_custom_control(no_parameters_label)

func parse_parameter(parameter_data: SynapseParameterData, state_machine: SynapseStateMachine, container: Container) -> void:
	var found_value := false
	for prop in parameter_data.parameter.get_property_list():
		if prop["name"] == &"value":
			found_value = true
			if not prop["usage"] & PROPERTY_USAGE_EDITOR:
				push_warning("Found property 'value' on parameter '", parameter_data.name, "', but it is not annotated with @export")
				break
			var value_editor := SynapseGUIUtil.get_property_editor_for(parameter_data, prop)
			value_editor.label = SynapseGUIUtil.nameify(parameter_data.name)
			value_editor.size_flags_horizontal = Control.SIZE_FILL
			# adding the property editor directly to this plugin messes up the property mapping, because
			# the inspector seems dead set on associating it with the selected node (the state machine)
			# the intermediate container serves to break that relationship
			container.add_child(value_editor)
			value_editor.set_object_and_property(parameter_data, &"value")
			value_editor.property_changed.connect(_on_value_changed_in_editor.bind(parameter_data, state_machine, value_editor))
			value_editor.update_property()
			break
	if not found_value:
		push_warning("No property named 'value' on parameter '", parameter_data.name, "'")

func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	# hide the sentinel property by marking it as parsed
	if name == PARAMETER_GROUP_SENTINEL:
		return true

	if object is SynapseBehavior:
		for prop in object.get_property_list():
			@warning_ignore("unsafe_cast")
			var cls := prop["class_name"] as String
			if prop["name"] == name and prop["type"] == TYPE_OBJECT and not cls.is_empty() and SynapseClassUtil.is_assignable_from(cls, &"SynapseParameter"):
				var value_editor := SynapseGUIUtil.ReadOnlyPropertyEditor.new(name, "(parameter)", "Parameters can only be assigned in the state machine editor.")
				add_property_editor(name, value_editor)
				return true

	return false

func _on_value_changed_in_editor(_property_name: String, new_value: Variant, _field: String, changing: bool, parameter_data: SynapseParameterData, state_machine: SynapseStateMachine, value_editor: EditorProperty) -> void:
	undo_redo.create_action("Set " + parameter_data.name, UndoRedo.MERGE_ENDS if changing else UndoRedo.MERGE_DISABLE, state_machine.data)
	undo_redo.add_do_method(self, "_set_parameter_value", parameter_data, new_value, value_editor)
	undo_redo.add_undo_method(self, "_set_parameter_value", parameter_data, parameter_data.parameter.get(&"value"), value_editor)
	undo_redo.commit_action()

func _set_parameter_value(parameter_data: SynapseParameterData, value: Variant, value_editor: EditorProperty) -> void:
	parameter_data.parameter.set(&"value", value)
	parameter_value_set.emit(parameter_data.name)
	value_editor.update_property()
