# Core Concepts
## <img src="../addons/synapse/icons/state_machine.svg" width="18" height="18"> State Machine
A state machine like most others. A state machine needs a root state (the entry point), and manages
all the internal stuff around entering and exiting states.

## <img src="../addons/synapse/icons/root_state.svg" width="18" height="18"> State
Unlike many state machine implementations, this addon doesn't model the states themselves as nodes.
States can have arbitrary relationships that the scene tree can't visually represent (because it's a
tree, not an arbitrary graph). States are just entry points for game logic, but don't *do* much by
themselves. States can be either active (when entered), or inactive (when exited).

States aren't entered/exited directly, but rather through the actions of their parent states (or the
state machine itself in the case of the root state). The next few sections describe the various
parent state types available out-of-the-box, but you can also create your own custom state types.

***Note:*** *States are only created when the state machine initializes at runtime (what you see in
the editor is just a visual representation of their configuration).*

## <img src="../addons/synapse/icons/behavior.svg" width="18" height="18"> Behavior
Behaviors are the brains of the state machine. Where [States](#-state) specify control flow,
behaviors implement logic. A behavior is just a node assigned to a particular state (called its
owner). The state machine will suspend and unsuspend it in accordance with its owner state.
Behaviors are meant to be extended, making them ideal extension points for integrating your game
logic with the state machine.

You can place behavior nodes anywhere in the scene tree, including nested within sub-scenes. The
editor can also create them for you from a script, in which case they're just created as children of
the state machine- such behavior nodes are called "managed" because the editor will delete them when
no longer referenced in the state machine. Because behaviors are independent of the structure of the
state machine, you can easily restructure your state machine and re-assign behaviors to different
states as your game's needs evolve.

## <img src="../addons/synapse/icons/parameter.svg" width="18" height="18"> Parameter
Essentially just a wrapper around a variable of your choosing. Parameters are modeled as resources
in Godot, which means they can be shared anywhere in your game, and they can maintain persistent
state for things like saving and loading.

Behaviors can read and write to parameters, which is visually represented in the editor to make it
easy to see how the data in your game flows within the state machine.

Default parameters for most Godot standard types are included, but you can create your own
parameters for your game's custom types.

## <img src="../addons/synapse/icons/signal_bridge.svg" width="18" height="18"> Signal Bridge
An adaptor that allows you to assign any combination of values to a target method. Mainly used to
connect a signal to a method with an incompatible signature, but is also useful when wanting to
"wire in" method arguments from different sources.

A signal bridge exposes a connectable input for each method argument, and supports two ways of
supplying a value:
1. **Wiring** in a compatible signal argument, by selecting it from the list of options.
2. **Linking** to a value specified elsewhere, such as the name of a state or a
[Parameter](#-parameter) value.

A signal bridge must have all required method arguments specified, or it will not initialize at
runtime. Any unspecified arguments with default values will automatically revert to their defaults.

Using signal bridges is more flexible than using `Callable.bind()` since it supports arbitrary
argument assignment order- they only require that you specify all arguments that don't have
defaults in the target method. Note, however, that this flexibility comes at a slight performance
cost as each parameter is internally connected through a sub-method that is invoked each time the
signal fires.

| [Back to Documentation](./README.md) |
| :---: |
