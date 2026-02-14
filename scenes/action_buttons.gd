extends VBoxContainer

@onready var interface: Control = $"../.."
@onready var map: Control = $"../../Map_texture/Map"
@onready var room_skill: HBoxContainer = $Room_skill
@onready var listen: Button = $Traps_Listen/Listen

@onready var skill_button: Button = $Room_skill/skill_button
@onready var skill_description: Label = $Room_skill/skill_description

var player_room
var start_kitchen = false

var house_skill = {
	"balcony": ["Jump", 0, "Jump into the kitchen."],
	"basement": ["Control Panel", 1, "Arms a trap that automatically explodes on the end of next turn."],
	"library": ["Hatch switch", 1, "Open the kitchen hatch leading to the basement."],
	"bedroom": ["Flooding", 1, "Flood the basement. Ennemy can be hit."],
	"hall": ["Echoes", 0, "Listen and localise any ennemy on the 1st floor."],
	"kitchen": ["Breakfast", 0, "At the beginning of turn: Eat and get 3 AP."],
}

var remote_trap_location = {
	"balcony": 0, "library": 0, "corridor": 0, "bedroom": 0,
	"hall": 0, "kitchen": 0, "dining_room": 0,
}

func _process(_delta):
	# On met à jour l'UI uniquement en fonction du joueur local
	if interface.local_player:
		player_room = interface.local_player.position_player
		if house_skill.has(player_room):
			if player_room == "kitchen":
				if start_kitchen == true:
					update_skill_room()
				else:
					room_skill.visible = false
			else:
				update_skill_room()
		else:
			room_skill.visible = false

func update_skill_room():
	room_skill.visible = true
	skill_button.text = str(player_room) + " / " + str(house_skill[player_room][1]) + " AP"
	skill_description.text = str(house_skill[player_room][2])

func _on_skill_button_pressed() -> void:
		# SÉCURITÉ ABSOLUE (Le Videur) :
	if interface.current_phase != interface.game_phase.TURN_RUNNING:
		print("Action refusée : La partie n'a pas encore commencé.")
		return
	if interface.active_player != interface.local_player:
		print("Action refusée : Ce n'est pas ton tour.")
		return
	player_room = interface.local_player.position_player
	match player_room:
		"balcony": balcony_skill.rpc()
		"basement": basement_skill.rpc()
		"library": library_skill.rpc()
		"bedroom": bedroom_skill.rpc()
		"hall": hall_skill.rpc()
		"kitchen": kitchen_skill.rpc()

# Fonction utilitaire pour trouver qui subit l'action
func _get_victim():
	return interface.opponent_player if interface.active_player == interface.local_player else interface.local_player

@rpc("any_peer", "call_local", "reliable")
func balcony_skill():
	interface.online_printer.rpc("Saut depuis le balcon dans la cuisine")
	interface.active_player.position_player = "kitchen"
	interface.point_paywall(house_skill["balcony"][1])

@rpc("any_peer", "call_local", "reliable")
func basement_skill():
	# Seul le joueur dont c'est le tour affiche l'interface de pose de piège
	if interface.active_player == interface.local_player:
		interface.action_stats_now = interface.action_stats.TRAP
		for location in remote_trap_location:
			map.room_status[location] = "set_trap"
			
		var remote_trap_placed = await map.button_selected
		
		map.remove_icon("set_trap")
		# On synchronise le placement sur le réseau !
		place_trap_sync.rpc(remote_trap_placed)
		interface.action_stats_now = interface.action_stats.FREE
		interface.point_paywall(house_skill["basement"][1])

@rpc("any_peer", "call_local", "reliable")
func place_trap_sync(room: String):
	remote_trap_location[room] = 2

@rpc("any_peer", "call_local", "reliable")
func trap_countdown():
	for room in remote_trap_location:
		if remote_trap_location[room] > 0:
			remote_trap_location[room] -= 1
			if remote_trap_location[room] == 0:
				interface.online_printer.rpc("BOOM dans la " + str(room))
				interface.hit_verification(room)

@rpc("any_peer", "call_local", "reliable")
func library_skill():
	var victim = _get_victim()
	if victim.position_player == "kitchen" :
		interface.online_printer.rpc("La trappe de la cuisine s'ouvre. Quelqu'un tombe.")
		victim.position_player = "basement"
	else:
		interface.online_printer.rpc("La trappe de la cuisine s'ouvre.")
	interface.point_paywall(house_skill["library"][1])

@rpc("any_peer", "call_local", "reliable")
func bedroom_skill():
	map.basement_flood = 2
	interface.online_printer.rpc("La cave est maintenant inondée.")
	interface.basement_flood_check()
	interface.point_paywall(house_skill["bedroom"][1])

@rpc("any_peer", "call_local", "reliable")
func hall_skill():
	var victim = _get_victim()
	var first_floor = ["balcony", "corridor", "library", "bedroom"]
	if first_floor.has(victim.position_player):
		interface.online_printer.rpc("Bruit entendu dans la " + str(victim.position_player) + " !")
	else:
		interface.online_printer.rpc("Écoute : " + str(map.house[victim.position_player].pick_random()))
	interface.point_paywall(house_skill["hall"][1])

@rpc("any_peer", "call_local", "reliable")
func kitchen_skill():
	start_kitchen = false
	interface.active_player.action_point_remaining = 3
	interface.point_paywall(house_skill["kitchen"][1])
