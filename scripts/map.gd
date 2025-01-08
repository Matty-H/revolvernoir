extends Control

@onready var player: Control = $"../../Player"
@onready var opponent: Control = $"../../Opponent"

@onready var shot: Button = $"../../UI/Action_Buttons/Shot"
@onready var map: Control = $"."
@onready var interface: Control = $"../.."
@onready var action_buttons: VBoxContainer = $"../../UI/Action_Buttons"

signal button_selected(String)
signal room_shooted(String)
signal room_fled(String)

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
var adjacent_locations

func _ready() -> void:
	for child in get_children():
		child.pressed.connect(func():
			clicked_on_room(child.name))
		child.mouse_entered.connect(func():
			mouse_over_room(child.name))
		child.mouse_exited.connect(func():
			mouse_left_room(child.name))

func _process(_delta) -> void:
	if interface.ok == true:
		if interface.player_actif.position_player:
			adjacent_locations = house[interface.player_actif.position_player]
		update_button_icon()


var room_status = {
	"balcony": "null",
	"library": "null",
	"corridor": "null",
	"bedroom": "null",
	"hall": "null",
	"kitchen": "null",
	"dining_room": "null",
	"basement": "null",
}

var button_status = {
	"null": "",
	"shot": "res://graphics/aiming.svg",
	"move": "res://graphics/moving.png",
	"set_trap": "res://graphics/bomb.svg",
	"explose": "res://graphics/explosion.svg",
	"player": "res://graphics/icon.svg",
	}
	#on pourrait emettre un signal connecter sur la func update_button_icon quand ce dictionnaire est update pour gagner en ressource


func update_button_icon():
	if player.position_player:
		room_status[player.position_player] = "player"
		if interface.action_stats_now == interface.action_stats.AIMING:
			room_status[player.position_player] = "shot"
			
	for room_name in room_status.keys():
		var status = room_status[room_name]
		var texture_path = button_status.get(status, "")
		if texture_path != "":
			map.get_node(room_name).texture_normal = load(texture_path)
			#map.get_node(room_name).texture_normal = load(button_status[status])
		else:
			map.get_node(room_name).texture_normal = null  # ou une texture par défaut
		pass


func set_icon(x):
	for room in map.house:
		map.room_status[room] = x
		
func remove_icon(x):
	for room in map.room_status:
		if map.room_status[room] == x:
			map.room_status[room] = "null"

func change_player_position(x):
	var old_position = interface.player_actif.position_player
	interface.player_actif.position_player = x
	room_status[old_position]  = "null"

@rpc("any_peer", "call_local", "reliable")
func clicked_on_room(room):
	button_selected.emit(room)
	var button = room_status[room]
	match interface.action_stats_now:
		0: #action_stats_now.FREE
			if room_status[room] == "move":
				change_player_position(room)
				#print("P1 moved")
				interface.point_paywall(1)
		1: #action_stats_now.AIMING
			if room_status[room] == "shot":
				room_shooted.emit(room)
		2: #action_stats_now.TRAP
			if room_status[room] == "set_trap":
				room_shooted.emit(room)
		3: #action_stats_now.RUNNING
			if room_status[room] == "move":
				room_fled.emit(room)
				change_player_position(room)
			return


func mouse_over_room(room):
	var valid_position : bool = (
		interface.player_actif.position_player and
		interface.action_stats_now == interface.action_stats.FREE and
		adjacent_locations.has(room))
	if valid_position:
		room_status[room] = "move"


func mouse_left_room(room):
	if interface.action_stats_now != 3 and interface.current_phase != 0:
		if room_status[room] == "move":
			room_status[room] = "null"
