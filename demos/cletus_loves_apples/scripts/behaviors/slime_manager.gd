@tool

## Manages the life cycle of all the slimes in the scene.[br][br]
## Because Synapse state machines don't currently support dynamically adding states, this behavior
## handles the spawning of slimes and ensures that their state machines are saved and loaded with
## the game state machine (to which this behavior belongs).
class_name SynapseDemoSlimeManagerBehavior
extends SynapseBehavior

const SLIME_SCENE := preload("uid://cfrd6imdlf8vn") as PackedScene

signal attack_success # emitted when a slime performs an attack on Cletus

@export var enemy_container: Node2D # Node where instantiated slimes scenes must be added to
@export var player: CharacterBody2D # reference to Cletus, so we can avoid spawning slimes too close
@export var spawn_interval_seconds := 5.0 # how often to spawn a slime
@export var map_area: SynapseRect2Parameter # map area, to restrict slime spawn locations
@export var minimum_player_distance := 200.0 # minimum distance to Cletus we can spawn

var _timer: Timer # internal timer used to spawn slimes
var _slimes: Array[SynapseDemoSlime] = [] # tracks all the active slimes, for convenience

static func get_category() -> StringName:
	return CATEGORY_DEMOS

func _get_read_only_parameters() -> PackedStringArray:
	return ["map_area"]

func _state_machine_created() -> void:
	# start the spawn timer- note that adding it as a child of this behavior makes it so it won't
	# tick while the behavior is suspended (like while the game is paused)
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.autostart = false
	_timer.wait_time = spawn_interval_seconds
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_timer.start() # timer won't actually tick while this state is suspended

func _unsuspend() -> void:
	# we need to activate all the slimes' state machines when we unsuspend
	for slime in _slimes:
		slime.state_machine.activate()

func _suspend() -> void:
	# we need to deactivate all the slimes' state machines when we are suspended
	for slime in _slimes:
		slime.state_machine.deactivate()

func _on_timer_timeout() -> void:
	# spawn a new slime at a random location
	var spawn_pos := player.global_position
	# keep picking random map points until we've found one far enough away
	while player.global_position.distance_to(spawn_pos) < minimum_player_distance:
		spawn_pos = Vector2(map_area.value.position.x + 100.0 + randf() * (map_area.value.size.x - 200.0), map_area.value.position.y + 100.0 + randf() * (map_area.value.size.y - 200.0))
	_spawn_slime(spawn_pos)

func _spawn_slime(spawn_pos: Vector2) -> SynapseDemoSlime:
	# create a new slime and add it to the enemy container node
	var slime := SLIME_SCENE.instantiate() as SynapseDemoSlime
	enemy_container.add_child(slime)
	slime.global_position = spawn_pos
	slime.tree_exiting.connect(_slimes.erase.bind(slime)) # stop tracking the slime when it is freed

	# defer our slime registration actions until its state machine is fully initialized
	slime.state_machine.created.connect(_on_slime_state_machine_created.bind(slime))
	return slime

func _on_slime_state_machine_created(slime: SynapseDemoSlime) -> void:
	# emit our own attack_success signal when the slime hits Cletus
	# note we can only grab a reference to its "AttackComplete" behavior after the slime's state machine has fully initialized
	(slime.state_machine.all_behaviors[&"AttackComplete"] as SynapseDemoOneShotTimerBehavior).timeout.connect(attack_success.emit)
	_slimes.append(slime) # keep track of the slime

func _get_custom_save_data() -> Dictionary:
	# for each slime, we save the map position and its state machine's save data
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
	# free all current slimes (loading can happen while another game is in progress)
	for slime in _slimes:
		slime.queue_free()
	_slimes.clear()

	for slime_data: Dictionary in custom_save_data[&"slimes"]:
		# spawn a slime at the loaded position
		@warning_ignore("unsafe_cast")
		var slime := _spawn_slime(slime_data[&"global_position"] as Vector2)

		# we can only load the slime's save data after its state machine has initialized!
		@warning_ignore("unsafe_cast")
		slime.state_machine.created.connect(slime.state_machine.load_save_data.bind(slime_data[&"state_machine_save_data"] as Dictionary), CONNECT_ONE_SHOT)
