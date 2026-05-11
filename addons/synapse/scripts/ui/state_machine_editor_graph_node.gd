@tool
@abstract
class_name SynapseStateMachineEditorGraphNode
extends GraphNode

const SLOT_NAME_MANAGER := &"__entity_name_manager"
const SLOT_PREFIX_CALLABLE := "c::"
const SLOT_PREFIX_SIGNAL := "s::"

signal name_update_requested(new_name: StringName)
signal slots_updated

var _entity_name := &""
var _icon: TextureRect
var _slot_controls: Dictionary[StringName, Control] = {}
var _emitted_signal_infos: Dictionary[StringName, Dictionary]
var _received_signal_callable_infos: Dictionary[StringName, Dictionary]
var _runtime_property_infos: Dictionary[StringName, Dictionary]
var _node_link_button: Button

const PORT_COLORS: Dictionary[SynapseStateMachineEditor.ConnectionType, Color] = {
	SynapseStateMachineEditor.ConnectionType.NONE: Color.WHITE,
	SynapseStateMachineEditor.ConnectionType.PARENT: Color.BLUE,
	SynapseStateMachineEditor.ConnectionType.CHILD: Color.DARK_BLUE,
	SynapseStateMachineEditor.ConnectionType.TRANSITION_TO: Color.DEEP_SKY_BLUE,
	SynapseStateMachineEditor.ConnectionType.TRANSITION_FROM: Color.SKY_BLUE,
	SynapseStateMachineEditor.ConnectionType.BEHAVIOR_OUT: Color.DARK_MAGENTA,
	SynapseStateMachineEditor.ConnectionType.BEHAVIOR_IN: Color.MAGENTA,
	SynapseStateMachineEditor.ConnectionType.PARAMETER_RO: Color.LIGHT_YELLOW,
	SynapseStateMachineEditor.ConnectionType.PARAMETER_RW: Color.RED,
	SynapseStateMachineEditor.ConnectionType.PARAMETER_READER: Color.YELLOW,
	SynapseStateMachineEditor.ConnectionType.PARAMETER_WRITER: Color.ORANGE_RED,
	SynapseStateMachineEditor.ConnectionType.SIGNAL_OUT: Color.GREEN,
	SynapseStateMachineEditor.ConnectionType.SIGNAL_IN: Color.GREEN_YELLOW,
	SynapseStateMachineEditor.ConnectionType.PROPERTY_REFERENCE_OUT: Color.YELLOW,
	SynapseStateMachineEditor.ConnectionType.PROPERTY_REFERENCE_IN: Color.LIGHT_YELLOW,
	SynapseStateMachineEditor.ConnectionType.EXPOSE_CALLABLE: Color.GREEN,
	SynapseStateMachineEditor.ConnectionType.EXPOSE_SIGNAL: Color.GREEN_YELLOW,
}

func clear_slots() -> void:
	for slot_name: StringName in _slot_controls:
		remove_child(_slot_controls[slot_name])
		_slot_controls[slot_name].queue_free()
	_slot_controls.clear()
	_emitted_signal_infos.clear()
	_received_signal_callable_infos.clear()
	_runtime_property_infos.clear()
	slots_updated.emit()

func link_scene(scene: PackedScene) -> void:
	var script := SynapseClassUtil.get_root_script(scene)
	var edit_script_button := Button.new()
	edit_script_button.icon = get_theme_icon(&"PackedScene", &"EditorIcons")
	edit_script_button.tooltip_text = "Open Scene: " + scene.resource_path
	edit_script_button.pressed.connect(func() -> void:
		EditorInterface.edit_script(script)
		EditorInterface.set_main_screen_editor("Script")
		EditorInterface.open_scene_from_path(scene.resource_path)
	)
	get_titlebar_hbox().add_child(edit_script_button)
	set_icon(SynapseClassUtil.get_script_icon(script))

func link_script(script: Script) -> void:
	var edit_script_button := Button.new()
	edit_script_button.icon = get_theme_icon(&"Script", &"EditorIcons")
	edit_script_button.tooltip_text = "Open Script: " + script.resource_path
	if script.is_tool():
		edit_script_button.self_modulate = get_theme_color(&"accent_color", &"Editor")
	edit_script_button.pressed.connect(func() -> void:
		EditorInterface.edit_script(script)
		EditorInterface.set_main_screen_editor("Script")
	)
	get_titlebar_hbox().add_child(edit_script_button)
	set_icon(SynapseClassUtil.get_script_icon(script))

