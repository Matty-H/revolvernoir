extends Node

@export var running_local : bool = true

@onready var server: Node = $"."
@onready var player_1_label: Label = %Player1
@onready var player_2_label: Label = %Player2
@onready var lobby: VBoxContainer = %Lobby
@onready var start_menu: VBoxContainer = %Start_menu
@onready var bounding: Label = $Bounding

# Signals
signal player_connected(peer_id, room_info)
signal player_disconnected(peer_id)
signal server_disconnected

# Network Constants
const PORT : int = 6000
const MAX_CONNECTIONS : int = 2
const IP_RANGE : String = "192.168.1.255"

# Variables
var broadcastTimer : Timer
var broadcaster : PacketPeerUDP
var listener : PacketPeerUDP
var peer : ENetMultiplayerPeer
var joining : bool = false

var listenPort : int = PORT
var broadcastPort : int = listenPort+1

var server_ip = "127.0.0.1"
var players = {}  # Player info for every connected player
var room_info = {
	"name": "",
	"ip_address": "",
	"is_ready": false
}

func _process(delta):
	if not joining:
		return
	#if listener.get_available_packet_count() > 0:
		#var serverip : String = listener.get_packet_ip()
		#var serverport = listener.get_packet_port()
		#var bytes = listener.get_packet()
		#var data = bytes.get_string_from_ascii()
		#var roomInfo = JSON.parse_string(data)
		#print("Server Ip: " + serverip + " | Server Port: " + str(serverport))
		#
		#if serverip != "": #BUG GODOT ? Without, windows-builds bypass the error check on connection_server
			#connection_server(serverip)
		
		

func _ready():
	broadcastTimer = $BroadcastTimer
	listeningPort()
	room_info.ip_address = _get_self_local_ip()
	room_info.name = _get_name()
	_connect_signals()
	_reset_labels()
	
func listeningPort():
	listener = PacketPeerUDP.new()
	if listener.bind(listenPort) == OK:
		print("Find port to " + str(listenPort))
		bounding.text = "Can join: True"
	else:
		print("Failed to find")
		bounding.text = "Can join: False"

func setUpBroadcast():
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_broadcast_enabled(true)
	broadcaster.set_dest_address(IP_RANGE, listenPort)
	if broadcaster.bind(broadcastPort) == OK:
		print("Bounded to " + str(broadcastPort))
	else:
		print("Failed to bound")
	$BroadcastTimer.start()

func _on_broadcast_timer_timeout() -> void:
	print("Currenlty opened server")
	var data = JSON.stringify(room_info)
	var packet = data.to_ascii_buffer()
	broadcaster.put_packet(packet)
	pass # Replace with function body.

func cleanUp_UDP():
	$BroadcastTimer.stop()
	if listener != null:
		listener.close()
	if broadcaster != null:
		broadcaster.close()

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
	server_ip = _get_self_local_ip()
	print("Hosted on ", server_ip +":"+ str(PORT))
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		print("Create Server error" + str(error))
		return error
	multiplayer.multiplayer_peer = peer
	_add_local_player(1)

func join_game():
	if running_local: # Si on est en test local
		connection_server(_get_self_local_ip())
	else:
		listeningPort()
		joining = true


func connection_server(address : String):
	joining = false
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error != OK:
		print("Failed to connect to server.")
		return
	multiplayer.multiplayer_peer = peer

# --- Signal Handlers ---
func _on_player_connected(id):
	_register_player.rpc_id(id, room_info)

@rpc("any_peer", "reliable")
func _register_player(new_room_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_room_info
	player_connected.emit(new_player_id, new_room_info)
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
	players[peer_id] = room_info
	player_connected.emit(peer_id, room_info)

func _update_ready_status(player_id, status):
	# Met à jour seulement le statut ready dans les labels existants
	if players.has(player_id):
		players[player_id].is_ready = status
		_update_labels()  # Mise à jour complète des labels

func _get_self_local_ip() -> String:
	var interfaces = IP.get_local_interfaces()
	for interface in interfaces:
		for address in interface.addresses:
			if address.begins_with("192.168.1."):
				return address
	return ""

# --- Game Scene Management ---
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
		rpc("load_game", "res://scenes/interface.tscn")

@rpc("any_peer", "call_local", "reliable")
func load_game(game_scene_path):
	get_tree().change_scene_to_file(game_scene_path)

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
	joining = false
	cleanUp_UDP()
	disconnect_from_server()
	_reset_labels()
	print("Left the lobby.")
