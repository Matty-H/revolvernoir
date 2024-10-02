extends Control

@export var player_scene: PackedScene
@onready var start_menu: VBoxContainer = $Start_menu
@onready var lobby: VBoxContainer = $Lobby
@onready var interface: Control = $level/Interface
@onready var level: Control = $level
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner


func _ready() -> void:
	pass

func _on_play_pressed() -> void:
	lobby.visible = false
	start_menu.visible = false
	lobby.change_level(load("res://scenes/interface.tscn"))
	

func _on_settings_pressed() -> void:
	print("Not yet implemented")

func _on_quit_pressed() -> void:
	print("To quit press red cross")


func _on_host_pressed() -> void:
	start_menu.visible = false
	lobby.visible = true
	lobby.hosting()

 
 
func _on_join_pressed():
	start_menu.visible = false
	lobby.visible = true
	lobby.joining()

func _on_back_pressed() -> void:
	start_menu.visible = true
	lobby.visible = false