func link_node(node: Node, tooltip: String) -> void:
	if _node_link_button:
		_node_link_button.queue_free()
	_node_link_button = Button.new()
	_node_link_button.flat = true
	_node_link_button.icon = SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_EXTERNAL_LINK)
	_node_link_button.tooltip_text = tooltip
	_node_link_button.pressed.connect(SynapseGUIUtil.select_node_in_editor.bind(node))
	add_title_button(_node_link_button)

func set_icon(icon_texture: Texture2D) -> void:
	if _icon:
		_icon.queue_free()
		_icon = null
	if icon_texture:
		_icon = SynapseGUIUtil.get_texture_rect_for_icon(icon_texture)
		get_titlebar_hbox().add_child(_icon)
		get_titlebar_hbox().move_child(_icon, 0)

func add_title_button(button: Button) -> void:
	get_titlebar_hbox().add_child(button)

func has_named_slot(slot_name: StringName) -> bool:
	return _slot_controls.has(slot_name)

func get_slot_number(slot_name: StringName) -> int:
	return _slot_controls[slot_name].get_index()

func create_slot_label(text: String, has_input: bool, has_output: bool) -> Label:
	var label := Label.new()
	label.name = text
	label.text = text

	if has_input == has_output:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif has_input:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	elif has_output:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return label

func add_parameter_slot(variable_name: StringName, value_property_dict: Dictionary, writable: bool = false) -> void:
	var container := HBoxContainer.new()
	var type_icon := SynapseGUIUtil.get_texture_rect_for_icon(SynapseClassUtil.get_type_icon(value_property_dict))
	if writable:
		container.add_child(create_slot_label(variable_name, false, true))
		container.add_child(type_icon)
		add_named_slot(variable_name, SynapseStateMachineEditor.ConnectionType.NONE, SynapseStateMachineEditor.ConnectionType.PARAMETER_RW, container)
	else:
		container.add_child(type_icon)
		container.add_child(create_slot_label(variable_name, true, false))
		add_named_slot(variable_name, SynapseStateMachineEditor.ConnectionType.PARAMETER_RO, SynapseStateMachineEditor.ConnectionType.NONE, container)

func add_signal_emit_slot(signal_info: Dictionary) -> void:
	@warning_ignore("unsafe_cast")
	var signal_name := signal_info["name"] as String
	var slot_name := SLOT_PREFIX_SIGNAL + signal_name
	var container := HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(create_slot_label(signal_name, false, true))
	container.add_child(SynapseGUIUtil.get_texture_rect_for_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_SIGNAL)))
	add_named_slot(slot_name, SynapseStateMachineEditor.ConnectionType.NONE, SynapseStateMachineEditor.ConnectionType.SIGNAL_OUT, container)
	_emitted_signal_infos[slot_name] = signal_info

func get_emitted_signal_info(slot_name: StringName) -> Dictionary:
	return _emitted_signal_infos.get(slot_name, {})

func get_slot_name_for_emitted_signal_name(signal_name: StringName) -> StringName:
	for slot_name in _emitted_signal_infos:
		if _emitted_signal_infos[slot_name]["name"] == signal_name:
			return slot_name
	push_warning("No slot found for emitted signal name '", signal_name, "'")
	return &""

func can_receive_signals() -> bool:
	return true

func get_signal_receive_slot_callable_info(slot_name: StringName) -> Dictionary:
	return _received_signal_callable_infos.get(slot_name, {})

func add_signal_receive_slot(callable_info: Dictionary) -> void:
	@warning_ignore("unsafe_cast")
	var callable_name := callable_info["name"] as String
	var slot_name := SLOT_PREFIX_CALLABLE + callable_name
	var container := HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(SynapseGUIUtil.get_texture_rect_for_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_METHOD)))
	container.add_child(create_slot_label(callable_name, true, false))
	add_named_slot(slot_name, SynapseStateMachineEditor.ConnectionType.SIGNAL_IN, SynapseStateMachineEditor.ConnectionType.NONE, container)
	_received_signal_callable_infos[slot_name] = callable_info

