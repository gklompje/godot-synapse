# 🔗 Demo: Multiplayer

## 📝 Summary
This demo showcases Synapse's multiplayer synchronization capabilities.

### 🕹️ What It Does
The main demo scene ([multiplayer_demo.tscn]) contains a simple UI with a color picker and a "spawn
client" button. When pressed, the server spawns a new Godot process for each new client. The client
will connect to the server and request that the server spawns a character for it with the specified
color.

Each client's character is controllable only from that client. You can see this by focusing a given
client's window and pressing the arrow keys to move the character around (the
`ui_[up,down,left,right]` actions, in case you re-mapped them in your project).

Notice that the server cannot control any characters, but it shows the location of all the client
characters. Similarly, all other clients can see the movement of all other clients, but each client
can only control its own character.

### 🎓 What It Teaches
All the character movement synchronization is controlled by a Synapse state machine. The state
machine itself is configured to enforce the "rules" around which multiplayer peer can do what. If
you open up the character scene ([character.tscn]) and inspect the state machine, the following
settings are of particular note:
 - The state machine itself has its "Multiplayer (High Level API)" setting enabled (this is usually
on by default, but does nothing if there isn't a multiplayer peer connected).
 - The `position` and `vector` (direction) parameters are set to replicate to other peers from their
owning client (parameters will **not** replicate to other peers by default).
 - The `DemoUpdateVectorOnActionInput`, which sets the `vector` parameter to the movement direction
when the arrow keys are pressed, is configured to only run on the state machine's multiplayer
authority, which is set to the client's ID when it connects to the server. This is what limits
movement to only the owning client, because the behavior is never unsuspended elsewhere.
- Similarly, `DemoPositionRecorder2D` just copies the character sprite node's global position to the
`position` parameter, but it also just runs on the owning client.
- On the other hand, the `DemoPositionReceiver2D` behavior is set to run on only the
non-authoritative peers, i.e. the server and other non-controlling clients. This behavior just does
the reverse- it sets the sprite's global position to the `position` parameter's value whenever it is
updated (which happens when remote peers replicate their position).
- Lastly, the `DemoSmoothMotion2D` just applies velocity in the direction of the movement `vector`.
This is what actually moves the sprite on the owning client, but this behavior is set to run on all
peers even though it doesn't have to so that the position updates are a bit smoother (this is also
why the `vector` parameter is replicated to peers).

Try changing some of the parameter replication and behavior execution modes to see how it affects
the demo!

The main lesson from this demo is that Synapse offers easy-to-use settings for you to set up a
multiplayer-enhanced state machine. Using them amounts to three things:
1. Deciding which **behaviors** are *executed* on which multiplayer peers, and setting their
***execution modes*** accordingly.
1. Deciding which **parameters** are *replicated* from which multiplayer peer(s), and setting their
***replication modes*** accordingly.
1. Making sure the state machine is configured to synchronize across peers using Godot's high-level
API (or not, if you want to handle this using your own multiplayer synchronization code).

---

## 💡 Additional Notes

### Multiplayer Structure
The demo itself contains a number of additional scripts to handle all the multiplayer setup, which
isn't the main focus of the demo but is commented quite heavily anyway so you can pick them apart if
you want to see how it's all put together.

The structure of the multiplayer setup is as follows:
 - The main demo scene ([multiplayer_demo.tscn]) has a script ([multiplayer_demo.gd]) that starts
the multiplayer server.
 - When the "spawn client" button is pressed, the server script starts a new Godot process using the
client scene ([client.tscn]) as a starting point, and passes it a command line argument containing
the selected color.
 - The client script ([client.gd]) then connects to the server automatically, and sends an RPC
method to the server (see [rpc_bridge.gd]) to spawn its character.
 - The character scene is instantiated *by the server* and replicated to all peers using a
`MultiplayerSpawner`, but the character scene's multiplayer authority is set to that of the newly
connected client so that the state machine in the character scene knows when to replicate its
parameters and execute its behaviors.

### Asymmetric Scenes
Normally in multiplayer games the client and server are running the exact same scenes, which makes
multiplayer synchronization using Godot's high-level multiplayer API easy. However, since we have
different scenes and the RPC methods multiplayer spawner rely on having identical scene paths by
default, the RPC script sets itself (the `MultiplayerRoot` node) as its multiplayer peer "root
path". That way, the RPC methods and the multiplayer spawner can find their counterparts across both
the server and client setups.

(In hindsight, this really wasn't necessary and we could have just added the UI elements from a
single script using the client/server differentiation to pick its setup, but it does have the
advantage of making the whole scene more modular and understandable compared to a single
scene/script that you have to reason about being in in either client or server mode.)

### Debugging
The demo also contains a separate TCP server ([debug_server.gd]) and client ([debug_client.gd]) that
are responsible for printing those pretty colored messages you see in the console output. They don't
really add much value to the demo, but they came in pretty handy when debugging multiplayer issues
during the development of the demo so feel free to use and adapt them in your own projects.

---


| [⬅️ Back to Demos](../README.md) |
| :---: |
