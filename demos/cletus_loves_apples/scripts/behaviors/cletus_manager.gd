@tool
class_name SynapseDemoCletusManagerBehavior
extends SynapseBehavior

static func get_category() -> StringName:
	return CATEGORY_DEMOS

@export var map_area: SynapseRect2Parameter

@onready var cletus: CharacterBody2D = %Cletus

func _state_machine_created() -> void:
	cletus.global_position = map_area.value.get_center()

func _get_read_only_parameters() -> PackedStringArray:
	return ["map_area"]

func _get_custom_save_data() -> Dictionary:
	return {
		&"global_position": cletus.global_position,
	}

func _load_custom_save_data(custom_save_data: Dictionary) -> void:
	cletus.global_position = custom_save_data[&"global_position"]
