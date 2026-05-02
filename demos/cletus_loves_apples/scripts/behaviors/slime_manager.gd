@tool
class_name SynapseDemoSlimeManagerBehavior
extends SynapseBehavior

const SLIME_SCENE := preload("uid://cfrd6imdlf8vn") as PackedScene

signal attack_success

@export var enemy_container: Node2D
@export var player: CharacterBody2D
@export var spawn_interval_seconds := 5.0
@export var map_area: SynapseRect2Parameter
@export var minimum_player_distance := 200.0

var _timer: Timer
var _slimes: Array[SynapseDemoSlime] = []

static func get_category() -> StringName:
	return CATEGORY_DEMOS

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

func _unsuspend() -> void:
	for slime in _slimes:
		slime.state_machine.activate()

func _suspend() -> void:
	for slime in _slimes:
		slime.state_machine.deactivate()

func _on_timer_timeout() -> void:
	var spawn_pos := player.global_position
	while player.global_position.distance_to(spawn_pos) < minimum_player_distance:
		spawn_pos = Vector2(map_area.value.position.x + 100.0 + randf() * (map_area.value.size.x - 200.0), map_area.value.position.y + 100.0 + randf() * (map_area.value.size.y - 200.0))
	_spawn_slime(spawn_pos)

func _spawn_slime(spawn_pos: Vector2) -> SynapseDemoSlime:
	var slime := SLIME_SCENE.instantiate() as SynapseDemoSlime
	enemy_container.add_child(slime)
	slime.global_position = spawn_pos
	slime.tree_exiting.connect(_slimes.erase.bind(slime))
	slime.state_machine.created.connect(_on_slime_state_machine_created.bind(slime))
	return slime

func _on_slime_state_machine_created(slime: SynapseDemoSlime) -> void:
	(slime.state_machine.all_behaviors[&"AttackComplete"] as SynapseDemoOneShotTimerBehavior).timeout.connect(attack_success.emit)
	_slimes.append(slime)

func _get_custom_save_data() -> Dictionary:
	var slime_datas := []
	for slime: SynapseDemoSlime in _slimes:
		if not is_instance_valid(slime) or slime.is_queued_for_deletion():
			continue
		slime_datas.append({
			&"global_position": slime.global_position,
			&"state_machine_save_data": slime.state_machine.get_save_data(),
		})
	return {
		&"slimes": slime_datas,
	}

func _load_custom_save_data(custom_save_data: Dictionary) -> void:
	for i in range(len(_slimes) - 1, -1, -1):
		var slime := _slimes[i]
		slime.queue_free()
		_slimes.erase(slime)
	for slime_data: Dictionary in custom_save_data[&"slimes"]:
		@warning_ignore("unsafe_cast")
		var slime := _spawn_slime(slime_data[&"global_position"] as Vector2)
		@warning_ignore("unsafe_cast")
		slime.state_machine.created.connect(slime.state_machine.load_save_data.bind(slime_data[&"state_machine_save_data"] as Dictionary), CONNECT_ONE_SHOT)
