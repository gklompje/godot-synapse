class_name SynapseMultiplayerDemo
extends Control

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

var _debug_server := TCPServer.new()
var _debug_client_connections: Array[StreamPeerTCP] = []

var _spawned_pids: Array[int] = []

func _ready() -> void:
	# Ensures that we can reliably clean up server/client processes
	get_tree().set_auto_accept_quit(false)

	# create the debug server
	var error := _debug_server.listen(DEBUG_SERVER_PORT, DEBUG_SERVER_IP)
	if error != OK:
		push_error("Unable to start debug server: ", error_string(error))
		get_tree().quit()

	# spawn the game server process
	_spawn_process(SCENE_SERVER, true)

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
					print("WTF: ", data)
		elif status != StreamPeerTCP.STATUS_CONNECTING:
			disconnected_indices.append(i)

	disconnected_indices.reverse()
	for index in disconnected_indices:
		_debug_client_connections.remove_at(index)

func _debug_print(data: Dictionary) -> void:
	var identity: String = data.get("identity", "Unknown")
	var pid: int = data.get("pid", 0)
	var message: String = data.get("message", "")
	var type: String = data.get("type", "print")
	var color: String = data.get("color", Color.CYAN.to_html(false))

	var tag := "[%s (PID: %d)]" % [identity.to_upper(), pid]
	match type:
		"warn":
			print_rich("[color=#%s]%s[/color] [color=yellow][WARNING] %s[/color]" % [color, tag, message])
		"err":
			print_rich("[color=#%s]%s[/color] [color=red][ERROR] %s[/color]" % [color, tag, message])
		_:
			print_rich("[color=#%s]%s[/color] %s" % [color, tag, message])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		for pid in _spawned_pids:
			if OS.is_process_running(pid):
				OS.kill(pid)
		get_tree().quit()

func _spawn_process(scene: String, headless: bool = false, ...user_args: Array) -> void:
	var args := PackedStringArray()
	if headless:
		args.append("--headless")
	args.append_array(["--scene", scene])
	if user_args:
		args.append(ARG_USER_SEPARATOR)
		args.append_array(user_args)
	_spawned_pids.append(OS.create_instance(args))

func _on_spawn_client_button_pressed() -> void:
	_spawn_process(SCENE_CLIENT, false, ARG_CLIENT_COLOR + "=" + color_picker_button.color.to_html(false))
