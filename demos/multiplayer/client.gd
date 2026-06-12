extends Node

@onready var debug_client: SynapseMultiplayerDebugClient = %SynapseMultiplayerDebugClient
@onready var multiplayer_root: SynapseDemoMultiplayerRPCBridge = %MultiplayerRoot
@onready var label: Label = %Label

func _ready() -> void:
	var color := Color.WHITE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(SynapseMultiplayerDemo.ARG_CLIENT_COLOR):
			color = Color(arg.substr(len(SynapseMultiplayerDemo.ARG_CLIENT_COLOR) + 1))
	label.add_theme_color_override("font_outline_color", color)

	# must be done before we add the multiplayer peer (ot things like MultiplayerSpawner will break)
	(multiplayer as SceneMultiplayer).root_path = multiplayer_root.get_path()

	# connect to server
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(SynapseMultiplayerDemo.SERVER_IP, SynapseMultiplayerDemo.SERVER_PORT)
	if error:
		push_error("Client unable to connect to server: ", error_string(error))
		get_tree().quit()
		return
	multiplayer.multiplayer_peer = peer

	# register
	debug_client.client_color = color
	debug_client.client_name = "Client %d" % [multiplayer.multiplayer_peer.get_unique_id()]
	debug_client.debug_log("Connected")
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected.bind(color))

func _on_multiplayer_peer_connected(peer_id: int, color: Color) -> void:
	if peer_id != 1:
		return
	multiplayer_root.register_client.rpc(color)
