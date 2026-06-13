## Main server scene for the Synapse multiplayer demo.
class_name SynapseMultiplayerDemo
extends Node

const ARG_USER_SEPARATOR := "--" # separates Godot process arguments from custom (user) arguments
const ARG_CLIENT_COLOR := "--color" # custom argument that specifies the client color

const SCENE_CLIENT := "uid://chmffnipntsqm" # used to spawn the client process
const SCENE_CHARACTER := "uid://c068lu73a18jd" # the character scene spawned by the multiplayer spawner

# server settings
const SERVER_IP := "127.0.0.1"
const SERVER_PORT := 30_662
const SERVER_MAX_CLIENTS := 32

@onready var color_picker_button: ColorPickerButton = %ColorPickerButton
@onready var multiplayer_root: SynapseDemoMultiplayerRPCBridge = %MultiplayerRoot
@onready var debug_server: SynapseMultiplayerDebugServer = $SynapseMultiplayerDebugServer

## Keeps track of spawned client processes (so we can terminate them when the server closes)
var _spawned_pids: Array[int] = []

func _ready() -> void:
	# Ensures that we can reliably clean up client processes
	get_tree().set_auto_accept_quit(false)

	# just so we can log a pretty message when a client character spawns
	multiplayer_root.client_registered.connect(_on_multiplayer_root_client_registered)

	# create the server
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip(SERVER_IP)
	var error := peer.create_server(SERVER_PORT, SERVER_MAX_CLIENTS)
	if error:
		push_error("Unable to start server: ", error_string(error))
		get_tree().quit()
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)

	debug_server.debug_log("Initialized")

func _notification(what: int) -> void:
	# terminate all the client processes we spawned when the window is closed
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		for pid in _spawned_pids:
			if OS.is_process_running(pid):
				OS.kill(pid)
		get_tree().quit()

## Spawns a new client process when the "spawn client" button is pressed.
func _on_spawn_client_button_pressed() -> void:
	var args :PackedStringArray = [
		"--scene",
		SCENE_CLIENT,
		ARG_USER_SEPARATOR,
		"%s=%s" % [ARG_CLIENT_COLOR, color_picker_button.color.to_html(false)]
	]
	_spawned_pids.append(OS.create_instance(args))

## Log a message when the RPC bridge indicates a character was spawned for a newly connected client.
func _on_multiplayer_root_client_registered(peer_id: int, color: Color) -> void:
	debug_server.debug_log("Spawned character for client [color=#%s]%d[/color]" % [color.to_html(false), peer_id])

## Despawn a recently disconnected client's character scene (across all peers).
func _on_multiplayer_peer_disconnected(id: int) -> void:
	multiplayer_root.despawn_character(id)
	debug_server.debug_log("Despawned character for disconnected client ", id)
