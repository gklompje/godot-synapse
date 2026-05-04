@tool

## Makes a character roam around randomly.[br][br]
## Used by slimes when they have no line of sight to Cletus. Every few seconds, picks a random point
## in a circle centered where the character was when this behavior was unsuspended. It then sets the
## character direction toward that point, and sets the direction to zero when the character reaches
## it.
class_name SynapseDemoRandomRoam2D
extends SynapseDemoCharacterBehavior2D

@export var radius := 100.0 # roaming circle radius
@export var stop_radius := 10.0 # how close to the target point to stop
@export var direction: SynapseVector2Parameter # direction to set, controls character's movement
@export var recalculate_interval_seconds := 5.0 # how often to pick a point to move to
@export var max_stop_time_seconds := 1.0 # maximum time to wait before picking another point once the previous one was reached

var _roam_origin := Vector2.ZERO # center position, recorded when unsuspended
var _target_position := Vector2.ZERO # current target point
var _seconds_since_last_recalculate := 0.0 # how long since we last picked a new point
var _seconds_since_stop := 0.0 # how long since we reached a target point

static func get_category() -> StringName:
	return SynapseBehavior.CATEGORY_DEMOS

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# ensures we always recalculate initially
	_seconds_since_last_recalculate = recalculate_interval_seconds

func _unsuspend() -> void:
	# record the character's position as the roaming circle's center, then pick a point
	_roam_origin = character.global_position
	_recalculate()

func _process(delta: float) -> void:
	# since this is a tool script, we don't want it running in the editor (this isn't really
	# necessary since the behavior node stops its processing when it loads, but just in case we
	# enable it in the inspector).
	if Engine.is_editor_hint():
		return

	# check if it's time to pick a new point, either:
	# (a) when it's been `recalculate_interval_seconds` since the last time we did, or
	# (b) if we reached a point and waited there for `max_stop_time_seconds`
	_seconds_since_last_recalculate += delta
	if _seconds_since_last_recalculate >= recalculate_interval_seconds or _seconds_since_stop >= max_stop_time_seconds:
		_recalculate()

	# stop if we're close enough to the point (and keep track of how long we've been stopped), or keep moving
	if character.global_position.distance_squared_to(_target_position) <= stop_radius * stop_radius:
		if direction.value == Vector2.ZERO:
			# we're at the point- track how long we're there
			_seconds_since_stop += delta
		else:
			# we've just reached the point- stop
			direction.value = Vector2.ZERO
			_seconds_since_stop = 0.0
	else:
		# not close to the point- keep moving
		direction.value = _target_position - character.global_position

func _recalculate() -> void:
	# pick a random point in the circle, at least half the circle's radius from where we currently are
	_seconds_since_last_recalculate = 0.0
	var angle := randf_range(0.0, TAU)
	var distance := randf() * radius
	_target_position = _roam_origin + Vector2(distance * cos(angle), distance * sin(angle))
