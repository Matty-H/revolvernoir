extends Control

@onready var map: Control = $Map_texture/Map
@onready var action_buttons: VBoxContainer = $UI/Action_Buttons
@onready var overlay: Control = $Overlay
@onready var console_log: RichTextLabel = $UI/Labels/consoleLog
@onready var players_container: Node = $Players # NOUVEAU: Le dossier qui contiendra les joueurs

signal turn_changed(is_local_turn)
signal players_setup_completed
signal random_value_propagated
signal setup_phase_started

enum game_phase {INITIALISATION, TURN_RUNNING, GAME_OVER}
var current_phase: game_phase = game_phase.INITIALISATION

enum action_stats {FREE, AIMING, TRAP, RUNNING}
var action_stats_now: action_stats = action_stats.FREE

# Fini les chemins en dur. On garde des références vers les objets GamePlayer.
var local_player: GamePlayer
var opponent_player: GamePlayer 
var active_player: GamePlayer
var players_ready_count: int = 0

func _ready() -> void:
	current_phase = game_phase.INITIALISATION
	action_buttons.visible = false
	if multiplayer.is_server():
		NetworkManager.spawn_players_in_scene(players_container)
	
	# 1. On remplace le Timer aléatoire par une sécurité stricte :
	# On attend que les 2 pions (Joueurs ou IA) soient physiquement apparus chez tout le monde
	while players_container.get_child_count() < 2:
		await get_tree().process_frame 
	
	# 2. Maintenant on est sûr qu'ils sont là, on les identifie
	_setup_players_references()
	
	# 3. Le Contrôleur écoute le Modèle (Phase 2)
	local_player.room_selected.connect(_on_player_setup_complete)
	opponent_player.room_selected.connect(_on_player_setup_complete)
	
	# 4. SYNCHRONISATION : On prévient le Serveur qu'on a fini de charger
	if multiplayer.is_server():
		tell_server_im_ready() # L'hôte valide pour lui-même
	else:
		tell_server_im_ready.rpc_id(1) # Le client envoie un Ping à l'hôte

# NOUVELLE FONCTION : Le serveur écoute les validations
@rpc("any_peer", "reliable")
func tell_server_im_ready():
	if not multiplayer.is_server(): return # Sécurité
	
	players_ready_count += 1
	
	# Si tous les vrais joueurs connectés ont validé, on lance le jeu !
	if players_ready_count == NetworkManager.players.size():
		choosing_first_player()

func _setup_players_references() -> void:
	var my_id = multiplayer.get_unique_id()
	
	# On fouille dans le dossier Players pour trouver qui est qui grâce à leur nom (leur ID réseau)
	for child in players_container.get_children():
		if child.name == str(my_id):
			local_player = child
		else:
			opponent_player = child

func sync_random_value():
	var random_value = randi_range(0, 1)
	# On prévient les autres
	propagate_random_value.rpc(random_value)
	# On s'applique la valeur à soi-même (Hôte)
	propagate_random_value(random_value)

@rpc("authority", "call_local", "reliable")
func propagate_random_value(value: int) -> void:
	if current_phase != game_phase.INITIALISATION: 
		return 
	
	# On applique le tirage
	choosing_first_player_with_value(value)
	
	# On passe DIRECTEMENT à la phase de setup, plus aucun await réseau !
	begin_setup_phase()

func choosing_first_player():
	current_phase = game_phase.INITIALISATION
	action_buttons.visible = false
	propagate_random_value.rpc(randi_range(0, 1))

func choosing_first_player_with_value(random_first_player: int):
	var is_opponent_computer = NetworkManager.is_opponent_computer
	online_printer("=======> RAND_SEED: " + str(random_first_player))
	
	if is_opponent_computer:
		if random_first_player == 0:
			online_printer("Human start")
			active_player = local_player
		else:
			online_printer("Computer start")
			active_player = opponent_player
	else:
		if random_first_player == 0:
			online_printer("Player 1 (Host) starts")
			active_player = local_player if multiplayer.is_server() else opponent_player
		else:
			online_printer("Player 2 (Client) starts")
			active_player = opponent_player if multiplayer.is_server() else local_player

