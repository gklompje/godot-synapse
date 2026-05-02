# Tutorial: Creating Custom Parameters
Creating a custom parameter is very simple- you just copy some code and replace a couple of type
declarations. The main reasons why you would want to define custom parameters for your own game
objects are:
1. To share them between behaviors in your state machines.
1. To save and load their values with a state machine.
1. To leverage [Static typing in GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html).

Note that parameters are `Resource`s, which means their value types must be serializable - see
Godot's [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html)
docmentation for more details.

A parameter script only has to satisfy the following requirements:
1. It must inherit from `SynapseParameter`.
1. It must have a global class name.
1. It must define an exported property called `value`.
1. It must define a signal called `value_set` that is emitted whenever `value` is *set* (not just
when it changes).

Let's say you have a custom resource called `Damage` that can have a damage value and an elemental
damage type, for example:
```gdscript
class_name Damage
extends Resource

enum ElementType {
	NONE,
	FIRE,
	ICE,
	POISON,
}

@export var element_type: ElementType
@export var damage_value: float
```

The corresponding parameter implementation will look like this:
```gdscript
class_name DamageParameter
extends SynapseParameter

signal value_set(new_value: Damage)

@export var value: Damage:
	set(new_value):
		value = new_value
		value_set.emit(new_value)
```

That's all there is to it. When you save the parameter script, Synapse will automatically pick it up
and you will be able to add it to your state machines right away!

## Saving and Loading
When the state machine is saved it captures the values of all its parameters and restores them when
loading. For most cases, you don't need to do anything special- it just works. However, if you want
to customize how your parameter's value is stored (for example if it references a complex type like
a `Node` and you want to only save the path to that node, not the node itself), you can do that by
overriding the `get_value_for_saving` and `set_from_saved_value` methods. The default
implementations simply return and set the parameter's `value` property, but depending on how you
plan to serialize the state machine's save data this may not work if the value type is not trivially
serializable, like a custom class.

| [Tutorials](README.md) | [Next: Creating Custom Behaviors →](custom_behaviors.md) |
| :--- | ---: |
