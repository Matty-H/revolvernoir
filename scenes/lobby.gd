extends VBoxContainer


@onready var control: Control = $".."
@export var spawn_level: PackedScene
@onready var level: Control = $"../level"
@onready var lobby: VBoxContainer = $"."

@onready var player_1: Label = $Player1
@onready var player_2: Label = $Player2



signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

const PORT = 123
const DEFAULT_SERVER_IP = "127.0.0.1"
const MAX_CONNECTIONS = 20

var players = {}
var player_info = {"name": "Name"}

var players_loaded = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func hosting():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to start multiplayer server.")
		return
	multiplayer.multiplayer_peer = peer
	#multiplayer.peer_connected.connect(_add_player)
	_add_player()


func _add_player(id = 1):
	var player_id = spawn_level.instantiate()
	player_id.name = str(id)
	print("Player ID: "+str(id))
	call_deferred("add_child",player_id)
	start_game()


func joining(address = ""):
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		return error
	multiplayer.multiplayer_peer = peer


func change_level(scene: PackedScene):
	for c in level.get_children():
		level.remove_child(c)
		c.queue_free()
		# Add new level.
	level.add_child(scene.instantiate())


func start_game():
		lobby.visible = false
		if multiplayer.is_server():
			change_level(load("res://scenes/interface.tscn"))
		else:
			print("IUHLIH")

func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer

	players[1] = player_info
	player_connected.emit(1, player_info)

func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null

@rpc("call_local", "reliable")
func load_game(game_scene_path):
	get_tree().change_scene_to_file(game_scene_path)

@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if multiplayer.is_server():
		players_loaded += 1
		if players_loaded == players.size():
			$/root/Game.start_game()
			players_loaded = 0

func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)


func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)


func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)


func _on_connected_fail():
	multiplayer.multiplayer_peer = null


func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

#func _on_ready_pressed() -> void:
	
