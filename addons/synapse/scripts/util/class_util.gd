@tool
class_name SynapseClassUtil

static func build_inheritance_map(class_list: Array[Dictionary] = []) -> Dictionary[StringName, StringName]:
	if not class_list:
		class_list = ProjectSettings.get_global_class_list()
	var inheritance_map: Dictionary[StringName, StringName] = {}
	for entry in class_list:
		inheritance_map[entry["class"]] = entry["base"]
	return inheritance_map

static func is_assignable_from(current_class: StringName, base_class: StringName, inheritance_map: Dictionary[StringName, StringName] = {}) -> bool:
	if current_class == base_class:
		return true

	if not inheritance_map:
		inheritance_map = build_inheritance_map()

	var cls: StringName = current_class
	while cls != null and cls != &"":
		if cls == base_class:
			return true

		if inheritance_map.has(cls):
			cls = inheritance_map[cls]
		else:
			if ClassDB.class_exists(cls) and ClassDB.class_exists(base_class):
				return ClassDB.is_parent_class(cls, base_class)
			break

	return false

static func get_property_class_name(obj: Object, property_name: StringName) -> StringName:
	for property_dict in obj.get_property_list():
		if property_dict["name"] == property_name:
			return property_dict["class_name"]
	return &""

static func get_script_property_class_name(script: Script, property_name: StringName) -> StringName:
	for property_dict in script.get_script_property_list():
		if property_dict["name"] == property_name:
			return property_dict["class_name"]
	return &""

static func get_script_for(cls_name: StringName) -> Script:
	for entry in ProjectSettings.get_global_class_list():
		if entry["class"] == cls_name:
			@warning_ignore("unsafe_cast")
			return load(entry["path"] as String)
	return null

static func script_inherits_class_name(script: Script, target_class_name: StringName) -> bool:
	var current_script := script
	while current_script != null:
		if current_script.get_global_name() == target_class_name:
			return true
		current_script = current_script.get_base_script()
	return false

static func get_property_type_string(prop: Dictionary) -> String:
	@warning_ignore("unsafe_cast")
	if prop["type"] == TYPE_OBJECT and not (prop["class_name"] as String).is_empty():
		return prop["class_name"]
	@warning_ignore("unsafe_cast")
	return type_string(prop["type"] as int)

static func get_script_class_name(script: Script) -> StringName:
	var current_script := script
	while current_script != null:
		var script_class_name := current_script.get_global_name()
		if not script_class_name.is_empty():
			return script_class_name
		current_script = current_script.get_base_script()
	return &""

static func get_root_script(scene: PackedScene) -> Script:
	var state := scene.get_state()
	# Iterate properties of the root node (index 0)
	for i in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, i) == "script":
			return state.get_node_property_value(0, i)
	return null

static func get_script_icon(script: Script) -> Texture2D:
	var global_classes := ProjectSettings.get_global_class_list()
	var current_script := script
	while current_script != null:
		for class_info in global_classes:
			@warning_ignore("unsafe_cast")
			var icon_path := class_info["icon"] as String
			if icon_path and class_info["path"] == current_script.resource_path:
				return load(icon_path)
		current_script = current_script.get_base_script()
	return null

static func get_class_icon(cls_name: StringName) -> Texture2D:
	var global_class_map: Dictionary[StringName, Dictionary] = {}
	for entry in ProjectSettings.get_global_class_list():
		global_class_map[entry["class"]] = entry
	var current_class := cls_name
	while current_class != null:
		if not global_class_map.has(current_class):
			return null
		var class_info := global_class_map[current_class]
		@warning_ignore("unsafe_cast")
		var icon_path := class_info["icon"] as String
		if icon_path:
			return load(icon_path)
		current_class = class_info["base"]
	return null

