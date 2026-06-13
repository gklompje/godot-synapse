## Client for [SynapseMultiplayerDebugServer]. Sends log messages to the server to be printed by
## that process.
class_name SynapseMultiplayerDebugClient
extends Node

@export var client_name: String
@export var client_color: Color = Color.WHITE
@export var message_buffer_size := 100

var _is_connected := false
var _connection_time := 0.0
var _client := StreamPeerTCP.new()
var _message_buffer: Array[Dictionary] = []

func _ready() -> void:
	var error := _client.connect_to_host(SynapseMultiplayerDebugServer.SERVER_IP, SynapseMultiplayerDebugServer.SERVER_PORT)
	if error != OK:
		push_error("Failed to initialize debug client: ", error_string(error))

func _process(_delta: float) -> void:
	var error := _client.poll()
	if error != OK:
		push_error("Received error on poll: ", error_string(error))
		get_tree().quit()
		return

	var status := _client.get_status()
	match status:
		StreamPeerTCP.STATUS_CONNECTING:
			_connection_time += _delta
			if _connection_time > 5.0:
				push_error("Failed to connect- giving up!")
				_client.disconnect_from_host()
		StreamPeerTCP.STATUS_CONNECTED:
			_is_connected = true
			for data in _message_buffer:
				_client.put_var(data)
			_message_buffer.clear()
		_:
			if _is_connected:
				push_warning("Disconnected with status: ", status)
				_is_connected = false

func debug_log(...args: Array) -> void:
	var data := {
		"identity": client_name,
		"color": client_color.to_html(false),
		"pid": OS.get_process_id(),
		"message": str.callv(args),
	}
	if _is_connected:
		_client.put_var(data)
	else:
		_message_buffer.append(data)
		if _message_buffer.size() > message_buffer_size:
			push_warning("Message buffer overflow, dropping message: ", _message_buffer.pop_front())
