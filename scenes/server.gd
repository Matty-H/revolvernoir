extends Node

@onready var server: Node = $"."
@onready var player_1_label: Label = %Player1
@onready var player_2_label: Label = %Player2
@onready var level: Control = $"../level"
@onready var lobby: VBoxContainer = %Lobby
@onready var start_menu: VBoxContainer = %Start_menu
@onready var bounding: Label = $VBoxContainer/HBoxContainer/Bounding
@onready var ip_label: Label = $VBoxContainer/HBoxContainer/ip
@onready var id_label: Label = $VBoxContainer/HBoxContainer/ID

# Signals
signal player_connected(peer_id, room_info)
signal player_disconnected(peer_id)
signal server_disconnected

#PlayMode
var is_opponent_computer : bool = true

# Network Constants & Variables
var peer : ENetMultiplayerPeer
const PORT : int = 60000

var broadcaster : PacketPeerUDP
var broadcastPort : int = PORT+600

var listener : PacketPeerUDP
var listenPort : int = PORT+850

var broadcastTimer : Timer
const MAX_CONNECTIONS : int = 1
const IP_RANGE : String = "192.168.1.255"
var hosting_state : bool = false
var joining_state : bool = false

@onready var server_ip = _get_self_local_ip()
var players = {}  # Player info for every connected player
var room_info = {
	"name": "",
	"id_machine":"",
	"ip_address": "",
	"is_ready": false
}


func _ready():
	peer = ENetMultiplayerPeer.new()
	broadcastTimer = $BroadcastTimer
	room_info.ip_address = _get_self_local_ip()
	room_info.name = _get_name()
	listeningPort()
	_connect_signals()
	_reset_labels()
	_update_labels()
	
func listeningPort():
	listener = PacketPeerUDP.new()
	if listener.bind(listenPort) == OK:
		bounding.text = "Listener port " + str(listenPort) + " connected"
	else:
		bounding.text = "Listener port " + str(listenPort) + " already used"
	$BroadcastTimer.start()

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
	if hosting_state:
		format_and_send_packet()
	if joining_state:
		looking_for_packet()

func looking_for_packet():
	if listener.get_available_packet_count() > 0:
		print("GET PACKET")
		var Ip_sender = listener.get_packet_ip()
		var serverport = listener.get_packet_port()
		var bytes = listener.get_packet()
		var data = bytes.get_string_from_ascii()
		var roomInfo = JSON.parse_string(data)
		var address = roomInfo.ip_address
		print("server Ip: " + address +" serverPort: "+ str(serverport))

		if address != "": #BUG GODOT ? Without, windows-builds bypass the error check on connection_server
			connection_server(address)

func format_and_send_packet():
	print("Sending packets")
	var data = JSON.stringify(room_info)
	var packet = data.to_ascii_buffer()
	broadcaster.put_packet(packet)
	
func cleanUp():
	$BroadcastTimer.stop()
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
	hosting_state = true
	setUpBroadcast()
	print("Hosted on ", server_ip +":"+ str(PORT))
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		print("Create Server error: " + str(error))
		return error
	multiplayer.multiplayer_peer = peer
	_add_local_player(1)

func join_game():
	joining_state = true
	listeningPort()
	#connection_server(server_ip)


func connection_server(address : String):
	joining_state = false
	var error = peer.create_client(address, PORT)
	match error:
		OK:
			pass
		20:
			print(ERR_ALREADY_EXISTS)
			return
		22:
			print(ERR_ALREADY_IN_USE)
			return
	multiplayer.multiplayer_peer = peer

# --- Signal Handlers ---
func _on_player_connected(id):
	room_info.id_machine = id
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
	if players.has(player_id):
		players[player_id].is_ready = status
		_update_labels()

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
		stop_broadcast_timer()
		is_opponent_computer = false
		rpc("sync_opponent_type", is_opponent_computer)
		rpc("load_game", "res://scenes/interface.tscn")

@rpc("any_peer", "call_local", "reliable")
func sync_opponent_type(is_computer: bool) -> void:
	is_opponent_computer = is_computer

@rpc("any_peer", "call_local", "reliable")
func load_game(game_scene_path):
	lobby.visible = false
	var interface_scene: PackedScene = load(game_scene_path)
	var interface_instance: Node = interface_scene.instantiate()
	level.add_child(interface_instance)

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
	
	ip_label.text = "IP: " + str(server_ip)
	id_label.text = "ID: " + str(room_info.id_machine)

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

func stop_broadcast_timer():
	hosting_state = false
	joining_state = false

func leave_lobby():
	stop_broadcast_timer()
	cleanUp()
	disconnect_from_server()
	_reset_labels()
	print("Left the lobby.")