static func get_type_icon(property_def: Dictionary) -> Texture2D:
	if property_def["type"] == TYPE_OBJECT:
		@warning_ignore("unsafe_cast")
		var class_name_str := property_def.get("class_name", "") as String
		if class_name_str.is_empty() and property_def["hint"] == PROPERTY_HINT_RESOURCE_TYPE:
			class_name_str = property_def["hint_string"]

		if not class_name_str.is_empty():
			if EditorInterface.get_editor_theme().has_icon(class_name_str, &"EditorIcons"):
				return EditorInterface.get_editor_theme().get_icon(class_name_str, &"EditorIcons")
			else:
				var class_icon := get_class_icon(class_name_str)
				if class_icon:
					return class_icon

	var icon_name: String = ""
	match property_def["type"]:
		TYPE_NIL:
			icon_name = "Variant" #"Nil" is technically null's type, but TYPE_NIL in this context means "Variant"
		TYPE_BOOL:
			icon_name = "bool"
		TYPE_INT:
			icon_name = "int"
		TYPE_FLOAT:
			icon_name = "float"
		TYPE_STRING:
			icon_name = "String"
		TYPE_VECTOR2:
			icon_name = "Vector2"
		TYPE_VECTOR2I:
			icon_name = "Vector2i"
		TYPE_RECT2:
			icon_name = "Rect2"
		TYPE_RECT2I:
			icon_name = "Rect2i"
		TYPE_VECTOR3:
			icon_name = "Vector3"
		TYPE_VECTOR3I:
			icon_name = "Vector3i"
		TYPE_TRANSFORM2D:
			icon_name = "Transform2D"
		TYPE_VECTOR4:
			icon_name = "Vector4"
		TYPE_VECTOR4I:
			icon_name = "Vector4i"
		TYPE_PLANE:
			icon_name = "Plane"
		TYPE_QUATERNION:
			icon_name = "Quaternion"
		TYPE_AABB:
			icon_name = "AABB"
		TYPE_BASIS:
			icon_name = "Basis"
		TYPE_TRANSFORM3D:
			icon_name = "Transform3D"
		TYPE_PROJECTION:
			icon_name = "Projection"
		TYPE_COLOR:
			icon_name = "Color"
		TYPE_STRING_NAME:
			icon_name = "StringName"
		TYPE_NODE_PATH:
			icon_name = "NodePath"
		TYPE_RID:
			icon_name = "RID"
		TYPE_OBJECT:
			icon_name = "Object"
		TYPE_CALLABLE:
			icon_name = "Callable"
		TYPE_SIGNAL:
			icon_name = "Signal"
		TYPE_DICTIONARY:
			icon_name = "Dictionary"
		TYPE_ARRAY:
			icon_name = "Array"
		TYPE_PACKED_BYTE_ARRAY:
			icon_name = "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY:
			icon_name = "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY:
			icon_name = "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY:
			icon_name = "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY:
			icon_name = "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY:
			icon_name = "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY:
			icon_name = "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY:
			icon_name = "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY:
			icon_name = "PackedColorArray"
		TYPE_PACKED_VECTOR4_ARRAY:
			icon_name = "PackedVector4Array"
		_:
			icon_name = "Variant"

	return EditorInterface.get_base_control().get_theme_icon(icon_name, &"EditorIcons")

static func is_value_empty(value: Variant) -> bool:
	match typeof(value):
		TYPE_STRING:
			@warning_ignore("unsafe_cast")
			return (value as String).is_empty()
		TYPE_STRING_NAME:
			@warning_ignore("unsafe_cast")
			return (value as StringName).is_empty()
		TYPE_NODE_PATH:
			@warning_ignore("unsafe_cast")
			return (value as NodePath).is_empty()
		TYPE_DICTIONARY:
			@warning_ignore("unsafe_cast")
			return (value as Dictionary).is_empty()
		TYPE_ARRAY:
			@warning_ignore("unsafe_cast")
			return (value as Array).is_empty()
		TYPE_NIL:
			return true

	# Godot assigns default values to most types (e.g. integer zero), and we can't tell the difference between that and someone intentionally setting it to that value
	return false

static func is_instance_of_class_name(node: Node, base_class: StringName) -> bool:
	# only works for built-in classes
	if node.is_class(base_class):
		return true

	@warning_ignore("unsafe_cast")
	var script := node.get_script() as Script
	return script_inherits_class_name(script, base_class)

static func find_all_child_nodes_of(node: Node, base_class: StringName = &"Node", inheritance_map: Dictionary[StringName, StringName] = {}) -> Array[Node]:
	if not inheritance_map:
		inheritance_map = build_inheritance_map()
	var nodes: Array[Node] = []
	if is_instance_of_class_name(node, base_class):
		nodes.append(node)
	for child in node.get_children():
		nodes.append_array(find_all_child_nodes_of(child, base_class, inheritance_map))
	return nodes