func get_slot_name_for_signal_receive_callable_name(callable_name: StringName) -> StringName:
	for slot_name in _received_signal_callable_infos:
		if _received_signal_callable_infos[slot_name]["name"] == callable_name:
			return slot_name
	push_warning("No slot found for callable name '", callable_name, "'")
	return &""

func add_signal_receive_and_emit_slot(slot_name: StringName, callable_info: Dictionary, signal_info: Dictionary, label_text: String = "") -> void:
	if callable_info.is_empty() and signal_info.is_empty():
		return

	var container := HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left_connection_type := SynapseStateMachineEditor.ConnectionType.NONE
	var right_connection_type := SynapseStateMachineEditor.ConnectionType.NONE
	if not callable_info.is_empty():
		container.add_child(SynapseGUIUtil.get_texture_rect_for_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_METHOD)))
		left_connection_type = SynapseStateMachineEditor.ConnectionType.SIGNAL_IN
		_received_signal_callable_infos[slot_name] = callable_info

	var center_control: Control
	if label_text.is_empty():
		center_control = Control.new()
		center_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		center_control = create_slot_label(label_text, false, false)
	container.add_child(center_control)

	if not signal_info.is_empty():
		container.add_child(SynapseGUIUtil.get_texture_rect_for_icon(SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.UI_SIGNAL)))
		right_connection_type = SynapseStateMachineEditor.ConnectionType.SIGNAL_OUT
		_emitted_signal_infos[slot_name] = signal_info

	add_named_slot(slot_name, left_connection_type, right_connection_type, container)

func add_named_slot(slot_name: StringName, input_type: SynapseStateMachineEditor.ConnectionType, output_type: SynapseStateMachineEditor.ConnectionType, custom_control: Control = null) -> Control:
	if _slot_controls.has(slot_name):
		push_error("Cannot register duplicate slot name: " + slot_name)
		return null

	var has_input := input_type != SynapseStateMachineEditor.ConnectionType.NONE
	var has_output := output_type != SynapseStateMachineEditor.ConnectionType.NONE

	var control: Control
	if custom_control:
		control = custom_control
	else:
		control = create_slot_label(slot_name, has_input, has_output)

	add_child(control)
	set_slot(control.get_index(), has_input, input_type, PORT_COLORS[input_type], has_output, output_type, PORT_COLORS[output_type])

	_slot_controls[slot_name] = control
	return control

func add_name_manager(editable: bool = true, runtime_property_info: Dictionary = {}) -> SynapseStateMachineEditorGraphNodeNameManager:
	if not has_named_slot(SLOT_NAME_MANAGER):
		var name_manager := SynapseStateMachineEditorResourceManager.Scenes.instantiate_graph_node_name_manager()
		name_manager.editable = editable
		if runtime_property_info.is_empty():
			add_named_slot(SLOT_NAME_MANAGER, SynapseStateMachineEditor.ConnectionType.NONE, SynapseStateMachineEditor.ConnectionType.NONE, name_manager)
		else:
			var container := HBoxContainer.new()
			container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_child(name_manager)
			container.add_child(SynapseGUIUtil.get_texture_rect_for_icon(SynapseClassUtil.get_type_icon(runtime_property_info)))
			add_named_slot(SLOT_NAME_MANAGER, SynapseStateMachineEditor.ConnectionType.NONE, SynapseStateMachineEditor.ConnectionType.PROPERTY_REFERENCE_OUT, container)
			set_runtime_property_info(SLOT_NAME_MANAGER, runtime_property_info)
		name_manager.update_requested.connect(name_update_requested.emit)
	return _get_name_manager()

func set_runtime_property_info(slot_name: StringName, runtime_property_info: Dictionary) -> void:
	_runtime_property_infos[slot_name] = runtime_property_info

func get_runtime_property_info(slot_name: StringName) -> Dictionary:
	return _runtime_property_infos.get(slot_name, {})