func begin_setup_phase():
	online_printer("=== CHOIX DES SALLES DE DÉPART ===")
	if local_player != null:
		local_player.pick_starting_room(map)
	setup_phase_started.emit()

func begin_turn():
	online_printer.rpc("=== CHOIX DES SALLES DE DÉPART ===")
	if local_player != null:
		print("DEBUG : J'ordonne à mon local_player (ID ", local_player.name, ") de choisir.")
		local_player.pick_starting_room(map)
	else:
		print("ERREUR : local_player est NULL sur l'ID ", multiplayer.get_unique_id())

func _on_player_setup_complete(_room_name: String):
	# Dès qu'un joueur choisit une salle, on vérifie si la condition de passage à la Phase 3 est remplie
	if current_phase == game_phase.INITIALISATION:
		if local_player.position_player != "" and opponent_player.position_player != "":
			online_printer("=== LES DEUX JOUEURS SONT PRÊTS ===")
			current_phase = game_phase.TURN_RUNNING
			apply_turn_state() # Lance la boucle de jeu !

# --- GESTION DES TOURS ---
func apply_turn_state():
	if active_player == local_player:
		action_buttons.visible = true
		action_buttons.start_kitchen = (local_player.position_player == "kitchen")
		turn_changed.emit(true)
	else:
		action_buttons.visible = false
		turn_changed.emit(false)

func point_paywall(pts: int):
	action_buttons.start_kitchen = false
	
	# SÉCURITÉ : Seul le joueur dont c'est le tour a le droit de demander à payer
	if active_player == local_player:
		# On demande au réseau de déduire les points pour TOUT LE MONDE en même temps
		sync_spend_ap.rpc(pts)

@rpc("any_peer", "call_local", "reliable")
func sync_spend_ap(pts: int) -> void:
	active_player.action_point_remaining -= pts
	online_printer("PA restants pour " + active_player.name + " : " + str(active_player.action_point_remaining))
	active_player.stats_changed.emit(active_player.life, active_player.action_point_remaining)
	if active_player.action_point_remaining <= 0:
		execute_switch_turn()

func execute_switch_turn() -> void:
	if active_player == local_player:
		online_printer("=== FIN DE MON TOUR ===")
		pop_up("Tour de l'adversaire", 1)
		active_player = opponent_player
	else:
		online_printer("=== DÉBUT DE TON TOUR ===")
		pop_up("C'est à toi !", 1)
		active_player = local_player
		
	# On redonne 2 AP au nouveau joueur
	active_player.action_point_remaining = 2
	active_player.stats_changed.emit(active_player.life, active_player.action_point_remaining)

	apply_turn_state()

# --- UTILITAIRES ---
func pop_up(message: String, timer: float):
	# Le Contrôleur donne un ordre simple à la Vue, sans se soucier de COMMENT elle le fait.
	overlay.get_node("opacifier").pop_up(message, timer)

var print_line : int = 0
@rpc("any_peer", "call_local", "reliable")
func online_printer(printing_paper):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = multiplayer.get_unique_id() # Si appelé en local
	print("(" + str(sender_id) + ") " + printing_paper)
	print_line += 1
	console_log.text += str(print_line) + "/ " + printing_paper + "\n"
	
func hit_verification(target_room: String):
	# On vérifie si la salle ciblée correspond à la position en mémoire de l'adversaire
	if opponent_player.position_player == target_room:
		online_printer.rpc("💥 TOUCHÉ ! " + opponent_player.name + " prend 1 dégât !")
		
		# On ordonne via RPC à l'adversaire de perdre 1 point de vie
		opponent_player.take_damage.rpc(1)
	else:
		online_printer.rpc("💨 MANQUÉ ! Il n'y avait personne dans " + target_room + ".")
