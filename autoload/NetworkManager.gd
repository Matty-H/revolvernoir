extends Node
# Nom du Singleton (Autoload) : NetworkManager

# --- Signaux pour communiquer avec l'UI (Front-end) ---
signal player_list_updated(players: Dictionary)
signal server_disconnected
signal game_started

# --- Variables Réseau ---
var peer: ENetMultiplayerPeer
const PORT: int = 60000

var broadcaster: PacketPeerUDP
const BROADCAST_PORT: int = PORT + 600
const BROADCAST_IP: String = "255.255.255.255" # Broadcast local universel

var listener: PacketPeerUDP
const LISTEN_PORT: int = PORT + 850

var broadcast_timer: Timer
const MAX_CONNECTIONS: int = 1

var hosting_state: bool = false
var joining_state: bool = false
var is_opponent_computer: bool = true

var player_scene: PackedScene = preload("res://scenes/player.tscn")

@onready var server_ip: String = _get_self_local_ip()
var players: Dictionary = {}
var room_info: Dictionary = {
	"name": "",
	"id_machine": "",
	"ip_address": "",
	"is_ready": false
}

func _ready() -> void:
	peer = ENetMultiplayerPeer.new()
	room_info.ip_address = server_ip
	room_info.name = _get_system_name()
	
	# Création du timer dynamiquement pour éviter de devoir l'ajouter à la main dans l'éditeur
	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = 1.0
	broadcast_timer.timeout.connect(_on_broadcast_timer_timeout)
	add_child(broadcast_timer)
	
	_connect_multiplayer_signals()

# --- Découverte IP & Système (Dynamique) ---
func _get_self_local_ip() -> String:
	var interfaces = IP.get_local_interfaces()
	for interface in interfaces:
		for address in interface.addresses:
			# On cherche une adresse IPv4 qui n'est pas la boucle locale (localhost)
			if address.count(".") == 3 and not address.begins_with("127."):
				return address
	return "127.0.0.1"

func _get_system_name() -> String:
	if OS.has_environment("COMPUTERNAME"): return OS.get_environment("COMPUTERNAME")
	if OS.has_environment("HOSTNAME"): return OS.get_environment("HOSTNAME")
	return "Player_" + str(randi() % 1000)

# --- Logique LAN (UDP) ---
func start_listening() -> void:
	listener = PacketPeerUDP.new()
	var err = listener.bind(LISTEN_PORT)
	if err != OK:
		print("Erreur: Port d'écoute déjà utilisé ou bloqué.")
	broadcast_timer.start()

func start_broadcasting() -> void:
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_broadcast_enabled(true)
	broadcaster.set_dest_address(BROADCAST_IP, LISTEN_PORT)
	broadcast_timer.start()

func _on_broadcast_timer_timeout() -> void:
	if hosting_state:
		_send_broadcast_packet()
	if joining_state:
		_listen_for_packets()

func _send_broadcast_packet() -> void:
	var data = JSON.stringify(room_info).to_ascii_buffer()
	
	# 1. Envoi au réseau local (LAN pour les autres PC)
	broadcaster.set_dest_address(BROADCAST_IP, LISTEN_PORT)
	broadcaster.put_packet(data)
	
	# 2. Envoi à la machine elle-même (Localhost pour tes tests sur le même Mac !)
	broadcaster.set_dest_address("127.0.0.1", LISTEN_PORT)
	broadcaster.put_packet(data)

func _listen_for_packets() -> void:
	if listener and listener.get_available_packet_count() > 0:
		var bytes = listener.get_packet()
		var data = bytes.get_string_from_ascii()
		var incoming_room_info = JSON.parse_string(data)
		
		if incoming_room_info and incoming_room_info.has("ip_address"):
			connect_to_server(incoming_room_info.ip_address)

func stop_lan_discovery() -> void:
	broadcast_timer.stop()
	hosting_state = false
	joining_state = false
	if listener: listener.close()
	if broadcaster: broadcaster.close()

# --- Logique Serveur / Client (ENet) ---
func host_game() -> void:
	hosting_state = true
	start_broadcasting()
	
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		print("Erreur création serveur: ", error)
		return
	
	multiplayer.multiplayer_peer = peer
	_add_local_player(1)

