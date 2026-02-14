extends VBoxContainer

@onready var p_1: Label = $Players_label/P1
@onready var p_2: Label = $Players_label/P2
@onready var p_1_room: Label = $players_localisation/P1_room
@onready var p_2_room: Label = $players_localisation/P2_room
@onready var game_phase: Label = $game_phase

# Si tu n'utilises pas ces boutons dans ce script, tu peux les supprimer.
@onready var trap_1: Button = $"../HBoxContainer/Traps/Trap_1"
@onready var trap_2: Button = $"../HBoxContainer/Traps/Trap_2"

@onready var interface: Control = $"../.."
@onready var map: Control = $"../Map_texture/Map"

func _process(_delta: float) -> void:
	# SÉCURITÉ : On ne met à jour l'UI QUE si les joueurs ont bien fini d'apparaître !
	if not interface.local_player or not interface.opponent_player:
		return
		
	# Raccourcis pour rendre le code plus lisible
	var p = interface.local_player
	var o = interface.opponent_player
	
	# L'ID du joueur est maintenant contenu dans le nom du nœud (p.name)
	p_1.text = "P1_ID#" + str(p.name) + " " + p.position_player + " / LP: " + str(p.life) + " / AP: " + str(p.action_point_remaining)
	
	# Affichage de l'adversaire (Note : En version finale, il faudra cacher o.position_player !)
	p_2.text = "P2: " + o.position_player + " / LP: " + str(o.life) + " / AP: " + str(o.action_point_remaining)

	# Affichage des pièges (Pareil, o.trap_1 et o.trap_2 sont des secrets de l'adversaire !)
	p_1_room.text = "Traps: " + str(p.trap_1) + " / " + str(p.trap_2)
	p_2_room.text = "Traps: " + str(o.trap_1) + " / " + str(o.trap_2)
	
	# Affichage de la phase de jeu
	game_phase.text = str(interface.game_phase.keys()[interface.current_phase])
