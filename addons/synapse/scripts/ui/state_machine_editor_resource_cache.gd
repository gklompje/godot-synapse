@tool
class_name SynapseStateMachineEditorResourceCache

signal caching_started
signal caching_total_file_count_determined(num_files: int)
signal caching_file(file_path: String)
signal caching_files_completed(files_cached: int)
signal caching_complete

var _caching_thread: Thread
var _resource_cache: Dictionary[String, CachedResource] = {}
var _state_data_script_cache: Dictionary[String, CachedScript] = {}
var _parameter_script_cache: Dictionary[String, CachedScript] = {}
var _plugin_internal_classes: Dictionary[String, Array] = {}
var _filesystem_dirty := false

class CachedResource:
	var path: String
	var mtime: int

	func _init(file_path: String) -> void:
		path = file_path
		mtime = FileAccess.get_modified_time(path)

	func is_dirty() -> bool:
		return FileAccess.get_modified_time(path) != mtime

class CachedScene extends CachedResource:
	var short_name: StringName

	func _init(file_path: String) -> void:
		super(file_path)
		short_name = (load(path) as PackedScene).get_state().get_node_name(0)

	func load_scene() -> PackedScene:
		return load(path) as PackedScene

class CachedScript extends CachedResource:
	func load_script() -> Script:
		return load(path) as Script

func clear_resource_cache() -> void:
	_await_caching()
	_resource_cache.clear()
	_state_data_script_cache.clear()
	_parameter_script_cache.clear()

func cache_resources() -> void:
	call_deferred("_cache_resources")

func _cache_resources() -> void:
	if _caching_thread != null:
		_filesystem_dirty = true
		return
	_caching_thread = Thread.new()
	_caching_thread.start(_cache_resources_threaded)
	caching_started.emit()

func _get_files_to_scan_recursively(dir: EditorFileSystemDirectory, visited_paths: Dictionary[StringName, bool]) -> Dictionary[String, StringName]:
	var file_paths: Dictionary[String, StringName] = {}
	for i in dir.get_file_count():
		var path := dir.get_file_path(i)
		visited_paths[path] = true
		if not _resource_cache.has(path) or _resource_cache[path].is_dirty():
			var file_type := dir.get_file_type(i)
			if [&"PackedScene", &"GDScript"].has(file_type):
				file_paths[path] = file_type
	for i in dir.get_subdir_count():
		file_paths.merge(_get_files_to_scan_recursively(dir.get_subdir(i), visited_paths))
	return file_paths

func _cache_resources_threaded() -> void:
	var root := EditorInterface.get_resource_filesystem().get_filesystem()
	var visited_paths: Dictionary[StringName, bool] = {}

	var file_paths := _get_files_to_scan_recursively(root, visited_paths)
	for path: String in _resource_cache.keys():
		if not path in visited_paths:
			# remove stale entries
			_resource_cache.erase(path)
			_state_data_script_cache.erase(path)
			_parameter_script_cache.erase(path)
	caching_total_file_count_determined.emit.call_deferred(file_paths.size())
	_cache_resources_from_paths(file_paths)
	call_deferred("_complete_caching")

func _cache_resources_from_paths(file_paths: Dictionary[String, StringName]) -> void:
	var global_plugin_dir := ProjectSettings.globalize_path("res://addons/" + SynapseStateMachineEditorPlugin.PLUGIN_FOLDER + "/")

	var scanned_count := 0
	for path in file_paths:
		caching_file.emit.call_deferred(path)
		match file_paths[path]:
			&"GDScript":
				var cached_script := CachedScript.new(path)
				_resource_cache[path] = cached_script
				var script := cached_script.load_script()
				if not script.is_abstract():
					if SynapseClassUtil.script_inherits_class_name(script, &"SynapseStateData"):
						_state_data_script_cache[path] = cached_script
					elif SynapseClassUtil.script_inherits_class_name(script, &"SynapseParameter"):
						_parameter_script_cache[path] = cached_script
					if ProjectSettings.globalize_path(path).begins_with(global_plugin_dir):
						if not script.get_global_name().is_empty():
							@warning_ignore("unsafe_cast")
							(_plugin_internal_classes.get_or_add(path.get_base_dir(), []) as Array).append(script.get_global_name())
		scanned_count += 1
		caching_files_completed.emit.call_deferred(scanned_count)

func _complete_caching() -> void:
	_caching_thread.wait_to_finish()
	_caching_thread = null
	caching_complete.emit()

	if _filesystem_dirty:
		_filesystem_dirty = false
		call_deferred("cache_resources")

func get_cached_state_data_scripts() -> Array[CachedScript]:
	_await_caching()
	return _state_data_script_cache.values()

func get_cached_parameter_scripts() -> Array[CachedScript]:
	_await_caching()
	return _parameter_script_cache.values()

func get_plugin_internal_classes_by_base_dir() -> Dictionary[String, Array]:
	return _plugin_internal_classes.duplicate(true)

func _await_caching() -> void:
	if _caching_thread != null:
		await caching_complete
