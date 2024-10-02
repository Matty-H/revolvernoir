extends VBoxContainer

@onready var p_1: Label = $Players_label/P1
@onready var p_2: Label = $Players_label/P2
@onready var p_1_room: Label = $players_localisation/P1_room
@onready var p_2_room: Label = $players_localisation/P2_room
@onready var game_phase: Label = $game_phase

@onready var trap_1: Button = $"../HBoxContainer/Traps/Trap_1"
@onready var trap_2: Button = $"../HBoxContainer/Traps/Trap_2"

@onready var player: Control = $"../../Player"
@onready var opponent: Control = $"../../Opponent"

@onready var interface: Control = $"../.."
@onready var map: Control = $"../Map_texture/Map"


func _process(delta: float) -> void:		
		p_1.text = "P1_ID#"+str(player.player_id)+" "+str(player.position_player)+" / LP: "+str(player.life)+" / AP: "+str(player.action_point_remaining)
		p_2.text = "P2: "+str(opponent.position_player)+" / LP: "+str(opponent.life)+" / AP: "+str(opponent.action_point_remaining)

		p_1_room.text = "Traps: "+str(player.trap_1)+" / "+str(player.trap_2)
		p_2_room.text = "Traps: "+str(opponent.trap_1)+" / "+str(opponent.trap_2)
		game_phase.text = str(interface.game_phase.keys()[interface.current_phase])
