# Multiplayer State Machines

## Overview
A Synapse state machine can contain an arbitrary number of states, behaviors, parameters, etc. When
building a multiplayer game, you want to control how each component behaves depending on which
multiplayer peer it is running in.

In order to understand how Synapse state machines handle multiplayer synchronization, you must first
understand the basics about Godot's multiplayer support, which you can find in the project's
[Networking](https://docs.godotengine.org/en/stable/tutorials/networking/index.html) documentation.
In particular, you need to understand the difference between the high-level and low-level APIs
because you will need to choose which one Synapse uses.

## Prerequisites
When designing a multiplayer state machine, you will need to decide how you want to organize your
game. In particular, you need to choose whether you follow a server/client model and decide which
peer is authoritative for a given state machine. With that in mind, Synapse multiplayer support is
built around each state machine being able to identify:
1. Whether it is running on the *server* ([`MultiplayerAPI.is_server()`](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html#class-multiplayerapi-method-is-server)), and
2. Whether it is running on the peer that is authoritative for the state machine node ([`Node.is_multiplayer_authority()`](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-is-multiplayer-authority))

The above applies irrespective of which multiplayer API you use. When using a custom low-level API,
you must still ensure that `MultiplayerAPI.is_server()` and `Node.is_multiplayer_authority()`
return appropriate values for use by the state machine.

🚧 Coming soon! 🚧

TODO: allow execution/replication modes to be set separately from high-level API enablement!

Synapse multiplayer support is configured *at the state machine level*. This means that each
individual state machine is responsible for synchronizing all of its contained entities with its
equivalent state machine across multiplayer peers.

## What Synapse Provides
There are two key aspects that drive how a state machine behaves in a multiplayer environment:
1. [Behavior execution](#-behavior-execution-modes): You will want Certain behaviors to only execute
on some peers, for example an input handling behavior for controlling a specific player's character.
2. [Parameter replication](#-parameter-replication-modes): In many cases you want to share things
like a character's position with other peers, which requires replicating the parameter's value
across the network.

Synapse does **not** handle the spawning of state machines across the network.

### Behavior Execution Modes
Behaviors will execute on all multiplayer peers by default, but you can choose to restrict execution
of any given behavior based on which multiplayer peer it is running in.

Each behavior has a **multiplayer execution** parameter that you can set via the inspector or
directly on the behavior node in the Synapse editor (if you don't see the widget, make sure you
enable multiplayer support on your state machine per the [Prerequisites](#-prerequisites)):

<p align="center">
  <img src="./media/behavior_execution_mode.png" alt="The behavior multiplayer execution mode option" />
</p>

The options are as follows:

🚧 Coming soon! 🚧 TODO: List (with light/dark icons)

### Parameter Replication Modes
Parameters are **not** shared across multiplayer peers by default, meaning each peer has its own
value for the parameter that is independent of other peers.

In a multiplayer environment you want some peers to be responsible for updating a parameter and have
those updates reflected on other peers. For example, when the server updates player scores or when a
player updates their character's position. You can do this from the Synapse editor:

<p align="center">
  <img src="./media/parameter_replication_mode.png" alt="The parameter multiplayer replication mode option" />
</p>

The options are as follows:

🚧 Coming soon! 🚧 TODO: List (with light/dark icons)

🚧 Coming soon! 🚧 TODO: Validation

## High-level vs. Low-level
If you're already familiar with Godot multiplayer support, you'll know which side of this fence your
project is on. If not, it is recommended that you use the high-level API because it abstracts away
a lot of the complexity of multiplayer synchronization, at the cost of being less flexible and more
opinionated about the implementation.

### Using the High-level API

🚧 Coming soon! 🚧

### Using the Low-level API

🚧 Coming soon! 🚧

| [← Previous: Working with Signals](signals.md) | [Manual](README.md) |
-| :--- | ---: |
