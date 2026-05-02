@abstract
@icon("uid://r0bf3np5qisi")

## A lightweight wrapper around a variable of your choosing. Parameters are modeled as [Resource]s,
## which means they can be shared anywhere in your game, and they can maintain persistent state for
## things like saving and loading.[br][br]
## Parameters can be read by and written to by [SynapseBehavior]s and can be linked to signal bridges to be
## passed as method arguments. Signal bridges will always use the current value of the parameter
## when sending them, but you can also use them as "constants" in that context if their value is
## never written to.[br][br]
## Default parameters for many built-in Godot types exist, but you can create your own parameters
## for any type, including your game's custom types as long as they can be stored within a
## [Resource]. There are only two requirements for a parameter to be recognized by the addon:[br]
## 1. It must have an exported property called [code]value[/code], and[br]
## 2. It must define a signal called [code]value_set[/code] that accepts an argument of the same
## type as [code]value[/code]. It is standard practice for this signal to be emitted whenever
## [code]value[/code] is [i]set[/i], not just when it changes.[br]
## The above two conditions necessary because the editor exposes the setter for [code]value[/code]
## so signals can be connected to it, and it also exposes the [code]value_set[/code] signal to
## connect to other methods.[br][br]
## Here's an example of what a typical parameter implementation looks like:
## [codeblock]
## class_name MyTypeBehaviorParameter
## extends SynapseParameter
##
## signal value_set(new_value: MyType)
##
## @export var value: MyType:
## 	set(new_value):
## 		value = new_value
## 		value_set.emit(new_value)
## [/codeblock]
## [br]
## While you are free to add other methods etc. to your custom parameter, keep in mind that the
## addon treats parameters as simple single-value data carriers so you're probably better off
## modelling more complex shapes differently, for example as [Resource]s assigned to the parameter's
## [code]value[/code].
class_name SynapseParameter
extends Resource

@export var name: StringName

## Used at runtime as a target for signal bridges to set the value, and when loading saved data.
func set_value(new_value: Variant) -> void:
	set(&"value", new_value)

## Called by the state machine to retrieve this parameter's value for saving.[br][br]
## By default, this method returns the [code]value[/code] property as-is. However, should the value
## property's type not be serializable, this method and [method set_from_saved_value] should be
## overridden to produce and consume a custom value that is serializable.
func get_value_for_saving() -> Variant:
	return get(&"value")

## Called by the state machine to restore a previously saved value returned by
## [method get_value_for_saving].[br][br]
## The default implementation calls [method set_value] directly.
@warning_ignore("unused_parameter")
func set_from_saved_value(saved_value: Variant, state_machine: SynapseStateMachine) -> void:
	set_value(saved_value)
