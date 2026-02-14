extends Control

@onready var start_menu: VBoxContainer = %Start_menu
@onready var lobby: VBoxContainer = %Lobby
@onready var player_1_label: Label = %Player1
@onready var player_2_label: Label = %Player2
@onready var bounding: Label = $Debugger/HBoxContainer/Bounding
@onready var ip_label: Label = $Debugger/HBoxContainer/ip
@onready var id_label: Label = $Debugger/HBoxContainer/ID

func _ready() -> void:
	# On s'abonne aux signaux du backend
	NetworkManager.player_list_updated.connect(_update_ui_labels)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	_show_start_menu()
	_update_ui_labels(NetworkManager.players)

# --- Actions des boutons ---
func _on_play_pressed() -> void:
	# 1. On crée un serveur local. Cela donne à ton PC le rôle d'Autorité (ID 1).
	NetworkManager.host_game()
	# 2. On ferme immédiatement les portes du LAN.
	NetworkManager.stop_lan_discovery()
	# 3. On sécurise la variable du bot (Même si load_game_scene le fait aussi).
	NetworkManager.is_opponent_computer = true
	# 4. On charge la scène de jeu INSTANTANÉMENT, sans attendre dans le Lobby.
	NetworkManager.load_game_scene.rpc("res://scenes/interface.tscn")

func _on_host_pressed() -> void:
	_show_lobby()
	NetworkManager.host_game()

func _on_join_pressed() -> void:
	_show_lobby()
	NetworkManager.join_game()

func _on_back_pressed() -> void:    
	NetworkManager.leave_game()
	_show_start_menu()

func _on_ready_pressed() -> void:
	NetworkManager.toggle_ready()

func _on_quit_pressed() -> void:
	get_tree().quit()

# --- Mises à jour Visuelles ---
func _show_start_menu() -> void:
	start_menu.visible = true
	lobby.visible = false

func _show_lobby() -> void:
	start_menu.visible = false
	lobby.visible = true

func _on_server_disconnected() -> void:
	_show_start_menu()
	_update_ui_labels({}) # Reset avec un dictionnaire vide

func _update_ui_labels(players: Dictionary) -> void:
	ip_label.text = "Mon IP : " + NetworkManager.server_ip
	
	# Reset visuel
	player_1_label.text = "Hôte : En attente..."
	player_2_label.text = "Joueur 2 : En attente..."
	
	# Affichage Joueur 1 (Hôte)
	if players.has(1):
		var p1 = players[1]
		player_1_label.text = "Hôte : %s | PC : %s | Prêt : %s" % [
			p1.ip_address, p1.name, str(p1.is_ready)
		]
	
	# Affichage Joueur 2 (Client)
	var other_ids = players.keys()
	other_ids.erase(1)
	
	if other_ids.size() > 0:
		var p2 = players[other_ids[0]]
		player_2_label.text = "Joueur 2 : %s | PC : %s | Prêt : %s" % [
			p2.ip_address, p2.name, str(p2.is_ready)
		]
		
