extends Control

@onready var interface: Control = $".."
@onready var traps: VBoxContainer = $"../UI/Action_Buttons/Traps_Listen/Traps"
@onready var listen: Button = $"../UI/Action_Buttons/Traps_Listen/Listen"
@onready var shot: Button = $"../UI/Action_Buttons/Shot"
@onready var map: Control = $"../Map_texture/Map"

signal room_selected()

var position_player
var life = 2
var action_point_remaining = 2
var trap_1 = null
var trap_2 = null

func _ready():
	interface.opponent_turn.connect(random_turn)

func random_turn():
	while action_point_remaining > 0:
		var random_play = randi_range(0,3)
		#var random_play = 0
		match random_play:
			0: #MOVE
				var adjacent_room = map.house[position_player].pick_random()
				position_player = adjacent_room
				print("P2 moved")
				interface.point_paywall(1)
			1: #LISTEN
				listen.listening()
			2: #TRAP
				var random_trap_slot = randi_range(1,2)
				traps.trap_checker(random_trap_slot)
			3: #SHOOT
				if action_point_remaining >= 2:
					shot.firing()

func set_position_player():
	var rooms_list = map.house.keys()
	position_player = rooms_list[randi() % rooms_list.size()]
	print("P2 start in the "+str(position_player))
	room_selected.emit()

func basement_relocalisation():
	var rooms_list = map.house["basement"]
	position_player = rooms_list[randi() % rooms_list.size()]
	print("P2 fled into "+str(position_player))
	room_selected.emit()
