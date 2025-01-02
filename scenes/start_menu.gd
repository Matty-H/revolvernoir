extends Control

@export var player_scene: PackedScene
@onready var start_menu: VBoxContainer = $Start_menu
@onready var lobby: VBoxContainer = $Lobby
@onready var interface: Control = $level/Interface
@onready var level: Control = $level
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner

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
	lobby.host_game()
 
func _on_join_pressed():
	start_menu.visible = false
	lobby.visible = true
	lobby.join_game()

func _on_back_pressed() -> void:
	lobby._disconnect_from_server.rpc()
	
	start_menu.visible = true
	lobby.visible = false

func _on_ready_pressed() -> void:
	#if lobby.players.size() > 0:
		#print(lobby.players.keys()[0])
	lobby.print_hello.rpc()
