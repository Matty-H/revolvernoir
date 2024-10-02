extends Control

@onready var map: Control = $"../Map_texture/Map"
@onready var interface: Control = $".."
@onready var traps: VBoxContainer = $"../UI/Action_Buttons/Traps_Listen/Traps"

signal room_selected()

var player_id

var position_player
var life = 2
var action_point_remaining = 2
var trap_1 = null
var trap_2 = null

func set_position_player():
	#player_id = get_tree().get_root().get_node("Control").player_id
	map.set_icon("move")
	position_player = await map.button_selected
	map.set_icon("null")
	room_selected.emit()
