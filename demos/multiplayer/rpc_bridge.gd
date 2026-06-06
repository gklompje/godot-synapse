class_name SynapseDemoMultiplayerRPCBridge
extends Node2D

@onready var character_spawner: MultiplayerSpawner = %CharacterSpawner

signal client_connected(id: int, color: Color)

func _ready() -> void:
	character_spawner.spawn_function = _spawn_character

@rpc("any_peer")
func register_client(color: Color) -> void:
	client_connected.emit(multiplayer.get_remote_sender_id(), color)

func spawn_character(id: int, color: Color) -> void:
	if not multiplayer.is_server():
		return
	var spawn_data := {
		"peer_id": id,
		"color": color,
	}
	character_spawner.spawn(spawn_data)

func _spawn_character(data: Variant) -> Node:
	var character := (load(SynapseMultiplayerDemo.SCENE_CHARACTER) as PackedScene).instantiate() as SynapseDemoMultiplayerCharacter
	@warning_ignore("unsafe_cast")
	character.set_multiplayer_authority(data["peer_id"] as int)
	character.color = data["color"]
	character.name = "CharacterForPeer" + str(data["peer_id"])
	return character
