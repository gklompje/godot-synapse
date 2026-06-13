## A simple dedicated TCP server that prints color-highlighted messages received from clients.
class_name SynapseMultiplayerDebugServer
extends Node

const SERVER_IP := "127.0.0.1"
const SERVER_PORT := SynapseMultiplayerDemo.SERVER_PORT + 1

var color := Color.CYAN # the server's local message color

var _debug_server := TCPServer.new()
var _debug_client_connections: Array[StreamPeerTCP] = []

func _ready() -> void:
	var error := _debug_server.listen(SERVER_PORT, SERVER_IP)
	if error != OK:
		push_error("Unable to start debug server: ", error_string(error))
		get_tree().quit()

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

## For the server process to locally print messages
func debug_log(...args: Array) -> void:
	_debug_print({ "message": str.callv(args) })

func _debug_print(data: Dictionary) -> void:
	var identity: String = data.get("identity", "Server")
	var pid: int = data.get("pid", OS.get_process_id())
	var message: String = data.get("message", "")
	var client_color: String = data.get("color", color.to_html(false))

	var tag := "[%s (PID: %d)]" % [identity.to_upper(), pid]
	print_rich("[color=#%s]%s[/color] %s" % [client_color, tag, message])
