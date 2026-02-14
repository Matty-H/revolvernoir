extends VBoxContainer

@onready var p_1: Label = $Players_label/P1
@onready var p_2: Label = $Players_label/P2
@onready var p_1_room: Label = $players_localisation/P1_room
@onready var p_2_room: Label = $players_localisation/P2_room
@onready var game_phase: Label = $game_phase

@onready var trap_1: Button = $"../HBoxContainer/Traps/Trap_1"
@onready var trap_2: Button = $"../HBoxContainer/Traps/Trap_2"

@onready var interface: Control = $"../.."
@onready var map: Control = $"../Map_texture/Map"


func _process(delta: float) -> void:		
		var p1 = interface.player1
		var p2 = interface.player2

		# Show full info only for self or if server (for debug)
		var p1_pos = p1.position_player if (p1.is_local or multiplayer.is_server()) else "???"
		var p2_pos = p2.position_player if (p2.is_local or multiplayer.is_server()) else "???"

		p_1.text = "P1: %s / LP: %d / AP: %d" % [p1_pos, p1.life, p1.action_point_remaining]
		p_2.text = "P2: %s / LP: %d / AP: %d" % [p2_pos, p2.life, p2.action_point_remaining]

		p_1_room.text = "Traps: %s / %s" % [str(p1.trap_1), str(p1.trap_2)]
		p_2_room.text = "Traps: %s / %s" % [str(p2.trap_1), str(p2.trap_2)]

		var phase_name = "UNKNOWN"
		if interface.game_manager:
			phase_name = GameManager.GamePhase.keys()[interface.game_manager.current_phase]
		game_phase.text = phase_name
