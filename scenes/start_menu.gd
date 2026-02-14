extends Control

@export var player_scene: PackedScene
@onready var start_menu: VBoxContainer = $Start_menu
@onready var lobby: VBoxContainer = $Lobby
@onready var server_list: VBoxContainer = $ServerList
@onready var server_container: VBoxContainer = $ServerList/ScrollContainer/ServerContainer
@onready var level: Control = $level
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var host: Button = $Start_menu/HBoxContainer/Host
@onready var join: Button = $Start_menu/HBoxContainer/Join
@onready var server: Node = $Server


func _on_play_pressed() -> void:
	lobby.visible = false
	start_menu.visible = false
	server.is_opponent_computer = true
	server.room_info.id_machine = 1
	var interface_scene: PackedScene = load("res://scenes/interface.tscn")
	var interface_instance: Node = interface_scene.instantiate()
	level.add_child(interface_instance)

func _on_settings_pressed() -> void:
	print("Not yet implemented")

func _on_quit_pressed() -> void:
	#get_tree().quit()
	pass

func _on_host_pressed() -> void:
	start_menu.visible = false
	lobby.visible = true
	server.host_game()
 
func _on_join_pressed():
	start_menu.visible = false
	server_list.visible = true
	# Clear previous list
	for child in server_container.get_children():
		child.queue_free()
	server.join_game()

func _on_back_pressed() -> void:
	lobby.visible = false
	start_menu.visible = true
	server.leave_lobby()

func _on_ready_pressed() -> void:
	server.player_ready()

func _on_server_found(server_info: Dictionary) -> void:
	var btn = Button.new()
	btn.text = "%s (%s)" % [server_info.name, server_info.ip_address]
	btn.pressed.connect(func(): _on_server_selected(server_info.ip_address))
	server_container.add_child(btn)

func _on_server_selected(ip: String) -> void:
	server_list.visible = false
	lobby.visible = true
	server.connection_server(ip)

func _ready() -> void:
	server.server_found.connect(_on_server_found)

func _on_back_server_list_pressed() -> void:
	server_list.visible = false
	start_menu.visible = true
	server.stop_broadcast_timer()
