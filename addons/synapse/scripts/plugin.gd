@tool
class_name SynapseStateMachineEditorPlugin
extends EditorPlugin

const PLUGIN_FOLDER := "synapse"

static var plugin_config: ConfigFile

var dock: EditorDock
var dock_ui: SynapseStateMachineEditorDockUI
var resource_cache: SynapseStateMachineEditorResourceCache
var state_machine_inspector_plugin: SynapseStateMachineEditorInspectorPlugin

var _initialized := false

func _enter_tree() -> void:
	plugin_config = load_plugin_config()
	if not plugin_config:
		return
	if not check_engine_version_compatibility(plugin_config):
		return
	generate_plugin_version_script()
	_initialized = true # here instead of at the end to at least try to clean up when unloading, even if half-broken
	var plugin_icon := SynapseStateMachineEditorResourceManager.Icons.get_icon(SynapseStateMachineEditorResourceManager.Icons.STATE_MACHINE)

	dock_ui = SynapseStateMachineEditorResourceManager.Scenes.instantiate_state_machine_editor_dock_ui()

	dock = EditorDock.new()
	dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	dock.available_layouts = EditorDock.DOCK_LAYOUT_ALL
	dock.title = str(plugin_config.get_value("plugin", "name", ""))
	dock.dock_icon = plugin_icon
	dock.transient = true
	dock.add_child(dock_ui)
	add_dock(dock)

	resource_cache = SynapseStateMachineEditorResourceCache.new()
	resource_cache.caching_complete.connect(_on_resource_cache_caching_complete, CONNECT_ONE_SHOT)
	dock_ui.connect_signals_to_resource_cache(resource_cache)
	resource_cache.cache_resources()
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(resource_cache.cache_resources)

	dock_ui.editor.prepare_in_plugin(get_undo_redo(), resource_cache)

	state_machine_inspector_plugin = SynapseStateMachineEditorInspectorPlugin.new(get_undo_redo())
	state_machine_inspector_plugin.parameter_value_set.connect(dock_ui.editor.notify_parameter_value_updated)
	add_inspector_plugin(state_machine_inspector_plugin)

	add_custom_type("SynapseStateMachine", "Node", preload("uid://ceetsmex74c8w"), plugin_icon)

	_make_visible(false)

func _exit_tree() -> void:
	if not _initialized:
		return
	_make_visible(false)

	EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(resource_cache.cache_resources)
	resource_cache.clear_resource_cache()
	resource_cache = null

	remove_inspector_plugin(state_machine_inspector_plugin)
	state_machine_inspector_plugin = null # RefCounted
	remove_custom_type("SynapseStateMachine")
	dock_ui.editor.queue_free()
	dock.remove_child(dock_ui)
	dock_ui.queue_free()
	remove_dock(dock)
	dock.queue_free()
	dock = null
	dock_ui = null

func _handles(object: Object) -> bool:
	if not _initialized:
		return false
	if object is SynapseStateMachine:
		return true
	if object is SynapseBehavior and is_instance_valid(dock_ui.editor.state_machine) and dock_ui.editor.state_machine.data:
		var path_to_behavior := dock_ui.editor.state_machine.get_path_to(object as SynapseBehavior)
		if dock_ui.editor.state_machine.data.behaviors.values().any(func(bd: SynapseBehaviorData) -> bool: return bd.node_path == path_to_behavior):
			return true
	return false

func _make_visible(visible: bool) -> void:
	if _initialized:
		if visible:
			dock.open()
		else:
			dock.close()

func _clear() -> void:
	if _initialized:
		dock_ui.editor.unload_state_machine()

func _edit(object: Object) -> void:
	if _initialized and object is SynapseStateMachine:
		dock_ui.editor.select_state_machine(object as SynapseStateMachine)

func load_plugin_config() -> ConfigFile:
	var config_file_path := "res://addons/" + PLUGIN_FOLDER + "/plugin.cfg"
	var config := ConfigFile.new()
	var err := config.load(config_file_path)
	if err == OK:
		return config

	error_out("Unable to load plugin config at: " + config_file_path, config)
	return null

func generate_plugin_version_script() -> void:
	var version := get_plugin_version_from_config()
	if version.is_empty():
		return

	var content := "# GENERATED FILE - DO NOT EDIT\nclass_name SynapseVersionInfo\nconst STRING = \"%s\"\n" % version
	var path := ResourceUID.get_id_path(ResourceUID.text_to_id(SynapseStateMachineEditorResourceManager.UIDs.VERSION_INFO_SCRIPT))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)

func check_engine_version_compatibility(config: ConfigFile) -> bool:
	var engine_version := Engine.get_version_info()
	if engine_version.major < 4 or (engine_version.major == 4 and engine_version.minor < 6):
		error_out("Requires Godot 4.6 or higher. You are running " + str(engine_version["string"]), config)
		return false
	return true

func error_out(message: String, config: ConfigFile) -> void:
	var plugin_name := str(config.get_value("plugin", "name", ""))
	if not plugin_name.is_empty():
		message = plugin_name + ": " + message
	printerr(message)

	# call_deferred doesn't work because the editor settings window is probably open (and exclusive)
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		EditorInterface.set_plugin_enabled(PLUGIN_FOLDER, false)
	)

	var dialogue := AcceptDialog.new()
	dialogue.dialog_text = message
	dialogue.exclusive = false # otherwise it clashes with the project settings exclusive dialogue
	EditorInterface.get_base_control().add_child(dialogue)
	dialogue.popup_centered()

func _on_resource_cache_caching_complete() -> void:
	var plugin_dir := "res://addons/" + PLUGIN_FOLDER + "/"
	var feature_profile_file_path := plugin_dir + "editor_feature_profile.profile"
	var profile := EditorFeatureProfile.new()
	var err := profile.load_from_file(feature_profile_file_path)
	if err != OK:
		push_warning("Unable to load Synapse feature profile to hide internal classes from the editor. No big deal, but the dialogs for adding nodes and scenes might be a bit cluttered!")
		return
	var profile_disabled_class_dirs: Array[String] = [
		ProjectSettings.globalize_path(plugin_dir + "demos/"),
		ProjectSettings.globalize_path(plugin_dir + "scripts/generated/"),
		ProjectSettings.globalize_path(plugin_dir + "scripts/resource_types/"),
		ProjectSettings.globalize_path(plugin_dir + "scripts/state_machine/"),
		ProjectSettings.globalize_path(plugin_dir + "scripts/ui/"),
		ProjectSettings.globalize_path(plugin_dir + "scripts/util/"),
	]

	var plugin_classes_by_base_dir := resource_cache.get_plugin_internal_classes_by_base_dir()
	for base_dir in plugin_classes_by_base_dir:
		var global_dir := ProjectSettings.globalize_path(base_dir) + "/"
		for disabled_dir in profile_disabled_class_dirs:
			if global_dir.begins_with(disabled_dir):
				for cls: StringName in plugin_classes_by_base_dir[base_dir]:
					profile.set_disable_class(cls, true)
	profile.save_to_file(feature_profile_file_path)

static func get_plugin_version_from_config() -> String:
	if not EditorInterface.is_plugin_enabled(PLUGIN_FOLDER):
		# tool scripts can call this while the plugin is disabled
		return ""

	var version := ""
	if plugin_config:
		version = plugin_config.get_value("plugin", "version", "")

	if version.is_empty():
		push_error("Unable to determine plugin version")
		return ""
	return version
