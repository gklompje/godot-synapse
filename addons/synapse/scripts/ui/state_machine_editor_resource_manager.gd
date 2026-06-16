class_name SynapseStateMachineEditorResourceManager

class Scenes:
	static func instantiate_reorderable_list() -> SynapseEditorReorderableList:
		return (load("uid://mdbfb22n2xv5") as PackedScene).instantiate()

	static func instantiate_reorderable_list_item() -> SynapseEditorReorderableListItem:
		return (load("uid://d1gi1mhk4pmth") as PackedScene).instantiate()

	static func instantiate_graph_node_name_manager() -> SynapseStateMachineEditorGraphNodeNameManager:
		return (load("uid://c348aml4l32qk") as PackedScene).instantiate()

	static func instantiate_root_sentinel_graph_node() -> SynapseRootSentinelGraphNode:
		return (load("uid://b0rny5cgiji6d") as PackedScene).instantiate()

	static func instantiate_behavior_graph_node() -> SynapseBehaviorGraphNode:
		return (load("uid://bfeeedg0go824") as PackedScene).instantiate()

	static func instantiate_state_graph_node() -> SynapseStateGraphNode:
		return (load("uid://cn040cq6rtp2") as PackedScene).instantiate()

	static func instantiate_parameter_graph_node() -> SynapseParameterGraphNode:
		return (load("uid://d5qr254qfk7d") as PackedScene).instantiate()

	static func instantiate_signal_bridge_graph_node() -> SynapseSignalBridgeGraphNode:
		return (load("uid://cg8712w6lwowb") as PackedScene).instantiate()

	static func instantiate_signal_bridge_argument() -> SynapseSignalBridgeArgument:
		return (load("uid://g1g77xde2k0b") as PackedScene).instantiate()

	static func instantiate_state_machine_editor_dock_ui() -> SynapseStateMachineEditorDockUI:
		return (load("uid://casi77dn32ds4") as PackedScene).instantiate()

class UIDs:
	const VERSION_INFO_SCRIPT := "uid://dyarhkbobe5yt"

class Icons:
	enum {
		BEHAVIOR,
		BEHAVIOR_EXECUTION_EVERYONE,
		BEHAVIOR_EXECUTION_AUTHORITY_ONLY,
		BEHAVIOR_EXECUTION_NON_AUTH_ONLY,
		BEHAVIOR_EXECUTION_SERVER_ONLY,
		BEHAVIOR_EXECUTION_CLIENTS_ONLY,
		BEHAVIOR_EXECUTION_PROXIES_ONLY,
		PARAMETER,
		PARAMETER_REPLICATION_LOCAL,
		PARAMETER_REPLICATION_SERVER,
		PARAMETER_REPLICATION_CLIENT_PREDICTED,
		PARAMETER_REPLICATION_CLIENT_AUTH,
		SIGNAL_BRIDGE,
		STATE_MACHINE,
		STATE_ROOT,
		STATE_STATE,
		STATE_SELECTOR,
		STATE_COMBINER,
		STATE_SEQUENCE,
		UI_DELETE,
		UI_EDIT,
		UI_EXTERNAL_LINK,
		UI_ERASE_STATE_MACHINE,
		UI_HIDDEN,
		UI_ITEM_LIST_DOWN,
		UI_ITEM_LIST_UP,
		UI_METHOD,
		UI_SIGNAL,
		UI_VISIBLE,
	}

	static func get_icon(icon: int) -> Texture2D:
		match icon:
			BEHAVIOR:
				return load("uid://c1mjn5rsw7v6a")
			BEHAVIOR_EXECUTION_EVERYONE:
				return load("uid://d4kmgu6h4046t")
			BEHAVIOR_EXECUTION_AUTHORITY_ONLY:
				return load("uid://dujfdcpgh1n4")
			BEHAVIOR_EXECUTION_NON_AUTH_ONLY:
				return load("uid://d1m3hspwjyxi5")
			BEHAVIOR_EXECUTION_SERVER_ONLY:
				return load("uid://dalh370f68qh1")
			BEHAVIOR_EXECUTION_CLIENTS_ONLY:
				return load("uid://0qg4nn641a86")
			BEHAVIOR_EXECUTION_PROXIES_ONLY:
				return load("uid://rf0omcubyndv")
			PARAMETER:
				return load("uid://r0bf3np5qisi")
			PARAMETER_REPLICATION_LOCAL:
				return load("uid://ceo0o4ednx8po")
			PARAMETER_REPLICATION_SERVER:
				return load("uid://diuuh68opsnur")
			PARAMETER_REPLICATION_CLIENT_PREDICTED:
				return load("uid://cdbkbar1uevs8")
			PARAMETER_REPLICATION_CLIENT_AUTH:
				return load("uid://cys17gjltcpgn")
			SIGNAL_BRIDGE:
				return load("uid://cjtjo2ad7afpv")
			STATE_MACHINE:
				return load("uid://brducfl5b54hv")
			STATE_ROOT:
				return load("uid://cofpicxmcaeq0")
			STATE_STATE:
				return load("uid://db62s30spivmp")
			STATE_SELECTOR:
				return load("uid://duokvlfxebl1t")
			STATE_COMBINER:
				return load("uid://fjqcakgsj7rs")
			STATE_SEQUENCE:
				return load("uid://rg32ebo2fcoe")
			UI_DELETE:
				return load("uid://bjl2olq0y7l8l")
			UI_EDIT:
				return load("uid://ce2y8fyvecfwg")
			UI_EXTERNAL_LINK:
				return load("uid://d0vpmo3oo8f1x")
			UI_ERASE_STATE_MACHINE:
				return load("uid://lvyl3c45r1k7")
			UI_HIDDEN:
				return load("uid://bv22n8d1whaun")
			UI_ITEM_LIST_DOWN:
				return load("uid://ctx5luy4o5riy")
			UI_ITEM_LIST_UP:
				return load("uid://nx30g16qd8kk")
			UI_METHOD:
				return load("uid://bb82r05ae0nf1")
			UI_SIGNAL:
				return load("uid://dvurta8uf0vfg")
			UI_VISIBLE:
				return load("uid://sa0f753owp3n")
		push_error("No such icon: ", icon)
		return null
