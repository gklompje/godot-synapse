# 🔗 Demo: Multiplayer

## 📝 Summary
This demo showcases Synapse's multiplayer synchronization capabilities.

### 🕹️ What It Does
The main demo scene ([multiplayer_demo.tscn](multiplayer_demo.tscn)) contains a simple UI with a
color picker and a "spawn client" button. When pressed, the server spawns a new Godot process for
each new client. The client will connect to the server and request that the server spawns a
character for it with the specified color.

Each client's character is controllable only from that client. You can see this by focusing a given
client's window and pressing the arrow keys to move the character around (the
`ui_[up,down,left,right]` actions, in case you re-mapped them in your project).

Notice that the server cannot control any characters, but it shows the location of all the client
characters. Similarly, all other clients can see the movement of all other clients, but each client
can only control its own character.

### 🎓 What It Teaches
All the character movement synchronization is controlled by a Synapse state machine. The state
machine itself is configured to enforce the "rules" around which multiplayer peer can do what. If
you open up the character scene ([character.tscn](character.tscn)) and inspect the state machine,
the following settings are of particular note:
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

The main lesson from this demo is to outline how to synchronize a Synapse state machine across
multiplayer peers, which amounts to:
1. Deciding which **behaviors** are *executed on* which multiplayer peers by setting their
***execution mode***s.
1. Deciding which **parameters** are *replicated from* which multiplayer peer(s) using their
***replication mode***s.
1. Setting each peer state machine's multiplayer authority to match your desired setup.
1. Making sure the state machine is configured to synchronize across peers using Godot's high-level
API.

Try changing some of the parameter replication and behavior execution modes to see how it affects
the demo! You can learn more about Synapse multiplayer support, including custom (e.g. low-level
API) replication, in the [Multiplayer](../../docs/manual/multiplayer.md) documentation.

---

## 💡 Additional Notes

### 🌐 Connection Flow
The demo uses a structured setup to manage networking outside of the state machine:
- **Server Initialization:** [multiplayer_demo.gd](multiplayer_demo.gd) starts the host server.
- **Client Arguments**: The server launches [client.tscn](client.tscn) instances and passes the
chosen color via command-line arguments.
- **RPC Spawning**: [client.gd](client.gd) automatically connects and uses an RPC method via
[rpc_bridge.gd](rpc_bridge.gd) to request a character spawn.
- **Authority Assignment**: The server instantiates the character and syncs it using a
`MultiplayerSpawner`, assigning network authority to the connecting client's ID.

### 🎭 Asymmetric Scenes
Clients and servers in this demo use separate scenes rather than identical ones. Because Godot's
`MultiplayerSpawner` and RPC systems expect matching node paths by default, the RPC script sets the
`MultiplayerRoot` node as its root path. This ensures all network actions resolve correctly across
differing structures.

(In hindsight, this really wasn't necessary and we could have just added the UI elements from a
single script using the client/server differentiation to pick its setup, but it does have the
advantage of making the whole scene more understandable compared to a single scene/script.)

### 🐛 Console Debugging
The demo includes a separate TCP server ([debug_server.gd]) and client ([debug_client.gd]) that are
responsible for printing those pretty colored messages you see in the console when running the demo.
While they're not required for the demo or Synapse, they came in pretty handy when debugging
multiplayer issues during the development of the demo!

---


| [⬅️ Back to Demos](../README.md) |
| :---: |