func get_slot_name_for_runtime_property_name(property_name: StringName) -> StringName:
	for slot_name in _runtime_property_infos:
		if _runtime_property_infos[slot_name]["name"] == property_name:
			return slot_name
	push_warning("Can't find slot with runtime property '", property_name, "'")
	return &""

func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		call_deferred("_emit_slots_updated") # defer because set_slot is only caller after a child node is added (handlers of this signal depend on set_slot being called)

func _emit_slots_updated() -> void:
	slots_updated.emit()

func _get_name_manager() -> SynapseStateMachineEditorGraphNodeNameManager:
	@warning_ignore("unsafe_cast")
	var name_manager_control := _slot_controls.get(SLOT_NAME_MANAGER) as Control
	if name_manager_control:
		if name_manager_control is SynapseStateMachineEditorGraphNodeNameManager:
			return name_manager_control
		else:
			return name_manager_control.get_child(0)
	return null

func remove_named_slot(slot_name: StringName) -> void:
	var control := _slot_controls[slot_name]
	set_slot(control.get_index(), false, 0, Color.WHITE, false, 0, Color.WHITE)
	_slot_controls.erase(slot_name)
	_emitted_signal_infos.erase(slot_name)
	_received_signal_callable_infos.erase(slot_name)
	_runtime_property_infos.erase(slot_name)
	remove_child_and_fix_slot_numbers(control)
	control.queue_free()
	shrink_to_fit_contents()

func remove_child_and_fix_slot_numbers(node: Node) -> void:
	var index := node.get_index()
	for i in range(index, get_child_count()):
		set_slot(i, is_slot_enabled_left(i + 1), get_slot_type_left(i + 1), get_slot_color_left(i + 1), is_slot_enabled_right(i + 1), get_slot_type_right(i + 1), get_slot_color_right(i + 1))
	remove_child(node)

func shrink_to_fit_contents() -> void:
	size = Vector2.ZERO

func get_input_port_number(slot_name: StringName) -> int:
	if not _slot_controls.has(slot_name):
		return -1

	var slot_number := _slot_controls[slot_name].get_index()
	var port_count := 0
	for i in range(slot_number):
		if is_slot_enabled_left(i):
			port_count += 1
	return port_count

func get_output_port_number(slot_name: StringName) -> int:
	if not _slot_controls.has(slot_name):
		return -1

	var slot_number := _slot_controls[slot_name].get_index()
	var port_count := 0
	for i in range(slot_number):
		if is_slot_enabled_right(i):
			port_count += 1
	return port_count

func get_connection_type_for_input_port(port_number: int) -> SynapseStateMachineEditor.ConnectionType:
	return get_input_port_type(port_number) as SynapseStateMachineEditor.ConnectionType

func get_connection_type_for_output_port(port_number: int) -> SynapseStateMachineEditor.ConnectionType:
	return get_output_port_type(port_number) as SynapseStateMachineEditor.ConnectionType

func get_slot_name_for_input_port(port_number: int) -> StringName:
	var slot_number := get_input_port_slot(port_number)
	var slot_control := get_child(slot_number)
	for slot_name in _slot_controls:
		var control := _slot_controls[slot_name]
		if is_same(control, slot_control):
			return slot_name
	push_warning("No input port ", port_number, " on '", get_entity_name(), "'")
	return &""

func get_slot_name_for_output_port(port_number: int) -> StringName:
	var slot_number := get_output_port_slot(port_number)
	var slot_control := get_child(slot_number)
	for slot_name in _slot_controls:
		var control := _slot_controls[slot_name]
		if is_same(control, slot_control):
			return slot_name
	push_warning("No output port ", port_number, " on '", get_entity_name(), "'")
	return &""

func get_entity_name() -> StringName:
	var name_manager := _get_name_manager()
	if name_manager:
		return name_manager.name_value
	return _entity_name

func set_entity_name(entity_name: StringName) -> void:
	var name_manager := _get_name_manager()
	if name_manager:
		name_manager.name_value = entity_name
		shrink_to_fit_contents()
	_entity_name = entity_name
	return

@abstract
func get_entity_type() -> SynapseStateMachineData.EntityType

func get_entity_reference() -> SynapseEntityReferenceData:
	return SynapseEntityReferenceData.of(get_entity_type(), get_entity_name())
