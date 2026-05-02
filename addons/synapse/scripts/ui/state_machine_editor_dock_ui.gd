@tool
class_name SynapseStateMachineEditorDockUI
extends Container

@onready var caching_progress: SynapseStateMachineEditorResourceManagerCachingProgressUI = %StateMachineEditorResourceManagerCachingProgress
@onready var editor: SynapseStateMachineEditor = %StateMachineEditor

func connect_signals_to_resource_cache(resource_cache: SynapseStateMachineEditorResourceCache) -> void:
	caching_progress.connect_signals_to_resource_cache(resource_cache)
	resource_cache.caching_started.connect(_on_resource_cache_caching_started)
	resource_cache.caching_complete.connect(_on_resource_cache_caching_complete)

func _on_resource_cache_caching_started() -> void:
	editor.hide()
	caching_progress.show()

func _on_resource_cache_caching_complete() -> void:
	editor.refresh_graph()
	caching_progress.hide()
	editor.show()
