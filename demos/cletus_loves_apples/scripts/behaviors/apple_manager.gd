@tool

## Handles the spawning of apples at regular intervals.[br][br]
class_name SynapseDemoAppleManagerBehavior
extends SynapseBehavior

const APPLE_SCENE := preload("uid://plvb58wrbpqc") as PackedScene

static func get_category() -> StringName:
	return CATEGORY_DEMOS

@export var apple_container: Node2D # the node apple scenes will be parented to
@export var player: CharacterBody2D # player reference, so we can avoid spawning apples too close to it
@export var spawn_interval_seconds := 3.0 # how often to spawn an apple
@export var map_area: SynapseRect2Parameter # the map area, to spawn apples within
@export var minimum_player_distance := 150.0 # must spawn apples at least this far from the player
@export var max_apples := 5 # maximium total number of apples on the map

var _timer: Timer # the timer that we'll create to 
var _apples: Array[StaticBody2D] = [] # keeps track of spawned apple scenes, for convenience

func _get_read_only_parameters() -> PackedStringArray:
	return ["map_area"]

func _state_machine_created() -> void:
	# Create a timer that repeats every `spawn_interval_seconds` seconds.
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.autostart = false
	_timer.wait_time = spawn_interval_seconds
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_timer.start() # timer won't actually tick while this state is suspended

func _on_timer_timeout() -> void:
	# don't spawn if we're already at the max allowed apples
	if len(_apples) >= max_apples:
		return

	# spawn a new apple at a random position at least `minimum_player_distance` away from the player
	var spawn_pos := player.global_position
	while player.global_position.distance_to(spawn_pos) < minimum_player_distance:
		spawn_pos = Vector2(map_area.value.position.x + 100.0 + randf() * (map_area.value.size.x - 200.0), map_area.value.position.y + 100.0 + randf() * (map_area.value.size.y - 200.0))
	_spawn_apple(spawn_pos)

func _spawn_apple(spawn_pos: Vector2) -> StaticBody2D:
	# instantiate the apple scene and add it to the specified container node
	var apple := APPLE_SCENE.instantiate() as StaticBody2D
	apple_container.add_child(apple)
	apple.global_position = spawn_pos
	apple.tree_exiting.connect(_apples.erase.bind(apple))

	# keep track of the apple so we can save it
	_apples.append(apple)
	return apple

func _get_custom_save_data() -> Dictionary:
	var apple_datas := []
	for apple in _apples:
		# don't bother saving an apple that's already going away (probably been eaten)
		if not is_instance_valid(apple) or apple.is_queued_for_deletion():
			continue

		# we save only the apple's position- this is all we need on load to spawn a new one
		apple_datas.append({
			&"global_position": apple.global_position,
		})

	# our save data is just an array of apple positions captured above, keyed on "apples"
	# (we should technically also store the timer's remaining time, but that's more hassle than it's worth)
	return {
		&"apples": apple_datas
	}

func _load_custom_save_data(custom_save_data: Dictionary) -> void:
	# first delete any apples we're currently tracking (loading can happen mid-game)
	# (we loop over the currently tracked apples in reverse so we can remove from the array while we iterate over it)
	for i in range(len(_apples) - 1, -1, -1):
		var apple := _apples[i]
		apple.queue_free()
		_apples.erase(apple)

	# now spawn a new apple at each position recorded in the save data
	for apple_data: Dictionary in custom_save_data[&"apples"]:
		@warning_ignore("unsafe_cast")
		_spawn_apple(apple_data[&"global_position"] as Vector2)
