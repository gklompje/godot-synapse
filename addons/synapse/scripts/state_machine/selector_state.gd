@icon("uid://duokvlfxebl1t")

## Exactly one contained state will always be selected
## When a state is selected while the selector state is active:
##   1. the currently selected state will be exited, and
##   2. the newly selected state will be entered
## When entered/exited, the selected state will be entered/exited accordingly
class_name SynapseSelectorState
extends SynapseState

const SAVE_DATA_SELECTED_STATE_NAME := &"selected_state_name"

var contained_states: Dictionary[StringName, SynapseState]
var selected_state: SynapseState
var allowed_transitions: Dictionary[StringName, Transitions] # key is the *source* state

# GDScript doesn't support nested typed collections
class Transitions extends RefCounted:
	var transitions: Array[StringName]
	var t: Dictionary[StringName, SynapseState] # key is the *target* state

	@warning_ignore("shadowed_variable")
	func _init(transitions: Array[StringName]) -> void:
		self.transitions = transitions

@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
func _init(name: StringName, contained_states: Array[SynapseState], allowed_transitions: Dictionary[StringName, Transitions] = {}, behaviors: Array[SynapseBehavior] = []) -> void:
	super(name, behaviors)
	assert(len(contained_states) > 0, "SynapseSelectorState must have at least one contained state")
	for state in contained_states:
		assert(not self.contained_states.has(state.name), "SynapseSelectorState with duplicate state: " + state.name)
		self.contained_states[state.name] = state

	var valid_transitions := allowed_transitions
	for state in contained_states:
		var transitions: Transitions = valid_transitions.get(state.name)
		if transitions:
			transitions.t = {}
			for to_state_name in transitions.transitions:
				assert(self.contained_states.has(to_state_name), "Invalid transition from " + state.name + " to unknown state: " + to_state_name)
				transitions.t[to_state_name] = self.contained_states[to_state_name]
	self.allowed_transitions = valid_transitions
	self.selected_state = contained_states[0]

func enter() -> void:
	super()
	self.selected_state.enter()

func exit() -> void:
	self.selected_state.exit()
	super()

func select(state_name: StringName) -> bool:
	var current_name := selected_state.name
	if state_name == current_name:
		return true

	var transitions: Transitions = allowed_transitions.get(current_name)
	if not transitions:
		push_error("[", name, "] No transitions from state '", current_name, "'")
		return false

	var target_state: SynapseState = transitions.t.get(state_name)
	if not target_state:
		push_error("[", name, "] No valid transition from '", current_name, "' to '", state_name, "'")
		return false

	if active:
		selected_state.exit()
		target_state.enter()
	self.selected_state = target_state
	return true

func is_selected(state_name: StringName) -> bool:
	return selected_state.name == state_name

func get_save_data() -> Dictionary:
	return {
		SAVE_DATA_SELECTED_STATE_NAME: selected_state.name,
	}

func load_save_data(save_data: Dictionary) -> void:
	# don't have to worry about exiting and entering the selected state here- this method is only called while the state machine is deactivated
	# (we intentionally don't call `select` here because there may not be a direct transition from the currently selected state to the saved selected state)
	@warning_ignore("unsafe_cast")
	selected_state = contained_states[save_data[SAVE_DATA_SELECTED_STATE_NAME] as StringName]
