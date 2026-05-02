@tool
class_name SynapseGUIUtil

class ReadOnlyPropertyEditor extends EditorProperty:
	var custom_label := Label.new()

	func _init(property_name: String, message: Variant, tooltip: String) -> void:
		label = property_name
		custom_label.text = message
		custom_label.tooltip_text = tooltip
		custom_label.mouse_filter = Control.MOUSE_FILTER_PASS
		modulate = EditorInterface.get_base_control().get_theme_color(&"font_readonly_color", &"Editor")
		add_child(custom_label)

static func nameify(s: String) -> String:
	match EditorInterface.get_editor_settings().get_setting("interface/inspector/default_property_name_style"):
		0: # Raw
			return s
		1: # Capitalized
			return s.capitalize()
		2: # Localized (Usually also capitalizes)
			return EditorInterface.tr(s).capitalize()
		_:
			return s.capitalize()

static func validate_name(proposed_name: String, is_invalid: Callable) -> StringName:
	var proposal := proposed_name
	var suffix := 0
	while is_invalid.call(proposal):
		suffix = maxi(2, suffix + 1) # Godot starts numbering duplicates from 2
		proposal = proposed_name + str(suffix)
	return proposal

static func get_property_editor_for(obj: Object, prop: Dictionary, auto_label: bool = true) -> EditorProperty:
	@warning_ignore("unsafe_cast")
	var editor := EditorInspector.instantiate_property_editor(
		obj,
		prop["type"] as Variant.Type,
		prop["name"] as String,
		prop["hint"] as PropertyHint,
		prop["hint_string"] as String,
		prop["usage"] as int
	)
	if auto_label:
		@warning_ignore("unsafe_cast")
		editor.label = nameify(prop["name"] as String)
	editor.custom_minimum_size = Vector2(100.0, 0.0)
	return editor

static func get_texture_rect_for_icon(icon: Texture2D) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	texture_rect.texture = icon
	return texture_rect

static func select_node_in_editor(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var path_in_scene := node.owner.get_path_to(node)
	var scene_path := node.owner.scene_file_path
	if EditorInterface.get_edited_scene_root().scene_file_path != scene_path:
		EditorInterface.open_scene_from_path(scene_path)
		# opening the scene might take a frame
		await (Engine.get_main_loop() as SceneTree).process_frame
	var new_root := EditorInterface.get_edited_scene_root()
	var equivalent_node := new_root.get_node(path_in_scene)
	if equivalent_node:
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(equivalent_node)
		EditorInterface.edit_node(equivalent_node)

static func get_parameter_value_property_dict(parameter: SynapseParameter) -> Dictionary:
	var value_property_dict: Dictionary
	for prop in parameter.get_property_list():
		if prop["name"] == "value":
			value_property_dict = prop
			break
	if not value_property_dict:
		push_warning("Unable to find property 'value' on parameter: ", parameter)
	return value_property_dict

static func prepare_property_for_storage(state_machine: SynapseStateMachine, property_dict: Dictionary, raw_value: Variant) -> Variant:
	var value_to_store: Variant = raw_value
	match property_dict["type"]:
		# TODO: store nodes with scene_unique_name set as %name
		TYPE_NODE_PATH:
			# note: because the state machine is selected in the editor, actual node paths are already relative to the state machine
			pass
		TYPE_OBJECT:
			if property_dict["hint"] & PROPERTY_HINT_NODE_TYPE:
				# store node reference as node path relative to state machine
				@warning_ignore("unsafe_cast")
				value_to_store = state_machine.get_path_to(raw_value as Node)
			else:
				push_warning("Persisting object reference ('", property_dict["name"], "') that isn't a Node - this may cause unexpected results")
	return value_to_store

static func hydrate_property_from_storage(state_machine: SynapseStateMachine, property_dict: Dictionary, stored_value: Variant) -> Variant:
	var value_to_return: Variant = stored_value
	if value_to_return == null:
		return null
	match property_dict["type"]:
		TYPE_NODE_PATH:
			# node paths are stored relative to the state machine (which is selected in the editor), so no transformation necessary
			pass
		TYPE_OBJECT:
			if property_dict["hint"] & PROPERTY_HINT_NODE_TYPE:
				# node references are stored as node paths relative to state machine
				@warning_ignore("unsafe_cast")
				value_to_return = state_machine.get_node(value_to_return as NodePath)
			else:
				push_warning("Returning object reference ('", property_dict["name"], "') that isn't a Node - this may cause unexpected results")
	return value_to_return
