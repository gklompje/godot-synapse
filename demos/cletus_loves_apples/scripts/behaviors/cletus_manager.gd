@tool

## Manages Cletus' position on the map.
class_name SynapseDemoCletusManagerBehavior
extends SynapseBehavior

static func get_category() -> StringName:
	return CATEGORY_DEMOS

@export var map_area: SynapseRect2Parameter # map area to calculate Cletus' position from

@onready var cletus: CharacterBody2D = %Cletus # our dear, hungry friend Cletus

func _state_machine_created() -> void:
	# position Cletus at the center of the map when we first start up
	cletus.global_position = map_area.value.get_center()

func _get_read_only_parameters() -> PackedStringArray:
	return ["map_area"]

func _get_custom_save_data() -> Dictionary:
	# when saving, we want to keep track of Cletus' position
	return {
		&"global_position": cletus.global_position,
	}

func _load_custom_save_data(custom_save_data: Dictionary) -> void:
	# put Cletus back where he was when we saved the game
	cletus.global_position = custom_save_data[&"global_position"]
