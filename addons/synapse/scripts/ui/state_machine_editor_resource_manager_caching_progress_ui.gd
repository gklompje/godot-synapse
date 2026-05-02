@tool
class_name SynapseStateMachineEditorResourceManagerCachingProgressUI
extends Control

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var file_label: Label = %FileLabel
@onready var progress_label: Label = %ProgressLabel

func connect_signals_to_resource_cache(resource_cache: SynapseStateMachineEditorResourceCache) -> void:
	resource_cache.caching_started.connect(_on_resource_cache_caching_started)
	resource_cache.caching_total_file_count_determined.connect(_on_resource_cache_caching_total_file_count_determined)
	resource_cache.caching_file.connect(_on_resource_cache_caching_file)
	resource_cache.caching_files_completed.connect(_on_resource_cache_caching_files_completed)
	resource_cache.caching_complete.connect(_on_resource_cache_caching_complete)

func _on_resource_cache_caching_started() -> void:
	progress_bar.value = 0
	progress_bar.max_value = 1
	file_label.text = ""
	progress_label.text = "Files scanned: 0"

func _on_resource_cache_caching_total_file_count_determined(num_files: int) -> void:
	progress_bar.max_value = num_files

func _on_resource_cache_caching_file(path: String) -> void:
	file_label.text = path

func _on_resource_cache_caching_files_completed(files_cached: int) -> void:
	progress_bar.value = files_cached
	progress_label.text = "Files scanned: " + str(files_cached) + " / " + str(int(progress_bar.max_value))

func _on_resource_cache_caching_complete() -> void:
	file_label.text = ""
