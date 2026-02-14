extends Control

@onready var map: Control = $"."
@onready var interface: Control = $"../.."

signal button_selected(room: String)
signal room_shooted(room: String)
signal room_fled(room: String)

var house = {
	#1st Floor
	"balcony": ["hall", "corridor"],
	"library": ["basement", "basement", "corridor"],
	"corridor": ["balcony", "bedroom", "library"],
	"bedroom": ["kitchen", "corridor"],
	#Ground Floor
	"hall": ["kitchen", "dining_room", "balcony", "basement"],
	"kitchen": ["hall", "dining_room", "bedroom"],
	"dining_room": ["hall", "kitchen", "basement"],
	#Basement
	"basement": ["hall", "dining_room", "library"],
}

var target = {
	#1st Floor
	"balcony": ["balcony", "corridor", "hall", "kitchen", "dining_room"],
	"library": ["library", "corridor", "balcony"],
	"corridor": [ "corridor", "balcony", "bedroom", "library"],
	"bedroom": [ "bedroom", "corridor", "balcony"],
	#Ground Floor
	"hall": ["hall", "dining_room", "kitchen"],
	"kitchen": ["kitchen", "hall", "dining_room"],
	"dining_room": ["dining_room", "hall", "kitchen"],
	#Basement
	"basement": ["basement", "hall", "dining_room"],
}

var basement_flood = 0
var adjacent_locations = []

var room_status = {
	"balcony": "null", "library": "null", "corridor": "null", "bedroom": "null",
	"hall": "null", "kitchen": "null", "dining_room": "null", "basement": "null",
}

var button_status = {
	"null": "",
	"shot": "res://graphics/aiming.svg",
	"move": "res://graphics/moving.png",
	"set_trap": "res://graphics/bomb.svg",
	"explose": "res://graphics/explosion.svg",
	"player": "res://graphics/icon.svg",
}

func _ready() -> void:
	for child in get_children():
		# STRICTEMENT LOCAL : On a enlevé le .rpc() ici !
		child.pressed.connect(func(): clicked_on_room(child.name))
		child.mouse_entered.connect(func(): mouse_over_room(child.name))
		child.mouse_exited.connect(func(): mouse_left_room(child.name))

func _process(_delta) -> void:
	# Phase 2 (Setup) : L'interface DOIT se mettre à jour pour qu'on voie ce qu'on survole
	if interface.current_phase == interface.game_phase.INITIALISATION:
		update_button_icon()
		return
		
	# Phase 3 (Jeu) : On ne met à jour les cases adjacentes que si l'active_player est valide
	if is_instance_valid(interface.active_player) and interface.active_player.position_player != "":
		adjacent_locations = house[interface.active_player.position_player]
		update_button_icon()

func update_button_icon():
	# 1. NETTOYAGE STRICT : On efface TOUTES les icônes "player"
	# Cela empêche les "fantômes" ou la position de l'adversaire de rester collés à l'écran
	for room_name in room_status.keys():
		if room_status[room_name] == "player":
			room_status[room_name] = "null"

	# 2. PLACEMENT : On place l'icône UNIQUEMENT pour le joueur local
	if interface.local_player and interface.local_player.position_player != "":
		room_status[interface.local_player.position_player] = "player"
		
		# Variante si le joueur est en train de viser
		if interface.action_stats_now == interface.action_stats.AIMING:
			room_status[interface.local_player.position_player] = "shot"
			
	# 3. AFFICHAGE : On applique les textures sur la carte
	for room_name in room_status.keys():
		var status = room_status[room_name]
		var texture_path = button_status.get(status, "")
		if texture_path != "":
			map.get_node(room_name).texture_normal = load(texture_path)
		else:
			map.get_node(room_name).texture_normal = null

func set_icon(x):
	for room in map.house:
		map.room_status[room] = x
		
func remove_icon(x):
	for room in map.room_status:
		if map.room_status[room] == x:
			map.room_status[room] = "null"

func change_player_position(x):
	var old_position = interface.active_player.position_player
	interface.active_player.sync_room_choice.rpc(x)
	if room_status.has(old_position):
		room_status[old_position]  = "null"

func mouse_over_room(room):
	# Phase 2 : Autoriser le survol de N'IMPORTE QUELLE salle tant qu'on n'a pas choisi
	if interface.current_phase == interface.game_phase.INITIALISATION:
		if interface.local_player and interface.local_player.position_player == "":
			room_status[room] = "move"
		return

	# Phase 3 : Bloquer le survol si ce n'est pas mon tour
	if interface.active_player != interface.local_player:
		return
		
	var valid_position : bool = (
		interface.local_player.position_player != "" and
		interface.action_stats_now == interface.action_stats.FREE and
		adjacent_locations.has(room)
	)
	if valid_position:
		room_status[room] = "move"

func mouse_left_room(room):
	# CORRECTION BUG 2 : Protection pendant la fuite
	# Si on est en train de fuir, les icônes de mouvement sont "verrouillées" par le jeu.
	# Le mouvement de la souris ne doit surtout pas les effacer.
	if interface.action_stats_now == interface.action_stats.RUNNING:
		return
		
	# Comportement normal (Phase FREE) : on nettoie la trace de la souris
	if room_status[room] == "move":
		room_status[room] = "null"

func clicked_on_room(room):
	button_selected.emit(room)
	
	if interface.current_phase == interface.game_phase.INITIALISATION:
		room_status[room] = "null" 
		return
		
	match interface.action_stats_now:
		0: # FREE
			if room_status[room] == "move":
				change_player_position(room)
				interface.point_paywall(1)
		1: # AIMING
			if room_status[room] == "shot":
				room_shooted.emit(room)
		2: # TRAP
			if room_status[room] == "set_trap":
				pass 
		3: # RUNNING
			if room_status[room] == "move":
				# CORRECTION BUG 1 : L'ordre d'exécution vital !
				# 1. On déplace le joueur pendant que c'est ENCORE son tour
				change_player_position(room)
				
				# 2. On prévient le jeu que l'action est finie (ce qui va déclencher la perte des PA et la fin du tour)
				room_fled.emit(room)
				
