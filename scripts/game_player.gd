extends Node
class_name GamePlayer

signal room_selected()
signal life_changed(new_life)
signal ap_changed(new_ap)

@export var player_name: String = ""
@export var player_id: int = 0 # 1 or 2
@export var is_local: bool = false
@export var is_ai: bool = false
@export var peer_id: int = 0

var position_player: String = ""
var life: int = 2:
	set(value):
		life = value
		life_changed.emit(life)

var action_point_remaining: int = 2:
	set(value):
		action_point_remaining = value
		ap_changed.emit(action_point_remaining)

var trap_1 = null
var trap_2 = null

@onready var interface = get_tree().get_root().find_child("Interface", true, false)

func _ready():
	if player_id == 1:
		player_name = "Host"
	else:
		player_name = "Guest"

func set_position_player_auto():
	var map = interface.map
	var rooms_list = map.house.keys()
	position_player = rooms_list[randi() % rooms_list.size()]
	print(player_name, " starts in the ", position_player)
	room_selected.emit()

func move_to(room: String):
	position_player = room
	room_selected.emit()
