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
const MAX_CONNECTIONS = 2

# Variables
var server_ip = "127.0.0.1"
var players = {}  # Player info for every connected player
var player_info = {
	"name": "",
	"ip_address": "",
	"is_ready": false
}
var players_loaded = 0

func _ready():
	player_info.ip_address = _get_local_ip()
	player_info.name = _get_name()
	_connect_signals()
	_reset_labels()

func _get_name() -> String:
	# Essaye différentes méthodes pour obtenir le nom de la machine
	if OS.has_environment("COMPUTERNAME"):  # Windows
		return OS.get_environment("COMPUTERNAME")
	elif OS.has_environment("HOSTNAME"):    # Linux/Mac
		return OS.get_environment("HOSTNAME")
	else:
		# Fallback : utilise la commande système appropriée
		var output = []
		if OS.get_name() == "Windows":
			OS.execute("hostname", [], output)
		else:  # Linux/Mac
			OS.execute("hostname", [], output)
		
		if output.size() > 0:
			return output[0].strip_edges()
		
		return "Dummy"

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
	players.clear()

# --- Utility Functions ---
func _connect_signals():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)

func _add_local_player(peer_id):
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

func _update_ready_status(player_id, status):
	# Met à jour seulement le statut ready dans les labels existants
	if players.has(player_id):
		players[player_id].is_ready = status
		_update_labels()  # Mise à jour complète des labels

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
	var player_id = multiplayer.get_unique_id()

	# Toggle the ready status for the player
	if players.has(player_id):
		players[player_id].is_ready = not players[player_id].is_ready

		# Update labels locally for the player who changed their status
		_update_labels()

	# Notify all players of the change in status
	rpc("notify_player_ready", player_id, players[player_id].is_ready)

	var all_ready = true
	for player in players.values():
		if not player.is_ready:
			all_ready = false
			break
	if all_ready:
		print("Start Game")


@rpc("any_peer", "reliable")
func notify_player_ready(player_id, status):
	_update_ready_status(player_id, status)

func _reset_labels() -> void:
	player_1_label.text = "Host: Waiting..."
	player_2_label.text = "Player 2: Waiting..."

func _update_labels() -> void:
	var host_info = "Host: " + ("Hosting" if multiplayer.is_server() else "Connected" if players.has(1) else "Waiting...")
	if players.has(1):
		host_info = "Host: %s | IP: %s | PC: %s | Ready: %s" % [
			"Hosting" if multiplayer.is_server() else "Connected",
			players[1].ip_address,
			players[1].name,
			str(players[1].is_ready)
		]
	player_1_label.text = host_info

	var other_player_ids = players.keys()
	other_player_ids.erase(1)
	var player2_info = "Player 2: Waiting..."
	if other_player_ids:
		var player_id = other_player_ids[0]
		player2_info = "Player 2: Connected | IP: %s | PC: %s | Ready: %s" % [
			players[player_id].ip_address,
			players[player_id].name,
			str(players[player_id].is_ready)
		]
	player_2_label.text = player2_info

func _launch_game_scene():
	rpc("load_game", "res://scenes/interface.tscn")

func _reset_players_loaded():
	players_loaded = 0

# --- Disconnecting ---
func disconnect_from_server():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		_remove_multiplayer_peer()
		players.clear()
		server_disconnected.emit()
		start_menu.visible = true
		lobby.visible = false

func _remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null

func leave_lobby():
	disconnect_from_server()
	_reset_labels()
	print("Left the lobby.")