static func is_argument_compatible(source_argument: Dictionary, target_argument: Dictionary, inheritance_map: Dictionary[StringName, StringName] = {}) -> bool:
	if source_argument.is_empty() or target_argument.is_empty():
		return false

	if target_argument["type"] == TYPE_NIL:
		return true # target accepts Variant

	if source_argument["type"] != target_argument["type"]:
		# String and StringName are interchangeable
		if (source_argument["type"] == TYPE_STRING and target_argument["type"] == TYPE_STRING_NAME)\
				or (target_argument["type"] == TYPE_STRING and source_argument["type"] == TYPE_STRING_NAME):
			return true
		# int -> float promotion
		if source_argument["type"] == TYPE_INT and target_argument["type"] == TYPE_FLOAT:
			return true
		return false

	if not inheritance_map:
		inheritance_map = build_inheritance_map()

	if source_argument["type"] == TYPE_OBJECT:
		@warning_ignore("unsafe_cast")
		if not is_assignable_from(source_argument["class_name"] as StringName, target_argument["class_name"] as StringName, inheritance_map):
			return false

	if source_argument["type"] == TYPE_ARRAY or source_argument["type"] == TYPE_DICTIONARY:
		var s_hint: String = source_argument.get("hint_string", "")
		var m_hint: String = target_argument.get("hint_string", "")

		if m_hint == "":
			return true

		var s_parts := s_hint.split(";")
		var m_parts := m_hint.split(";")
		if s_parts.size() != m_parts.size():
			return false

		for j in range(m_parts.size()):
			var s_sub := s_parts[j].split(":")[-1]
			var m_sub := m_parts[j].split(":")[-1]

			if not is_assignable_from(s_sub, m_sub, inheritance_map):
				return false
		return true

	return true

static func is_signature_compatible(source_dict: Dictionary, target_dict: Dictionary, bound_argument_count: int = 0, inheritance_map: Dictionary[StringName, StringName] = {}) -> bool:
	if source_dict.is_empty() or target_dict.is_empty():
		return false

	var sig_args: Array = source_dict.get("args", [])
	var meth_args: Array = target_dict.get("args", [])
	var default_args: Array = target_dict.get("default_args", [])

	var total_meth_args := meth_args.size()
	var default_count := default_args.size()
	var remaining_args_count := total_meth_args - bound_argument_count
	var effective_meth_args := meth_args.slice(0, remaining_args_count)
	var mandatory_count := clampi(total_meth_args - default_count, 0, remaining_args_count)

	if sig_args.size() < mandatory_count or sig_args.size() > effective_meth_args.size():
		return false

	if not inheritance_map:
		inheritance_map = build_inheritance_map()

	for i in range(mini(sig_args.size(), effective_meth_args.size())):
		@warning_ignore("unsafe_cast")
		var s := sig_args[i] as Dictionary
		@warning_ignore("unsafe_cast")
		var m := meth_args[i] as Dictionary

		if not is_argument_compatible(s, m, inheritance_map):
			return false

	return true

static func can_connect_signal_to_method(sig: Signal, method: Callable, inheritance_map: Dictionary[StringName, StringName] = {}) -> bool:
	var emitter := sig.get_object()
	var receiver := method.get_object()
	if not emitter or not receiver: return false

	var sig_def: Dictionary = {}
	for s in emitter.get_signal_list():
		if s["name"] == sig.get_name():
			sig_def = s
			break

	var meth_def: Dictionary = {}
	for m in receiver.get_method_list():
		if m["name"] == method.get_method():
			meth_def = m
			break

	if sig_def.is_empty() or meth_def.is_empty():
		return false

	return is_signature_compatible(sig_def, meth_def, method.get_bound_arguments_count(), inheritance_map)

static func find_scripts_implementing(base_class: String) -> Array[Script]:
	var class_list := ProjectSettings.get_global_class_list()
	var scripts: Array[Script] = []
	for entry in class_list:
		@warning_ignore("unsafe_cast")
		var script := load(entry["path"] as String) as Script
		if script and not script.is_abstract() and SynapseClassUtil.script_inherits_class_name(script, base_class):
			scripts.append(script)
	return scripts

static func call_static_method_on_script_or_base_classes(script: Script, method_name: StringName, ...args: Array) -> Variant:
	var current_script := script
	while current_script != null:
		if current_script.has_method(method_name):
			return current_script.callv(method_name, args)
		current_script = current_script.get_base_script()

	return null