func join_game() -> void:
	joining_state = true
	start_listening()

func connect_to_server(address: String) -> void:
	joining_state = false
	var error = peer.create_client(address, PORT)
	if error == OK:
		multiplayer.multiplayer_peer = peer
	else:
		print("Erreur de connexion : ", error)

func leave_game() -> void:
	stop_lan_discovery()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

# --- Gestion des joueurs et RPCs ---
func _connect_multiplayer_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _add_local_player(id: int) -> void:
	players[id] = room_info.duplicate()
	player_list_updated.emit(players)

func _on_peer_connected(id: int) -> void:
	# Le serveur synchronise les infos avec le nouveau client
	_register_player.rpc_id(id, room_info)

@rpc("any_peer", "reliable")
func _register_player(info: Dictionary) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	players[sender_id] = info
	player_list_updated.emit(players)

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	player_list_updated.emit(players)

func _on_connected_to_server() -> void:
	_add_local_player(multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	leave_game()

# --- Gestion du statut Prêt (Ready) ---

# 1. Le joueur clique sur le bouton (Appelé depuis MainMenu.gd)
func toggle_ready() -> void:
	if multiplayer.is_server():
		# Si je suis le serveur, je traite ma propre demande directement
		_process_ready_toggle(1)
	else:
		# Si je suis client, j'envoie une requête RPC au serveur (ID 1)
		_request_ready_toggle.rpc_id(1)

# 2. Le serveur reçoit la demande d'un client
@rpc("any_peer", "reliable")
func _request_ready_toggle() -> void:
	if not multiplayer.is_server(): return # Sécurité : seul le serveur écoute ça
	
	var sender_id = multiplayer.get_remote_sender_id()
	_process_ready_toggle(sender_id)

# 3. Le serveur modifie les données
func _process_ready_toggle(id: int) -> void:
	if players.has(id):
		var new_status = not players[id].is_ready
		# Le serveur ordonne à TOUS les joueurs (y compris lui-même) de se mettre à jour
		_sync_player_ready.rpc(id, new_status)
		_check_all_ready()

# 4. Synchronisation forcée chez tout le monde
@rpc("authority", "call_local", "reliable")
func _sync_player_ready(id: int, is_ready: bool) -> void:
	if players.has(id):
		players[id].is_ready = is_ready
		# On signale à l'UI locale (MainMenu) de se rafraîchir
		player_list_updated.emit(players)

func _check_all_ready() -> void:
	var all_ready = true
	for p in players.values():
		if not p.is_ready:
			all_ready = false
			break
			
	if all_ready and players.size() > 1:
		stop_lan_discovery()
		is_opponent_computer = false # <-- AJOUTE BIEN CECI !
		load_game_scene.rpc("res://scenes/interface.tscn")

@rpc("authority", "call_local", "reliable")
func load_game_scene(scene_path: String) -> void:
	# CORRECTION CRUCIALE : On déduit le type de partie pour tout le monde !
	# Si on est plus de 1 joueur connecté, c'est forcément un humain (false).
	is_opponent_computer = (players.size() <= 1)
	
	game_started.emit()
	get_tree().change_scene_to_file(scene_path)

# --- NOUVELLES FONCTIONS ---
# L'interface appellera cette fonction quand elle sera 100% chargée
func spawn_players_in_scene(container: Node) -> void:
	# Sécurité absolue : Seul le serveur a le droit de créer les pions
	if not multiplayer.is_server():
		return 
		
	for peer_id in players.keys():
		_instantiate_player(peer_id, container)
		
	# On n'oublie pas l'IA si on joue contre l'ordinateur
	if is_opponent_computer:
		_instantiate_player(2, container) # ID fictif "2" pour l'IA

func _instantiate_player(id: int, container: Node) -> void:
	var player_instance = player_scene.instantiate()
	player_instance.name = str(id) # Le nom devient l'ID réseau
	container.add_child(player_instance)
	
# Fonction utilitaire pour générer un joueur
func spawn_player(id: int, container: Node) -> void:
	var player_instance = player_scene.instantiate()
	player_instance.name = str(id) # Le nom DU NOEUD devient l'ID réseau, c'est vital !
	container.add_child(player_instance)
