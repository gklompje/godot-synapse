## Serves as the common RPC node script for clients and the server to spawn characters.
class_name SynapseDemoMultiplayerRPCBridge
extends Node2D

## Emitted on the server when a client successfully connected and a character was spawned for it.
signal client_registered(id: int, color: Color)

@onready var character_spawner: MultiplayerSpawner = %CharacterSpawner

func _ready() -> void:
	# set the RPC bridge root path
	# (has to be done before the peer is connected or the MultiplayerSpawner won't work)
	(multiplayer as SceneMultiplayer).root_path = get_path()

	# set the multiplayer spawner's custom spawn function
	character_spawner.spawn_function = _spawn_character

## RPC function called by clients when they connect. Calls [method spawn_character] to spawn a
## character for the new client, and emits [signal client_registered] so the server process can do
## some housekeeping.
@rpc("any_peer", "call_remote", "reliable")
func register_client(color: Color) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	spawn_character(peer_id, color)
	client_registered.emit(peer_id, color)

## Called by the server after a client connects to instruct the multiplayer spawner to spawn the
## new client's character (across all peers).
func spawn_character(id: int, color: Color) -> void:
	if not multiplayer.is_server():
		return
	var spawn_data := {
		"peer_id": id,
		"color": color,
	}
	character_spawner.spawn(spawn_data)

## Called by the server when a client disconnects to instruct the multiplayer spawner to remove the
## client's character (from all peers).
func despawn_character(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for node in character_spawner.get_node(character_spawner.spawn_path).get_children():
		if node.get_multiplayer_authority() == peer_id:
			node.queue_free()
			return

## Called by the multiplayer spawner to instantiate the character scene in the current peer's scene
## tree. Sets the spawned character's multiplayer authority, color, and a unique node name according
## to the data sent via [method spawn_character].
func _spawn_character(data: Variant) -> Node:
	var character := (load(SynapseMultiplayerDemo.SCENE_CHARACTER) as PackedScene).instantiate() as SynapseDemoMultiplayerCharacter
	@warning_ignore("unsafe_cast")
	character.set_multiplayer_authority(data["peer_id"] as int)
	character.color = data["color"]
	character.name = "CharacterForPeer" + str(data["peer_id"])
	return character
