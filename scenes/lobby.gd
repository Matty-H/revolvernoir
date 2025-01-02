extends VBoxContainer

# Node References
@onready var control: Control = $".."
@export var spawn_level: PackedScene
@onready var level: Control = $"../level"
@onready var lobby: VBoxContainer = $"."
@onready var player_1_label: Label = $Player1
@onready var player_2_label: Label = $Player2
@onready var start_menu: VBoxContainer = $"../Start_menu"
@onready var interface: Control = $"../level/Interface"

# Network Constants
const PORT: int = 123
const DEFAULT_SERVER_IP: String = "127.0.0.1"
const MAX_CONNECTIONS: int = 2

# Variables
var players: Dictionary = {}
var player_info: Dictionary = {"name": "Name"}
var players_loaded: int = 0

# Signals
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected
signal server_shutdown

func _ready() -> void:
	_reset_labels()

# Network Methods
func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT) != OK:
		print("Failed to start multiplayer server.")
		return
	_setup_multiplayer_peer(peer)
	#_add_player(1)

func join_game(address: String = "") -> Error:
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		push_error("Failed to connect to server.")
		return error
	
	_setup_multiplayer_peer(peer)
	return OK

func _setup_multiplayer_peer(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# Player Management
@rpc("any_peer", "reliable")
func _register_player(new_player_info: Dictionary) -> void:
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	emit_signal("player_connected", new_player_id, new_player_info)
	_update_labels()

@rpc("any_peer", "reliable")
func player_loaded() -> void:
	if multiplayer.is_server():
		players_loaded += 1
		if players_loaded == players.size():
			$"/root/Game".start_game()
			players_loaded = 0

func _add_player(id: int) -> void:
	if not spawn_level:
		push_error("No spawn_level scene provided!")
		return
	
	var player_instance = spawn_level.instantiate()
	player_instance.name = str(id)
	call_deferred("add_child", player_instance)
	players[id] = player_info
	_update_labels()

func _remove_player(peer_id: int) -> void:
	players.erase(peer_id)
	emit_signal("player_disconnected", peer_id)
	_update_labels()

@rpc
func notify_disconnect(peer_id: int) -> void:
	print("Peer déconnecté : ", peer_id)

@rpc("any_peer", "reliable")
func _disconnect_from_server() -> void:
	multiplayer.multiplayer_peer.close()		

# Level Management
func _change_level(scene: PackedScene) -> void:
	if not scene:
		push_error("Invalid scene provided!")
		return
	
	for child in level.get_children():
		level.remove_child(child)
		child.queue_free()
	
	var new_level = scene.instantiate()
	level.add_child(new_level)

@rpc("call_local", "reliable")
func load_game(game_scene_path: String) -> void:
	get_tree().change_scene_to_file(game_scene_path)

# Network Event Handlers
func _on_player_connected(peer_id: int) -> void:
	_register_player.rpc_id(peer_id, player_info)

func _on_player_disconnected(peer_id: int) -> void:
	_remove_player(peer_id)
	if peer_id == 1:
		print("Host disconnected! Shutting down the server...")
		if multiplayer.is_server():
			multiplayer.multiplayer_peer.quit()

func _on_connected_ok() -> void:
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	emit_signal("player_connected", peer_id, player_info)
	_update_labels()

func _on_connected_fail() -> void:
	print("Connection failed")
	pass

func _on_server_disconnected() -> void:
	players.clear()
	emit_signal("server_disconnected")

func _reset_labels() -> void:
	player_1_label.text = "Host: Waiting..."
	player_2_label.text = "Player 2: Waiting..."

func _update_labels() -> void:
	player_1_label.text = "Host: " + ("Hosting" if multiplayer.is_server() else "Connected" if players.has(1) else "Waiting...")
	
	var other_player_ids = players.keys()
	other_player_ids.erase(1)
	player_2_label.text = "Player 2: " + (str(other_player_ids[0]) if other_player_ids else "Waiting...")

@rpc("any_peer", "reliable")
func print_hello() -> void:
	lobby.visible = not lobby.visible
