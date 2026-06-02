class_name SynapseMultiplayerDebugClient
extends Node

signal connected

@export var client_name: String
@export var client_color: Color = Color.WHITE

var _was_connected := false
var _connection_time := 0.0
var _client := StreamPeerTCP.new()

func _ready() -> void:
	var error := _client.connect_to_host(SynapseMultiplayerDemo.DEBUG_SERVER_IP, SynapseMultiplayerDemo.DEBUG_SERVER_PORT)
	if error != OK:
		push_error("Failed to initialize debug client: ", error_string(error))

func _process(_delta: float) -> void:
	var error := _client.poll()
	if error != OK:
		push_error("Received error on poll: ", error_string(error))
		get_tree().quit()
		return
	var status := _client.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTING:
		_connection_time += _delta
		if _connection_time > 5.0:
			push_error("Failed to connect- giving up!")
			get_tree().quit()
		return
	elif status == StreamPeerTCP.STATUS_CONNECTED:
		if not _was_connected:
			connected.emit()
		_was_connected = true
	else:
		push_error("Peer status not connected: ", status)
		get_tree().quit()
		return

func debug_log(message: String, type: String = "print") -> void:
	if _client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var data := {
			"identity": client_name,
			"color": client_color.to_html(false),
			"pid": OS.get_process_id(),
			"message": message,
			"type": type
		}
		_client.put_var(data)
	else:
		print("[Local Fallback] ", message)
