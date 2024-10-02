extends VBoxContainer

@onready var map: Control = $"../../../../Map_texture/Map"
@onready var trap_1: Button = $Trap_1
@onready var trap_2: Button = $Trap_2
@onready var interface: Control = $"../../../.."

@onready var player: Control = $"../../../../Player"
@onready var opponent: Control = $"../../../../Opponent"


func trap_checker(x):
	match x:
		1:
			if interface.player_actif.trap_1:
				blow_up(x)
			else:
				if interface.player_actif.trap_2 != null:
					if interface.player_actif.position_player == interface.player_actif.trap_2:
						print("Trap already placed here")
					else:
						setup_trap(x)
				else:
					setup_trap(x)
		2:
			if interface.player_actif.trap_2:
				blow_up(x)
			else:
				if interface.player_actif.trap_1 != null:
					if interface.player_actif.position_player == interface.player_actif.trap_1:
						print("Trap already placed here")
					else:
						setup_trap(x)
				else:
					setup_trap(x)


func setup_trap(x):
	match interface.player_actif:
		player:
			match x:
				1:
					interface.player_actif.trap_1 = interface.player_actif.position_player
					trap_1.text = str(interface.player_actif.position_player)+" ready!"
				2:
					interface.player_actif.trap_2 = interface.player_actif.position_player
					trap_2.text = str(interface.player_actif.position_player)+" ready!"

		opponent:
			match x:
				1: interface.player_actif.trap_1 = interface.player_actif.position_player
				2: interface.player_actif.trap_2 = interface.player_actif.position_player
	print("Used trap")
	interface.point_paywall(1)

func blow_up(x):
	if x == 1:
		print(interface.player_actif.trap_1 +" blew up!")
		interface.hit_verification(interface.player_actif.trap_1)
		interface.player_actif.trap_1 = null
		trap_1.text = "Trap 1"
	elif x == 2:
		print(interface.player_actif.trap_2 +" blew up!")
		interface.hit_verification(interface.player_actif.trap_2)
		interface.player_actif.trap_2 = null
		trap_2.text = "Trap 2"
	interface.point_paywall(1)

func _on_trap_1_pressed() -> void:
			trap_checker(1)

func _on_trap_2_pressed() -> void:
			trap_checker(2)
