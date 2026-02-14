extends Node
class_name GamePlayer

# On utilise des signaux pour prévenir l'UI que quelque chose a changé (ex: on a pris un dégât)
signal room_selected(room_name)
signal stats_changed(life, action_points)
signal player_died

# --- DONNÉES DU JOUEUR ---
var life: int = 2
var action_point_remaining: int = 2
var position_player: String = ""
var trap_1 = null
var trap_2 = null

var interface: Control 

func _ready() -> void:
	set_multiplayer_authority(str(name).to_int())
	# On remonte de DEUX crans : Player -> Players -> Interface
	interface = get_tree().current_scene

func _on_starting_room_selected(room_name: String):
	print("JOUEUR : Choix validé : ", room_name)
	
	# On utilise la référence à la map qu'on a trouvée via l'interface
	var map_node = interface.map 
	
	# On déconnecte proprement
	for connection in map_node.button_selected.get_connections():
		map_node.button_selected.disconnect(connection.callable)
	
	sync_room_choice.rpc(room_name)

# --- DÉPLACEMENT & CHOIX DE SALLE ---
# L'interface passe le nœud "map" en argument pour éviter les $"../Map"
func pick_starting_room(map_node: Control):
	print("JOUEUR : J'ai reçu l'ordre de choisir une salle. J'écoute la carte...")
	if not map_node.button_selected.is_connected(_on_starting_room_selected):
		map_node.button_selected.connect(_on_starting_room_selected)
	else:
		print("JOUEUR : Erreur, j'écoutais déjà la carte.")

@rpc("any_peer", "call_local", "reliable")
func sync_room_choice(room: String):
	position_player = room
	print("Position mise à jour pour ", name, " : ", room)
	# On prévient le Contrôleur (l'interface) que la donnée a changé
	room_selected.emit(room)

# Fonction pour prendre des dégâts
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int) -> void:
	life -= amount
	stats_changed.emit(life, action_point_remaining) # L'interface mettra à jour les cœurs à l'écran
	if life <= 0:
		player_died.emit()
