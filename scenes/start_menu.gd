extends Control

@export var player_scene: PackedScene
@onready var start_menu: VBoxContainer = $Start_menu
@onready var lobby: VBoxContainer = $Lobby
@onready var level: Control = $level
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var host: Button = $Start_menu/HBoxContainer/Host
@onready var join: Button = $Start_menu/HBoxContainer/Join
@onready var server: Node = $Server

func _on_play_pressed() -> void:
	lobby.visible = false
	start_menu.visible = false
	get_tree().change_scene_to_file("res://scenes/interface.tscn")

func _on_settings_pressed() -> void:
	print("Not yet implemented")

func _on_quit_pressed() -> void:
	#get_tree().quit()
	pass

func _on_host_pressed() -> void:
	start_menu.visible = false
	lobby.visible = true
	server.host_game()
	server.setUpBroadcast()
 
func _on_join_pressed():
	start_menu.visible = false
	lobby.visible = true
	server.join_game()

func _on_back_pressed() -> void:	
	server.leave_lobby()
	server.cleanUp_UDP()

func _on_ready_pressed() -> void:
	server.player_ready()
	#lobby.print_hello.rpc()

@rpc("any_peer")
func print_hello():
	print("Hello from peer!")
