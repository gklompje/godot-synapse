## Client scene for the Synapse multiplayer demo. Not intended to be run directly, but in a separate
## process spawned by the server.
extends Node

@onready var debug_client: SynapseMultiplayerDebugClient = %SynapseMultiplayerDebugClient
@onready var multiplayer_root: SynapseDemoMultiplayerRPCBridge = %MultiplayerRoot
@onready var label: Label = %Label

var color := Color.WHITE

func _ready() -> void:
	# parse command line arguments to determine this client's character color
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(SynapseMultiplayerDemo.ARG_CLIENT_COLOR):
			color = Color(arg.substr(len(SynapseMultiplayerDemo.ARG_CLIENT_COLOR) + 1))
	label.add_theme_color_override("font_outline_color", color)

	# connect to server
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(SynapseMultiplayerDemo.SERVER_IP, SynapseMultiplayerDemo.SERVER_PORT)
	if error:
		push_error("Client unable to connect to server: ", error_string(error))
		get_tree().quit()
		return
	multiplayer.multiplayer_peer = peer

	# debug client setup
	debug_client.client_color = color
	debug_client.client_name = "Client %d" % [multiplayer.multiplayer_peer.get_unique_id()]
	debug_client.debug_log("Connected")

	# register with the game server to spawn our character once we're connected
	multiplayer.connected_to_server.connect(_on_multiplayer_connected_to_server)

	# normally the server will clean up after itself, but make sure the client process dies if the
	# server process dies unexpectedly
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)

func _on_multiplayer_connected_to_server() -> void:
	multiplayer_root.register_client.rpc(color)

	# tighten timeouts to handle server disconnects so this client process doesn't outlive the
	# server by too much if it unexpectedly disconnects
	var server_peer := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(1)
	server_peer.set_timeout(1000, 1000, 2000)
	server_peer.ping_interval(1000)

func _on_multiplayer_server_disconnected() -> void:
	push_warning("Server disconnected- stopping client")
	get_tree().quit()
