extends Node2D

@onready var debug_client: SynapseMultiplayerDebugClient = %SynapseMultiplayerDebugClient
@onready var multiplayer_root: SynapseDemoMultiplayerRPCBridge = %MultiplayerRoot

func _ready() -> void:
	# must be done before we add the multiplayer peer (ot things like MultiplayerSpawner will break)
	(multiplayer as SceneMultiplayer).root_path = multiplayer_root.get_path()
	multiplayer_root.client_connected.connect(_on_client_connected)

	# start server
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip(SynapseMultiplayerDemo.SERVER_IP)
	var error := peer.create_server(SynapseMultiplayerDemo.SERVER_PORT, SynapseMultiplayerDemo.SERVER_MAX_CLIENTS)
	if error:
		push_error("Unable to start server: ", error_string(error))
		get_tree().quit()
		return
	multiplayer.multiplayer_peer = peer

	debug_client.debug_log("Initialized")

func _on_client_connected(id: int, color: Color) -> void:
	debug_client.debug_log("Client registered: ID=%d, color=#%s" % [id, color.to_html(false)])
	multiplayer_root.spawn_character(id, color)
