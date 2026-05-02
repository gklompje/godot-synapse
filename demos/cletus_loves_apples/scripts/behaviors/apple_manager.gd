@tool
class_name SynapseDemoAppleManagerBehavior
extends SynapseBehavior

const APPLE_SCENE := preload("uid://plvb58wrbpqc") as PackedScene

static func get_category() -> StringName:
	return CATEGORY_DEMOS

@export var apple_container: Node2D
@export var player: CharacterBody2D
@export var spawn_interval_seconds := 3.0
@export var map_area: SynapseRect2Parameter
@export var minimum_player_distance := 150.0
@export var max_apples := 5

var _timer: Timer
var _apples: Array[StaticBody2D] = []

func _get_read_only_parameters() -> PackedStringArray:
	return ["map_area"]

func _state_machine_created() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.autostart = false
	_timer.wait_time = spawn_interval_seconds
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_timer.start() # timer won't actually tick while this state is suspended

func _on_timer_timeout() -> void:
	if len(_apples) >= max_apples:
		return
	var spawn_pos := player.global_position
	while player.global_position.distance_to(spawn_pos) < minimum_player_distance:
		spawn_pos = Vector2(map_area.value.position.x + 100.0 + randf() * (map_area.value.size.x - 200.0), map_area.value.position.y + 100.0 + randf() * (map_area.value.size.y - 200.0))
	_spawn_apple(spawn_pos)

func _spawn_apple(spawn_pos: Vector2) -> StaticBody2D:
	var apple := APPLE_SCENE.instantiate() as StaticBody2D
	apple_container.add_child(apple)
	apple.global_position = spawn_pos
	apple.tree_exiting.connect(_apples.erase.bind(apple))
	_apples.append(apple)
	return apple

func _get_custom_save_data() -> Dictionary:
	var apple_datas := []
	for apple in _apples:
		if not is_instance_valid(apple) or apple.is_queued_for_deletion():
			continue
		apple_datas.append({
			&"global_position": apple.global_position,
		})
	return {
		&"apples": apple_datas,
	}

func _load_custom_save_data(custom_save_data: Dictionary) -> void:
	for i in range(len(_apples) - 1, -1, -1):
		var apple := _apples[i]
		apple.queue_free()
		_apples.erase(apple)
	for apple_data: Dictionary in custom_save_data[&"apples"]:
		@warning_ignore("unsafe_cast")
		_spawn_apple(apple_data[&"global_position"] as Vector2)
