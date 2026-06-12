class_name SynapseMultiplayerDemo
extends Node

const ARG_USER_SEPARATOR := "--"
const ARG_CLIENT_COLOR := "--color"

const SCENE_SERVER := "uid://chkp6qtolydwd"
const SCENE_CLIENT := "uid://chmffnipntsqm"
const SCENE_CHARACTER := "uid://c068lu73a18jd"
const SCENE_API_BRIDGE := "uid://cij8h2l0l1utw"

const SERVER_IP := "127.0.0.1"
const SERVER_PORT := 30_662
const SERVER_MAX_CLIENTS := 32

const DEBUG_SERVER_IP := "127.0.0.1"
const DEBUG_SERVER_PORT := SERVER_PORT + 1

@onready var color_picker_button: ColorPickerButton = %ColorPickerButton
@onready var multiplayer_root: SynapseDemoMultiplayerRPCBridge = %MultiplayerRoot

var _debug_server := TCPServer.new()
var _debug_client_connections: Array[StreamPeerTCP] = []

var _spawned_pids: Array[int] = []

func _ready() -> void:
	# Ensures that we can reliably clean up client processes
	get_tree().set_auto_accept_quit(false)

	# create the debug server
	var error := _debug_server.listen(DEBUG_SERVER_PORT, DEBUG_SERVER_IP)
	if error != OK:
		push_error("Unable to start debug server: ", error_string(error))
		get_tree().quit()

	# spawn the game server
	# must be done before we add the multiplayer peer (ot things like MultiplayerSpawner will break)
	(multiplayer as SceneMultiplayer).root_path = multiplayer_root.get_path()
	multiplayer_root.client_connected.connect(_on_client_connected)
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip(SynapseMultiplayerDemo.SERVER_IP)
	error = peer.create_server(SynapseMultiplayerDemo.SERVER_PORT, SynapseMultiplayerDemo.SERVER_MAX_CLIENTS)
	if error:
		push_error("Unable to start server: ", error_string(error))
		get_tree().quit()
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)

	debug_log("Initialized")

func _process(_delta: float) -> void:
	if _debug_server.is_connection_available():
		_debug_client_connections.append(_debug_server.take_connection())

	var disconnected_indices: Array[int] = []
	for i in range(_debug_client_connections.size()):
		var peer := _debug_client_connections[i]
		peer.poll()
		var status := peer.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			while peer.get_available_bytes() > 0:
				var data: Variant = peer.get_var()
				if data is Dictionary:
					@warning_ignore("unsafe_cast")
					_debug_print(data as Dictionary)
				else:
					push_error("Received unknown debug log data object: ", data)
		elif status != StreamPeerTCP.STATUS_CONNECTING:
			disconnected_indices.append(i)

	disconnected_indices.reverse()
	for index in disconnected_indices:
		_debug_client_connections.remove_at(index)

func _debug_print(data: Dictionary) -> void:
	var identity: String = data.get("identity", "Server")
	var pid: int = data.get("pid", OS.get_process_id())
	var message: String = data.get("message", "")
	var color: String = data.get("color", Color.CYAN.to_html(false))

	var tag := "[%s (PID: %d)]" % [identity.to_upper(), pid]
	print_rich("[color=#%s]%s[/color] %s" % [color, tag, message])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		for pid in _spawned_pids:
			if OS.is_process_running(pid):
				OS.kill(pid)
		get_tree().quit()

func _on_spawn_client_button_pressed() -> void:
	var args :PackedStringArray = [
		"--scene",
		SCENE_CLIENT,
		ARG_USER_SEPARATOR,
		"%s=%s" % [ARG_CLIENT_COLOR, color_picker_button.color.to_html(false)]
	]
	_spawned_pids.append(OS.create_instance(args))

func _on_client_connected(id: int, color: Color) -> void:
	debug_log("Registered client [color=#%s]%d[/color]" % [color.to_html(false), id])
	multiplayer_root.spawn_character(id, color)

func _on_multiplayer_peer_disconnected(id: int) -> void:
	multiplayer_root.despawn_character(id)
	debug_log("Deregistered disconnected client ", id)

func debug_log(...args: Array) -> void:
	_debug_print({ "message": str.callv(args) })
