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
	#1st Floor
	"balcony": 0,
	"library": 0,
	"corridor": 0,
	"bedroom": 0,
	#Ground Floor
	"hall": 0,
	"kitchen": 0,
	"dining_room": 0,
}

func _process(delta):
	if interface.player_actif == null: return
	player_room = interface.player_actif.position_player
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
	skill_button.text = str(player_room)+" / "+str(house_skill[player_room][1])+" AP"
	skill_description.text = (str(house_skill[player_room][2]))


func _on_skill_button_pressed() -> void:
	if not interface.player_actif.is_local: return

	player_room = interface.player_actif.position_player
	request_skill.rpc_id(1, player_room)

@rpc("any_peer", "call_local", "reliable")
func request_skill(room: String):
	if not multiplayer.is_server(): return

	if interface.player_actif.position_player != room: return

	var ap_cost = house_skill[room][1]
	if interface.player_actif.action_point_remaining < ap_cost: return

	match room:
		"balcony":
			balcony_skill()
		"basement":
			basement_skill()
		"library":
			library_skill()
		"bedroom":
			bedroom_skill()
		"hall":
			hall_skill()
		"kitchen":
			kitchen_skill()

func balcony_skill():
	var player_actif = interface.player_actif
	interface.online_printer.rpc(str(player_actif.player_name)+" jumped over balcony into the kitchen")
	player_actif.position_player = "kitchen"
	interface.point_paywall(house_skill["balcony"][1])

func basement_skill():
	if interface.player_actif.is_local:
		interactive_basement_trap()

func interactive_basement_trap():
	interface.action_stats_now = interface.action_stats.TRAP
	for location in remote_trap_location:
		map.room_status[location] = "set_trap"
	var remote_trap_placed = await map.button_selected
	
	map.remove_icon("set_trap")
	interface.action_stats_now = interface.action_stats.FREE
	request_set_basement_trap.rpc_id(1, remote_trap_placed)

@rpc("any_peer", "call_local", "reliable")
func request_set_basement_trap(room: String):
	if not multiplayer.is_server(): return
	if interface.player_actif.position_player != "basement": return
	if interface.player_actif.action_point_remaining < house_skill["basement"][1]: return

	remote_trap_location[room] = 2
	interface.online_printer.rpc(interface.player_actif.player_name + " armed a remote trap")
	interface.point_paywall(house_skill["basement"][1])

func trap_countdown():
	for room in remote_trap_location:
		if remote_trap_location[room] > 0:
			remote_trap_location[room] -= 1
			if remote_trap_location[room] == 0:
				print("BOMM in the "+str(room))
				interface.hit_verification(room)

func library_skill():
	if interface.player_non_actif.position_player == "kitchen" :
		print("Kitchen hatch opened and somebody fell.")
		interface.player_non_actif.position_player = "basement"
	else:
		print("Kitchen hatch opened.")
	interface.point_paywall(house_skill["library"][1])

func bedroom_skill():
	map.basement_flood = 2
	print("The basement is now flooded.")
	interface.basement_flood_check()
	interface.point_paywall(house_skill["bedroom"][1])

func hall_skill():
	var first_floor = ["balcony","corridor","library","bedroom"]
	if first_floor.has(interface.player_non_actif.position_player):
		print("Noice in the "+ str(interface.player_non_actif.position_player)+"!")
	else:
		print("Listening: "+ str(map.house[interface.player_non_actif.position_player].pick_random()))
	interface.point_paywall(house_skill["hall"][1])

func kitchen_skill():
	start_kitchen = false
	interface.player_actif.action_point_remaining = 3
	interface.point_paywall(house_skill["kitchen"][1])
