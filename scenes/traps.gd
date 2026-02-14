extends VBoxContainer

@onready var trap_1: Button = $Trap_1
@onready var trap_2: Button = $Trap_2
@onready var interface: Control = get_tree().current_scene

func _on_trap_1_pressed() -> void:
	if _can_act(): trap_checker(1)

func _on_trap_2_pressed() -> void:
	if _can_act(): trap_checker(2)

# --- LE VIDEUR (Refacto pour ne pas répéter le code) ---
func _can_act() -> bool:
	if interface.current_phase != interface.game_phase.TURN_RUNNING:
		print("Action refusée : La partie n'a pas encore commencé.")
		return false
	if interface.active_player != interface.local_player:
		print("Action refusée : Ce n'est pas ton tour.")
		return false
	if interface.local_player.action_point_remaining < 1:
		print("Action refusée : Pas assez de points d'action.")
		return false
	return true

# --- LOGIQUE LOCALE DU JOUEUR ACTIF ---
func trap_checker(trap_id: int):
	# On sait que c'est le tour du local_player grâce au Videur
	var current_player = interface.local_player 
	var current_room = current_player.position_player

	# Astuce : on récupère la valeur du piège dynamiquement selon l'ID
	var trap_room = current_player.trap_1 if trap_id == 1 else current_player.trap_2
	var other_trap_room = current_player.trap_2 if trap_id == 1 else current_player.trap_1

	if trap_room != null:
		# 1. EXPLOSION
		blow_up_rpc.rpc(trap_id) # On synchronise la variable (efface le piège)
		
		# 2. UNIQUEMENT le tireur lance les événements réseau pour éviter l'écho !
		interface.online_printer.rpc("BOOM ! Un piège a explosé dans : " + str(trap_room))
		interface.hit_verification(trap_room)
		interface.point_paywall(1)
		
	else:
		# 1. POSE DU PIÈGE
		if other_trap_room == current_room:
			print("Un piège est déjà placé dans cette salle !")
		else:
			setup_trap_rpc.rpc(trap_id, current_room) # On synchronise la variable
			
			# 2. Pareil, seul l'initiateur lance le paiement et le message
			interface.online_printer.rpc("Un piège a été posé.")
			interface.point_paywall(1)

# --- SYNCHRONISATION DES DONNÉES (Modèle & Vue) ---
# Ces fonctions ne font QUE mettre à jour les variables et les boutons. Aucun événement réseau ici !

@rpc("any_peer", "call_local", "reliable")
func setup_trap_rpc(trap_id: int, room: String):
	var actor = interface.active_player

	if trap_id == 1:
		actor.trap_1 = room
		if actor == interface.local_player:
			trap_1.text = room + " ready!"
			
	elif trap_id == 2:
		actor.trap_2 = room
		if actor == interface.local_player:
			trap_2.text = room + " ready!"

@rpc("any_peer", "call_local", "reliable")
func blow_up_rpc(trap_id: int):
	var actor = interface.active_player

	if trap_id == 1:
		actor.trap_1 = null
		if actor == interface.local_player:
			trap_1.text = "Trap 1"
			
	elif trap_id == 2:
		actor.trap_2 = null
		if actor == interface.local_player:
			trap_2.text = "Trap 2"
