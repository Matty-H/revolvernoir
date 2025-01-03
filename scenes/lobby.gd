extends Node

@onready var player_1_label: Label = $Player1
@onready var player_2_label: Label = $Player2
@onready var lobby: VBoxContainer = $"."
@onready var start_menu: VBoxContainer = $"../Start_menu"

# Signals
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

# Network Constants
const PORT = 7000
const VALIDATION_PORT = 7001
const MAX_CONNECTIONS = 2
const SERVER_IDENTIFIER = "GAME_SERVER_V1"

# Variables
var server_ip = "127.0.0.1"
var players = {}  # Player info for every connected player
var player_info = {"name": "Name"}  # Local player info
var players_loaded = 0  # Nombre de joueurs chargés

# --- Lifecycle Functions ---
func _ready():
	_connect_signals()
	_reset_labels()

# --- Hosting and Joining Functions ---
func host_game():
	server_ip = _get_local_ip()
	print("Hosted on ", server_ip)
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	_add_local_player(1)

func join_game():
	var address = _get_local_ip()
	if address.is_empty():
		print("No server found.")
		return
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error != OK:
		print("Failed to connect to server.")
		return
	multiplayer.multiplayer_peer = peer


# --- Signal Handlers ---
func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	_update_labels()

func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)
	_update_labels()

func _on_connected_ok():
	_add_local_player(multiplayer.get_unique_id())

func _on_connected_fail():
	_remove_multiplayer_peer()

# --- Utility Functions ---
func _connect_signals():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)

func _add_local_player(peer_id):
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

func _reset_labels() -> void:
	player_1_label.text = "Host: Waiting..."
	player_2_label.text = "Player 2: Waiting..."

func _update_labels() -> void:
	player_1_label.text = "Host: " + ("Hosting" if multiplayer.is_server() else "Connected" if players.has(1) else "Waiting...")

	var other_player_ids = players.keys()
	other_player_ids.erase(1)
	player_2_label.text = "Player 2: " + (str(other_player_ids[0]) if other_player_ids else "Waiting...")

func _get_local_ip() -> String:
	var interfaces = IP.get_local_interfaces()
	for interface in interfaces:
		for address in interface.addresses:
			if address.begins_with("192.168.1."):
				return address
	return ""

# --- Game Scene Management ---
@rpc("call_local", "reliable")
func load_game(game_scene_path):
	get_tree().change_scene_to_file(game_scene_path)

@rpc("any_peer", "reliable")
func player_ready():
	# Le joueur signale qu'il est prêt
	var player_id = multiplayer.get_unique_id()
	players[player_id].ready = true  # On marque ce joueur comme prêt

	if multiplayer.is_server():
		players_loaded += 1
		if players_loaded == 2:
			_launch_game_scene()
			_reset_players_loaded()

	# Envoyer un RPC pour notifier aux autres joueurs que ce joueur est prêt
	rpc("notify_player_ready", player_id)

@rpc("any_peer", "reliable")
func notify_player_ready(player_id):
	_update_ready_status(player_id)

func _update_ready_status(player_id):
	# Mettez à jour l'interface de chaque joueur avec l'état prêt du joueur
	if player_id == 1:
		player_1_label.text = "Host: Ready"
	else:
		player_2_label.text = "Player 2: Ready"

func _launch_game_scene():
	rpc("load_game", "res://scenes/interface.tscn")


func _reset_players_loaded():
	players_loaded = 0

# --- Disconnecting ---
func disconnect_from_server():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		_remove_multiplayer_peer()
		server_disconnected.emit()
		start_menu.visible = true
		lobby.visible = false

func _remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null

func leave_lobby():
	disconnect_from_server()
	_reset_labels()
	print("Left the lobby.")
