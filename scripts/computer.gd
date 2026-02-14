extends Node

@onready var interface: Control = get_parent() 

func _ready() -> void:
	print("--- CERVEAU IA INSÉRÉ DANS LA SCÈNE ---")
	
	if NetworkManager.is_opponent_computer:
		print("IA : Initialisée et prête à écouter.")
		interface.setup_phase_started.connect(_on_setup_phase_started)
		interface.turn_changed.connect(_on_turn_changed)
	else:
		print("IA : Désactivée.")

# --- PHASE 2 : CHOIX DE LA SALLE DE DÉPART ---
func _on_setup_phase_started():
	print("IA : Je choisis ma salle de départ en secret...")

	var map = interface.map 
	
	var random_room = map.house.keys().pick_random()
	interface.opponent_player.sync_room_choice.rpc(random_room)
	
	interface.opponent_player.sync_room_choice.rpc(random_room)

# --- PHASE 3 : LE TOUR DE L'IA ---
func _on_turn_changed(is_local_turn: bool) -> void:
	if not is_local_turn and NetworkManager.is_opponent_computer:
		random_turn()

func random_turn() -> void:
	interface.online_printer.rpc("L'ordinateur réfléchit...")
	var bot = interface.opponent_player
	
	# ON RÉCUPÈRE LA MAP ICI AUSSI !
	var map = interface.map 
	
	while bot.action_point_remaining > 0:
		await get_tree().create_timer(1.5).timeout 
		
		var possible_actions = [0, 1, 2] 
		if bot.action_point_remaining >= 2:
			possible_actions.append(3) 
			
		var action = possible_actions.pick_random()
		
		match action:
			0: # MOVE
				var adjacent_room = map.house[bot.position_player].pick_random()
				bot.sync_room_choice.rpc(adjacent_room)
				interface.online_printer.rpc("IA : (Bruit de pas...)")
				interface.sync_spend_ap.rpc(1)
				
			1: # LISTEN
				interface.online_printer.rpc("IA : Tend l'oreille...")
				interface.sync_spend_ap.rpc(1)
				
			2: # TRAP
				interface.online_printer.rpc("IA : Fait un bruit métallique...")
				interface.sync_spend_ap.rpc(1)
				
			3: # SHOOT
				interface.online_printer.rpc("IA : TIRE À L'AVEUGLE !")
				var random_target = map.target[bot.position_player].pick_random()
				interface.hit_verification(random_target)
				interface.sync_spend_ap.rpc(2)
