@tool
class_name SynapseDemoNodePathBehavior
extends SynapseBehavior

@export var direct_reference_icon: Sprite2D
@export_node_path("Sprite2D") var node_path_icon: NodePath
@export var node_path_parameter_icon: SynapseSprite2DNodePathParameter

@onready var on_ready_icon: Sprite2D = $"../../OnReadyIcon"

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["node_path_parameter_icon"]

func _unsuspend() -> void:
	# direct node references and NodePath variables defined on the SynapseBehavior can be used as per normal
	direct_reference_icon.modulate = Color.RED
	(get_node(node_path_icon) as Sprite2D).modulate = Color.GREEN
	on_ready_icon.modulate = Color.ORANGE

	# NodePath references embedded within BehaviorParameters are relative to the *state machine*
	# (because parameters are shared across the whole state machine, they don't belong to a single behavior)
	(state_machine.get_node(node_path_parameter_icon.value) as Sprite2D).modulate = Color.BLUE
