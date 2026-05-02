# 🎮 Demo: Cletus Loves Apples

## 📝 Summary
This demo contains a complete game about a friendly chap called Cletus who *really* loves apples.

### 🕹️ What It Does
Cletus is a person with clear priorities in life:
1. **🍎 Apple Priority:** Whenever an apple is near, Cletus will blindly walk to eat and eat it.
2. **👻 Survival Instinct:** Whenever enemy slimes are near and *no apple is in sight*, Cletus will
flee from the slimes.
3. **⌨️ Manual Control:** Whenever Cletus isn't doing either of the above, he will respond to your
movement input.

The aim of the game is simple: Collect as many apples as possible before succumbing to the endless
horde of slimes.

### 🎓 What It Teaches
The demo makes use of state machines in the following ways:
1. **🌍 Main State Machine:** Controls the flow between the menu and the running game.
2. **🖱️ Menu State Machine:** Manages the UI buttons and their interactions with the game.
3. **👤 Character State Machine:** For Cletus's AI and movement.
4. **🦠 Enemy State Machine:** For the slimes.

The state machines are modeled in their respective scenes (with the exception of the apple scene
which doesn't need one), and linked to each other as nested state machines starting with the main
state machine.

The main lesson in this demo is that of **separation of concerns**—keeping things organized by
keeping related nodes in their respective scene files, and keeping behaviors small and focused on
single tasks so they can be easily added to states, moved around as the game evolves, and reused
across state machines.

The demo also includes a simple **saving and loading** capability (which is also used to restart the
game) to illustrate how to save and load state machine data in your game.

**💡 Experimentation Ideas:**
* ⏳ Make apples disappear after a timeout.
* ❤️ Give Cletus health that replenishes when eating an apple and display a health bar.
* 🔊 Add sounds that play when Cletus starts moving to an apple, eats it, or evades a slime.
* 🎵 Add music that changes based on which state Cletus is in.
* 🗺️ Add obstacles and make Cletus and the slimes use pathfinding to get around them.
* 🤝 Contribute your improvements [on GitHub](https://github.com/gklompje/godot-synapse)!

## 💡 Additional Notes
There are far too many distinct behaviors and interactions to unpack in this short reference, but
we are planning to add a complete tutorial for building the game from scratch. Look out for that in
[Tutorial: Building a Complete Game](../../docs/tutorials/game.md).

In the meantime, play the game and think about what could be happening behind the scenes. Then, open
up the scene files and have a look at how the state machines are modeled. You should also look
through the behavior scripts since that's where all the game logic lives.


| [⬅️ Back to Demos](../README.md) |
| :---: |
